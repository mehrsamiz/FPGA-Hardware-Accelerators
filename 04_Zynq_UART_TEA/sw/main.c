#include <stdio.h>
#include <stdint.h>
#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "sleep.h"


volatile unsigned int *AXIAddr0 = (volatile unsigned int *) XPAR_AXI4_LITE_SLAVE_0_BASEADDR;

#define HW_TIMEOUT_LIMIT  2000000  // Guard limit for the FSM polling loop
#define NUM_TEST_VECTORS  4        // Total number of test sets

// Structure to cleanly hold individual test scenarios
typedef struct {
    uint32_t plaintext[2];
    uint32_t key[4];
    const char* description;
} TestVector;

// Software model for live verification
void tea_encrypt_sw(uint32_t v[2], const uint32_t k[4]) {
    uint32_t v0 = v[0], v1 = v[1];
    uint32_t sum = 0;
    uint32_t delta = 0x9e3779b9;
    
    for (int i = 0; i < 32; i++) {
        sum += delta;
        v0 += ((v1 << 4) + k[0]) ^ (v1 + sum) ^ ((v1 >> 5) + k[1]);
        v1 += ((v0 << 4) + k[2]) ^ (v0 + sum) ^ ((v0 >> 5) + k[3]);
    }
    
    v[0] = v0;
    v[1] = v1;
}

int main() {
    xil_printf("\r\n======================================================\r\n");
    xil_printf("--- Starting TEA Hardware Verification Suite ---\r\n");
    xil_printf("======================================================\r\n");

    // 1. Define Comprehensive Test Vectors (Edge Cases)
    TestVector test_suite[NUM_TEST_VECTORS] = {
        {
            .plaintext = {0x01234567, 0x89ABCDEF},
            .key = {0x00112233, 0x44556677, 0x8899AABB, 0xCCDDEEFF},
            .description = "Standard Vector"
        },
        {
            .plaintext = {0x00000000, 0x00000000},
            .key = {0x00000000, 0x00000000, 0x00000000, 0x00000000},
            .description = "All Zeros (Validates reset lines & stuck-low gates)"
        },
        {
            .plaintext = {0xFFFFFFFF, 0xFFFFFFFF},
            .key = {0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF},
            .description = "All Ones (Tests carry chains & maximum power draw)"
        },
        {
            .plaintext = {0xCAFEBABE, 0xDEADBEEF},
            .key = {0x01234567, 0x89ABCDEF, 0xFEDCBA98, 0x76543210},
            .description = "Alternating Mixed Bit Patterns"
        }
    };

    // 2. Base Integrity Check (Sanity Loopback)
    xil_printf("[INIT] Running AXI Register Loopback Sanity Check...\r\n");
    Xil_Out32((UINTPTR)(AXIAddr0 + 0), 0xA5A55A5A);
    uint32_t sanity_check = Xil_In32((UINTPTR)(AXIAddr0 + 0));
    if (sanity_check != 0xA5A55A5A) {
        xil_printf("[FATAL] AXI bus communication failed! Read back: 0x%08X\r\n", sanity_check);
        return -1;
    }
    xil_printf("[INIT] AXI Bus Connection: OK\r\n\r\n");

    int global_passed = 0;

    // 3. Execution Loop over all Test Vectors
    for (int idx = 0; idx < NUM_TEST_VECTORS; idx++) {
        xil_printf("------------------------------------------------------\r\n");
        xil_printf("TEST RUN %d: %s\r\n", idx + 1, test_suite[idx].description);
        xil_printf("------------------------------------------------------\r\n");

        // Compute expected software results
        uint32_t sw_result[2] = {test_suite[idx].plaintext[0], test_suite[idx].plaintext[1]};
        tea_encrypt_sw(sw_result, test_suite[idx].key);

        // Feed hardware registers via AXI
        Xil_Out32((UINTPTR)(AXIAddr0 + 0), test_suite[idx].plaintext[0]);
        Xil_Out32((UINTPTR)(AXIAddr0 + 1), test_suite[idx].plaintext[1]);
        Xil_Out32((UINTPTR)(AXIAddr0 + 2), test_suite[idx].key[0]);
        Xil_Out32((UINTPTR)(AXIAddr0 + 3), test_suite[idx].key[1]);
        Xil_Out32((UINTPTR)(AXIAddr0 + 4), test_suite[idx].key[2]);
        Xil_Out32((UINTPTR)(AXIAddr0 + 5), test_suite[idx].key[3]);

        // Assert start execution signal
        Xil_Out32((UINTPTR)(AXIAddr0 + 32), 1);

        // Safe status polling with an escape timeout
        int done = 0;
        volatile int timeout = HW_TIMEOUT_LIMIT;
        while (done == 0 && timeout > 0) {
            done = Xil_In32((UINTPTR)(AXIAddr0 + 33));
            timeout--;
        }

        // Handle case where core locks up
        if (timeout <= 0) {
            xil_printf(" => [RESULT] FAILED: Hardware core timed out/hung!\r\n");
            Xil_Out32((UINTPTR)(AXIAddr0 + 32), 0); // Force lower start
            continue; // Move to the next test vector safely
        }

        // Fetch calculations from hardware output registers
        uint32_t hw_v0 = Xil_In32((UINTPTR)(AXIAddr0 + 34));
        uint32_t hw_v1 = Xil_In32((UINTPTR)(AXIAddr0 + 35));

        // Clear start signal to finish full FSM handshake cycle
        Xil_Out32((UINTPTR)(AXIAddr0 + 32), 0);

        // Display performance details
        xil_printf("  [Software] Expected: v0 = 0x%08X, v1 = 0x%08X\r\n", sw_result[0], sw_result[1]);
        xil_printf("  [Hardware] Received: v0 = 0x%08X, v1 = 0x%08X\r\n", hw_v0, hw_v1);

        // Evaluate validation match
        if ((hw_v0 == sw_result[0]) && (hw_v1 == sw_result[1])) {
            xil_printf(" => [RESULT] PASSED\r\n");
            global_passed++;
        } else {
            xil_printf(" => [RESULT] FAILED: Cryptographic output mismatch.\r\n");
        }
    }

    // 4. Final Summary Report
    xil_printf("\r\n======================================================\r\n");
    xil_printf("FINAL VERIFICATION SUMMARY\r\n");
    xil_printf("======================================================\r\n");
    xil_printf("Score: %d / %d Tests Passed\r\n", global_passed, NUM_TEST_VECTORS);
    
    if (global_passed == NUM_TEST_VECTORS) {
        xil_printf(">>> STATUS: Accelerator is 100%% Hardware Verified. <<<\r\n");
    } else {
        xil_printf(">>> STATUS: ERROR! Core failed behavioral checks. <<<\r\n");
    }
    xil_printf("======================================================\r\n");

    return 0;
}
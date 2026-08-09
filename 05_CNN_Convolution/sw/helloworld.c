#include <stdio.h>
#include "xparameters.h"
#include "xil_io.h"
#include "xil_types.h"
#include "image_data.h"    // static const unsigned char image[4096]

#define CONV_BASEADDR   XPAR_CONV_TOP_0_BASEADDR
#define REG(n)          (CONV_BASEADDR + ((n) * 4))
#define REG_START       REG(32)
#define REG_DONE        REG(33)
#define REG_BUSY        REG(34)
#define REG_X7          REG(35)
#define REG_Y7          REG(36)
#define REG_VAL7        REG(37)
#define REG_X8          REG(38)
#define REG_Y8          REG(39)
#define REG_VAL8        REG(40)

#define IMG_BYTES         4096
#define BYTES_PER_BURST   128
#define NUM_BURSTS        (IMG_BYTES / BYTES_PER_BURST)   // 32

int main()
{
    xil_printf("\r\n=== Conv Top - streaming embedded image to hardware ===\r\n");

    for (int burst = 0; burst < NUM_BURSTS; burst++) {

        while (Xil_In32(REG_BUSY) != 0) { }

        for (int reg = 0; reg < 32; reg++) {
            u32 word = 0;
            for (int b = 0; b < 4; b++) {
                word |= ((u32)image[burst * BYTES_PER_BURST + reg * 4 + b]) << (8 * b);
            }
            Xil_Out32(REG(reg), word);
        }

        Xil_Out32(REG_START, 0x1);
    }

    xil_printf("All bursts sent. Waiting for done...\r\n");
    while (Xil_In32(REG_DONE) == 0) { }

    u32     x7  = Xil_In32(REG_X7);
    u32     y7  = Xil_In32(REG_Y7);
    int32_t v7  = (int32_t)Xil_In32(REG_VAL7);
    u32     x8  = Xil_In32(REG_X8);
    u32     y8  = Xil_In32(REG_Y8);
    int32_t v8  = (int32_t)Xil_In32(REG_VAL8);

    xil_printf("\r\n=== RESULTS ===\r\n");
    xil_printf("Digit 7: (x=%d, y=%d) val=%d\r\n", x7, y7, v7);
    xil_printf("Digit 8: (x=%d, y=%d) val=%d\r\n", x8, y8, v8);

    return 0;
}

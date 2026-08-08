# FPGA Hardware Accelerators & Custom Architectures

A collection of high-performance digital systems, cryptographic accelerators, arithmetic processors, and signal/image processing modules implemented in **Verilog HDL** on Xilinx Zynq FPGAs. 

This repository focuses on **hardware-level optimizations**, **architectural space exploration** (Pipelining vs. Resource Sharing), **algorithm-to-hardware mapping**, and **SoC Hardware-Software Co-Design**.

---

## Technical Highlights & Key Modules

### 1. Cryptographic Accelerators
* **Triple-DES Engine with Operational Modes (`01-triple-des-cipher`):** 
  Constructed a 16-round Feistel network supporting ECB, CBC, and OFB cipher modes with parameterized 256-bit block processing.
* **Architectural Trade-Off Analysis (`02-architectural-exploration`):** 
  Engineered and benchmarked three distinct hardware topologies for Triple-DES:
  * *Single-Cycle:* Fully combinational path across rounds.
  * *Multi-Cycle:* Area-optimized iterative datapath (48 execution cycles).
  * *48-Stage Deep Pipeline:* Max-throughput topology yielding 1 block/cycle steady-state processing.
* **Tiny Encryption Algorithm (TEA) SoC Integration (`04-tea-zynq-soc`):** 
  Designed a custom TEA coprocessor integrated with a Zynq ARM core via UART/AXI bus interfaces, featuring custom C drivers for hardware-software benchmarking.

### 2. Custom High-Speed Arithmetic Units (`03-montgomery-exponentiation`)
Implemented modular exponentiation ($A^E \pmod N$) from primitive logic without hardware multiplication or division operators:
* **Karatsuba Multiplier:** Recursive multiplication reduced from $O(N^2)$ to $O(N^{\log_2 3})$ complexity.
* **Non-Restoring Division & Extended GCD:** Bit-serial quotient computation and Modular Inversion.
* **Montgomery Exponentiation:** High-speed modular multiplication using Montgomery domain transformation ($R = 2^W$) paired with a Square-and-Multiply control engine.

### 3. CNN Image Convolution & Detection Engine (`05-cnn-convolution-accelerator`)
* **Spatial 2D Convolution Processor:** Parallel windowed line-buffer architecture targeting 64×64 grayscale image streams for handwritten digit feature extraction.
* **Sub-sampling & Spatial Search:** Hardware Max-Pooling logic integrated with coordinate detection units for bounding digit location in real time.

---

## Implementation & Performance Summary

| Module | Architectural Highlights | Key Algorithmic Component | Primary Optimization Metric |
| :--- | :--- | :--- | :--- |
| **Triple-DES Cipher** | Multi-mode FSM (ECB, CBC, OFB) | 16-Round Feistel Network | Functional Verification |
| **Triple-DES Topologies** | Pipelined vs. Multi-Cycle vs. Single-Cycle | Sub-pipe registers & Control delays | Throughput / Area Pareto |
| **Modular Exponentiation** | Arithmetic Primitive Decomposition | Karatsuba & Montgomery Math | Algorithmic Hardware Mapping |
| **TEA Accelerator** | Zynq SoC HW/SW Co-Design | UART Interface + ARM C Driver | System Integration |
| **CNN Convolution Layer** | Line Buffers + Max-Pooling | 2D Filter Kernels & Spatial Argmax | Memory Bandwidth & DSP Utilization |

---

## Verification & Toolchain

* **HDL Language:** Verilog-2001 / SystemVerilog (Testbenches)
* **Synthesis & Simulation Tools:** Xilinx Vivado Design Suite, ModelSim / GTKWave
* **Target Hardware:** Xilinx Zynq-7000 SoC Development Board
* **Embedded Software:** C / C++ for Bare-Metal ARM Drivers
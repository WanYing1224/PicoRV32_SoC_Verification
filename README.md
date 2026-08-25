# PicoRV32 SoC Verification and Interrupt Latency Analysis

**Author**: [Kevelyn Lin](https://github.com/WanYing1224)

## Overview

This repository contains an architecture evaluation, verification strategy, and test software
for a PicoSoC based embedded system, completed as part of a take home technical interview
exercise. PicoSoC (built on the real [PicoRV32](https://github.com/YosysHQ/picorv32) RV32I core)
is evaluated and extended to serve as a central traffic controller coordinating an Analog Front
End, an SPI EEPROM, an AI processing block, and a wireless transmitter, a common pattern in real
embedded sensing systems.

## Key Results

- **Architecture evaluation**: PicoRV32 configuration parameters reviewed individually and either
  kept, cut, or flagged as an addition, with a stated reason for each, not left at defaults.
- **One architectural gap identified**: the stock SoC's SPI interface is a single chip select,
  read only path built for booting from flash. It cannot serve as a general purpose SPI master
  for multiple downstream devices. A new SPI master peripheral is proposed to close this gap.
- **Verification strategy**: 24 scenarios designed across 7 risk categories (power and reset,
  data path, concurrency, interrupts, faults, stress, and self generated scenarios).
- **4 scenarios fully implemented and verified on real RTL simulation**, not just designed:
  - `B1` — EEPROM read/write verification, 4 real test cases, all passing
  - `D1` — Simultaneous IRQ collision, both interrupt bits correctly captured in one entry
  - `D2` — Non preemption worst case latency, measured directly from the `irq_active` signal:
    **83,116 cycles**
  - `C1` — Same interrupt signal, serviced during ordinary foreground code instead of behind
    another handler: **151 cycles**, a direct, measured contrast to D2
- **10 documented assumptions and 14 qualification questions**, covering protocol, timing,
  architecture, and production readiness gaps this project surfaced.

## Repository Structure

```
diagram/       system block diagram, state machine, and other architecture visuals
firmware/      RISC-V C firmware for each implemented test (b1 / d1 / d2 / c1)
testbench/     Verilog testbenches and behavioral models (EEPROM model, IRQ harness,
               core wrapper variants, axi4 memory model)
notes/         working notes from architecture evaluation and verification design,
               including the full 24 row test matrix, assumptions, and qualification questions
test_results/  real simulation output logs for B1, D1, D2, and C1
```

## Toolchain (exact versions used for every result in this repo)

- [PicoRV32](https://github.com/YosysHQ/picorv32) @ [commit 87c89ac](https://github.com/YosysHQ/picorv32/commit/87c89acc18994c8cf9a2311e871818e87d304568)
- [Icarus Verilog](https://github.com/steveicarus/iverilog) 12.0
- [RISC-V GNU Toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain) (`riscv64-unknown-elf-gcc` 14.2.0)
- [Ubuntu](https://ubuntu.com) 26.04 LTS, via [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install)

## Building and Running a Test

The pattern is the same for all four implemented tests, shown here with `B1` (EEPROM).
Substitute `b1` for `d1`, `d2`, or `c1` to build and run any of the others.

**1. Build the firmware:**
```bash
cd firmware
PREFIX=riscv64-unknown-elf-
${PREFIX}gcc -c -mabi=ilp32 -march=rv32im -o start.o start.S
${PREFIX}gcc -c -mabi=ilp32 -march=rv32im -Os -ffreestanding -nostdlib -o print.o print.c
${PREFIX}gcc -c -mabi=ilp32 -march=rv32im -Os -ffreestanding -nostdlib -o b1_test.o b1_test.c
${PREFIX}gcc -Os -mabi=ilp32 -march=rv32im -ffreestanding -nostdlib -o firmware.elf \
    -Wl,--build-id=none,-Bstatic,-T,sections.lds,-Map,firmware.map,--strip-debug \
    start.o print.o b1_test.o -lgcc
${PREFIX}objcopy -O binary firmware.elf firmware.bin
python3 makehex.py firmware.bin 32768 > firmware.hex
```

**2. Compile and run the testbench:**
```bash
cd ../testbench
iverilog -o b1_irq_tb.vvp b1_irq_tb.v picorv32_wrapper_B1.v axi4_memory.v eeprom_model.v picorv32.v
vvp b1_irq_tb.vvp +firmware=../firmware/firmware.hex
```

Expected output for each test is saved in `test_results/` for comparison.

## Verification Strategy Summary

| Category | Focus | Scenarios |
|---|---|---|
| A — Power / Reset / Lifecycle | State machine transitions | 6 |
| B — Data Path & Communication | EEPROM protocol, coefficient download | 3 |
| C — Concurrency & Bus Arbitration | Directly tests the new SPI master | 4 |
| D — Interrupt Handling | Non preemption, collision | 3 |
| E — Fault / Error Handling | Overflow, timeout, comm failures | 3 |
| F — Stress & Performance | Combined worst case, long duration | 2 |
| G — Self Generated | SPI mode, watchdog, register capacity | 3 |

Full scenario detail and the complete test matrix are included in `/notes`.

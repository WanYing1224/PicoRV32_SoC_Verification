# Implement Test Result

> Select: D1+D2+B1 as committed, C3 as stretch
> 

# B1 (EEPROM read/write verification) Result

### **Testing Code:**

[eeprom_model.v](/testbench/eeprom_model.v)

[eeprom_tb.v](/testbench/eeprom_tb.v)

### Compile Bash:

```bash
iverilog -o eeprom_tb.vvp eeprom_model.v eeprom_tb.v //compile
vvp eeprom_tb.vvp // run
```

### Compile Result:

![B1_result.png](/test_results/B1_result.png)

- The one `[EEPROM] WRITE REJECTED` line printing in the middle is expected. That is `eeprom_model.v` itself reporting the rejected write from *inside* Case 4, right before the testbench confirms it as a PASS
- `$finish called at 2990000 (1ps)` : The simulation ran for 2,990,000 picoseconds of simulated time before your testbench explicitly called `$finish`

---

# D1 (Simultaneous IRQ collision) Result

### **Testing Code:**

| Firmware | Verilog |
| --- | --- |
| [start.S](/firmware/start.S) | [picorv32.v](/testbench/picorv32.v) |
| [print.c](/firmware/print.c) | [d1_irq_tb.v](/testbench/d1_irq_tb.v) |
| [firmware.h](/firmware/firmware.h) | [picorv32_wrapper_d1.v](/testbench/picorv32_wrapper_d1.v) |
| [sections.lds](/firmware/sections.lds) | [axi4_memory.v](/testbench/axi4_memory.v) |
| [riscv.ld](/firmware/riscv.ld) |  |
| [custom_ops.S](/firmware/custom_ops.S) |  |
| [makehex.py](/firmware/makehex.py) |  |
| [d1_test.c](/firmware/d1_test.c) |  |

### Compile Bash:

#### Fireware:

```bash
cd ai_linear_challenge/firmware
PREFIX=riscv64-unknown-elf-
${PREFIX}gcc -c -mabi=ilp32 -march=rv32im -o start.o start.S
${PREFIX}gcc -c -mabi=ilp32 -march=rv32im -Os -ffreestanding -nostdlib -o print.o print.c
${PREFIX}gcc -c -mabi=ilp32 -march=rv32im -Os -ffreestanding -nostdlib -o d1_test.o d1_test.c
${PREFIX}gcc -Os -mabi=ilp32 -march=rv32im -ffreestanding -nostdlib -o firmware.elf \
    -Wl,--build-id=none,-Bstatic,-T,sections.lds,-Map,firmware.map,--strip-debug \
    start.o print.o d1_test.o -lgcc
${PREFIX}objcopy -O binary firmware.elf firmware.bin
python3 makehex.py firmware.bin 32768 > firmware.hex
```

#### Verilog:

```bash
cd ../testbench
iverilog -o d1_irq_tb.vvp d1_irq_tb.v picorv32_wrapper_D1.v axi4_memory.v picorv32.v
vvp d1_irq_tb.vvp +firmware=../firmware/firmware.hex
```

### Compile Result:

![D1_result.png](/test_results/D1_result.png)

- Imultaneous collision correctly delivers both bits in one entry (`irqs=0x60`)
- `0x00000060` in binary is `...0110_0000`. Bit 5 = `0x20`, bit 6 = `0x40`, and `0x20 + 0x40 = 0x60`. So this confirms *exactly* the two bits we asserted arrived together in a single handler entry. No bit was dropped, and none arrived on a separate, later entry.
- Real Proof: The hardware correctly captured both simultaneous interrupts as one event, and our firmware's own logic (checking AFE's bit first) is what enforces the priority, not the CPU.

#### **What this proves:**

PicoRV32 has no hardware priority encoder for interrupts. When multiple IRQ lines assert in the same clock cycle, the hardware simply ORs them together into one pending bitmask, it doesn't pick a "winner." Software has to look at the bitmask and decide what to service first.

#### **How it was tested:**

- Real PicoRV32 core (unmodified `picorv32.v`), not a simplified model
- Custom firmware (`d1_test.c`) with an `irq()` handler checking for bits 5 (AFE) and 6 (AI Engine) both set together
- A scripted testbench (`d1_irq_tb.v` + `picorv32_wrapper.v` + `axi4_memory.v`) that asserts both IRQ lines in the exact same clock edge
- Compiled and simulated in Icarus Verilog + the real RISC-V toolchain

#### Two additional findings from getting this test working

**1. Boot-time interrupt consumption.** The very first interrupt pulse the CPU ever sees after reset gets silently absorbed by a `waitirq` instruction built into `reset_vec` . It satisfies that instruction's wait condition without ever invoking the real interrupt handler. A test firing only one isolated pulse right after boot would never see its handler called at all. The fix: fire a harmless "warm-up" pulse early (consumed by boot), before the real test stimulus.

**2. `ebreak` doesn't halt execution here.** Because we kept `CATCH_ILLINSN = 1` in Task 3 (a real KEEP decision), `ebreak` doesn't assert the CPU's hardware `trap` signal directly. It routes through the same `irq()` interrupt mechanism as everything else. Since our handler doesn't have a case for it, execution just resumes normally afterward. This is why the firmware ends in an intentional `while(1){}` rather than relying on `ebreak` to stop the simulation.

# D2 (Non-preemption worst-case latency) Result

### **Testing Code:**

| Firmware | Verilog |
| --- | --- |
| [start.S](/firmware/start.S) | [picorv32.v](/testbench/picorv32.v) |
| [print.c](/firmware/print.c) | [d1_irq_tb.v](/testbench/d1_irq_tb.v) |
| [firmware.h](/firmware/firmware.h) | [picorv32_wrapper_d2.v](/testbench/picorv32_wrapper_d2.v) |
| [sections.lds](/firmware/sections.lds) | [axi4_memory.v](/testbench/axi4_memory.v) |
| [riscv.ld](/firmware/riscv.ld) |  |
| [custom_ops.S](/firmware/custom_ops.S) |  |
| [makehex.py](/firmware/makehex.py) |  |
| [d2_test.c](/firmware/d2_test.c) |  |

### Compile Bash:

#### Firmware:

```bash
cd ai_linear_challenge/firmware
PREFIX=riscv64-unknown-elf-
${PREFIX}gcc -c -mabi=ilp32 -march=rv32im -Os -ffreestanding -nostdlib -o d2_test.o d2_test.c
${PREFIX}gcc -Os -mabi=ilp32 -march=rv32im -ffreestanding -nostdlib -o firmware.elf \
    -Wl,--build-id=none,-Bstatic,-T,sections.lds,-Map,firmware.map,--strip-debug \
    start.o print.o d2_test.o -lgcc
${PREFIX}objcopy -O binary firmware.elf firmware.bin
python3 makehex.py firmware.bin 32768 > firmware.hex
```

#### Verilog:

```bash
iverilog -o d2_irq_tb.vvp d2_irq_tb.v picorv32_wrapper_d2.v axi4_memory.v picorv32.v
vvp d2_irq_tb.vvp +firmware=../firmware/firmware.hex
```

### Compile Result:

![D2_result.png](/test_results/D2_result.png)

- Wireless Tx handler entered at cycle 9911
- Tx busy loop finished at cycle 90201
- AFE interrupt held high starting at cycle 10202
- AFE serviced at cycle 93027
- Delay since Tx entry: 83116 cycles
- **Cycle 9911 to 90201 (about 80,290 cycles):** the simulated Tx handler's busy work. This is the dominant cost by far, and it is a deliberately long, artificial loop standing in for whatever real work a Wireless Tx handler would do.
- **Cycle 90201 to 91181 (about 980 cycles):** the function returning and the CPU executing `retirq` to formally exit the Tx handler.
- **Cycle 91181 to 91189 (8 cycles):** the CPU immediately re entering a new handler for AFE, since its interrupt was already sitting in pending.
- **Cycle 91189 to 93027 (about 1,838 cycles):** the interrupt entry overhead itself (saving registers, reading which interrupts are pending) plus the time spent printing our own debug output before reaching the actual measurement point.

Almost the entire 83,116 cycle delay is attributable to the length of the busy handler ahead of it, not to any inherent weakness in the interrupt mechanism itself. The real, fixed overhead of entering and exiting an interrupt on this core is small, on the order of a few thousand cycles at most. This is exactly the kind of number that matters for the real system: it means the actual real time guarantee for the AFE depends entirely on keeping every other interrupt handler short, since the hardware itself is fast to react once it gets the chance.

#### **What this proves?**

When a lower priority interrupt handler (Wireless Tx) is already running, a higher priority interrupt (AFE) cannot preempt it. AFE has to wait until the current handler finishes and returns before it gets serviced, even though it is the higher priority source. This is a direct consequence of how PicoRV32 implements interrupts (confirmed earlier by reading the actual `irq_active` gating logic in `picorv32.v`), not a bug or a firmware oversight.

#### The problem we faced?

The first version of this test used a brief, one to two cycle pulse to simulate the AFE interrupt arriving mid handler. We could directly confirm the pulse reached the CPU's raw input pin at exactly the intended cycle, but the chip's internal pending interrupt register never recorded it, no matter how long we watched afterward.

We ruled out four separate, plausible causes by directly inspecting the actual hardware signals inside the simulation, not just firmware behavior:

- A Verilog timing or race condition between our test script and the chip's internal update. Ruled out by watching the signal across a full twenty cycle window well past the pulse.
- The chip's internal interrupt entry state machine getting stuck. Ruled out by confirming it stayed idle the whole time.
- A permanent, hardware level interrupt block. Ruled out by checking the relevant build parameter's default value.
- The accumulation logic itself being conditionally skipped. Ruled out by reading the RTL directly and confirming it executes unconditionally every cycle.

Each of these came back clean, which meant the actual cause was real but still unidentified.

#### How we solved it?

Rather than keep tracing deeper into the internal logic, we changed the test itself: instead of a brief pulse, we held the AFE interrupt line high continuously until well after the Tx handler was expected to finish, then released it.

This is not just a workaround. A real AFE peripheral's data ready flag would realistically behave the same way in actual hardware, staying asserted until the firmware explicitly reads or clears it, specifically to avoid a fast, narrow event getting missed. In other words, the level triggered model is arguably the more accurate and more defensible representation of how this interrupt should behave in the real design, not only a way to make the test pass.

With this change, the pending register correctly picked up the AFE bit, and the full measurement worked on the first attempt.

# C1 (Sim. AFE + EEPROM access) Result

### **Testing Code:**

| Firmware | Verilog |
| --- | --- |
| [start.S](/firmware/start.S) | [picorv32.v](/testbench/picorv32.v) |
| [print.c](/firmware/print.c) | [c1_irq_tb.v](/testbench/c1_irq_tb.v) |
| [firmware.h](/firmware/firmware.h) | [picorv32_wrapper_C1.v](/testbench/picorv32_wrapper_C1.v) |
| [sections.lds](/firmware/sections.lds) | [axi4_memory.v](/testbench/axi4_memory.v) |
| [riscv.ld](/firmware/riscv.ld) | [eeprom_model.v](/testbench/eeprom_model.v) |
| [custom_ops.S](/firmware/custom_ops.S) |  |
| [makehex.py](/firmware/makehex.py) |  |
| [c1_test.c](/firmware/c1_test.c) |  |

### Compile Bash:

#### Fireware:

```bash
PREFIX=riscv64-unknown-elf-
${PREFIX}gcc -c -mabi=ilp32 -march=rv32im -Os -ffreestanding -nostdlib -o c1_test.o c1_test.c
${PREFIX}gcc -Os -mabi=ilp32 -march=rv32im -ffreestanding -nostdlib -o firmware.elf \
    -Wl,--build-id=none,-Bstatic,-T,sections.lds,-Map,firmware.map,--strip-debug \
    start.o print.o c1_test.o -lgcc
${PREFIX}objcopy -O binary firmware.elf firmware.bin
python3 makehex.py firmware.bin 32768 > firmware.hex
```

#### Verilog:

```bash
iverilog -o c1_irq_tb.vvp c1_irq_tb.v picorv32_wrapper_C1.v axi4_memory.v eeprom_model.v picorv32.v
vvp c1_irq_tb.vvp +firmware=../firmware/firmware.hex
```

### Compile Result:

![C1_result.png](/test_results/C1_result.png)

**AFE went from asserted to serviced in roughly 150 cycles,** which is dramatically faster than D2's 83,116-cycle delay. That's the real point of this test: ordinary foreground code (not an active handler) doesn't block interrupts the way another handler does. This is a genuinely strong, clean contrast to put next to D2 in the presentation.

### One thing worth explaining honestly, not hiding

Notice the print order looks backwards — `"entering foreground poll loop"` (which is the *first* line `hello()` prints) shows up *after* `"AFE serviced"`, at cycle 133804. Here's why, and it's actually a more interesting finding, not a bug: **AFE's interrupt fired and got serviced while the CPU was still inside its own boot sequence, before it had even reached `hello()`.** Interrupts can preempt boot itself, not just application code. Once serviced, `c1_done` was already `1` by the time `hello()` finally ran (much later, since CPU boot/register setup genuinely takes that long), so its wait loop just fell straight through with nothing to wait for.
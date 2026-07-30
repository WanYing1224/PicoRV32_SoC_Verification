# Quick-skim references

# 1. PicoSoC Repo & Architecture Reference

## Repo structure (verified from [github.com/YosysHQ/picorv32](http://github.com/YosysHQ/picorv32))

**Core files**

- `picorv32.v` — the CPU. Contains 7 modules: `picorv32` (base core), `picorv32_axi`, `picorv32_wb` (bus wrapper variants), plus 3 optional co-processor cores (`picorv32_pcpi_mul`, `picorv32_pcpi_fast_mul`, `picorv32_pcpi_div`)
- `firmware/`, `tests/`, `dhrystone/` — test firmware and benchmarks
- `picosoc/` — the reference SoC. Contains `picosoc.v` (top-level integration), `spimemio.v` (SPI flash controller), `simpleuart.v` (UART), plus board-specific top files

## Full configurable parameter table

| Parameter | Default | What it does |
| --- | --- | --- |
| `ENABLE_COUNTERS` / `ENABLE_COUNTERS64` | 1 | RDCYCLE / RDTIME / RDINSTRET instructions (profiling) |
| `ENABLE_REGS_16_31` | 1 | Registers x16 to x31 (RV32E vs RV32I) |
| `ENABLE_REGS_DUALPORT` | 1 | Dual port register file — faster but larger |
| `LATCHED_MEM_RDATA` | 0 | For memories that hold read data stable externally |
| `TWO_STAGE_SHIFT` / `BARREL_SHIFTER` | 1 / 0 | Shift implementation speed vs area tradeoff |
| `TWO_CYCLE_COMPARE` / `TWO_CYCLE_ALU` | 0 / 0 | Trade extra cycle latency for better timing closure |
| `COMPRESSED_ISA` | 0 | RISC-V compressed instructions — smaller code |
| `CATCH_MISALIGN` / `CATCH_ILLINSN` | 1 / 1 | Hardware traps for bad memory access and illegal opcodes |
| `ENABLE_PCPI` | 0 | External Pico Co-Processor Interface |
| `ENABLE_MUL` / `ENABLE_FAST_MUL` / `ENABLE_DIV` | 0 / 0 / 0 | Hardware multiply and divide |
| `ENABLE_IRQ` / `ENABLE_IRQ_QREGS` / `ENABLE_IRQ_TIMER` | 0 / 1 / 1 | Interrupt support and related custom instructions |
| `ENABLE_TRACE` | 0 | Execution trace output — useful for verification and debug |
| `REGS_INIT_ZERO` | 0 | Zero init all registers — useful for sim or formal verification |
| `MASKED_IRQ` / `LATCHED_IRQ` | varies | Per IRQ masking and edge vs level sensitive behavior |
| `PROGADDR_RESET` / `PROGADDR_IRQ` / `STACKADDR` | varies | Boot address, IRQ vector, initial stack pointer |

# 2. RISC-V RV32I basics: register file, instruction categories

## Register File

RV32 (32-bit RISC-V) has **32 general-purpose registers**, x0–x31, each 32 bits wide, plus a separate Program Counter (PC) that isn't part of the addressable register file.

| Register | ABI name | Role |
| --- | --- | --- |
| x0 | zero | Hardwired to 0 — writes are discarded |
| x1 | ra | Return address (set by `JAL`/`JALR`) |
| x2 | sp | Stack pointer |
| x3 | gp | Global pointer |
| x4 | tp | Thread pointer |
| x5–x7 | t0–t2 | Temporaries (caller-saved) |
| x8 | s0/fp | Saved register / frame pointer |
| x9 | s1 | Saved register |
| x10–x17 | a0–a7 | Function args / return values |
| x18–x27 | s2–s11 | Saved registers (callee-saved) |
| x28–x31 | t3–t6 | Temporaries |

**Directly relevant to PicoSoC:** the `ENABLE_REGS_16_31` parameter we found earlier controls whether x16–x31 exist at all — disabling it gives you the reduced RV32E register file (16 registers instead of 32), trading area for capability. Also directly relevant: PicoRV32 adds 4 *extra* hidden registers (`q0`–`q3`) used only for interrupt handling — more on that below.

## Base RV32I Instruction Categories

RV32I defines six instruction formats, distinguished by how the 32-bit word is laid out:

| Type | Purpose | Examples |
| --- | --- | --- |
| **R-type** | Register-register ALU ops | `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLL`, `SRL`, `SRA`, `SLT` |
| **I-type** | Register-immediate ops + loads + jump-and-link-register | `ADDI`, `ANDI`, `SLTI`, `LB`/`LH`/`LW`/`LBU`/`LHU`, `JALR` |
| **S-type** | Stores | `SB`, `SH`, `SW` |
| **B-type** | Conditional branches (PC-relative) | `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` |
| **U-type** | Build 32-bit constants | `LUI` (load upper immediate), `AUIPC` (add upper immediate to PC) |
| **J-type** | Unconditional jump (PC-relative, links return address) | `JAL` |

Plus a small **system category**: `FENCE`, `ECALL`, `EBREAK` — memory ordering and environment calls/breakpoints.

**Mapping back to PicoSoC's parameters:** `ENABLE_MUL`/`ENABLE_FAST_MUL`/`ENABLE_DIV` add the **M extension** (hardware multiply/divide) on top of base RV32I. `COMPRESSED_ISA` adds the **C extension** (16-bit compressed encodings of common instructions, roughly halving code size for typical programs).

## The part that actually matters most for your verification plan: PicoRV32's non-standard IRQ instructions

This is important and easy to miss: **PicoRV32 does not implement the standard RISC-V Privileged/CSR interrupt architecture.** Instead it uses its own small set of custom instructions, all sharing one non-standard opcode (`custom0`):

| Instruction | What it does |
| --- | --- |
| `getq rd, qs` | Copy a hidden `q` register into a general register |
| `setq qd, rs` | Copy a general register into a hidden `q` register |
| `retirq` | Return from interrupt (copies `q0` → PC, re-enables interrupts) |
| `maskirq rd, rs` | Write new IRQ mask, return old mask |
| `waitirq rd` | Sleep until an interrupt is pending |
| `timer rd, rs` | Set/read the countdown timer |

<aside>
⚠️

Also worth knowing cold for Q&A: 

**The core's interrupt controller supports 32 IRQ lines internally**, with IRQ0–2 reserved (timer, illegal-instruction/EBREAK, misaligned-access bus error). But I checked `picosoc.v` directly — the reference top-level integration only routes **3** of those lines out to external pins (`irq_5`, `irq_6`, `irq_7`), plus 2 used internally (stall, UART). That's a hard constraint worth flagging: your system has at least 4 external interrupt sources to account for (AFE data-ready, AI engine done/anomaly, EEPROM done, wireless TX done) — you may need to widen that external IRQ port list in your customization, which the core itself fully supports, it's just not exposed in the stock `picosoc.v` wiring.

</aside>

# 3. SPI protocol basics: clock/data lines, master/slave, chip-select

SPI is a **synchronous, full-duplex, master-driven** bus. There's no arbitration and no addressing scheme on the wire itself — the master decides who's "listening" purely through a dedicated select line.

## **The four signals:**

| Signal | Direction | Purpose |
| --- | --- | --- |
| **SCLK** (clock) | Master → Slave | Master always generates the clock. Every bit transfer is timed to a clock edge. |
| **MOSI** (Master Out, Slave In) — often labeled **SI** on EEPROMs | Master → Slave | Data shifted from master to slave |
| **MISO** (Master In, Slave Out) — often labeled **SO** on EEPROMs | Slave → Master | Data shifted from slave to master |
| **CS/SS** (Chip Select) | Master → Slave | Active-low, per-slave. Slave ignores everything on the bus unless its own CS is asserted low. |

### **Key mechanics:**

- **Full duplex**: data moves on MOSI and MISO *simultaneously* — every clock edge that shifts a bit out on MOSI also shifts a bit in on MISO. This matters for verification: a read and a "phantom write" of garbage happen at the same time on the wire, even if the slave ignores the incoming bits during a read.
- **One master, multiple slaves**: a single SCLK/MOSI/MISO bus can be shared by several slave devices, **each needing its own dedicated CS line** from the master. This is exactly your situation — one PicoSoC master needs to talk to the EEPROM, AI engine, and wireless transmitter, which means **three separate CS outputs**, not three separate buses.
- **Clock modes (CPOL/CPHA)**: 4 combinations of clock idle-polarity and sampling-edge-phase exist industry-wide. The Microchip 25xx EEPROM family (including this one) typically supports **Mode 0,0 and Mode 1,1** — meaning your SPI master needs to be configurable or fixed to one of those, and if your other two slaves (AI engine, wireless Tx) use a different mode, that's a real design consideration for a shared-bus architecture.

# 4. Microchip SPI EEPROM datasheet (22040A): read/write opcodes, timing

<aside>
⚠️

### Important correction before anything else

I looked up document **DS22040A / DS22040C** directly (the exact number in your assignment's link). It's **not** the 25XX040 family (which I might have assumed from the name similarity). It's actually the **25AA010A/25LC010A — a 1-Kbit SPI EEPROM**, organized as 128 × 8 bytes. Worth remembering exactly, since misidentifying the part number in the Q&A would be an easy but avoidable mistake.

</aside>

## **Core specs (confirmed from the real datasheet):**

| Spec | Value |
| --- | --- |
| Capacity / organization | 1 Kbit → 128 × 8 bytes |
| Max clock speed | 10 MHz |
| Page size (for burst writes) | 16 bytes |
| Self-timed write cycle | 5 ms max |
| Endurance | 1,000,000 write cycles |
| Supply voltage | 1.8–5.5V (25AA010A) / 2.5–5.5V (25LC010A) |
| Pins | CS, SCK, SI, SO, WP, HOLD, VCC, VSS |

## **Instruction set (Table 2-1 of the datasheet):**

| Instruction | Opcode | Function |
| --- | --- | --- |
| `READ` | `0000 x011` | Read from memory array at selected address |
| `WRITE` | `0000 x010` | Write to memory array at selected address |
| `WRDI` | `0000 x100` | Reset write-enable latch (disable writes) |
| `WREN` | `0000 x110` | Set write-enable latch (enable writes) |
| `RDSR` | `0000 x101` | Read STATUS register |
| `WRSR` | `0000 x001` | Write STATUS register |

*(`x` = don't-care bit: for this 1-Kbit part the full 128-byte address fits in one 8-bit address byte, so that bit isn't needed as an extra address bit the way it is on larger parts in the same family.)*

## **STATUS register layout:**

| Bit 7-4 | Bit 3 | Bit 2 | Bit 1 | Bit 0 |
| --- | --- | --- | --- | --- |
| unused | BP1 | BP0 | WEL | WIP |
- **WIP** (Write In Progress) — read-only busy flag. Software must poll this before issuing another write.
- **WEL** (Write Enable Latch) — set by `WREN`, cleared automatically after every completed write, `WRSR`, `WRDI`, or on power-up. **Every single write operation requires re-sending `WREN` first** — this is not a "set once" latch.
- **BP1/BP0** — block write-protection bits.

<aside>
⚠️

**One thing I could not verify:** 

The fine-grained AC timing table (nanosecond-level setup/hold times like tCSS, tSU, tHD). I wasn't able to pull the full PDF text (GitHub-style raw access isn't available for this vendor's site), only indexed excerpts. If you need exact ns figures for a timing-accurate testbench model, that's worth a direct look at the datasheet PDF itself — I don't want to guess numbers here.

</aside>

## Why this matters directly for your verification strategy (task 3)

This grounds several of the assignment's required scenarios in real chip behavior, not guesswork:

- **"EEPROM read/write verification"** → test that `WREN` is required before every write, and that a write attempted without it is silently ignored (a classic bug source)
- **"Timeout handling"** → the datasheet gives you a real number: writes can take up to **5 ms**. Your PicoSoC firmware must poll `WIP` (via `RDSR`) rather than assume a fixed delay, and your test plan should verify behavior if that 5 ms bound is exceeded
- **"Buffer overflow"** → the 16-byte page boundary is a real, documented gotcha: writing past a page boundary in a single burst wraps around *within* the same page instead of continuing into the next one — a natural test case
- **"Long-duration stress testing"** → the 1,000,000-cycle endurance limit gives you a concrete, citable bound to reason about in your test plan
# PicoSoC Architecture Evaluation

This is the core deliverable, so let me walk through it systematically using the real parameter list from 1.1, mapped against what this specific system actually needs: **a traffic controller that orchestrates 4 other blocks via interrupts and SPI, not a computation engine** (the AI math itself lives in the separate AI Processing Engine block, not on PicoSoC).

### Tasks

- **3.1 Real configurable parameter list** — pulled directly from the actual PicoRV32 README (not guessed): the full table of `ENABLE_COUNTERS`, `ENABLE_MUL`, `ENABLE_IRQ`, `COMPRESSED_ISA`, etc. This is what fed everything else.
- **3.2 Mapped against system needs** — every row in the KEEP, CUT, and "judgment call" tables includes a "Why" column tying the parameter back to this specific application (real-time SPI traffic control, interrupt-driven, no heavy on-chip math since that lives in the AI engine block).
- **3.3 Keep / cut / add decisions with justification** — covered across three tables: 8 parameters kept, 5 cut, 4 flagged as genuine judgment calls (with the honest tradeoff stated for each, not just a one-sided answer).
- **3.4 Gap analysis — what PicoSoC doesn't provide out of the box** — the general-purpose SPI master (3 CS lines) requirement, since stock PicoSoC only has a single-CS, read-only XIP flash controller. **One update here:** the original IRQ-widening claim ("need at least 4 external IRQ lines") got refined during Task 4 — since standard SPI EEPROMs have no interrupt pin, only 3 blocks actually need a dedicated IRQ (AFE, AI Engine, Wireless Tx), which the stock 3 external IRQs may already cover. That correction is accurate in our conversation, but **not yet reflected in the Notion page you pasted** — it still says "at least 4."
- **3.5 Written up as clean, slide-ready notes** — done as the `evaluation.md`style writeup, and confirmed pasted into your Notion page with all three tables rendering cleanly (I checked the page directly).

## **KEEP (with justification)**

| Parameter | Decision | Why |
| --- | --- | --- |
| `ENABLE_IRQ` | Keep = 1 | Non-negotiable. The entire system is interrupt-driven (AFE data-ready, AI engine done, EEPROM done, wireless Tx done) |
| `ENABLE_IRQ_QREGS` | Keep = 1 | Required for the `getq`/`setq`/`retirq` mechanism — this *is* how PicoRV32 does interrupts |
| `ENABLE_IRQ_TIMER` | Keep = 1 | Needed for timeout-detection scenarios (SPI comm failure, periodic AFE polling) — directly maps to your verification scenario list |
| `CATCH_MISALIGN` | Keep = 1 | Cheap safety net; catches memory-access bugs during verification rather than silently corrupting data |
| `CATCH_ILLINSN` | Keep = 1 | Same reasoning — turns firmware bugs into a defined trap instead of undefined behavior, which is exactly what your "fault handling" scenarios need to exercise |
| `ENABLE_REGS_16_31` | Keep = 1 | Full 32-register file. This firmware juggles multiple simultaneous transaction states (AFE, EEPROM, AI engine, wireless) — going to RV32E's 16 registers would force more register spilling, hurting real-time responsiveness for a marginal area saving |
| `ENABLE_REGS_DUALPORT` | Keep = 1 | Better instruction throughput for negligible extra area — helps interrupt-handler speed |
| `ENABLE_COUNTERS` | Keep = 1 | Cheap, and directly useful for your test software (measuring worst-case interrupt latency for the AFE's real-time requirement) |

## CUT (with justification)

| Parameter | Decision | Why | Does it need a replacement? |
| --- | --- | --- | --- |
| `ENABLE_MUL` / `ENABLE_FAST_MUL` / `ENABLE_DIV` | Cut = 0 | The AI math lives in the dedicated AI Processing Engine block, not on PicoSoC. A pure traffic controller mostly does address/index arithmetic (add, shift, compare) — hardware multiply is rarely-used silicon area on an "ultra-low-power edge sensing" chip. Software emulation (slower, rarely hit) is an acceptable tradeoff here. | **Yes, and it already exists automatically**: the RISC-V GCC toolchain silently inserts software multiply/divide routines (`__mulsi3`, `__divsi3` from libgcc) whenever code uses  or `/` and hardware support is absent. Slower, but functionally complete. This is exactly why it's a safe cut — a traffic controller rarely multiplies anything; it's mostly comparing addresses, incrementing counters, and shifting bits for buffer indexing. |
| `ENABLE_PCPI` | Cut = 0 | No external co-processor is needed once MUL/DIV are cut — nothing left to route through PCPI | No, it becomes entirely unused once MUL/DIV are cut, since PCPI only exists to route instructions to an external co-processor. |
| `BARREL_SHIFTER` | Cut, keep default off | Shift-heavy operations aren't the bottleneck for a traffic controller (that's data movement + branching). Area savings favored. | Not really a "replacement," more a fallback: the core's default `TWO_STAGE_SHIFT` mode already does shifts (just spread over ~2 cycles instead of one) — it's a slower path within the same core, not new hardware. |
| `TWO_CYCLE_COMPARE` / `TWO_CYCLE_ALU` | Cut, keep default off | Single-cycle preferred for lowest interrupt-response latency in a real-time controller — only worth enabling if synthesis timing closure fails on the target process | No replacement needed — cutting these just *keeps* the faster single-cycle default. There's nothing to substitute; we're declining an option that would have made things slower. |
| `LATCHED_MEM_RDATA` | Cut, keep default off | Only needed for specific external memory types that latch read data; no evidence this system needs it | No replacement needed — genuinely unused for this design, since the internal SRAM being used doesn't require that timing behavior |

#### Judgment calls worth flagging explicitly in your presentation (genuinely defensible either way)

| Parameter | My recommendation | The honest tradeoff |
| --- | --- | --- |
| `ENABLE_COUNTERS64` | Lean keep | 32-bit cycle counter alone wraps every ~1.5 min at 50 MHz — could corrupt timing measurements during your "long-duration stress testing" scenario. 64-bit avoids that for a small area cost. |
| `COMPRESSED_ISA` | Lean add (enable) | Smaller code = smaller memory footprint, which matters on a power/area-constrained edge chip. Cost: slightly more decode logic and marginal timing risk. Real design teams go back and forth on this. |
| `ENABLE_TRACE` | Add for verification builds | Very valuable for exactly what you're doing this week — but flag that it would likely be stripped for final tape-out to save area, so frame it as "on during verification, off/fused-out for production" |
| `REGS_INIT_ZERO` | Add for verification builds | Makes simulation deterministic and catches uninitialized-register bugs early — same "dev vs. production" framing as above |

## ADD

> The gap analysis (this is what the assignment is explicitly rewarding)
> 

Straight from the architectural fact we already confirmed in 1.1: **PicoSoC's stock SPI is a single-CS, read-only XIP flash controller — not a general-purpose SPI master.** Concretely, here's what needs to be added on top of the base repo:

1. **A general-purpose SPI master peripheral** — memory-mapped, byte-oriented read/write, with **3 independent chip-select outputs** (EEPROM, AI engine, wireless Tx). The existing `spimemio` engine stays only if you still need XIP boot-from-flash for the CPU's own program; otherwise it can be dropped entirely in favor of this new block.
2. **External IRQ lines — corrected after Task 4's block diagram.** Standard SPI EEPROMs have no interrupt pin at all (confirmed directly from the 25AA010A/25LC010A datasheet in 1.4 — the device is purely polled via the WIP status bit). So of the 4 peripheral blocks, only 3 actually generate interrupts: the AFE (data-ready), the AI Engine (status/anomaly-ready), and the Wireless Transmitter (done/ack). The stock `picosoc.v` already wires out exactly 3 external IRQ lines (`irq_5/6/7`), so **no widening of the IRQ port list is needed after all** — this is a smaller, cleaner conclusion than originally stated below.
3. **(Open question, not yet resolved)** — whether a small buffer/FIFO is needed between the AFE and the CPU, if sensor sampling is fast enough that byte-by-byte interrupt-driven copying could miss real-time deadlines. I don't have an actual data rate for the AFE from the assignment doc, so this should be stated as an explicit assumption or a direct question for the Ai Linear team, not asserted as fact.

## Assumptions & Ambiguities (to state explicitly in your deck)

- The assignment doesn't specify AFE sampling rate or required interrupt-response latency — the FIFO/buffering decision above depends on it.
- The assignment's "3-wire SPI" phrasing is inconsistent with standard 4-wire SPI (SCLK/MOSI/MISO/CS) — worth stating as an assumption (e.g., shared half-duplex data line) or raising directly with Ai Linear.
- I'm assuming the AI Processing Engine does not need PicoSoC to feed it live streaming data at CPU-cycle rates (i.e., it's request/response — "here's a coefficient block, signal me when done" — rather than needing a hardware DMA path). If that assumption is wrong, the ADD list would need a DMA controller too.

## Conclusion

**KEEP** — this is an interrupt-driven, real-time traffic controller, not a compute engine:

- `ENABLE_IRQ`, `ENABLE_IRQ_QREGS`, `ENABLE_IRQ_TIMER` — the entire system runs on interrupts (AFE data-ready, AI engine status/anomaly, wireless done); this is the mechanism PicoRV32 uses to implement that
- `CATCH_MISALIGN`, `CATCH_ILLINSN` — cheap hardware safety nets that convert firmware bugs into defined traps instead of silent corruption, directly useful during verification
- `ENABLE_REGS_16_31`, `ENABLE_REGS_DUALPORT` — full 32-register file with dual-port access, needed because firmware juggles four concurrent block transactions at once
- `ENABLE_COUNTERS` (lean also `ENABLE_COUNTERS64`) — cheap, and directly useful for measuring worst-case interrupt latency against the AFE's real-time requirement

**CUT** — the compute-heavy work lives elsewhere in the system, not on PicoSoC:

- `ENABLE_MUL` / `ENABLE_FAST_MUL` / `ENABLE_DIV` / `ENABLE_PCPI` — the AI math runs entirely in the separate AI Processing Engine block; PicoSoC only does address/index arithmetic, so hardware multiply/divide and the co-processor interface built to support it are unused silicon area and power on an ultra-low-power edge chip
- `BARREL_SHIFTER`, `TWO_CYCLE_COMPARE` / `TWO_CYCLE_ALU`, `LATCHED_MEM_RDATA` — none address this system's actual bottleneck (data movement, branching, interrupt latency), so default-off is favored for area unless synthesis timing closure later demands otherwise

**ADD** — the real gap between stock PicoSoC and what this application needs:

1. A general-purpose SPI master with **3 independent chip-select outputs** (EEPROM, AI Engine, Wireless Tx) — stock PicoSoC's only SPI interface is a single-CS, read-only, quad-SPI flash controller built for executing code from flash, not for general read/write transactions to multiple slave devices
2. *(Open item, stated as an assumption, not a certainty)* — a small buffer/FIFO between the AFE and CPU, only if AFE sampling rate turns out to exceed what interrupt-driven byte copying can keep up with; the assignment doesn't specify a data rate, so this is flagged as a question for the Ai Linear team rather than asserted as fact

**Not needed, despite first appearing that way:** widening PicoSoC's external interrupt lines. Standard SPI EEPROMs have no interrupt pin, so only 3 of the 4 peripheral blocks (AFE, AI Engine, Wireless Tx) generate interrupts — and the stock `picosoc.v` already exposes exactly 3 external IRQ lines. No change required there.

**Bottom line:** the customized PicoSoC keeps its full interrupt-handling and register-file capability, sheds hardware math it will never use, and needs exactly one meaningful architectural addition — a proper multi-device SPI master — to actually serve as this system's traffic controller.
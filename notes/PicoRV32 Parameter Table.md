# PicoRV32 Parameter Table

| Parameter | Our Decision | What it actually controls (the mechanism) |
| --- | --- | --- |
| `ENABLE_COUNTERS` | Keep | Turns on 3 opcodes (`RDCYCLE`, `RDTIME`, `RDINSTRET`) that let firmware read hardware performance counters. Off = executing these causes an illegal-instruction trap instead. |
| `ENABLE_COUNTERS64` | Keep | Sub-option of the above — controls whether the high-32-bit versions (`RDCYCLEH` etc.) exist for full 64-bit counters, vs only the low 32 bits. |
| `ENABLE_REGS_16_31` | Keep | Controls whether registers `x16`-`x31` physically exist in the register file at all. Off = only `x0`-`x15` exist (RV32E-style), smaller but more register pressure. |
| `ENABLE_REGS_DUALPORT` | Keep | Controls whether the register file can read **both** source operands (`rs1` and `rs2`) in the same cycle (dual-port, faster) or must read them one at a time (single-port, smaller). |
| `ENABLE_MUL` | Cut | Instantiates a real internal multiplier circuit implementing `MUL`/`MULH` opcodes. Off = those opcodes trap as illegal (then get emulated in software by the compiler's runtime library). |
| `ENABLE_FAST_MUL` | Cut | An alternative, bigger-but-faster multiplier circuit. If both this and `ENABLE_MUL` are on, this one silently wins and replaces the other. |
| `ENABLE_DIV` | Cut | Same idea as `ENABLE_MUL`, but for `DIV`/`REM` opcodes. |
| `ENABLE_PCPI` | Cut | Turns on the *external* co-processor wires (`pcpi_valid`, `pcpi_insn`, etc.) so an outside chip/module could handle custom instructions. Note: the internal mul/div cores above don't need this — only an *external* co-processor would. |
| `BARREL_SHIFTER` | Cut (default off) | An alternative shifter design that shifts by any number of bits in one step. Off = shifts happen iteratively instead (see `TWO_STAGE_SHIFT` below). |
| `TWO_STAGE_SHIFT` | Kept at default (on) | Controls *how* the iterative shifter works: shifts in one 4-bit chunk, then 1 bit at a time (faster, slightly bigger) vs. 1 bit at a time the whole way (smaller, slower). |
| `TWO_CYCLE_COMPARE` | Cut (default off) | Adds one extra clock-cycle of delay specifically to branch comparisons, in exchange for an easier physical-timing path during chip synthesis. |
| `TWO_CYCLE_ALU` | Cut (default off) | Same idea, but adds one extra cycle to **every** ALU-using instruction (not just branches) for the same timing-closure benefit. |
| `LATCHED_MEM_RDATA` | Cut (default off) | A timing *assumption* about the memory you connect: on = the external memory holds its output data steady after the transaction; off = PicoRV32 must capture/latch it internally in that exact cycle. |
| `COMPRESSED_ISA` | Judgment call — lean add | Turns on decoding for RISC-V's 16-bit "C" compressed instruction encodings — smaller compiled code, slightly more decode logic. |
| `CATCH_MISALIGN` | Keep | Turns on the actual detection circuit for unaligned memory accesses (e.g., a 4-byte load from an address not divisible by 4). Off = no such circuit exists; a misaligned access does something undefined instead of trapping. |
| `CATCH_ILLINSN` | Keep | Turns on the detection circuit for illegal/unrecognized opcodes. Off = `EBREAK` still traps, but *without* triggering IRQ1 the normal way — other illegal opcodes have undefined behavior. |
| `ENABLE_IRQ` | Keep | Master switch for the *entire* interrupt subsystem — the `custom0` opcode decoding, the external `irq[31:0]` input pins, all of it. Off = none of it exists, regardless of the sub-parameters below. |
| `ENABLE_IRQ_QREGS` | Keep | Sub-switch: on = builds the `getq`/`setq` opcodes + 4 hidden `q0`-`q3` registers. Off = the interrupt return address and IRQ bitmask are stored in ordinary registers `x3`(gp)/`x4`(tp) instead — no dedicated opcodes exist. |
| `ENABLE_IRQ_TIMER` | Keep | Sub-switch: on = builds the countdown-timer circuit and the `timer` opcode. Off = neither exists. |
| `ENABLE_TRACE` | Add (verification builds only) | Turns on 2 extra output wires (`trace_valid`, `trace_data`) that stream out exactly what the core does every cycle, purely for offline debugging — firmware never touches this. |
| `REGS_INIT_ZERO` | Add (verification builds only) | Controls whether the register file starts all-zero at time 0 (via a simulation `initial` block) vs. starting with unknown/random values like real silicon would. Makes simulation repeatable and catches "forgot to initialize" bugs. |
| `MASKED_IRQ` | Not yet discussed | A 32-bit bitmask, fixed at build time, that **permanently** disables specific IRQ lines — a hardwired lockout, not something software can change at runtime. |
| `LATCHED_IRQ` | Not yet discussed | A 32-bit bitmask controlling, per IRQ line, whether a brief pulse gets "remembered" as pending (edge-triggered) or the line must stay physically high to register (level-sensitive). |
| `PROGADDR_RESET` | Not yet discussed | The literal memory address the CPU jumps to on power-up — where your firmware's first instruction must live. |
| `PROGADDR_IRQ` | Not yet discussed | The fixed memory address the CPU jumps to whenever any interrupt fires — where your interrupt handler must live. |
| `STACKADDR` | Not yet discussed | The value auto-loaded into the stack pointer (`x2`) at reset, if set to something other than the default sentinel. |
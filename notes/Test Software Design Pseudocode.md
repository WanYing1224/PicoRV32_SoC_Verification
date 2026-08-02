# Test Software: Design/Pseudocode

# Shared Testbench Infrastructure Map

Going category by category and cataloging what each one actually needs, then consolidating to see what overlaps.

## What each category needs

| Category | Infrastructure Needed |
| --- | --- |
| A (Power/Reset) | Reset control, EEPROM model, AI Engine model, IRQ injection, cycle timing |
| B (Data Path) | EEPROM model (full protocol), AI Engine model (coefficient buffer), IRQ injection, cycle timing |
| C (Concurrency) | EEPROM model, AI Engine model, **Wireless Tx model (new)**, **the new SPI master itself**, randomized stimulus, `mem_ready` delay injection |
| D (Interrupts) | IRQ injection (multi-bit + mid-handler), cycle timing |
| E (Fault Handling) | EEPROM model, AI Engine model, firmware-level fault triggers (misaligned access, illegal opcode) |
| F (Stress/Perf) | Everything from C + B, combined — no new infra, just longer/combined runs |
| G (Self-generated) | Configurable SPI mode on all 3 models (G1), new watchdog stub (G2), pure observation of F1 (G3) |

## Consolidated — build these once, reuse everywhere

1. **EEPROM Behavioral Model:** By far the most reused piece (touches A, B, C, E, F, G). Must model the real facts we established: `WREN`/`WRDI`/`RDSR`/`WRSR`/`READ`/`WRITE` opcodes, `WEL` auto-clearing after every write (not just once), `WIP` timing up to 5ms, 16-byte page-boundary wraparound. Plus configurable knobs: "non-responsive" mode (for A2/E2), settable SPI mode (for G1), a write-counter (for F2), optional bit-corruption injection (for E3).
2. **AI Engine Model/Stub:** Second most reused (A, B, C, D, E, G). Needs: a coefficient receive buffer with byte-compare capability, a configurable ack delay, a controllable "done" status flag (for E1's underflow test), a "never respond" mode, and its own dedicated IRQ output.
3. **Wireless Tx Model/Stub: S**impler, needed by C, D, E, F, G. Just needs to accept a transaction and optionally assert done/ack, plus the same "never respond" and configurable-mode knobs as the others.
4. **IRQ Injection Harness:** Needed by A, B, D. Must support firing `irq_5/6/7` individually, **simultaneously in the same cycle** (D1), and critically, **mid-handler** (D2). Last one is the trickiest to build correctly, since it requires precise cycle-level control while another handler is actively running.
5. **Cycle-Accurate Timing Measurement:** Needed by A, B, D, F. Built directly on the `ENABLE_COUNTERS` hardware we kept in Task 3, or a simple testbench-side counter watching bus transactions.
6. **The New SPI Master (the actual DUT extension):** Needed by C, F, G. This is Task 3's proposed ADD, and it's the one piece that doesn't exist as a model or stub. It is real RTL we'd need to actually design. Given today's time budget, this is realistically pseudocode/behavioral-level today, not synthesizable RTL, unless it becomes one of our 1–2 implemented tests.
7. **`mem_ready` delay injection:** Narrow, just for C4, but easy to add once the SPI master interface exists.
8. **Randomized/constrained-random stimulus generator:** Just for C3/F1, sits on top of the 3 device models once they exist.

## What this tells us about build order

Build in this order: **EEPROM model → AI Engine model → IRQ harness** — those three alone unlock direct testing of Categories A, B, D, and E (11 of the 24 scenarios) without touching the new SPI master at all. **Wireless Tx model + the new SPI master** unlock C, F, and G on top of that.

This also sharpens the choice for step 1.3 (which 1–2 scenarios to actually implement): if we build the EEPROM model + IRQ harness first, we could realistically implement **B1** (EEPROM read/write, since the model IS the test) essentially for free, while still aiming for **C3 or D2** as the more impressive, architecture-proving second test.

---

# Pseudocode/Kkeleton Structure for Testbench

## **What's real and grounded:**

Every comment tagged with "REAL RULE" reflects a fact we verified directly from source this week — the EEPROM opcode table, WEL auto-clearing, page-boundary wraparound, and PicoRV32's actual non-preemptive `irq_active` gate. Those aren't guesses.

## **What's explicitly marked as not-yet-real:**

- `WRITE_CYCLES = 250000` is a placeholder — it represents "~5ms," but the actual cycle count depends on the clock frequency, which we don't have a firm number for yet. I flagged this in a comment rather than silently picking a number and presenting it as fact.
- The AI Engine model is built entirely on the assumption we flagged back in Task B2 — its real register map is undefined in the doc, so this is "the simplest model that satisfies every scenario touching it," not a guess at the real protocol.
- Anywhere you see `// TODO (Step 2, if implementing)` marks a spot where this is intentionally transaction-level pseudocode, not bit-level SPI shift-register logic — that gap gets closed only for whichever 1–2 scenarios we actually implement today.

## **The one piece worth flagging as genuinely tricky:**

`fire_mid_handler` in the IRQ harness (for D2) is the hardest thing in this whole file — it has to reach into the DUT and watch its internal `irq_active` signal directly, then time an injection precisely against it. That's real verification engineering, not a simple stimulus generator, and it's a strong thing to mention if D2 comes up in Q&A.

This structure directly unlocks Categories A, B, D, and E (11 scenarios) without touching the new SPI master at all.

---

# Choosing the 1–2 Scenarios to Actually Implement

Before locking this in, I want to flag something that changes the calculus from what I said earlier — worth being upfront about rather than quietly picking for you.

## The honest constraint: C3 needs RTL that doesn't exist yet

I'd earlier suggested C3 (SPI bus contention) as a strong candidate, since it directly proves Task 3's biggest architectural call. But C3 requires the **new general-purpose SPI master to exist as real, working RTL** — and right now that's only a conceptual proposal from Task 3, not a single line of actual hardware description. Implementing C3 "for real" today would mean *also* designing and debugging a new synthesizable peripheral from scratch, on top of everything else scheduled today. That's a realistic multi-day task on its own, not a same-day add-on.

## What's actually achievable today, using what already exists

- **D2 (non-preemption worst-case latency)** is genuinely achievable, and doesn't need any new RTL — it only needs the **real PicoRV32 core** (already cloned, already passing `make test`) plus simple test firmware with two interrupt handlers, driven by the `irq_test_harness.v` we already wrote. This tests real, existing hardware, not a stub.
- **B1 (EEPROM read/write), scoped down to a standalone unit test** is also achievable — testing `eeprom_model.v` in isolation against a small directed testbench (drive `sck`/`csb`/`si`, check `WEL`/`WIP`/page-wrap behavior), without needing it wired into the full CPU/SPI-master system yet.
- **A lighter option for C3, if you want the architectural story represented too:** we could write a small standalone arbitration-logic testbench — just the priority-decision logic in isolation (3 simultaneous requests in, correct priority order out), without the full physical SPI master around it. This wouldn't be "C3, fully implemented," but it would be real, working proof that the *core arbitration decision* behind Task 3's ADD is sound, which is honestly the part most likely to come up in Q&A anyway.

### Recommendation

Given the time available, I'd suggest: **D2 (using the real CPU) + the standalone EEPROM unit test (B1)**. That gives you two things that actually run in your existing WSL2/Icarus environment today, both grounded in real hardware or a real (if scoped) model — rather than starting a bigger RTL design task for C3 that's unlikely to finish today.

<aside>
✅ Select: D1+D2+B1 as committed, C3 as stretch

</aside>
# Procedure of Category D

> **Scenarios:** Interrupt handling and collisions
> 

This one turned up a genuinely important architectural fact I want to flag clearly before we get to the test plan.

## The real mechanism (verified directly against the RTL, not assumed)

I traced the actual interrupt logic in `picorv32.v`, and found something that matters a lot for this specific system:

- **PicoRV32 does not have a hardware priority encoder.** When multiple IRQ lines assert all of them simply get OR'd together into one 32-bit `irq_pending` register (`next_irq_pending = next_irq_pending | irq;`) even in the exact same clock cycle. The handler entry point receives the *entire* pending bitmask via `getq`, and it's **firmware's job**, not hardware's, to look at that bitmask and decide which bit to service first.
- **More importantly: interrupts are non-preemptive.** I confirmed this precisely **cannot interrupt it. E**ntry into a new interrupt handler is gated by `!irq_active` (line 1538), meaning **while one handler is running, a second interrupt — even from AFE, the highest-priority source.** It just sits latched as pending until the current handler executes `retirq` (which is the only place `irq_active` gets cleared back to 0).
- **Why this matters for this system specifically:** the doc says AFE must always be prioritized. But the hardware has no concept of "AFE always wins" — if the CPU happens to be inside the Wireless Tx or AI Engine handler when an AFE sample arrives, **that AFE interrupt waits**, full stop, regardless of priority, until the current handler finishes. The only way to actually guarantee AFE's real-time requirement is to keep every other interrupt handler short enough that its worst-case runtime never threatens the AFE deadline. That's not a software nicety — it's the *only* mechanism protecting the requirement, since the hardware won't do it for you.

## How to test this

- **Test D1 — Simultaneous-cycle collision:**
    - Assert two or more IRQ lines in the exact same clock cycle.
    - **Pass/fail:** the handler must see *all* asserted bits correctly in the returned bitmask (none silently dropped), and the firmware's own priority-resolution logic (checking AFE's bit first, regardless of bit position) must be verified to actually run in that order.
- **Test D2 — Non-preemption / worst-case handler latency (the real risk):**
    - While inside the *lowest*-priority handler (Wireless Tx), assert the AFE interrupt.
    - **Pass/fail:** measure exactly how long AFE waits (using the `ENABLE_COUNTERS` hardware), then confirm that maximum measured delay is still inside whatever real-time bound Task B3 established, even in this worst case.
- **Test D3 — Rapid-fire / back-to-back interrupts:**
    - Fire the same interrupt line repeatedly before its bit gets serviced.
    - **Pass/fail:** since `LATCHED_IRQ` defaults to all-1s (edge-latched), confirm a second pulse arriving before the first is cleared doesn't get lost. It should still show as pending.

#### Test Matrix — Category D rows

| ID | Scenario | Test Method | Stimulus & Setup | Expected Result | Pass/Fail Criteria | Priority |
| --- | --- | --- | --- | --- | --- | --- |
| D1 | Simultaneous IRQ collision | Directed test, same-cycle multi-assert | Assert AFE + AI Engine IRQ bits in the same clock cycle | Both bits appear in the pending bitmask; firmware services AFE first | No bit silently dropped; software priority order respected | High |
| D2 | Non-preemption worst-case latency | Directed test, nested-timing | Assert AFE while CPU is inside the Wireless Tx handler | AFE waits until `retirq`, then services immediately | Measured worst-case delay stays within the real-time bound from B3 | **Highest — this is the real risk in this system** |
| D3 | Rapid repeated interrupts | Directed test, repeated pulse injection | Fire same IRQ line twice before it's serviced | Second pulse remains latched, not lost | Pending bit still set after first pulse, before handler runs | Medium |

<aside>

#### **⚠️ This is worth saying explicitly in the room:**

D2 is arguably the single most important finding in the whole verification plan, on the same level as C3. It's not a hypothetical edge case — it's a direct consequence of how this specific CPU implements interrupts, and it means "keep every handler short" isn't just good practice here, it's the load-bearing assumption that makes the AFE's real-time guarantee actually true.

</aside>

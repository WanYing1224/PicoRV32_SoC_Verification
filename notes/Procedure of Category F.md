# Procedure of Category F

> **Scenarios:** Worst-case traffic conditions, Long-duration stress testing
> 

Unlike the other scenarios, these two aren't new mechanisms to test. They're about **combining and sustaining** everything already built in Categories B–E, which makes this a good one to end on.

## F1. Worst-case traffic conditions

- **What/why (plain):** All the individual "what if two things happen at once" tests (Category C) proved pairs of collisions work. This scenario asks the harder question: what if *everything* goes wrong-timed at the exact same moment — not just two devices, but AFE at its measured maximum rate, an EEPROM write in progress, an AI Engine transaction mid-flight, *and* Wireless Tx firing, all overlapping simultaneously?
- **This deliberately reuses, not reinvents:** the AFE ceiling rate from B3, the bus-contention arbitration logic from C3, and the interrupt non-preemption risk from D2 — combined into one comprehensive stress scenario instead of tested only in isolation.
- **How to test:** Run the C3 randomized-contention testbench, but with AFE driven at its B3-measured maximum rate throughout (rather than a moderate rate), for a sustained window. **Pass/fail:** the same priority guarantees from C3 and D2 must still hold even under this combined worst case — no new failure mode should appear just because multiple stresses are stacked together.

## F2. Long-duration stress testing

- **What/why (plain):** Some bugs only show up after running a very long time, not in a short test — things that slowly drift, wrap around, or wear out.
- **Two real, concrete numbers drive this one directly:**
    - **Counter wraparound** — this is exactly the risk we flagged back in Task 3's judgment call on `ENABLE_COUNTERS64`: a 32-bit cycle counter wraps roughly every ~1.5 minutes at 50MHz. A long-duration test is precisely where that would actually bite — any timing measurement (like the B3 latency checks) that assumes the counter never wraps would silently give wrong numbers in a sustained run.
    - **EEPROM endurance** — the real datasheet spec is 1,000,000 write cycles (1.4). A long-duration test should confirm firmware isn't wasting writes unnecessarily (e.g., rewriting unchanged config), since that write budget is a real, finite lifetime resource, not an abstract concern.**How to test:** Run a simulated extended-duration session (many simulated hours compressed via accelerated clock cycles) and specifically check: (1) do all interrupt/timing measurements remain correct across a 32-bit counter wraparound event, and (2) does the write pattern to EEPROM stay within a reasonable lifetime budget rather than writing redundantly.

## Test Matrix — Category F rows

| ID | Scenario | Test Method | Stimulus & Setup | Expected Result | Pass/Fail Criteria | Priority |
| --- | --- | --- | --- | --- | --- | --- |
| F1 | Worst-case traffic | Combined stress: C3's contention test + B3's max AFE rate, sustained | All 4 devices contending, AFE at measured ceiling, sustained over a long window | Same priority/arbitration guarantees as C3/D2 hold under combined load | No new failure mode appears only under combined stress | Highest — the ultimate integration check |
| F2 | Long-duration stress | Extended-duration sim, accelerated clock | Run past a 32-bit counter wraparound event; track cumulative EEPROM write count | Timing measurements stay correct across wraparound; write count stays within a reasonable lifetime budget | Zero timing corruption from counter rollover; no unnecessary EEPROM writes | Medium-high |
# Procedure of Category E

> **Scenarios:** Buffer overflow and underflow, Timeout handling, Communication failures
> 

This category directly verifies two of Task 3's KEEP decisions ( `ENABLE_IRQ_TIMER` and `CATCH_MISALIGN`/`CATCH_ILLINSN` ) the same way Category C verified the SPI master ADD and Category D verified the interrupt architecture.

## E1. Buffer overflow and underflow

- **What/why (plain):** If data arrives faster than PicoSoC can handle it, does it get silently lost or corrupted? And, if something tries to read data before it actually exists, does it get garbage without knowing it?
- **Honest connection to an open item:** This is exactly where Task 3's flagged-but-unresolved question comes back. We noted a possible need for a small FIFO between AFE and the CPU if sampling rate exceeds interrupt-driven throughput, but left it as an open assumption since the doc doesn't specify a data rate. **This scenario is literally the test that would resolve that open question.**
- **How to test:**
    - **Overflow: D**rive AFE samples faster than the measured worst-case service rate from B3, and check whether new data silently overwrites unread data (bad) or is properly flagged/dropped with a detectable indicator (acceptable, if documented).
    - **Underflow: H**ave firmware read the AI Engine's result register *before* its "done" status is actually set, and confirm this returns a clearly invalid/flagged value rather than plausible-looking garbage that could be mistaken for a real result.

## E2. Timeout handling

- **What/why (plain):** Every conversation PicoSoC has with another block (EEPROM write, AI Engine ack, Wireless Tx confirmation) could just... never finish. Something needs to notice and not wait forever.
- **Real mechanism (grounded, ties directly to a Task 3 KEEP):** this is exactly what `ENABLE_IRQ_TIMER` and the real `timer` instruction/countdown hardware are for. Concretely: firmware arms the timer for an expected worst-case duration right before starting a transaction (e.g., the EEPROM's documented 5ms max write cycle from 1.4), and if the timer IRQ fires before the expected "done" signal, that's a hard timeout, not a guess.
- **How to test:** Force each of the 3 external interfaces (EEPROM, AI Engine, Wireless Tx) to simply never complete, and confirm the timer-based timeout fires correctly for each, at the right bound, and triggers defined recovery rather than an indefinite hang.

## E3. Communication failures

- **What/why (plain):** Broader than a full hang. What if a device responds, but the response is just *wrong* (corrupted, garbled, or nonsensical)?
- **Two real, concrete hardware tests live here, directly verifying a Task 3 KEEP decision:**
    - **Misaligned access:** force a firmware bug that attempts a 4-byte access at an address not divisible by 4. Since we kept `CATCH_MISALIGN`, this should trap cleanly rather than silently doing something undefined.
    - **Illegal instruction:** force execution of an unimplemented/garbage opcode (simulating corrupted program flow). Since we kept `CATCH_ILLINSN`, this should trap cleanly too.
    - **Protocol-level corruption:** simulate a bit-flipped/garbled SPI response from a peripheral and confirm firmware has *some* sanity check (even a basic one, like a plausible-range check on status bytes) rather than blindly trusting whatever comes back.

## Test Matrix — Category E rows

| ID | Scenario | Test Method | Stimulus & Setup | Expected Result | Pass/Fail Criteria | Priority |
| --- | --- | --- | --- | --- | --- | --- |
| E1 | Buffer overflow/underflow | Rate-sweep + directed early-read test | AFE rate exceeds B3's measured ceiling; AI Engine result read before "done" | Overflow flagged/handled, not silently overwritten; underflow returns detectable invalid value | Zero silent data corruption in either direction | High |
| E2 | Timeout handling | Directed test, forced non-completion per interface | Force EEPROM/AI Engine/Wireless Tx to never complete, one at a time | Timer-based timeout fires at documented bound (e.g. 5ms for EEPROM), triggers recovery | No indefinite hang on any of the 3 interfaces | High |
| E3 | Communication failures | Directed fault injection | Misaligned access, illegal opcode, corrupted SPI response | `CATCH_MISALIGN`/`CATCH_ILLINSN` trap cleanly; corrupted data caught by sanity check | All 3 fault types detected, none silently accepted as valid | Medium-high |

<aside>
⚠️

#### **Worth noting out loud:**

This category is a good demonstration that the KEEP decisions from Task 3 weren't arbitrary — `ENABLE_IRQ_TIMER` and `CATCH_MISALIGN`/`CATCH_ILLINSN` are the literal mechanisms E2 and E3 depend on. If those parameters had been cut instead, this entire category would have no hardware safety net to test against.

</aside>
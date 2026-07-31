# Procedure of Category B

> **Scenarios:** EEPROM read/write verification, Downloading ML coefficients into the AI engine, Continuous sensor acquisition
> 

## B1. EEPROM read/write verification

- **What/why (plain):** We need to prove PicoSoC follows the filing cabinet's actual rules correctly — otherwise config or coefficients could get silently corrupted or misread.
- **Real facts driving this test (from 1.4):** `WREN` must be sent before **every single** write (not once — it auto-clears after each write), the chip has a 16-byte page boundary that wraps instead of rolling over, and writes take up to 5ms with `WIP` as the only way to know when they're done.
- **How to test:** Drive a simulated EEPROM model through: (1) a normal read, (2) a normal write-then-read-back, (3) an **intentional write attempt without `WREN` first** — this should be silently rejected, a classic real bug, (4) a write that straddles a 16-byte page boundary — verify it wraps within the page instead of continuing into the next one, (5) back-to-back writes without waiting for `WIP` to clear.

## B2. Downloading ML coefficients into the AI Engine

- **What/why (plain):** PicoSoC has to move the doctor's cheat sheet from the filing cabinet to the doctor, byte for byte, with nothing lost or garbled along the way — since a corrupted coefficient set means bad diagnoses later.
- **Honest assumption flag:** The AI Engine's actual register map/protocol for receiving coefficients is explicitly "outside the scope" per the doc — so we model it simply as "write a coefficient stream to a config register/FIFO" and state that as an assumption, not a fact.
- **How to test:** Pre-load a known coefficient pattern into the EEPROM model, run the full read-then-forward pipeline, and compare what the AI Engine model actually received against the original byte-for-byte. Also test an interrupted transfer (AI Engine delays its ack mid-stream) — it should stall/retry cleanly, not silently continue with a partial, corrupted set.

## B3. Continuous sensor acquisition

- **What/why (plain):** This is the stethoscope's constant stream — we need to prove PicoSoC never misses a sample, since this is the one link explicitly flagged as real-time priority.
- **Honest assumption flag:** The doc never states an actual AFE sample rate or latency requirement — so rather than guess a number and present it as fact, we test this as a **sweep**: start slow, increase the interrupt rate, and find the actual ceiling where drops start happening. That gives a real, defensible number to report instead of an assumption dressed up as a fact.
- **How to test:** Drive periodic AFE interrupts at increasing rates, measure worst-case interrupt-service latency using the `ENABLE_COUNTERS` hardware we kept in Task 3, and find the exact rate where the CPU can no longer service one sample before the next arrives.

## Test Matrix — Category B rows

| ID | Scenario | Test Method | Stimulus & Setup | Expected Result | Pass/Fail Criteria | Priority |
| --- | --- | --- | --- | --- | --- | --- |
| B1 | EEPROM read/write | Behavioral EEPROM model + directed tests | Normal read/write, write-without-WREN, page-boundary-straddling write, back-to-back writes | Correct data on valid ops; write silently rejected without WREN; page wraps correctly; WIP gates next op | All 4 sub-cases pass, including the 2 negative cases | High |
| B2 | ML coefficient download | Full-pipeline sim: EEPROM → PicoSoC → AI Engine model | Known coefficient pattern preloaded; also test delayed AI Engine ack | Byte-for-byte match at destination; graceful stall on delayed ack | Zero data corruption; no silent partial transfer | High |
| B3 | Continuous sensor acquisition | Interrupt-rate sweep + latency measurement | AFE IRQs fired at increasing rates, using `ENABLE_COUNTERS` for timing | Zero dropped samples up to a found ceiling rate | Documented max sustainable rate with zero drops | Highest (per doc) |

<aside>

#### **⚠️ One thing worth noticing across all three:**

Every single test here directly reuses infrastructure from earlier work. B1 needs the same EEPROM model Category A's brown-out test would also use, B2 depends on B1 working first (you can't verify coefficient download without trustworthy EEPROM reads), and B3 reuses the counter hardware we already justified keeping in Task 3. That's exactly the "shared work across categories" payoff.

</aside>

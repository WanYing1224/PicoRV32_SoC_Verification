# Procedure of Category A

> **Scenarios:** Power-up initialization, Startup and recovery, Reset recovery, Brown-out conditions, Sleep and wake-up transitions, Power management
> 

## A1. Power-up initialization

- **What/why (plain):** When the chip first turns on, it needs to wake up knowing nothing, and get itself ready to work — read its instructions, grab the AI settings from the filing cabinet, and tell the doctor to get ready.
- **How to test:** Simulate a cold power-on. Check that the very first instruction fetched is at address `0x0010_0000` (we confirmed this is where the CPU actually boots from — flash, not RAM). Check that the EEPROM read sequence, coefficient download to the AI Engine, and SPI master setup all complete, in order, within some maximum expected time. **Pass/fail:** system reaches "ready for normal operation" within a defined cycle-count budget, with no register left in a garbage/undefined state (this is exactly why we're adding `REGS_INIT_ZERO` for verification builds — it makes "did we forget to initialize something" bugs visible in simulation).

## A2. Startup and recovery

- **What/why (plain):** What happens if something *goes wrong* while waking up — like the filing cabinet doesn't answer, or the doctor doesn't respond to being turned on.
- **How to test:** Simulate the EEPROM or AI Engine simply not responding (no `WIP` clearing, no ack). **Pass/fail:** the system must detect the timeout and either retry or flag a clear startup-failure state — it must NOT hang forever, and must NOT silently continue with garbage coefficients.

## A3. Reset recovery

- **What/why (plain):** This is different from #1 — it's "what if the system resets in the *middle* of normal work," not just cold power-on.
- **How to test:** Force a reset while the system is mid-transaction (e.g., halfway through sending sensor data to the AI Engine). **Pass/fail:** the system must cleanly return to the exact same Power-Up/Init sequence as #1, from any prior state, with no corrupted leftover data or stuck interrupt flags.

## A4. Brown-out conditions

- **What/why (plain):** What if the power supply briefly dips (not a full outage, just a wobble) — could that corrupt something mid-write?
- **Honest flag:** PicoRV32 itself has **no built-in brown-out detection circuit** — that's normally a separate analog supervisor chip that asserts a hardware reset when voltage dips. So this scenario is really: "assuming an external supervisor forces a reset on brown-out, does our reset-recovery (#3) handle it cleanly?" This is worth stating explicitly as an assumption rather than claiming PicoSoC detects brown-outs itself.
- **How to test:** Same as #3, but specifically triggered mid-EEPROM-write, to check the EEPROM's own write-cycle isn't left in a half-finished state.

## A5. Sleep and wake-up transitions

- **What/why (plain):** When there's nothing to do, the chip should be able to "nap" to save power, and wake up instantly the moment something needs it.
- **Real mechanism (grounded from 1.2):** PicoRV32 has a real built-in instruction for exactly this — `waitirq`, which pauses the CPU until an interrupt arrives.
- **How to test:** Put the CPU into `waitirq`, then fire the AFE interrupt. **Pass/fail:** the CPU must wake and resume within a tight, defined cycle count — and critically, test the **race condition**: what if the interrupt arrives in the *exact same cycle* the CPU is entering sleep? It must not be missed.

## A6. Power management

- **What/why (plain):** This is the bigger-picture policy question — *when* should the system decide to nap versus stay awake, given it also has to coordinate the AFE, AI Engine, and Wireless Tx?
- **How to test:** Simulate a realistic duty cycle (mostly idle, occasional bursts of activity) and confirm the system actually enters sleep during idle periods rather than needlessly staying awake, without ever missing real-time AFE data.

## Table so far

| # | Scenario | Test Method | Pass/Fail Criteria |
| --- | --- | --- | --- |
| A1 | Power-up init | Cold-boot sim, check boot address + init sequence timing | Ready state reached within cycle budget, no undefined registers |
| A2 | Startup/recovery | Simulate non-responsive EEPROM/AI Engine | Timeout detected, no hang, no silent garbage data |
| A3 | Reset recovery | Force reset mid-transaction | Clean return to Init, no corrupted state |
| A4 | Brown-out | Reset mid-EEPROM-write (assumes external supervisor) | EEPROM write not left half-finished |
| A5 | Sleep/wake | `waitirq` then fire IRQ, including same-cycle race | Wake within tight cycle bound, no missed interrupt |
| A6 | Power management | Realistic duty-cycle simulation | Sleeps when idle, never misses real-time AFE data |

## State-Machine Diagram

![category_a_state_machine.svg](category_a_state_machine.svg)
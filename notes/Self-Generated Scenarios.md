# Self-Generated Scenarios

<aside>
🚩

Two genuinely new ones. Not re-labels of what's already folded into B1/C3/D1. Both came from a real gap-hunting question: "what could still go wrong that none of the 19 required scenarios actually cover?"

</aside>

## G1. SPI clock mode consistency across shared-bus devices

- **What/why (plain):** All three slave devices (EEPROM, AI Engine, Wireless Tx) share the *same physical clock line* on the new multi-CS SPI master. But nothing in the assignment or the architecture guarantees all three devices actually want the same clock behavior. We already flagged back in 1.3 that the Microchip EEPROM family typically supports SPI Mode (0,0) and (1,1), but the AI Engine and Wireless Tx's required SPI mode is never specified anywhere.
- **This is a real, previously-unstated assumption risk**, not a hypothetical: if the AI Engine actually needs a different clock mode than the EEPROM, and the master doesn't reconfigure `CPOL`/`CPHA` between transactions, data gets silently misread, SPI has no built-in error detection for a mode mismatch.
- **How to test:** Model each of the 3 devices with a specific expected SPI mode (potentially mismatched in the testbench on purpose), and verify the SPI master control logic correctly reconfigures mode before each transaction based on which chip-select is active. Include a negative case: an intentionally wrong-mode transaction should produce a detectably corrupted result, so we know it's actually being checked rather than passing by coincidence.

## G2. Firmware hang recovery (watchdog)

- **What/why (plain):** Category E's timeout scenario (E2) covers *peripherals* not responding. But what if the bug is in **PicoSoC's own firmware. A** logic error causing an infinite loop, with no peripheral even being waited on? Nothing in PicoRV32 or the stock PicoSoC design catches this class of failure at all.
- **This surfaces a second real architectural gap**, the same way Category C surfaced the need for the multi-CS SPI master.
- **Proposal:** Add a dedicated watchdog timer peripheral (separate from PicoRV32's built-in `ENABLE_IRQ_TIMER`, which only counts down for interrupt scheduling, not hang detection) — firmware must periodically "kick" it in the main loop, and if it's not kicked within a bound, it forces a hardware reset.
- **How to test:** Simulate a firmware hang (stub the main loop to spin without kicking the watchdog) and confirm the watchdog forces a reset within its configured window, then confirm the system cleanly re-enters the exact same Power-Up/Init state from the Category A diagram, proving recovery is clean, not just that a reset happened.

## G3. Register file capacity under load

- **What/why (plain):** Back in Task 3, we kept the full 32-register file (`ENABLE_REGS_16_31`) and dual-port reads (`ENABLE_REGS_DUALPORT`) instead of the smaller 16-register option, specifically because firmware juggles multiple simultaneous transaction states at once (AFE, EEPROM, AI Engine, Wireless Tx). That's a real, testable engineering claim, not just a design opinion, and right now nothing actually checks whether it's true.
- **This closes a real gap in our own reasoning, the same way G1 and G2 closed gaps in the architecture:** every other Task 3 KEEP/CUT decision has a matrix row backing it up (interrupts have D1-D3, CATCH_MISALIGN/ILLINSN have E3, counters have F2) except this one. If someone asks "how did you verify you actually need all 32 registers," the honest answer right now would be "we reasoned it out but never checked," and this scenario fixes that.
- **How to test:** Reuse F1's combined worst-case stress scenario (all 4 devices contending, AFE at its measured maximum rate) rather than building new test infrastructure, since the traffic pattern needed is identical, we're just watching a different signal this time. While that stress runs, monitor register file utilization and spilling behavior.
- **Pass/fail:** if register pressure genuinely spikes under this combined worst-case load, that's direct evidence the full 32-register, dual-port file is actually necessary, proving the Task 3 KEEP decision instead of just asserting it.

## Test Matrix — Self-Generated rows

| ID | Scenario | Test Method | Stimulus & Setup | Expected Result | Pass/Fail Criteria | Priority |
| --- | --- | --- | --- | --- | --- | --- |
| G1 | SPI clock mode consistency | Directed test, mismatched-mode injection | Model 3 devices with distinct expected SPI modes; include an intentional mismatch case | Master reconfigures mode per-device correctly; mismatch produces detectable corruption | No silent misread from an unhandled mode mismatch | Medium — real risk, currently unstated assumption |
| G2 | Firmware hang / watchdog recovery | Directed test, simulated firmware hang | Stub main loop to spin without kicking a proposed watchdog | Watchdog forces reset within bound; system re-enters Power-Up/Init cleanly | Reset triggers within window; recovery is clean (ties to Category A state machine) | High — proposes closing a real gap, similar to Task 3's SPI master finding |
| G3 | Register file capacity under load (verifies Task 3 KEEP) | Reuse F1's stress scenario, monitor register spilling | Run F1's combined worst-case traffic while all 4 transaction contexts stay concurrently active | Full 32-reg/dual-port file avoids excessive spilling under load | Quantified spill count supports the Task 3 KEEP justification | Medium — closes the one Task 3 KEEP decision without direct test coverage until now |

<aside>
🚩

Both of these are good material for the presentation specifically *because* they're not just checkbox completion.G1 catches an unstated assumption, and G2 identifies a second real architectural gap the same way the SPI master did in Task 3.

</aside>
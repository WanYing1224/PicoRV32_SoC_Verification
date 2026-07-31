# Procedure of Category C

> **Scenarios:** Simultaneous sensor acquisition and EEPROM access, Simultaneous wireless transmission and sensor acquisition, SPI bus contention, Wait-state analysis
> 

<aside>
⚠️ This category exists specifically to stress-test Task 3's biggest architectural call — the new multi-CS SPI master. Every scenario here asks some version of "with one master and one bus, but four devices that all want attention, does the traffic controller actually control traffic?”

</aside>

## C1. Simultaneous sensor acquisition and EEPROM access

- **What/why (plain):** What happens if PicoSoC is mid-conversation with the filing cabinet exactly when the stethoscope needs her attention?
- **A real nuance worth knowing cold:** the EEPROM's 5ms write isn't actually a 5ms *bus* block — per the datasheet, that 5ms is the EEPROM's **internal** self-timed write cycle, which happens *after* the write command is clocked in. `CS` can be released during that internal write, freeing the SPI bus for other traffic. So the real risk isn't "the bus is stuck for 5ms" — it's whether the firmware **polls `WIP` in a tight busy-wait loop** that hogs the bus anyway, even though it doesn't strictly need to.
- **How to test:** Fire an AFE interrupt while an EEPROM write is in its internal 5ms window. **Pass/fail:** the AFE sample must be serviced promptly, and the firmware's `WIP`-polling pattern must not itself be the thing blocking it.

## C2. Simultaneous wireless transmission and sensor acquisition

- **What/why (plain):** When there's an anomaly to report, does sending that alert ever cause a dropped heartbeat reading?
- **How to test:** Trigger a Wireless Tx transaction at the exact moment an AFE sample is due. **Pass/fail:** since Wireless Tx is explicitly the lowest-priority link (Task 4), it must yield — the AFE sample must never be delayed or dropped because of it.

## C3. SPI bus contention

- **What/why (plain):** The general, worst-case version of C1/C2 — what if *all four* devices want service in the same narrow window, not just two?
- **How to test:** Generate randomized, overlapping service requests from all sources simultaneously. **Pass/fail:** the firmware's arbitration must always honor the priority order (AFE highest, EEPROM lowest) and no request may be silently dropped or starved indefinitely, even under sustained worst-case overlap.

## C4. Wait-state analysis

- **What/why (plain):** This one's different — it's not about *who* goes first, it's about a lower-level circuit question: when PicoSoC asks the new SPI master peripheral to do something, does the CPU correctly *wait* for it to actually finish, instead of barreling ahead with garbage data?
- **Real mechanism:** this is the `mem_valid`/`mem_ready` handshake we mapped in the datapath diagram — the CPU is supposed to stall until the addressed peripheral asserts `mem_ready`.
- **How to test:** Artificially delay the new SPI master's `mem_ready` response across a range (0 cycles, a few cycles, a pathologically long but bounded delay). **Pass/fail:** the CPU must hold correctly for every delay length and only latch data the exact cycle `mem_ready` fires — never early, never with stale data.

## Test Matrix — Category C rows

| ID | Scenario | Test Method | Stimulus & Setup | Expected Result | Pass/Fail Criteria | Priority |
| --- | --- | --- | --- | --- | --- | --- |
| C1 | Sim. AFE + EEPROM access | Directed test, timed interrupt injection | Fire AFE IRQ during EEPROM's internal 5ms write window | AFE serviced promptly; WIP-polling doesn't block it | AFE latency stays within bound regardless of EEPROM write in progress | High |
| C2 | Sim. Wireless Tx + AFE | Directed test, timed interrupt injection | Trigger Wireless Tx exactly when AFE sample is due | Wireless Tx yields; AFE sample unaffected | Zero AFE sample loss/delay caused by Tx activity | High |
| C3 | SPI bus contention | Randomized/constrained-random stimulus | All 4 devices request service in overlapping windows, repeated across many trials | Priority order always honored, no starvation | No dropped or indefinitely-delayed request across all trials | Highest — this is the direct test of Task 3's ADD |
| C4 | Wait-state analysis | Directed test, `mem_ready` delay injection | Sweep `mem_ready` delay from 0 to a large bounded value | CPU stalls correctly every time, latches only on `mem_ready` | No early latch, no data corruption, at every delay value tested | Medium-high |

<aside>

#### **⚠️ Worth saying out loud in the presentation:**

C3 is arguably the single most important scenario in the entire verification plan, because it's the one that either validates or invalidates the biggest architectural decision from Task 3. If this one passes, the SPI master addition is proven correct; if it doesn't, that's exactly the kind of finding that would send you back to revise the architecture.

</aside>

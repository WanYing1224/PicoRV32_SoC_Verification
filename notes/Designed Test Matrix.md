# Designed Test Matrix

## Category A: Power / Reset / Lifecycle

| ID | Category | Description | Test Method | Stimulus & Setup | Expected Result | Pass/Fail Criteria | Priority |
| --- | --- | --- | --- | --- | --- | --- | --- |
| A1 | Power/Reset | Power-up initialization | Cold-boot simulation | Cold power-on from time 0; check boot address + init timing | Reaches "ready" state within cycle budget | No undefined registers, budget met | High |
| A2 | Power/Reset | Startup and recovery | Directed fault injection | Simulate non-responsive EEPROM/AI Engine during init | Timeout detected, clean failure state | No hang, no silent garbage data | High |
| A3 | Power/Reset | Reset recovery | Directed test | Force reset mid-transaction | Clean return to Init state | No corrupted leftover state | High |
| A4 | Power/Reset | Brown-out conditions | Directed test | Force reset mid-EEPROM-write (assumes external supervisor) | EEPROM write not left half-finished | Clean recovery via same reset path as A3 | Medium |
| A5 | Power/Reset | Sleep and wake-up | Directed test, same-cycle race case | `waitirq`, then fire AFE IRQ (incl. same-cycle) | Wakes within tight cycle bound | No missed interrupt, even in race case | High |
| A6 | Power/Reset | Power management | Duty-cycle simulation | Realistic idle/burst pattern | Sleeps when idle, wakes for real-time data | Never misses AFE data | Medium |

## Category B: Data Path & Communication

| ID | Category | Description | Test Method | Stimulus & Setup | Expected Result | Pass/Fail Criteria | Priority |
| --- | --- | --- | --- | --- | --- | --- | --- |
| B1 | Data Path | EEPROM read/write verification | Behavioral model + directed tests | Normal ops, write-without-WREN, page-boundary write, back-to-back writes | Correct data; invalid ops rejected/handled | All 4 sub-cases pass, incl. 2 negative cases | High |
| B2 | Data Path | ML coefficient download | Full-pipeline simulation | Known pattern preloaded; delayed AI Engine ack tested | Byte-for-byte match; graceful stall on delay | Zero corruption, no silent partial transfer | High |
| B3 | Data Path | Continuous sensor acquisition | Interrupt-rate sweep | AFE IRQs at increasing rates, `ENABLE_COUNTERS` timing | Zero drops up to a found ceiling | Documented max rate with zero drops | Highest |

## Category C: Concurrency & Bus Arbitration

| ID | Category | Description | Test Method | Stimulus & Setup | Expected Result | Pass/Fail Criteria | Priority |
| --- | --- | --- | --- | --- | --- | --- | --- |
| C1 | Concurrency | Sim. AFE + EEPROM access | Directed, timed injection | AFE IRQ during EEPROM's internal 5ms write window | AFE serviced promptly | Latency bound held regardless of EEPROM write | High |
| C2 | Concurrency | Sim. Wireless Tx + AFE | Directed, timed injection | Trigger Tx exactly when AFE sample is due | Tx yields, AFE unaffected | Zero AFE loss/delay from Tx activity | High |
| C3 | Concurrency | SPI bus contention | Randomized/constrained-random | All 4 devices request service, overlapping, many trials | Priority order honored, no starvation | No dropped/delayed request across all trials | Highest |
| C4 | Concurrency | Wait-state analysis | Directed, `mem_ready` delay sweep | Sweep delay from 0 to large bounded value | CPU stalls correctly, latches only on ready | No early latch, no corruption at any delay | Medium-high |

## Category D: Interrupt Handling and Collisions

| ID | Category | Description | Test Method | Stimulus & Setup | Expected Result | Pass/Fail Criteria | Priority |
| --- | --- | --- | --- | --- | --- | --- | --- |
| D1 | Interrupts | Simultaneous IRQ collision | Directed, same-cycle multi-assert | Assert AFE + AI Engine bits same cycle | Both bits appear; AFE serviced first | No dropped bit, correct software priority | High |
| D2 | Interrupts | Non-preemption worst-case latency | Directed, nested-timing | Assert AFE during Wireless Tx handler | AFE waits, then services on `retirq` | Delay stays within B3's real-time bound | Highest |
| D3 | Interrupts | Rapid repeated interrupts | Directed, repeated pulse | Fire same line twice before serviced | Second pulse remains latched | Pending bit not lost | Medium |

## Category E: Fault / Error Handling

| ID | Category | Description | Test Method | Stimulus & Setup | Expected Result | Pass/Fail Criteria | Priority |
| --- | --- | --- | --- | --- | --- | --- | --- |
| E1 | Fault Handling | Buffer overflow/underflow | Rate-sweep + directed early-read | AFE past B3 ceiling; AI Engine read before "done" | Overflow flagged; underflow returns invalid marker | Zero silent corruption either direction | High |
| E2 | Fault Handling | Timeout handling | Directed, forced non-completion | Force each of 3 interfaces to never complete | Timer IRQ fires at documented bound | No indefinite hang on any interface | High |
| E3 | Fault Handling | Communication failures | Directed fault injection | Misaligned access, **MUL/DIV illegal opcode (verifies Task 3 CUT)**, corrupted SPI response | Traps fire cleanly; corruption caught | All 3 fault types detected, none accepted | Medium-high |

## Category F: Stress & Performance

| ID | Category | Description | Test Method | Stimulus & Setup | Expected Result | Pass/Fail Criteria | Priority |
| --- | --- | --- | --- | --- | --- | --- | --- |
| F1 | Stress/Perf | Worst-case traffic | Combined stress (C3 + B3 ceiling) | All 4 devices contending at AFE's max rate, sustained | Same guarantees as C3/D2 hold | No new failure mode under combined load | Highest |
| F2 | Stress/Perf | Long-duration stress | Extended-duration, accelerated clock | Run past 32-bit counter wraparound; track EEPROM write count | Timing stays correct; writes stay in budget | Zero corruption from rollover, no wasted writes | Medium-high |

## Self-Generated Scenarios

| ID | Category | Description | Test Method | Stimulus & Setup | Expected Result | Pass/Fail Criteria | Priority |
| --- | --- | --- | --- | --- | --- | --- | --- |
| G1 | Self-Generated | SPI clock mode consistency | Directed, mismatched-mode injection | 3 devices with distinct expected SPI modes | Master reconfigures mode per-device | No silent misread from mode mismatch | Medium |
| G2 | Self-Generated | Firmware hang / watchdog recovery | Directed, simulated hang | Stub main loop to spin, no watchdog kick | Reset forced within bound, clean re-init | Reset triggers on time, recovery is clean | High |
| G3 | Self-Generated | Register file capacity under load (verifies Task 3 KEEP) | Reuse F1's stress scenario, monitor register spilling | Run F1's combined worst-case traffic while all 4 transaction contexts stay concurrently active | Full 32-reg/dual-port file avoids excessive spilling under load | Quantified spill count supports the Task 3 KEEP justification | Medium |
# Consolidate the Assumptions List

> Pulling together every assumption flagged across the week into one clean, presentation-ready list, organized by category.
> 

## Protocol / Interface Assumptions

| # | Assumption | Where It Came From | Risk If Wrong |
| --- | --- | --- | --- |
| 1 | The system truly uses a standard 4 wire SPI (SCLK, MOSI, MISO, CS), despite the assignment's literal wording of "3 wire SPI" | Task 3 architecture review | If actually 3 wire (shared MOSI/MISO), the SPI master design needs a half duplex data line instead of separate MOSI/MISO |
| 2 | The AI Engine and Wireless Transmitter's required SPI clock mode (CPOL/CPHA) is unstated in the assignment; only the EEPROM's real datasheet confirms Mode 0,0 or 1,1 | Flagged in 1.3, became self generated scenario G1 | If AI Engine or Wireless Tx need a different mode than the EEPROM, the shared bus master must reconfigure mode per transaction or data gets silently misread |
| 3 | The AI Engine's actual register map and command protocol are undefined in the assignment; modeled as the simplest interface satisfying init, coefficient load, status read, and result read | Task B2, [ai_engine_model.v](/testbench/ai_engine_model.v) | The real protocol could require additional registers, different timing, or a different transaction sequence entirely |
| 4 | Wireless Transmitter may provide a done or acknowledge interrupt after transmission; this is not explicitly stated in the assignment | Task 4 block diagram | If no such line exists, PicoSoC would need to poll instead, changing its verification scenario |

## Architecture / Design Assumptions

| # | Assumption | Where It Came From | Risk If Wrong |
| --- | --- | --- | --- |
| 5 | The AI Processing Engine does not require PicoSoC to stream live sensor data at CPU cycle rates; assumed to be request/response rather than continuous DMA style transfer | Task 3 ADD analysis | If streaming at high rate is actually required, the ADD list would need a DMA controller, not just a general purpose SPI master |
| 6 | A small buffer or FIFO between the AFE and CPU may or may not be needed, depending on the AFE's actual sampling rate, which the assignment does not specify | Task 3 ADD analysis, tested empirically in B3 as a rate sweep rather than assumed | If the real AFE rate exceeds what we measured as the safe ceiling, a hardware FIFO becomes a required addition, not optional |
| 7 | Brown out conditions are detected by an external supervisor chip, not by PicoRV32 itself, since the core has no on chip brown out detection circuitry | Category A verification design | If Ai Linear expects on chip brown out detection, this would require an entirely different, currently unplanned circuit |
| 8 | PicoSoC is the sole SPI bus master; no multi master arbitration is designed or tested | Task 3 and 4 architecture | If any other device can also initiate SPI transactions, real bus arbitration logic would be required |

## Verification / Test Infrastructure Assumptions

| # | Assumption | Where It Came From | Risk If Wrong |
| --- | --- | --- | --- |
| 9 | The EEPROM's real timing constant (5ms max write cycle) is currently a placeholder cycle count in our test models, since the actual target clock frequency for the final chip is not yet known | [eeprom_model.v](/testbench/eeprom_model.v) | The placeholder must be recalculated once a real clock frequency is confirmed, or timeout based tests could pass or fail incorrectly in simulation |
| 10 | Our EEPROM behavioral model is based on the 25AA010A or 25LC010A part (inferred from the document number in the assignment's own datasheet link), not an explicit part number stated in the assignment text | 1.4 SPI/EEPROM analysis | Well grounded, but technically an inference; if a different EEPROM part is actually used, opcodes and timing may differ slightly |

**10 assumptions total**, organized into 3 categories. Each one is something we deliberately chose to state rather than quietly build around, which is exactly what this deliverable is meant to demonstrate.
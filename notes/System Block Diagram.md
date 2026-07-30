# System Block Diagram

<aside>
🎯

**Topology confirmed from the assignment doc:** this is a **star topology** — PicoSoC is explicitly "the central embedded traffic controller." All 4 other blocks connect only THROUGH PicoSoC, never directly to each other.

</aside>

## Rendered Diagram

![system_block_diagram.svg](/diagram/system_block_diagram.svg)

## Zoom Levels: System → SoC → CPU Core

![architecture_zoom_levels.svg](/diagram/architecture_zoom_levels.svg)

## Data Paths (direction, interface, priority)

| Link | Direction | Interface | What flows | Priority |
| --- | --- | --- | --- | --- |
| AFE ↔ PicoSoC | AFE → PicoSoC | Shared SPI + dedicated data-ready IRQ | Periodic digitized sensor samples | Highest — doc explicitly requires this be prioritized (real-time source) |
| PicoSoC ↔ EEPROM | Mostly PicoSoC ← EEPROM (reads) | SPI only, no IRQ (standard EEPROMs have no interrupt pin — confirmed in 1.4, polled via RDSR/WIP) | Config, ML coefficients, calibration data | Low — mostly one time at startup |
| PicoSoC ↔ AI Engine | Bidirectional (heaviest link) | Shared SPI + dedicated status/anomaly IRQ | Init, coefficient download, config writes, relayed sensor data, status reads, anomaly results | Medium-high — must respond promptly to its IRQ |
| PicoSoC → Wireless Tx | PicoSoC → Tx only | Shared SPI (+ optional done/ack IRQ) | Anomaly report + system status | Low — event-triggered only, on anomaly |

### PicoRV32 Datapath (Zoom 1 — what's inside the CPU core box)

![picorv32_datapath.svg](/diagram/picorv32_datapath.svg)

- **Solid lines** = shared SPI bus (PicoSoC is the sole master; only one device is ever "hot" per transaction)
- **Dashed lines** = dedicated interrupt (GPIO) line, separate from the SPI bus itself

<aside>
✅

**Corrected finding (consistent with the Architecture Evaluation page):** only 3 of the 4 peripheral blocks actually generate interrupts — AFE, AI Engine, and Wireless Tx. The EEPROM has no interrupt pin at all (standard for SPI EEPROMs) and is purely polled. The stock `picosoc.v` already exposes exactly 3 external IRQ lines (`irq_5/6/7`), which lines up with what this system actually needs — no widening required.

</aside>

## Instruction Execution, Stage by Stage (sequential, not pipelined)

![picorv32_stage_by_stage.svg](/diagram/picorv32_stage_by_stage.svg)
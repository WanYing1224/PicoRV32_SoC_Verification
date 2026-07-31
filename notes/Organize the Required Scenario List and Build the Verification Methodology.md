# Organize the Required Scenario List and Build the Verification Methodology

## The 19 Required Scenarios, Grouped into Logical Categories

I've organized these into 6 categories based on what's actually being tested, and noted where our existing work already gives us concrete facts to build on for each one.

### Category A: Power / Reset / Lifecycle (6 scenarios)

[Procedure of Category A](Procedure of Category A.md)

- Power-up initialization
- Startup and recovery
- Reset recovery
- Brown-out conditions
- Sleep and wake-up transitions
- Power management

**Already established:** `PROGADDR_RESET` boots from flash at `0x0010_0000` (not RAM), via the multi-cycle FSM we mapped out. **This entire category maps directly onto this afternoon's state-machine diagram** — every scenario here is a state transition (Reset → Init → Normal Op → Sleep → Wake, etc.).

### Category B: Data Path & Communication (3 scenarios)

[Procedure of Category B](Procedure of Category B.md)

- EEPROM read/write verification
- Downloading ML coefficients into the AI engine
- Continuous sensor acquisition

**Already established:** The real EEPROM (Electrically Erasable Programmable Read-Only Memory) instruction set (`WREN`/`WRDI`/`RDSR`/`WRSR`/`READ`/`WRITE`), the WEL-must-be-set-before-every-write rule, 16-byte page size, 5ms max write cycle — all from the real datasheet (1.4). The AI Engine transaction list (init, coefficient download, config, status, results) from the Task 4 block diagram.

### Category C: Concurrency & Bus Arbitration (4 scenarios)

[Procedure of Category C](Procedure of Category C.md)

- Simultaneous sensor acquisition and EEPROM access
- Simultaneous wireless transmission and sensor acquisition
- SPI bus contention
- Wait-state analysis

**Already established:** This category is the direct verification target for Task 3's "ADD" finding — the new multi-CS SPI master. These scenarios exist specifically *because* one master now serves three devices on a shared bus; this is where that architectural decision gets proven correct (or found lacking).

### Category D: Interrupt Handling (1 scenario, kept separate — too central to bury)

[Procedure of Category D](Procedure of Category D.md)

- Interrupt handling and collisions

**Already established:** `ENABLE_IRQ`/`IRQ_QREGS`/`IRQ_TIMER` (Task 3 KEEP decisions), the 3 external IRQ lines (`irq_5/6/7`) mapped to AFE/AI Engine/Wireless Tx (Task 4's corrected finding), and PicoRV32's actual custom instructions (`getq`/`setq`/`retirq`/`maskirq`/`waitirq`) from 1.2.

### Category E: Fault / Error Handling (3 scenarios)

[Procedure of Category E](Procedure of Category E.md)

- Buffer overflow and underflow
- Timeout handling
- Communication failures

**Already established:** `CATCH_MISALIGN`/`CATCH_ILLINSN` (Task 3 KEEP). The EEPROM's 16-byte page-boundary wraparound behavior (1.4) is a real, concrete case for "buffer overflow" — and a strong candidate for one of our self-generated scenarios in step 4.

### Category F: Stress & Performance (2 scenarios)

[Procedure of Category F](Procedure of Category F.md)

- Worst-case traffic conditions
- Long-duration stress testing

**Already established:** `ENABLE_COUNTERS`/`COUNTERS64` (Task 3 KEEP, for measuring timing) and the EEPROM's 1,000,000-cycle endurance limit (1.4) — a real, citable bound for what "long-duration" should mean here.
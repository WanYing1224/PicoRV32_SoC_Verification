# Environment Setup and Results

## Setup Plan: Everything Runs Inside WSL2 Ubuntu

Quick reasoning before the steps: PicoRV32's own Makefile and testbenches are built around **Icarus Verilog**, not ModelSim. Rewriting the build system to target ModelSim would mean hand-converting the Makefile/testbench flow, which burns time you don't have this week.

Since you already have WSL2 Ubuntu, the far faster path is:

- Do everything Linux-native inside WSL2 (git, Icarus, RISC-V toolchain)
- Point your existing VS Code at it via the WSL Remote extension

**ModelSim stays available as an option later** if you want its GUI for a custom testbench you write yourself — I'll note where that fits in.

**One assumption I'm making:** your WSL2 Ubuntu is a reasonably recent release (20.04 or newer). If `lsb_release -a` shows something older, flag it and I'll adjust the package names.

---

## Installing Steps

### Step 1 — Open a WSL2 Ubuntu terminal and update packages

Open Windows Terminal (or run `wsl` from PowerShell/cmd) to get into your Ubuntu shell, then:

```bash
sudo apt update && sudo apt upgrade -y
```

### Step 2 — Clone the PicoRV32 repo (inside the Linux filesystem, not `/mnt/c/...`)

This matters: cloning into `/mnt/c/Users/...` (the Windows-mounted drive) makes every file operation cross the WSL2/Windows boundary, which is noticeably slower and can cause flaky build behavior. Keep it in your native Linux home directory instead.

```bash
mkdir -p ~/picosoc_projects
cd ~/picosoc_projects
git clone https://github.com/YosysHQ/picorv32.git
cd picorv32
```

### Step 3 — Install Icarus Verilog

```bash
sudo apt install -y iverilog
iverilog -V
```

Check the version output. The PicoRV32 README carries an old warning that Icarus **0.9.7** has bugs that break its testbench, and recommends building from GitHub master if you hit that. Recent Ubuntu releases package a much newer Icarus (11.x/12.x), so `apt install` should already be fine — just don't be surprised if `make test` complains and it turns out you're stuck on 0.9.7.

If that happens:

```bash
# Fallback: build Icarus from source (only if apt version is 0.9.7 or make test misbehaves)
sudo apt install -y build-essential autoconf gperf flex bison
git clone https://github.com/steveicarus/iverilog.git ~/projects/iverilog-src
cd ~/picosoc_projects/iverilog-src
sh autoconf.sh
./configure
make -j$(nproc)
sudo make install
cd ~/picosoc_projects/picorv32
```

### Step 4 — Install the RISC-V GNU toolchain

Try the prebuilt Ubuntu package first — it's much faster than building from source:

```bash
sudo apt install -y gcc-riscv64-unknown-elf
riscv64-unknown-elf-gcc --version
```

If that package isn't available on your Ubuntu version (`apt` will just say it can't find it), fall back to building it yourself — this takes longer (~20-30 min) but is the officially documented path:

```bash
sudo apt install -y autoconf automake autotools-dev curl python3 python3-pip \
    libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo \
    gperf libtool patchutils bc zlib1g-dev libexpat-dev ninja-build

git clone https://github.com/riscv/riscv-gnu-toolchain ~/picosoc_projects/riscv-gnu-toolchain
cd ~/picosoc_projects/riscv-gnu-toolchain
./configure --prefix=/opt/riscv --with-arch=rv32i --with-abi=ilp32
sudo make -j$(nproc)
echo 'export PATH=/opt/riscv/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
cd ~/picosoc_projects/picorv32
```

### Step 5 — Install Verilator + GTKWave (optional but recommended)

Verilator gives you a second, much faster simulator for later regression/coverage work, and GTKWave is the standard free waveform viewer that pairs with Icarus's VCD output.

```bash
sudo apt install -y verilator gtkwave
```

### Step 6 — Verify everything works: run the repo's own test suite

```bash
cd ~/picosoc_projects/picorv32
make test
```

This compiles the firmware with the RISC-V toolchain, simulates it with Icarus, and should finish with something like `ALL TESTS PASSED`.

**This is your checkpoint** — if this doesn't pass cleanly, something in Steps 3-4 needs fixing before you start customizing anything.

Optional: see a waveform to confirm your whole toolchain (including GTKWave) works end to end:

```bash
make test_vcd
gtkwave testbench.vcd &
```

### Step 7 — Point VS Code at this WSL2 environment

1. In VS Code, install the **"WSL"** extension (by Microsoft) if it's not already there.
2. From your WSL2 terminal, just run:
This opens VS Code connected directly to your WSL2 filesystem — you get your normal VS Code UI, but all terminal commands, file paths, and extensions run in Linux.
    
    ```bash
    cd ~/picosoc_projects/picorv32
    code .
    ```
    
3. Optional but worth it: install a Verilog syntax extension inside that WSL window (e.g., **"Verilog-HDL/SystemVerilog"** by mshr-h) for syntax highlighting and basic linting while you read/edit `picorv32.v` and the `picosoc/` files.

### Where ModelSim fits in

You don't need it for verifying the stock repo — Icarus + GTKWave covers that. But **ModelSim becomes genuinely useful in task 4** (test software), specifically if you want a GUI-driven testbench for the verification scenarios you design yourself (e.g., stepping through a simulated SPI transaction interactively, inspecting signals by hand).

If you get there and want to use ModelSim instead of Icarus for your own custom testbench, that's a reasonable choice — just flag it and I'll help you set up the `vlog`/`vsim` project instead of the Makefile-driven Icarus flow.

Once `make test` passes cleanly, that's Step 2.5 done and the whole environment task is checked off. Want to move straight into **task 3 (the PicoSoC keep/cut/add evaluation)** next, since that's the biggest remaining piece for today?

---

## Environment Version & Results

| Component | Version | Notes |
| --- | --- | --- |
| Host OS | Ubuntu 26.04 LTS ("resolute") | via WSL2 |
| WSL kernel | 6.18.33.1-microsoft-standard-WSL2 |  |
| PicoRV32 repo | commit `87c89ac` (full: `87c89acc18994c8cf9a2311e871818e87d304568`) | Mon Jun 17 08:20:13 2024 +0200, from `github.com/YosysHQ/picorv32.git` |
| Icarus Verilog | 12.0 (stable) | See note below |
| RISC-V toolchain | `riscv64-unknown-elf-gcc` 14.2.0+19 | Invoked via `TOOLCHAIN_PREFIX=riscv64-unknown-elf-` override in the Makefile |
| Verilator | 5.032 (2025-01-01, Debian 5.032-1) |  |
| GTKWave | 3.3.126 |  |

### `make test` Results

```bash
Cycle counter: 435668
Instruction counter: 91210
CPI: 4.77

EBREAK instruction at 0x0000072A
pc 0000072D x8  00000000 x16 E2E2B92B x24 00000000
x1 000006FC x9  00000000 x17 00000000 x25 00000000
x2 00020000 x10 20000000 x18 00000000 x26 00000000
x3 DEADBEEF x11 075BCD15 x19 00003C28 x27 00000000
x4 DEADBEEF x12 0000004F x20 00000000 x28 00000000
x5 0000108E x13 0000004E x21 00000000 x29 00000001
x6 00000020 x14 00000045 x22 00000000 x30 00000000
x7 00000000 x15 0000000A x23 00000000 x31 00000000

Number of fast external IRQs counted: 54
Number of slow external IRQs counted: 6
Number of timer IRQs counted: 22
TRAP after 477707 clock cycles
ALL TESTS PASSED.
testbench.v:266: $finish called at 4778170000 (1ps)
```
# BSW Project Template

BSW (Basic Software) + MCAL project template based on **LP-MSPM0G series EVM**.  
LED blink (PA0) is the hello world — compile, test, and flash in one setup script.

## Repository Structure

```
bsw-project-template/
├── _shared/
│   ├── bootstrap.ps1       Windows entry point
│   ├── bootstrap.sh        macOS / Linux entry point
│   ├── setup.py            Common setup logic (submodule + toolchain + pyOCD)
│   └── platforms.json      Supported platform list
├── boards/
│   └── lp_mspm0g3507.yaml  Board pin / peripheral definition
├── bsw/                    BSW submodule (initialized by setup script)
├── cmake/
│   ├── arm-none-eabi.cmake Firmware cross-compiler toolchain
│   └── toolchain-host.cmake Host compiler (unit test / SIL)
├── renode/
│   ├── lp_mspm0g3507.repl  Renode platform description (Cortex-M0+)
│   └── test_led_blink.robot Robot Framework SIL test
├── src/
│   ├── main.c              Application entry point
│   ├── led_blink.h / .c    Testable LED blink state machine
└── tests/
    ├── mock/               MCAL stubs (Dio, Mcu, Os) for host build
    └── unit/
        └── test_led_blink.c 7 Unity unit test cases
```

## Supported Platforms

| Platform key | Hardware | Toolchain |
|---|---|---|
| `bsw-mcal-msp` | TI MSPM0G series (LP-MSPM0G3507) | arm-none-eabi-gcc |
| `bsw-mcal-traveo` | Infineon TRAVEO II | arm-none-eabi-gcc |

## Build Presets

| Preset | Purpose | Requires |
|---|---|---|
| `bsw-mcal-msp` | Firmware for LP-MSPM0G3507 | ARM GCC + BSW submodule |
| `host-test` | Unit tests on host PC | MinGW-w64 (Win) / GCC (Linux/macOS) |
| `renode-sil` | SIL via Renode emulator | ARM GCC + Renode |

---

## Quick Start

### Prerequisites (all platforms)

- **Git** with submodule support
- **Python 3.8+**
- **CMake 3.20+** (installed by setup script if missing)

---

## Windows

### Step 1 — Clone

```powershell
git clone https://github.com/billykim1221/bsw-project-template
cd bsw-project-template
```

### Step 2 — Run Bootstrap

Open **PowerShell** (not CMD) and run:

```powershell
.\_shared\bootstrap.ps1 -Platform bsw-mcal-msp
```

The script will:
1. Check Python 3.8+ → install via `winget` if missing
2. Init BSW submodule → `git submodule update --init bsw`
3. Init platform MCAL → `git submodule update --init bsw/platform/bsw-mcal-msp`
4. Download ARM GCC 13.3.rel1 (Windows zip) → `_shared/tools/compilers/`
5. Install MinGW-w64 via MSYS2 → `winget install MSYS2.MSYS2`
6. Install Renode → `winget install Antmicro.Renode`
7. `pip install pyocd cmake ninja robotframework`
8. Install pyOCD target pack `TexasInstruments.MSPM0G_DFP`

> **Execution Policy**: If you see a script blocked error, run once:
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```

### Step 3 — Unit Test (no hardware needed)

```powershell
cmake --preset host-test
cmake --build build\host-test
ctest --preset host-test -v
```

Expected output:
```
Test project .../build/host-test
    Start 1: LedBlink::UnitTests
1/1 Test #1: LedBlink::UnitTests ..............   Passed    0.00 sec

100% tests passed, 0 tests failed out of 1
```

### Step 4 — SIL via Renode (no hardware needed)

Build the ARM binary first:

```powershell
cmake --preset renode-sil
cmake --build build\renode-sil
```

Run the Robot Framework SIL test:

```powershell
renode-test renode\test_led_blink.robot
```

The test verifies:
- LED starts OFF at T=0
- LED goes HIGH after 500 ms of emulated time
- LED returns LOW after 1000 ms (full 1 Hz cycle)

### Step 5 — Flash to LP-MSPM0G3507 (hardware required)

Connect LP-MSPM0G3507 via USB (XDS110 onboard debugger).

```powershell
cmake --preset bsw-mcal-msp
cmake --build build\bsw-mcal-msp
cmake --build build\bsw-mcal-msp --target flash
```

Or manually:

```powershell
pyocd flash --target MSPM0G3507 build\bsw-mcal-msp\bsw_project_template.elf
```

---

## macOS

### Step 1 — Clone

```bash
git clone https://github.com/billykim1221/bsw-project-template
cd bsw-project-template
```

### Step 2 — Run Bootstrap

```bash
chmod +x _shared/bootstrap.sh
./_shared/bootstrap.sh --platform bsw-mcal-msp
```

The script will:
1. Check Python 3.8+ → prompt `brew install python3` if missing
2. Init BSW + platform MCAL submodules
3. Download ARM GCC 13.3.rel1 (macOS tar.xz) → `_shared/tools/compilers/`
4. Download Renode portable zip → `_shared/tools/renode/`
5. `pip3 install pyocd cmake ninja robotframework`
6. Install pyOCD target pack `TexasInstruments.MSPM0G_DFP`

> **Homebrew users** can pre-install the toolchain:
> ```bash
> brew install --cask gcc-arm-embedded
> brew install cmake ninja
> ```
> Then run bootstrap with `--skip-toolchain`.

### Step 3 — Unit Test

```bash
cmake --preset host-test
cmake --build build/host-test
ctest --preset host-test -v
```

### Step 4 — SIL via Renode

```bash
cmake --preset renode-sil
cmake --build build/renode-sil
renode-test renode/test_led_blink.robot
```

### Step 5 — Flash (LP-MSPM0G3507)

```bash
cmake --preset bsw-mcal-msp
cmake --build build/bsw-mcal-msp --target flash
```

---

## Linux

### Step 1 — Clone

```bash
git clone https://github.com/billykim1221/bsw-project-template
cd bsw-project-template
```

### Step 2 — Run Bootstrap

```bash
chmod +x _shared/bootstrap.sh
./_shared/bootstrap.sh --platform bsw-mcal-msp
```

The script will:
1. Check Python 3.8+ → prompt package manager install if missing
2. Init BSW + platform MCAL submodules
3. Download ARM GCC 13.3.rel1 (Linux tar.xz) → `_shared/tools/compilers/`
4. Install Renode `.deb` via `dpkg` (Debian/Ubuntu) or portable zip
5. `pip3 install pyocd cmake ninja robotframework`
6. Install pyOCD target pack `TexasInstruments.MSPM0G_DFP`

> **Debian/Ubuntu** pre-install shortcut:
> ```bash
> sudo apt install gcc-arm-none-eabi cmake ninja-build python3-pip
> ./_shared/bootstrap.sh --platform bsw-mcal-msp --skip-toolchain
> ```

> **pyOCD udev rules** (required for USB access without sudo):
> ```bash
> python3 -m pyocd install-udev-rules
> ```

### Step 3 — Unit Test

```bash
cmake --preset host-test
cmake --build build/host-test
ctest --preset host-test -v
```

### Step 4 — SIL via Renode

```bash
cmake --preset renode-sil
cmake --build build/renode-sil
renode-test renode/test_led_blink.robot
```

### Step 5 — Flash (LP-MSPM0G3507)

```bash
cmake --preset bsw-mcal-msp
cmake --build build/bsw-mcal-msp --target flash
```

---

## Adding a New Platform

1. Add an entry to `_shared/platforms.json`
2. Add a board YAML to `boards/`
3. Add a CMake preset to `CMakePresets.json`
4. Run bootstrap with the new platform key:

```bash
./_shared/bootstrap.sh --platform bsw-mcal-traveo
cmake --preset bsw-mcal-traveo
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `BSW submodule not initialized` | Run bootstrap first |
| `arm-none-eabi-gcc: not found` | Re-run bootstrap or set `ARM_GCC_PATH` env var |
| `winget: not found` (Windows) | Update Windows 10/11 via Microsoft Store → App Installer |
| `pyocd: No connected probes` | Check USB cable, install udev rules (Linux), check XDS110 driver (Windows) |
| Renode `robot` test hangs | Check ELF path in `.robot` file matches build output |
| MinGW `gcc` not in PATH | Add `C:\msys64\ucrt64\bin` to system PATH |

---

## License

MIT

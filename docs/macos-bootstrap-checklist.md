# macOS Bootstrap Checklist

Step-by-step run-through for bringing the BSW Project Template up on a
fresh macOS box (Apple Silicon or Intel). README.md covers the basic
flow; this doc adds expected outputs, verification probes, and a
failure-reporting cheat sheet.

Use this when bringing up a new Mac, onboarding a teammate, or
debugging a bootstrap that misbehaves.

---

## 0. Prerequisites (one-time)

```bash
# Homebrew (if missing)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Recommended — with brew present, bootstrap routes ARM GCC / Renode
# / .NET 8 through brew casks (much cleaner than the dmg fallback).
brew install python3 cmake ninja git
```

---

## 1. Clone

```bash
git clone --recursive https://github.com/Weldex-Corporation/bsw-project-template
cd bsw-project-template
```

If you forgot `--recursive`:

```bash
git submodule update --init --recursive
```

---

## 2. Bootstrap

```bash
chmod +x bootstrap/bootstrap.sh
./bootstrap/bootstrap.sh --platform bsw-mcal-msp
```

What to look for in the output:

| Line | Meaning |
|---|---|
| `[setup] ✓ ARM GCC installed (Darwin/arm64)` | Apple Silicon got the native arm64 toolchain — no Rosetta needed. Intel Macs should show `(Darwin/x86_64)`. |
| `[setup] ✓ Renode installed via brew --cask renode` | brew is present, used the cask path — also pulls .NET 8 runtime. |
| `[setup] ⚠ brew --cask renode failed - falling back to .dmg download` | brew refused — falls back to `hdiutil attach` + `ditto` copy. **This is expected** — the `renode` cask is not always registered in Homebrew. The dmg fallback is the normal path on macOS. |
| `[bootstrap] Note: Renode needs the .NET 8 runtime on macOS.` | Only printed when `dotnet` is missing AND brew isn't used to install Renode. Manual fix: `brew install --cask dotnet`. |
| `[setup] ✗ ...` | Any line starting with `✗` is a hard failure — capture it. |

---

## 3. Activate PATH (current shell only)

```bash
source bootstrap/env-setup.sh
```

Verify:

```bash
arm-none-eabi-gcc --version   # 13.3.rel1 (bootstrap) or system-installed version
cmake --version               # 3.20+
ninja --version
renode --version              # 1.16.1 — or: renode-test --version
pyocd --version
```

All five must report a version. If any is missing, jump to
[§7 Failure-reporting cheat sheet](#7-failure-reporting-cheat-sheet).

---

## 4. Build (three integration styles)

```bash
# bare-metal
cmake -S . -B build/bm -G Ninja \
      -DCMAKE_TOOLCHAIN_FILE=cmake/arm-none-eabi.cmake \
      -DBOARD=lp_mspm0g3507 -DPLATFORM=mspm0 -DAPP_MODEL=baremetal
ninja -C build/bm

# oslite (cooperative scheduler — Os_Lite)
cmake -S . -B build/ol -G Ninja \
      -DCMAKE_TOOLCHAIN_FILE=cmake/arm-none-eabi.cmake \
      -DBOARD=lp_mspm0g3507 -DPLATFORM=mspm0 -DAPP_MODEL=oslite
ninja -C build/ol

# rte_os (full AUTOSAR — Os_bcc1 + Rte_bcc1)
cmake -S . -B build/rte -G Ninja \
      -DCMAKE_TOOLCHAIN_FILE=cmake/arm-none-eabi.cmake \
      -DBOARD=lp_mspm0g3507 -DPLATFORM=mspm0 -DAPP_MODEL=rte_os
ninja -C build/rte
```

Expected `.bin` sizes (approximate — exact values vary with GCC version):

| APP_MODEL  | Size (approx) |
|---|---|
| baremetal  | 2900–3100 B |
| oslite     | 2900–3100 B |
| rte_os     | 9600–10200 B |

Sizes depend on the ARM GCC version (`13.3.rel1` from bootstrap vs a
system-installed toolchain). Cross-platform builds with the **same**
compiler should match to the byte. If a size is drastically outside
these ranges the build picked up an unexpected source — capture
`ninja -v -C build/<mode>` and report.

---

## 5. Renode SIL

The `.robot` files expect the rte_os ELF at
`build/bsw-mcal-msp-rte/bsw_project_template.elf`, so either build
directly to that path or copy:

```bash
mkdir -p build/bsw-mcal-msp-rte
cp -r build/rte/* build/bsw-mcal-msp-rte/

renode-test renode/test_rte_os_boot.robot
renode-test renode/test_rte_os_wcet.robot
```

> **Renode version**: These tests require **Renode 1.16.1** or later.
> Version 1.16.0 is missing the `request.Type` API used by the test
> scripts and will fail all tests. The bootstrap script installs 1.16.1
> by default.

Pass criteria:

- `Boot Without Fault` — PASS
- `System Tick Counter Advances` — `os_counter_ms after 200 ms = ~198` then PASS
- `Per-Tick WCET ...` — `max instructions / tick < 32000` then PASS

If Renode says "command not found: dotnet", install the .NET 8 runtime
(see §2 note) and re-run.

---

## 6. Flash real silicon (LP-MSPM0G3507)

USB-connect the board (XDS110 onboard debugger), then:

```bash
pyocd flash --target MSPM0G3507 build/rte/bsw_project_template.elf
```

Expected flow: `Erasing → Programming → Verifying → done`. PA0 LED
should toggle once Reset releases.

If `pyocd` can't find the probe:
- Re-seat the USB cable
- `pyocd list` — should show the XDS110
- macOS may ask for "Accessory connection permission" the first time
  (System Settings → Privacy & Security → USB Accessories)

---

## 7. Failure-reporting cheat sheet

When opening an issue or pinging the team, attach the matching capture:

| Step | What to capture |
|---|---|
| 2. bootstrap | Last 30 lines of `./bootstrap/bootstrap.sh ...` output |
| 3. env-setup | `source bootstrap/env-setup.sh` output + `echo $PATH` |
| 4. build     | `ninja -v -C build/<mode>` last 50 lines |
| 5. Renode    | `renode-test renode/test_rte_os_boot.robot 2>&1 \| tail -50` |
| 6. pyOCD     | `pyocd flash -v --target MSPM0G3507 ...` output |

Plus the host info — paste once:

```bash
uname -m              # arm64 or x86_64
sw_vers               # macOS version
xcode-select -p       # CommandLineTools path
brew --version        # if Homebrew is used
```

---

## Working from a different Mac later

Everything in this checklist is now on `main`. On any new Mac:

```bash
git clone --recursive https://github.com/Weldex-Corporation/bsw-project-template
cd bsw-project-template
./bootstrap/bootstrap.sh --platform bsw-mcal-msp
source bootstrap/env-setup.sh
```

That's the full onboarding — no special branches.

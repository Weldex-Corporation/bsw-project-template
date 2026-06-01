#!/usr/bin/env python3
"""
BSW Project Template — Setup Script
Installs: BSW submodule, platform MCAL submodule, ARM GCC, MinGW-w64 (Windows),
          Renode, pyOCD, CMake, Ninja.

Usage:
    python _shared/setup.py --platform bsw-mcal-msp [--skip-toolchain]
    python _shared/setup.py                           # interactive menu
"""

import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
import urllib.request
import zipfile
import tarfile
from pathlib import Path

# ── Paths ─────────────────────────────────────────────────────────────────

SCRIPT_DIR   = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent

_WORKSPACE_SHARED = Path("/srv/workspaces/_shared/tools/compilers")
_LOCAL_SHARED     = PROJECT_ROOT / "_shared" / "tools" / "compilers"
TOOLS_DIR = _WORKSPACE_SHARED if _WORKSPACE_SHARED.exists() else _LOCAL_SHARED

# True when running on the ELM Studio server (shared workspace mount present).
IS_ELM_SERVER = Path("/srv/workspaces/_shared").is_dir()

PLATFORMS_JSON = SCRIPT_DIR / "platforms.json"
BSW_REPO_URL   = "https://github.com/Weldex-Corporation/bsw.git"
BSW_PATH       = PROJECT_ROOT / "bsw"
OS             = platform.system()  # 'Linux', 'Darwin', 'Windows'

# ── ARM GCC ───────────────────────────────────────────────────────────────

ARM_GCC_VERSION = "13.3.rel1"
ARM_GCC_URLS = {
    "Linux":   "https://developer.arm.com/-/media/Files/downloads/gnu/13.3.rel1/binrel/arm-gnu-toolchain-13.3.rel1-x86_64-arm-none-eabi.tar.xz",
    "Darwin":  "https://developer.arm.com/-/media/Files/downloads/gnu/13.3.rel1/binrel/arm-gnu-toolchain-13.3.rel1-darwin-x86_64-arm-none-eabi.tar.xz",
    "Windows": "https://developer.arm.com/-/media/Files/downloads/gnu/13.3.rel1/binrel/arm-gnu-toolchain-13.3.rel1-mingw-w64-i686-arm-none-eabi.zip",
}

# ── MinGW-w64 (Windows host compiler for unit tests) ─────────────────────
# Standalone build from WinLibs (no MSYS2 required)
MINGW_VERSION  = "13.3.0"
MINGW_MSYS2_PATH = Path("C:/msys64")
MINGW_UCRT_BIN   = MINGW_MSYS2_PATH / "ucrt64/bin"

# ── Renode ────────────────────────────────────────────────────────────────
RENODE_VERSION = "1.15.2"
RENODE_URLS = {
    "Windows": f"https://github.com/renode/renode/releases/download/v{RENODE_VERSION}/renode_win64-portable.zip",
    "Linux":   f"https://github.com/renode/renode/releases/download/v{RENODE_VERSION}/renode_{RENODE_VERSION}_amd64.deb",
    "Darwin":  f"https://github.com/renode/renode/releases/download/v{RENODE_VERSION}/renode-macos-portable.zip",
}
RENODE_LOCAL_DIR = PROJECT_ROOT / "_shared" / "tools" / "renode"

# ── Helpers ───────────────────────────────────────────────────────────────

def log(msg):    print(f"[setup] {msg}")
def ok(msg):     print(f"[setup] ✓ {msg}")
def warn(msg):   print(f"[setup] ⚠ {msg}")
def err(msg):    print(f"[setup] ✗ {msg}", file=sys.stderr)

def run(cmd, cwd=None, check=True, capture=False):
    log(f"$ {' '.join(str(c) for c in cmd)}")
    result = subprocess.run(
        [str(c) for c in cmd], cwd=cwd, check=check,
        capture_output=capture, text=True
    )
    return result

def _progress(block, block_size, total):
    done = block * block_size
    pct  = min(100, int(done * 100 / total)) if total > 0 else 0
    bar  = "█" * (pct // 5) + "░" * (20 - pct // 5)
    print(f"\r  [{bar}] {pct}%", end="", flush=True)

def download(url, dest):
    log(f"Downloading {url.split('/')[-1]} ...")
    urllib.request.urlretrieve(url, dest, reporthook=_progress)
    print()

def extract(archive, dest):
    log(f"Extracting to {dest} ...")
    if str(archive).endswith(".zip"):
        with zipfile.ZipFile(archive) as z:
            z.extractall(dest)
    else:
        with tarfile.open(archive) as t:
            t.extractall(dest)

def load_platforms():
    with open(PLATFORMS_JSON) as f:
        return json.load(f)

def select_platform(platforms, arg=None):
    keys = list(platforms.keys())
    if arg and arg in platforms:
        return arg
    if arg:
        warn(f"Unknown platform '{arg}'. Available: {', '.join(keys)}")
    print("\nAvailable platforms:")
    for i, key in enumerate(keys, 1):
        print(f"  [{i}] {key} — {platforms[key]['description']}")
    while True:
        try:
            choice = int(input("\nSelect platform number: "))
            if 1 <= choice <= len(keys):
                return keys[choice - 1]
        except (ValueError, KeyboardInterrupt):
            pass
        print("Invalid selection.")

# ── Step 1: BSW submodule ─────────────────────────────────────────────────

def init_bsw():
    if (BSW_PATH / ".git").exists():
        ok("BSW submodule already initialized")
        return
    log("Initializing BSW submodule...")
    gitmodules = PROJECT_ROOT / ".gitmodules"
    if gitmodules.exists() and '[submodule "bsw"]' in gitmodules.read_text():
        run(["git", "submodule", "update", "--init", "bsw"], cwd=PROJECT_ROOT)
    else:
        run(["git", "submodule", "add", "--branch", "main",
             BSW_REPO_URL, "bsw"], cwd=PROJECT_ROOT)
    ok("BSW submodule ready")

# ── Step 2: Platform MCAL submodule ──────────────────────────────────────

def init_platform(cfg):
    sub = cfg["submodule_path"]
    target = BSW_PATH / sub
    if (target / ".git").exists():
        ok(f"Platform submodule '{sub}' already initialized")
        return
    log(f"Initializing platform submodule: {sub}")
    run(["git", "submodule", "update", "--init", sub], cwd=BSW_PATH)
    ok(f"Platform '{sub}' ready")

# ── Step 3: ARM GCC (firmware cross-compiler) ─────────────────────────────

def install_arm_gcc():
    dest_dir = TOOLS_DIR / "gnu-arm" / ARM_GCC_VERSION
    gcc_bin = dest_dir / "bin" / (
        "arm-none-eabi-gcc.exe" if OS == "Windows" else "arm-none-eabi-gcc"
    )
    if gcc_bin.exists() or shutil.which("arm-none-eabi-gcc"):
        ok(f"ARM GCC {ARM_GCC_VERSION} already available")
        return
    url = ARM_GCC_URLS.get(OS)
    if not url:
        warn(f"No ARM GCC URL for OS '{OS}'. Install manually.")
        return
    # Extract into a temp dir, then move the single inner toolchain folder's
    # contents up to dest_dir. The Arm archives contain a top-level folder
    # like 'arm-gnu-toolchain-13.3.rel1-x86_64-arm-none-eabi/' which would
    # otherwise nest below dest_dir and break the dest_dir/bin/ layout that
    # cmake/arm-none-eabi.cmake expects.
    dest_dir.parent.mkdir(parents=True, exist_ok=True)
    staging = TOOLS_DIR / f".gnu-arm-{ARM_GCC_VERSION}-staging"
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)
    archive = TOOLS_DIR / url.split("/")[-1]
    download(url, archive)
    extract(archive, staging)
    archive.unlink(missing_ok=True)
    inner = [p for p in staging.iterdir() if p.is_dir()]
    if len(inner) == 1:
        if dest_dir.exists():
            shutil.rmtree(dest_dir)
        shutil.move(str(inner[0]), str(dest_dir))
        shutil.rmtree(staging, ignore_errors=True)
    else:
        # Archive layout differs from expected (no single top-level dir).
        # Fall back to using staging contents directly.
        if dest_dir.exists():
            shutil.rmtree(dest_dir)
        shutil.move(str(staging), str(dest_dir))
    if not gcc_bin.exists():
        err(f"ARM GCC install failed: {gcc_bin} not found after extraction")
        return
    ok(f"ARM GCC installed at {dest_dir}")

# ── Step 4: MinGW-w64 (Windows only — host compiler for unit tests) ───────

def install_mingw_windows():
    if OS != "Windows":
        return
    if MINGW_UCRT_BIN.exists() and (MINGW_UCRT_BIN / "gcc.exe").exists():
        ok(f"MinGW-w64 already at {MINGW_UCRT_BIN}")
        return
    log("MinGW-w64 not found — installing MSYS2 + MinGW-w64 via winget...")
    try:
        run(["winget", "install", "MSYS2.MSYS2",
             "--silent", "--accept-source-agreements",
             "--accept-package-agreements"], check=False)
        # Give MSYS2 a moment then install ucrt64 GCC
        msys2_bash = MINGW_MSYS2_PATH / "usr/bin/bash.exe"
        if msys2_bash.exists():
            run([str(msys2_bash), "-lc",
                 "pacman -S --noconfirm mingw-w64-ucrt-x86_64-gcc "
                 "mingw-w64-ucrt-x86_64-cmake mingw-w64-ucrt-x86_64-ninja"])
            ok(f"MinGW-w64 installed at {MINGW_UCRT_BIN}")
        else:
            warn("MSYS2 installed but bash not found yet. Restart terminal and re-run.")
    except Exception as e:
        warn(f"MinGW-w64 install failed: {e}")
        print("  Manual install: https://www.msys2.org → then:")
        print("  pacman -S mingw-w64-ucrt-x86_64-gcc")

# ── Step 5: Renode (SIL emulator) ─────────────────────────────────────────

def install_renode():
    if shutil.which("renode") or shutil.which("renode-test"):
        ok("Renode already in PATH")
        return
    # Windows: try winget first
    if OS == "Windows":
        log("Installing Renode via winget...")
        result = run(["winget", "install", "Antmicro.Renode",
                      "--silent", "--accept-source-agreements",
                      "--accept-package-agreements"], check=False)
        if result.returncode == 0:
            ok("Renode installed via winget")
            return
    # Fallback: download portable zip
    url = RENODE_URLS.get(OS)
    if not url:
        warn(f"No Renode URL for OS '{OS}'")
        return
    RENODE_LOCAL_DIR.mkdir(parents=True, exist_ok=True)
    archive = RENODE_LOCAL_DIR / url.split("/")[-1]
    download(url, archive)
    if archive.suffix == ".zip":
        extract(archive, RENODE_LOCAL_DIR)
        archive.unlink(missing_ok=True)
        ok(f"Renode (portable) installed at {RENODE_LOCAL_DIR}")
        print(f"  Add to PATH: {RENODE_LOCAL_DIR}")
    elif archive.suffix == ".deb":
        run(["sudo", "dpkg", "-i", str(archive)], check=False)
        archive.unlink(missing_ok=True)
        ok("Renode .deb installed")

# ── Step 6: Python packages (pyOCD, cmake, ninja, robotframework) ─────────

def install_python_pkgs(cfg):
    pkgs = ["pyocd", "cmake", "ninja", "robotframework"]
    log(f"pip install {' '.join(pkgs)}")
    run([sys.executable, "-m", "pip", "install", "--quiet"] + pkgs)
    # pyOCD target pack
    pack = cfg.get("pyocd_pack")
    if pack:
        log(f"pyOCD pack: {pack}")
        run(["pyocd", "pack", "update"],           check=False)
        run(["pyocd", "pack", "install", pack],    check=False)
    ok("Python packages ready")

# ── Step 7: Verify ────────────────────────────────────────────────────────

def verify():
    print("\n[setup] ── Verification ──────────────────────────────────")
    # Extend PATH with known tool locations
    extra = []
    arm_bin = TOOLS_DIR / "gnu-arm" / ARM_GCC_VERSION / "bin"
    if arm_bin.exists():
        extra.append(str(arm_bin))
    if OS == "Windows" and MINGW_UCRT_BIN.exists():
        extra.append(str(MINGW_UCRT_BIN))
    if extra:
        os.environ["PATH"] = os.pathsep.join(extra) + os.pathsep + os.environ.get("PATH","")

    checks = [
        ["arm-none-eabi-gcc", "--version"],
        ["gcc",               "--version"],
        ["cmake",             "--version"],
        ["ninja",             "--version"],
        ["pyocd",             "--version"],
    ]
    for cmd in checks:
        try:
            out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True).split("\n")[0]
            ok(out.strip())
        except Exception:
            warn(f"{cmd[0]} — not found (may need PATH update)")

    renode_found = shutil.which("renode") or shutil.which("renode-test")
    if renode_found:
        ok("Renode found")
    else:
        warn("Renode — not in PATH (install manually or use portable zip in _shared/tools/renode)")

    print(f"\n  BSW  : {BSW_PATH}")
    print(f"  Tools: {TOOLS_DIR}")
    print()
    print("  ── Next steps ──────────────────────────────────────────")
    print("  # Unit tests (Windows/Linux/macOS)")
    print("  cmake --preset host-test")
    print("  ctest --preset host-test")
    print()
    print("  # SIL (Renode)")
    print("  cmake --preset renode-sil && ninja -C build/renode-sil")
    print("  renode-test renode/test_led_blink.robot")
    print()
    print("  # Firmware flash (LP-MSPM0G3507)")
    print("  cmake --preset bsw-mcal-msp && ninja -C build/bsw-mcal-msp flash")
    print()

# ── Main ──────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="BSW Project Template Setup")
    parser.add_argument("--platform",        help="Platform (e.g. bsw-mcal-msp)")
    parser.add_argument("--skip-toolchain",  action="store_true",
                        help="Skip ARM GCC download")
    parser.add_argument("--skip-renode",     action="store_true",
                        help="Skip Renode install")
    parser.add_argument("--skip-bsw",        action="store_true",
                        help="Skip BSW submodule init (tool-only install)")
    args = parser.parse_args()

    if IS_ELM_SERVER:
        log("Environment: ELM server (shared toolchain under /srv/workspaces/_shared)")
    else:
        log(f"Environment: local {OS}")

    platforms = load_platforms()
    chosen    = select_platform(platforms, args.platform)
    cfg       = platforms[chosen]
    log(f"Platform: {chosen} — {cfg['description']}")

    if not args.skip_bsw:
        init_bsw()
        init_platform(cfg)

    if not args.skip_toolchain:
        install_arm_gcc()
        if OS == "Windows":
            install_mingw_windows()

    if not args.skip_renode:
        install_renode()

    install_python_pkgs(cfg)
    verify()

if __name__ == "__main__":
    main()

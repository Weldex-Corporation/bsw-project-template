#!/usr/bin/env python3
"""
BSW Project Template — Setup Script
Installs: BSW submodule, platform MCAL submodule, ARM GCC, MinGW-w64 (Windows),
          Renode, pyOCD, CMake, Ninja.

Usage:
    python bootstrap/setup.py --platform bsw-mcal-msp [--skip-toolchain]
    python bootstrap/setup.py                           # interactive menu
"""

import argparse
import json
import os
import platform
import shutil
import ssl
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
_LOCAL_SHARED     = PROJECT_ROOT / "bootstrap" / "tools" / "compilers"
TOOLS_DIR = _WORKSPACE_SHARED if _WORKSPACE_SHARED.exists() else _LOCAL_SHARED

PLATFORMS_JSON = SCRIPT_DIR / "platforms.json"
BSW_REPO_URL   = "https://github.com/Weldex-Corporation/bsw.git"
BSW_PATH       = PROJECT_ROOT / "bsw"
OS             = platform.system()              # 'Linux', 'Darwin', 'Windows'
ARCH           = platform.machine().lower()     # 'x86_64'|'arm64'|'aarch64'|'amd64'

# ── ARM GCC ───────────────────────────────────────────────────────────────

ARM_GCC_VERSION = "13.3.rel1"
_ARM_URL_BASE   = ("https://developer.arm.com/-/media/Files/downloads/gnu/"
                   "13.3.rel1/binrel/arm-gnu-toolchain-13.3.rel1-")
# Keyed by (OS, normalised ARCH). ARM ships native arm64 binaries for
# both Linux (aarch64) and Darwin (arm64) since 13.3.rel1, so Apple
# Silicon does NOT need Rosetta when this URL set is used.
ARM_GCC_URLS = {
    ("Linux",   "x86_64"):  f"{_ARM_URL_BASE}x86_64-arm-none-eabi.tar.xz",
    ("Linux",   "aarch64"): f"{_ARM_URL_BASE}aarch64-arm-none-eabi.tar.xz",
    ("Darwin",  "x86_64"):  f"{_ARM_URL_BASE}darwin-x86_64-arm-none-eabi.tar.xz",
    ("Darwin",  "arm64"):   f"{_ARM_URL_BASE}darwin-arm64-arm-none-eabi.tar.xz",
    ("Windows", "amd64"):   f"{_ARM_URL_BASE}mingw-w64-i686-arm-none-eabi.zip",
    ("Windows", "x86_64"):  f"{_ARM_URL_BASE}mingw-w64-i686-arm-none-eabi.zip",
}

def _arm_gcc_url():
    return ARM_GCC_URLS.get((OS, ARCH))

# ── MinGW-w64 (Windows host compiler for unit tests) ─────────────────────
# Standalone build from WinLibs (no MSYS2 required)
MINGW_VERSION  = "13.3.0"
MINGW_MSYS2_PATH = Path("C:/msys64")
MINGW_UCRT_BIN   = MINGW_MSYS2_PATH / "ucrt64/bin"

# ── Renode ────────────────────────────────────────────────────────────────
# v1.16.0 is the first release with a Windows portable asset; older tags
# ship only .msi for Windows.
RENODE_VERSION = "1.16.0"
# macOS portable assets are .dmg per architecture; Linux is .tar.gz;
# Windows is .zip. Keyed by (OS, arch) so Apple Silicon and Intel get
# the right binary.
_RENODE_BASE = f"https://github.com/renode/renode/releases/download/v{RENODE_VERSION}"
RENODE_URLS = {
    ("Windows", "amd64"):   f"{_RENODE_BASE}/renode-{RENODE_VERSION}.windows-portable-dotnet.zip",
    ("Windows", "x86_64"):  f"{_RENODE_BASE}/renode-{RENODE_VERSION}.windows-portable-dotnet.zip",
    ("Linux",   "x86_64"):  f"{_RENODE_BASE}/renode-{RENODE_VERSION}.linux-portable.tar.gz",
    ("Darwin",  "arm64"):   f"{_RENODE_BASE}/renode-{RENODE_VERSION}-dotnet.osx-arm64-portable.dmg",
    ("Darwin",  "x86_64"):  f"{_RENODE_BASE}/renode-{RENODE_VERSION}-dotnet.osx-x64-portable.dmg",
}

def _renode_url():
    return RENODE_URLS.get((OS, ARCH))
RENODE_WINGET_ID = "Renode.Renode"
RENODE_LOCAL_DIR = PROJECT_ROOT / "bootstrap" / "tools" / "renode"

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

_SSL_CTX = None

def _ensure_ssl_context():
    """Return an SSLContext using certifi's CA bundle.
    Windows builds of CPython ship without a usable system CA store, so
    HTTPS downloads from ARM / GitHub fail with SSLCertVerificationError.
    Lazily pip-installs certifi on first use."""
    global _SSL_CTX
    if _SSL_CTX is not None:
        return _SSL_CTX
    try:
        import certifi
    except ImportError:
        log("Installing certifi for SSL CA verification...")
        subprocess.run(
            [sys.executable, "-m", "pip", "install", "--quiet", "certifi"],
            check=True
        )
        import certifi
    _SSL_CTX = ssl.create_default_context(cafile=certifi.where())
    return _SSL_CTX

def download(url, dest):
    log(f"Downloading {url.split('/')[-1]} ...")
    ctx = _ensure_ssl_context()
    https_handler = urllib.request.HTTPSHandler(context=ctx)
    opener = urllib.request.build_opener(https_handler)
    urllib.request.install_opener(opener)
    urllib.request.urlretrieve(url, dest, reporthook=_progress)
    print()

def extract(archive, dest):
    log(f"Extracting to {dest} ...")
    if str(archive).endswith(".zip"):
        with zipfile.ZipFile(archive) as z:
            z.extractall(dest)
    else:
        with tarfile.open(archive) as t:
            # filter='data' silences the Py3.14 deprecation and is safer
            try:
                t.extractall(dest, filter="data")
            except TypeError:
                t.extractall(dest)

def flatten_single_top(dest):
    """If `dest` contains exactly one subdirectory (typical for vendor archives
    like ARM GCC / Renode), move its contents up into `dest` itself so callers
    can use a stable layout (e.g. dest/bin/...)."""
    entries = [p for p in Path(dest).iterdir()]
    if len(entries) == 1 and entries[0].is_dir():
        top = entries[0]
        for item in list(top.iterdir()):
            target = Path(dest) / item.name
            if target.exists():
                if target.is_dir():
                    shutil.rmtree(target)
                else:
                    target.unlink()
            shutil.move(str(item), str(target))
        top.rmdir()

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

def _has_gitlink(repo_root, path):
    """Return True iff `path` is registered as a submodule gitlink (mode 160000)
    in the index of the git repo rooted at `repo_root`."""
    res = subprocess.run(
        ["git", "ls-files", "--stage", "--", path],
        cwd=repo_root, capture_output=True, text=True
    )
    if res.returncode != 0:
        return False
    line = res.stdout.strip()
    return line.startswith("160000")

def init_bsw():
    if (BSW_PATH / ".git").exists():
        ok("BSW submodule already initialized")
        return
    log("Initializing BSW submodule...")
    if _has_gitlink(PROJECT_ROOT, "bsw"):
        run(["git", "submodule", "update", "--init", "bsw"], cwd=PROJECT_ROOT)
    else:
        # Parent template repo lacks a committed gitlink for `bsw` even though
        # .gitmodules declares it. Clone the BSW repo directly instead.
        warn("Parent repo has no gitlink for 'bsw' - cloning directly")
        BSW_PATH.parent.mkdir(parents=True, exist_ok=True)
        run(["git", "clone", "--branch", "main", BSW_REPO_URL, str(BSW_PATH)])
    ok("BSW submodule ready")

# ── Step 2: Platform MCAL submodule ──────────────────────────────────────

def init_platform(cfg):
    sub = cfg["submodule_path"]
    target = BSW_PATH / sub
    if (target / ".git").exists():
        ok(f"Platform submodule '{sub}' already initialized")
        return
    log(f"Initializing platform submodule: {sub}")
    if _has_gitlink(BSW_PATH, sub):
        run(["git", "submodule", "update", "--init", sub], cwd=BSW_PATH)
    else:
        # BSW repo declares the platform in .gitmodules but no committed gitlink.
        # Parse the url from .gitmodules and clone directly.
        gm = (BSW_PATH / ".gitmodules").read_text()
        section = f'[submodule "{sub}"]'
        url = None
        in_section = False
        for line in gm.splitlines():
            stripped = line.strip()
            if stripped == section:
                in_section = True
                continue
            if in_section:
                if stripped.startswith("["):
                    break
                if stripped.startswith("url"):
                    url = stripped.split("=", 1)[1].strip()
                    break
        if not url:
            err(f"Could not find URL for platform '{sub}' in BSW .gitmodules")
            sys.exit(1)
        warn(f"BSW repo has no gitlink for '{sub}' - cloning {url}")
        target.parent.mkdir(parents=True, exist_ok=True)
        run(["git", "clone", "--branch", "main", url, str(target)])
    ok(f"Platform '{sub}' ready")

# ── Step 3: ARM GCC (firmware cross-compiler) ─────────────────────────────

def install_arm_gcc():
    gcc_bin = TOOLS_DIR / "gnu-arm" / ARM_GCC_VERSION / "bin" / (
        "arm-none-eabi-gcc.exe" if OS == "Windows" else "arm-none-eabi-gcc"
    )
    if gcc_bin.exists() or shutil.which("arm-none-eabi-gcc"):
        ok(f"ARM GCC {ARM_GCC_VERSION} already available")
        return
    url = _arm_gcc_url()
    if not url:
        warn(f"No ARM GCC URL for OS='{OS}' ARCH='{ARCH}'.")
        if OS == "Darwin":
            print("  macOS hint: brew install --cask gcc-arm-embedded")
            print("              then rerun bootstrap with --skip-toolchain")
        return
    dest_dir = TOOLS_DIR / "gnu-arm" / ARM_GCC_VERSION
    dest_dir.mkdir(parents=True, exist_ok=True)
    archive = TOOLS_DIR / url.split("/")[-1]
    download(url, archive)
    extract(archive, dest_dir)
    # Vendor archives wrap everything in a versioned top-level dir
    # (e.g. arm-gnu-toolchain-13.3.rel1-mingw-w64-i686-arm-none-eabi/).
    # Flatten so we get dest_dir/bin/arm-none-eabi-gcc directly.
    flatten_single_top(dest_dir)
    archive.unlink(missing_ok=True)
    if not gcc_bin.exists():
        warn(f"ARM GCC binary not found at expected path after extract: {gcc_bin}")
    else:
        ok(f"ARM GCC installed ({OS}/{ARCH})")

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
            # Sync package DB first (fresh MSYS2 has no DB yet)
            run([str(msys2_bash), "-lc", "pacman -Sy --noconfirm"], check=False)
            run([str(msys2_bash), "-lc",
                 "pacman -S --noconfirm --needed "
                 "mingw-w64-ucrt-x86_64-gcc "
                 "mingw-w64-ucrt-x86_64-cmake "
                 "mingw-w64-ucrt-x86_64-ninja"])
            ok(f"MinGW-w64 installed at {MINGW_UCRT_BIN}")
        else:
            warn("MSYS2 installed but bash not found yet. Restart terminal and re-run.")
    except Exception as e:
        warn(f"MinGW-w64 install failed: {e}")
        print("  Manual install: https://www.msys2.org → then:")
        print("  pacman -S mingw-w64-ucrt-x86_64-gcc")

# ── Step 5: Renode (SIL emulator) ─────────────────────────────────────────

def _install_renode_dmg(archive, dest):
    """Mount the Renode .dmg, copy its portable layout to `dest`, and
    eject. The dmg root typically contains a single folder like
    `renode_1.16.0_portable` with `bin/`, `scripts/`, etc."""
    dest.mkdir(parents=True, exist_ok=True)
    mountpoint = Path(f"/Volumes/renode-bootstrap-{os.getpid()}")
    attached = False
    try:
        run(["hdiutil", "attach", "-nobrowse", "-quiet",
             "-mountpoint", str(mountpoint), str(archive)])
        attached = True
        # Copy everything in the mount root into dest. Use ditto so xattrs
        # / quarantine flags are preserved correctly on macOS.
        for entry in mountpoint.iterdir():
            target = dest / entry.name
            if target.exists():
                if target.is_dir():
                    shutil.rmtree(target)
                else:
                    target.unlink()
            run(["ditto", str(entry), str(target)])
    finally:
        if attached:
            run(["hdiutil", "detach", "-quiet", str(mountpoint)], check=False)
    flatten_single_top(dest)

def install_renode():
    if shutil.which("renode") or shutil.which("renode-test"):
        ok("Renode already in PATH")
        return
    # Windows: try winget first (package id is Renode.Renode, not Antmicro.Renode)
    if OS == "Windows":
        log(f"Installing Renode via winget ({RENODE_WINGET_ID})...")
        result = run(["winget", "install", "--id", RENODE_WINGET_ID,
                      "--silent", "--accept-source-agreements",
                      "--accept-package-agreements"], check=False)
        if result.returncode == 0:
            ok("Renode installed via winget")
            return
        warn("winget install Renode failed - falling back to portable zip")
    # macOS: try Homebrew Cask first — much cleaner than mounting a dmg,
    # and avoids a system-wide .NET runtime install dance.
    if OS == "Darwin" and shutil.which("brew"):
        log("Installing Renode via Homebrew Cask...")
        result = run(["brew", "install", "--cask", "renode"], check=False)
        if result.returncode == 0:
            ok("Renode installed via brew --cask renode")
            return
        warn("brew --cask renode failed - falling back to .dmg download")
    # Fallback: download portable archive matching this OS+arch.
    url = _renode_url()
    if not url:
        warn(f"No Renode URL for OS='{OS}' ARCH='{ARCH}'")
        return
    RENODE_LOCAL_DIR.mkdir(parents=True, exist_ok=True)
    archive = RENODE_LOCAL_DIR / url.split("/")[-1]
    download(url, archive)
    name = archive.name.lower()
    if name.endswith(".zip"):
        extract(archive, RENODE_LOCAL_DIR)
        flatten_single_top(RENODE_LOCAL_DIR)
        archive.unlink(missing_ok=True)
        ok(f"Renode (portable) installed at {RENODE_LOCAL_DIR}")
        print(f"  Add to PATH: {RENODE_LOCAL_DIR}")
    elif name.endswith(".tar.gz") or name.endswith(".tar.xz") or name.endswith(".tgz"):
        extract(archive, RENODE_LOCAL_DIR)
        flatten_single_top(RENODE_LOCAL_DIR)
        archive.unlink(missing_ok=True)
        ok(f"Renode (portable) installed at {RENODE_LOCAL_DIR}")
        print(f"  Add to PATH: {RENODE_LOCAL_DIR}")
    elif name.endswith(".dmg"):
        _install_renode_dmg(archive, RENODE_LOCAL_DIR)
        archive.unlink(missing_ok=True)
        ok(f"Renode (portable) installed at {RENODE_LOCAL_DIR}")
        print(f"  Add to PATH: {RENODE_LOCAL_DIR / 'bin'}")
    elif name.endswith(".deb"):
        run(["sudo", "dpkg", "-i", str(archive)], check=False)
        archive.unlink(missing_ok=True)
        ok("Renode .deb installed")
    else:
        warn(f"Don't know how to unpack Renode archive: {archive.name}")

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
        # pyocd is a pip console script; invoking via module avoids PATH issues
        [sys.executable, "-m", "pyocd", "--version"],
    ]
    for cmd in checks:
        label = cmd[0] if cmd[0] != sys.executable else "pyocd"
        try:
            out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True).split("\n")[0]
            ok(f"{label}: {out.strip()}")
        except Exception:
            warn(f"{label} — not found (may need PATH update)")

    renode_found = shutil.which("renode") or shutil.which("renode-test")
    if renode_found:
        ok("Renode found")
    else:
        warn("Renode — not in PATH (install manually or use portable zip in bootstrap/tools/renode)")

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

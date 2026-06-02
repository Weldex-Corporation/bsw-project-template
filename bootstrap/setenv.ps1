# BSW Project Template — Build environment shim
#
# Dot-source this once per PowerShell session before running cmake/ctest:
#
#     . .\bootstrap\setenv.ps1
#
# Adds discovered toolchain locations to $env:PATH for the current session
# only (no system PATH changes). Idempotent — safe to re-run.

$Root = Split-Path -Parent $PSScriptRoot

function Add-PathEntry {
    param([string]$Dir, [string]$Label)
    if (-not $Dir -or -not (Test-Path $Dir)) { return }
    $entries = $env:PATH -split ";"
    if ($entries -contains $Dir) { return }
    $env:PATH = "$Dir;$env:PATH"
    Write-Host ("  + {0,-22} {1}" -f $Label, $Dir) -ForegroundColor DarkGray
}

function Find-Renode {
    # Resolve renode.exe / renode-test.bat across known install layouts:
    #   1. MSI install (winget Renode.Renode) → %ProgramFiles%\Renode\bin
    #   2. winget portable cache
    #   3. Local portable zip extracted by setup.py
    $candidates = @(
        "$env:ProgramFiles\Renode\bin",
        "$env:ProgramFiles\Renode",
        "${env:ProgramFiles(x86)}\Renode\bin",
        "${env:ProgramFiles(x86)}\Renode",
        (Join-Path $Root "bootstrap\tools\renode\bin"),
        (Join-Path $Root "bootstrap\tools\renode")
    )
    # winget portable cache lives under a versioned/hashed dir
    $wingetCache = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
    if (Test-Path $wingetCache) {
        $candidates += @(Get-ChildItem $wingetCache -Filter "Renode.Renode_*" -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    }
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c "renode.exe"))      { return $c }
        if (Test-Path (Join-Path $c "renode-test.bat")) { return $c }
    }
    return $null
}

Write-Host "[setenv] BSW build environment" -ForegroundColor Cyan

# UTF-8 stdio for Python (avoids cp949 console crashes)
$env:PYTHONIOENCODING = "utf-8"
$env:PYTHONUTF8       = "1"

# MSYS2 ucrt64 (MinGW gcc, ninja, cmake — required by host-test preset)
Add-PathEntry "C:\msys64\ucrt64\bin" "MinGW ucrt64"

# ARM GCC (local-installed by bootstrap; not strictly needed since the
# toolchain file uses an absolute path, but exposing it lets you invoke
# arm-none-eabi-gcc directly)
$armBin = Join-Path $Root "bootstrap\tools\compilers\gnu-arm\13.3.rel1\bin"
Add-PathEntry $armBin "ARM GCC 13.3"

# Python Scripts dir (pyocd, robotframework, ninja installed via pip)
$pyCands = @(
    "$env:LOCALAPPDATA\Programs\Python\Python313",
    "$env:LOCALAPPDATA\Programs\Python\Python312",
    "$env:LOCALAPPDATA\Programs\Python\Python311"
)
foreach ($p in $pyCands) {
    if (Test-Path (Join-Path $p "python.exe")) {
        Add-PathEntry $p           "Python"
        Add-PathEntry "$p\Scripts" "Python Scripts"
        break
    }
}

# Python Launcher (py.exe) — renode-test.bat invokes `py -3`
$pyLauncher = "$env:LOCALAPPDATA\Programs\Python\Launcher"
Add-PathEntry $pyLauncher "Python Launcher"

# Renode (winget MSI or portable)
$renodeDir = Find-Renode
if ($renodeDir) {
    Add-PathEntry $renodeDir "Renode"
} else {
    Write-Host "  ! Renode not located — run bootstrap or install manually" -ForegroundColor DarkYellow
}

Write-Host "`n[setenv] Tool check:" -ForegroundColor Green
@(
    @{name="gcc";               label="host C compiler"},
    @{name="ninja";             label="build system"},
    @{name="cmake";             label="generator"},
    @{name="arm-none-eabi-gcc"; label="firmware compiler"},
    @{name="pyocd";             label="flashing"},
    @{name="renode-test";       label="SIL runner"}
) | ForEach-Object {
    $g = Get-Command $_.name -ErrorAction SilentlyContinue
    if ($g) {
        Write-Host ("  [OK] {0,-22} -> {1}" -f $_.name, $g.Source) -ForegroundColor Green
    } else {
        Write-Host ("  [--] {0,-22} ({1}) not found" -f $_.name, $_.label) -ForegroundColor DarkYellow
    }
}
Write-Host ""

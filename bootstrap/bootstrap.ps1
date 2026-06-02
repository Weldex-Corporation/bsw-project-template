# BSW Project Template — Windows Bootstrap
# Run from project root: .\bootstrap\bootstrap.ps1 -Platform bsw-mcal-msp
#
# If you hit "running scripts is disabled on this system", launch via the
# included bootstrap.bat wrapper, which sets -ExecutionPolicy Bypass.
param(
    [string]$Platform = "",
    [switch]$SkipToolchain,
    [switch]$SkipRenode,
    [switch]$SkipBsw
)

# Deliberately NOT using Set-StrictMode/Stop here — native installers
# (winget, msys pacman) routinely emit benign stderr that would otherwise
# halt the script in PowerShell 5.1.
$ErrorActionPreference = "Continue"

$Root = Split-Path -Parent $PSScriptRoot

Write-Host "`n[bootstrap] BSW Project Template - Windows Setup" -ForegroundColor Cyan

# ── Execution policy (best effort) ───────────────────────────────────────────
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq "Restricted" -or $policy -eq "Undefined") {
    Write-Host "[bootstrap] Setting CurrentUser ExecutionPolicy to RemoteSigned..." -ForegroundColor Yellow
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
}

# ── Helpers ───────────────────────────────────────────────────────────────────
function Get-NativeStdout {
    # Run a native exe and capture stdout+stderr safely, without going through
    # PowerShell's 2>&1 wrapper (which turns stderr lines into ErrorRecords
    # and can halt the script under $ErrorActionPreference='Stop').
    param([string]$Exe, [string[]]$Arguments)
    # ProcessStartInfo.ArgumentList is .NET Core 2.1+; PS 5.1 uses .NET
    # Framework, so fall back to the single Arguments string.
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName               = $Exe
    $psi.Arguments              = ($Arguments -join " ")
    $psi.UseShellExecute        = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.CreateNoWindow         = $true
    try {
        $p = [System.Diagnostics.Process]::Start($psi)
        $out = $p.StandardOutput.ReadToEnd()
        $err = $p.StandardError.ReadToEnd()
        $p.WaitForExit()
        return ("$out`n$err").Trim()
    } catch {
        return ""
    }
}

function Find-RealPython {
    # Prefer known per-user / system install paths over PATH lookups,
    # which on Windows are polluted by the Microsoft Store python.exe stub.
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python310\python.exe",
        "$env:ProgramFiles\Python313\python.exe",
        "$env:ProgramFiles\Python312\python.exe",
        "$env:ProgramFiles\Python311\python.exe",
        "C:\Python313\python.exe",
        "C:\Python312\python.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    # Fallback: any python.exe on PATH that isn't the WindowsApps stub
    $all = @(Get-Command python  -All -ErrorAction SilentlyContinue) +
           @(Get-Command python3 -All -ErrorAction SilentlyContinue)
    foreach ($g in $all) {
        if ($g -and $g.Source -and ($g.Source -notlike "*\WindowsApps\*")) {
            return $g.Source
        }
    }
    return $null
}

function Test-PythonOK {
    param([string]$Exe)
    if (-not $Exe -or -not (Test-Path $Exe)) { return $false }
    $ver = Get-NativeStdout -Exe $Exe -Arguments @("--version")
    if ($ver -match "Python\s+3\.(\d+)") {
        if ([int]$Matches[1] -ge 8) {
            Write-Host "[bootstrap] Found: $ver" -ForegroundColor Green
            Write-Host "[bootstrap]   at: $Exe" -ForegroundColor DarkGray
            return $true
        }
    }
    return $false
}

function Refresh-PathFromRegistry {
    $m = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $u = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:PATH = "$m;$u;$env:PATH"
}

# ── Python check ──────────────────────────────────────────────────────────────
$python = Find-RealPython
if (-not (Test-PythonOK $python)) { $python = $null }

if (-not $python) {
    Write-Host "[bootstrap] Python 3.8+ not found - installing Python 3.12 via winget..." -ForegroundColor Yellow
    & winget install --id Python.Python.3.12 --silent `
        --accept-source-agreements --accept-package-agreements
    # winget may exit non-zero if already installed; that's fine — re-scan.
    Refresh-PathFromRegistry
    $python = Find-RealPython
    if (-not (Test-PythonOK $python)) {
        Write-Host "[bootstrap] ERROR: Python install completed but a usable python.exe was not found." -ForegroundColor Red
        Write-Host "  Hint: Settings -> Apps -> App execution aliases -> turn OFF the Microsoft Store python.exe alias," -ForegroundColor Yellow
        Write-Host "        then open a NEW PowerShell window and re-run this script." -ForegroundColor Yellow
        exit 1
    }
}

# Make sure Python's Scripts dir is on PATH so pip-installed CLIs work in this session
$pyDir = Split-Path -Parent $python
$env:PATH = "$pyDir;$pyDir\Scripts;$env:PATH"

# Force UTF-8 for Python stdio so non-ASCII chars (em-dash, check marks) in
# setup.py print() don't crash on cp949 / non-UTF-8 console codepages.
$env:PYTHONIOENCODING = "utf-8"
$env:PYTHONUTF8       = "1"

# ── Run setup.py ──────────────────────────────────────────────────────────────
$setupScript = Join-Path $PSScriptRoot "setup.py"
$argsList    = @($setupScript)
if ($Platform)       { $argsList += @("--platform", $Platform) }
if ($SkipToolchain)  { $argsList += "--skip-toolchain" }
if ($SkipRenode)     { $argsList += "--skip-renode" }
if ($SkipBsw)        { $argsList += "--skip-bsw" }

Write-Host "[bootstrap] Running setup.py via $python ..." -ForegroundColor Cyan
& $python @argsList
$rc = $LASTEXITCODE
if ($rc -ne 0) {
    Write-Host "[bootstrap] setup.py exited with code $rc" -ForegroundColor Red
    exit $rc
}
Write-Host "[bootstrap] Done." -ForegroundColor Green

# BSW Project Template — Windows Bootstrap
# Run from project root: .\bootstrap.ps1 [--platform bsw-mcal-msp]
param(
    [string]$Platform = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

Write-Host "`n[bootstrap] BSW Project Template — Windows Setup" -ForegroundColor Cyan

# ── Python check ──────────────────────────────────────────────────────────────
$python = $null
foreach ($cmd in @("python", "python3", "py")) {
    try {
        $ver = & $cmd --version 2>&1
        if ($ver -match "Python 3\.(\d+)") {
            if ([int]$Matches[1] -ge 8) {
                $python = $cmd
                Write-Host "[bootstrap] Found: $ver" -ForegroundColor Green
                break
            }
        }
    } catch {}
}

if (-not $python) {
    Write-Host "[bootstrap] Python 3.8+ not found. Installing via winget..." -ForegroundColor Yellow
    try {
        winget install Python.Python.3.12 --silent --accept-source-agreements --accept-package-agreements
        $env:PATH = "$env:LOCALAPPDATA\Programs\Python\Python312;$env:LOCALAPPDATA\Programs\Python\Python312\Scripts;$env:PATH"
        $python = "python"
        Write-Host "[bootstrap] Python installed" -ForegroundColor Green
    } catch {
        Write-Host "[bootstrap] ERROR: winget failed. Install Python 3.8+ from https://python.org and re-run." -ForegroundColor Red
        exit 1
    }
}

# ── Execution policy ─────────────────────────────────────────────────────────
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq "Restricted") {
    Write-Host "[bootstrap] Setting execution policy to RemoteSigned for current user..." -ForegroundColor Yellow
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
}

# ── Run setup.py ─────────────────────────────────────────────────────────────
$setupScript = Join-Path $PSScriptRoot "setup.py"
$args_list   = @($setupScript)
if ($Platform) { $args_list += "--platform"; $args_list += $Platform }

Write-Host "[bootstrap] Running setup.py..." -ForegroundColor Cyan
& $python @args_list
if ($LASTEXITCODE -ne 0) {
    Write-Host "[bootstrap] setup.py failed (exit $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "`n[bootstrap] Done. Tool paths have been added to your User PATH." -ForegroundColor Green
Write-Host "            Restart this terminal (or open a new one) for PATH to take effect." -ForegroundColor Yellow

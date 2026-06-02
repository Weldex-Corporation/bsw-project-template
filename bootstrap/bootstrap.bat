@echo off
REM bootstrap.bat - launches bootstrap.ps1 bypassing the default
REM Restricted ExecutionPolicy on Windows Home editions.
REM Usage:  bootstrap.bat [-Platform bsw-mcal-msp]

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0bootstrap.ps1" %*
exit /b %ERRORLEVEL%

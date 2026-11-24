@echo off
setlocal
cd /d "%~dp0"

rem Prefer PowerShell 7; fall back to the built-in 5.1
where pwsh >nul 2>nul
if errorlevel 1 (
    set "PSEXE=powershell"
) else (
    set "PSEXE=pwsh"
    rem pwsh emits UTF-8; console codepage must match or Chinese becomes boxes
    chcp 65001 >nul
)

if "%~1"=="" (
    "%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Check-GTA.ps1"
) else (
    "%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Check-GTA.ps1" -GameDir "%~1"
)

echo.
pause
@echo off
setlocal

cd /d "%~dp0"

where pwsh >nul 2>nul
if errorlevel 1 (
    echo Can not find PowerShell 7.
    echo Please install PowerShell 7 to play ONE MORE DAY.
    pause
    exit /b 1
)

pwsh -NoProfile -ExecutionPolicy Bypass -File ".\main.ps1"

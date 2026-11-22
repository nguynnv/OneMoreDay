@echo off
setlocal

cd /d "%~dp0"

where pwsh >nul 2>nul
if errorlevel 1 (
    echo Can not find PowerShell 7.
    echo Please install PowerShell 7 to run the Helper.
    pause
    exit /b 1
)

start "ONE MORE DAY - HELPER" pwsh -NoProfile -ExecutionPolicy Bypass -File ".\tools\helper.ps1" -Root "%~dp0"

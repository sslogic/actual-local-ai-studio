@echo off
title Mayniak AI Studio Setup
cd /d "%~dp0"

if not exist "scripts\setup.ps1" (
    echo Setup file not found: scripts\setup.ps1
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup.ps1"
if errorlevel 1 (
    echo.
    echo Setup failed.
    pause
    exit /b 1
)

exit /b 0

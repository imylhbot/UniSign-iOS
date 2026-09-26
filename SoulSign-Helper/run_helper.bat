@echo off
chcp 65001 >nul
title SoulSign 电脑助手 Pro
cd /d "%~dp0"

if exist "SoulSign-Helper.exe" (
    start "" "SoulSign-Helper.exe"
    exit /b 0
)

if exist "dist\SoulSign-Helper.exe" (
    start "" "dist\SoulSign-Helper.exe"
    exit /b 0
)

if exist "soulsign_helper_gui.py" (
    start "" pythonw soulsign_helper_gui.py
    if %ERRORLEVEL% NEQ 0 (
        python soulsign_helper_gui.py
    )
    exit /b 0
)

echo [!] 未找到 SoulSign-Helper.exe 或 soulsign_helper_gui.py。
pause

@echo off
chcp 65001 >nul
title UniSign 电脑端助手 v2.0 - 启动中...

echo ========================================================
echo         UniSign 电脑端助手 (UniSign Helper v2.0)
echo   支持 USB 手机连接、Apple ID / P12 签名、iOS 16+ 开发者模式开启
echo ========================================================
echo.

cd /d "%~dp0"

echo [*] 正在启动图形界面...
python unisign_helper_gui.py

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [!] 启动时出现异常，请检查 Python 及 PySide6 环境。
    pause
)

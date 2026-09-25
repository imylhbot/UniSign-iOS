@echo off
chcp 65001 >nul
title UniSign 电脑助手 - EXE 一键打包工具
echo ========================================================
echo       UniSign 电脑端助手 (UniSign-Helper) EXE 一键打包
echo ========================================================
echo.

cd /d "%~dp0"

echo [*] 检查并安装打包所需依赖...
python -m pip install --upgrade pip
pip install PySide6 cryptography requests pycryptodome pyinstaller

echo.
echo [*] 开始通过 PyInstaller 编译单文件 Windows 可执行程序...
pyinstaller --onefile --noconsole --clean --name "UniSign-Helper" unisign_helper_gui.py

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [√] 编译成功！
    echo [*] 可执行文件位于: dist\UniSign-Helper.exe
    if not exist "..\package" mkdir "..\package"
    copy /y "dist\UniSign-Helper.exe" "..\package\"
    copy /y "run_helper.bat" "..\package\"
    copy /y "README.md" "..\package\"
    echo [*] 已就绪！直接运行 dist\UniSign-Helper.exe 即可。
) else (
    echo.
    echo [!] 编译失败，请检查 Python 及 PyInstaller 输出。
)

echo.
pause

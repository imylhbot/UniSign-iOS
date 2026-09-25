@echo off
chcp 65001 >nul
title UniSign 电脑助手 - EXE 一键打包工具
echo ========================================================
echo       UniSign 电脑助手 Pro (UniSign-Helper) EXE 一键打包
echo ========================================================
echo.

cd /d "%~dp0"

echo [*] 检查并安装打包所需依赖...
python -m pip install --upgrade pip
pip install PySide6 cryptography requests pycryptodome pyinstaller pillow

echo.
echo [*] 开始通过 PyInstaller 编译单文件 Windows 可执行程序 (嵌入 unisign.ico 图标)...
pyinstaller --onefile --noconsole --clean --icon="unisign.ico" --add-data "unisign.ico;." --add-data "unisign.png;." --name "UniSign-Helper" unisign_helper_gui.py

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [√] 编译成功！
    echo [*] 可执行文件位于: dist\UniSign-Helper.exe
    if not exist "..\package" mkdir "..\package"
    copy /y "dist\UniSign-Helper.exe" "..\package\"
    copy /y "run_helper.bat" "..\package\"
    copy /y "README.md" "..\package\"
    echo [*] 已就绪！直接双击 dist\UniSign-Helper.exe 即可运行。
) else (
    echo.
    echo [!] 编译失败，请检查 Python 及 PyInstaller 输出。
)

echo.
pause

@echo off
chcp 65001 >nul
title SoulSign 电脑助手 - EXE 一键打包工具
echo ========================================================
echo       SoulSign 电脑助手 Pro (SoulSign-Helper) EXE 一键打包
echo ========================================================
echo.

cd /d "%~dp0"

echo [*] 检查并安装打包所需依赖...
python -m pip install --upgrade pip
pip install PySide6 cryptography requests pycryptodome pyinstaller pillow

echo.
if not exist "rcodesign.exe" (
    echo [*] 正在下载 Apple 代码签名引擎 (rcodesign.exe)...
    python -c "import urllib.request, zipfile, io; url = 'https://github.com/indygreg/apple-platform-rs/releases/download/apple-codesign%%2F0.29.0/apple-codesign-0.29.0-x86_64-pc-windows-msvc.zip'; data = urllib.request.urlopen(url, timeout=45).read(); z = zipfile.ZipFile(io.BytesIO(data)); [z.extract(f, '.') for f in z.namelist() if f.endswith('rcodesign.exe')]"
)

echo [*] 开始通过 PyInstaller 编译单文件 Windows 可执行程序 (嵌入 soulsign.ico 图标与签名引擎)...

set ADD_BINARY=
if exist "rcodesign.exe" (
    set ADD_BINARY=--add-binary "rcodesign.exe;."
)

pyinstaller --onefile --noconsole --clean --icon="soulsign.ico" --add-data "soulsign.ico;." --add-data "soulsign.png;." %ADD_BINARY% --name "SoulSign-Helper" unisign_helper_gui.py

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [√] 编译成功！
    echo [*] 可执行文件位于: dist\SoulSign-Helper.exe
    if not exist "..\package" mkdir "..\package"
    copy /y "dist\SoulSign-Helper.exe" "..\package\"
    if exist "rcodesign.exe" copy /y "rcodesign.exe" "..\package\"
    copy /y "run_helper.bat" "..\package\"
    copy /y "README.md" "..\package\"
    echo [*] 已就绪！直接双击 dist\SoulSign-Helper.exe 即可运行。
) else (
    echo.
    echo [!] 编译失败，请检查 Python 及 PyInstaller 输出。
)

echo.
pause

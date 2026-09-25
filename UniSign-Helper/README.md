# UniSign Helper (电脑端助手) v2.0

UniSign 桌面端配套助手，用于通过 USB 数据线将 `UniSign.ipa`（或任意第三方 IPA）一键签名并安装到 iPhone / iPad 设备，并针对 iOS 16+ 高版本系统自动开启手机的「开发者模式」。

---

## ✨ 核心特性

1. **USB 极速直连与设备识别**：
   - 基于原生 Apple Mobile Device 协议（`usbmuxd` 端口 27015），实时识别连接的设备型号、iOS 系统版本、UDID 与信任状态。
2. **iOS 16+ 开发者模式一键激活**：
   - 自动检测设备 iOS 版本。针对 iOS 16.0 及以上设备，对接 `com.apple.amfi.lockdown` 接口，一键发送激活指令引导手机开启「开发者模式」。
3. **Apple ID 免费签名 (7 天)**：
   - 使用普通免费 Apple ID 进行 GrandSlam 认证握手，自动申请个人开发证书与 Provisioning Profile 并完成 Mach-O 代码签名。
4. **P12 开发者/企业证书签名**：
   - 支持导入企业或个人 `.p12` 证书与 `.mobileprovision` 描述文件进行批量或单应用重签。
5. **USB 免越狱 1-Click 安装**：
   - 通过手机文件传输通道（AFC）自动将应用缓存至 `PublicStaging`，并调用 `com.apple.mobile.installation_proxy` 执行系统级安装，直接在手机桌面上生成应用图标！

---

## 🚀 启动与使用方式

### 方式一：直接双击运行（最简方式，无需 Python）
在解压目录中，直接双击运行：
👉 **`UniSign-Helper.exe`**
*(无需配置 Python 环境，无需命令行，带有应用专属高清图标)*

### 方式二：双击批处理脚本
双击 **`run_helper.bat`** 会自动拉起 `UniSign-Helper.exe`。

### 方式三：开发者源码运行
```bash
cd UniSign-Helper
python -m pip install -r requirements.txt  # 或 pip install PySide6 cryptography requests pycryptodome
python unisign_helper_gui.py
```

---

## 📱 使用步骤

1. **连接手机**：
   - 使用 USB 数据线连接 iPhone 与电脑。
   - 解锁手机屏幕，若弹出提示请点击 **「信任此电脑」**。
2. **开启开发者模式（仅 iOS 16+ 需要）**：
   - 助手检测到设备为 iOS 16+ 时，点击面板上的 **「一键开启开发者模式」**。
   - 手机屏幕将弹出重启提示，点击重启并在开机后输入锁屏密码确认开启。
3. **选择待签 IPA**：
   - 助手会自动检测当前工程构建的 `UniSign.ipa`，也可点击 **「浏览...」** 选择其他安装包。
4. **签名并安装**：
   - 在 **「Apple ID 免费签名」** 栏输入你的 Apple ID 账号与密码（支持 2FA 双重验证）。
   - 点击 **「🚀 一键签名并安装到手机」**。
   - 等待传输与校验完成，即可在手机桌面上直接打开使用 UniSign！

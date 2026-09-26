# SoulSign-iOS (iOS 本地签名与深度定制工具 v2.5)

<p align="center">
  <img src="soulsign.png" width="128" height="128" alt="SoulSign Logo" />
</p>

SoulSign 是一款专为 iOS 设备（支持 iOS 15.0 及以上版本）设计的**纯本地、免电脑、免越狱**的 IPA 代码签名与应用深度定制神器。同时配套提供 Windows 电脑端助手 **SoulSign Helper Pro**，实现全场景免越狱安装与设备管理。

---

## 🌟 核心功能一览

### 1. 纯本地安全代码签名 (Pure On-Device Code Signing)
- **多 Apple ID 账号中心**：支持添加、持久化保存多个 Apple ID，随时在界面中一键切换活跃账号。
- **7 天自动续期 (1-Click Renewal)**：对于 Apple ID 签名的应用，智能记录关联账号与签名元数据。当证书临近到期或已过期时，点击“🔄 一键续期”全自动向苹果服务器申请最新描述文件并完成 Mach-O 代码重签，一秒刷新 7 天生命周期。
- **P12 证书状态与有效期实时计算**：导入 P12 证书后，精准计算剩余有效天数（例如“剩余 185 天”或“已过期”），到期时间一目了然。

### 2. Safari 一键获取真实物理 UDID (OTA Profile Extraction)
- 内置专用 MobileConfig 描述文件服务器。
- 在「证书与 UDID」管理界面点击 **「⚡ Safari 一键获取真实物理 UDID」**，即可直接跳转 Safari 调出系统安装描述文件，1 秒回传精确的设备真实物理 UDID 与序列号，告别复杂的第三方网页或 iTunes 查询！

### 3. 本地 HTTPS 服务与一键 OTA 安装
- 内置轻量级本地 HTTPS 服务器与自我签发的临时 SSL 证书。
- 签名完成后支持直接通过 `itms-services://` 协议本地无感 OTA 安装到 iPhone。
- 同时支持 **TrollStore（巨魔商店）** URL Scheme 一键无签名限制秒装。

### 4. 深度定制与 Mach-O 动态库 (Dylib) 注入
- **应用信息修改**：自由修改 Bundle Identifier、应用显示名称、版本号与构建号。
- **系统限制解锁**：一键解除最低 iOS 版本限制（`MinimumOSVersion`）。
- **文件沙盒互通**：一键注入 `UIFileSharingEnabled` 与 `LSSupportsOpeningDocumentsInPlace`，开启系统“文件”App 自由导入导出应用沙盒文档。
- **自定义图标**：从手机相册一键选取图片替换应用图标。
- **Mach-O 插件管理**：纯 Swift 解析 64 位 Mach-O 二进制文件，支持 `LC_LOAD_DYLIB` 动态库一键注入与定位移除。

### 5. 配套 Windows 电脑端助手 (SoulSign Helper Pro)
- 位于 `UniSign-Helper/` 目录，无需配置环境，解压即用。
- **USB 设备识别**：基于原生 `usbmuxd` 协议识别设备型号与系统状态。
- **iOS 16+ 开发者模式一键激活**：调用 AMFI 协议发送激活指令，一键唤起手机开发者模式。
- **集成 rcodesign 签名引擎**：支持使用免费 Apple ID 或个人/企业 P12 证书离线/在线极速签名并通过 AFC 通道直装到手机。

---

## 🚀 GitHub Actions 手动打包与 Releases 下载

推送最新代码至仓库后，你可以随时在 GitHub 网页上手动触发一键打包发布：

1. 打开你的 GitHub 仓库主页：`https://github.com/imylhbot/UniSign-iOS`
2. 点击上方的 **Actions** 选项卡。
3. 在左侧列表中点击 **`Build & Release SoulSign iOS & PC Helper`**。
4. 在右侧点击 **Run workflow** 下拉按钮：
   - 输入本次发布的版本号（例如 `v2.5.0`）。
   - 点击绿色的 **Run workflow** 按钮启动构建。
5. 等待 2~3 分钟构建完成后：
   - 进入仓库主页右侧的 **Releases** 栏目；
   - 即可看到最新发布的 Release，下载附件中的 **`SoulSign.ipa`** 或 **`SoulSign-Helper-Windows.zip`**！

---

## 📱 手机端安装与使用步骤

1. **下载安装包**：从 GitHub Release 下载 `SoulSign.ipa`。
2. **安装到手机**：
   - **推荐方式一（巨魔商店 TrollStore）**：直接分享到 TrollStore 点击「Install」，永久免签名使用。
   - **推荐方式二（SoulSign 电脑助手 Pro）**：使用数据线连接电脑，打开 `SoulSign-Helper.exe`，拖入 IPA 点击「一键签名并安装」。
   - **方式三（AltStore / SideStore / 牛蛙助手）**：使用第三方签名工具自签安装。
3. **开始使用**：
   - 切换到 **证书管理** 标签页，点击「⚡ Safari 一键获取真实物理 UDID」，或导入你的 `.p12` / 添加 Apple ID。
   - 切换到 **应用库** 标签页，点击右上角 `+` 导入需要签名的 IPA 或 `.dylib` 插件。
   - 点击导入的 IPA 进入定制页面，修改信息、注入插件并一键完成签名与安装！

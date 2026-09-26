# SoulSign-iOS (iOS 多 Apple ID 本地签名与应用管理工具)

<p align="center">
  <img src="soulsign.png" width="128" height="128" alt="SoulSign Logo" />
</p>

SoulSign 是一款专为 iOS 设备（适配 iOS 15.0 及以上版本）打造的**纯本地、免电脑、免越狱**的多 Apple ID 签名与应用管理工具。深度参考 **SideStore**、**Pastel-macOS** 与 **ipatool.ts** 的先进架构设计，提供多 Apple ID 统一管理、免费账号 3 个 App 配额管控、登录有效性检测、一键自动续签等强大特性。同时配套提供 Windows 电脑端助手 **SoulSign Helper Pro**，实现全场景免越狱安装与设备管理。

---

## 🌟 核心功能一览

### 1. 多 Apple ID 账号管理与 SideStore 登录架构
- **深度参考 SideStore / Pastel / ipatool 登录体系**：集成 GrandSlam 与 Anisette 协议验证机制，支持 Apple ID 双重认证（2FA 验证码输入）与 WebAuth 降级登录，无需依赖电脑即可在设备端直接登录 Apple 开发者服务。
- **多账号无缝切换与持久化**：支持添加、管理多个 Apple ID 账号，安全加密保存会话凭据，并可在证书管理中心或签名弹窗中任意切换活跃签名账号。

### 2. 单 Apple ID 严格 3 个 App 配额限制
- **免费开发者配额管控**：苹果对免费个人 Apple ID 限制最多在设备上激活 3 个 App。SoulSign 对每个 Apple ID 实时统计已签名的活跃 App 数量。
- **配额可视化进度条**：在证书管理界面清晰展示配额占用（如 `0/3`、`1/3`、`2/3`、`3/3`）与可用余量。
- **智能防超额拦截**：签名时若所选账号已达到 3 个 App 上限，系统自动阻断并提示切换其他 Apple ID 或清理已卸载/过期应用，避免向苹果服务器触发多余的证书请求失败。

### 3. Apple ID 登录有效性检测 (Session Health Check)
- **苹果开发者接口探测**：主动请求 Apple Developer Portal 接口（如 `listTeams` / `viewDeveloper`）验证当前 Cookie 与 GrandSlam Token 的真实有效性。
- **直观状态指示与检测时间**：
  - 🟢 **有效**：会话正常，可立即进行免密签名。
  - 🔴 **会话已失效**：Cookie 或 Token 已被苹果注销，点击可一键调起重新认证。
  - 🟡 **需双重验证**：需输入 2FA 短信或弹窗 6 位验证码。
  - ⚪ **未检测**：尚未执行探测。
- **一键全量检测与下拉刷新**：支持对单个账号独立检测，也支持点击「🔍 检测所有账号」或在列表顶部下拉刷新，批量校验全部已绑定的 Apple ID。

### 4. 智能一键续签 (1-Click Renewal)
- **多维度续签**：
  - **按账号一键续签**：在每个 Apple ID 卡片中点击「⚡ 一键续签」，自动为该账号下的所有活跃 App 向苹果申请最新描述文件并完成重签，刷新 7 天生命周期。
  - **全局一键续签**：在应用库中一键批量刷新所有已签名的应用。
  - **单 App 独立续签**：针对单个临期应用快速续期。
- **全自动 Mach-O 重签**：利用内置纯本地签名引擎，秒级更新 Provisioning Profile 与 Code Signature。

### 5. Safari 一键获取真实物理 UDID (OTA Profile Extraction)
- 内置专用 MobileConfig 描述文件服务器。
- 在「设置」界面点击 **「⚡ Safari 一键获取真实物理 UDID」**，即可直接跳转 Safari 调出系统安装描述文件，1 秒回传精确的设备真实物理 UDID 与序列号，告别复杂的第三方网页或 iTunes 查询！

### 6. 本地 HTTPS 服务与一键 OTA 安装
- 内置轻量级本地 HTTP 服务器与自我签发的临时 SSL 证书。
- 签名完成后支持直接通过 `itms-services://` 协议本地无感 OTA 安装到 iPhone。
- 同时支持 **TrollStore（巨魔商店）** URL Scheme 一键秒装。

### 7. 深度定制与 Mach-O 动态库 (Dylib) 注入
- **应用信息修改**：自由修改 Bundle Identifier、应用显示名称、版本号与构建号。
- **系统限制解锁**：一键解除最低 iOS 版本限制（`MinimumOSVersion`）。
- **文件沙盒互通**：一键注入 `UIFileSharingEnabled` 与 `LSSupportsOpeningDocumentsInPlace`，开启系统“文件”App 自由导入导出应用沙盒文档。
- **自定义图标**：从手机相册一键选取图片替换应用图标。

### 8. 配套 Windows 电脑端助手 (SoulSign Helper Pro)
- 位于 `SoulSign-Helper/` 目录，无需配置复杂环境，解压即用。
- **USB 设备识别**：基于原生 `usbmuxd` 协议识别设备型号与系统状态。
- **iOS 16+ 开发者模式一键激活**：调用 AMFI 协议发送激活指令，一键唤起手机开发者模式。
- **集成 rcodesign 签名引擎**：支持使用免费 Apple ID 或个人/企业 P12 证书离线/在线极速签名并通过 AFC 通道直装到手机。

---

## 🚀 GitHub Actions 手动打包与 Releases 下载

推送最新代码至仓库后，你可以随时在 GitHub 网页上手动触发一键打包发布：

1. 打开你的 GitHub 仓库主页；
2. 点击上方的 **Actions** 选项卡；
3. 在左侧列表中点击 **`Build & Release SoulSign iOS & PC Helper`**；
4. 在右侧点击 **Run workflow** 下拉按钮并输入版本号启动构建；
5. 构建完成后前往 Releases 栏目下载 **`SoulSign.ipa`**。

---

## 📱 手机端安装与使用步骤

1. **下载安装包**：从 GitHub Release 下载 `SoulSign.ipa`。
2. **安装到手机**：
   - **推荐方式一（巨魔商店 TrollStore）**：直接分享到 TrollStore 点击「Install」，永久免签名使用。
   - **推荐方式二（SoulSign 电脑助手 Pro）**：使用数据线连接电脑，打开 `SoulSign-Helper.exe`，拖入 IPA 点击「一键签名并安装」。
   - **方式三（SideStore / AltStore / 牛蛙助手）**：使用第三方签名工具自签安装。
3. **开始使用**：
   - 切换到 **账号中心** 标签页，添加你的一个或多个 Apple ID；
   - 随时点击「🔍 检测有效性」验证 Apple ID 登录状态；
   - 切换到 **签名** 标签页，导入需要签名的 IPA；
   - 选择任一未满额（< 3 个 App）的 Apple ID，一键完成签名与安装！

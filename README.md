# UniSign-iOS (iOS 本地签名与深度定制工具 v2.0)

UniSign 是一款专为 iOS 设备（支持 iOS 13.0 及以上版本）设计的纯本地、免电脑、免越狱的 IPA 签名与应用深度定制工具。

---

## 🌟 v2.0 升级核心特性

### 1. 多 Apple ID 账号中心与一键续期
- **多账号持久化**：支持添加、保存多个 Apple ID，随时在界面中一键切换当前活跃账号。
- **一键续期 (1-Click Renewal)**：对于 Apple ID 签名的应用（免费开发者账号 7 天限制），记录关联账号与签名元数据。当证书临近到期或过期时，点击“🔄 一键续期”即可全自动向苹果服务器申请最新描述文件并静默重签，刷新 7 天倒计时。

### 2. P12 证书状态与有效天数实时计算
- 导入 P12 证书并解密后，自动计算精确的剩余有效天数（例如“剩余 185 天”或“已过期”），到期时间一目了然。

### 3. 本机设备 UDID 查询与管理
- 界面内提供独立的“Device UDID”卡片，自动读取并格式化本机设备识别码，支持一键复制到剪贴板，或手动覆写为指定 UDID。

### 4. 内置资源管理中心 (已签/未签/插件 分栏浏览)
- **未签名 IPA 库 (Unsigned IPAs)**：集中查看从“文件”App 导入的原包，显示文件大小与导入时间，点击即可直接进入签名与定制页。
- **已签名应用库 (Signed Apps)**：卡片式展示已签名应用，包含应用图标、Bundle ID、版本、签名方式（P12 / 对应 Apple ID）以及**过期倒计时徽章**。支持一键 OTA 本地安装、一键续期、导出分享和删除。
- **插件库 (Dylibs)**：集中管理导入的 `.dylib` 插件，在定制界面可直接勾选一键注入。

### 5. 深度定制与 Mach-O 插件管理
- 修改 Bundle Identifier、应用名称、版本号与构建号。
- 解除最低 iOS 版本限制（`MinimumOSVersion`）。
- 一键注入 `UIFileSharingEnabled` 开启应用沙盒的“文件”App 访问。
- 从相册自由替换应用图标。
- 纯 Swift 解析 64 位 Mach-O，支持 `LC_LOAD_DYLIB` 动态库注入与定位移除。

### 6. GitHub Actions 手动云端打包与 Releases 自动发布
- 取消 push 自动触发，改为在 GitHub 网页手动点击触发（`workflow_dispatch`），方便修改代码后自主掌控打包时机。
- 编译完成后自动创建 **GitHub Release**，直接将生成好的 `UniSign.ipa` 上传至 Release 附件，无需在 Artifacts 里解压。

---

## 🚀 如何在 GitHub 手动打包并发布 Release？

推送最新代码至仓库后，你可以随时在 GitHub 网页上手动触发打包：

1. 打开你的 GitHub 仓库主页：`https://github.com/imylhbot/UniSign-iOS`
2. 点击上方的 **Actions** 选项卡。
3. 在左侧列表中点击 **`Manual Build & Release UniSign IPA`**。
4. 在右侧点击 **Run workflow** 下拉按钮：
   - 可输入本次发布的版本号（例如 `v1.0.0` 或 `v2.0.0`）。
   - 点击绿色的 **Run workflow** 按钮启动构建。
5. 等待 2~3 分钟，构建完成后：
   - 直接进入仓库主页右侧的 **Releases** 栏目；
   - 即可看到最新发布的 Release，点击附件中的 **`UniSign.ipa`** 直接下载安装！

---

## 📱 手机端安装与使用

1. 下载 GitHub Release 中的 `UniSign.ipa`。
2. 使用 **TrollStore（巨魔商店，强烈推荐）**、**AltStore**、**SideStore** 或 **牛蛙助手** 将 `UniSign.ipa` 安装到你的设备上。
3. 打开 UniSign：
   - 切换到 **Certs & UDID** 标签页，导入你的 `.p12` 证书或添加 Apple ID。
   - 切换到 **Library** 标签页，点击右上角 `+` 导入需要签名的 IPA 或插件。
   - 点击导入的 IPA 即可进入定制页面，修改信息、注入插件并一键完成签名！

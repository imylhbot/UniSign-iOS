# UniSign-iOS (iOS 本地 IPA 签名与深度定制工具)

UniSign 是一款专为 iOS 设备（支持 iOS 13.0 及以上版本）设计的纯本地、免电脑、免越狱的 IPA 签名与应用深度定制工具。

底层基于类似 `zsign` 的代码签名机制，结合 Mach-O 二进制解析、Info.plist 属性注入以及 Apple 免费开发者账号 GrandSlam 认证协议，实现了全部签名与定制流程在手机本机沙盒中闭环完成。

---

## 🌟 核心功能特性

### 1. 双重签名体系
- **P12 证书签名**：支持导入 `.p12` 证书文件（支持密码解密）与 `.mobileprovision` 描述文件，签名有效期取决于证书自身。
- **Apple ID 个人免费签名**：内置 Anisette 头部请求与 GrandSlam 认证客户端，支持免电脑输入 Apple ID 和密码（支持 2FA），全自动向苹果官方服务器申请 7 天有效期的免费开发者证书及描述文件并完成签名。

### 2. 深度 IPA 定制功能
- **Bundle ID 自定义**：自由修改应用的 `CFBundleIdentifier`，支持微信多开、同款 App 多版本并存。
- **显示名称自定义**：修改应用桌面图标下方显示的文字（`CFBundleDisplayName` 与 `CFBundleName`）。
- **版本号与构建号定制**：修改 `CFBundleShortVersionString` 和 `CFBundleVersion`。
- **解除最低 iOS 系统限制**：可任意下调 `MinimumOSVersion`（例如将要求 iOS 16 的应用下调至 iOS 13+ 兼容）。
- **开启沙盒“文件”访问权限**：自动注入 `UIFileSharingEnabled = true` 与 `LSSupportsOpeningDocumentsInPlace = true`，签名后可直接通过系统自带的“文件”App 访问和导出该应用沙盒文档。
- **应用图标自由替换**：从相册任意挑选一张图片，自动适配并替换应用桌面图标。

### 3. Mach-O 插件注入与管理
- **动态库注入**：导入任意 `.dylib` 插件，自动复制到 `Frameworks` 目录，并在 Mach-O 二进制头部注入 `LC_LOAD_DYLIB` 指令并重新对 dylib 进行签名。
- **动态库移除**：支持通过库文件名或路径，定位并安全移除 Mach-O 中的 `LC_LOAD_DYLIB` 指令及物理文件。

### 4. 本地一键安装 (Local OTA Install)
- 内置基于纯 Swift Network 框架实现的超轻量本地 Web 服务器。
- 签名完成后，通过本地监听端口构造 `manifest.plist`，使用 `itms-services://?action=download-manifest&url=...` 协议直接唤起 iOS 原生安装器一键完成安装，无需上传至任何第三方服务器。

---

## 🚀 部署至 GitHub 并通过 GitHub Actions 自动打包

本项目已完整配置 `.github/workflows/build.yml`，你无需在本地安装 Xcode，直接推送到 GitHub 仓库即可利用 GitHub Actions 免费云端构建并下载 `.ipa` 安装包。

### 部署步骤：
1. **在 GitHub 上创建一个新的仓库**（例如命名为 `UniSign-iOS`）。
2. **将本项目代码推送到你的 GitHub 仓库**：
   ```bash
   cd UniSign-iOS
   git init
   git add .
   git commit -m "feat: initial commit for UniSign-iOS"
   git branch -M main
   git remote add origin https://github.com/<你的用户名>/UniSign-iOS.git
   git push -u origin main
   ```
3. **查看打包流程**：
   - 打开你的 GitHub 仓库页面，点击上方的 **Actions** 选项卡。
   - 你会看到名为 `Build & Release UniSign IPA` 的工作流正在自动运行。
   - 构建通常需要 2~3 分钟。构建完成后，在工作流详情页底部的 **Artifacts** 区域即可直接下载编译生成的 `UniSign-IPA`（内含 `UniSign.ipa`）。

---

## 📲 如何在手机上安装 UniSign 本身？

由于 UniSign 是一个管理工具，首次将下载到的 `UniSign.ipa` 安装到 iOS 设备上有以下常见免越狱方式：
1. **TrollStore（巨魔商店，强烈推荐）**：支持 iOS 14.0 ~ 17.0 等特定版本的设备，直接用 TrollStore 共享打开 `UniSign.ipa` 即可永久免证书安装。
2. **AltStore / SideStore / Sideloadly**：使用电脑辅助一次性将 `UniSign.ipa` 安装到你的手机上。
3. **已有的自签工具**：如果你手机上已经有牛蛙助手、全能签、轻松签或 Scarlet，直接导入 `UniSign.ipa` 完成首次签名安装。

---

## 📂 项目结构概览

```text
UniSign-iOS/
├── .github/
│   └── workflows/
│       └── build.yml               # GitHub Actions 云端构建并输出 IPA
├── UniSign.xcodeproj/              # Xcode 工程配置
├── UniSign/
│   ├── App/
│   │   ├── AppDelegate.swift       # 应用入口
│   │   ├── SceneDelegate.swift     # iOS 13+ 场景支持 & 文档关联打开
│   │   └── Info.plist              # 权限声明与文件类型关联
│   ├── SigningEngine/
│   │   ├── ZSignBridge.h           # Objective-C++ 签名桥接头文件
│   │   ├── ZSignBridge.mm          # Security 框架与签名引擎桥接
│   │   └── AppleID/
│   │       ├── AnisetteClient.swift       # Anisette 头部请求客户端
│   │       └── AppleDeveloperService.swift# Apple ID 认证与证书/描述文件自动拉取
│   ├── IPAModifier/
│   │   ├── MachOModifier.swift     # 纯 Swift Mach-O 解析与 LC_LOAD_DYLIB 注入/移除
│   │   ├── PlistModifier.swift     # Info.plist 属性读取与批量定制
│   │   ├── IconReplacer.swift      # 应用图标自动缩放与资源替换
│   │   └── IPAManager.swift        # 解压、修改、注入、签名、重打包总调度
│   ├── LocalServer/
│   │   └── LocalInstallServer.swift# 本地轻量 Web 服务与 itms-services 安装服务
│   ├── Views/
│   │   ├── MainTabBarController.swift
│   │   ├── SignWorkflowViewController.swift       # 签名与定制主功能界面
│   │   ├── CertificateManagerViewController.swift # 证书与 Apple ID 管理界面
│   │   └── SettingsViewController.swift           # 本地端口与 Anisette 配置
│   └── UniSign-Bridging-Header.h
└── README.md
```

---

## ⚖️ 免责声明
本项目仅供 iOS 开发爱好者、逆向工程学习及个人合法应用测试使用，严禁用于任何侵犯他人软件著作权或违反法律法规的用途。

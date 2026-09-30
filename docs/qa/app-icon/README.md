# 游戏图标接入验证

日期：2026-09-30。

## 交付

- 图标资源：`Resources/Assets.xcassets/AppIcon.appiconset/`。
- 18 个 iPhone、iPad 与 App Store 图标槽，使用 13 个对应像素尺寸的 PNG 文件。
- App Store 图标 `AppIcon-1024.png` 为 1024×1024、8 位 RGB PNG，无 Alpha 通道。
- 原始生成图及完整提示词：`docs/art/app-icon-prompt.md`。
- 资源目录加入工程 Resources 编译阶段，`project.yml` 明确指定 `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`。

## 验证结果

- 检查全部 PNG 的 IHDR，实际尺寸与各图标槽一致，均为 RGB 色彩类型、没有 Alpha 通道。
- Release 的 iOS 真机平台未签名 Archive 成功；归档的 `Info.plist` 同时包含 `CFBundleIcons` 和 `CFBundleIcons~ipad`，主图标名称均为 `AppIcon`。
- 使用 `assetutil --info` 检查归档的 `Assets.car`，确认包含图标的各尺寸及 1024×1024 marketing rendition。
- Debug 模拟器构建通过；更新安装至现有 iPhone 17（iOS 26.4）模拟器，桌面显示新图标，点击图标后正常进入首页，成绩与进度仍显示。
- 桌面截图：[home-screen.png](home-screen.png)。
- 用 `project.yml` 在独立目录重新生成工程，确认资源目录及 AppIcon 设置均存在；原工作区工程未被重新生成覆盖。
- 本次工程变更仅增加四行资源引用，Bundle ID 与用户已有签名配置保持不变。

完整日志和未签名归档位于 `build/icon-qa/`，不纳入 Git。此次验证没有进行签名导出或向 App Store Connect 上传，云端是否接受仍需重新签名 Archive 后上传验证。旧归档不包含新图标。

配置依据：[Apple App Icon 配置文档](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)。

# Gummy Ricochet 改名验证

日期：2026-09-30。

- 产品名称与桌面名称：`Gummy Ricochet`；首页标题：`GUMMY RICOCHET`。
- 工程、Target、Scheme 与可执行文件：`GummyRicochet`。
- 保留已申请的 Bundle ID：`com.lxygame.gummydrop.prototype`。
- 保留工作区已有签名设置；此次提交不纳入用户先前的工程配置改动。

## 验证

- Debug、Release 的 iOS Simulator 构建通过；两个配置的产物均确认 `CFBundleName` 和 `CFBundleDisplayName` 为 `Gummy Ricochet`、Bundle ID 未变。
- 将拟提交内容导出为独立源码副本，Debug 模拟器构建通过，确认改名提交不依赖未提交的工程配置改动；日志：`build/rename-qa/build-staged-debug.log`。
- 在现有 iPhone 17（iOS 26.4）模拟器上安装更新并冷启动，首页新标题完整显示、未越出卡片；现有最佳成绩、关卡进度和 Resume 入口仍显示。
- 首页运行截图：[home.png](home.png)。截图保留模拟器原始帧方向，应用内容为横屏。
- 源码、工程配置与运行说明已检查，不再使用旧工程名、旧首页标题或 `LXYGame06 Prototype`；旧 Bundle ID 与历史验收材料保留。
- 完整构建日志保留于 `build/rename-qa/build-debug.log` 与 `build/rename-qa/build-release.log`，不纳入 Git。

此次验证覆盖名称、工程引用、编译产物与首页排版，不替代真机签名打包、App Store Connect 名称注册或完整玩法验收。

# iOS 27.1 / iPhone Duo 适配验收

日期：2026-10-09。使用本机 Xcode 27.1（27A9275）及已有模拟器。

原版本在 Xcode 控制台报 `Application failed to launch: UIScene life cycle is required for apps built with this SDK.`。本次采用单窗口 UIScene 配置，SceneDelegate 创建 UIWindowScene 窗口；AppDelegate 只负责进程启动。GDViewController 继续承载同一 SpriteKit 场景，按当前 view bounds 和四边安全区域缩放 1200×680 画布。窗口尺寸变化时暂停当前局；失活、后台和场景断开时暂停并存档，返回后保留暂停状态，玩家点击 Resume 后才继续。音频由场景激活状态控制。

## 已验证

- Debug：iOS 27.1 Simulator 构建通过，成功安装并正常启动首页，无原来的 UIScene 启动错误。
- Release：generic iOS 真机平台编译通过，关闭签名；不代表真机运行验收。
- 核心专项 816 条断言、5 项设置持久化检查通过。仅拟提交内容的隔离目录 Debug 完整编译也通过，确认本次提交不依赖既有未提交的界面和签名改动。完整摘要见 [checks.log](checks.log)。
- iPhone Duo（iOS 27.1）：实际点击 New Game、展开内屏、Resume、设备 Home、回到应用、折叠外屏、返回游戏首页和旋转设备。展开时保留原局并显示 PAUSED；内外屏尺寸变化均通过画布比例和安全区域运行断言。
- 真正进入后台约一分钟，音乐和音效停止。前后保存的 32 项游戏快照字段全部相同；回到同一进程后仍为 PAUSED，音乐保持暂停；再次折叠也未推进游戏状态。结果见 [background-comparison.json](background-comparison.json)，生命周期及布局日志见 [duo-lifecycle.log](duo-lifecycle.log)。
- iPhone 17 Pro（iOS 26.4.1）：同一个使用 27.1 SDK 构建的 Debug 包正常启动首页，场景激活后菜单音乐播放。只进行启动检查，保留原设备的玩家进度。

## 截图与复跑

[外屏首页](closed-home.png)、[内屏暂停](open-paused.png)、[iOS 26 首页](ios26-home.png) 为真实模拟器截图，未使用图片编辑或画面夹具。

打开 GummyRicochet.xcodeproj，运行 GummyRicochet。调试时可增加 `-qa-lifecycle` 参数，输出场景激活、暂停、音频和画布布局证据；Release 不含这些运行断言和日志。

原始构建日志和测试输出保留在忽略目录 `build/qa-ios27/`。最低系统仍为 iOS 15，但本机没有 iOS 15 runtime，因此没有声明 iOS 15 运行通过。真机、半折姿态、分屏和多触指仍未验收。Duo 模拟器在切屏期间曾短暂显示黑屏及 `no drawables available`，随后恢复正常画面；未将该模拟器瞬态当作应用崩溃或通过证据。

收尾重新启动 Duo 时，bootstatus 曾显示 `Data Migration Failed`，但退出码仍为 0；后续用正常参数启动游戏，进程采样显示主线程在正常事件循环中，重新连接 Device Hub 窗口后实际看到游戏结算页并点击 Home，最终首页正常显示且保留最新 910 分纪录。未据退出码将该迁移状态报告为成功。

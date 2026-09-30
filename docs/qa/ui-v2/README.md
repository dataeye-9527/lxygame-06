# UI v2 验证证据

2026-09-30，使用用户原有 iPhone 17（iOS 26.4）模拟器；本轮没有新建或启动其他模拟器。六张 PNG 是真实应用截图，仅将模拟器原始竖向缓冲旋转为横屏阅读方向，没有裁剪或合成。Help 在收尾安装最终 Debug 构建后重新截图，包含 WILD 的 `auto-match a color` 文案；其他五张复用已通过 PM 目视验收的最终截图。

| 文件 | 证明范围 |
| --- | --- |
| `home-final.png` | 开始页、连续全屏背景、New Game / Resume / Settings / How to Play |
| `game-final.png` | 普通触控后 395 分局面、18/17 列软糖棋盘、技能 / NEXT / HOLD / 三炮台 |
| `settings-final.png` | 三项独立设置及 On / Off 表现 |
| `help-final.png` | 操作说明、四技能短文案、WILD 自动匹配说明 |
| `paused-final.png` | 暂停操作、全屏遮罩连续性 |
| `result-final.png` | 普通真实局压行触发 Game Over、Retry / Home、全屏遮罩 |
| `core-focused.log` | 独立 macOS 核心测试：661 断言、453/453 有效角度 |
| `settings-tests.log` | 独立 macOS 设置测试：4 条持久化 / 独立设置检查 |
| `cold-restore-comparison.json` | 真实局冷恢复前后比较，19 项字段全部一致 |
| `aim-feedback.log` | 从真实运行完整日志提取的瞄准开关与非零 SystemSoundID 记录 |
| `build-summary.log` | 最终代码 Debug / Release 的 iOS Simulator 构建成功摘要 |

真实触控覆盖普通开局、Hold、左炮台切换、拖动射击、Pause → Settings → Back 仍暂停 → Resume、返回 Home，以及普通局压行失败。三项设置 Off 后重启仍 Off；收尾时已确认三项均 On，更新应用没有清空当前存档，Home 保留 Resume。冷恢复比较只覆盖 JSON 所列 19 个字段，原始前后快照保留在本地 `build/qa/ui-v2/`。

核心与设置脚本不是 XCTest，也不代表完整模拟器端到端测试。额外 24 种种子长局本轮曾超时，未完成；不计为通过。Debug QA 启动参数和日志仅在 DEBUG 构建启用。完整构建 / 运行日志、原始截图与临时产物留在被 Git 忽略的 `build/`，此目录归档必要小型证据。

尚未验证：真机音效听感与触感、其他屏幕比例、长期平衡。模式评估与正式名称仍待定。

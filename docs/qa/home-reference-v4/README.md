# 糖果界面复刻与全页风格验收

日期：2026-10-08。按用户最新的 GUMMY RICOCHET 双模式参考图复刻主页，并按追加要求统一其他游戏页面的美术风格。七个独立素材使用内置 imagegen 生成，由 SpriteKit 拼接；完整提示词、生成方式与资源清单见 [提示词](../../art/home-reference-v4/prompts.md) 和 [资源清单](../../art/home-reference-v4/asset-manifest.json)。

## 呈现与对齐

- 左侧保留双行糖果 Logo、四枚糖果、奶油发射器、蛋糕底座和动态 BEST 分数。
- 右侧为 ENDLESS、LEVELS 两张奶油卡片及三个功能按钮。无尽按钮收在卡片内部；没有有效存档时 Resume 置灰且不可点击。
- 文字按 CoreText 实际可见字形边界居中；系统图标先裁掉透明留白，再与文字按可见中心对齐。皇冠、BEST、数字共用一条水平中心线，数值较长时自动缩小至预留区域。
- 有关卡存档时 LEVELS 卡片显示 Select Level 和 Resume N，保留原有恢复入口。
- 游戏、帮助、设置、选关、排行榜、暂停和结算共用糖果背景、奶油面板、金色星饰及果冻按钮。游戏区保留深紫底衬，维持棋子与瞄准线的可读性。
- 通用奶油面板采用九块纹理拼接，按钮采用三块纹理拼接，边角随布局保持合理尺寸。所有切片直接定位于原始图集；原始生成图片及 alpha 完整保留，半透明面板叠在不透明奶油底色上。
- 动态分数、倒计时、能量及目标文字沿用 SKLabelNode 接口，由可见字形绘制和单一无障碍语义标签共同呈现。

## 验证结果

| 检查 | 结果 |
| --- | --- |
| Debug Simulator 构建 | BUILD SUCCEEDED |
| Release Simulator 构建 | BUILD SUCCEEDED |
| `scripts/test_settings.sh` | PASS: 4 persistent settings checks |
| `git diff --check` | 通过 |
| iPhone 17 Pro，iOS 26.4，横屏 | 布局与图标/文字居中已实屏确认，主按钮未越出卡片，皇冠未遮住分数 |
| iPad Air 13-inch (M3)，iOS 26.4，横屏 | 布局已实屏确认；较高屏幕由背景完整铺满 |
| Local Scores / Settings / Help / Select Level | 进入及返回主页正常 |
| 设置 On → Off → On | 新图标、文字和按钮状态正确，操作有效 |
| 真实关卡射击 | 棋盘更新，分数变为 180，黄色能量变为 18/20；动态字形正常 |
| Pause → Settings → Back | 保持暂停、180 分及倒计时状态 |
| 排行榜空状态与三页记录 | 无遮挡，Next / Previous / 末页边界正常；多页记录使用已有 DEBUG fixture |
| 关卡胜利结算 | 金色星星及四个按钮无越框，All Levels 入口有效；使用已有 `-qa-last-level` 表现 fixture |
| 无尽失败结算 | 三个按钮及最佳分/本地排名显示正常；由已有 `-qa-failure` 棋盘 fixture 触发实际失败路径 |
| 无有效无尽存档的 Resume | 置灰，点击无跳转 |
| New Game → Pause → Home → Resume | 正常恢复 ENDLESS |
| LEVEL 01 → Pause → Home → Resume 1 | 正常恢复 LEVEL 01 |
| 原 iPhone 模拟器持久化数据对比 | 全部偏好值与操作前相同，见 `player-data-comparison.json` |

实屏截图来自 Simulator 的原始帧，只按设备方向旋转，无视觉合成。iPhone 截图旋转 270°，iPad 截图旋转 90°。其他页面与 fixture 操作位于单独创建的 iPhone 测试设备，不覆盖原 iPhone 的玩家数据。关卡胜利截图仅证明结算表现，不代表实际通关验收。

| 页面 | 截图 |
| --- | --- |
| iPhone 主页，无关卡存档 | [home-phone.png](home-phone.png) |
| iPad 主页，双模式有存档 | [home-ipad.png](home-ipad.png) |
| 设置 | [settings.png](settings.png) |
| 帮助 | [help.png](help.png) |
| 选关 | [levels.png](levels.png) |
| 游戏 | [gameplay.png](gameplay.png) |
| 暂停 | [paused.png](paused.png) |
| 排行榜空状态 / 有记录 | [scores-empty.png](scores-empty.png) / [scores.png](scores.png) |
| 胜利 / 失败结算 | [result-win.png](result-win.png) / [result-loss.png](result-loss.png) |

本次未进行真机或 Archive 验证。构建使用 `CODE_SIGNING_ALLOWED=NO`；Xcode 输出的既有无效描述文件诊断不影响 Simulator 构建。完整构建日志保留在本地 `build/home-reference/`。

## 构建命令

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project GummyRicochet.xcodeproj -scheme GummyRicochet \
  -configuration Debug -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=32C8A380-995E-44FD-83D2-1695230AF4F7' \
  -derivedDataPath build/HomeReferenceDerivedData CODE_SIGNING_ALLOWED=NO build
```

Release 使用相同命令，将 `-configuration` 改为 `Release`。最终构建摘要见 `build-summary.log`。未改动已注册的 Bundle ID。此次提交只包含界面实现与生成素材，操作前已有的隐私政策及工程设置改动另行保留；设置截图中的 Privacy Policy 来自这些已有改动。

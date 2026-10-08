# 游戏结束与通关弹窗比例调整

日期：2026-10-08。将无尽失败、关卡失败、普通关卡通关及最后一关通关弹窗同步到已确认的暂停页比例。

## 布局

| 元素 | 调整前 | 最终 |
| --- | --- | --- |
| 失败面板 | 454 × 550 | 608 × 590 |
| 通关面板 | 454 × 550 | 608 × 630 |
| 操作按钮 | 286 × 57 | 512 × 96 |
| 按钮文字 / 图标尺寸 | 22.8 / 23–26.22 | 36 / 36 |
| 标题 / 分数文字 | 33 / 24 | 36 / 28 |
| 通关星星 / 条件文字 | 38 / 13 | 44 / 17 |

尺寸采用 1200 × 680 的 SpriteKit 场景坐标。所有弹窗共用同一按钮尺寸及点击范围计算，文字与图标延用按可见内容居中的绘制。失败页的三行按钮间隔一致；通关页适当增加高度，将星级、条件及四个操作按钮分别排开。Home 统一使用金色按钮。暂停页的已确认布局保持原比例。

## 验证

- Debug、Release Simulator 构建均通过，使用 `CODE_SIGNING_ALLOWED=NO`，按顺序执行；摘要见 [build-summary.txt](build-summary.txt)。
- `git diff --check` 通过。
- 全部画面与操作均使用当前已有的 iPhone 17 Pro 模拟器，iOS 26.4，设备 `32C8A380-995E-44FD-83D2-1695230AF4F7`。未启动或创建其他设备。
- 四种结算画面均无按钮越框、字形裁切、图标偏移及星级遮挡。普通通关显示 Next Level，最后一关显示 All Levels。
- Local Scores、关卡失败的 Levels、最后一关的 All Levels 入口均打开对应页面。
- 展示结束后用正常启动参数返回主页；BEST 6245、5 / 30 unlocked、12 ★、Resume 5 均保留。
- 验证前后所有持久化偏好值一致，见 [player-data-comparison.json](player-data-comparison.json)。

| 状态 | 截图 |
| --- | --- |
| 无尽失败，含本地排名 | [endless-loss.png](endless-loss.png) |
| 关卡失败 | [level-loss.png](level-loss.png) |
| 普通关卡通关 | [level-win.png](level-win.png) |
| 最后一关通关 | [last-level-win.png](last-level-win.png) |

截图来自当前 Simulator 的原始帧，仅旋转 270°，未进行视觉合成。为了检查多个结束状态而不覆盖现有玩家数据，扩展已有 DEBUG 结算展示机制：`-qa-result endless-loss / level-loss / level-win`，并保留 `-qa-last-level`。这些画面明确标注 QA FIXTURE，跳过存档与完成记录写入，仅允许返回主页、选关、排行榜等浏览操作。本次未点击会开始新游戏的 Retry、Replay、Next Level，也未将结算展示视为实际失败或通关验证。正常玩法与 Release 构建不使用这些展示参数。

本次未进行真机验证。完整构建日志保留在本地 `build/result-proportions/`。原有隐私政策和工程设置改动保留在工作区，未纳入此次提交。

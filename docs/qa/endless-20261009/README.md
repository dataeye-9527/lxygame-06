# 无尽模式弹药与 Buff 验收

日期：2026-10-09 至 2026-10-10。规则与全部 13 项 Buff 的等级、价格见 [设计记录](../../endless-economy.md)。新开无尽局启用新循环，关卡及旧格式存档保留原规则。

## 验证结果

| 检查 | 结果 | 范围 |
| --- | --- | --- |
| 弹药与 Buff 专项 | 2710 条断言通过 | 同色三合一及余数、技能来源回收、有限队列、购买与升级、断粮、技能联动、一次性保命、存档校验与兼容 |
| 既有核心专项 | 816 条断言通过 | 几何、连接与坠落、技能、队列、暂停、压行优先级、冷恢复；使用旧规则夹具，未运行完整 24 种子长局 |
| 关卡前向回放 | 30 / 30 通关，8948 条断言通过 | 30 个关卡布局，28 种连接拓扑；关卡仍使用原有无限队列 |
| Debug / Release | 两种 Simulator 构建通过 | Xcode 27.1，generic iOS Simulator，关闭签名；不代表真机运行 |
| SpriteKit 集成 | 6 个场景通过 | 实际运行引擎和场景控制方法，核对购买、升级、暂停、瞄准及渲染 |
| 玩家数据 | 测试前后相同 | 完整偏好字典比较，变更键为空；没有覆盖原有存档 |

专项中的生成局审计使用 8 个种子，完成 285 次实际引擎射击、118 次补给购买。这段有界审计未自然清空一波；正常清波、升级商店、商店暂停、选项稳定及跨波状态由单独的确定性射击夹具覆盖。它不证明长期经济平衡。检查摘要见 [checks.log](checks.log)。

## 模拟器界面与交互

复用已有 iPhone Duo 27.1 模拟器 `B4013321-6131-4C5A-98C6-09A661AE1FA6`，闭合外屏横屏。自动夹具标有 `QA FIXTURE`；以下截图直接取自运行中的模拟器，没有编辑。人工核对了文字、价格、库存计数和按钮布局。

- [战斗 HUD](flow.png)：库存、回收余数、独立 CREDITS、双保留槽。
- [升级商店](shop.png)：换色二级 350、保命 800、反弹万能三级 850。
- [补给](supply.png)：四色购买、换色额度、万能选色、范围/纵向爆破开关。
- [Buff 列表](buffs.png)：当前效果与下一档价格，超过六项时分页。
- [纵向爆破](cut.png)：合法目标与真实切割范围使用窄列预览。
- [保命触发](rescue.png)：清屏后进入下一波，显示 `RESCUE +3 AMMO`，不发放额外分数或回收材料。

自动 `flow` 调用真实场景控制方法，验证商店补弹、购买升级、补给暂停计时及取消已蓄力爆破、赠弹、换色、万能选色、纵向爆破开关、第二保留槽和 Buff 翻页。它不模拟触摸。日志见 [scene-controls.log](scene-controls.log)，六场景和偏好比较见 [report.json](report.json)。

另通过 Device Hub 的实际点击验证：买两发蓝弹时积分 1000 → 800、蓝色库存 4 → 7；Area → Cut 切换；万能 Auto → RED 选色；Buff 翻页；购买换色二级时积分 1000 → 650，显示 LV 2，下一档 600。[购买后的列表](manual-upgrade.png) 与 [人工点击记录](manual-report.json) 保留对应证据，商店点击前后偏好相同。这些点击使用 DEBUG 夹具，不是完整人工长局。

通过普通首页 Help → Endless 实际打开并检查了 [无尽帮助页](endless-help.png)，最终回到正常首页。保命图标使用内置生图模式生成，透明原图直接接入，完整提示词见 [素材记录](../../art/rescue-charm-prompt.md)。

## 复跑

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
scripts/test_economy.sh
scripts/test_core.sh --focused
scripts/test_campaign.sh
xcodebuild -project GummyRicochet.xcodeproj -scheme GummyRicochet \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/endless-derived CODE_SIGNING_ALLOWED=NO build
python3 scripts/qa_economy_simulator.py \
  --device B4013321-6131-4C5A-98C6-09A661AE1FA6 --display primary \
  --app build/endless-derived/Build/Products/Debug-iphonesimulator/GummyRicochet.app \
  --output build/endless-qa
```

Release 编译使用同一构建命令并将 configuration 改为 Release。完整原始日志保留在忽略目录 `build/`。

本机 iOS 27.1 曾在 `simctl launch --stdout/--stderr` 时返回未取得进程句柄；改用 `--console` 转发日志后成功运行六场景。Duo 默认截图可能选择非当前显示屏，本次显式使用 `primary` 并检查每张截图。脚本保留命令超时、启动就绪检查、失败信息和偏好比较。

真机、低版本系统运行及长期数值平衡尚未验收；短关的升级机会留给后续关卡适配。这些实现和测试不是 App Store 审核结论。

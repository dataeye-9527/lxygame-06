# 本轮体验、排行榜与关卡验收

2026-09-30。仅使用用户已有的 iPhone 17 / iOS 26.4，设备 UUID `6E23975F-15CB-45F9-9B46-AA0170B27963`；没有创建或启动其他模拟器。以下区分真实触控、核心回放和视觉夹具。`ui-v2` 是上一阶段历史证据。

| 验证层级 | 结果与证据 |
| --- | --- |
| 最终平台编译 | Debug、Release 的 generic iOS Simulator 构建均退出 0。见 `build-summary.log`；完整日志留在忽略目录 `build/qa/experience-v3/`。Release 有原有 `GDReadPoint` 未使用函数警告，无编译错误。未运行真机构建、签名或 XCTest。 |
| 核心正向回放 | 30/30 关真实引擎通关、8043 条断言；focused 回归 661 条断言通过。30 个颜色布局 hash、28 个初始几何，全部关卡有三星路径。详见 [campaign-validation.md](campaign-validation.md)，不是玩家难度或最短解证明。 |
| 设置与音效 | 四条设置检查通过；15 段原创 44.1 kHz PCM 无削波。AVAudioPlayer 实际巡检 14 个事件均 playing=1，最多 3 声部；Off 立即停止且后续请求不播放。见 [audio-review.md](audio-review.md)、`audio-runtime.json`、`settings-tests.log`。 |
| 最终资源 | 15 WAV 与源文件逐字节一致，8 PNG 数量、尺寸、alpha 均正确，`levels.json` 与最终目录 SHA 一致。Xcode CgBI 优化会改变 PNG 编码和非预乘 RGB；反解后的预乘通道误差小于 1/255，背景像素完全一致。见 `bundle-audit.json`。 |
| 工程同步 | `xcodegen generate --spec project.yml` 重生成前后 `project.pbxproj` 逐字节一致。见 `project-generation-check.json`。 |

## 真实模拟器触控

原有 1020 分无尽暂停局继续运行，经过自然压行触线失败，写入唯一一条本机成绩；终止再启动后榜单仍为这一条，旧 Best 5665 保留。`endless-result.png`、`scores-real.png` 和 `endless-record.json` 属于真实局证据。初始空榜与设置 Off 图记录早期状态，不代表最终收尾状态。

第一关使用正式 seed 20261001，真实 CUA 触控完成换台、反弹、Hold、BLAST 和 SWEEP，最终 980 分、两星；普通发射 10 次、红弹 1 次、直接移除 77、坠落 14、压行 1 次，活跃时间 39.6318 秒。发射数满足 ≤12，时间超过 35 秒，因此两星符合规则。真实结果曾在 CUA 中显示 LEVEL CLEAR；该时刻文件截图因相对路径被 simctl 拒绝而未归档，不使用视觉夹具替代它。可核对 `level1-real-record.json`、`level1-interaction.log`、`levels-unlocked-real.png` 和保存进度。

触控验收使用每段操作后的 Pause 留出工具读图时间；AX 等待仍计入部分活跃时间，确实发生一次压行。压行后根据真实暂停快照，在隔离测试 suite 中只读计算残局建议，再由 CUA 实际发射与施放 SWEEP；没有注入胜利、能量或棋盘。这验证操作可达、结算、通关和保存，不代表连续手速或首关平均难度。

修复了炮台拖动未收到 touchesMoved 时松手不发射的输入边界：明显位移按释放点重算预览，炮台点按仍只换台。真实 cannon-start 拖动、board-start 拖动和左台约 -67° 反弹均有效。炮台 tap、底部取消及界面控件未误射。多触指隔离经源码审查，CUA 不提供多触指输入，未宣称自动实测通过。

真实 Next Level 到达 Level 02 并 Pause → Home；另开真实无尽局并 Pause → Home。终止应用后两个 Resume 入口各恢复原局，两个存档各比较 32 项字段，全部相同，包含 runID、mode、levelID、棋盘、随机状态、队列、能量、计时与操作记录。见 `dual-restore-comparison.json`。最终保留独立的无尽与第二关暂停局。

`presentation-clock.log` 的 60/120 Hz 与抖动、飞行/结算暂停、万能/红弹冷恢复退款六项均为 1；启动此巡检前后整个持久偏好完全一致，见 `clock-persistence-comparison.json`。先前巡检产生的临时 0 分及 LastRun 污染已按真实局备份精确恢复；当前没有巡检成绩或夹具进度。

最终截图 `home-dual-resume-real.png` 显示两个恢复入口、2/30 解锁、2 星与 Best 5665；`levels-unlocked-real.png` 显示第一关两星及第二关解锁；`level2-resumed-real.png` 显示真实第二关收集/多波 HUD。`levels-chapter6-real.png` 使用最终目录（Level 28 为 36 gummies）检查后期目标与较长门槛文字，无重叠。

## 视觉夹具与媒体

`scores-page1-fixture.png`、`scores-page3-fixture.png` 使用 17 条内存成绩检查分页、排序呈现与末页按钮，画面标明 QA FIXTURE。`level30-result-fixture.png` 使用内存终态检查最终 All Levels 导航、黄色星动画及较长门槛文字，画面同样标明 QA FIXTURE。夹具不代表真实通关；Replay 被阻止，Home/Levels 可离开。最终末关巡检前后整个偏好完全一致，见 `fixture-persistence-comparison.json`。

`feedback-real.mp4` 为真实 Level 02 的约 9 秒无声录屏，包含炮台拖动、反弹与一次 8 颗消除（80 分），不包含技能、坠落或音频。`audio-preview.wav` 单独提供原创音效串列。原始录屏和截图保留在 `build/qa/experience-v3/`，归档截图仅作 90° 旋转；视频截取实际触控时段并旋转，没有改游戏状态。

## 收尾与边界

最终 Debug 已安装，应用以正常参数启动并停在 Home，方便用户继续试玩。当前唯一真实无尽榜单为 1020 分、旧 Best 为 5665；真实进度为第一关 980 分/两星、第二关已解锁。全部三项设置最终为 On。编译、核心回放、模拟器触控与视觉夹具不能替代真机扬声器/静音开关/耳机、触感、其他屏幕比例和长期平衡；这些仍待用户真机试玩。

复跑命令见主 README；30 关使用 `scripts/test_campaign.sh`，核心使用 `scripts/test_core.sh --focused`，设置使用 `scripts/test_settings.sh`。CLI 核心测试在 UUID defaults suite 中隔离，不写玩家偏好。

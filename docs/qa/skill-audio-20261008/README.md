# 爆炸、冰冻与 Music 开关修正

红色 BLAST 的蓄力加入点火火花；实际命中时，以碰撞球心为中心显示暖色闪光、两层冲击波、飞散火花和短暂烟团。蓝色 FREEZE 释放时显示冷雾和冰晶扩散，在冻结期间保留淡蓝霜边。爆炸范围与蓝色冻结 30 秒的规则沿用当前引擎。

Music 胶囊复用其他设置项的图标映射：开启显示 `✓ On`，关闭显示 `× Off`。模拟器运行截图见 [settings-on.png](settings-on.png) 与 [settings-off.png](settings-off.png)；两次切换后已恢复原有 Music On。

## 原创音效

| 文件 | 时长 | 听感设计 |
| --- | --- | --- |
| `blast_ready.wav` | 0.36 秒 | 低频点火、干燥火花，提示爆炸球已装填 |
| `blast.wav` | 0.82 秒 | 短促爆响、低频冲击与逐渐消散的余响 |
| `freeze.wav` | 0.90 秒 | 冷气扩散、不规则冰裂与冰晶共振尾音 |

均由 [generate_sfx.py](../../../scripts/generate_sfx.py) 本地原创合成，为 44.1 kHz、16-bit、单声道 WAV。试听 [skills-preview.m4a](skills-preview.m4a) 的顺序为红色蓄力、红色爆炸、蓝色冰冻。背景音乐、其余颜色的发射与消除声沿用上一轮资源。

## 验证

- Debug / Release iOS Simulator 编译通过，未增加第三方依赖。
- 音频资源检查通过：24 段音效与 2 段循环音乐的格式、有效信号、峰值、循环边界及构建包与源文件一致性。
- `scripts/test_core.sh --focused` 通过 816 项断言，包含技能、能量、暂停与续局恢复。
- 使用真实技能激活与发射流程：蓝色冻结剩余 30 秒，红色命中消除 14 球，运行日志确认对应音效实际开始播放。原始模拟器截图见 [freeze.png](freeze.png) 与 [blast.png](blast.png)，日志见 [skill-runtime.log](skill-runtime.log)。原始截图保留模拟器输出的像素方向。
- 图标开关通过可见界面核验；设置测试前后的玩家数据与偏好一致。原有项目文件、隐私页面与隐私资源未纳入本次改动。

Debug 可分别使用 `-qa-freeze-art -qa-feedback`、`-qa-blast-art -qa-feedback` 重现释放画面。演示使用独立新局并停在动画帧，禁止写入玩家续局快照。

## 存档对照与边界

原模拟器的关卡续局、关卡进度、最高分和排行榜保持一致；Endless 续局快照 `GummyRunSnapshot` 在本轮对照中发现缺失，原因未确认，未使用不匹配的旧快照覆盖。详细对照见 [player-state.json](player-state.json)。

最终在现有 iPhone 17 Pro 模拟器上重新执行冰冻、爆炸和正常主页启动；与复查前备份比较，当前玩家存档、记录与所有已有设置项保持一致。

真机扬声器、耳机下的最终听感及触感仍需试玩确认。模拟器编译、播放启动日志和渲染检查不代表真机听感验收。

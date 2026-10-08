# 背景音乐与四色音效

2026-10-08。音乐和音效均在本地原创合成，无外部录音、商业曲库或付费生成服务。资源在 `Resources/Audio/`，生成源在 `scripts/generate_music.py` 和 `scripts/generate_sfx.py`。

## 音乐与切换

悠闲版为 88 BPM、16 小节、约 43.64 秒的 C 大调循环，以柔和木琴主旋律、轻拨弦、暖低音、铺底和轻刷节奏配合软糖美术。急促版使用相同的旋律、和声与乐句结构，改为 132 BPM、约 29.09 秒，加入八分音符分解和弦、低鼓和短促节奏；不通过变速播放改变音高。

Home、设置和其他菜单播放悠闲版。游戏按存活球体的下边缘计算与危险线的距离：小于等于两行高度进入急促版，大于三行高度恢复悠闲版，中间区间保留当前版本以避免反复切换。冻结期间使用悠闲版；冻结到期后重新判断危险距离。两版切换按相同乐句位置对齐，并交叉淡化约 0.45 秒。暂停停止音乐时间线，Resume 续播；胜负结束停止循环并播放结算音效；进入后台或音频中断停止声音。

两段音乐采用立体声 44.1 kHz / 16-bit WAV，循环尾音折回开头，不在每次循环末端渐隐。实际 PCM 峰值、RMS 和接缝数据在 `music_manifest.json`，没有削波。游戏内音乐音量为 0.30，音效保留独立的较清晰音量。

[音乐试听](music-preview.m4a)：前 12 秒为悠闲版，随后为急促版。完整曲目为 `music_relaxed.wav` 和 `music_danger.wav`。

## 音效

新增蓝、红、黄、白各一段发射和消除音效：蓝色偏清凉钟音，红色偏低沉弹性，黄色明亮轻快，白色带较高的透明铃音。普通消除始终播放实际消除颜色的声音，悬空坠落和连消作为附加声部，最多同时三个音效声部。

保留按钮轻响、冻结、爆破、扫除、万能、充能完成、坠落、连消、胜利、Game Over 和无效操作；红色技能额外增加独立蓄力音，取消蓄力不会播放释放音。共 24 段音效，长度和 PCM 数据见 `manifest.json`。原有枚举数值兼容。

[音效试听](effects-preview.m4a)顺序：按钮；蓝色发射/消除；红色发射/消除；黄色发射/消除；白色发射/消除；冻结；红色蓄力；爆破；扫除；万能；坠落；连消；充能；胜利；Game Over；无效操作。

设置增加独立的 Music 开关，默认开启并持久化。Sound Effects Off 立即停止音效，音乐继续；Music Off 立即停止音乐，音效继续。四个设置项和现有隐私入口的布局见 `settings-music-off.png`、`settings-effects-off.png`。

## 验证

- Debug / Release iOS Simulator 构建通过，只有既有的 `GDReadPoint` 未使用警告；摘要见 `build-summary.txt`。
- 五项设置检查通过，覆盖默认值、重建后的持久化、存档保持和两个开关的独立性。
- `Tests/AudioAssetsTests.py` 对全部 26 段实际 WAV 检查格式、可听强度、削波、两个音乐循环接缝、四色波形差异；同时核对 Debug / Release 包中的音频与源文件一致。
- 应用内 AVAudioPlayer 巡检成功播放 23 种事件/颜色声音（另一个旧 Match 变体由资源检查覆盖），最多三个效果声部；独立静音、交叉淡化结束、生命周期通知模拟，以及耳机拔出通知后的暂停和 Music On 恢复均通过。见 `audio-runtime.log` 与 `audio-runtime.json`。
- 应用内确定性棋盘夹具覆盖靠近危险线、恢复阈值、冻结、冻结到期、暂停、恢复和 Game Over，见 `music-gameplay.log`。这是音乐状态检查，不是自然通关证据。
- 通过模拟器 UI 实际点击两个音频开关，检查布局，并从设置返回暂停页后确认音乐停止。巡检结束恢复音乐/音效为开启，正常启动保留原有玩家存档和关卡进度。

重建和验证命令：

```sh
uv run --with numpy scripts/generate_music.py
uv run scripts/generate_sfx.py
scripts/test_settings.sh
uv run --with numpy Tests/AudioAssetsTests.py path/to/GummyRicochet.app
xcrun simctl launch --console booted com.lxygame.gummydrop.prototype -qa-audio -qa-feedback
xcrun simctl launch --console booted com.lxygame.gummydrop.prototype -qa-music -qa-feedback
```

真机扬声器/耳机听感、硬件静音开关和真实电话中断尚未验证；通知模拟不替代这些真机检查。两段原始 WAV 共约 12.24 MiB，保留无压缩循环便于后续试听调整。

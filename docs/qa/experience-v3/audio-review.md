# 软糖音效实现与验证

2026-09-30。素材均为本仓库原创 PCM 合成，不依赖外部录音或付费服务。用 `python3 scripts/generate_sfx.py` 可重建全部 15 段 44.1 kHz / 16-bit / mono WAV；参数在脚本中，逐段时长、峰值、RMS 和削波样本数在 `Resources/Audio/manifest.json`。

此前六段音效只有短正弦扫频和音阶。本次替换为两层快速下滑共振、柔和的过滤噪声和少量钟音尾声。Tap 更短、更轻；Shot 用空气扫过表达发射；Match 使用三次略错开的软糖 pop，并有两个变体；Fall 用下降音高的四个 pop 和空气尾声表达成片坠落；Combo 使用上行亮音。FREEZE 为冰铃、BLAST 为低频软爆、SWEEP 为扫过气声、WILD 为四音亮铃；Ready、Win、Game Over 分别有独立短句。原有六个事件枚举值保持兼容。

播放由 `GDAudioFeedback` 管理，最多同时 3 个声部，同类事件至少间隔 45–60 ms。技能 / 连消替换按钮轻响，胜负结束先停止其他声；射击与消除有有限速率变化，大片事件可控制强度。输出音量最高 0.45，素材峰值最高约 0.68，保留多声部叠加余量。所有素材削波样本数为 0；时长 0.16–0.83 秒。

Sound Effects Off 立即停止正在播放的声音；设置存储仍与 Haptics、Aim Guide 相互独立。AVAudioSession 使用 Ambient，遵循静音开关并混合其他音频，后台和音频中断停止已有声音，不在返回时重播旧效果。未接入循环音乐。

本机通过 `afplay` 播放旧 Match 及新音效串列，串列归档为本目录的 `audio-preview.wav`。这里的播放和 PCM 数值检查不代替用户的主观听感确认；真机扬声器、静音开关、耳机音量和触感仍待真机验收。应用内通过专用 DEBUG 音效巡检真实调用 AVAudioPlayer，14 个事件均 `playing=1`，连续压力触发时最多 3 声部；Sound Effects Off 后立即变为 0 声部，下一次请求仍为 0，完成后恢复原设置。完整小型证据见 `audio-runtime.log` 与 `audio-runtime.json`。该巡检是音效接口验证，不是关卡成功的玩法证据。

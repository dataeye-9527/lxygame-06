"""Validate emitted audio, loop continuity, color identity, and optional app bundling.

uv run --with numpy Tests/AudioAssetsTests.py [path/to/GummyRicochet.app]
"""
import hashlib
import itertools
import json
from pathlib import Path
import sys
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "Resources" / "Audio"
bundle = Path(sys.argv[1]) if len(sys.argv) > 1 else None
music = json.loads((AUDIO / "music_manifest.json").read_text())
effects = json.loads((AUDIO / "manifest.json").read_text())
clips = {}
for path in sorted(AUDIO.glob("*.wav")):
    with wave.open(str(path)) as stream:
        channels = stream.getnchannels()
        assert stream.getframerate() == 44100 and stream.getsampwidth() == 2, path
        samples = np.frombuffer(stream.readframes(stream.getnframes()), dtype="<i2")
        pcm = samples.astype(np.float64).reshape(-1, channels) / 32768
    assert np.all(np.isfinite(pcm)) and np.max(np.abs(pcm)) < .70, path
    assert np.sqrt(np.mean(pcm ** 2)) > .006, f"inaudible/empty: {path}"
    assert not np.any(np.abs(samples.astype(np.int32)) >= 32767), path
    if path.stem.startswith("music_"):
        track = music["tracks"][path.stem]
        expected = music["bars"] * 4 * 60 / track["bpm"]
        assert channels == 2 and abs(len(pcm) / 44100 - expected) <= 1 / 44100, path
        assert np.max(np.abs(pcm[0] - pcm[-1])) < .002, f"loop click: {path}"
        # The cycle has continuing ambience, rather than a fade to silence each repeat.
        assert np.sqrt(np.mean(pcm[-4410:] ** 2)) > .01, path
    else:
        assert channels == 1 and abs(len(pcm) / 44100 - effects["effects"][path.stem]["duration"]) < .001, path
        clips[path.stem] = pcm[:, 0]
    if bundle:
        bundled = bundle / path.name
        assert bundled.is_file() and hashlib.sha256(bundled.read_bytes()).digest() == hashlib.sha256(path.read_bytes()).digest(), f"missing/stale bundle: {path.name}"

for kind in ("shot", "match"):
    for a, b in itertools.combinations(("blue", "red", "yellow", "white"), 2):
        first, second = clips[f"{kind}_{a}"], clips[f"{kind}_{b}"]
        count = min(len(first), len(second))
        similarity = abs(np.dot(first[:count], second[:count]) / (np.linalg.norm(first[:count]) * np.linalg.norm(second[:count])))
        assert similarity < .85, f"colors sound identical: {kind} {a}/{b}"
assert music["tracks"]["music_danger"]["bpm"] / music["tracks"]["music_relaxed"]["bpm"] == 1.5
print(f"PASS: {len(clips)} effects, 2 seamless music loops, distinct color waveforms" + (", all app resources match source" if bundle else ""))

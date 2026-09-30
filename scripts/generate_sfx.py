"""Reproducible, original short PCM effects; no external audio assets."""
import math
from pathlib import Path
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Resources" / "Audio"
OUTPUT.mkdir(parents=True, exist_ok=True)
RATE = 22050
EFFECTS = {
    "tap": [(880, 660, .055)],
    "shot": [(360, 900, .12)],
    "match": [(660, 660, .065), (880, 880, .065), (1320, 1320, .09)],
    "skill": [(440, 660, .07), (660, 880, .07), (880, 1320, .13)],
    "game_over": [(660, 550, .12), (440, 330, .14), (330, 220, .18)],
    "error": [(220, 180, .09)],
}
for name, notes in EFFECTS.items():
    samples = []
    for start, end, duration in notes:
        count = round(duration * RATE)
        for n in range(count):
            t = n / RATE
            progress = n / count
            phase = 2 * math.pi * (start * t + .5 * (end - start) * t * t / duration)
            envelope = min(1, t / .008) * (1 - progress) ** 1.6
            tone = math.sin(phase) + .15 * math.sin(2 * phase)
            samples.append(round(32767 * .23 * envelope * tone))
    with wave.open(str(OUTPUT / f"{name}.wav"), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(struct.pack(f"<{len(samples)}h", *samples))
    print(f"{name}.wav: {len(samples) / RATE:.3f}s")

"""Compose the original Gummy Ricochet theme and its danger arrangement.

Rebuild: uv run --with numpy scripts/generate_music.py
No recordings, sound fonts, network generation services, or licensed melodies.
Both arrangements use the same 16-bar score; urgency changes tempo and orchestration.
"""
import json
from pathlib import Path
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Resources" / "Audio"
RATE = 44100
BARS = 16
TAU = 2 * np.pi

# Cmaj7, Am7, Fmaj7, G6, with a second phrase and a gentle turnaround.
CHORDS = [
    (48, 60, 64, 67, 71), (45, 60, 64, 67, 69),
    (41, 57, 60, 64, 67), (43, 59, 62, 67, 69),
    (48, 60, 64, 67, 71), (45, 60, 64, 67, 69),
    (50, 57, 60, 65, 69), (43, 59, 62, 65, 69),
    (41, 57, 60, 64, 67), (52, 55, 60, 64, 67),
    (50, 57, 60, 65, 69), (43, 59, 62, 67, 69),
    (48, 60, 64, 67, 71), (45, 60, 64, 67, 69),
    (50, 57, 60, 65, 69), (43, 59, 62, 65, 69),
]
# (beat, MIDI note, length in beats): space between phrases matters as much as notes.
MELODY = [
    [(0, 76, .8), (1, 79, .5), (1.5, 81, .5), (2.5, 79, 1)],
    [(.5, 76, .7), (1.5, 74, .5), (2.5, 72, 1)],
    [(0, 72, .8), (1, 76, .5), (2, 79, .8), (3, 76, .5)],
    [(.5, 74, .5), (1.5, 71, .5), (2.5, 67, .8)],
    [(0, 76, .8), (1, 79, .5), (1.5, 83, .5), (2.5, 81, .8)],
    [(.5, 79, .7), (1.5, 76, .5), (2.5, 72, .8)],
    [(0, 74, .8), (1.5, 77, .5), (2.5, 76, .5), (3, 74, .5)],
    [(.5, 71, .6), (1.5, 74, .6), (2.5, 79, 1)],
    [(0, 81, .8), (1, 79, .5), (2, 76, .8), (3, 72, .5)],
    [(.5, 79, .8), (1.5, 76, .5), (2.5, 72, .9)],
    [(0, 77, .8), (1, 76, .5), (2, 74, .8), (3, 69, .5)],
    [(.5, 71, .5), (1.5, 74, .5), (2.5, 79, .9)],
    [(0, 76, .8), (1, 79, .5), (2, 84, 1)],
    [(.5, 83, .6), (1.5, 81, .5), (2.5, 79, .8)],
    [(0, 77, .7), (1, 76, .5), (2, 74, .8)],
    [(0, 71, .7), (1.5, 74, .6), (2.5, 71, .7)],
]


def hz(note):
    return 440 * 2 ** ((note - 69) / 12)


def render(bpm, urgent):
    beat = 60 / bpm
    frames = round(BARS * 4 * beat * RATE)
    song = np.zeros((frames, 2), dtype=np.float64)
    rng = np.random.default_rng(20261008)

    def add(start, signal, gain, pan=0):
        # Fold every release and echo into the next cycle: the loop retains its tails.
        indices = (round(start * RATE) + np.arange(len(signal))) % frames
        np.add.at(song[:, 0], indices, signal * gain * np.sqrt((1 - pan) / 2))
        np.add.at(song[:, 1], indices, signal * gain * np.sqrt((1 + pan) / 2))

    def note(start, midi, length, gain, voice="wood", pan=0):
        duration = length + (.75 if voice == "pad" else .65)
        t = np.arange(round(duration * RATE)) / RATE
        f = hz(midi)
        attack = 1 - np.exp(-t / (.14 if voice == "pad" else .004))
        release = np.exp(-np.maximum(0, t - length) / (.22 if voice == "pad" else .13))
        if voice == "wood":
            signal = (np.sin(TAU * f * t) * np.exp(-t / .30)
                      + .29 * np.sin(TAU * f * 2 * t) * np.exp(-t / .13)
                      + .12 * np.sin(TAU * f * 3.99 * t) * np.exp(-t / .055))
        elif voice == "pluck":
            signal = sum((1 / k ** 1.65) * np.sin(TAU * f * k * t)
                         * np.exp(-t / (.42 / k ** .5)) for k in range(1, 7))
        elif voice == "bass":
            signal = (np.sin(TAU * f * t) + .18 * np.sin(TAU * f * 2 * t)) * np.exp(-t / .38)
        else:
            signal = (np.sin(TAU * f * t) + .10 * np.sin(TAU * f * 2.002 * t))
        signal *= attack * release
        # End at zero so even very quiet tails introduce no discontinuity.
        signal *= np.minimum(1, (duration - t) / .035)
        add(start, signal, gain, pan)
        if voice in ("wood", "pluck"):
            add(start + beat * .75, signal, gain * .16, -pan)
            add(start + beat * 1.5, signal, gain * .055, pan)

    def drum(start, kind, gain):
        duration = .24 if kind == "kick" else .13
        t = np.arange(round(duration * RATE)) / RATE
        if kind == "kick":
            phase = TAU * (52 * t + 48 * .023 * (1 - np.exp(-t / .023)))
            signal = np.sin(phase) * np.exp(-t / .065)
        else:
            noise = rng.uniform(-1, 1, len(t))
            if kind == "brush":
                signal = np.convolve(noise, np.ones(12) / 12, mode="same") * np.exp(-t / .030)
            else:
                signal = (noise - np.roll(noise, 1)) * np.exp(-t / .016) * .25
        signal *= np.minimum(1, t / .002) * np.minimum(1, (duration - t) / .008)
        add(start, signal, gain, .20 if kind == "hat" else 0)

    for bar, chord in enumerate(CHORDS):
        start = bar * 4 * beat
        for position, midi, length in MELODY[bar]:
            offset = .07 if position % 1 else 0
            note(start + (position + offset) * beat, midi, length * beat,
                 .26 if urgent else .24, "wood", .10)
        for i, midi in enumerate(chord[1:4]):
            note(start, midi - 12, 3.6 * beat, .024, "pad", (i - 1) * .48)
        for position in ([0, 1, 2, 3] if urgent else [0, 2]):
            note(start + position * beat, chord[0] - 12,
                 .50 * beat, .17 if urgent else .15, "bass", -.04)
        positions = [i / 2 for i in range(8)] if urgent else [0, .55, 1.55, 2, 2.55, 3.55]
        for i, position in enumerate(positions):
            midi = chord[1 + i % 4]
            note(start + position * beat, midi, .26 * beat,
                 .081 if urgent else .064, "pluck", -.30 if i % 2 else .30)
        for position in [0, 2]:
            drum(start + position * beat, "kick", .085 if urgent else .050)
        for position in [1, 3]:
            drum(start + position * beat, "brush", .13 if urgent else .078)
        for position in ([i / 2 for i in range(8)] if urgent else [.55, 1.55, 2.55, 3.55]):
            drum(start + position * beat, "hat", .068 if urgent else .043)
        if urgent:
            # A muted ticking pulse adds urgency without an alarm or a harsh lead.
            for position in [.75, 1.75, 2.75, 3.75]:
                note(start + position * beat, chord[3] + 12, .08 * beat, .045, "pluck", -.35)
    song -= np.mean(song, axis=0)
    song *= min(1, .60 / np.max(np.abs(song)))
    return np.rint(song * 32767).astype("<i2")


def write(name, pcm):
    with wave.open(str(OUT / f"{name}.wav"), "wb") as stream:
        stream.setnchannels(2)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(pcm.tobytes())


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {"originalComposition": True, "sampleRate": RATE, "channels": 2,
                "bits": 16, "bars": BARS, "key": "C major", "tracks": {}}
    for name, bpm, urgent in [("music_relaxed", 88, False), ("music_danger", 132, True)]:
        pcm = render(bpm, urgent)
        write(name, pcm)
        floating = pcm.astype(np.float64) / 32768
        manifest["tracks"][name] = {
            "bpm": bpm, "duration": len(pcm) / RATE,
            "peak": float(np.max(np.abs(floating))),
            "rms": float(np.sqrt(np.mean(floating ** 2))),
            "clippedSamples": int(np.sum(np.abs(pcm.astype(np.int32)) >= 32767)),
            "loopBoundaryStep": float(np.max(np.abs(floating[0] - floating[-1]))),
            "score": "shared 16-bar melody and harmony",
        }
        print(name, manifest["tracks"][name])
    (OUT / "music_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()

"""Original layered soft-candy sounds, deterministic PCM synthesis (no source recordings).

Run python3 scripts/generate_sfx.py. The manifest measures the actual emitted PCM.
Every sound combines a damped resonator with filtered noise/air or small bell tails;
headroom is retained because the application may overlap up to three quiet voices.
"""
import json
import math
from pathlib import Path
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Resources" / "Audio"
OUTPUT.mkdir(parents=True, exist_ok=True)
RATE = 44100
TAU = 2 * math.pi

def resonator(out, start, duration, hz, end_hz=None, gain=.3, decay=5, harmonics=.12):
    count = round(duration * RATE)
    phase = 0.0
    for i in range(count):
        t = i / RATE
        p = i / count
        freq = hz * ((end_hz or hz) / hz) ** p
        phase += TAU * freq / RATE
        envelope = min(1, t / .004) * math.exp(-decay * p) * min(1, (duration-t)/.012)
        value = (math.sin(phase) + harmonics * math.sin(2*phase)) * envelope * gain
        index = round(start * RATE) + i
        if index < len(out): out[index] += value

def air(out, start, duration, gain, seed, lowpass=.08, decay=2):
    rng = random.Random(seed)
    smooth = 0
    count = round(duration * RATE)
    for i in range(count):
        p = i/count
        smooth += lowpass * (rng.uniform(-1,1)-smooth)
        envelope = min(1,i/(RATE*.012)) * (1-p)**decay
        index = round(start*RATE)+i
        if index < len(out): out[index] += smooth * gain * envelope

def pop(out, start, base, gain=1):
    # Two falling resonances make the impact rounded; an airy tail gives squish.
    resonator(out,start,.17,base,base*.42,.52*gain,5,.17)
    resonator(out,start+.018,.13,base*1.65,base*.74,.16*gain,6,.07)
    air(out,start,.14,.55*gain,round(base),.16,3)

def bells(out, notes, gain=.22):
    for start,hz in notes:
        resonator(out,start,.32,hz,gain=gain,decay=5,harmonics=.08)
        resonator(out,start,.2,hz*2.76,gain=gain*.1,decay=8,harmonics=0)

sounds = {}
def make(name, duration):
    sounds[name] = [0.] * round(duration*RATE)
    return sounds[name]

pop(make("tap",.16),0,520,.5)
s=make("shot",.24); air(s,0,.18,.9,30,.065,1.7); resonator(s,.01,.2,220,740,.28,3,.08)
for name,base in [("match",680),("match_alt",750)]:
    s=make(name,.34)
    for start,hz,gain in [(0,base,1),(.043,base*1.19,.7),(.085,base*1.44,.5)]: pop(s,start,hz,gain)
    bells(s,[(.08,1046)],.12)
s=make("fall",.46); air(s,0,.38,1.5,90,.045,1.4)
for start,hz in [(0,430),(.064,355),(.13,270),(.205,210)]: pop(s,start,hz,.47)
s=make("combo",.47); bells(s,[(0,660),(.058,880),(.12,1046),(.182,1320)],.28); pop(s,0,590,.65)
s=make("freeze",.54); air(s,0,.28,.55,130,.1,2); bells(s,[(0,1046),(.054,1568),(.105,2093)],.24)
s=make("blast",.48); pop(s,0,190,1); resonator(s,0,.42,125,48,.6,4,.13); air(s,0,.34,1.7,143,.05,3)
s=make("sweep",.47); air(s,0,.39,2.1,159,.08,1.1); resonator(s,.015,.3,720,190,.25,2,.06)
for start,hz in [(.11,570),(.19,420),(.26,310)]: pop(s,start,hz,.28)
s=make("wild",.6); bells(s,[(0,784),(.048,988),(.096,1175),(.145,1568)],.3); air(s,.06,.3,.35,169,.04,2)
s=make("ready",.42); bells(s,[(0,880),(.065,1175)],.26)
s=make("win",.83); bells(s,[(0,523),(.09,659),(.18,784),(.3,1046),(.36,1318)],.3); pop(s,0,660,.35)
s=make("game_over",.61); resonator(s,0,.2,392,350,.29,3,.05); resonator(s,.16,.22,311,270,.29,3,.05); pop(s,.32,240,.6)
s=make("error",.18); pop(s,0,240,.42)
# Legacy generic skill is kept for existing call sites, but dedicated skills have their own identity.
s=make("skill",.48); bells(s,[(0,659),(.07,880),(.14,1175)],.25)

# Each candy keeps a recognizable timbre as well as its pitch on launch and match.
for color,base,air_gain,harmonics in [
    ("blue",622,.30,.05), ("red",392,.62,.22),
    ("yellow",784,.40,.13), ("white",988,.22,.03),
]:
    s=make(f"shot_{color}",.26)
    air(s,0,.19,air_gain,round(base),.08,1.8)
    resonator(s,.008,.20,base*.45,base,.32,3,harmonics)
    if color in ("blue","white"):
        bells(s,[(.035,base*2)],.10)
    s=make(f"match_{color}",.40)
    for start,hz,gain in [(0,base,.85),(.045,base*1.25,.55),(.095,base*1.5,.40)]:
        pop(s,start,hz,gain)
    bells(s,[(.06,base*2),(.13,base*2.5)],.14 if color=="white" else .09)
s=make("blast_ready",.32)
resonator(s,0,.23,196,392,.32,2,.18); bells(s,[(.11,587)],.15)

manifest={"sampleRate":RATE,"channels":1,"bits":16,"originalSynthesis":True,"effects":{}}
for name,samples in sounds.items():
    peak=max(abs(x) for x in samples)
    # Only reduce loud sounds; never amplify small effects into equally loud taps.
    scale=min(1,.68/peak)
    pcm=[round(x*scale*32767) for x in samples]
    with wave.open(str(OUTPUT/f"{name}.wav"),"wb") as wav:
        wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(RATE)
        wav.writeframes(struct.pack(f"<{len(pcm)}h",*pcm))
    rms=math.sqrt(sum((x/32768)**2 for x in pcm)/len(pcm))
    manifest["effects"][name]={"duration":round(len(pcm)/RATE,3),"peak":round(max(abs(x) for x in pcm)/32768,5),"rms":round(rms,5),"clippedSamples":sum(abs(x)>=32767 for x in pcm)}
    print(name,manifest["effects"][name])
(OUTPUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")

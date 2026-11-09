"""Generate short original bomb / shield cues; no external samples."""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 22050
ROOT = Path(__file__).resolve().parents[1] / 'assest/sounds'

def render(name, seconds, shield=False):
    rng = random.Random(969)
    phase = low = 0.0
    samples = bytearray()
    for i in range(int(seconds * RATE)):
        t = i / RATE
        p = t / seconds
        envelope = min(1, t / 0.004) * (1 - p) ** 2
        frequency = (660 if p < 0.45 else 990) if shield else 180 * (1 - p) ** 2 + 46
        phase += frequency / RATE
        triangle = 1 - 4 * abs(phase % 1 - 0.5)
        low = low * 0.68 + rng.uniform(-1, 1) * 0.32
        signal = triangle * 0.36 if shield else triangle * 0.54 + low * 0.56
        samples.extend(struct.pack('<h', int(signal * envelope * 0.65 * 32767)))
    with wave.open(str(ROOT / name), 'wb') as sound:
        sound.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        sound.writeframes(samples)

if __name__ == '__main__':
    render('bomb_burst.wav', 0.19)
    render('arsenal_shield.wav', 0.12, True)

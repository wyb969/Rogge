"""Generate two short, original, quiet retro cues (no samples or dependencies)."""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 22050
ROOT = Path(__file__).resolve().parents[1] / "assest" / "sounds"


def render(name: str, seconds: float, vortex: bool) -> None:
    rng = random.Random(969 if vortex else 147)
    samples = bytearray()
    low = 0.0
    phase = 0.0
    for i in range(int(RATE * seconds)):
        t = i / RATE
        progress = t / seconds
        envelope = min(1.0, t / 0.012) * (1.0 - progress) ** 1.7
        low = low * 0.76 + rng.uniform(-1.0, 1.0) * 0.24
        frequency = (380.0 - 240.0 * progress) if vortex else (650.0 - 330.0 * progress)
        phase += frequency / RATE
        triangle = 1.0 - 4.0 * abs((phase % 1.0) - 0.5)
        signal = (triangle * 0.56 + low * 0.22) if vortex else (low * 0.95 + triangle * 0.13)
        samples.extend(struct.pack("<h", int(signal * envelope * 0.52 * 32767)))
    with wave.open(str(ROOT / name), "wb") as audio:
        audio.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        audio.writeframes(samples)


if __name__ == "__main__":
    render("banana_fan.wav", 0.22, False)
    render("black_hole.wav", 0.34, True)

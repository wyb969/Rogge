"""Deterministic short original terrain cues, mono PCM16/22050 Hz, no runtime synthesis."""
from pathlib import Path
import math, random, struct, wave
root = Path(__file__).resolve().parents[1] / 'assest/sounds'
for kind, seconds in [('electric', .18), ('mine', .30)]:
    rng = random.Random(761 if kind == 'electric' else 931)
    values = []
    phase = 0.0
    low = 0.0
    for i in range(int(22050 * seconds)):
        t = i / 22050
        x = t / seconds
        noise = rng.uniform(-1, 1)
        attack = min(1, t / .003)
        if kind == 'electric':
            phase += 2 * math.pi * (950 - 600*x + 90*math.sin(2*math.pi*65*t)) / 22050
            pulse = .65 + .35*math.sin(2*math.pi*85*t)**2
            sample = (.38*math.sin(phase) + .22*noise) * pulse * (1-x)**2 * attack
        else:
            low += .16*(noise-low)
            phase += 2*math.pi*(150-105*x)/22050
            sample = (.58*math.sin(phase)*math.exp(-10*x) + .9*low*(1-x)**2) * attack
        values.append(max(-.85, min(.85, sample)))
    with wave.open(str(root / ('terrain_'+kind+'.wav')), 'wb') as out:
        out.setparams((1, 2, 22050, 0, 'NONE', 'not compressed'))
        out.writeframes(b''.join(struct.pack('<h', round(v*32767)) for v in values))
    print(kind, len(values), 'peak', round(max(abs(v) for v in values),3))

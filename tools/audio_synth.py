# Kevencre : musiques et bruitages synthétisés (aucun son externe).
# Usage : python3 tools/audio_synth.py <dossier audio>
import numpy as np, wave, sys, os, subprocess

SR = 32000
OUT = sys.argv[1] if len(sys.argv) > 1 else 'audio'
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(5)


def t(d):
    return np.arange(int(SR * d)) / SR


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def save(name, x, peak=0.9, ogg=True):
    x = norm(np.asarray(x, np.float64), peak)
    d = (x * 32767).astype(np.int16)
    wp = os.path.join(OUT, name + '.wav')
    with wave.open(wp, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(d.tobytes())
    if ogg:
        op = os.path.join(OUT, name + '.ogg')
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wp, '-c:a', 'libvorbis', '-q:a', '4', op], check=True)
        os.remove(wp)


def lowpass(x, cutoff):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 / (1 + (f / cutoff) ** 4)
    return np.fft.irfft(X, len(x))


def highpass(x, cutoff):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 - 1 / (1 + (f / cutoff) ** 4)
    return np.fft.irfft(X, len(x))


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def env_adsr(n, a, dcy, s, r):
    e = np.ones(n) * s
    A, D, R = int(a * SR), int(dcy * SR), int(r * SR)
    A = min(A, n); e[:A] = np.linspace(0, 1, A) if A > 0 else e[:A]
    if D > 0 and A + D < n:
        e[A:A + D] = np.linspace(1, s, D)
    if R > 0:
        R = min(R, n)
        e[-R:] *= np.linspace(1, 0, R)
    return e


# ------------------------------------------------------------------ instruments
def harp(f, d=1.6, bright=1.0):
    tt = t(d)
    x = np.zeros_like(tt)
    for k in range(1, 8):
        x += (1 / k ** 1.4) * np.sin(2 * np.pi * f * k * tt * (1 + 0.0004 * k)) * np.exp(-tt * (2.2 + 1.3 * k / bright))
    x *= np.minimum(1, tt / 0.004)
    return x


def piano(f, d=2.0):
    tt = t(d)
    x = np.zeros_like(tt)
    for k in range(1, 10):
        x += (1 / k ** 1.8) * np.sin(2 * np.pi * f * k * tt * (1 + 0.0007 * k * k)) * np.exp(-tt * (1.2 + 0.9 * k))
    x += 0.15 * np.sin(2 * np.pi * f * 1.002 * tt) * np.exp(-tt * 0.8)
    x *= np.minimum(1, tt / 0.003)
    return x


def marimba(f, d=0.9):
    tt = t(d)
    x = np.sin(2 * np.pi * f * tt) * np.exp(-tt * 5) + 0.35 * np.sin(2 * np.pi * f * 4 * tt) * np.exp(-tt * 18) + 0.1 * np.sin(2 * np.pi * f * 9.9 * tt) * np.exp(-tt * 40)
    return x * np.minimum(1, tt / 0.002)


def flute(f, d, vib=5.0):
    tt = t(d)
    ph = 2 * np.pi * np.cumsum(f * (1 + 0.006 * np.sin(2 * np.pi * vib * tt) * np.minimum(1, tt / 0.4))) / SR
    x = np.sin(ph) + 0.25 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph)
    breath = lowpass(noise(d), 3000) * 0.04
    e = env_adsr(len(tt), 0.06, 0.1, 0.85, min(0.25, d * 0.4))
    return (x + breath) * e


def pad(freqs, d, bright=1800):
    tt = t(d)
    x = np.zeros_like(tt)
    for f in freqs:
        for det in (-0.004, 0.0, 0.005):
            ph = 2 * np.pi * f * (1 + det) * tt + rng.uniform(0, 6.28)
            x += np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
    e = env_adsr(len(tt), min(0.8, d * 0.3), 0.2, 0.9, min(0.9, d * 0.35))
    return lowpass(x * e, bright)


def strings(f, d):
    tt = t(d)
    x = np.zeros_like(tt)
    for det in (-0.003, 0.0, 0.004):
        ph = 2 * np.pi * np.cumsum(f * (1 + det + 0.003 * np.sin(2 * np.pi * 5.5 * tt))) / SR
        saw = 2 * ((ph / (2 * np.pi)) % 1) - 1
        x += saw
    e = env_adsr(len(tt), 0.05, 0.1, 0.8, 0.12)
    return lowpass(x * e, 2400)


def bass(f, d):
    tt = t(d)
    x = np.sin(2 * np.pi * f * tt) + 0.4 * np.sin(4 * np.pi * f * tt) * np.exp(-tt * 6)
    return x * env_adsr(len(tt), 0.005, 0.15, 0.6, 0.06)


def kick(d=0.35):
    tt = t(d)
    return np.sin(2 * np.pi * np.cumsum(130 * np.exp(-tt * 28) + 42) / SR) * np.exp(-tt * 9)


def snare(d=0.22):
    tt = t(d)
    return highpass(noise(d), 1200) * np.exp(-tt * 20) * 0.8 + np.sin(2 * np.pi * 190 * tt) * np.exp(-tt * 30) * 0.5


def hat(d=0.06):
    tt = t(d)
    return highpass(noise(d), 6000) * np.exp(-tt * 70)


class Track:
    def __init__(self, dur):
        self.x = np.zeros(int(SR * dur) + SR * 4)
        self.dur = dur

    def put(self, s, at, vol=1.0):
        p = int(at * SR)
        if p >= len(self.x):
            return
        s = s[:len(self.x) - p]
        self.x[p:p + len(s)] += s * vol

    def render(self, reverb=0.25):
        x = self.x
        if reverb > 0:
            out = x.copy()
            for dly, g in ((0.031, 0.5), (0.053, 0.42), (0.079, 0.36), (0.113, 0.3), (0.167, 0.22), (0.233, 0.16), (0.31, 0.11)):
                n = int(dly * SR)
                out[n:] += x[:-n] * g * reverb * 2
            x = lowpass(out, 9000)
        # boucle : la queue revient au début
        n = int(self.dur * SR)
        tail = x[n:]
        y = x[:n].copy()
        y[:len(tail)] += tail
        return y


def chord(root, kind):
    return [root + i for i in {'M': (0, 4, 7), 'm': (0, 3, 7), 'M7': (0, 4, 7, 11), 'm7': (0, 3, 7, 10), '7': (0, 4, 7, 10), 'sus': (0, 5, 7), 'add9': (0, 4, 7, 14)}[kind]]


# ------------------------------------------------------------------ musiques
def music_title():
    bpm = 72; b = 60 / bpm; bars = 16; T = Track(bars * 4 * b)
    prog = [(48, 'add9'), (45, 'm7'), (41, 'M7'), (43, 'sus')]
    for i in range(bars):
        r, k = prog[i % 4]
        cs = chord(r, k)
        T.put(pad([midi(n + 12) for n in cs[:3]], 4 * b + 0.5), i * 4 * b, 0.10)
        T.put(bass(midi(r - 12), 4 * b), i * 4 * b, 0.25)
        arp = cs + [cs[1] + 12, cs[2] + 12, cs[0] + 24]
        for j in range(8):
            n = arp[[0, 1, 2, 3, 4, 3, 2, 1][j] % len(arp)] + 12
            T.put(harp(midi(n), 2.0), i * 4 * b + j * b / 2, 0.22)
    mel = [(76, 2), (79, 1), (77, 1), (76, 2), (72, 2), (74, 3), (72, 1), (69, 4),
           (72, 2), (74, 1), (76, 1), (77, 2), (76, 1), (74, 1), (76, 3), (79, 1), (74, 4)]
    at = 0
    for n, l in mel:
        T.put(flute(midi(n), l * b * 0.95), 8 * 4 * b * 0 + at + 0 * b, 0.0)
        at += l * b
    at = 0
    for rep in range(2):
        for n, l in mel:
            if at >= bars * 4 * b:
                break
            T.put(piano(midi(n), l * b + 1.2), at, 0.28)
            if rep:
                T.put(flute(midi(n + 12), l * b * 0.9), at, 0.07)
            at += l * b
    save('music_title', T.render(0.35), 0.8)


def music_meadow():
    bpm = 104; b = 60 / bpm; bars = 32; T = Track(bars * 3 * b)    # valse 3/4
    prog = [(43, 'M'), (43, 'M'), (48, 'M'), (50, 'M'), (40, 'm'), (36, 'M'), (38, 'M'), (38, '7')]
    for i in range(bars):
        r, k = prog[i % 8]
        cs = chord(r, k)
        at = i * 3 * b
        T.put(bass(midi(r - 12), b * 0.9), at, 0.4)
        for j in (1, 2):
            for n in cs:
                T.put(harp(midi(n + 12), 0.8, 0.7), at + j * b, 0.07)
        T.put(pad([midi(n + 12) for n in cs], 3 * b + 0.3, 1400), at, 0.05)
    mel = [(71, 1), (74, 1), (79, 1), (78, 2), (76, 1), (74, 3), (72, 1), (71, 1), (69, 1), (71, 3), (74, 3),
           (76, 1), (74, 1), (72, 1), (71, 2), (72, 1), (74, 3), (66, 3),
           (71, 1), (74, 1), (79, 1), (81, 2), (79, 1), (78, 3), (76, 1), (78, 1), (79, 1), (83, 3), (81, 3),
           (79, 1), (78, 1), (76, 1), (74, 2), (72, 1), (71, 3), (69, 2), (74, 1), (79, 3)]
    at = 0
    for rep in range(2):
        for n, l in mel:
            if at >= bars * 3 * b:
                break
            if rep == 0:
                T.put(flute(midi(n), l * b * 0.92), at, 0.2)
                T.put(harp(midi(n + 12), 1.0), at, 0.06)
            else:
                T.put(piano(midi(n + 12), l * b + 0.8), at, 0.22)
                T.put(flute(midi(n - 12), l * b * 0.9), at, 0.07)
            at += l * b
    save('music_meadow', T.render(0.3), 0.8)


def music_forest():
    bpm = 84; b = 60 / bpm; bars = 24; T = Track(bars * 4 * b)
    prog = [(50, 'm7'), (55, 'M'), (50, 'm7'), (48, 'M'), (46, 'M7'), (48, 'M')]
    for i in range(bars):
        r, k = prog[i % 6]
        cs = chord(r, k)
        at = i * 4 * b
        T.put(pad([midi(n) for n in cs], 4 * b + 0.6, 1100), at, 0.12)
        T.put(bass(midi(r - 12), 2 * b), at, 0.3)
        T.put(bass(midi(r - 12 + 7), 1.5 * b), at + 2.5 * b, 0.2)
        pat = [0, 2, 1, 3, 2, 1, 3, 2]
        for j in range(8):
            n = (cs + [cs[0] + 12])[pat[j] % (len(cs) + 1)] + 12
            T.put(marimba(midi(n)), at + j * b / 2, 0.16 if j % 2 == 0 else 0.1)
    mel = [(74, 3), (77, 1), (76, 2), (72, 2), (74, 4), (0, 2), (69, 1), (72, 1),
           (74, 2), (76, 1), (77, 1), (79, 3), (77, 1), (76, 6), (0, 2),
           (81, 3), (79, 1), (77, 2), (76, 2), (74, 4), (72, 2), (70, 2), (69, 8)]
    at = 2 * 4 * b
    for rep in range(2):
        for n, l in mel:
            if at >= bars * 4 * b:
                break
            if n:
                if rep == 0:
                    T.put(flute(midi(n), l * b * 0.95, 4.5), at, 0.17)
                else:
                    T.put(harp(midi(n), l * b + 1.0), at, 0.2)
                    T.put(flute(midi(n + 12), l * b * 0.95, 4.5), at, 0.06)
            at += l * b
        at += 2 * 4 * b
    # gouttes d'eau
    for k in range(40):
        T.put(marimba(midi(rng.integers(84, 96)), 0.3), rng.uniform(0, bars * 4 * b), 0.03)
    save('music_forest', T.render(0.45), 0.8)


def music_cliffs():
    bpm = 112; b = 60 / bpm; bars = 32; T = Track(bars * 4 * b)
    prog = [(45, 'm'), (45, 'm'), (41, 'M'), (43, 'M'), (45, 'm'), (40, 'm'), (41, 'M'), (40, 'M')]
    for i in range(bars):
        r, k = prog[i % 8]
        cs = chord(r, k)
        at = i * 4 * b
        for j in range(8):
            n = r - 12 + (12 if j % 2 else 0)
            T.put(strings(midi(n), b / 2 * 0.9), at + j * b / 2, 0.06)
        T.put(pad([midi(n + 12) for n in cs], 4 * b, 1500), at, 0.06)
        for j in range(4):
            T.put(kick(), at + j * b, 0.25 if j in (0, 2) else 0.0)
            T.put(hat(), at + j * b + b / 2, 0.08)
        if i >= 4:
            for j in range(16):
                n = cs[[0, 1, 2, 1][j % 4]] + 24
                T.put(harp(midi(n), 0.6, 1.4), at + j * b / 4, 0.06)
    mel = [(69, 2), (72, 1), (76, 1), (74, 2), (72, 2), (71, 3), (72, 1), (74, 4),
           (72, 2), (76, 1), (79, 1), (77, 2), (76, 2), (74, 2), (72, 2), (71, 4),
           (69, 2), (72, 1), (76, 1), (81, 3), (79, 1), (77, 2), (76, 2), (74, 4),
           (76, 2), (72, 2), (74, 2), (71, 2), (69, 8)]
    at = 4 * 4 * b
    for rep in range(2):
        for n, l in mel:
            if at >= bars * 4 * b:
                break
            T.put(flute(midi(n + (12 if rep else 0)), l * b * 0.9), at, 0.18 if rep == 0 else 0.12)
            T.put(strings(midi(n - 12), l * b * 0.9), at, 0.03 if rep == 0 else 0.05)
            at += l * b
        at += 4 * 4 * b
    save('music_cliffs', T.render(0.3), 0.8)


def music_boss():
    bpm = 152; b = 60 / bpm; bars = 32; T = Track(bars * 4 * b)
    prog = [52, 52, 48, 50, 52, 52, 55, 54]
    for i in range(bars):
        r = prog[i % 8]
        at = i * 4 * b
        for j in range(8):
            T.put(bass(midi(r - 12 + (7 if j in (3, 6) else 0)), b / 2 * 0.85), at + j * b / 2, 0.45)
            T.put(hat(), at + j * b / 2, 0.1 if j % 2 else 0.05)
        for j in (0, 3, 4):
            T.put(kick(), at + j * b / 2 * (1 if j != 3 else 1), 0.5)
        for j in (2, 6):
            T.put(snare(), at + j * b / 2, 0.35)
        if i % 2 == 0:
            for n in chord(r + 12, 'm'):
                T.put(strings(midi(n), 1.5 * b), at, 0.05)
                T.put(strings(midi(n), 1.0 * b), at + 2.5 * b, 0.04)
        if i % 16 >= 8:
            for j in range(8):
                n = [r + 24, r + 27, r + 31, r + 27][j % 4]
                T.put(marimba(midi(n), 0.4), at + j * b / 2, 0.08)
    mel = [(76, 3), (74, 1), (76, 2), (79, 2), (78, 3), (76, 1), (74, 4), (72, 3), (71, 1), (72, 2), (74, 2), (71, 8)]
    for start in (8, 24):
        at = start * 4 * b
        for n, l in mel:
            T.put(strings(midi(n), l * b / 2 * 1.9), at, 0.06)
            T.put(flute(midi(n + (12 if start == 24 else 0)), l * b / 2 * 1.9), at, 0.1)
            at += l * b / 2 * 2
    save('music_boss', T.render(0.18), 0.85)


def music_ending():
    bpm = 66; b = 60 / bpm; bars = 8; T = Track(bars * 4 * b)
    prog = [(48, 'M7'), (53, 'M7'), (45, 'm7'), (43, 'sus')]
    for i in range(bars):
        r, k = prog[i % 4]
        cs = chord(r, k)
        at = i * 4 * b
        T.put(pad([midi(n + 12) for n in cs], 4 * b + 0.6, 1600), at, 0.1)
        T.put(bass(midi(r - 12), 4 * b), at, 0.25)
        for j in range(6):
            n = (cs + [cs[0] + 12, cs[1] + 12])[j % (len(cs) + 2)] + 12
            T.put(harp(midi(n), 2.2), at + j * b * 2 / 3, 0.16)
    mel = [(72, 2), (76, 2), (79, 3), (77, 1), (76, 4), (72, 2), (74, 2), (76, 4), (74, 2), (72, 2), (71, 2), (72, 6)]
    at = 0
    for n, l in mel:
        T.put(piano(midi(n), l * b + 1.0), at, 0.3)
        at += l * b
    save('music_ending', T.render(0.4), 0.8)


# ------------------------------------------------------------------ bruitages
def sfx():
    # saut : petit "pouf" + glissando court
    d = 0.18; tt = t(d)
    x = np.sin(2 * np.pi * np.cumsum(300 + 900 * tt / d) / SR) * np.exp(-tt * 22) * 0.6 + highpass(noise(d), 2000) * np.exp(-tt * 40) * 0.3
    save('jump', x, 0.7)
    d = 0.16; tt = t(d)
    save('land', lowpass(noise(d), 600) * np.exp(-tt * 30) + np.sin(2 * np.pi * 90 * tt) * np.exp(-tt * 35) * 0.6, 0.7)
    # trait d'encre : coup de pinceau
    d = 0.32; tt = t(d)
    n = noise(d)
    sw = highpass(lowpass(n, 5000), 800) * np.sin(np.pi * np.clip(tt / d, 0, 1)) ** 0.6
    sw += np.sin(2 * np.pi * np.cumsum(500 + 700 * tt / d) / SR) * np.exp(-tt * 10) * 0.25
    save('dash', sw, 0.8)
    d = 0.25; tt = t(d)
    save('dry', highpass(noise(d), 3000) * np.exp(-tt * 18) * (rng.random(len(tt)) > 0.6), 0.5)
    d = 0.4; tt = t(d)
    save('hurt', np.sin(2 * np.pi * np.cumsum(520 * np.exp(-tt * 5)) / SR) * np.exp(-tt * 7) + lowpass(noise(d), 1200) * np.exp(-tt * 14) * 0.6, 0.85)
    d = 1.0; tt = t(d)
    x = np.zeros_like(tt)
    for k, f in enumerate([660, 520, 400, 300]):
        s = harp(f, 0.6); p = int(k * 0.12 * SR); x[p:p + len(s)] += s[:len(x) - p]
    save('die', x + lowpass(noise(d), 800) * np.exp(-tt * 5) * 0.3, 0.8)
    save('drop', harp(midi(84), 0.4, 2) + harp(midi(91), 0.4, 2) * 0.4, 0.6)
    x = np.zeros(int(SR * 1.8))
    for k, n in enumerate([72, 76, 79, 84, 88, 91]):
        s = harp(midi(n), 1.2); p = int(k * 0.08 * SR); x[p:p + len(s)] += s[:len(x) - p]
    save('pigment', x, 0.8)
    save('refill', harp(midi(88), 0.5, 2) + harp(midi(95), 0.5, 2) * 0.5, 0.7)
    d = 0.45; tt = t(d)
    save('boing', np.sin(2 * np.pi * np.cumsum(180 + 500 * (1 - np.exp(-tt * 10)) + 40 * np.sin(2 * np.pi * 18 * tt)) / SR) * np.exp(-tt * 6), 0.8)
    d = 0.35; tt = t(d)
    save('paper', highpass(noise(d), 1500) * (0.3 + 0.7 * (rng.random(len(tt)) > 0.85)) * np.exp(-tt * 8), 0.6)
    x = np.zeros(int(SR * 2.2))
    for n in [60, 64, 67, 72]:
        s = pad([midi(n)], 2.0, 3000); x[:len(s)] += s * 0.3
    for k, n in enumerate([72, 76, 79, 84]):
        s = harp(midi(n + 12), 1.4); p = int(k * 0.07 * SR); x[p:p + len(s)] += s[:len(x) - p] * 0.6
    save('checkpoint', x, 0.8)
    x = np.zeros(int(SR * 1.4))
    for k, n in enumerate([79, 83, 86, 91]):
        s = marimba(midi(n), 0.8); p = int(k * 0.1 * SR); x[p:p + len(s)] += s[:len(x) - p]
    save('secret', x, 0.75)
    d = 0.35; tt = t(d)
    save('splat', lowpass(noise(d), 1800) * np.exp(-tt * 14) + np.sin(2 * np.pi * np.cumsum(260 * np.exp(-tt * 9) + 60) / SR) * np.exp(-tt * 12) * 0.8, 0.85)
    d = 0.35; tt = t(d)
    caw = np.sign(np.sin(2 * np.pi * np.cumsum(620 - 300 * tt) / SR)) * 0.4 * np.exp(-tt * 6)
    save('caw', lowpass(caw + noise(d) * 0.2 * np.exp(-tt * 8), 2200), 0.6)
    d = 0.3; tt = t(d)
    save('spit', lowpass(noise(d), 900) * np.exp(-tt * 16) + np.sin(2 * np.pi * np.cumsum(400 * np.exp(-tt * 12)) / SR) * np.exp(-tt * 14) * 0.5, 0.7)
    d = 0.9; tt = t(d)
    save('slam', np.sin(2 * np.pi * np.cumsum(90 * np.exp(-tt * 5) + 30) / SR) * np.exp(-tt * 5) + lowpass(noise(d), 400) * np.exp(-tt * 4) * 1.2, 0.95)
    d = 0.8; tt = t(d)
    x = np.zeros_like(tt)
    for k, n in enumerate([64, 67, 71, 76]):
        s = harp(midi(n), 0.6); p = int(k * 0.05 * SR); x[p:p + len(s)] += s[:len(x) - p]
    save('open', x, 0.7)
    d = 0.8; tt = t(d)
    save('rain', highpass(noise(d), 2500) * np.sin(np.pi * tt / d) * 0.6, 0.5)
    d = 1.4; tt = t(d)
    save('wave', lowpass(noise(d), 700) * np.sin(np.pi * tt / d) ** 0.5, 0.8)
    d = 1.8; tt = t(d)
    save('flood', lowpass(noise(d), 500) * np.minimum(1, tt / 0.6) * np.exp(-tt * 0.8) + np.sin(2 * np.pi * 55 * tt) * 0.3 * np.exp(-tt * 1.2), 0.8)
    d = 0.25; tt = t(d)
    save('clink', np.sin(2 * np.pi * 1800 * tt) * np.exp(-tt * 25) + np.sin(2 * np.pi * 2700 * tt) * np.exp(-tt * 30) * 0.5, 0.6)
    d = 0.7; tt = t(d)
    x = lowpass(noise(d), 2500) * np.exp(-tt * 9) + np.sin(2 * np.pi * np.cumsum(220 * np.exp(-tt * 4) + 50) / SR) * np.exp(-tt * 5)
    for k, n in enumerate([76, 79, 83]):
        s = harp(midi(n), 0.5); p = int(k * 0.04 * SR); x[p:p + len(s)] += s[:len(x) - p] * 0.4
    save('bosshit', x, 0.9)
    d = 1.6; tt = t(d)
    roar = np.zeros_like(tt)
    for k in range(1, 7):
        roar += np.sin(2 * np.pi * np.cumsum((70 + 25 * np.sin(2 * np.pi * 3 * tt)) * k) / SR) / k
    roar = lowpass(roar + noise(d) * 0.6, 900) * np.sin(np.pi * np.clip(tt / d, 0, 1)) ** 0.5
    save('roar', roar, 0.9)
    x = np.zeros(int(SR * 3.0)); at = 0
    for n, l in [(67, 0.14), (72, 0.14), (76, 0.14), (79, 0.42), (77, 0.14), (79, 1.6)]:
        s = harp(midi(n), l + 1.0)
        fl = flute(midi(n + 12), l + 0.2) * 0.3
        s[:len(fl)] += fl
        p = int(at * SR); x[p:p + len(s)] += s[:len(x) - p]; at += l
    for n in [48, 55, 60, 64]:
        s = pad([midi(n)], 2.2, 2000); p = int(0.84 * SR); x[p:p + len(s)] += s[:len(x) - p] * 0.25
    save('victory', x, 0.85)
    d = 0.05; tt = t(d)
    save('blip', np.sin(2 * np.pi * 1100 * tt) * np.exp(-tt * 60), 0.5)
    save('confirm', np.concatenate([harp(midi(81), 0.08), harp(midi(88), 0.3)]), 0.6)


if __name__ == '__main__':
    which = sys.argv[2:] if len(sys.argv) > 2 else ['sfx', 'title', 'meadow', 'forest', 'cliffs', 'boss', 'ending']
    for wch in which:
        if wch == 'sfx':
            sfx()
        else:
            globals()['music_' + wch]()
        print('ok', wch)

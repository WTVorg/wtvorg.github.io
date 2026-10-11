"""Synthesises every Brew Guardians sound effect plus a music loop.

    python sounds.py <out_dir>

Writes BG_<Slot>.ogg files. Import them with Studio's Asset Manager
(Bulk Import) and drop the Sounds into SoundService; the game finds them by
name.
"""

import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env_ad(n, attack, decay_rate):
    """Fast attack then exponential decay."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-t * decay_rate)


def bell(freq, dur, decay=6.0, partials=((1, 1.0), (2.76, 0.45), (5.4, 0.25), (8.93, 0.12))):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for ratio, amp in partials:
        out += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * decay * (0.6 + ratio * 0.25))
    return out * env_ad(len(t), 0.002, 0.0)


def noise(dur):
    return rng.standard_normal(int(SR * dur))


def bandpass(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lowpass(x, f, order=2):
    sos = signal.butter(order, f, btype="low", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def highpass(x, f, order=2):
    sos = signal.butter(order, f, btype="high", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def reverb(x, seconds=1.2, mix=0.25, damp=4000):
    """Convolution with a decaying, darkened noise tail."""
    n = int(SR * seconds)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / SR * (6.9 / seconds))
    ir = lowpass(ir, damp)
    ir /= np.sqrt(np.sum(ir ** 2))
    wet = signal.fftconvolve(x, ir)
    wet = np.pad(wet, (0, len(x) + n - len(wet)))
    dry = np.pad(x, (0, n))
    return dry * (1 - mix) + wet * mix


def place(buf, x, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    end = min(len(buf), i + len(x))
    buf[i:end] += x[: end - i]


def finish(x, peak=0.78, fade=0.01, trim=True):
    x = x - np.mean(x)
    m = np.max(np.abs(x)) or 1
    x = x / m * peak
    if trim:
        # drop the silent end of the reverb tail
        loud = np.nonzero(np.abs(x) > 0.002)[0]
        if len(loud):
            x = x[: min(len(x), loud[-1] + int(SR * 0.05))]
    f = int(SR * fade)
    x[-f:] *= np.linspace(1, 0, f)
    return x.astype(np.float32)


# --------------------------------------------------------------------------
def throw():
    dur = 0.42
    n = noise(dur)
    t = t_axis(dur)
    # sweep a band-pass upward for the whoosh
    out = np.zeros_like(n)
    hop = 512
    for i in range(0, len(n), hop):
        prog = i / len(n)
        center = 600 + 2600 * prog
        end = min(len(n), i + hop)
        seg = bandpass(n[max(0, i - 2048): end], center * 0.6, center * 1.4)[-(end - i):]
        out[i:end] = seg
    shape = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.6
    return finish(reverb(out * shape, 0.4, 0.15))


def shake():
    dur = 0.35
    buf = np.zeros(int(SR * dur))
    # cork-in-glass clink plus a soft wobble thud
    place(buf, bell(1880, 0.3, decay=18) * 0.8, 0.0)
    place(buf, bell(2470, 0.25, decay=22) * 0.4, 0.012)
    thud = lowpass(noise(0.08), 400) * env_ad(int(SR * 0.08), 0.002, 40)
    place(buf, thud * 0.9, 0.0)
    return finish(reverb(buf, 0.5, 0.18))


def lock():
    dur = 1.8
    buf = np.zeros(int(SR * dur))
    notes = [1046.5, 1318.5, 1568.0, 2093.0]  # C6 E6 G6 C7
    for i, f in enumerate(notes):
        place(buf, bell(f, 1.4, decay=3.0, partials=((1, 1.0), (2.0, 0.35), (3.0, 0.15), (4.2, 0.06))) * (0.9 - i * 0.1), i * 0.075)
    # sparkle shimmer
    sparkle = highpass(noise(1.2), 6000) * env_ad(int(SR * 1.2), 0.05, 4.5) * 0.05
    place(buf, sparkle, 0.05)
    # click of the lock
    click = highpass(noise(0.02), 2000) * env_ad(int(SR * 0.02), 0.0005, 200)
    place(buf, click * 0.8, 0.0)
    return finish(reverb(buf, 1.6, 0.3))


def burst():
    dur = 1.1
    buf = np.zeros(int(SR * dur))
    # low pop + glass shards
    t = t_axis(0.25)
    pop = np.sin(2 * np.pi * (180 - 300 * t) * t) * np.exp(-t * 18)
    place(buf, pop * 1.0, 0.0)
    crack = bandpass(noise(0.12), 1500, 9000) * env_ad(int(SR * 0.12), 0.001, 30)
    place(buf, crack * 0.9, 0.0)
    for _ in range(26):
        f = rng.uniform(2500, 7500)
        place(buf, bell(f, 0.25, decay=rng.uniform(20, 40)) * rng.uniform(0.1, 0.35), rng.uniform(0.0, 0.45) ** 1.6)
    return finish(reverb(buf, 0.9, 0.22))


def bubble(freq, dur=0.12):
    t = t_axis(dur)
    sweep = freq * (1 + 2.2 * t / dur)
    phase = 2 * np.pi * np.cumsum(sweep) / SR
    return np.sin(phase) * env_ad(len(t), 0.004, 30)


def brew():
    dur = 1.4
    buf = np.zeros(int(SR * dur))
    for _ in range(22):
        place(buf, bubble(rng.uniform(250, 700)) * rng.uniform(0.3, 0.8), rng.uniform(0, 1.1))
    # magical swell
    t = t_axis(1.2)
    swell = (np.sin(2 * np.pi * 523.25 * t) + 0.5 * np.sin(2 * np.pi * 784 * t)) * np.sin(np.pi * t / 1.2) ** 2 * 0.25
    place(buf, swell, 0.15)
    return finish(reverb(buf, 1.0, 0.25))


def harvest():
    dur = 0.4
    buf = np.zeros(int(SR * dur))
    place(buf, bubble(420, 0.09) * 0.9, 0.0)
    rustle = bandpass(noise(0.18), 2000, 7000) * env_ad(int(SR * 0.18), 0.01, 18) * 0.35
    place(buf, rustle, 0.0)
    place(buf, bell(1568, 0.3, decay=10) * 0.35, 0.05)
    return finish(reverb(buf, 0.5, 0.18))


def coins():
    dur = 0.8
    buf = np.zeros(int(SR * dur))
    for i in range(6):
        f = rng.uniform(3000, 4600)
        place(buf, bell(f, 0.4, decay=9, partials=((1, 1.0), (1.48, 0.6), (2.33, 0.4), (3.1, 0.2))) * rng.uniform(0.4, 0.8), i * 0.06 + rng.uniform(0, 0.02))
    return finish(reverb(buf, 0.6, 0.2))


def click():
    dur = 0.07
    t = t_axis(dur)
    tone = np.sin(2 * np.pi * 1400 * t) * np.exp(-t * 90)
    tick = highpass(noise(dur), 3000) * np.exp(-t * 300) * 0.4
    return finish(tone + tick, peak=0.6)


# --------------------------------------------------------------------------
def pluck(freq, dur, bright=0.5):
    """Karplus-Strong plucked string."""
    n = int(SR * dur)
    period = int(SR / freq)
    buf = rng.uniform(-1, 1, period)
    buf = lowpass(np.concatenate([buf, buf]), 2000 + 6000 * bright)[:period]
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = 0.5 * (buf[i % period] + buf[(i + 1) % period]) * 0.996
    return out


def pad(freqs, dur):
    t = t_axis(dur)
    x = np.zeros_like(t)
    for f in freqs:
        for det in (-0.12, 0.0, 0.12):
            x += signal.sawtooth(2 * np.pi * f * (1 + det / 100) * t)
    x = lowpass(x, 1100)
    att = np.clip(t / 0.6, 0, 1)
    rel = np.clip((dur - t) / 0.6, 0, 1)
    return x * att * rel / (len(freqs) * 3)


def midi(m):
    return 440 * 2 ** ((m - 69) / 12)


def music():
    bpm = 88
    beat = 60 / bpm
    bar = beat * 4
    # I - vi - IV - V in C, twice (8 bars, ~22 s), loops seamlessly
    chords = [[48, 55, 60, 64], [45, 52, 57, 60], [41, 48, 53, 57], [43, 50, 55, 59]] * 2
    total = bar * len(chords)
    buf = np.zeros(int(SR * (total + 2)))
    melody = [72, 76, 79, 76, 74, 72, 71, 72, 69, 72, 76, 74, 72, 69, 67, 69,
              65, 69, 72, 69, 67, 65, 64, 65, 67, 71, 74, 71, 72, 74, 71, 67]  # one note per beat, 8 bars
    for ci, ch in enumerate(chords):
        start = ci * bar
        place(buf, pad([midi(n) for n in ch[1:]], bar + 0.4) * 0.5, start)
        place(buf, pluck(midi(ch[0] - 12), bar, 0.3) * 0.55, start)
        place(buf, pluck(midi(ch[0] - 12), beat * 2, 0.3) * 0.4, start + beat * 2)
        # arpeggio
        for k in range(8):
            note = ch[(k % 3) + 1] + 12
            place(buf, pluck(midi(note), beat * 1.2, 0.35) * 0.2, start + k * beat / 2)
    for k, m in enumerate(melody):
        place(buf, bell(midi(m), beat * 1.8, decay=2.6) * 0.16, k * beat)
    # soft shaker on off-beats
    for k in range(int(total / (beat / 2))):
        if k % 2 == 1:
            s = highpass(noise(0.05), 7000) * env_ad(int(SR * 0.05), 0.003, 70) * 0.05
            place(buf, s, k * beat / 2)
    wet = reverb(buf, 2.0, 0.28)
    # fold the reverb tail back to the start so the loop is seamless
    n = int(SR * total)
    loop = wet[:n].copy()
    tail = wet[n:n + int(SR * 2)]
    loop[: len(tail)] += tail
    return finish(loop, peak=0.7, fade=0.002, trim=False)


SOUNDS = {
    "Throw": throw, "Shake": shake, "Lock": lock, "Burst": burst, "Brew": brew,
    "Harvest": harvest, "Coins": coins, "Click": click, "Music": music,
}


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for name, fn in SOUNDS.items():
        x = fn()
        path = os.path.join(out, f"BG_{name}.ogg")
        sf.write(path, x, SR, format="OGG", subtype="VORBIS")
        print(f"{name:8s} {len(x) / SR:5.2f}s  -> {os.path.basename(path)}")


main()

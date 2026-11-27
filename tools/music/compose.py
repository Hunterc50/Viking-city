"""
Composes the game's original theme, "Over the Fjord": a slow Nordic piece
with a bowed drone, a low choir, a frame drum and a plucked lyre melody.
Everything is synthesised here from sine waves and noise, so the music is
our own. Writes music/VikingTheme.ogg (and .wav) that loops seamlessly.

    python3 tools/music/compose.py
"""

import os
import subprocess
import wave

import numpy as np

SR = 44100
BPM = 66
BEAT = 60 / BPM
BAR = BEAT * 4
BARS = 32
LENGTH = BARS * BAR
N = int(LENGTH * SR)
rng = np.random.default_rng(793)

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "music")


def hz(note):
    """'D3' style note name to frequency."""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    n = names[note[0]]
    rest = note[1:]
    if rest.startswith("#"):
        n += 1
        rest = rest[1:]
    elif rest.startswith("b"):
        n -= 1
        rest = rest[1:]
    octave = int(rest)
    return 440.0 * 2 ** ((n + (octave - 4) * 12) / 12)


def env(n, attack, release):
    e = np.ones(n)
    a = min(n, int(attack * SR))
    r = min(n - a, int(release * SR))
    if a:
        e[:a] = np.linspace(0, 1, a) ** 1.5
    if r:
        e[n - r:] = np.linspace(1, 0, r) ** 1.5
    return e


def add(track, start, sig):
    i = int(start * SR) % N
    # wrap past the end back to the start, so the piece loops seamlessly
    while len(sig):
        take = min(len(sig), N - i)
        track[i:i + take] += sig[:take]
        sig = sig[take:]
        i = 0


def bowed(freq, dur, amp, bright=10):
    """A tagelharpa-like bowed string: sawtooth harmonics with slow vibrato."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.004 * np.sin(2 * np.pi * 4.6 * t + rng.uniform(0, 6))
    phase = 2 * np.pi * freq * np.cumsum(vib) / SR
    sig = np.zeros(n)
    for k in range(1, bright + 1):
        sig += np.sin(k * phase + rng.uniform(0, 6)) / k ** 1.25
    # bow pressure wanders
    sig *= 0.8 + 0.2 * np.sin(2 * np.pi * 0.23 * t + rng.uniform(0, 6))
    return sig * env(n, dur * 0.3, dur * 0.35) * amp


def choir(freq, dur, amp):
    """A soft low choir: detuned sines with an 'oo' vowel."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for det in (-0.35, 0, 0.4):
        f = freq * 2 ** (det / 100 * 8)
        for k, w in ((1, 1.0), (2, 0.35), (3, 0.12), (4, 0.05)):
            sig += w * np.sin(2 * np.pi * f * k * t + rng.uniform(0, 6))
    return sig / 3 * env(n, dur * 0.4, dur * 0.45) * amp


def lyre(freq, dur, amp):
    """A plucked lyre string: harmonics that fade, the high ones first."""
    n = int((dur + 1.6) * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for k in range(1, 9):
        sig += np.sin(2 * np.pi * freq * k * t) * (0.9 / k ** 1.1) * np.exp(-t * (1.4 + k * 0.9))
    sig[: int(0.004 * SR)] *= np.linspace(0, 1, int(0.004 * SR))
    return sig * amp


def flute(freq, dur, amp):
    """A breathy wooden flute for the second theme."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.5, 0, 1)
    phase = 2 * np.pi * freq * np.cumsum(vib) / SR
    sig = np.sin(phase) + 0.25 * np.sin(2 * phase) + 0.08 * np.sin(3 * phase)
    breath = rng.standard_normal(n)
    breath = np.convolve(breath, np.ones(30) / 30, mode="same") * 0.18
    return (sig + breath) * env(n, 0.12, min(0.4, dur * 0.5)) * amp


def drum(amp, low=True):
    """A frame drum: a pitched thump and a skin of noise."""
    dur = 0.9 if low else 0.35
    n = int(dur * SR)
    t = np.arange(n) / SR
    f0 = 62 if low else 140
    pitch = f0 * (1 + 1.2 * np.exp(-t * 30))
    body = np.sin(2 * np.pi * np.cumsum(pitch) / SR) * np.exp(-t * (5 if low else 14))
    noise = rng.standard_normal(n)
    noise = np.convolve(noise, np.ones(12) / 12, mode="same") * np.exp(-t * 40) * 0.5
    sig = body + noise
    sig[: int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))  # no click
    return sig * amp


def reverb(x, seconds=3.2, mix=0.32):
    """A big stone-hall reverb, wrapped so the tail rings into the loop start."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = rng.standard_normal(n) * np.exp(-t / (seconds / 6.5))
    ir = np.convolve(ir, np.ones(8) / 8, mode="same")  # darker
    ir[: int(0.02 * SR)] = 0  # pre-delay
    ir /= np.sqrt(np.sum(ir ** 2))
    size = 1 << int(np.ceil(np.log2(len(x) + n)))
    wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x) + n]
    out = wet[: len(x)].copy()
    out[: n] += wet[len(x):]  # circular: the loop is seamless
    return x * (1 - mix) + out * mix * 1.6


def main():
    music = np.zeros(N)
    pads = np.zeros(N)

    # harmony, two bars per chord: D minor, B-flat, F, C / D minor, G minor, C, A
    chords = [
        ("D2", ["D3", "A3", "F4"]), ("Bb1", ["D3", "F3", "Bb3"]), ("F2", ["C3", "F3", "A3"]), ("C2", ["C3", "G3", "E4"]),
        ("D2", ["D3", "A3", "F4"]), ("G1", ["D3", "G3", "Bb3"]), ("C2", ["C3", "G3", "E4"]), ("A1", ["C#3", "E3", "A3"]),
    ]
    for bar in range(0, BARS, 2):
        root, voices = chords[(bar // 2) % len(chords)]
        start = bar * BAR
        add(pads, start, bowed(hz(root), BAR * 2 + 1.5, 0.22, bright=12))
        add(pads, start, bowed(hz(root) * 1.5, BAR * 2 + 1.5, 0.08, bright=6))  # open fifth
        if bar >= 4:
            for v in voices:
                add(pads, start + 0.1, choir(hz(v), BAR * 2 + 1.8, 0.09))

    # frame drum: heartbeat from bar 5, a fuller pattern in the second half
    for bar in range(4, BARS):
        t = bar * BAR
        add(music, t, drum(0.55))
        add(music, t + BEAT * 2, drum(0.4))
        if bar >= 16:
            add(music, t + BEAT * 1.5, drum(0.16, low=False))
            add(music, t + BEAT * 3, drum(0.22, low=False))
            add(music, t + BEAT * 3.5, drum(0.14, low=False))
        if bar % 8 == 7:
            for k in range(4):
                add(music, t + BEAT * (2 + k * 0.5), drum(0.18 + k * 0.05, low=False))

    # the lyre theme (bars 9-16 and 25-32): (beat offset, note, length in beats)
    theme = [
        (0, "D4", 1.5), (1.5, "E4", 0.5), (2, "F4", 1), (3, "A4", 1),
        (4, "G4", 1.5), (5.5, "F4", 0.5), (6, "D4", 2),
        (8, "F4", 1), (9, "G4", 1), (10, "A4", 1.5), (11.5, "C5", 0.5),
        (12, "A4", 1), (13, "G4", 1), (14, "E4", 2),
        (16, "D4", 1.5), (17.5, "E4", 0.5), (18, "F4", 1), (19, "A4", 1),
        (20, "Bb4", 1.5), (21.5, "A4", 0.5), (22, "G4", 2),
        (24, "F4", 1), (25, "E4", 1), (26, "C#4", 1.5), (27.5, "E4", 0.5),
        (28, "D4", 4),
    ]
    for first in (8, 24):
        for beat, note, length in theme:
            add(music, first * BAR + beat * BEAT, lyre(hz(note), length * BEAT, 0.3))
            # a quiet octave below on the long notes
            if length >= 2:
                add(music, first * BAR + beat * BEAT, lyre(hz(note) / 2, length * BEAT, 0.12))

    # the flute answers (bars 17-24)
    answer = [
        (0, "A4", 3), (3, "G4", 1), (4, "F4", 2), (6, "E4", 2),
        (8, "D5", 3), (11, "C5", 1), (12, "A4", 4),
        (16, "Bb4", 3), (19, "A4", 1), (20, "G4", 2), (22, "F4", 2),
        (24, "E4", 2), (26, "G4", 2), (28, "A4", 4),
    ]
    for beat, note, length in answer:
        add(music, 16 * BAR + beat * BEAT, flute(hz(note), length * BEAT, 0.16))

    mixdown = reverb(music, 3.4, 0.38) + reverb(pads, 4.0, 0.45)
    mixdown = np.tanh(mixdown * 1.1)  # gentle tape-like glue
    mixdown /= np.max(np.abs(mixdown)) * 1.12
    # a touch of stereo width: the reverb differs slightly left and right
    left = mixdown
    right = np.roll(mixdown, int(0.011 * SR)) * 0.96 + mixdown * 0.04

    os.makedirs(OUT, exist_ok=True)
    wav = os.path.join(OUT, "VikingTheme.wav")
    with wave.open(wav, "wb") as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(SR)
        data = np.stack([left, right], axis=1)
        f.writeframes((np.clip(data, -1, 1) * 32767).astype("<i2").tobytes())
    ogg = os.path.join(OUT, "VikingTheme.ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", ogg], check=True)
    os.remove(wav)
    print(f"wrote {ogg} ({LENGTH:.0f} s)")


if __name__ == "__main__":
    main()

"""
Original sound effects for the game's empty sound slots, made from noise and
sine waves: a war horn, wind, waves on the shore and a crackling fire.
Writes music/sfx/<Name>.ogg. Wind, Waves and Fire loop seamlessly.

    python3 tools/music/sfx.py
"""

import os
import subprocess
import wave

import numpy as np

SR = 44100
rng = np.random.default_rng(2024)
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "music", "sfx")


def lowpass(x, cutoff):
    """A simple one-pole low-pass filter, run in the frequency domain."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 / np.sqrt(1 + (f / cutoff) ** 4)
    return np.fft.irfft(X, len(x))


def bandpass(x, lo, hi):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= np.exp(-((np.log(np.maximum(f, 1) / np.sqrt(lo * hi))) / np.log(hi / lo)) ** 2 * 2)
    return np.fft.irfft(X, len(x))


def loop_noise(n, cutoff):
    # noise filtered in the frequency domain wraps around: a seamless loop
    return lowpass(rng.standard_normal(n), cutoff)


def save(name, x, stereo_delay=0.0):
    os.makedirs(OUT, exist_ok=True)
    x = x / (np.max(np.abs(x)) * 1.12)
    left = x
    right = np.roll(x, int(stereo_delay * SR)) if stereo_delay else x
    wav = os.path.join(OUT, name + ".wav")
    with wave.open(wav, "wb") as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes((np.clip(np.stack([left, right], 1), -1, 1) * 32767).astype("<i2").tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(wav)
    print("wrote", name)


def war_horn():
    dur = 4.2
    n = int(dur * SR)
    t = np.arange(n) / SR
    f0 = 98 * (1 + 0.06 * np.clip(1 - t / 0.35, 0, 1) * -1)  # it scoops up into the note
    f0 = f0 * (1 + 0.003 * np.sin(2 * np.pi * 5 * t))
    phase = 2 * np.pi * np.cumsum(f0) / SR
    sig = sum(np.sin(k * phase) * (1 / k ** 0.8) for k in range(1, 14))
    breath = bandpass(rng.standard_normal(n), 300, 2400) * 0.08
    env = np.clip(t / 0.25, 0, 1) * np.clip((dur - t) / 0.9, 0, 1)
    x = lowpass((sig + breath) * env, 1800)
    # the valley answers back
    echo = np.zeros(n + int(0.6 * SR))
    echo[:n] += x
    echo[int(0.6 * SR):] += x * 0.3
    return echo


def wind():
    n = int(20 * SR)
    t = np.arange(n) / SR
    gust = 0.55 + 0.45 * np.sin(2 * np.pi * t / 20 * 3 + 1) * np.sin(2 * np.pi * t / 20 * 2)
    whoosh = loop_noise(n, 500) * gust
    whistle = bandpass(rng.standard_normal(n), 700, 1100) * 0.25 * gust ** 3
    return whoosh + whistle


def waves():
    n = int(16 * SR)
    t = np.arange(n) / SR
    swell = np.zeros(n)
    for start in (0.0, 4.1, 8.3, 12.0):
        d = ((t - start) % 16)
        swell += np.clip(d / 1.6, 0, 1) ** 2 * np.exp(-np.maximum(d - 1.6, 0) / 1.5)
    surf = loop_noise(n, 1400) * (0.2 + swell)
    hiss = bandpass(rng.standard_normal(n), 2500, 8000) * 0.12 * swell
    return surf + hiss


def fire():
    n = int(10 * SR)
    roar = loop_noise(n, 300)
    x = roar.copy()
    # pops and crackles
    for _ in range(140):
        i = rng.integers(0, n)
        length = int(rng.uniform(0.003, 0.02) * SR)
        burst = rng.standard_normal(length) * np.exp(-np.arange(length) / (length / 4)) * rng.uniform(0.6, 2.2)
        idx = (i + np.arange(length)) % n
        x[idx] += bandpass(np.pad(burst, (0, 2048)), 1500, 6000)[:length] * 0.8
    return x


if __name__ == "__main__":
    save("WarHorn", war_horn())
    save("Wind", wind(), 0.013)
    save("Waves", waves(), 0.017)
    save("Fire", fire(), 0.007)

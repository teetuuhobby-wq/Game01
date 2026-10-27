"""Makes the game's copies of downloaded sounds (Freesound originals) so they're small and loop cleanly.

The full-size downloads live in audio_originals/ (git-ignored, keep them on your PC).
This script writes the game's versions into game/audio/<sound>/ :
  - loops (wind, town): the calmest 60 s stretch, the end blended into the start so the
    repeat can't be heard, at 32 kHz 16-bit (about a third of the size)
  - one-off sounds (bell, creaks): 16-bit, silence at the start cut, a short fade at the end
Every sound is brought to a similar loudness, so the sound board's volumes start sensibly.

Usage (from the repo root):  py -3 tools/prepare_sounds.py
Needs numpy. Add new sounds to JOBS below.
"""
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "audio_originals")
DST = os.path.join(ROOT, "game", "audio")

# (original file, game file, kind)
JOBS = [
    ("825860__vrymaa__desert-sand-dune-atmosphere.wav", "wind/825860_vrymaa_dune_loop.wav", "loop"),
    ("818390__sounds_from_palestine__street-village-ambience-on-a-summer-windy-day.wav",
     "town/818390_sounds_from_palestine_village_loop.wav", "loop"),
    ("378799__kgeshev__bell.wav", "bell/378799_kgeshev_bell.wav", "one"),
    ("456814__breviceps__creaking-wood.wav", "creak/456814_breviceps_creaking_wood.wav", "one"),
    ("113361__deleted_user_1371021__shipcreaks1.wav", "creak/113361_shipcreaks1.wav", "one"),
    ("113362__deleted_user_1371021__shipcreaks2.wav", "creak/113362_shipcreaks2.wav", "one"),
    ("496836__hinchinbrook__metallic-groan.wav", "creak/496836_hinchinbrook_metallic_groan.wav", "one"),
]

LOOP_SECONDS = 60.0
LOOP_FADE = 4.0     # seconds of the end blended into the start
LOOP_RATE = 32000
LOOP_RMS_DB = -22.0  # loops: steady background level
ONE_PEAK_DB = -1.0   # one-off sounds: loudest moment just under full scale


def read_wav(path):
    with wave.open(path) as w:
        ch, width, rate, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(n)
    if width == 2:
        x = np.frombuffer(raw, "<i2").astype(np.float64) / 32768.0
    elif width == 3:
        b = np.frombuffer(raw, np.uint8).reshape(-1, 3).astype(np.int32)
        v = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        v = np.where(v >= 1 << 23, v - (1 << 24), v)
        x = v.astype(np.float64) / float(1 << 23)
    else:
        raise ValueError("%s: %d-bit wav not handled" % (path, width * 8))
    return x.reshape(-1, ch), rate


def write_wav(path, x, rate):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = (np.clip(x, -1.0, 1.0) * 32767.0).round().astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(x.shape[1])
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(data.tobytes())


def resample(x, src, dst):
    """Clean change of sample rate (through the spectrum, so no harsh aliasing)."""
    if src == dst:
        return x
    n = x.shape[0]
    m = int(round(n * dst / src))
    spec = np.fft.rfft(x, axis=0)
    keep = m // 2 + 1
    if keep <= spec.shape[0]:
        spec = spec[:keep]
    else:
        spec = np.vstack([spec, np.zeros((keep - spec.shape[0], x.shape[1]))])
    return np.fft.irfft(spec, n=m, axis=0) * (m / n)


def envelope(x, rate, step=0.5):
    hop = int(rate * step)
    mono = x.mean(axis=1)
    k = len(mono) // hop
    return np.sqrt((mono[: k * hop].reshape(k, hop) ** 2).mean(axis=1) + 1e-12)


def calmest_start(x, rate, seconds):
    """Start of the stretch with the fewest sudden loud moments (a car horn, a bump on the mic)."""
    env = envelope(x, rate)
    win = int(seconds / 0.5)
    if len(env) <= win:
        return 0
    best, best_score = 0, None
    for s in range(0, len(env) - win, 2):
        e = env[s: s + win]
        score = e.max() / np.median(e)
        if best_score is None or score < best_score:
            best, best_score = s, score
    return int(best * 0.5 * rate)


def make_loop(x, rate):
    length = int(LOOP_SECONDS * rate)
    fade = int(LOOP_FADE * rate)
    length = min(length, x.shape[0] - fade)
    start = calmest_start(x, rate, (length + fade) / rate)
    win = x[start: start + length + fade]
    out = win[:length].copy()
    # Equal-power blend: the loop's start fades in from what follows its end,
    # so playing out[-1] then out[0] is the same as playing on through the recording.
    t = np.linspace(0.0, 1.0, fade)[:, None]
    out[:fade] = win[:fade] * np.sin(t * np.pi / 2) + win[length: length + fade] * np.cos(t * np.pi / 2)
    out = resample(out, rate, LOOP_RATE)
    rms = np.sqrt((out ** 2).mean())
    gain = min(10 ** (LOOP_RMS_DB / 20) / rms, 10 ** (ONE_PEAK_DB / 20) / np.abs(out).max())
    return out * gain, LOOP_RATE


def make_one(x, rate):
    peak = np.abs(x).max()
    level = np.abs(x).max(axis=1)
    start = max(0, np.nonzero(level > peak * 0.01)[0][0] - int(0.005 * rate))
    # Keep the tail until it's very quiet (a bell rings on for a long time)
    end = min(x.shape[0], np.nonzero(level > peak * 0.002)[0][-1] + int(0.05 * rate))
    out = x[start:end].copy()
    fade = min(int(0.05 * rate), out.shape[0] // 4)
    out[-fade:] *= np.linspace(1.0, 0.0, fade)[:, None]
    return out * (10 ** (ONE_PEAK_DB / 20) / peak), rate


def main():
    for src, dst, kind in JOBS:
        path = os.path.join(SRC, src)
        if not os.path.exists(path):
            print("missing (skipped):", src)
            continue
        x, rate = read_wav(path)
        out, out_rate = make_loop(x, rate) if kind == "loop" else make_one(x, rate)
        write_wav(os.path.join(DST, dst), out, out_rate)
        print("%-55s %5.1f s  %d ch  %d Hz  %.1f MB" % (
            dst, out.shape[0] / out_rate, out.shape[1], out_rate, os.path.getsize(os.path.join(DST, dst)) / 1e6))


if __name__ == "__main__":
    main()

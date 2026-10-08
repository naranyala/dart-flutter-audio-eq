#!/usr/bin/env python3
"""Generate assets/samples/demo.wav — bundled EQ audition loop.

6 s, 44.1 kHz mono 16-bit: alternating bass roots (A2/E3) + A-major
arpeggio + soft high shimmer, so bass / mid / treble slider moves are all
audible. Deterministic output; re-run to regenerate.

Usage: python3 tool/make_demo_wav.py
"""

import math
import struct
import wave
from pathlib import Path

SR = 44100
SECONDS = 6
OUT = Path(__file__).resolve().parent.parent / "assets" / "samples" / "demo.wav"

A2, E3 = 110.0, 164.81
ARPEGGIO = [220.0, 277.18, 329.63, 440.0]  # A3 C#4 E4 A4
SHIMMER = 3520.0


def note(freq: float, t: float, dur: float, amp: float) -> float:
    """One decaying note with 2 harmonics, starting at t=0 (local time)."""
    if t < 0 or t >= dur:
        return 0.0
    env = math.exp(-2.2 * t / dur)
    w = 2 * math.pi * freq * t
    return amp * env * (
        math.sin(w) + 0.35 * math.sin(2 * w) + 0.12 * math.sin(3 * w)
    )


def main() -> None:
    n = SR * SECONDS
    samples = [0.0] * n
    for i in range(n):
        t = i / SR
        bar = int(t // 1.5)  # 1.5 s per chord root
        root = A2 if bar % 2 == 0 else E3
        v = note(root, t % 1.5, 1.5, 0.5)
        arp_idx = int(t * 2) % len(ARPEGGIO)  # 2 notes/s
        v += note(ARPEGGIO[arp_idx], t % 0.5, 0.5, 0.28)
        v += 0.05 * math.sin(2 * math.pi * SHIMMER * t)
        # global fade in/out to avoid clicks on loop
        fade = min(1.0, t / 0.3, (SECONDS - t) / 0.3)
        samples[i] = v * max(0.0, fade)

    peak = max(abs(s) for s in samples) or 1.0
    gain = 0.7 / peak
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(
            b"".join(
                struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767))
                for s in samples
            )
        )
    print(f"wrote {OUT} ({SECONDS}s @ {SR}Hz)")


if __name__ == "__main__":
    main()

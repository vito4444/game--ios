#!/usr/bin/env python3
"""Generate the game's sound effects from code.

Same reasoning as the art: no third-party samples means nothing to license or
attribute at submission, and the output is deterministic so CI can diff it.

    python3 tools/gen_audio.py            # write WAVs into assets/generated/audio
    python3 tools/gen_audio.py --check    # fail if the committed WAVs are stale
"""

from __future__ import annotations

import argparse
import io
import math
import random
import struct
import wave
from pathlib import Path
from typing import Callable, Sequence

SAMPLE_RATE = 22050
AMPLITUDE = 26000

REPO_ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = REPO_ROOT / "assets" / "generated" / "audio"

Envelope = Callable[[float], float]


def _adsr(attack: float, decay: float, sustain: float, release: float) -> Envelope:
    """Envelope over a normalised 0-1 position through the sound."""

    def shape(position: float) -> float:
        if position < attack:
            return position / attack if attack > 0 else 1.0
        if position < attack + decay:
            through = (position - attack) / decay
            return 1.0 + (sustain - 1.0) * through
        if position < 1.0 - release:
            return sustain
        remaining = (1.0 - position) / release if release > 0 else 0.0
        return sustain * max(remaining, 0.0)

    return shape


def _tone(
    frequency: float,
    seconds: float,
    envelope: Envelope,
    harmonics: Sequence[tuple[float, float]] = ((1.0, 1.0),),
    sweep: float = 1.0,
) -> list[float]:
    samples: list[float] = []
    total = int(SAMPLE_RATE * seconds)
    for index in range(total):
        position = index / total
        time = index / SAMPLE_RATE
        pitch = frequency * (1.0 + (sweep - 1.0) * position)
        value = 0.0
        for multiple, weight in harmonics:
            value += weight * math.sin(math.tau * pitch * multiple * time)
        samples.append(value * envelope(position))
    return samples


def _noise(seconds: float, envelope: Envelope, seed: int, smoothing: int = 1) -> list[float]:
    rng = random.Random(seed)
    total = int(SAMPLE_RATE * seconds)
    raw = [rng.uniform(-1.0, 1.0) for _ in range(total)]
    if smoothing > 1:
        # A cheap low-pass, which turns hiss into something more like air.
        window: list[float] = []
        smoothed: list[float] = []
        for value in raw:
            window.append(value)
            if len(window) > smoothing:
                window.pop(0)
            smoothed.append(sum(window) / len(window))
        raw = smoothed
    return [value * envelope(index / total) for index, value in enumerate(raw)]


def _mix(*layers: list[float]) -> list[float]:
    length = max(len(layer) for layer in layers)
    out = [0.0] * length
    for layer in layers:
        for index, value in enumerate(layer):
            out[index] += value
    return out


def _normalise(samples: list[float], peak: float = 0.9) -> list[float]:
    loudest = max((abs(value) for value in samples), default=0.0)
    if loudest == 0.0:
        return samples
    scale = peak / loudest
    return [value * scale for value in samples]


# --------------------------------------------------------------------------
# The sounds themselves
# --------------------------------------------------------------------------


def ui_click() -> list[float]:
    return _tone(660.0, 0.05, _adsr(0.01, 0.02, 0.4, 0.5), ((1.0, 1.0), (2.0, 0.3)))


def ui_back() -> list[float]:
    return _tone(440.0, 0.08, _adsr(0.01, 0.05, 0.3, 0.5), ((1.0, 1.0),), sweep=0.7)


def door_open() -> list[float]:
    return _mix(
        _noise(0.35, _adsr(0.05, 0.15, 0.5, 0.4), seed=11, smoothing=24),
        _tone(160.0, 0.35, _adsr(0.05, 0.2, 0.35, 0.4), ((1.0, 0.6), (2.0, 0.2)), sweep=1.35),
    )


def door_close() -> list[float]:
    return _mix(
        _noise(0.3, _adsr(0.02, 0.1, 0.4, 0.5), seed=12, smoothing=24),
        _tone(200.0, 0.3, _adsr(0.02, 0.15, 0.3, 0.5), ((1.0, 0.6),), sweep=0.6),
    )


def pick_up() -> list[float]:
    return _mix(
        _tone(520.0, 0.12, _adsr(0.01, 0.05, 0.5, 0.4), ((1.0, 1.0), (3.0, 0.25)), sweep=1.5),
        _noise(0.1, _adsr(0.01, 0.04, 0.2, 0.6), seed=21, smoothing=6),
    )


def craft_done() -> list[float]:
    return _mix(
        _tone(392.0, 0.28, _adsr(0.02, 0.1, 0.6, 0.35)),
        _tone(587.0, 0.28, _adsr(0.12, 0.1, 0.5, 0.35), ((1.0, 0.7),)),
    )


def alarm() -> list[float]:
    """Two-tone warble, the sound of having been seen."""
    first = _tone(740.0, 0.3, _adsr(0.02, 0.05, 0.9, 0.1), ((1.0, 1.0), (2.0, 0.35)))
    second = _tone(560.0, 0.3, _adsr(0.02, 0.05, 0.9, 0.1), ((1.0, 1.0), (2.0, 0.35)))
    return first + second + first + second


def blackout() -> list[float]:
    """Power winding down: a hum that loses its pitch."""
    return _mix(
        _tone(120.0, 1.1, _adsr(0.02, 0.2, 0.7, 0.5), ((1.0, 1.0), (2.0, 0.3)), sweep=0.35),
        _noise(1.1, _adsr(0.1, 0.3, 0.25, 0.5), seed=31, smoothing=40),
    )


def power_restored() -> list[float]:
    return _mix(
        _tone(90.0, 0.9, _adsr(0.3, 0.2, 0.8, 0.3), ((1.0, 1.0), (2.0, 0.25)), sweep=1.6),
        _noise(0.9, _adsr(0.2, 0.3, 0.2, 0.4), seed=32, smoothing=40),
    )


def bubble() -> list[float]:
    """Played while the air gauge is running down."""
    return _mix(
        _tone(300.0, 0.22, _adsr(0.02, 0.08, 0.4, 0.5), ((1.0, 0.8), (1.5, 0.3)), sweep=1.8),
        _noise(0.22, _adsr(0.02, 0.06, 0.2, 0.6), seed=41, smoothing=12),
    )


def out_of_air() -> list[float]:
    return _mix(
        _tone(220.0, 1.0, _adsr(0.05, 0.3, 0.5, 0.4), ((1.0, 1.0), (0.5, 0.4)), sweep=0.4),
        _noise(1.0, _adsr(0.05, 0.2, 0.3, 0.6), seed=42, smoothing=30),
    )


def caught() -> list[float]:
    return _mix(
        _tone(180.0, 0.6, _adsr(0.01, 0.15, 0.5, 0.4), ((1.0, 1.0), (1.5, 0.4)), sweep=0.5),
        _noise(0.6, _adsr(0.01, 0.1, 0.3, 0.5), seed=51, smoothing=16),
    )


def escaped() -> list[float]:
    """Rising three-note figure. The only unambiguously good sound in the game."""
    return (
        _tone(392.0, 0.24, _adsr(0.02, 0.08, 0.7, 0.3))
        + _tone(523.0, 0.24, _adsr(0.02, 0.08, 0.7, 0.3))
        + _tone(659.0, 0.5, _adsr(0.02, 0.15, 0.6, 0.4), ((1.0, 1.0), (2.0, 0.25)))
    )


SOUNDS: tuple[tuple[str, Callable[[], list[float]]], ...] = (
    ("ui_click", ui_click),
    ("ui_back", ui_back),
    ("door_open", door_open),
    ("door_close", door_close),
    ("pick_up", pick_up),
    ("craft_done", craft_done),
    ("alarm", alarm),
    ("blackout", blackout),
    ("power_restored", power_restored),
    ("bubble", bubble),
    ("out_of_air", out_of_air),
    ("caught", caught),
    ("escaped", escaped),
)


# --------------------------------------------------------------------------
# Writing
# --------------------------------------------------------------------------


def _wav_bytes(samples: list[float]) -> bytes:
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, value)) * AMPLITUDE))
            for value in samples
        )
        handle.writeframes(frames)
    return buffer.getvalue()


def generate(check_only: bool = False) -> int:
    ok = True
    if not check_only:
        OUT_DIR.mkdir(parents=True, exist_ok=True)

    for name, build in SOUNDS:
        path = OUT_DIR / f"{name}.wav"
        data = _wav_bytes(_normalise(build()))

        if check_only:
            if not path.exists():
                print(f"MISSING  {path.relative_to(REPO_ROOT)}")
                ok = False
            elif path.read_bytes() != data:
                print(f"STALE    {path.relative_to(REPO_ROOT)}")
                ok = False
            else:
                print(f"ok       {path.relative_to(REPO_ROOT)}")
            continue

        path.write_bytes(data)
        seconds = len(data) / (SAMPLE_RATE * 2)
        print(f"wrote    {path.relative_to(REPO_ROOT)}  {seconds:.2f}s")

    return 0 if ok else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify committed WAVs match what this script produces, without writing",
    )
    args = parser.parse_args()
    return generate(check_only=args.check)


if __name__ == "__main__":
    raise SystemExit(main())

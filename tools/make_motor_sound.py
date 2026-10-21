#!/usr/bin/env python3
"""Perämoottorin äänet oikeasta nauhoituksesta.

Lähde: data/sounds/outboard_kyles_637744.mp3, "outboard motor boat onboard
high speed" (kyles, Freesound 637744, CC0), Freesoundin esikuuntelutiedosto.
Nauhoitus on tehty veneestä täydellä vauhdilla, ja moottori käy tasaisesti
noin 49 Hz:n sytytystaajuudella. Siitä leikataan saumaton silmukka;
käynnistykseen tulee narun nykäisyt ja silmukan alku, sammutukseen hidastuva
silmukka.

Käyttö (vaatii uv:n, joka hakee mp3-purkajan):
    uv run --no-project --with miniaudio --with numpy python tools/make_motor_sound.py
"""
import os
import sys

import miniaudio
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from make_sounds import SR, band, damped_sine, filtered, mix, place, rng, save, splash_burst  # noqa: E402

SOURCE = os.path.join(os.path.dirname(__file__), '..', 'data', 'sounds', 'outboard_kyles_637744.mp3')
LOOP_START, LOOP_END = 30.0, 38.0  # tasainen kohta nauhoituksessa (s)
CROSSFADE = 0.4  # silmukan saumaan (s)


def load():
    d = miniaudio.decode_file(SOURCE, output_format=miniaudio.SampleFormat.SIGNED16, nchannels=1, sample_rate=SR)
    return np.array(d.samples, dtype=np.float64) / 32767


def motor_loop(x):
    """Silmukan loppu ristihäivytetään alkua edeltävään kohtaan, jolloin
    lopusta jatketaan saumattomasti alkuun."""
    a, b, n = int(LOOP_START * SR), int(LOOP_END * SR), int(CROSSFADE * SR)
    loop = x[a:b].copy()
    loop[-n:] = x[b - n:b] * np.cos(np.linspace(0, np.pi / 2, n)) + x[a - n:a] * np.sin(np.linspace(0, np.pi / 2, n))
    return loop


def motor_start(loop):
    """Narun nykäisy, yskähdys ja käynnistyminen."""
    out = np.zeros(int(2.2 * SR))
    for start, length in [(0.0, 0.45), (0.75, 0.5)]:
        n = int(length * SR)
        zip_noise = filtered(rng.standard_normal(n), band(600, 4000)) * np.sin(np.linspace(0, np.pi, n)) ** 2
        place(out, zip_noise, start, 0.35)
        # Mäntä pyörähtää: muutama puskahdus
        for k in range(5):
            place(out, mix(damped_sine(70 + k * 8, 0.12, 0.04), splash_burst(0.1, 200, 1500, decay=0.03) * 0.4), start + 0.05 + k * 0.08, 0.5)
    # Käynnistyy: silmukan alku voimistuu
    engine = loop[: int(0.9 * SR)]
    engine = engine / np.max(np.abs(engine)) * np.minimum(1, np.linspace(0, 3, len(engine)))
    place(out, engine, 1.3, 0.8)
    return out


def motor_stop(loop):
    engine = loop[: int(0.7 * SR)]
    n = len(engine)
    # Hidastuva: resamplataan pidemmäksi ja hiljennetään
    idx = np.cumsum(np.linspace(1.0, 0.35, int(n * 1.6)))
    idx = idx[idx < n - 1].astype(int)
    slowed = engine[idx]
    return slowed * np.linspace(1, 0, len(slowed)) ** 1.5


def main():
    loop = motor_loop(load())
    save('motor_loop', loop, fades=False)
    save('motor_start', motor_start(loop))
    save('motor_stop', motor_stop(loop))


if __name__ == '__main__':
    main()

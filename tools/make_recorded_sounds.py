#!/usr/bin/env python3
"""Pelin äänet oikeista nauhoituksista (Freesound, kaikki CC0).

Lähteet ovat kansiossa data/sounds/ (Freesoundin esikuuntelutiedostot):
  outboard_kyles_637744.mp3             perämoottori veneestä täydellä vauhdilla
  waves_small_mcmikai_532179.mp3        kesäjärven aallot (pienet aallot)
  waves_big_ali6868_384360.mp3          aallot aallonmurtajaan (isot aallot)
  wind_light_kyles_454360.mp3           heikko puuskittainen tuuli
  wind_strong_teadrinker_403051.mp3     kova tuuli ruotsalaisessa metsässä
  wind_light_winter_mhcerberus_141143.mp3  talven heikko tuuli, puut narisevat
  wind_strong_winter_jpnien_97397.mp3   kova talvituuli
  oars_skibkamusic_478973.mp3           airovedot (lapa veteen, hankaimen kolahdus)
  paddle_danjocross_503208.mp3          kajakin melonta tyynellä järvellä yöllä

Tasaisista kohdista leikataan saumattomat silmukat ja niiden voimakkuus
asetetaan entisten syntetisoitujen äänten tasolle. Moottorin käynnistykseen
tulee narun nykäisyt ja silmukan alku, sammutukseen hidastuva silmukka.
Airo- ja melavedoista leikataan yksittäiset vedot muunnelmiksi (_1, _2, ...).

Käyttö (vaatii uv:n, joka hakee mp3-purkajan):
    uv run --no-project --with miniaudio --with numpy python tools/make_recorded_sounds.py
"""
import os
import sys

import miniaudio
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from make_sounds import OUT, SR, band, damped_sine, filtered, mix, place, rng, save, splash_burst  # noqa: E402

SOURCES = os.path.join(os.path.dirname(__file__), '..', 'data', 'sounds')

# Silmukat: nimi -> (lähde, alku s, loppu s, ylipäästö Hz, alipäästö Hz, tavoite-RMS).
# Pienten aaltojen nauhoitus on hiljainen ja sitä vahvistetaan paljon, jolloin
# mp3-pakkauksen sihinä kuuluisi löylyn kihinänä: alipäästö poistaa sen. Kovan
# tuulen metsäkahinasta vaimennetaan korkein kihinä samasta syystä.
LOOPS = {
    'water_lap_loop': ('waves_small_mcmikai_532179.mp3', 20.5, 40.5, 60, 2500, 0.077),
    'water_waves_loop': ('waves_big_ali6868_384360.mp3', 38.5, 58.5, 40, None, 0.095),
    'wind_light_loop': ('wind_light_kyles_454360.mp3', 43.0, 63.0, 25, None, 0.155),
    'wind_strong_loop': ('wind_strong_teadrinker_403051.mp3', 21.5, 41.5, 25, 3500, 0.155),
    'wind_light_winter_loop': ('wind_light_winter_mhcerberus_141143.mp3', 1.0, 15.5, 25, None, 0.155),
    'wind_strong_winter_loop': ('wind_strong_winter_jpnien_97397.mp3', 1.0, 21.0, 40, None, 0.155),
}
CROSSFADE = 1.0  # taustaäänten silmukan saumaan (s)

# Yksittäiset vedot: nimi -> (lähde, [vedon huippu nauhoituksessa s]).
# Peli soittaa satunnaisen muunnelman (game_audio.gd).
STROKES = {
    'oar_stroke': ('oars_skibkamusic_478973.mp3', [0.8, 5.5, 7.65, 10.6, 13.05]),
    'paddle_stroke': ('paddle_danjocross_503208.mp3', [21.65, 23.85, 30.75, 42.9]),
}
STROKE_LENGTH = 1.1  # s

MOTOR_SOURCE = 'outboard_kyles_637744.mp3'
MOTOR_START, MOTOR_END = 30.0, 38.0  # tasainen kohta nauhoituksessa (s)
MOTOR_CROSSFADE = 0.4


def load(name):
    d = miniaudio.decode_file(os.path.join(SOURCES, name), output_format=miniaudio.SampleFormat.SIGNED16,
                              nchannels=1, sample_rate=SR)
    return np.array(d.samples, dtype=np.float64) / 32767


def make_loop(x, start, end, crossfade):
    """Silmukan loppu ristihäivytetään alkua edeltävään kohtaan, jolloin
    lopusta jatketaan saumattomasti alkuun."""
    a, b, n = int(start * SR), int(end * SR), int(crossfade * SR)
    loop = x[a:b].copy()
    loop[-n:] = x[b - n:b] * np.cos(np.linspace(0, np.pi / 2, n)) + x[a - n:a] * np.sin(np.linspace(0, np.pi / 2, n))
    return loop


def save_rms(name, x, rms):
    """Tallentaa silmukan tavoitevoimakkuuteen; yksittäiset huiput pehmennetään."""
    x = x * rms / np.sqrt(np.mean(x ** 2))
    x = 0.98 * np.tanh(x / 0.98)
    save(name, x, peak=np.max(np.abs(x)), fades=False)


def cut_stroke(x, peak):
    """Veto alkaa hieman ennen kuin ääni nousee (30 % huipusta) ja häipyy loppua kohti."""
    a = int(max(0.0, peak - 0.3) * SR)
    seg = x[a:a + int((STROKE_LENGTH + 0.3) * SR)]
    env = np.convolve(np.abs(seg), np.ones(int(0.01 * SR)) / int(0.01 * SR), mode='same')
    onset = int(np.argmax(env > 0.3 * env.max()))
    seg = seg[max(0, onset - int(0.03 * SR)):][:int(STROKE_LENGTH * SR)].copy()
    return seg * np.minimum(1.0, np.linspace(1.6, 0.0, len(seg))) ** 1.5  # loppu häipyy


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
    loop = make_loop(load(MOTOR_SOURCE), MOTOR_START, MOTOR_END, MOTOR_CROSSFADE)
    save('motor_loop', loop, fades=False)
    save('motor_start', motor_start(loop))
    save('motor_stop', motor_stop(loop))
    for name, (source, start, end, highpass, lowpass, rms) in LOOPS.items():
        x = filtered(load(source), lambda f, hp=highpass: 1.0 / (1.0 + (hp / f) ** 4))
        if lowpass:
            x = filtered(x, lambda f, lp=lowpass: 1.0 / (1.0 + (f / lp) ** 4))
        save_rms(name, make_loop(x, start, end, CROSSFADE), rms)
    for name, (source, peaks) in STROKES.items():
        x = filtered(load(source), lambda f: 1.0 / (1.0 + (60 / f) ** 4))
        for i, peak in enumerate(peaks):
            save(f'{name}_{i + 1}', cut_stroke(x, peak))


if __name__ == '__main__':
    main()

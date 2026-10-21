#!/usr/bin/env python3
"""Syntetisoi pelin äänet WAV-tiedostoiksi (assets/sounds/).

Kaikki äänet tehdään tässä itse, joten niissä ei ole lisenssirajoituksia.
Toistuvat taustaäänet (*_loop) on tehty taajuustasossa, jolloin ne ovat
jaksollisia ja toistuvat saumattomasti. Perämoottorin, aaltojen ja tuulen äänet
tehdään oikeista nauhoituksista työkalulla tools/make_recorded_sounds.py.

Käyttö: python3 tools/make_sounds.py            (kaikki äänet)
        python3 tools/make_sounds.py NIMI ...   (vain nimetyt, esim. reel_loop)
"""
import os
import sys
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')
rng = np.random.default_rng(2026)


# --- Apufunktiot --------------------------------------------------------------

def t_axis(seconds):
    return np.arange(int(seconds * SR)) / SR


def shaped_noise(seconds, shape):
    """Kohinaa, jonka spektri muotoillaan funktiolla shape(taajuus) -> vahvistus.
    Tulos on jaksollinen, joten se toistuu saumattomasti."""
    n = int(seconds * SR)
    spectrum = np.fft.rfft(rng.standard_normal(n))
    freqs = np.fft.rfftfreq(n, 1 / SR)
    spectrum *= shape(np.maximum(freqs, 1.0))
    out = np.fft.irfft(spectrum, n)
    return out / (np.max(np.abs(out)) + 1e-9)


def band(lo, hi, slope=2.0):
    """Kaistanpäästö: pehmeät reunat taajuuksien lo ja hi kohdalla."""
    return lambda f: 1.0 / (1.0 + (lo / f) ** slope) / (1.0 + (f / hi) ** slope)


def filtered(x, shape):
    spectrum = np.fft.rfft(x)
    spectrum *= shape(np.maximum(np.fft.rfftfreq(len(x), 1 / SR), 1.0))
    return np.fft.irfft(spectrum, len(x))


def envelope(n, attack, decay, hold=0.0):
    t = np.arange(n) / SR
    env = np.where(t < attack, t / max(attack, 1e-6), np.exp(-(t - attack - hold).clip(0) / decay))
    return env


def mix(*parts):
    """Summaa eri pituiset äänet (lyhyemmät täytetään hiljaisuudella)."""
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def place(target, sound, start, gain=1.0, wrap=False):
    """Lisää äänen kohtaan start (s). wrap=True kierrättää lopun alkuun (silmukat)."""
    i = int(start * SR)
    n = len(sound)
    if wrap:
        idx = (np.arange(n) + i) % len(target)
        np.add.at(target, idx, sound * gain)
    else:
        end = min(len(target), i + n)
        target[i:end] += sound[: end - i] * gain


def normalize(x, peak=0.9):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def fade(x, fade_in=0.005, fade_out=0.02):
    n_in, n_out = int(fade_in * SR), int(fade_out * SR)
    x = x.copy()
    if n_in:
        x[:n_in] *= np.linspace(0, 1, n_in)
    if n_out:
        x[-n_out:] *= np.linspace(1, 0, n_out)
    return x


def save(name, x, peak=0.9, fades=True):
    if fades:
        x = fade(x, fade_in=0.0005)  # lyhyt, ettei terävä alku (napsahdus) katoa
    x = normalize(x, peak)
    data = (x * 32767).astype('<i2')
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f'{name:18s} {len(x) / SR:5.2f} s')


def splash_burst(seconds, lo, hi, attack=0.004, decay=0.12):
    n = int(seconds * SR)
    return filtered(rng.standard_normal(n), band(lo, hi)) * envelope(n, attack, decay)


def damped_sine(freq, seconds, decay, glide=1.0):
    t = t_axis(seconds)
    f = freq * glide ** (t / seconds)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / decay)


def drop(seconds=0.05, f0=1400, f1=2600, decay=0.015):
    """Vesipisara: nopeasti nouseva sinikirahdus (kuplan resonanssi)."""
    t = t_axis(seconds)
    f = f0 + (f1 - f0) * (t / seconds)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / decay)


# --- Ympäristö -------------------------------------------------------------

def rain_loop():
    """Sade: kohina ja tiheät pisaroiden napsahdukset veteen."""
    seconds = 8.0
    out = 0.5 * shaped_noise(seconds, lambda f: band(600, 9000, 1.5)(f) / np.sqrt(f / 600))
    for _ in range(900):
        place(out, drop(seconds=0.03, f0=rng.uniform(1500, 3000), f1=rng.uniform(3000, 5000), decay=0.006), rng.uniform(0, seconds), rng.uniform(0.1, 0.5), wrap=True)
    return out


def ice_drill():
    """Jääkaira: terä raapii jäätä kierros kerrallaan, lopussa vesi pulpahtaa."""
    seconds = 3.2
    t = t_axis(seconds)
    scrape = shaped_noise(seconds, band(900, 6000)) * (0.55 + 0.45 * np.abs(np.sin(2 * np.pi * 1.6 * t)))
    crunch = np.zeros_like(t)
    for _ in range(140):
        place(crunch, splash_burst(0.03, 1500, 7000, attack=0.001, decay=0.008), rng.uniform(0, seconds - 0.4), rng.uniform(0.2, 0.7))
    out = 0.6 * scrape + crunch
    out *= np.minimum(1.0, t / 0.15)
    gulp = mix(damped_sine(160, 0.4, 0.1, glide=0.7), splash_burst(0.4, 200, 2000, decay=0.1) * 0.6)
    place(out, gulp, seconds - 0.45, 0.9)
    return out


def snow_step():
    """Askel kovalla lumella: narskahdus."""
    n = int(0.22 * SR)
    crunch = filtered(rng.standard_normal(n), band(700, 5000)) * envelope(n, 0.01, 0.05)
    for _ in range(6):
        place(crunch, splash_burst(0.02, 2000, 8000, attack=0.001, decay=0.005), rng.uniform(0.0, 0.12), 0.4)
    return crunch


def chaffinch_song():
    """Peippo: kiihtyvä, laskeva sarja ja lopun koukero."""
    out = np.zeros(int(2.2 * SR))
    time = 0.0
    for i in range(11):
        f0 = 5200 - i * 160
        note = damped_sine(f0, 0.07, 0.03, glide=0.75)
        place(out, note * envelope(len(note), 0.005, 0.03), time, 0.8)
        time += 0.11 - i * 0.004
    for f0, glide in [(3800, 1.4), (5200, 0.6), (4200, 0.7)]:
        note = damped_sine(f0, 0.12, 0.06, glide=glide)
        place(out, note * envelope(len(note), 0.012, 0.05), time, 1.0)
        time += 0.1
    return out


def great_tit_call():
    """Talitiainen: "ti-tyy, ti-tyy"."""
    out = np.zeros(int(1.8 * SR))
    time = 0.0
    for _ in range(3):
        for f0, dur in [(5400, 0.09), (3900, 0.16)]:
            note = damped_sine(f0, dur, dur * 0.8, glide=0.97)
            note *= envelope(len(note), 0.01, dur * 0.6)
            place(out, note, time)
            time += dur + 0.04
        time += 0.08
    return out


def loon_call():
    """Kuikka: pitkä, nouseva ja laskeva valitus vibraton kera."""
    seconds = 4.2
    t = t_axis(seconds)
    pitch = np.interp(t, [0, 0.8, 1.6, 2.2, 3.2, 4.2], [560, 760, 740, 980, 900, 700])
    vibrato = 1 + 0.012 * np.sin(2 * np.pi * 5.5 * t)
    phase = 2 * np.pi * np.cumsum(pitch * vibrato) / SR
    tone = np.sin(phase) + 0.35 * np.sin(2 * phase) + 0.12 * np.sin(3 * phase)
    amp = np.interp(t, [0, 0.3, 1.5, 1.8, 2.1, 3.6, 4.2], [0, 1, 0.9, 0.4, 1, 0.8, 0])
    return tone * amp


# --- Vene --------------------------------------------------------------------

def oar_catch():
    """Lapa veteen: loiskahdus ja airon kolahdus hankaimessa."""
    out = np.zeros(int(0.6 * SR))
    place(out, splash_burst(0.5, 400, 3500, attack=0.01, decay=0.12), 0.0, 1.0)
    knock = mix(damped_sine(310, 0.08, 0.02), 0.6 * damped_sine(720, 0.06, 0.012))
    place(out, knock, 0.02, 0.6)
    return out


def oar_drip():
    out = np.zeros(int(0.9 * SR))
    for _ in range(6):
        place(out, drop(f0=rng.uniform(1000, 1600), f1=rng.uniform(2000, 3200)), rng.uniform(0.0, 0.8), rng.uniform(0.3, 1.0))
    return out


def boat_bump():
    return mix(damped_sine(85, 0.5, 0.12), 0.7 * damped_sine(160, 0.4, 0.07), 0.3 * damped_sine(410, 0.2, 0.03),
               0.5 * splash_burst(0.2, 100, 1200, decay=0.04))


def prop_strike():
    """Potkuri osuu pohjaan: metallinen kolahdus, kivien ja soran rahina
    lapojen raapiessa pohjaa ja moottorin hetkellinen töksähdys."""
    out = np.zeros(int(0.9 * SR))
    clank = mix(damped_sine(870, 0.4, 0.07), 0.7 * damped_sine(1430, 0.3, 0.05),
                0.5 * damped_sine(2310, 0.25, 0.035), 0.3 * damped_sine(3650, 0.15, 0.02))
    place(out, clank, 0.0, 0.8)
    # Lavat raapivat pohjaa: tiheitä rahinapurskeita
    for k in range(9):
        place(out, splash_burst(0.06, 900, 6000, attack=0.002, decay=0.015), 0.02 + k * 0.045 + rng.uniform(0, 0.01), 0.5 * (1.0 - k / 10))
    place(out, mix(damped_sine(70, 0.35, 0.09), 0.5 * damped_sine(130, 0.3, 0.06)), 0.0, 0.9)
    return out


def anchor_drop():
    out = np.zeros(int(1.2 * SR))
    place(out, splash_burst(0.8, 200, 2500, attack=0.005, decay=0.18), 0.0)
    place(out, damped_sine(140, 0.4, 0.1, glide=0.7), 0.0, 0.6)
    for _ in range(8):
        place(out, drop(f0=700, f1=1300, decay=0.03), rng.uniform(0.1, 1.0), 0.3)  # kuplia
    return out


def anchor_up():
    out = np.zeros(int(1.4 * SR))
    for _ in range(12):
        place(out, drop(f0=rng.uniform(900, 1600), f1=rng.uniform(2000, 3000)), rng.uniform(0.0, 1.3), rng.uniform(0.3, 1.0))
    place(out, splash_burst(0.6, 300, 2000, attack=0.05, decay=0.2), 0.0, 0.5)
    return out


# --- Kalastus -----------------------------------------------------------------

def cast_swish():
    seconds = 0.45
    n = int(seconds * SR)
    noise = rng.standard_normal(n)
    out = np.zeros(n)
    # Laskeva kaistanpäästö: pätkissä, keskitaajuus laskee
    chunk = 512
    for i in range(0, n, chunk):
        center = 2600 * (1 - i / n) + 500
        seg = noise[i:i + chunk * 2]
        out[i:i + len(seg)] += filtered(seg, band(center * 0.6, center * 1.6)) * np.hanning(len(seg))
    return out * np.sin(np.linspace(0, np.pi, n)) ** 1.5


def lure_splash():
    out = np.zeros(int(0.4 * SR))
    plop = damped_sine(900, 0.06, 0.02, glide=0.35)
    place(out, plop, 0.0, 0.8)
    place(out, splash_burst(0.35, 600, 5000, attack=0.002, decay=0.06), 0.0, 0.6)
    return out


def reel_loop():
    """Kelan ratina ja vaihteiston hurina, 20 naksahdusta sekunnissa."""
    seconds = 1.0
    out = np.zeros(int(seconds * SR))
    for k in range(20):
        click = filtered(rng.standard_normal(int(0.004 * SR)), band(2500, 7000)) * np.hanning(int(0.004 * SR))
        place(out, mix(click, 0.3 * damped_sine(4200, 0.01, 0.003)), k / 20, 0.8, wrap=True)
    t = t_axis(seconds)
    whir = np.sin(2 * np.pi * 180 * t) * 0.08 + shaped_noise(seconds, band(500, 1500)) * 0.06
    return out + whir


def drag_loop():
    """Jarru laulaa: nopea räikkä, 45 naksahdusta sekunnissa (pitch nostaa tahtia)."""
    seconds = 1.0
    out = np.zeros(int(seconds * SR))
    for k in range(45):
        click = filtered(rng.standard_normal(int(0.003 * SR)), band(3000, 9000)) * np.hanning(int(0.003 * SR))
        place(out, mix(click, 0.5 * damped_sine(3300, 0.012, 0.004)), k / 45, 1.0, wrap=True)
    return out


def fish_splash():
    out = np.zeros(int(1.0 * SR))
    for k in range(3):
        place(out, splash_burst(0.6, 300, 4500, attack=0.004, decay=rng.uniform(0.08, 0.16)), k * rng.uniform(0.12, 0.22), rng.uniform(0.6, 1.0))
    place(out, damped_sine(180, 0.3, 0.08, glide=0.6), 0.0, 0.4)
    return out


def line_snap():
    out = np.zeros(int(0.5 * SR))
    crack = rng.standard_normal(int(0.006 * SR)) * np.linspace(1, 0, int(0.006 * SR))
    place(out, crack, 0.0, 1.0)
    place(out, damped_sine(2600, 0.3, 0.06, glide=0.9), 0.0, 0.5)
    place(out, damped_sine(1200, 0.3, 0.08), 0.0, 0.3)
    return out


def net_landing():
    out = np.zeros(int(1.3 * SR))
    place(out, splash_burst(0.8, 250, 3000, attack=0.03, decay=0.2), 0.0)
    for k in range(4):  # kala sätkii haavissa
        place(out, splash_burst(0.2, 400, 4000, decay=0.04), 0.5 + k * 0.15, 0.35)
    return out


def bite_tick():
    """Vavan kärjen nykäys: siima napsahtaa."""
    return mix(damped_sine(1800, 0.08, 0.015), 0.5 * damped_sine(900, 0.08, 0.02))


def record_chime():
    out = np.zeros(int(1.4 * SR))
    for k, f in enumerate([659.3, 987.8]):  # E5, H5
        tone = mix(damped_sine(f, 1.0, 0.35), 0.25 * damped_sine(f * 2, 1.0, 0.18), 0.1 * damped_sine(f * 4.1, 0.5, 0.05))
        place(out, tone, k * 0.16)
    return out


def main(only=None):
    loops = {
        'reel_loop': reel_loop, 'drag_loop': drag_loop,
    }
    sounds = {
        'oar_catch': oar_catch,
        'oar_drip': oar_drip, 'boat_bump': boat_bump, 'anchor_drop': anchor_drop, 'anchor_up': anchor_up,
        'cast_swish': cast_swish, 'lure_splash': lure_splash, 'fish_splash': fish_splash,
        'line_snap': line_snap, 'net_landing': net_landing, 'bite_tick': bite_tick,
        'record_chime': record_chime, 'bird_chaffinch': chaffinch_song, 'bird_great_tit': great_tit_call,
        'bird_loon': loon_call,
    }
    # Myöhemmin lisätyt äänet tehdään viimeisinä, jotta aiempien satunnaisuus ei muutu
    late_loops = {'rain_loop': rain_loop}
    late = {'ice_drill': ice_drill, 'snow_step': snow_step, 'prop_strike': prop_strike}
    if only:
        # Vain nimetyt äänet: muut tiedostot pysyvät ennallaan
        for name in only:
            fn = loops.get(name) or late_loops.get(name)
            if fn:
                save(name, fn(), fades=False)
            else:
                save(name, (sounds.get(name) or late[name])())
        return
    for name, fn in loops.items():
        save(name, fn(), fades=False)
    for name, fn in sounds.items():
        save(name, fn())
    for name, fn in late_loops.items():
        save(name, fn(), fades=False)
    for name, fn in late.items():
        save(name, fn())


if __name__ == '__main__':
    main(sys.argv[1:])

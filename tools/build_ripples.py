#!/usr/bin/env python3
"""Laskee veden väreiden kaltevuuskuvion (CATCHFISH-77).

Väreet ovat satojen lyhyiden aaltojen summa: suunnat satunnaisia noin ±60°
tuulesta (cos²-jakauma) ja aallonpituudet jatkuvalta väliltä (1/120–1/10
ruudun leveydestä), satunnaiset vaiheet ja korkeudet. Kuvio on saumaton
(aaltovektorit ovat ruudun jaksollisia), joten varjostin voi toistaa sitä. Kuvassa
x on tuulen suunta ja y poikki tuulen. Varjostin käyttää samaa kuviota kahdessa
mittakaavassa ja kääntää ja liikuttaa sitä, joten toistoa ei erota.

Kirjoittaa assets/lake/ripples.bin:
  otsake 8 tavua: b'RIP1', uint16 leveys, uint16 korkeus
  data uint8 RG: kaltevuus tuulen suuntaan (R) ja poikki tuulen (G),
                 arvo = 128 + 127 * kaltevuus / (3 × keskihajonta), rivit järjestyksessä
Varjostin kertoo kaltevuuden takaisin (water.gdshader RIPPLE_RANGE).

Käyttö: python3 tools/build_ripples.py
"""
import os
import struct

import numpy as np

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'lake', 'ripples.bin')
SIZE = 512
N_MIN = 10.0  # pisin aalto: ruudun leveys / 10
N_MAX = 120.0  # lyhin aalto: ruudun leveys / 120 (yli 4 pikseliä)
SPREAD = np.radians(60.0)  # suunnat tuulesta enintään ±60°
RANGE = 3.0  # tallennettava kaltevuus ±3 keskihajontaa


def main():
    rng = np.random.default_rng(77)
    n = np.fft.fftfreq(SIZE, 1.0 / SIZE)  # aaltoluvut kierroksina ruudulla
    kx, ky = np.meshgrid(n, n)
    k = np.hypot(kx, ky)
    theta = np.arctan2(ky, kx)
    # Kaltevuuden varianssi tasan aallonpituuden logaritmin suhteen: |A| ~ k^-2
    amp = np.zeros_like(k)
    band = (k >= N_MIN) & (k <= N_MAX)
    amp[band] = k[band] ** -2.0
    # Pehmeät reunat aallonpituusvälille, ettei kuvioon tule rengasta
    amp *= np.clip((k - N_MIN) / 4.0, 0.0, 1.0) * np.clip((N_MAX - k) / 15.0, 0.0, 1.0)
    # Suuntajakauma: cos² tuulen ympärillä, ±60° ulkopuolella ei aaltoja
    spread = np.where(np.abs(theta) < SPREAD, np.cos(theta * (np.pi / 2.0) / SPREAD) ** 2, 0.0)
    amp *= np.sqrt(spread)
    phase = rng.uniform(0.0, 2.0 * np.pi, k.shape)
    # Korkeuksien vaihtelu (Rayleigh): ei tasakokoisia aaltoja
    spec = amp * rng.rayleigh(1.0, k.shape) * np.exp(1j * phase)
    sx = np.real(np.fft.ifft2(1j * 2.0 * np.pi * kx * spec))
    sy = np.real(np.fft.ifft2(1j * 2.0 * np.pi * ky * spec))
    sd = np.sqrt((sx.var() + sy.var()) / 2.0)
    enc = lambda s: np.clip(np.round(128.0 + 127.0 * s / (RANGE * sd)), 0, 255).astype(np.uint8)
    data = np.stack([enc(sx), enc(sy)], axis=-1)
    with open(OUT, 'wb') as f:
        f.write(b'RIP1' + struct.pack('<HH', SIZE, SIZE))
        f.write(data.tobytes())
    print('ripples.bin: %d x %d, kaltevuuden keskihajonta x %.3f y %.3f (yksikkö: keskihajonta)'
          % (SIZE, SIZE, sx.std() / sd, sy.std() / sd))


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Laskee järven pyyhkäisymatkat aallokkoa varten (CATCHFISH-77).

Pyyhkäisymatka on matka, jonka tuuli on puhaltanut veden yli ennen kutakin
kohtaa, eli etäisyys ylätuulen rantaan vesisoluja pitkin. Saaret ja niemet
katkaisevat matkan. Jokaiselle 16 m:n karkealle solulle lasketaan matka 16
tuulensuuntaan; kunkin suunnan arvo on 22,5°:n sektorin viiden säteen
keskiarvo, jottei yksittäinen kaislasolu tee teräviä varjoja.

Lukee assets/lake/lake.json ja water.bin, kirjoittaa assets/lake/fetch.bin:
  otsake 16 tavua: b'FET1', uint16 sarakkeet, uint16 rivit, uint16 suunnat,
                   uint16 solun koko (m), uint32 suurin matka FETCH_MAX (m)
  data uint8: suunta kerrallaan (suunta 0 ensin), rivit pohjoisesta etelään.
              Arvo = round(255 * sqrt(matka / FETCH_MAX)); neliöjuuri, koska
              aallonkorkeus kasvaa matkan neliöjuuren mukaan.
Suunta d = d * 22,5° on suunta, JOHON tuuli puhaltaa (0 = pohjoiseen, -Z),
kuten Weather.wind_direction.

Käyttö: python3 tools/build_fetch.py
"""
import json
import math
import os
import struct

import numpy as np

LAKE_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'lake')
CELL = 16  # karkean solun koko (m)
DIRS = 16
FETCH_MAX = 4096  # m, tätä pidemmät matkat rajataan (järvi on n. 3,5 km pitkä)
STEP = 2.0  # säteen askel (m)
RAYS = (-9.0, -4.5, 0.0, 4.5, 9.0)  # säteet sektorin sisällä (astetta)


def main():
    meta = json.load(open(os.path.join(LAKE_DIR, 'lake.json'), encoding='utf-8'))
    cols, rows = int(meta['cols']), int(meta['rows'])
    cs = float(meta['cell_size'])
    ox, oz = float(meta['origin_x']), float(meta['origin_z'])
    water = np.fromfile(os.path.join(LAKE_DIR, 'water.bin'), dtype=np.uint8).reshape(rows, cols) == 1

    fcols = math.ceil(cols * cs / CELL)
    frows = math.ceil(rows * cs / CELL)
    # Karkeiden solujen keskipisteet maailman koordinaateissa
    cx = ox + (np.arange(fcols) + 0.5) * CELL
    cz = oz + (np.arange(frows) + 0.5) * CELL
    gx, gz = np.meshgrid(cx, cz)
    gx = gx.ravel()
    gz = gz.ravel()

    def is_water(x, z):
        c = np.floor((x - ox) / cs).astype(np.int64)
        r = np.floor((z - oz) / cs).astype(np.int64)
        inside = (c >= 0) & (r >= 0) & (c < cols) & (r < rows)
        out = np.zeros(x.shape, dtype=bool)
        out[inside] = water[r[inside], c[inside]]
        return out

    start_wet = is_water(gx, gz)
    sx = gx[start_wet]
    sz = gz[start_wet]
    print('vesisoluja %d / %d' % (sx.size, gx.size))

    planes = np.zeros((DIRS, frows * fcols), dtype=np.uint8)
    longest = 0.0
    for d in range(DIRS):
        total = np.zeros(sx.shape)
        for offset in RAYS:
            a = math.radians(d * 360.0 / DIRS + offset)
            # Ylätuuleen: vastakkainen suunta kuin tuuli (sin a, -cos a)
            ux, uz = -math.sin(a), math.cos(a)
            dist = np.zeros(sx.shape)
            active = np.ones(sx.shape, dtype=bool)
            steps = int(FETCH_MAX / STEP)
            for i in range(1, steps + 1):
                idx = np.nonzero(active)[0]
                if idx.size == 0:
                    break
                s = i * STEP
                wet = is_water(sx[idx] + ux * s, sz[idx] + uz * s)
                dist[idx[wet]] = s
                active[idx[~wet]] = False
            total += dist
        fetch = total / len(RAYS)
        longest = max(longest, float(fetch.max()))
        enc = np.round(255.0 * np.sqrt(np.clip(fetch, 0.0, FETCH_MAX) / FETCH_MAX))
        plane = np.zeros(gx.shape, dtype=np.uint8)
        plane[start_wet] = enc.astype(np.uint8)
        planes[d] = plane
        print('suunta %5.1f°: pisin %.0f m' % (d * 360.0 / DIRS, fetch.max()))

    path = os.path.join(LAKE_DIR, 'fetch.bin')
    with open(path, 'wb') as f:
        f.write(b'FET1')
        f.write(struct.pack('<HHHHI', fcols, frows, DIRS, CELL, FETCH_MAX))
        f.write(planes.tobytes())
    print('%s: %d x %d solua, %d suuntaa, pisin matka %.0f m, %d tavua'
          % (path, fcols, frows, DIRS, longest, os.path.getsize(path)))


if __name__ == '__main__':
    main()

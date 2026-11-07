#!/usr/bin/env python3
"""Piirtää kalastustarvikeliikkeen sisätilan taustakuvaksi (CATCHFISH-84).

Kuva näkyy uramoodissa koko ruudun taustana vain kalastustarvikeliikkeessä
(StartMenu/CareerView). Huone piirretään yhden pisteen perspektiivillä
3D-koordinaateista monikulmioina (maalarin algoritmi, takaa eteen), 2x
ylinäytteistettynä. Valaistus on ruudun tilassa: hämärä perusvalo,
riippuvalaisimien hehku ja valokeilat, vinjetti. Lopuksi pienennys,
pehmennys ja kohina. Kiinteä siemen (84), joten sama ajo tuottaa tavulleen
saman tiedoston. Vain numpy ja standardikirjasto; PNG kirjoitetaan itse
(zlib + struct).

Kirjoittaa assets/shop/shop_interior.png (1920x1080 RGB).

Käyttö: python3 tools/build_shop_image.py [TIEDOSTO]
"""
import os
import struct
import sys
import zlib

import numpy as np

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'shop', 'shop_interior.png')

W, H = 1920, 1080
SS = 2
SW, SH = W * SS, H * SS
CX, CY = 0.55 * SW, 0.45 * SH
F = (SW / 2) / np.tan(np.radians(35.0))
EYE = 1.6
RNG = np.random.default_rng(84)

# Huone (m): x vasen..oikea, y lattia..katto, z kamerasta taakse (negatiivinen)
XL, XR, YC, ZB = -2.4, 2.4, 2.7, -7.0

img = np.zeros((SH, SW, 3), np.float32)


def hexc(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def proj(p):
    x, y, z = p
    return (CX + F * x / -z, CY - F * (y - EYE) / -z)


def depth_k(z):
    """Kauempana hieman tummempi (ilmaperspektiivi sisätilassa)."""
    return float(np.clip(1.0 - 0.045 * (-z - 3.0), 0.72, 1.08))


def fill2d(pts, color):
    """Kupera monikulmio ruudun koordinaateissa."""
    pts = np.asarray(pts, np.float64)
    x0 = int(max(0, np.floor(pts[:, 0].min())))
    x1 = int(min(SW, np.ceil(pts[:, 0].max()) + 1))
    y0 = int(max(0, np.floor(pts[:, 1].min())))
    y1 = int(min(SH, np.ceil(pts[:, 1].max()) + 1))
    if x0 >= x1 or y0 >= y1:
        return
    ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float64)
    xs += 0.5
    ys += 0.5
    n = len(pts)
    area = 0.0
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        area += a[0] * b[1] - b[0] * a[1]
    s = 1.0 if area > 0 else -1.0
    mask = np.ones(xs.shape, bool)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        mask &= s * ((b[0] - a[0]) * (ys - a[1]) - (b[1] - a[1]) * (xs - a[0])) >= 0
    img[y0:y1, x0:x1][mask] = color


def quad(p3, color):
    z = np.mean([p[2] for p in p3])
    fill2d([proj(p) for p in p3], np.clip(color * depth_k(z), 0, 1))


def ellipse2d(cx, cy, rx, ry, color):
    x0, x1 = int(max(0, cx - rx)), int(min(SW, cx + rx + 1))
    y0, y1 = int(max(0, cy - ry)), int(min(SH, cy + ry + 1))
    if x0 >= x1 or y0 >= y1:
        return
    ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float64)
    m = ((xs + 0.5 - cx) / rx) ** 2 + ((ys + 0.5 - cy) / ry) ** 2 <= 1.0
    img[y0:y1, x0:x1][m] = color


def line3d(a, b, width_m, color):
    """Ohut sauva (vapa, naru) ruudun suuntaisena nauhana."""
    pa, pb = np.array(proj(a)), np.array(proj(b))
    d = pb - pa
    nrm = np.array([-d[1], d[0]]) / (np.hypot(*d) + 1e-9)
    wa = max(1.2, F * width_m / -a[2]) / 2
    wb = max(1.2, F * width_m / -b[2]) / 2
    z = (a[2] + b[2]) / 2
    fill2d([pa + nrm * wa, pb + nrm * wb, pb - nrm * wb, pa - nrm * wa], np.clip(color * depth_k(z), 0, 1))


def vary(c, amt):
    return np.clip(c * (1.0 + RNG.uniform(-amt, amt)), 0, 1)


# --- Paletti --------------------------------------------------------------------
PINE = hexc('#9A7650')
PINE_GAP = hexc('#4A3420')
FLOOR = hexc('#5E432C')
FLOOR_GAP = hexc('#2A1D13')
CEIL = hexc('#2C231C')
SHELF = hexc('#6B4628')
SHELF_DARK = hexc('#4A301C')
PEG = hexc('#8A7858')
PEG_HOLE = hexc('#5A4C38')
GREEN = hexc('#294D38')
GREEN_HI = hexc('#3D6B4D')
GOLD = hexc('#D8B04A')
LURES = [hexc(h) for h in ('#B8463A', '#D8B04A', '#9CB44A', '#C8CCC8', '#C8743A', '#4A72A0', '#E0E0D8')]
CARDS = [hexc(h) for h in ('#C8C4B4', '#A8B4B0', '#B8B0A0')]
BOXES = [hexc(h) for h in ('#3E5A48', '#5A6E7A', '#7A4A3A', '#8A7A5A', '#4A5A6A', '#6A5A3E')]
WINDOW = hexc('#9AA8AE')


# --- Huone ----------------------------------------------------------------------
def room():
    # katto
    quad([(XL, YC, -0.6), (XR, YC, -0.6), (XR, YC, ZB), (XL, YC, ZB)], CEIL)
    # kattopalkit poikittain
    for z in (-2.0, -3.6, -5.2):
        quad([(XL, YC - 0.12, z), (XR, YC - 0.12, z), (XR, YC - 0.12, z - 0.14), (XL, YC - 0.12, z - 0.14)], hexc('#3A2C20'))
        quad([(XL, YC, z), (XR, YC, z), (XR, YC - 0.12, z), (XL, YC - 0.12, z)], hexc('#4A3826'))
    # takaseinä pystypaneelina
    x = XL
    while x < XR:
        w = 0.14
        quad([(x, 0, ZB), (x + w, 0, ZB), (x + w, YC, ZB), (x, YC, ZB)], vary(PINE, 0.07))
        quad([(x + w - 0.008, 0, ZB), (x + w, 0, ZB), (x + w, YC, ZB), (x + w - 0.008, YC, ZB)], PINE_GAP)
        x += w
    # sivuseinät pystypaneelina (z-suunnassa)
    for xw, sh in ((XL, 0.82), (XR, 0.9)):
        z = ZB
        while z < -0.6:
            w = 0.14
            c = vary(PINE, 0.07) * sh
            quad([(xw, 0, z), (xw, 0, z + w), (xw, YC, z + w), (xw, YC, z)], c)
            quad([(xw, 0, z + w - 0.01), (xw, 0, z + w), (xw, YC, z + w), (xw, YC, z + w - 0.01)], PINE_GAP)
            z += w
    # lattia lautoina (z-suunnassa)
    x = XL
    while x < XR:
        w = 0.16
        quad([(x, 0, -0.6), (x + w, 0, -0.6), (x + w, 0, ZB), (x, 0, ZB)], vary(FLOOR, 0.09))
        quad([(x + w - 0.012, 0, -0.6), (x + w, 0, -0.6), (x + w, 0, ZB), (x + w - 0.012, 0, ZB)], FLOOR_GAP)
        x += w
    # lattian ja seinien jalkalistat
    quad([(XL, 0, ZB), (XR, 0, ZB), (XR, 0.1, ZB), (XL, 0.1, ZB)], SHELF_DARK)
    for xw in (XL, XR):
        quad([(xw, 0, ZB), (xw, 0, -0.6), (xw, 0.1, -0.6), (xw, 0.1, ZB)], SHELF_DARK)


def box3(x0, x1, y0, y1, z0, z1, color, top=None, side=None):
    """Laatikko: näkyvät tahot etu (z1), päällinen ja kameran puoleinen kylki."""
    top = color * 1.12 if top is None else top
    side = color * 0.78 if side is None else side
    xc = (x0 + x1) / 2
    if xc > 0:
        quad([(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)], side)
    else:
        quad([(x1, y0, z0), (x1, y0, z1), (x1, y1, z1), (x1, y1, z0)], side)
    if y1 < EYE:
        quad([(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], top)
    else:
        quad([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], color * 0.6)
    quad([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], color)


# --- Vasen seinä: hyllyt ja rasiat ----------------------------------------------
def left_shelves():
    d = 0.42
    xs = XL + d
    for z0, z1 in ((-6.9, -5.2), (-5.0, -3.3), (-3.1, -1.4)):
        box3(XL, xs, 0, 2.3, z0 - 0.04, z0, SHELF_DARK, side=SHELF_DARK * 1.1)
        for y in (0.12, 0.62, 1.12, 1.62, 2.12):
            # tavarat hyllyllä tasaisina riveinä
            z = z1 - 0.04
            kind = RNG.integers(len(BOXES))
            while z - 0.18 > z0:
                h = RNG.choice([0.22, 0.26, 0.3])
                wz = RNG.choice([0.16, 0.2, 0.24])
                c = vary(BOXES[kind], 0.05)
                box3(XL + 0.06, xs - 0.04, y + 0.03, y + 0.03 + h, z - wz, z, c, side=c * 0.9)
                # etiketti kyljessä
                quad([(xs - 0.04, y + 0.03 + h * 0.4, z - wz * 0.8), (xs - 0.04, y + 0.03 + h * 0.4, z - wz * 0.2),
                      (xs - 0.04, y + 0.03 + h * 0.7, z - wz * 0.2), (xs - 0.04, y + 0.03 + h * 0.7, z - wz * 0.8)],
                     vary(CARDS[0], 0.05) * 0.85)
                z -= wz + 0.02
                if RNG.random() < 0.12:
                    kind = RNG.integers(len(BOXES))
            box3(XL, xs, y - 0.03, y + 0.03, z0, z1, SHELF, top=SHELF * 1.1, side=SHELF_DARK)
        # pystytuet
        box3(XL, xs, 0, 2.3, z1 - 0.04, z1, SHELF_DARK, side=SHELF_DARK * 1.1)
        # hyllyn yläreunan vihreä tuotelista (ei tekstiä)
        quad([(xs, 2.3, z0), (xs, 2.3, z1), (xs, 2.45, z1), (xs, 2.45, z0)], GREEN)


# --- Takaseinä: reikälevy, hauki, ikkuna ----------------------------------------
def pegboard(z):
    px0, px1, py0, py1 = -0.1, 1.42, 0.98, 1.78
    quad([(px0 - 0.04, py0 - 0.04, z), (px1 + 0.04, py0 - 0.04, z), (px1 + 0.04, py1 + 0.04, z), (px0 - 0.04, py1 + 0.04, z)], SHELF_DARK)
    quad([(px0, py0, z), (px1, py0, z), (px1, py1, z), (px0, py1, z)], PEG)
    for yy in np.arange(py0 + 0.025, py1, 0.05):
        for xx in np.arange(px0 + 0.025, px1, 0.05):
            u, v = proj((xx, yy, z))
            ellipse2d(u, v, 1.6, 1.6, PEG_HOLE)
    # vihreä otsikkolevy (tyhjä, kultainen reunus)
    quad([(px0, py1 + 0.06, z), (px1, py1 + 0.06, z), (px1, py1 + 0.2, z), (px0, py1 + 0.2, z)], GOLD * 0.75)
    quad([(px0 + 0.015, py1 + 0.075, z), (px1 - 0.015, py1 + 0.075, z), (px1 - 0.015, py1 + 0.185, z), (px0 + 0.015, py1 + 0.185, z)], GREEN)
    for row, yy in enumerate((1.62, 1.42, 1.22, 1.04)):
        col = RNG.permutation(len(LURES))
        xx = px0 + 0.06
        i = 0
        while xx + 0.09 < px1:
            card = vary(CARDS[(row + i // 3) % len(CARDS)], 0.04)
            line3d((xx + 0.045, yy + 0.12, z), (xx + 0.045, yy + 0.15, z), 0.006, hexc('#3A3A38'))
            quad([(xx, yy - 0.04, z), (xx + 0.09, yy - 0.04, z), (xx + 0.09, yy + 0.12, z), (xx, yy + 0.12, z)], card)
            lc = LURES[col[(i // 2) % len(LURES)]]
            u, v = proj((xx + 0.045, yy + 0.04, z))
            s = F / -z
            if row % 2 == 0:  # vaappu
                ellipse2d(u, v, 0.016 * s, 0.045 * s, lc)
                ellipse2d(u, v - 0.028 * s, 0.012 * s, 0.013 * s, lc * 0.7 + 0.3)
            else:  # lusikka
                ellipse2d(u, v, 0.022 * s, 0.04 * s, lc)
                ellipse2d(u - 0.006 * s, v - 0.01 * s, 0.008 * s, 0.016 * s, np.clip(lc * 1.3, 0, 1))
            xx += 0.12
            i += 1


PIKE_BACK = hexc('#2E3E26')
PIKE_SIDE = hexc('#5C6E38')
PIKE_BELLY = hexc('#D2CBA0')
PIKE_SPOT = hexc('#D8CE84')
PIKE_FIN = hexc('#A0603A')


def pike(z, x0, yc, length):
    """Täytetty hauki sivulta, pää vasemmalla, kita auki. Mitat metreinä."""
    s = F / -z
    u0, v0 = proj((x0, yc, z))
    L = length * s

    def half(t):  # vartalon puolikorkeus suhteessa pituuteen
        if t < 0.16:
            return 0.012 + (0.055 - 0.012) * (t / 0.16) ** 0.8
        if t < 0.62:
            return 0.055 + 0.02 * np.sin((t - 0.16) / 0.46 * np.pi * 0.5)
        return 0.075 - (0.075 - 0.026) * ((t - 0.62) / 0.2) ** 1.2

    def P(t, h):  # h: +ylös, suhteessa pituuteen
        return (u0 + t * L, v0 - h * L)

    # evät ensin (vartalo peittää tyven)
    fins = [
        [(0.66, 0.07), (0.71, 0.135), (0.8, 0.075), (0.79, 0.03)],     # selkäevä
        [(0.67, -0.065), (0.72, -0.125), (0.8, -0.07), (0.79, -0.03)],  # peräevä
        [(0.47, -0.065), (0.5, -0.11), (0.55, -0.1), (0.54, -0.06)],   # vatsaevä
        [(0.19, -0.04), (0.24, -0.095), (0.28, -0.085), (0.25, -0.035)],  # rintaevä
    ]
    for f in fins:
        fill2d([P(t, h) for t, h in f], PIKE_FIN)
    # pyrstö, haarainen
    fill2d([P(0.8, 0.026), P(0.97, 0.11), P(0.93, 0.0), P(0.8, -0.026)], PIKE_FIN * 0.95)
    fill2d([P(0.8, 0.026), P(0.93, 0.0), P(0.97, -0.11), P(0.8, -0.026)], PIKE_FIN * 0.95)
    # vartalo siivuina: selkä, kylki, vatsa
    n = 80
    for k in range(n):
        ta, tb = 0.0 + 0.82 * k / n, 0.82 * (k + 1) / n
        ha, hb = half(ta), half(tb)
        for f0, f1, c in ((1.0, 0.35, PIKE_BACK), (0.35, -0.45, PIKE_SIDE), (-0.45, -1.0, PIKE_BELLY)):
            fill2d([P(ta, ha * f0), P(tb, hb * f0), P(tb, hb * f1), P(ta, ha * f1)], c)
    # vaaleat pilkut kyljissä riveittäin
    for k in range(70):
        t = RNG.uniform(0.24, 0.78)
        h = half(t) * RNG.uniform(-0.35, 0.6)
        u, v = P(t, h)
        ellipse2d(u, v, 0.009 * L, 0.0055 * L, PIKE_SPOT)
    # kita auki: alaleuka alas, suu tumma, hampaat
    fill2d([P(0.0, 0.004), P(0.15, -0.012), P(0.15, -0.035), P(0.01, -0.05)], hexc('#4A1E1A'))
    fill2d([P(0.01, -0.05), P(0.15, -0.035), P(0.17, -0.05), P(0.02, -0.062)], PIKE_BELLY * 0.9)
    for k in range(7):
        t = 0.02 + k * 0.018
        fill2d([P(t, 0.002 - 0.0011 * k), P(t + 0.007, 0.002 - 0.0011 * k), P(t + 0.0035, -0.011 - 0.0011 * k)], hexc('#F0ECE0'))
        fill2d([P(t + 0.004, -0.049 + 0.0009 * k), P(t + 0.011, -0.049 + 0.0009 * k), P(t + 0.0075, -0.037 + 0.0009 * k)], hexc('#F0ECE0'))
    # kiduskansi ja silmä
    for k in range(12):
        a0, a1 = -1.2 + 2.4 * k / 12, -1.2 + 2.4 * (k + 1) / 12
        r = 0.05
        cu, cv = P(0.16, 0.0)
        pa = (cu + np.cos(a0) * r * 0.5 * L, cv - np.sin(a0) * r * L)
        pb = (cu + np.cos(a1) * r * 0.5 * L, cv - np.sin(a1) * r * L)
        fill2d([pa, pb, (pb[0] + 0.006 * L, pb[1]), (pa[0] + 0.006 * L, pa[1])], PIKE_BACK * 0.8)
    u, v = P(0.1, 0.022)
    ellipse2d(u, v, 0.014 * L, 0.014 * L, hexc('#E0C050'))
    ellipse2d(u, v, 0.007 * L, 0.007 * L, hexc('#141210'))


def back_wall():
    z = ZB + 0.01
    pegboard(z)
    # täytetty hauki isolla laudalla reikälevyn ja tiskin yllä
    bx0, bx1, by0, by1 = -1.0, 1.35, 2.02, 2.6
    quad([(bx0, by0, z), (bx1, by0, z), (bx1, by1, z), (bx0, by1, z)], hexc('#4A2E1A'))
    quad([(bx0 + 0.04, by0 + 0.04, z), (bx1 - 0.04, by0 + 0.04, z), (bx1 - 0.04, by1 - 0.04, z), (bx0 + 0.04, by1 - 0.04, z)], hexc('#7A5232'))
    # messinkilaatta (tyhjä)
    quad([(0.06, by0 + 0.06, z), (0.3, by0 + 0.06, z), (0.3, by0 + 0.11, z), (0.06, by0 + 0.11, z)], GOLD * 0.85)
    pike(z, bx0 + 0.12, (by0 + by1) / 2 + 0.03, 2.1)
    # ikkuna takaseinän oikealla
    wx0, wx1, wy0, wy1 = 1.62, 2.25, 1.1, 2.05
    quad([(wx0 - 0.06, wy0 - 0.06, z), (wx1 + 0.06, wy0 - 0.06, z), (wx1 + 0.06, wy1 + 0.06, z), (wx0 - 0.06, wy1 + 0.06, z)], hexc('#D8D0BC') * 0.75)
    for k in range(40):
        t0, t1 = k / 40, (k + 1) / 40
        c = WINDOW * (1.05 - 0.15 * t0)
        quad([(wx0, wy0 + (wy1 - wy0) * t0, z), (wx1, wy0 + (wy1 - wy0) * t0, z), (wx1, wy0 + (wy1 - wy0) * t1, z), (wx0, wy0 + (wy1 - wy0) * t1, z)], c)
    for k in range(9):
        xx = wx0 + (wx1 - wx0) * (k + 0.5) / 9
        h = 0.18 + 0.1 * RNG.random()
        u, v = proj((xx, wy0, z))
        s = F / -z
        fill2d([(u - 0.05 * s, v), (u, v - h * s), (u + 0.05 * s, v)], hexc('#56665E'))
    quad([(wx0, wy0, z), (wx1, wy0, z), (wx1, wy0 + 0.06, z), (wx0, wy0 + 0.06, z)], hexc('#56665E'))
    mid = (wx0 + wx1) / 2
    quad([(mid - 0.02, wy0, z), (mid + 0.02, wy0, z), (mid + 0.02, wy1, z), (mid - 0.02, wy1, z)], hexc('#D8D0BC') * 0.75)
    quad([(wx0, 1.55, z), (wx1, 1.55, z), (wx1, 1.59, z), (wx0, 1.59, z)], hexc('#D8D0BC') * 0.75)


# --- Myyjä ----------------------------------------------------------------------
SELLER_X, SELLER_Z = -0.5, -5.75
SKIN = hexc('#C8946E')
BEARD = hexc('#C4BEB2')
BEARD_DARK = hexc('#A49C90')
SELLER_SCALE = 1.25
SHIRT = hexc('#8A3A30')
SHIRT_DARK = hexc('#5E2620')
VEST = hexc('#4E5A3A')


def seller():
    """Partasuu myyjä tiskin takana, tasomainen hahmo (kuvataso z = SELLER_Z)."""
    z = SELLER_Z
    x = SELLER_X

    sc = SELLER_SCALE  # hahmo hieman luonnollista isompi, jotta kasvot erottuvat

    def Y(b):
        return CTR_H + (b - CTR_H) * sc

    def Q(pts, c):
        quad([(x + a * sc, Y(b), z) for a, b in pts], c)

    def E(a, b, rx, ry, c):
        u, v = proj((x + a * sc, Y(b), z))
        s = F / -z * sc
        ellipse2d(u, v, rx * s, ry * s, np.clip(c * depth_k(z), 0, 1))

    # paita ja hihat
    Q([(-0.3, 0.8), (0.3, 0.8), (0.3, 1.36), (-0.3, 1.36)], SHIRT)
    E(-0.25, 1.32, 0.08, 0.05, SHIRT)
    E(0.25, 1.32, 0.08, 0.05, SHIRT)
    # ruudutus paitaan
    for k in range(-5, 6):
        Q([(k * 0.055 - 0.008, 0.8), (k * 0.055 + 0.008, 0.8), (k * 0.055 + 0.008, 1.34), (k * 0.055 - 0.008, 1.34)], SHIRT_DARK)
    for k in range(10):
        yy = 0.82 + k * 0.055
        Q([(-0.3, yy), (0.3, yy), (0.3, yy + 0.014), (-0.3, yy + 0.014)], SHIRT_DARK)
    # kalastusliivi taskuineen
    Q([(-0.27, 0.8), (-0.07, 0.8), (-0.1, 1.36), (-0.25, 1.38)], VEST)
    Q([(0.07, 0.8), (0.27, 0.8), (0.25, 1.38), (0.1, 1.36)], VEST)
    for px in (-0.2, 0.13):
        Q([(px, 1.0), (px + 0.09, 1.0), (px + 0.09, 1.1), (px, 1.1)], VEST * 0.78)
        Q([(px, 1.1), (px + 0.09, 1.1), (px + 0.09, 1.125), (px, 1.125)], VEST * 0.6)
    # kaula ja pää
    Q([(-0.05, 1.36), (0.05, 1.36), (0.05, 1.46), (-0.05, 1.46)], SKIN * 0.85)
    E(0.0, 1.6, 0.105, 0.135, SKIN)
    E(-0.105, 1.6, 0.025, 0.04, SKIN * 0.9)  # korvat
    E(0.105, 1.6, 0.025, 0.04, SKIN * 0.9)
    # iso parta: poskista rinnalle (kasvot ja silmät jäävät näkyviin)
    E(0.0, 1.42, 0.15, 0.15, BEARD)
    E(0.0, 1.31, 0.105, 0.09, BEARD)
    Q([(-0.108, 1.61), (-0.084, 1.61), (-0.09, 1.45), (-0.145, 1.45)], BEARD)
    Q([(0.084, 1.61), (0.108, 1.61), (0.145, 1.45), (0.09, 1.45)], BEARD)
    for i in range(4):  # partaan muutama juova
        a = -0.06 + i * 0.04
        Q([(a - 0.004, 1.44), (a + 0.004, 1.44), (a * 0.8 + 0.003, 1.3), (a * 0.8 - 0.003, 1.3)], BEARD_DARK)
    # viikset ja nenä
    E(-0.035, 1.545, 0.05, 0.02, BEARD_DARK)
    E(0.035, 1.545, 0.05, 0.02, BEARD_DARK)
    E(0.0, 1.585, 0.022, 0.03, SKIN * 0.88)
    # silmät ja kulmat (harmaat)
    E(-0.042, 1.632, 0.012, 0.01, hexc('#1E1814'))
    E(0.042, 1.632, 0.012, 0.01, hexc('#1E1814'))
    Q([(-0.072, 1.652), (-0.016, 1.656), (-0.016, 1.67), (-0.072, 1.666)], BEARD_DARK)
    Q([(0.016, 1.656), (0.072, 1.652), (0.072, 1.666), (0.016, 1.67)], BEARD_DARK)
    # vihreä lippalakki päälaella
    E(0.0, 1.735, 0.112, 0.06, GREEN)
    Q([(-0.112, 1.69), (0.112, 1.69), (0.112, 1.735), (-0.112, 1.735)], GREEN)
    Q([(-0.13, 1.68), (0.15, 1.68), (0.15, 1.695), (-0.13, 1.695)], GREEN * 0.7)
    Q([(-0.045, 1.71), (0.045, 1.71), (0.045, 1.76), (-0.045, 1.76)], GOLD * 0.8)  # merkki


# --- Tiski ----------------------------------------------------------------------
CTR_X0, CTR_X1, CTR_Z0, CTR_Z1, CTR_H = -1.1, 1.3, -5.4, -4.8, 0.95


def counter():
    x0, x1, z0, z1, h = CTR_X0, CTR_X1, CTR_Z0, CTR_Z1, CTR_H
    box3(x0, x1, 0, h - 0.05, z0, z1, SHELF, side=SHELF_DARK)
    # lasivitriini etuosassa
    gx0, gx1 = -0.95, 0.45
    quad([(gx0, 0.25, z1 + 0.001), (gx1, 0.25, z1 + 0.001), (gx1, 0.82, z1 + 0.001), (gx0, 0.82, z1 + 0.001)], hexc('#2A3A36'))
    for shelf_y in (0.32, 0.56):
        quad([(gx0, shelf_y, z1 + 0.002), (gx1, shelf_y, z1 + 0.002), (gx1, shelf_y + 0.02, z1 + 0.002), (gx0, shelf_y + 0.02, z1 + 0.002)], hexc('#8A9A94'))
        xx = gx0 + 0.07
        while xx < gx1 - 0.05:
            u, v = proj((xx, shelf_y + 0.07, z1))
            s = F / -z1
            c = LURES[RNG.integers(len(LURES))] * 0.75
            ellipse2d(u, v, 0.022 * s, 0.045 * s, c)
            xx += 0.1
    # vihreä etupaneeli oikealla
    quad([(0.6, 0.15, z1 + 0.001), (1.2, 0.15, z1 + 0.001), (1.2, 0.82, z1 + 0.001), (0.6, 0.82, z1 + 0.001)], GREEN)
    quad([(0.64, 0.19, z1 + 0.002), (1.16, 0.19, z1 + 0.002), (1.16, 0.78, z1 + 0.002), (0.64, 0.78, z1 + 0.002)], GREEN * 0.85)
    # tiskilevy
    box3(x0 - 0.05, x1 + 0.05, h - 0.05, h, z0, z1 + 0.05, hexc('#7A5232'), top=hexc('#8E6440'), side=SHELF_DARK)
    # kassakone tiskin päällä: varjo, runko, viisto näppäimistö, näyttö
    rx0, rx1, rz0, rz1 = 0.72, 1.14, -5.3, -4.95
    quad([(rx0 - 0.03, h + 0.001, rz0 - 0.02), (rx1 + 0.05, h + 0.001, rz0 - 0.02), (rx1 + 0.05, h + 0.001, rz1 + 0.04), (rx0 - 0.03, h + 0.001, rz1 + 0.04)], hexc('#4A3220'))
    box3(rx0, rx1, h, h + 0.12, rz0, rz1, hexc('#8C8C82'), top=hexc('#A2A298'), side=hexc('#6E6E66'))
    quad([(rx0 + 0.02, h + 0.12, rz1 - 0.02), (rx1 - 0.02, h + 0.12, rz1 - 0.02), (rx1 - 0.02, h + 0.2, rz0 + 0.12), (rx0 + 0.02, h + 0.2, rz0 + 0.12)], hexc('#5A5A54'))
    for i in range(4):
        for j in range(3):
            kx = rx0 + 0.06 + i * 0.08
            ky = h + 0.135 + j * 0.022
            kz = rz1 - 0.05 - j * 0.04
            u, v = proj((kx, ky, kz))
            ellipse2d(u, v, 4, 2.6, hexc('#D8D4C8') * 0.85)
    box3(rx0 + 0.04, rx1 - 0.04, h + 0.12, h + 0.3, rz0, rz0 + 0.12, hexc('#6A6A62'), top=hexc('#7E7E76'))
    quad([(rx0 + 0.08, h + 0.2, rz0 + 0.121), (rx1 - 0.08, h + 0.2, rz0 + 0.121), (rx1 - 0.08, h + 0.27, rz0 + 0.121), (rx0 + 0.08, h + 0.27, rz0 + 0.121)], hexc('#3A5A40'))
    # uistinrasia ja siimakelat tiskillä
    box3(-0.95, -0.6, h, h + 0.08, -5.0, -4.85, hexc('#6E3A30'), top=hexc('#8A4A3A'))
    for k in range(4):
        xx = 0.05 + k * 0.13
        u, v = proj((xx, h + 0.06, -4.95))
        s = F / 4.95
        ellipse2d(u, v, 0.05 * s, 0.05 * s, BOXES[k % len(BOXES)] * 1.1)
        ellipse2d(u, v, 0.02 * s, 0.02 * s, hexc('#2A2420'))


# --- Oikea: vapateline ja haavit ------------------------------------------------
def rod_rack():
    rx0, rx1, rz0, rz1 = 1.45, 2.1, -4.3, -3.8
    base_h, rail_y = 0.16, 1.2
    # takapylväät ja yläkisko (vavat nojaavat kiskoon)
    for px in (rx0, rx1 - 0.05):
        box3(px, px + 0.05, 0, rail_y + 0.08, rz0, rz0 + 0.05, SHELF_DARK, side=SHELF_DARK * 0.85)
    box3(rx0, rx1, rail_y, rail_y + 0.08, rz0, rz0 + 0.06, SHELF, top=SHELF * 1.1, side=SHELF_DARK)
    # jalusta
    box3(rx0, rx1, 0, base_h, rz0, rz1, SHELF_DARK, top=SHELF)
    rods = []
    for k in range(10):
        t = k / 9
        x = rx0 + 0.06 + (rx1 - rx0 - 0.12) * t
        z = rz1 - 0.12 - RNG.uniform(0.0, 0.18)
        top = 2.3 + RNG.uniform(-0.15, 0.2)
        rods.append((z, x, top))
    rods.sort()
    for z, x, top in rods:
        blank = hexc(['#2A2A2A', '#3A2E24', '#2E3A34', '#4A3A2A'][RNG.integers(4)])
        # vapa nojaa yläkiskoon: tyvi jalustassa, kärki kiskon takana
        lean_z = (rz0 + 0.03 - z) / (rail_y - base_h)
        def at(y):
            return (x, y, z + lean_z * (y - base_h))
        u, v = proj((x, base_h, z))
        s = F / -z
        ellipse2d(u, v, 0.03 * s, 0.012 * s, hexc('#1E1610'))  # reikä
        line3d(at(base_h), at(top), 0.014, blank)
        line3d(at(base_h), at(0.5), 0.032, hexc('#B08A5A'))  # korkkikahva
        line3d(at(0.5), at(0.56), 0.036, hexc('#2A2420'))   # kelaistuin
        for f in (0.45, 0.7, 0.88):
            u, v = proj(at(base_h + (top - base_h) * f))
            ellipse2d(u, v, 2.4, 2.4, hexc('#9A9A90') * 0.8)


def right_wall():
    # haavit oikealla seinällä
    for zc in (-6.2, -5.55):
        x = XR - 0.02
        u, v = proj((x, 1.9, zc))
        s = F / -zc
        ellipse2d(u, v, 0.11 * s, 0.24 * s, hexc('#3A3430'))
        ellipse2d(u, v, 0.095 * s, 0.215 * s, PINE * 0.9 * depth_k(zc))
        # verkkopussi
        fill2d([(u - 0.09 * s, v + 0.05 * s), (u + 0.09 * s, v + 0.05 * s), (u + 0.02 * s, v + 0.42 * s), (u - 0.03 * s, v + 0.42 * s)], hexc('#4A5A4E') * 0.8)
        line3d((x, 1.66, zc), (x, 0.55, zc), 0.025, hexc('#5A4A38'))
    # pilkkikairat nurkassa
    for k, zc in enumerate((-6.75, -6.6)):
        x = XR - 0.15 - k * 0.1
        line3d((x, 0.05, zc), (x + 0.05, 1.25, zc - 0.05), 0.04, hexc('#4A6A7A'))
        line3d((x + 0.04, 1.0, zc - 0.04), (x + 0.04, 1.3, zc - 0.05), 0.03, hexc('#B84A3A'))


# --- Valaisimet -----------------------------------------------------------------
AMBIENT = 0.78
LAMPS = [(-0.2, 2.4, -3.2), (0.55, 2.45, -4.6)]


def lamps_geometry():
    for x, y, z in LAMPS:
        line3d((x, YC, z), (x, y + 0.2, z), 0.01, hexc('#1A1612'))
        u0, v0 = proj((x, y + 0.2, z))
        u1, v1 = proj((x, y, z))
        s = F / -z
        fill2d([(u0 - 0.05 * s, v0), (u0 + 0.05 * s, v0), (u1 + 0.22 * s, v1), (u1 - 0.22 * s, v1)], GREEN * 1.1)
        ellipse2d(u1, v1, 0.22 * s, 0.035 * s, hexc('#FFE6A8'))


def lighting():
    ys, xs = np.mgrid[0:SH, 0:SW].astype(np.float32)
    L = np.full((SH, SW), AMBIENT, np.float32)
    warm = np.zeros((SH, SW, 3), np.float32)
    for x, y, z in LAMPS:
        u, v = proj((x, y, z))
        s = F / -z
        # kartiomainen valokeila alaspäin
        dy = np.clip((ys - v) / (1.6 * s), 0, None)
        spread = 0.35 * s + dy * 1.1 * s
        beam = np.exp(-((xs - u) / (spread + 1)) ** 2) * np.exp(-dy * 0.9) * (ys > v)
        glow = np.exp(-(((xs - u) ** 2 + (ys - v) ** 2) / (0.5 * s) ** 2))
        # valotäplä lattialla
        fu, fv = proj((x, 0, z))
        pool = np.exp(-(((xs - fu) / (1.2 * s)) ** 2 + ((ys - fv) / (0.35 * s)) ** 2))
        L += 0.38 * beam + 0.35 * pool + 0.25 * glow
        warm += (0.10 * glow)[..., None] * hexc('#FFD98A')[None, None, :]
    # ikkunan valo (viileä)
    wu, wv = proj((1.93, 1.55, ZB))
    s = F / -ZB
    L += 0.12 * np.exp(-(((xs - wu) ** 2 + (ys - wv) ** 2) / (0.9 * s) ** 2))
    # yläosa (katto) ja vasen reuna tummempia
    L *= np.clip(0.55 + 0.6 * ys / SH, 0, 1.0) ** 0.5
    # vinjetti
    nx = (xs - CX) / (SW * 0.62)
    ny = (ys - SH * 0.5) / (SH * 0.75)
    vig = np.clip(1.0 - 0.55 * (nx ** 2 + ny ** 2), 0.25, 1.0)
    L *= vig
    tint = np.array([1.0, 0.93, 0.8], np.float32)  # lämmin hehkulamppuvalo
    return L, warm, tint


def blur(a, sigma):
    r = int(3 * sigma) + 1
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    out = a.copy()
    for axis in (0, 1):
        pad = [(0, 0)] * a.ndim
        pad[axis] = (r, r)
        p = np.pad(out, pad, mode='edge')
        acc = np.zeros_like(out)
        for i, w in enumerate(k):
            sl = [slice(None)] * a.ndim
            sl[axis] = slice(i, i + out.shape[axis])
            acc += w * p[tuple(sl)]
        out = acc
    return out


def write_png(path, rgb8):
    h, w, _ = rgb8.shape
    a = rgb8.reshape(h, w * 3).astype(np.int16)
    sub = a.copy()
    sub[:, 3:] = a[:, 3:] - a[:, :-3]
    up = a.copy()
    up[1:] = a[1:] - a[:-1]
    best = None
    for ftype, arr in ((1, sub), (2, up)):
        b = (arr % 256).astype(np.uint8)
        raw = b''.join(bytes([ftype]) + b[y].tobytes() for y in range(h))
        c = zlib.compress(raw, 9)
        if best is None or len(c) < len(best):
            best = c

    def chunk(t, d):
        c = struct.pack('>I', len(d)) + t + d
        return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
    data += chunk(b'IDAT', best) + chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(data)


def lum(a):
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def rounded_rect_mask(x0, y0, x1, y1, r):
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32) + 0.5
    cx = np.clip(xs, x0 + r, x1 - r)
    cy = np.clip(ys, y0 + r, y1 - r)
    d = np.hypot(xs - cx, ys - cy)
    inside = (xs >= x0) & (xs <= x1) & (ys >= y0) & (ys <= y1)
    return (inside & (d <= r)).astype(np.float32)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else OUT
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    room()
    left_shelves()
    back_wall()
    right_wall()
    seller()
    counter()
    rod_rack()
    lamps_geometry()
    L, warm, tint = lighting()
    lit = img * L[..., None] * tint + warm
    # pienennys 2x keskiarvolla
    small = lit.reshape(H, SS, W, SS, 3).mean(axis=(1, 3))
    small = blur(small, 1.2)
    small += RNG.uniform(-0.5, 0.5, small.shape).astype(np.float32) / 255.0
    small = np.clip(small, 0, 1)
    rgb8 = (small * 255 + 0.5).astype(np.uint8)
    write_png(out, rgb8)
    l = lum(small)
    print('keskiluminanssi %.3f, vasen 40%% %.3f, oikea 60%% %.3f, max %.3f' % (
        l.mean(), l[:, :int(W * 0.4)].mean(), l[:, int(W * 0.4):].mean(), l.max()))


if __name__ == '__main__':
    main()

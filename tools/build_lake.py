#!/usr/bin/env python3
"""Tekee järven korkeusdatan pelin käyttämään muotoon.

Tuloste (assets/lake/), kaikki ruudukot rivi kerrallaan pohjoisesta etelään:
  lake.json    metatiedot: ruudukon koko, solun koko, aloituspaikka, kivet, lähde
  heights.bin  float32 (little-endian): korkeus metreinä järven vedenpinnasta.
               Järven kohdalla arvo on pohjan korkeus (negatiivinen). Padon
               takana maa voi olla myös vedenpinnan alapuolella.
  water.bin    uint8: 1 = järveä
  ground.bin   uint8: maastotyyppi (GROUND_*)
  shore.bin    uint16: etäisyys rantaviivaan metreinä (vedessä maahan, maalla veteen)
  map.png      järven kartta pelin karttanäkymään (pohjoinen ylhäällä)

Käyttö:
  python3 tools/build_lake.py --mml data/mml    MML:n maastotietokannasta ja korkeusmallista
  python3 tools/build_lake.py --synthetic       väliaikainen järvi testaukseen
"""
import argparse
import json
import math
import os

import numpy as np
from osgeo import gdal

gdal.UseExceptions()

OUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'lake')

GROUND_FOREST = 0
GROUND_FIELD = 1
GROUND_BOG = 2
GROUND_OPEN = 3
GROUND_ROCK = 4
GROUND_REEDS = 5

# Maastotietokannan tasot -> maastotyyppi (myöhempi voittaa päällekkäisyyksissä)
# Aloituspaikat (ETRS-TM35FIN): maamerkki rannalla, jonka viereen vene laitetaan.
# Lintutorni on maastotietokannassa. Uimalaiturin paikka on käyttäjän merkitsemä
# (pohjoisranta, tien päässä). Veneenlaskupaikka on päätelty tiestä ja rannan
# rakennuksista. dock_width = laiturin leveys (m), parking = parkkipaikka rannalle,
# ramp = veneenlaskuluiska laiturin viereen.
MML_STARTS = [
    {'id': 'kota', 'name': 'Haapajärven kota ja lintutorni', 'description': 'Lounaisrannalla lintutornin vieressä',
     'e': 380147, 'n': 7167913},
    {'id': 'uimalaituri', 'name': 'Uimalaituri ja parkkipaikka', 'description': 'Järven pohjoisrannalla tien päässä',
     'e': 381080, 'n': 7170642, 'dock_width': 3.2, 'parking': True},
    {'id': 'veneenlasku', 'name': 'Veneenlaskupaikka', 'description': 'Järven länsirannalla, betoninen luiska',
     'e': 380396, 'n': 7169095, 'ramp': True},
]

MML_GROUND_LAYERS = [
    ('suo', GROUND_BOG),
    ('soistuma', GROUND_BOG),
    ('maatalousmaa', GROUND_FIELD),
    ('niitty', GROUND_OPEN),
    ('muuavoinalue', GROUND_OPEN),
    ('taytemaa', GROUND_OPEN),
    ('varastoalue', GROUND_OPEN),
    ('kallioalue', GROUND_ROCK),
    ('kivikko', GROUND_ROCK),
]


def value_noise(rows, cols, cell, rng):
    """Pehmeää kohinaa: satunnaisruudukko interpoloituna (arvot -1..1)."""
    gr, gc = rows // cell + 2, cols // cell + 2
    grid = rng.uniform(-1, 1, (gr, gc))
    y = np.arange(rows) / cell
    x = np.arange(cols) / cell
    y0, x0 = np.floor(y).astype(int), np.floor(x).astype(int)
    fy, fx = (y - y0)[:, None], (x - x0)[None, :]
    fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    a = grid[np.ix_(y0, x0)]
    b = grid[np.ix_(y0, x0 + 1)]
    c = grid[np.ix_(y0 + 1, x0)]
    d = grid[np.ix_(y0 + 1, x0 + 1)]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fractal_noise(rows, cols, base_cell, octaves, rng):
    total = np.zeros((rows, cols))
    amp, cell, norm = 1.0, base_cell, 0.0
    for _ in range(octaves):
        total += amp * value_noise(rows, cols, max(2, cell), rng)
        norm += amp
        amp *= 0.5
        cell //= 2
    return total / norm


def distance_to(mask, cell_size):
    """Etäisyys metreinä lähimpään soluun, jossa mask on tosi (GDAL ComputeProximity)."""
    rows, cols = mask.shape
    drv = gdal.GetDriverByName('MEM')
    src = drv.Create('', cols, rows, 1, gdal.GDT_Byte)
    src.GetRasterBand(1).WriteArray(mask.astype(np.uint8))
    dst = drv.Create('', cols, rows, 1, gdal.GDT_Float32)
    gdal.ComputeProximity(src.GetRasterBand(1), dst.GetRasterBand(1), ['VALUES=1', 'DISTUNITS=PIXEL'])
    return dst.GetRasterBand(1).ReadAsArray().astype(np.float64) * cell_size


def synthetic_lake():
    """Väliaikainen tekoaltaan kaltainen järvi: pitkulainen, matala, vanha jokiuoma
    pohjassa, pato toisessa päässä ja pari saarta."""
    rng = np.random.default_rng(7)
    cell = 4.0
    cols, rows = 900, 500  # 3,6 km x 2,0 km
    yy, xx = np.mgrid[0:rows, 0:cols]
    u = (xx - cols / 2) / (cols / 2)   # -1..1 länsi-itä
    v = (yy - rows / 2) / (rows / 2)   # -1..1 pohjoinen-etelä

    # Pitkulainen allas, jonka reunaa mutkittelee kohina
    shape = (np.abs(u) / 0.85) ** 2.2 + (np.abs(v + 0.08 * np.sin(u * 3.0)) / 0.62) ** 2.2
    shape += 0.35 * fractal_noise(rows, cols, 96, 4, rng)
    water = shape < 1.0
    # Pato itäpäässä: suora reuna
    dam_x = int(cols * 0.90)
    water[:, dam_x:] = False
    # Saaret
    for cx, cy, r in [(0.15, -0.15, 0.07), (-0.35, 0.18, 0.045)]:
        d = np.hypot((u - cx) / 1.6, v - cy) + 0.03 * fractal_noise(rows, cols, 24, 2, rng)
        water &= d > r

    # Pidetään vain suurin yhtenäinen vesialue (ei irrallisia lampia)
    water = largest_component(water)

    shore_dist_water = distance_to(~water, cell)  # vedessä: matka rantaan
    shore_dist_land = distance_to(water, cell)    # maalla: matka veteen

    # Syvyys: loivasti syvenevä pohja + mutkitteleva vanha jokiuoma
    depth = np.minimum(4.5, 0.9 * np.sqrt(shore_dist_water / 3.0))
    channel_v = 0.12 * np.sin(u * 4.0 + 0.6) + 0.05 * np.sin(u * 9.0)
    channel = np.exp(-((v - channel_v) / 0.06) ** 2) * np.clip(shore_dist_water / 60.0, 0, 1)
    depth += 3.5 * channel
    depth += 0.4 * fractal_noise(rows, cols, 32, 3, rng)
    depth = np.clip(depth, 0.3, None)

    # Maasto: ranta nousee loivasti, kauempana kumpareita
    land = 0.4 + 0.012 * shore_dist_land + 6.0 * (fractal_noise(rows, cols, 128, 4, rng) + 0.6) * np.clip(shore_dist_land / 250.0, 0, 1)
    land = np.clip(land, 0.25, None)
    # Patopenger: korkea harjanne padon kohdalla
    dam = np.exp(-((xx - dam_x - 3) / 4.0) ** 2) * (np.abs(v) < 0.75)
    land = np.maximum(land, 3.5 * dam)

    heights = np.where(water, -depth, land).astype(np.float32)
    ground = np.full(heights.shape, GROUND_FOREST, np.uint8)
    ground[(~water) & (shore_dist_land < 30) & (land < 0.6)] = GROUND_REEDS

    # Aloituspaikka: etelärannan rantautumispaikka keskellä allasta, vene osoittaa järvelle
    col = int(cols * 0.45)
    column = water[:, col]
    south_shore_row = max(r for r in range(rows) if column[r])
    start_row = south_shore_row - 3
    meta_start = {
        'x': (col - cols / 2) * cell,
        'z': (start_row - rows / 2) * cell,
        'yaw_deg': 0.0,  # 0 = pohjoiseen (-Z)
        'dock_length': 14.0,
    }
    return heights, water, ground, cell, meta_start, [], {
        'name': 'Väliaikainen järvi',
        'source': 'synthetic',
        'attribution': '',
        'depth_estimated': True,
    }


def mml_lake(folder):
    """Haapajärven tekoallas MML:n aineistosta.

    Rantaviiva tulee maastotietokannan järvikuviosta (taso jarvi). Jos käytössä on
    vain maasto-teema, järvi tunnistetaan korkeusmallista suurimpana tasaisena
    alueena vedenpinnan korkeudella. Tekoaltaasta ei ole syvyystietoja, joten
    syvyys arvioidaan etäisyydestä rantaan.
    """
    dem_path = os.path.join(folder, 'korkeusmalli_2m.tif')
    gpkg_path = os.path.join(folder, 'maastotietokanta_kaikki.gpkg')
    has_water_theme = os.path.exists(gpkg_path)
    if not has_water_theme:
        gpkg_path = os.path.join(folder, 'maasto.gpkg')
    ds = gdal.Open(dem_path)
    gt = ds.GetGeoTransform()
    dem = ds.ReadAsArray().astype(np.float64)

    # Vedenpinta: yleisin korkeusarvo. Korkeusmallin karttalehdillä voi olla
    # pari senttiä eri taso, joten hyväksytään kaikki tasaiset arvot sen läheltä.
    vals, counts = np.unique(np.round(dem, 2), return_counts=True)
    order = np.argsort(counts)[::-1]
    level = float(vals[order[0]])
    flat_levels = [float(vals[i]) for i in order[:4] if abs(vals[i] - level) < 0.05 and counts[i] > counts[order[0]] * 0.05]
    flat = np.zeros(dem.shape, bool)
    for lv in flat_levels:
        flat |= np.abs(dem - lv) < 0.006
    water_level = float(np.mean(flat_levels))

    # Poistetaan pienet läikät (rantakasvillisuus, yksittäiset pisteet)
    flat = sieve(flat, 400)

    # 2 m -> 4 m ruudukko
    rows2, cols2 = (dem.shape[0] // 2) * 2, (dem.shape[1] // 2) * 2
    def down(a, fn):
        a = a[:rows2, :cols2].reshape(rows2 // 2, 2, cols2 // 2, 2)
        return fn(a, axis=(1, 3))
    cell = 4.0
    dem4 = down(dem, np.mean)
    rows, cols = dem4.shape
    gt4 = (gt[0], cell, 0, gt[3], 0, -cell)
    vec = gdal.OpenEx(gpkg_path, gdal.OF_VECTOR)

    def rasterize(layer_name, where=None):
        mem = gdal.GetDriverByName('MEM').Create('', cols, rows, 1, gdal.GDT_Byte)
        mem.SetGeoTransform(gt4)
        mem.SetProjection(ds.GetProjection())
        if where:
            gdal.Rasterize(mem, vec, SQLStatement=f'SELECT * FROM {layer_name} WHERE {where}', burnValues=[1])
        else:
            gdal.Rasterize(mem, vec, layers=[layer_name], burnValues=[1])
        return mem.GetRasterBand(1).ReadAsArray() == 1

    if has_water_theme:
        # Järvikuviot, joiden keskikorkeus (millimetreinä) on altaan pinnan tasolla
        level_mm = int(round(level * 10)) * 100
        water = rasterize('jarvi', f'keskikorkeus BETWEEN {level_mm - 200} AND {level_mm + 200}')
        if not water.any():
            raise SystemExit(f'Maastotietokannasta ei löytynyt järveä korkeudella {level_mm / 1000:.2f} m')
        water_level = level_mm / 1000.0
    else:
        water = down(flat.astype(float), np.mean) >= 0.5
    water = largest_component(water)
    water &= ~border_mask(water.shape)

    rng = np.random.default_rng(3)
    shore_dist_water = distance_to(~water, cell)
    shore_dist_land = distance_to(water, cell)
    if has_water_theme:
        # Altaan pohja on vanhaa maastoa: maastotietokannan korkeuskäyrät
        # jatkuvat veden alla, ja niistä saadaan syvyydet
        contour_depth = rasterize_contours(vec, rows, cols, gt4, ds.GetProjection(), water_level)
        depth = bathymetry(water, contour_depth, cell, rng)
    else:
        depth = 0.36 * np.sqrt(shore_dist_water) * (1.0 + 0.25 * fractal_noise(rows, cols, 64, 3, rng))
        depth = np.clip(depth, 0.3, 4.0)

    land = dem4 - water_level
    # Rannan maa vähintään hieman vedenpinnan yläpuolelle, ettei vesi "vuoda" maalle
    land = np.where(shore_dist_land < 12, np.maximum(land, 0.15), land)
    # Maastotyypit maastotietokannasta
    ground = np.full((rows, cols), GROUND_FOREST, np.uint8)
    for layer_name, code in MML_GROUND_LAYERS:
        ground[rasterize(layer_name)] = code
    ground[(~water) & (shore_dist_land < 30) & (land < 0.4)] = GROUND_REEDS
    if has_water_theme:
        # Maatuva vesialue = kasvillisuuden valtaama matalikko: kaislikkoa ja matalaa vettä
        overgrown = rasterize('maatuvavesialue') & water
        ground[overgrown] = GROUND_REEDS
        heights_override = overgrown
    else:
        heights_override = np.zeros_like(water)

    depth = np.where(heights_override, np.minimum(depth, 0.6), depth)
    heights = np.where(water, -depth, land).astype(np.float32)

    def to_world(e, n):
        return (e - gt[0]) - cols * cell / 2, (gt[3] - n) - rows * cell / 2

    extras = {}
    if has_water_theme:
        extras = mml_features(vec, to_world, water_level)

    rocks = []
    for layer_name in ('kivi', 'harvalouhikko'):
        layer = vec.GetLayerByName(layer_name)
        for feat in layer:
            geom = feat.GetGeometryRef()
            x, z = to_world(geom.GetX(), geom.GetY())
            rocks.append({'x': round(x, 1), 'z': round(z, 1), 'size': 1.6 if layer_name == 'kivi' else 0.8})

    starts = []
    for spot in MML_STARTS:
        c = (spot['e'] - gt[0]) / cell
        r = (gt[3] - spot['n']) / cell
        starts.append({**start_near(water, shore_dist_water, heights, cell, c, r),
                       'id': spot['id'], 'name': spot['name'], 'description': spot['description'],
                       'dock_width': spot.get('dock_width', 1.8), 'parking': spot.get('parking', False),
                       'ramp': spot.get('ramp', False)})
    start = starts[0]
    map_image(heights, water, ground, cell, vec, gt, ds.GetProjection())
    lake_area = water.sum() * cell * cell
    return heights, water, ground, cell, start, rocks, {
        **extras,
        'starts': starts,
        'name': 'Haapajärven tekoallas, Raahe',
        'source': 'mml',
        'attribution': 'Sisältää Maanmittauslaitoksen Maastotietokannan ja Korkeusmalli 2 m -aineistoa (CC BY 4.0)',
        'depth_estimated': not has_water_theme,
        'water_level_n2000': round(water_level, 2),
        'tm35fin_origin': [gt[0], gt[3]],
        'lake_area_km2': round(lake_area / 1e6, 2),
    }


MAX_DEPTH = 7.0  # m: altaan syvin kohta (paikallistieto)


def rasterize_contours(vec, rows, cols, gt, projection, water_level):
    """Korkeuskäyrät ruudukoksi: veden syvyys käyrän kohdalla, muualla NaN.
    Alle metrin syvyiset käyrät jätetään pois (yksittäisiä rantapätkiä)."""
    mem = gdal.GetDriverByName('MEM').Create('', cols, rows, 1, gdal.GDT_Float32)
    mem.SetGeoTransform(gt)
    mem.SetProjection(projection)
    band = mem.GetRasterBand(1)
    band.Fill(np.nan)
    band.SetNoDataValue(np.nan)
    # korkeusarvo on millimetreinä
    gdal.Rasterize(mem, vec, SQLStatement=f'SELECT korkeusarvo / 1000.0 AS h, * FROM korkeuskayra WHERE korkeusarvo < {water_level * 1000 - 1000}',
                   attribute='h', allTouched=True)
    h = band.ReadAsArray().astype(np.float64)
    return water_level - h


def label_components(mask):
    """Yhtenäiset alueet (4-naapurusto): tunnisteet 1..n, 0 = ei aluetta."""
    rows, cols = mask.shape
    labels = np.zeros(mask.shape, dtype=np.int32)
    label = 0
    for r0 in range(rows):
        for c0 in np.flatnonzero(mask[r0] & (labels[r0] == 0)):
            if labels[r0, c0]:
                continue
            label += 1
            stack = [(r0, c0)]
            labels[r0, c0] = label
            while stack:
                r, c = stack.pop()
                for nr, nc in ((r + 1, c), (r - 1, c), (r, c + 1), (r, c - 1)):
                    if 0 <= nr < rows and 0 <= nc < cols and mask[nr, nc] and not labels[nr, nc]:
                        labels[nr, nc] = label
                        stack.append((nr, nc))
    return labels, label


def bathymetry(water, contour_depth, cell, rng):
    """Syvyydet korkeuskäyristä. Käyrät jakavat altaan alueisiin; alueen
    syvyys tulee sitä rajaavista käyristä ja rannasta (syvyys 0) etäisyyksien
    suhteessa. Alue, jota rajaa vain yksi käyrä, on syvänne: sen keskelle
    kohoaa syvyyttä, ja syvimmän käyrän suurimman syvänteen keskellä syvyys on
    MAX_DEPTH. Syvänne voi koskettaa rantaa (vanha jokiuoma päättyy padolle),
    jolloin se madaltuu jyrkästi vasta rannan lähellä."""
    line = water & ~np.isnan(contour_depth)
    levels = sorted(set(np.round(contour_depth[line], 2)))
    free = water & ~line
    labels, count = label_components(free)
    d_shore = distance_to(~water, cell) + cell * 0.5
    d_level = {v: distance_to(line & (np.round(contour_depth, 2) == v), cell) + cell * 0.5 for v in levels}

    # Mitkä rajat kukin alue koskettaa: ranta (0) ja käyrien syvyydet
    touches = [set() for _ in range(count + 1)]
    rows, cols = water.shape
    for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        src = free[max(0, -dr):rows - max(0, dr), max(0, -dc):cols - max(0, dc)]
        lab = labels[max(0, -dr):rows - max(0, dr), max(0, -dc):cols - max(0, dc)]
        nb_water = water[max(0, dr):rows - max(0, -dr), max(0, dc):cols - max(0, -dc)]
        nb_line = line[max(0, dr):rows - max(0, -dr), max(0, dc):cols - max(0, -dc)]
        nb_depth = contour_depth[max(0, dr):rows - max(0, -dr), max(0, dc):cols - max(0, -dc)]
        for k in np.unique(lab[src & ~nb_water]):
            touches[k].add(0.0)
        sel = src & nb_line
        for k, v in set(zip(lab[sel].tolist(), np.round(nb_depth[sel], 2).tolist())):
            touches[k].add(v)

    depth = np.zeros(water.shape)
    depth[line] = contour_depth[line]
    domes = []
    for k in range(1, count + 1):
        region = labels == k
        bounds = touches[k]
        contours = bounds - {0.0}
        if len(contours) == 1 and (0.0 not in bounds or next(iter(contours)) != levels[0]):
            v = next(iter(contours))
            domes.append((k, v, d_level[v][region].max(), 0.0 in bounds))
        elif len(bounds) >= 2:
            # Käyrien välissä: syvyys etäisyyksien käänteisillä painoilla
            num = np.zeros(region.sum())
            den = np.zeros(region.sum())
            for v in bounds:
                d = (d_shore if v == 0.0 else d_level[v])[region]
                num += v / d
                den += 1.0 / d
            depth[region] = num / den
        elif bounds == {0.0} or not bounds:
            # Lahti, jossa ei ole käyriä: matala rannasta kasvava syvyys
            depth[region] = np.minimum(levels[0] - 0.3 if levels else 3.0, 0.36 * np.sqrt(d_shore[region]))
    # Syvänteet: syvimmän käyrän suurin syvänne saa MAX_DEPTH:n
    for k, v, size, at_shore in domes:
        region = labels == k
        deeper = [lv for lv in levels if lv > v]
        if deeper:
            amp = min(1.5, deeper[0] - v - 0.3)
        else:
            biggest = max(s for kk, vv, s, _ in domes if vv == v)
            amp = (MAX_DEPTH - v) * np.sqrt(size / biggest)
        depth[region] = v + amp * (d_level[v][region] / size) ** 0.8
        if at_shore:
            depth[region] = np.minimum(depth[region], 0.5 * d_shore[region])

    # Pehmennys (käyrien välinen taite) ja pieni vaihtelu pohjaan
    for _ in range(3):
        padded = np.pad(np.where(water, depth, 0.0), 1, mode='edge')
        weight = np.pad(water.astype(float), 1, mode='edge')
        acc = sum(padded[1 + dr:1 + dr + rows, 1 + dc:1 + dc + cols] for dr in (-1, 0, 1) for dc in (-1, 0, 1))
        wsum = sum(weight[1 + dr:1 + dr + rows, 1 + dc:1 + dc + cols] for dr in (-1, 0, 1) for dc in (-1, 0, 1))
        depth = np.where(water, acc / np.maximum(wsum, 1.0), 0.0)
    # Rantatörmä: altaan rannoilla vesi syvenee heti noin 0,8 metriin (veneet ja
    # laiturit); laajat matalikot ovat maatuvilla vesialueilla
    depth = np.maximum(depth, np.minimum(0.8, 0.25 * np.sqrt(d_shore)))
    depth += 0.12 * fractal_noise(rows, cols, 32, 3, rng) * np.clip(depth / 2.0, 0.0, 1.0)
    print(f'  syvyyskäyrät {levels} m, {count} aluetta, {len(domes)} suljettua syvännettä')
    return np.clip(depth, 0.3, MAX_DEPTH)


def mml_features(vec, to_world, water_level):
    """Paikannimet, rakennukset ja näkötornit pelin maisemaan."""
    places, seen = [], set()
    for feat in vec.GetLayerByName('paikannimi'):
        name = feat.GetField('teksti')
        if not name or name in seen:
            continue
        seen.add(name)
        geom = feat.GetGeometryRef()
        x, z = to_world(geom.GetX(), geom.GetY())
        places.append({'name': name, 'x': round(x, 1), 'z': round(z, 1)})

    buildings = []
    for feat in vec.GetLayerByName('rakennus'):
        geom = feat.GetGeometryRef()
        geom = geom.GetGeometryRef(0) if geom.GetGeometryName().startswith('MULTI') else geom
        ring = geom.GetGeometryRef(0)
        pts = []
        for i in range(ring.GetPointCount() - 1):  # viimeinen piste = ensimmäinen
            x, z = to_world(ring.GetX(i), ring.GetY(i))
            pts.append([round(x, 2), round(z, 2)])
        if len(pts) >= 3:
            buildings.append({'points': pts, 'height': 3.2 if geom.GetArea() < 60 else 4.5})

    towers = []
    for feat in vec.GetLayerByName('nakotorni'):
        geom = feat.GetGeometryRef()
        x, z = to_world(geom.GetX(), geom.GetY())
        towers.append({'x': round(x, 1), 'z': round(z, 1)})
    return {'places': places, 'buildings': buildings, 'towers': towers}


def border_mask(shape):
    m = np.zeros(shape, bool)
    m[0, :] = m[-1, :] = m[:, 0] = m[:, -1] = True
    return m


def sieve(mask, min_cells):
    """Poistaa alle min_cells kokoiset yhtenäiset läikät (GDAL SieveFilter)."""
    rows, cols = mask.shape
    mem = gdal.GetDriverByName('MEM').Create('', cols, rows, 1, gdal.GDT_Byte)
    band = mem.GetRasterBand(1)
    band.WriteArray(mask.astype(np.uint8))
    gdal.SieveFilter(band, None, band, min_cells, 4)
    return band.ReadAsArray() == 1


def start_near(water, shore_dist_water, heights, cell, c, r):
    """Aloituspaikka maamerkin (solu c, r) viereen: lähin vesisolu, joka on
    8–14 m rannasta ja vähintään 0,6 m syvä. Keula osoittaa reittiä pitkin
    kohti avovettä (vähintään 50 m rannasta): reitti haetaan leveyshaulla
    soluja pitkin, joissa on vähintään 0,45 m vettä (veneen syväys 0,3 m) ja
    jotka ovat vähintään 8 m rannasta."""
    rows, cols = water.shape
    rr, cc = np.mgrid[0:rows, 0:cols]
    depth = np.where(water, -heights, 0.0)
    passable = (depth >= 0.45) & (shore_dist_water >= 8)
    goal = shore_dist_water >= 50
    # Laituripaikan pitää olla yhteydessä avoveteen riittävän leveää reittiä pitkin
    connected = flood_fill(passable, goal)
    ok = water & connected & (shore_dist_water >= 8) & (shore_dist_water <= 14) & (depth >= 0.6)
    dist = np.where(ok, np.hypot(rr - r, cc - c), np.inf)
    sr, sc = np.unravel_index(np.argmin(dist), dist.shape)
    print(f'  aloituspaikka {math.hypot(sr - r, sc - c) * cell:.0f} m maamerkistä')
    path = water_path(passable, goal, (sr, sc))
    if path is None:
        raise SystemExit('Aloituspaikalta ei löytynyt reittiä avovedelle')
    # Suunta noin 30 m päässä olevaan reitin pisteeseen
    tr, tc = path[min(len(path) - 1, 8)]
    yaw = math.degrees(math.atan2(-(tc - sc), -(tr - sr)))
    # Laituri osoittaa veneeltä lähimpään rantaan (maailmassa: +Z = etelä, +X = itä)
    land = np.where(~water, np.hypot(rr - sr, cc - sc), np.inf)
    lr, lc = np.unravel_index(np.argmin(land), land.shape)
    dock_yaw = math.degrees(math.atan2(lc - sc, lr - sr))
    return {
        'dock_yaw_deg': round(dock_yaw, 1),
        'x': round((sc - cols / 2) * cell, 1),
        'z': round((sr - rows / 2) * cell, 1),
        'yaw_deg': round(yaw, 1),
        'dock_length': round(float(shore_dist_water[sr, sc]) + 6.0, 1),
    }


def flood_fill(passable, seeds):
    """Solut, joihin pääsee seed-soluista passable-soluja pitkin (8-naapurusto)."""
    from collections import deque
    rows, cols = passable.shape
    seen = seeds & passable
    queue = deque(zip(*np.nonzero(seen)))
    while queue:
        r, c = queue.popleft()
        for dr in (-1, 0, 1):
            for dc in (-1, 0, 1):
                nr, nc = r + dr, c + dc
                if 0 <= nr < rows and 0 <= nc < cols and passable[nr, nc] and not seen[nr, nc]:
                    seen[nr, nc] = True
                    queue.append((nr, nc))
    return seen


def water_path(passable, goal, start):
    """Lyhin reitti (8-naapurusto) solusta start lähimpään goal-soluun."""
    from collections import deque
    rows, cols = passable.shape
    came = {start: None}
    queue = deque([start])
    while queue:
        cur = queue.popleft()
        if goal[cur]:
            path = []
            while cur is not None:
                path.append(cur)
                cur = came[cur]
            return path[::-1]
        r, c = cur
        for dr in (-1, 0, 1):
            for dc in (-1, 0, 1):
                n = (r + dr, c + dc)
                if (dr or dc) and 0 <= n[0] < rows and 0 <= n[1] < cols and passable[n] and n not in came:
                    came[n] = cur
                    queue.append(n)
    return None


def map_image(heights, water, ground, cell, vec, gt, projection):
    """Karttakuva: vesi syvyyden mukaan, maastotyypit, tiet ja rakennukset."""
    rows, cols = water.shape
    depth = np.clip(-heights / MAX_DEPTH, 0, 1)[..., None]
    shallow = np.array([150, 190, 225], float)
    deep = np.array([40, 95, 170], float)
    land_colors = np.array([
        (88, 128, 72),   # metsä
        (205, 200, 120),  # pelto
        (150, 140, 95),  # suo
        (160, 185, 110),  # avoin
        (150, 150, 145),  # kallio
        (130, 160, 95),  # kaislikko
    ], float)
    img = np.where(water[..., None], shallow * (1 - depth) + deep * depth, land_colors[ground])
    # Rantaviiva tummemmaksi
    edge = water ^ np.roll(water, 1, 0) | water ^ np.roll(water, 1, 1)
    img[edge] = (30, 60, 110)

    mem = gdal.GetDriverByName('MEM').Create('', cols, rows, 3, gdal.GDT_Byte)
    mem.SetGeoTransform((gt[0], cell, 0, gt[3], 0, -cell))
    mem.SetProjection(projection)
    for i in range(3):
        mem.GetRasterBand(i + 1).WriteArray(img[..., i].astype(np.uint8))
    gdal.Rasterize(mem, vec, bands=[1, 2, 3], layers=['tieviiva'], burnValues=[235, 225, 200])
    gdal.Rasterize(mem, vec, bands=[1, 2, 3], layers=['rakennus'], burnValues=[170, 50, 40])
    gdal.Translate(os.path.join(OUT_DIR, 'map.png'), mem, format='PNG')


def find_start(water, shore_dist_water, cell):
    """Aloituspaikka järven eteläpäästä, vähän matkaa rannasta, vene kohti järven keskustaa."""
    rows, cols = water.shape
    wr, wc = np.nonzero(water)
    centroid = np.array([wr.mean(), wc.mean()])
    south = wr.max()
    candidates = np.flatnonzero(wr == south)
    r, c = float(wr[candidates[len(candidates) // 2]]), float(wc[candidates[len(candidates) // 2]])
    direction = centroid - np.array([r, c])
    direction /= np.linalg.norm(direction)
    shore_r, shore_c = r, c
    while shore_dist_water[int(r), int(c)] < 10.0:
        r, c = r + direction[0], c + direction[1]
    # yaw: 0 = pohjoiseen (-Z), positiivinen vastapäivään ylhäältä katsottuna (Godotin Y-akselin kierto)
    yaw = math.degrees(math.atan2(-direction[1], -direction[0]))
    dock = math.hypot(r - shore_r, c - shore_c) * cell + 6.0
    return {
        'x': round((c - cols / 2) * cell, 1),
        'z': round((r - rows / 2) * cell, 1),
        'yaw_deg': round(yaw, 1),
        'dock_length': round(dock, 1),
    }


def largest_component(mask):
    """Suurin yhtenäinen alue (4-naapurusto), GDAL Polygonize-vapaa toteutus."""
    rows, cols = mask.shape
    labels = np.zeros(mask.shape, dtype=np.int32)
    best_label, best_size, label = 0, 0, 0
    for r0 in range(rows):
        for c0 in np.flatnonzero(mask[r0] & (labels[r0] == 0)):
            if labels[r0, c0]:
                continue
            label += 1
            stack = [(r0, c0)]
            labels[r0, c0] = label
            size = 0
            while stack:
                r, c = stack.pop()
                size += 1
                for nr, nc in ((r + 1, c), (r - 1, c), (r, c + 1), (r, c - 1)):
                    if 0 <= nr < rows and 0 <= nc < cols and mask[nr, nc] and not labels[nr, nc]:
                        labels[nr, nc] = label
                        stack.append((nr, nc))
            if size > best_size:
                best_label, best_size = label, size
    return labels == best_label


def write_output(heights, water, ground, cell, start, rocks, info):
    os.makedirs(OUT_DIR, exist_ok=True)
    rows, cols = heights.shape
    shore = np.where(water, distance_to(~water, cell), distance_to(water, cell))
    np.clip(np.round(shore), 0, 65535).astype('<u2').tofile(os.path.join(OUT_DIR, 'shore.bin'))
    heights.astype('<f4').tofile(os.path.join(OUT_DIR, 'heights.bin'))
    water.astype(np.uint8).tofile(os.path.join(OUT_DIR, 'water.bin'))
    ground.astype(np.uint8).tofile(os.path.join(OUT_DIR, 'ground.bin'))
    meta = {
        **info,
        'cell_size': cell,
        'cols': cols,
        'rows': rows,
        'origin_x': -cols / 2 * cell,
        'origin_z': -rows / 2 * cell,
        'max_depth': round(float(-heights[water].min()), 2),
        'start': start,
        'rocks': rocks,
    }
    with open(os.path.join(OUT_DIR, 'lake.json'), 'w', encoding='utf-8') as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
    print(f"{info['name']}: {cols}x{rows} solua à {cell} m, vesialaa {water.sum() * cell * cell / 1e6:.2f} km², "
          f"suurin syvyys {meta['max_depth']} m")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--synthetic', action='store_true', help='väliaikainen järvi')
    group.add_argument('--mml', metavar='KANSIO', help='MML:n maastotietokanta (.gpkg) ja korkeusmalli (.tif)')
    args = parser.parse_args()

    if args.synthetic:
        write_output(*synthetic_lake())
    else:
        write_output(*mml_lake(args.mml))


if __name__ == '__main__':
    main()

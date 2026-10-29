extends Node
## Aallokon testi (CATCHFISH-77): godot --headless --fixed-fps 30 -- --day=180 --wavetest
## Aallokon koko tuulen ja pyyhkäisymatkan mukaan (JONSWAP-taulukko ±30 %),
## ylätuulen rannan ja saaren suoja, terävät harjat ja leveät pohjat, tuulen
## kääntyminen ilman hyppäystä, kasvu ja laantuminen pelin ajassa, sama
## keinunta molemmilla laatutasoilla, fetch.bin samassa ruudukossa kuin water.bin
## ja laiturin kapeassa lahdessa (aloituspaikka 0) elävä pinta 3 m/s tuulella.
## Mittaukset tehdään aaltomallilla (Waves) suoraan, ruutuja ei tarvita.

const WIND_DIR := 0.0 # tuuli puhaltaa pohjoiseen
## Taulukko: tuuli -> [Hs selkä, L selkä, Hs ranta, L ranta] (selkä 2 km, ranta 300 m)
const TABLE := {
	2.0: [0.05, 1.5, 0.02, 0.4],
	4.0: [0.09, 2.4, 0.04, 0.7],
	8.0: [0.18, 3.9, 0.07, 1.1],
	12.0: [0.27, 5.1, 0.11, 1.4],
	15.0: [0.34, 5.9, 0.13, 1.7],
}

var main: Node
var lake: LakeData
var _log: Array[String] = []


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _ready() -> void:
	main = get_parent()
	lake = main.lake
	_check("pelin alussa aallokko heti tuulen mukainen (%.1f m/s)" % Waves.wind, absf(Waves.wind - minf(main.weather.wind_base, Waves.MAX_WIND)) < 0.01)
	Waves.near_radius = INF # mitataan koko järveltä (lähiveden reuna ei häivytä)
	var dock: Vector2 = main.boat.pos # aloituspaikka 0: laituri kapeassa lahdessa
	_fetch_file_checks()
	_table_checks()
	var open := _find_point(1900.0, 2300.0)
	var shore := _find_point(250.0, 350.0)
	print("selkä (%.0f, %.0f) pyyhkäisymatka %.0f m, ranta (%.0f, %.0f) %.0f m" % [open.x, open.y, lake.fetch_at(open.x, open.y, WIND_DIR), shore.x, shore.y, lake.fetch_at(shore.x, shore.y, WIND_DIR)])
	_measured_checks(open, shore)
	_island_check()
	_sharp_crest_check(open)
	_turn_check(open)
	_growth_checks(open)
	_quality_check(open)
	_ripple_checks(open)
	_dock_checks(dock)
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)


func _near(value: float, target: float, tolerance := 0.3) -> bool:
	return absf(value - target) <= target * tolerance


## fetch.bin on samassa ruudukossa kuin water.bin: maalla nolla, vedessä matkaa
func _fetch_file_checks() -> void:
	_check("fetch.bin ladattu: %d x %d solua, %d suuntaa" % [lake.fetch_cols, lake.fetch_rows, lake.fetch_dirs], lake.fetch_dirs == 16 and lake.fetch_planes.size() == 16)
	_check("fetch.bin kattaa water.bin-ruudukon",
		lake.fetch_cols == ceili(lake.cols * lake.cell_size / lake.fetch_cell) and lake.fetch_rows == ceili(lake.rows * lake.cell_size / lake.fetch_cell))
	var wrong := 0
	var wet := 0
	for r in lake.fetch_rows:
		for c in lake.fetch_cols:
			var x := lake.origin_x + (c + 0.5) * lake.fetch_cell
			var z := lake.origin_z + (r + 0.5) * lake.fetch_cell
			var most := 0
			for d in lake.fetch_dirs:
				most = maxi(most, lake.fetch_planes[d][r * lake.fetch_cols + c])
			if lake.is_water(x, z):
				wet += 1
				if most == 0:
					wrong += 1
			elif most != 0:
				wrong += 1
	_check("fetch.bin: maalla nolla, vedessä matkaa (%d vesisolua, %d poikkeavaa)" % [wet, wrong], wet > 1000 and wrong == 0)


## Aallokon kasvukäyrät taulukon mukaan (±30 %)
func _table_checks() -> void:
	for u in TABLE:
		var t: Array = TABLE[u]
		var open := Waves.sea_state(u, 2000.0)
		var shore := Waves.sea_state(u, 300.0)
		var ok: bool = _near(open.x, t[0]) and _near(open.y, t[1]) and _near(shore.x, t[2]) and _near(shore.y, t[3])
		_check("%.0f m/s: selkä Hs %.2f m L %.1f m, ranta Hs %.2f m L %.1f m" % [u, open.x, open.y, shore.x, shore.y], ok)
	_check("alle 1 m/s lähes peilityyni (Hs %.3f m)" % Waves.sea_state(0.8, 2000.0).x, Waves.sea_state(0.8, 2000.0).x < 0.005)
	_check("yli 15 m/s ei kasvata aallokkoa", Waves.sea_state(minf(20.0, Waves.MAX_WIND), 2000.0).x <= Waves.sea_state(15.0, 2000.0).x + 1e-6)


## Vesipiste, jonka pyyhkäisymatka tuulen suuntaan on välillä lo..hi (syvä, ei laiturin lähellä)
func _find_point(lo: float, hi: float) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 200000:
		var p := Vector2(lake.origin_x, lake.origin_z) + Vector2(rng.randf(), rng.randf()) * lake.world_size()
		if lake.depth_at(p.x, p.y) < 1.0:
			continue
		var f := lake.fetch_at(p.x, p.y, WIND_DIR)
		if f >= lo and f <= hi:
			return p
	return Vector2.ZERO


## Merkitsevä aallonkorkeus pinnasta mitattuna: 4 × korkeuden keskihajonta.
## Aallot ovat lyhytharjaisia (korkeus vaihtelee harjan suunnassa), joten
## mitataan 3 × 3 pisteessä (spacing m välein) ja lasketaan keskimääräinen varianssi.
func _measure_hs(p: Vector2, seconds := 240.0, spacing := 2.3) -> float:
	var variance := 0.0
	for i in 9:
		var q := p + Vector2(i % 3 - 1, i / 3 - 1) * spacing
		var sum := 0.0
		var sum2 := 0.0
		var n := 0
		var t := 0.0
		while t < seconds / 3.0:
			Waves.time = 1000.0 + t + i * 97.0
			var h := Waves.swell_height(q)
			sum += h
			sum2 += h * h
			n += 1
			t += 0.07
		var mean := sum / n
		variance += maxf(sum2 / n - mean * mean, 0.0) / 9.0
	return 4.0 * sqrt(variance)


## Pisin aalto, jolla on eniten korkeutta kohdassa p
func _dominant_length(p: Vector2) -> float:
	var best := 0.0
	var length := 0.0
	for c in Waves._components(p):
		if c[2] > best:
			best = c[2]
			length = Waves.LENGTHS[c[0]]
	return length


func _measured_checks(open: Vector2, shore: Vector2) -> void:
	_check("selkä- ja rantapisteet löytyivät", open != Vector2.ZERO and shore != Vector2.ZERO)
	var crest_ratio := 0.0
	for u in [4.0, 8.0, 12.0]:
		Waves.reset(u, WIND_DIR)
		var t: Array = TABLE[u]
		# Taulukon arvot ovat 2 km ja 300 m pyyhkäisymatkalle: verrataan pisteen omaan matkaan
		var f_open := Waves.set_fetch(0, open)
		var f_shore := Waves.set_fetch(0, shore)
		var exp_open: float = t[0] * sqrt(f_open / 2000.0)
		var exp_shore: float = t[2] * sqrt(f_shore / 300.0)
		var hs_open := _measure_hs(open)
		var hs_shore := _measure_hs(shore)
		var l_open := _dominant_length(open)
		var l_shore := _dominant_length(shore)
		_check("%.0f m/s selällä: pinnasta Hs %.3f m (odotus %.3f), aallonpituus %.1f m (taulukko %.1f)" % [u, hs_open, exp_open, l_open, t[1]],
			_near(hs_open, exp_open) and _near(l_open, t[1]))
		_check("%.0f m/s rannassa: pinnasta Hs %.3f m (odotus %.3f), aallonpituus %.1f m (taulukko %.1f)" % [u, hs_shore, exp_shore, l_shore, t[3]],
			_near(hs_shore, exp_shore) and _near(l_shore, t[3]))
		if u == 8.0:
			_check("8 m/s: ylätuulen ranta alle 50 %% selän aallokosta (%.0f %%)" % (hs_shore / hs_open * 100.0), hs_shore < hs_open * 0.5)
			_check("8 m/s: aaltoääni ja kohon keinunta suojassa pienempi (%.2f < %.2f)" % [Waves.local_strength(shore), Waves.local_strength(open)], Waves.local_strength(shore) < Waves.local_strength(open) * 0.6)
			# Suurimmat yksittäiset aallot (nollan ylityksestä seuraavaan, harjasta
			# pohjaan) samoissa 3 × 3 pisteessä kuin Hs
			var biggest := 0.0
			for k in 9:
				var q := open + Vector2(k % 3 - 1, k / 3 - 1) * 2.3
				var hi := -INF
				var lo := INF
				var prev := 0.0
				for i in 1400:
					Waves.time = 2000.0 + i * 0.07 + k * 97.0
					var h := Waves.swell_height(q)
					if prev < 0.0 and h >= 0.0:
						biggest = maxf(biggest, hi - lo)
						hi = -INF
						lo = INF
					hi = maxf(hi, h)
					lo = minf(lo, h)
					prev = h
			crest_ratio = biggest / hs_open
			_check("8 m/s selällä: suurimmat aallot noin 1,5–2 × Hs (%.2f × Hs)" % crest_ratio, crest_ratio > 1.35 and crest_ratio <= 2.0)


## Saaren suojapuolella (alatuulessa) aallokko on pienempi kuin tuulenpuolella
func _island_check() -> void:
	var found := false
	for place in lake.places:
		if not String(place["name"]).ends_with("saari"):
			continue
		var c := Vector2(place["x"], place["z"])
		if lake.is_water(c.x, c.y):
			continue
		var wind := Vector2(sin(WIND_DIR), -cos(WIND_DIR))
		var lee := _water_from(c, wind)
		var windward := _water_from(c, -wind)
		if lee == Vector2.ZERO or windward == Vector2.ZERO:
			continue
		Waves.reset(8.0, WIND_DIR)
		var h_lee := Waves.local_hs(lee)
		var h_wind := Waves.local_hs(windward)
		_check("%s: suojapuoli tyynempi (Hs %.3f m) kuin tuulenpuoli (%.3f m)" % [place["name"], h_lee, h_wind], h_lee < h_wind * 0.7)
		found = true
	_check("saari löytyi suojan tarkistukseen", found)


## Ensimmäinen vesikohta saaren keskeltä suuntaan dir, 25 m rannasta (enintään 400 m)
func _water_from(c: Vector2, dir: Vector2) -> Vector2:
	for s in range(0, 400, 4):
		var p := c + dir * s
		if lake.is_water(p.x, p.y):
			p += dir * 25.0
			return p if lake.is_water(p.x, p.y) else Vector2.ZERO
	return Vector2.ZERO


## Harjat terävämpiä kuin pohjat: pinnan kaarevuus harjoilla vs. pohjilla
## tuulen suuntaisella linjalla (8 m/s selällä)
func _sharp_crest_check(open: Vector2) -> void:
	Waves.reset(8.0, WIND_DIR)
	var lp := Waves.sea_state(8.0, Waves.set_fetch(0, open)).y
	var hs := Waves.local_hs(open)
	var wind := Vector2(sin(WIND_DIR), -cos(WIND_DIR))
	var dx := 0.05
	var delta := lp / 8.0
	var crest_curv := 0.0
	var trough_curv := 0.0
	var crests := 0
	var troughs := 0
	var window := int(lp / 4.0 / dx)
	for k in 12:
		Waves.time = 500.0 + k * 3.7
		var h := PackedFloat32Array()
		var n := int(60.0 / dx)
		for i in n:
			h.append(Waves.swell_height(open + wind * (i * dx - 30.0)))
		var step := int(delta / dx)
		for i in range(window, n - window):
			var v := h[i]
			if absf(v) < 0.2 * hs:
				continue
			var is_max := true
			var is_min := true
			for j in range(i - window, i + window + 1):
				if h[j] > v:
					is_max = false
				if h[j] < v:
					is_min = false
			if not (is_max or is_min) or i - step < 0 or i + step >= n:
				continue
			var curv := (h[i + step] - 2.0 * v + h[i - step]) / (delta * delta)
			if is_max and v > 0.0:
				crest_curv += -curv
				crests += 1
			elif is_min and v < 0.0:
				trough_curv += curv
				troughs += 1
	var ratio := (crest_curv / maxi(crests, 1)) / maxf(trough_curv / maxi(troughs, 1), 1e-6)
	_check("8 m/s: harjat terävämpiä kuin pohjat (kaarevuuden suhde %.2f, %d harjaa, %d pohjaa)" % [ratio, crests, troughs], ratio > 1.5 and crests >= 10 and troughs >= 10)


## Tuulen 90° kääntyminen: pinta ei hyppää, uusi suunta minuutissa
func _turn_check(open: Vector2) -> void:
	var dt := 1.0 / 30.0
	var calm_max := 0.0
	var turn_max := 0.0
	for phase in 2:
		Waves.reset(8.0, WIND_DIR)
		Waves.time = 3000.0
		var prev := Waves.swell_height(open)
		for i in int(70.0 / dt):
			var dir := WIND_DIR + (PI / 2.0 if phase == 1 and i > 0 else 0.0)
			Waves.step(dt, 8.0, dir, 0.0, 1.0)
			var h := Waves.swell_height(open)
			if phase == 0:
				calm_max = maxf(calm_max, absf(h - prev))
			else:
				turn_max = maxf(turn_max, absf(h - prev))
			prev = h
	_check("tuulen 90° kääntyminen ei hyppäytä pintaa (suurin muutos ruudussa %.3f m, tasaisella tuulella %.3f m)" % [turn_max, calm_max], turn_max < calm_max * 1.5 + 0.005)
	var turned := absf(angle_difference(Waves.set_angle[Waves.active], WIND_DIR + PI / 2.0)) < 0.01
	_check("aallokko kääntyi uuteen suuntaan minuutissa (paino %.2f)" % Waves.set_weight[Waves.active], turned and Waves.set_weight[Waves.active] > 0.99 and Waves.set_weight[1 - Waves.active] == 0.0)


## Aallokko kasvaa 2 -> 8 m/s noin 10 peliminuutissa ja laantuu 8 -> 2 m/s noin
## 20 peliminuutissa (90 % muutoksesta), myös ajan nopeutuksella
func _growth_checks(open: Vector2) -> void:
	for scale in [1.0, 10.0, 60.0]:
		var up := _minutes_to_90(open, 2.0, 8.0, scale)
		var down := _minutes_to_90(open, 8.0, 2.0, scale)
		_check("ajan nopeus x%d: kasvu %.1f peliminuuttia (10 ± 3), laantuminen %.1f (20 ± 5)" % [scale, up, down], absf(up - 10.0) <= 3.0 and absf(down - 20.0) <= 5.0)


func _minutes_to_90(p: Vector2, from: float, to: float, scale: float) -> float:
	Waves.reset(to, WIND_DIR)
	var h_to := Waves.local_hs(p)
	Waves.reset(from, WIND_DIR)
	var h_from := Waves.local_hs(p)
	var goal := h_from + 0.9 * (h_to - h_from)
	var dt := 1.0 / 30.0 # oikeaa aikaa ruudussa
	var game_s := 0.0
	while game_s < 3600.0:
		Waves.step(dt, to, WIND_DIR, 0.0, scale)
		game_s += dt * scale
		var h := Waves.local_hs(p)
		if (to > from and h >= goal) or (to < from and h <= goal):
			return game_s / 60.0
	return INF


## Keinunta ei riipu laadusta: Waves.swell_height (vene, koho, pyykit, ankkuri)
## ei lue Veden laatu -asetusta, joten asetuksen vaihto ei muuta tulosta. Matalan
## kevyempi pinta on vain varjostimessa.
func _quality_check(open: Vector2) -> void:
	Waves.reset(8.0, WIND_DIR)
	Waves.time = 1234.5
	var before := Settings.water_quality
	Settings.water_quality = "korkea"
	var high := Waves.swell_height(open)
	Settings.water_quality = "matala"
	var low := Waves.swell_height(open)
	Settings.water_quality = before
	_check("keinunta ei riipu Veden laadusta: swell_height asetuksella Korkea ja Matala %.4f / %.4f m" % [high, low], high == low)


## Väreet riippuvat tuulesta: selvästi 2 m/s alkaen, alle 1 m/s lähes peili
func _ripple_checks(open: Vector2) -> void:
	var f := Waves.set_fetch(0, open)
	_check("väreet 2 m/s selällä selvät (%.2f)" % Waves.ripple_amount(2.0, f), Waves.ripple_amount(2.0, f) >= 0.45)
	_check("väreet 0,8 m/s lähes poissa (%.2f)" % Waves.ripple_amount(0.8, f), Waves.ripple_amount(0.8, f) < 0.1)
	_check("suoja heikentää väreitä vain rannan ensimmäisillä metreillä (5 m: %.2f, 25 m: %.2f)" % [Waves.ripple_amount(3.0, 5.0), Waves.ripple_amount(3.0, 25.0)],
		Waves.ripple_amount(3.0, 5.0) < Waves.ripple_amount(3.0, 25.0) * 0.9 and is_equal_approx(Waves.ripple_amount(3.0, 25.0), Waves.ripple_amount(3.0, 2000.0)))


## Laiturissa (aloituspaikka 0, kapea lahti, pyyhkäisymatka 0–42 m) pinta ei ole
## tasainen 2 ja 3 m/s tuulella mistään 16 suunnasta: aallot liikuttavat pintaa
## (todelliset koot, joten vain nollasta poikkeava) ja väreet näkyvät selvästi
func _dock_checks(dock: Vector2) -> void:
	for u in [2.0, 3.0]:
		var worst := INF
		var failed: Array[String] = []
		for d in 16:
			var dir := d * TAU / 16.0
			Waves.reset(u, dir)
			var fetch := Waves.set_fetch(0, dock)
			var hs := _measure_hs(dock, 15.0, 0.7)
			var ripples := Waves.ripple_amount(u, fetch)
			worst = minf(worst, ripples)
			if not (hs > 0.0 and ripples >= 0.35):
				failed.append("%d° (pyyhkäisymatka %.0f m, Hs %.4f m, väreet %.2f)" % [roundi(rad_to_deg(dir)), fetch, hs, ripples])
		_check("laituri %.0f m/s kaikista 16 suunnasta: väreet vähintään %.2f %s" % [u, worst, ", ".join(failed)], failed.is_empty())

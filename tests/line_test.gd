extends Node
## Siiman testi (CATCHFISH-86): godot --headless --fixed-fps 30 -- --day=180 --linetest
## (talvi: --day=40 --linetest). Siiman muoto ja käytös suunnitelman
## hyväksymiskriteerien mukaan (docs/suunnitelmat/CATCHFISH-86.md) sekä
## nykäyskuorma: iso kala voi katkaista siiman ryntäyksellä alle siiman
## lujuuden, jos jarru on kireällä tai pelaaja kelaa.
##
## Taitekulma mitataan piirretystä käyrästä (siiman keskilinja). Sallitut
## taitteet ovat vain kiinnekohdissa: vavan kärki, siiman pää (uistin, koho
## tai kala), avanto ja veneen laita.

const MAX_BEND := 5.0 # astetta
const JUMP_LIMIT := 1.0 # m ruudussa

var main: Node
var f: Fishing
var boat: Boat
var _log: Array[String] = []
var _messages: Array[String] = []
var _spot := Vector2.ZERO
var _dir := Vector2.ZERO
# Hyppyjen seuranta ruuduittain (tilan vaihdot)
var _watch := false
var _prev_pts: Array = [PackedVector3Array(), PackedVector3Array()]
var _prev_init := [false, false]
var _prev_ends := [0.0, 0.0]
var _worst_jump := 0.0
var _worst_jump_at := ""
var _phase := ""
var _bend_worst := {}


func _ready() -> void:
	main = get_parent()
	f = main.fishing
	boat = main.boat
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	f.message.connect(func(t): _messages.append(t))
	for fish in main.population.fish:
		fish["wary"] = 1.0e9 # tärpit tehdään testissä itse
	main.weather.set_process(false) # sää ei muutu kesken testin
	_wind(3.0, 0.0)
	if f.on_ice:
		_winter.call_deferred()
		return
	_find_spot()
	_place_boat()
	_summer.call_deferred()


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])
	print(("OK    " if ok else "VIRHE ") + name)


func _finish() -> void:
	print("--- yhteenveto ---")
	for l in _log:
		print(l)
	Input.action_release("reel")
	Input.action_release("boat_forward")
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wind(speed: float, direction: float) -> void:
	main.weather.wind_base = speed
	main.weather.gust = 0.0
	main.weather.wind_direction = direction
	Waves.reset(speed, direction)


func _place_boat() -> void:
	boat.pos = _spot
	boat.velocity = Vector2.ZERO
	boat.yaw_rate = 0.0
	boat.yaw = atan2(-_dir.x, -_dir.y)
	boat._apply_transform()
	main.camera_rig.yaw = boat.yaw


## Syvä, suora vesialue (sama haku kuin troll_test.gd)
func _find_spot() -> void:
	var lake: LakeData = main.lake
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var best := -1.0
	var origin := Vector2(lake.start_position.x, lake.start_position.z)
	for i in 6000:
		var p := origin + Vector2(rng.randf_range(-1500, 1500), rng.randf_range(-1500, 1500))
		var d := Vector2.from_angle(rng.randf() * TAU)
		var shallowest := 99.0
		for s in range(-70, 70, 4):
			var q := p + d * s
			shallowest = minf(shallowest, lake.depth_at(q.x, q.y) if lake.is_water(q.x, q.y) else 0.0)
		if shallowest > best:
			best = shallowest
			_spot = p
			_dir = d
	print("Testipaikka: matalin kohta %.1f m" % best)


func _line(i := -1) -> FishingLine:
	return f._rod_get(f._cur if i < 0 else i, "_line")


func _mesh(i := -1) -> ArrayMesh:
	return f._rod_get(f._cur if i < 0 else i, "_line_mesh")


func _reset_rod() -> void:
	Input.action_release("reel")
	f._swap_to(0)
	f.held = 0
	f.in_holder = false
	f.state = Fishing.State.READY
	f._fish_index = -1
	f._fish = {}
	f.tension = 0.0
	f.snagged = false
	f.lure_on_land = false
	f._tie_line()
	f.lure_index = _lure("lusikka")
	main.camera_rig.first_person = false


func _lure(id: String) -> int:
	var list: Array = f.lures()
	for i in list.size():
		if list[i]["id"] == id:
			return i
	return 0


# --- Mittarit -------------------------------------------------------------------

## Piirretty käyrä tasavälein (2 cm): taite mitataan näkyvästä muodosta,
## eikä alle millin värähtely muutaman millin välipätkissä näy kulmana
func _resampled(pts: PackedVector3Array, step := 0.02) -> PackedVector3Array:
	var out := PackedVector3Array()
	if pts.size() < 2:
		return pts
	out.append(pts[0])
	var carry := 0.0
	for k in range(1, pts.size()):
		var a: Vector3 = pts[k - 1]
		var b: Vector3 = pts[k]
		var seg := a.distance_to(b)
		var t := step - carry
		while t <= seg:
			out.append(a.lerp(b, t / seg))
			t += step
		carry = seg - (t - step)
	if out[out.size() - 1].distance_to(pts[pts.size() - 1]) > step * 0.25:
		out.append(pts[pts.size() - 1])
	return out


## Suurin taite piirretyssä käyrässä (sallitut kiinnekohdat pois)
func _bend(i := -1) -> Dictionary:
	var raw := FishingLine.curve_points(_mesh(i))
	var pts := _resampled(raw)
	if raw.size() < 4:
		pts = raw
	var line := _line(i)
	var hole := f._line_hole() if (i < 0 or i == f._cur) else Vector3.INF
	var hull_inv := boat.hull.global_transform.affine_inverse()
	var worst := 0.0
	var at := Vector3.ZERO
	for k in range(1, pts.size() - 1):
		var a: Vector3 = pts[k] - pts[k - 1]
		var b: Vector3 = pts[k + 1] - pts[k]
		if a.length() < 1e-4 or b.length() < 1e-4:
			continue
		var p: Vector3 = pts[k]
		if p.distance_to(pts[0]) < 0.15 or p.distance_to(pts[pts.size() - 1]) < 0.15:
			continue # vavan kärki tai siiman pää (uistin, koho, kala)
		if not f.on_ice and p.y < -0.5 and main.lake.is_water(p.x, p.z):
			continue # syvemmällä kuin 0,5 m siima on häivytetty näkymättömiin (varjostin)
		if hole != Vector3.INF and p.distance_to(hole) < 0.02:
			continue # avannon reuna
		if _near_gunwale(hull_inv * p):
			continue # veneen laita
		var ang := rad_to_deg(a.angle_to(b))
		if ang > worst:
			worst = ang
			at = p
	return {"deg": worst, "at": at, "points": raw.size(), "line": line}


func _near_gunwale(l: Vector3) -> bool:
	if absf(l.z) > 2.45 or l.y > 0.9 or l.y < -0.55:
		return false
	var h := Boat._hull_at(clampf(l.z, -2.2, 2.2))
	return absf(l.x) < h.x + 0.25 and l.y < h.y + 0.25 and l.y > h.z - 0.25


func _check_bend(name: String, i := -1) -> void:
	var b := _bend(i)
	_check("%s: suurin taite %.1f° (≤ %.0f°, %d pistettä)" % [name, b["deg"], MAX_BEND, b["points"]], b["deg"] <= MAX_BEND and b["points"] > 3)
	if b["deg"] > MAX_BEND and OS.has_environment("LINEDEBUG"):
		_dump(b["line"], b["at"])


## Vianetsintä (LINEDEBUG=1): ketjun profiili
func _dump(line: FishingLine, worst_at: Vector3) -> void:
	var a := line.pos[0]
	var e := line.pos[FishingLine.POINTS - 1]
	var dir := Vector3(e.x - a.x, 0.0, e.z - a.z).normalized()
	var best := 0
	for i in FishingLine.POINTS:
		if line.pos[i].distance_to(worst_at) < line.pos[best].distance_to(worst_at):
			best = i
	print("  taite lähellä pistettä %d" % best)
	for i in FishingLine.POINTS:
		var p := line.pos[i]
		var ang := 0.0
		if i > 0 and i < FishingLine.POINTS - 1:
			ang = rad_to_deg((p - line.pos[i - 1]).angle_to(line.pos[i + 1] - p))
		var s := Waves.swell_height(Vector2(p.x, p.z))
		print("  %2d arc %6.2f  x %6.2f  y %6.3f  y-pinta %6.3f  wet %d water %d c %d  kulma %5.1f" % [i, line.arc[i], (p - a).dot(dir), p.y, p.y - s, line.wet[i], line.water[i], line.contact[i], ang])


## Ketjun pituus line_outiin verrattuna (venymä sallittu)
func _check_length(name: String, expected: float) -> void:
	var line := _line()
	var len := line.measured_length()
	var stretch := FishingLine.STRETCH * clampf(f.tension / FishingLine.STRENGTH, 0.0, 1.0)
	var tol := expected * (0.02 + stretch) + 0.02
	_check("%s: siiman pituus %.2f m, odotettu %.2f m (± %.2f)" % [name, len, expected, tol], absf(len - expected) <= tol)


## Ilmassa olevan osan suurin poikkeama suorasta (vavan kärjestä siiman päähän)
func _taut_deviation() -> float:
	var line := _line()
	var a := line.pos[0]
	var b := line.pos[FishingLine.POINTS - 1]
	var worst := 0.0
	for i in FishingLine.POINTS:
		var p := line.pos[i]
		if p.y <= Waves.swell_height(Vector2(p.x, p.z)) + 0.01:
			continue
		var q := Geometry3D.get_closest_point_to_segment(p, a, b)
		worst = maxf(worst, p.distance_to(q))
	return worst


## Pinnalla lepäävät pisteet aaltopinnalla; ei pisteitä pohjan tai maan alla
func _check_surface(name: String) -> void:
	var line := _line()
	var lake: LakeData = main.lake
	var resting := 0
	var worst := 0.0
	var below := 0
	for i in range(1, FishingLine.POINTS - 1):
		var p := line.pos[i]
		if p.y < lake.height_at(p.x, p.z) - 0.005:
			below += 1
		if line.wet[i] == 1 and lake.is_water(p.x, p.z):
			var s := Waves.swell_height(Vector2(p.x, p.z))
			# Pinnalla lepäävä (kelluu): siiman oma pinta; uistimelle painuva ei
			if absf(p.y - line.surf[i]) < 0.03 or absf(p.y - s) < 0.01:
				resting += 1
				if absf(p.y - s) > worst and OS.has_environment("LINEDEBUG"):
					print("    pinta: piste %d ero %.3f, ikä %.3f s, siirtynyt %.3f m, surf %.3f, todellinen %.3f, rate %.3f acc %.3f" % [i, p.y - s, line._time - line.surf_time[i], Vector2(p.x, p.z).distance_to(line.ground_xz[i]), line.surf[i], s, line.surf_rate[i], line.surf_acc[i]])
				worst = maxf(worst, absf(p.y - s))
	_check("%s: siima lepää pinnalla (%d pistettä)" % [name, resting], resting >= 3)
	if resting < 3 and OS.has_environment("LINEDEBUG"):
		_dump(line, line.pos[0])
	_check("%s: pinnalla lepäävät pisteet aaltopinnalla (suurin ero %.1f cm, ≤ 3 cm)" % [name, worst * 100.0], worst <= 0.03)
	_check("%s: ei pisteitä pohjan tai maan alla (%d)" % [name, below], below == 0)


## Löysän siiman ilmassa olevan osan suurin sivupoikkeama tuulen suuntaan
## pystytasosta, jossa ovat vavan kärki ja kohta, jossa siima koskettaa vettä
func _air_bow(wind_dir: Vector3) -> float:
	var line := _line()
	var a := line.pos[0]
	var touch := -1
	for i in range(1, FishingLine.POINTS):
		if line.wet[i] == 1:
			touch = i
			break
	if touch < 2:
		return 0.0
	var b := line.pos[touch]
	var along := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	var n := Vector3(-along.z, 0.0, along.x)
	if n.dot(wind_dir) < 0.0:
		n = -n
	var worst := 0.0
	for i in range(1, touch):
		var off := (line.pos[i] - a).dot(n)
		if absf(off) > absf(worst):
			worst = off
	return worst


## Ruuduittainen hyppy: suurin sisäpisteen siirtymä yli päiden siirtymän
func _process(_delta: float) -> void:
	if not _watch:
		return
	for i in f.rod_count():
		var line: FishingLine = f._rod_get(i, "_line")
		var pts := line.pos.duplicate()
		if line.initialized and _prev_init[i] and _prev_pts[i].size() == pts.size():
			# Päät (vavan kärki ja siiman pää) voivat siirtyä ruudussa ennen kuin
			# fysiikka-askel siirtää muun siiman: verrataan kahden ruudun päihin
			var ends_now := maxf(pts[0].distance_to(_prev_pts[i][0]), pts[pts.size() - 1].distance_to(_prev_pts[i][pts.size() - 1]))
			var ends := maxf(ends_now, _prev_ends[i])
			_prev_ends[i] = ends_now
			var worst := 0.0
			var wk := 0
			for k in range(1, pts.size() - 1):
				if pts[k].distance_to(_prev_pts[i][k]) > worst:
					worst = pts[k].distance_to(_prev_pts[i][k])
					wk = k
			var jump := worst - ends
			if jump > JUMP_LIMIT and OS.has_environment("LINEDEBUG"):
				print("  hyppy %.2f m (päät %.2f): %s, vapa %d, tila %s, kädessä %d, telineessä %s, piste %d %s -> %s, kärki %s -> %s, pää %s" % [jump, ends, _phase, i + 1, Fishing.State.keys()[f._rod_get(i, "state")], f.held, f._rod_get(i, "in_holder"), wk, _prev_pts[i][wk], pts[wk], _prev_pts[i][0], pts[0], pts[pts.size() - 1]])
			if jump > _worst_jump:
				_worst_jump = jump
				_worst_jump_at = "%s, vapa %d" % [_phase, i + 1]
		_prev_pts[i] = pts
		_prev_init[i] = line.initialized


# --- Kesä --------------------------------------------------------------------------

func _summer() -> void:
	await _frames(10)
	# Vianetsintä: LINEONLY=flight,slack,... ajaa vain nimetyt osat
	var only := OS.get_environment("LINEONLY").split(",", false)
	var parts := {
		"flight": _test_flight_and_slack, "slack": _test_slack_distances, "reel": _test_reel_taut,
		"stable": _test_stability, "wind": _test_wind, "bobber": _test_bobber, "fight": _test_fight,
		"boat": _test_under_boat, "troll": _test_troll, "shore": _test_shore,
		"transitions": _test_transitions, "piece": _test_piece,
	}
	for key in parts:
		if only.is_empty() or key in only:
			await parts[key].call()
	if only.is_empty() or "shock" in only:
		_test_shock()
	_finish()


## Heitto: lento ja löysä siima heiton jälkeen
func _test_flight_and_slack() -> void:
	_reset_rod()
	await _frames(5)
	f.lure_index = _lure("lusikka")
	f.power = 0.7
	f.state = Fishing.State.CHARGING
	await _frames(2)
	f._cast()
	var worst := 0.0
	var frames := 0
	while f.state == Fishing.State.FLYING and frames < 200:
		await _frames(1)
		frames += 1
		if f.state == Fishing.State.FLYING and frames > 2:
			var b := _bend()
			if b["deg"] > worst:
				worst = b["deg"]
				if worst > MAX_BEND and OS.has_environment("LINEDEBUG"):
					print("  lento ruutu %d:" % frames)
					_dump(b["line"], b["at"])
	_check("heitto lennossa: suurin taite %.1f° (≤ %.0f°)" % [worst, MAX_BEND], worst <= MAX_BEND and frames > 5)
	_check("heitto osui veteen (%s)" % Fishing.State.keys()[f.state], f.state == Fishing.State.RETRIEVING and not f.lure_on_land)
	await _frames(60)
	_check_bend("löysä siima heiton jälkeen")
	_check_length("löysä siima heiton jälkeen", f.line_out)
	_check_surface("löysä siima heiton jälkeen")


## Löysä siima 20 m ja 45 m (kuin heiton jälkeen)
func _test_slack_distances() -> void:
	for dist: float in [20.0, 45.0]:
		_reset_rod()
		await _frames(3)
		var at := boat.pos + boat.forward() * dist
		f.lure_pos = Vector3(at.x, 0.0, at.y)
		f._prev_lure = f.lure_pos
		f.state = Fishing.State.RETRIEVING
		f._leave_slack()
		await _frames(90)
		var name := "löysä siima %.0f m" % dist
		_check_bend(name)
		_check_length(name, f.line_out)
		_check_surface(name)


## Kelaus kireälle: ilmassa suora
func _test_reel_taut() -> void:
	_reset_rod()
	f.lure_index = _lure("vaappu")
	await _frames(3)
	var at := boat.pos + boat.forward() * 25.0
	f.lure_pos = Vector3(at.x, 0.0, at.y)
	f._prev_lure = f.lure_pos
	f.state = Fishing.State.RETRIEVING
	f._leave_slack()
	await _frames(45)
	Input.action_press("reel")
	Input.action_press("reel_fast")
	var taut := false
	for k in 300:
		await _frames(1)
		if f.state != Fishing.State.RETRIEVING:
			break
		if f.tension >= 0.5 and k > 30:
			taut = true
			break
	await _frames(15)
	Input.action_release("reel_fast")
	_check("kelaus kiristää siiman (jännitys %.2f kg ≥ 0,5 kg)" % f.tension, taut and f.state == Fishing.State.RETRIEVING and f.tension >= 0.5)
	_check_bend("kelaus kireälle")
	_check_length("kelaus kireälle", f.line_out)
	var dev := _taut_deviation()
	_check("kelaus kireälle: ilmassa suora (poikkeama %.1f cm, ≤ 5 cm)" % (dev * 100.0), dev <= 0.05)
	Input.action_release("reel")


## Vakaus: tyynellä, vene ja uistin paikallaan
func _test_stability() -> void:
	_wind(0.0, 0.0)
	_reset_rod()
	f.lure_index = _lure("vaappu") # kelluu levossa pinnalla: uistin paikallaan
	_place_boat() # vene paikallaan (ei ajelehdi edellisistä testeistä)
	# Heitto sivulle: siima ei roiku keulan yli (keulan yli roikkuva löysä
	# siima liukuu hitaasti rungon pintaa pitkin)
	main.camera_rig.yaw = boat.yaw + PI / 2.0
	await _frames(10)
	# Heitto tyynellä; sitten vene, uistin ja tuuli paikallaan 3 s
	f.power = 0.4
	f.state = Fishing.State.CHARGING
	await _frames(2)
	f._cast()
	while f.state == Fishing.State.FLYING:
		await _frames(1)
	await _frames(90) # 3 s
	var worst := 0.0
	var worst_i := 0
	var before := _line().pos.duplicate()
	for k in 30:
		await _frames(1)
		var now := _line().pos.duplicate()
		if OS.has_environment("LINEDEBUG") and k < 6:
			print("    ruutu %d: uistin %s, pituus %.4f, kärki %s, p20 %s" % [k, f.lure_pos, _line().length, f.rod_tip(), now[20]])
		var fw := 0.0
		var fi := 0
		for i in range(1, now.size() - 1):
			if now[i].distance_to(before[i]) > fw:
				fw = now[i].distance_to(before[i])
				fi = i
			if now[i].distance_to(before[i]) > worst:
				worst = now[i].distance_to(before[i])
				worst_i = i
		if OS.has_environment("LINEDEBUG") and fw > 0.001:
			var ln := _line()
			print("    ruutu %d liike %.2f mm pisteessä %d (w %.2f, c %d, wet %d, y %.3f, venymä %.4f), kärki %.2f mm" % [k, fw * 1000.0, fi, ln._w[fi], ln.contact[fi], ln.wet[fi], now[fi].y, ln._stretch(fi), now[0].distance_to(before[0]) * 1000.0])
		before = now
	if OS.has_environment("LINEDEBUG"):
		print("  vakaus: suurin liike pisteessä %d, uistin %s, line_out %.2f" % [worst_i, f.lure_pos, f.line_out])
		var hl := boat.hull.global_transform.affine_inverse()
		for k in 8:
			print("    rungossa %d: %s rest %.3f c %d" % [k, hl * _line().pos[k], _line().rest[mini(k, FishingLine.POINTS - 2)], _line().contact[k]])
		var ln := _line()
		for k in range(14, FishingLine.POINTS):
			print("    %d w %.2f venymä %.4f lepää %d taivutus %s" % [k, ln._w[k], ln._stretch(k), ln._resting[k], ln._bent(k)])
		_dump(_line(), _line().pos[worst_i])
	_check("vakaus: suurin liike ruudussa %.2f mm (≤ 1 mm)" % (worst * 1000.0), worst <= 0.001)
	_check_bend("vakaus tyynellä")
	_wind(3.0, 0.0)


## Tuulikaari: 12 m/s sivutuuli kaartaa löysää siimaa, tyynellä ei
func _test_wind() -> void:
	var results := {}
	for speed: float in [0.0, 12.0]:
		var side := Vector3(boat.right().x, 0.0, boat.right().y)
		_wind(speed, atan2(side.x, -side.z)) # puhaltaa veneen oikealle
		_reset_rod()
		await _frames(3)
		var at := boat.pos + boat.forward() * 20.0
		f.lure_pos = Vector3(at.x, 0.0, at.y)
		f._prev_lure = f.lure_pos
		f.state = Fishing.State.RETRIEVING
		f._leave_slack()
		await _frames(75)
		results[speed] = _air_bow(side)
		if speed > 0.0:
			_check_bend("kova sivutuuli 12 m/s")
			_check_surface("kova sivutuuli 12 m/s")
	_check("tuuli: 12 m/s kaartaa ilmassa olevaa siimaa myötätuuleen (%.2f m)" % results[12.0], results[12.0] > 0.1)
	_check("tuuli: tyynellä ei kaarra (%.3f m)" % absf(results[0.0]), absf(results[0.0]) < 0.03)
	_wind(3.0, 0.0)


## Koho-onki
func _test_bobber() -> void:
	_reset_rod()
	await _frames(3)
	f.lure_index = _lure("koho")
	f.float_depth = 1.5
	var at := boat.pos + boat.forward() * 12.0
	f.lure_pos = Vector3(at.x, 0.0, at.y)
	f._prev_lure = f.lure_pos
	f.state = Fishing.State.RETRIEVING
	f._leave_slack()
	await _frames(120)
	_check("koho pinnalla (%s)" % Fishing.State.keys()[f.state], f._bobber_node.visible)
	_check_bend("koho")
	var end := _line().pos[FishingLine.POINTS - 1]
	_check("koho: siima päättyy kohoon", end.distance_to(f._bobber_pos()) < 0.01)
	_check_length("koho", f.line_out - f._bobber_pos().distance_to(f.lure_pos))


func _hook(sp: String, weight: float, offset: Vector2, depth: float, drag: float) -> void:
	var idx := 0
	for i in main.population.fish.size():
		if main.population.fish[i]["sp"] == sp:
			idx = i
			break
	main.population.fish[idx]["weight"] = weight
	f._fish_index = idx
	f._fish = main.population.fish[idx]
	var p := boat.pos + offset
	f._fish_pos = Vector3(p.x, depth, p.y)
	f.lure_pos = f._fish_pos
	f.line_out = f.rod_tip().distance_to(f._fish_pos)
	f._stamina = 1.0
	f._run_intensity = 1.0
	f._run_dir = offset.normalized()
	f._run_timer = 30.0
	f.drag_kg = drag
	f._fish_known = true
	f._line_steady = 0.0
	f._line_shock = 0.0
	f._jerk_pending = false
	f.state = Fishing.State.FIGHT


## Väsytys: hauki 4 kg, jarru laulaa
func _test_fight() -> void:
	_reset_rod()
	await _frames(3)
	f.shock_load = false # muodon testi: ei nykäystä
	_hook("hauki", 4.0, boat.forward() * 12.0, -0.8, 4.0)
	var sang := false
	for k in 40:
		await _frames(1)
		sang = sang or f.drag_slipping
	_check("väsytys: jarru laulaa (jännitys %.2f kg)" % f.tension, sang and f.state == Fishing.State.FIGHT)
	_check_bend("väsytys, hauki 4 kg")
	_check_length("väsytys, hauki 4 kg", f.line_out)
	var dev := _taut_deviation()
	_check("väsytys: kireä siima ilmassa suora (poikkeama %.1f cm, ≤ 5 cm)" % (dev * 100.0), dev <= 0.05)
	# Jyrkkä kireä siima pinnan läpi: hauki 2 kg 6 m päässä 1,5 m syvyydessä
	_reset_rod()
	await _frames(3)
	_hook("hauki", 2.0, boat.forward() * 6.0, -1.5, 4.0)
	var steep := 0.0
	for k in 40:
		await _frames(1)
		if k > 25 and f.state == Fishing.State.FIGHT:
			var bb := _bend()
			if bb["deg"] > steep:
				steep = bb["deg"]
				if steep > MAX_BEND and OS.has_environment("LINEDEBUG"):
					print("    jyrkkä ruutu %d" % k)
					_dump(bb["line"], bb["at"])
	_check("väsytys, jyrkkä siima pinnan läpi: suurin taite %.1f° (≤ %.0f°)" % [steep, MAX_BEND], steep <= MAX_BEND)
	f.shock_load = true
	f.drag_kg = 3.0
	_reset_rod()


## Kala veneen alla: siima kiertää laidan yli eikä kulje rungon läpi
func _test_under_boat() -> void:
	_reset_rod()
	await _frames(3)
	f.shock_load = false
	# Kala veneen alla (kölin alla, hieman oikealla), vapa vasemmalla laidalla:
	# suora siima kulkisi rungon läpi
	_hook("ahven", 1.0, boat.right() * 0.3, -1.2, 4.0)
	f._run_dir = boat.right()
	f._run_intensity = 0.0
	f._run_timer = 1000.0
	main.camera_rig.yaw = boat.yaw + PI / 2.0
	var inside := 0
	var worst := 0.0
	for k in 60:
		await _frames(1)
		if f.state != Fishing.State.FIGHT:
			break
		var hull_inv := boat.hull.global_transform.affine_inverse()
		for p in _line().pos:
			var l: Vector3 = hull_inv * p
			if FishingLine._inside_hull(l) and _hull_depth(l) > 0.005:
				inside += 1
		if k > 25: # siirron jälkeen siima asettuu ensin
			var bb := _bend()
			if bb["deg"] > worst:
				worst = bb["deg"]
				if OS.has_environment("LINEDEBUG"):
					print("    ruutu %d taite %.1f° rungossa %s" % [k, worst, boat.hull.global_transform.affine_inverse() * bb["at"]])
	var line := _line()
	var touching := 0
	for c in line.contact:
		touching += c
	if OS.has_environment("LINEDEBUG"):
		var hl := boat.hull.global_transform.affine_inverse()
		print("  veneen alla: kärki rungossa %s, kala rungossa %s, taite %s" % [hl * f.rod_tip(), hl * f._fish_pos, hl * _bend()["at"]])
		var ln := _line()
		for k in FishingLine.POINTS:
			var ang := 0.0
			if k > 0 and k < FishingLine.POINTS - 1:
				ang = rad_to_deg((ln.pos[k] - ln.pos[k - 1]).angle_to(ln.pos[k + 1] - ln.pos[k]))
			print("    %s c %d kulma %.1f" % [hl * ln.pos[k], ln.contact[k], ang])
	_check("kala veneen alla: ei pisteitä rungon sisällä (%d)" % inside, inside == 0)
	_check("kala veneen alla: siima kulkee laidan yli (%d pistettä laidalla)" % touching, touching > 0)
	_check("kala veneen alla: suurin taite laidan ulkopuolella %.1f°" % worst, worst <= MAX_BEND)
	f.shock_load = true
	_reset_rod()


## Kuinka syvällä rungon sisällä piste on (marginaalin sisäpuolella)
func _hull_depth(l: Vector3) -> float:
	var h := Boat._hull_at(l.z)
	var hw := FishingLine._half_width(h, l.y) - FishingLine.HULL_MARGIN
	return minf(minf(hw - absf(l.x), h.y - l.y), l.y - h.z)


## Uistelu 60 m siimalla soutaen
func _test_troll() -> void:
	_reset_rod()
	await _frames(3)
	f.lure_index = _lure("lusikka")
	var at := boat.pos - boat.forward() * 58.0 + boat.right() * 1.5
	f.state = Fishing.State.RETRIEVING
	f.lure_pos = Vector3(at.x, -1.0, at.y)
	f._prev_lure = f.lure_pos
	f.line_out = 60.0
	Input.action_press("boat_forward")
	f._rod_holder_key()
	var worst := 0.0
	for k in 240:
		await _frames(1)
		if k > 90:
			var bb := _bend(0)
			if bb["deg"] > worst:
				worst = bb["deg"]
				if worst > MAX_BEND and OS.has_environment("LINEDEBUG"):
					print("    uistelu ruutu %d taite %.2f°" % [k, worst])
					_dump(bb["line"], bb["at"])
	Input.action_release("boat_forward")
	f._swap_to(0)
	_check("uistelu 60 m: vapa telineessä, soudetaan (%.1f km/h)" % boat.speed_kmh(), f.in_holder and boat.speed_kmh() > 1.0)
	_check("uistelu 60 m soutaen: suurin taite %.1f° (≤ %.0f°)" % [worst, MAX_BEND], worst <= MAX_BEND)
	_check_length("uistelu 60 m", f.line_out)
	# Takaisin käteen ja sisään
	f._take_rod(0, "testi")
	f.held = 0
	await _frames(5)
	_reset_rod()
	main.camera_rig.first_person = false
	_place_boat()
	await _frames(30)


## Heitto rannalle: siima lepää maan pinnalla
func _test_shore() -> void:
	_reset_rod()
	var lake: LakeData = main.lake
	# Rantapaikka: vesi veneen kohdalla, maata 12–20 m päässä
	var found := false
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var origin := Vector2(lake.start_position.x, lake.start_position.z)
	var boat_at := Vector2.ZERO
	var land_at := Vector2.ZERO
	for i in 20000:
		var p := origin + Vector2(rng.randf_range(-1500, 1500), rng.randf_range(-1500, 1500))
		if not lake.is_water(p.x, p.y) or lake.depth_at(p.x, p.y) < 1.5:
			continue
		var d := Vector2.from_angle(rng.randf() * TAU)
		var q := p + d * 16.0
		if lake.is_water(q.x, q.y) or lake.ground_at(q.x, q.y) == LakeData.Ground.FOREST:
			continue
		if not (lake.is_water(p.x + d.x * 6.0, p.y + d.y * 6.0) and lake.is_water(p.x - d.x * 3.0, p.y - d.y * 3.0)):
			continue
		boat_at = p
		land_at = q
		found = true
		break
	_check("rantapaikka löytyi", found)
	if not found:
		return
	boat.pos = boat_at
	boat.velocity = Vector2.ZERO
	boat.yaw = atan2(-(land_at - boat_at).x, -(land_at - boat_at).y)
	boat._apply_transform()
	await _frames(10)
	f.state = Fishing.State.RETRIEVING
	f.lure_on_land = true
	f.snagged = false
	f.lure_pos = Vector3(land_at.x, lake.height_at(land_at.x, land_at.y), land_at.y)
	f._prev_lure = f.lure_pos
	f._leave_slack()
	await _frames(90)
	var line := _line()
	var below := 0
	var on_ground := 0
	for i in range(1, FishingLine.POINTS - 1):
		var p := line.pos[i]
		var g := lake.height_at(p.x, p.z)
		if p.y < g - 0.005:
			below += 1
		if not lake.is_water(p.x, p.z) and p.y < g + 0.03:
			on_ground += 1
	_check("heitto rannalle: ei pisteitä maan alla (%d)" % below, below == 0)
	_check("heitto rannalle: siima lepää maassa (%d pistettä)" % on_ground, on_ground >= 2)
	_check_bend("heitto rannalle")
	_reset_rod()
	f.lure_on_land = false
	_place_boat()
	await _frames(20)


## Tilan vaihdot: ei vanhaan paikkaan jäävää ketjua eikä yli 1 m hyppäyksiä
func _test_transitions() -> void:
	_reset_rod()
	await _frames(5)
	_worst_jump = 0.0
	_watch = true
	_phase = "heitto"
	f.power = 0.5
	f.state = Fishing.State.CHARGING
	await _frames(10)
	f._cast()
	while f.state == Fishing.State.FLYING:
		await _frames(1)
	await _frames(20)
	_phase = "sisäänkelaus"
	Input.action_press("reel_fast")
	Input.action_press("reel")
	for k in 900:
		await _frames(1)
		if f.state == Fishing.State.READY:
			break
	Input.action_release("reel")
	Input.action_release("reel_fast")
	_check("sisäänkelaus päättyi (%s)" % Fishing.State.keys()[f.state], f.state == Fishing.State.READY)
	await _frames(20)
	var line := _line()
	var tip := f.rod_tip()
	var far := 0.0
	for p in line.pos:
		far = maxf(far, p.distance_to(tip))
	_check("sisäänkelauksen jälkeen siima roikkuu kärjessä (kauimmainen %.2f m)" % far, far < 0.6)
	_phase = "vapa telineeseen"
	_watch = false # testin oma siirto (uistin veneen perään) ei ole tilan vaihto
	var at := boat.pos - boat.forward() * 20.0
	f.state = Fishing.State.RETRIEVING
	f.lure_pos = Vector3(at.x, -0.5, at.y)
	f._prev_lure = f.lure_pos
	f.line_out = f.rod_tip().distance_to(f.lure_pos) + 0.5
	await _frames(60)
	_prev_init = [false, false]
	_watch = true
	f._rod_holder_key() # vapa 1 telineeseen, vapa 2 käteen
	if OS.has_environment("LINEDEBUG"):
		for k in 4:
			var l0 := _line(0)
			print("  ruutu %d: kärki %s, p3 %s, arc3 %.2f, len %.2f, tip_world %s" % [k, l0.pos[0], l0.pos[3], l0.arc[3], l0.length, f._rod_get(0, "_tip_world")])
			await _frames(1)
	await _frames(30)
	_check("vapa 1 telineessä, vapa 2 kädessä", f.held == 1 and _line(0).pos[0].distance_to(f._rod_get(0, "_tip_world")) < 0.01)
	_phase = "vavan vaihto"
	f._rod_holder_key() # vapa 2 pohjalle, vapa 1 telineestä käteen
	await _frames(30)
	_check("vapa 1 telineestä käteen", f.held == 0 and not f.in_holder)
	_check("vapa 1: siima seuraa kärkeä", _line(0).pos[0].distance_to(f.rod_tip()) < 0.01)
	_phase = "haavinta"
	_watch = false
	f.shock_load = false
	_hook("ahven", 0.4, boat.right() * 2.2, -0.4, 3.0)
	f.line_out = 2.5
	f._stamina = 0.1
	f._run_intensity = 0.12
	await _frames(30)
	_prev_init = [false, false]
	_watch = true
	f._try_land()
	var landing := f.state == Fishing.State.LANDING
	var end_ok := true
	for k in 150:
		await _frames(1)
		if f.state == Fishing.State.LANDING:
			end_ok = end_ok and _line().pos[FishingLine.POINTS - 1].distance_to(f._landing_net.fish_position()) < 0.3
		elif f.state == Fishing.State.LANDED:
			break
	_check("haavinta: siima seuraa kalaa haaviin", landing and end_ok)
	f.state = Fishing.State.READY
	f.shock_load = true
	await _frames(20)
	_phase = "katkeaminen"
	_watch = false
	_hook("hauki", 3.0, boat.forward() * 10.0, -0.8, 3.0)
	await _frames(30)
	_prev_init = [false, false]
	_watch = true
	f._lose_fish("Siima katkesi! (testi)", true)
	await _frames(30)
	_watch = false
	_check("tilan vaihdot: suurin hyppy ruudussa %.2f m (≤ %.0f m) %s" % [_worst_jump, JUMP_LIMIT, _worst_jump_at], _worst_jump <= JUMP_LIMIT)
	f._tie_line()
	_reset_rod()
	await _frames(10)


## Katkennut pätkä vavan kärjessä
func _test_piece() -> void:
	_reset_rod()
	await _frames(5)
	_hook("hauki", 3.0, boat.forward() * 15.0, -0.8, 3.0)
	await _frames(20)
	_messages.clear()
	f._lose_fish("Siima katkesi! (testi)", true)
	await _frames(60)
	var line := _line()
	var len := line.measured_length()
	_check("katkeaminen: tila READY (%s)" % Fishing.State.keys()[f.state], f.state == Fishing.State.READY)
	_check("katkennut pätkä roikkuu kärjessä (%.2f m, %.1f m ± 2 %%)" % [len, FishingLine.SNAP_PIECE], f._line_piece and line.free_end and absf(len - FishingLine.SNAP_PIECE) <= FishingLine.SNAP_PIECE * 0.02)
	_check("katkennut pätkä alkaa vavan kärjestä", line.pos[0].distance_to(f.rod_tip()) < 0.01)
	_check("katkennut pätkä: uistinta ei näy", not f._lure_node.visible)
	_check_surface_piece()
	# Poistuu: heitto
	f._unhandled_input(_action("cast", true))
	await _frames(2)
	_check("pätkä poistuu heitossa", not f._line_piece and not _line().free_end)
	f.state = Fishing.State.READY
	await _frames(5)
	# Poistuu: uistimen vaihto
	f._line_piece = true
	_line().cut(FishingLine.SNAP_PIECE)
	await _frames(5)
	var other := "vaappu" if f.lure()["id"] != "vaappu" else "lusikka"
	f.select_lure(other)
	await _frames(2)
	_check("pätkä poistuu uistimen vaihdossa", not f._line_piece)
	# Poistuu: vapa pohjalle (toinen vapa telineestä käteen tai kädet vapaiksi)
	f._line_piece = true
	_line().cut(FishingLine.SNAP_PIECE)
	await _frames(5)
	f._swap_to(0)
	f.held = -1 # vapa veneen pohjalle
	await _frames(5)
	_check("pätkä poistuu, kun vapa lasketaan pohjalle", not f._rod_get(0, "_line_piece"))
	f._swap_to(0)
	f.held = 0
	_reset_rod()
	await _frames(5)


func _check_surface_piece() -> void:
	var line := _line()
	var lake: LakeData = main.lake
	var below := 0
	for p in line.pos:
		if p.y < lake.height_at(p.x, p.z) - 0.005:
			below += 1
	_check("katkennut pätkä: ei pohjan alla (%d)" % below, below == 0)


func _action(action: String, pressed: bool) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	return ev


# --- Nykäyskuorma ------------------------------------------------------------------
# Väsytys ajetaan suoraan _fight-kutsuilla yhden ruudun aikana (vene paikallaan),
# joten tulos ei riipu ruudunpäivityksestä. Jokainen tapaus useilla siemenillä.

const DT := 1.0 / 60.0
const SEEDS := [1, 2, 3, 4, 5]


## Kala koukussa levossa (ei ryntäystä), siima kireällä
func _fight_setup(sp: String, weight: float, drag: float, seed: int) -> void:
	_hook(sp, weight, boat.forward() * 15.0, -1.5, drag)
	f._rng.seed = seed
	f._run_intensity = 0.12
	f._run_timer = 1000.0
	f._run_dir = boat.forward()
	f._fish_known = false
	f._line_steady = 0.0
	f._line_shock = 0.0
	# Levossa siima kiristyy tasaiseen jännitykseen
	for k in 30:
		f._fight(DT)


## Väsytetään s sekuntia; palauttaa {"snap": viesti tai "", "slip": jarru luisti}
func _fight_for(seconds: float, reel: bool) -> Dictionary:
	if reel:
		Input.action_press("reel")
	else:
		Input.action_release("reel")
	_messages.clear()
	var slip := false
	var result := ""
	for k in int(seconds / DT):
		f._fight(DT)
		slip = slip or f.drag_slipping
		if f.state != Fishing.State.FIGHT:
			for m in _messages:
				if m.begins_with("Siima katkesi"):
					result = m
			break
	Input.action_release("reel")
	return {"snap": result, "slip": slip}


func _stop_fight() -> void:
	f._tie_line()
	f.state = Fishing.State.READY
	f._fish = {}
	f._fish_index = -1
	f.tension = 0.0


func _test_shock() -> void:
	f._swap_to(0)
	f.held = 0
	f.in_holder = false
	var away := boat.forward()
	# 1) Hauki 8 kg, jarru 6 kg, ei kelausta: katkeaa ensimmäisessä täysivoimaisessa ryntäyksessä
	var snaps := 0
	var shock_msg := 0
	for s in SEEDS:
		_fight_setup("hauki", 8.0, 6.0, s)
		f._start_run(away, 1.0, 3.0)
		var r := _fight_for(0.2, false)
		snaps += 1 if r["snap"] != "" else 0
		shock_msg += 1 if r["snap"] == Fishing.SHOCK_SNAP_TEXT else 0
		_stop_fight()
	_check("nykäys: hauki 8 kg, jarru 6 kg katkeaa ensimmäisessä ryntäyksessä (%d/%d, nykäysviesti %d)" % [snaps, SEEDS.size(), shock_msg], snaps == SEEDS.size() and shock_msg == SEEDS.size())
	# 2) Hauki 8 kg, jarru 4 kg: ei katkea 30 s väsytyksessä, jarru luistaa
	for reel: bool in [false, true]:
		snaps = 0
		var slips := 0
		for s in SEEDS:
			_fight_setup("hauki", 8.0, 4.0, s)
			f._start_run(away, 1.0, 3.0)
			var r := _fight_for(30.0, reel)
			snaps += 1 if r["snap"] != "" else 0
			slips += 1 if r["slip"] else 0
			_stop_fight()
		_check("nykäys: hauki 8 kg, jarru 4 kg%s ei katkea 30 s (%d katkesi), jarru luistaa (%d/%d)" % [" kelaten" if reel else "", snaps, slips, SEEDS.size()], snaps == 0 and slips == SEEDS.size())
	# 3) Hauki 4,5 kg, jarru 6 kg: kelaus ryntäyksen alussa katkaisee, ilman ei
	for reel: bool in [true, false]:
		snaps = 0
		for s in SEEDS:
			_fight_setup("hauki", 4.5, 6.0, s)
			if reel:
				Input.action_press("reel")
			f._start_run(away, 1.0, 3.0)
			var r := _fight_for(1.0, reel)
			snaps += 1 if r["snap"] != "" else 0
			_stop_fight()
		if reel:
			_check("nykäys: hauki 4,5 kg, jarru 6 kg, kelaten ryntäyksen alussa katkeaa (%d/%d)" % [snaps, SEEDS.size()], snaps == SEEDS.size())
		else:
			_check("nykäys: hauki 4,5 kg, jarru 6 kg, ilman kelausta ei katkea (%d katkesi)" % snaps, snaps == 0)
	# 4) Pienet kalat eivät katkaise siimaa nykäyksellä: jarru 10 kg, kelaten 60 s
	for fish in [["ahven", 0.3], ["sarki", 1.4], ["lahna", 2.0], ["hauki", 3.0]]:
		snaps = 0
		for s in SEEDS:
			_fight_setup(fish[0], fish[1], 10.0, s)
			f._start_run(away, 1.0, 3.0)
			var r := _fight_for(60.0, true)
			snaps += 1 if r["snap"] == Fishing.SHOCK_SNAP_TEXT else 0
			_stop_fight()
		_check("nykäys: %s %.1f kg, jarru 10 kg, kelaten 60 s: ei nykäyskatkeamisia (%d)" % [fish[0], fish[1], snaps], snaps == 0)
	# 5) Jarru 5,0 kg: hauki 14 kg kelaten ei katkea
	snaps = 0
	for s in SEEDS:
		_fight_setup("hauki", 14.0, 5.0, s)
		f._start_run(away, 1.0, 3.0)
		var r := _fight_for(30.0, true)
		snaps += 1 if r["snap"] != "" else 0
		_stop_fight()
	_check("nykäys: jarru 5,0 kg, hauki 14 kg kelaten 30 s ei katkea (%d)" % snaps, snaps == 0)
	# 6) Vastaisku isoon kalaan: jarru 6 kg katkaisee, 3 kg ei
	for drag: float in [6.0, 3.0]:
		snaps = 0
		for s in SEEDS:
			_hook("hauki", 8.0, boat.forward() * 15.0, -1.5, drag)
			f.state = Fishing.State.BITE
			f.tension = 0.05
			f._rng.seed = s
			f._try_hook(1.0, "Vastaisku!")
			var r := _fight_for(10.0, false)
			snaps += 1 if r["snap"] != "" else 0
			_stop_fight()
		if drag > 5.0:
			_check("nykäys: vastaisku hauki 8 kg, jarru 6 kg katkaisee (%d/%d)" % [snaps, SEEDS.size()], snaps == SEEDS.size())
		else:
			_check("nykäys: vastaisku hauki 8 kg, jarru 3 kg ei katkaise (%d)" % snaps, snaps == 0)
	# 7) Jännityspalkki: huippu ja paluu tasaiseen noin 0,5 s:ssa
	_fight_setup("hauki", 4.5, 6.0, 1)
	var steady0 := f._line_steady
	f._start_run(away, 1.0, 3.0)
	f._fight(DT)
	var peak := f.tension
	var steady := f._line_steady
	for k in int(0.5 / DT):
		f._fight(DT)
	var after := f.tension - f._line_steady
	_check("nykäys: jännityspalkki hyppää huippuun %.2f kg (tasainen %.2f, ennen %.2f)" % [peak, steady, steady0], peak > steady + 1.0)
	_check("nykäys: palkki palaa tasaiseen 0,5 s:ssa (jäljellä %.2f kg)" % after, after < 0.12 * (peak - steady))
	_stop_fight()
	# 8) Kalan väsyminen ennallaan: sama kala ja jarru ilman nykäysmallia (= main)
	for fish in [["hauki", 3.0, 3.0], ["ahven", 0.8, 2.0]]:
		var times := []
		for model: bool in [true, false]:
			f.shock_load = model
			var total := 0.0
			for s in SEEDS:
				_fight_setup(fish[0], fish[1], fish[2], s)
				f._run_timer = 0.0
				var t := 0.0
				while t < 180.0 and f.state == Fishing.State.FIGHT and f._stamina >= 0.35:
					f._fight(DT)
					t += DT
				total += t
				_stop_fight()
			times.append(total / SEEDS.size())
		f.shock_load = true
		var ratio: float = times[0] / maxf(times[1], 0.001)
		_check("nykäys: %s %.1f kg jarru %.1f kg väsyy %.1f s (ilman nykäysmallia %.1f s, ero %.1f %%, ≤ 5 %%)" % [fish[0], fish[1], fish[2], times[0], times[1], (ratio - 1.0) * 100.0], absf(ratio - 1.0) <= 0.05)
	f.drag_kg = 3.0
	_reset_rod()


# --- Talvi --------------------------------------------------------------------------

func _winter() -> void:
	_find_spot()
	_place_boat()
	await _frames(10)
	var hole := Vector3.ZERO
	var front := boat.pos + boat.forward() * Fishing.HOLE_AHEAD
	hole = Vector3(front.x, 0.0, front.y)
	f.holes.append(hole)
	f._add_hole_visual(hole)
	# Pilkki avannossa
	f.current_hole = hole
	f.state = Fishing.State.RETRIEVING
	f.lure_pos = Vector3(hole.x, -1.5, hole.z)
	f.line_out = f.rod_tip().distance_to(hole) + 1.5
	await _frames(60)
	_check_bend("pilkki avannossa")
	_check_ice("pilkki avannossa")
	_check_length("pilkki avannossa", f.line_out - f.rod_tip().distance_to(hole))
	# Kala jään alla 4 m avannosta
	_hook("ahven", 0.6, boat.forward() * Fishing.HOLE_AHEAD + boat.right() * 4.0, -2.0, 3.0)
	f.shock_load = false
	f._run_intensity = 0.12
	var worst := 0.0
	var through := 0
	for k in 60:
		await _frames(1)
		if f.state != Fishing.State.FIGHT:
			break
		if k > 10:
			worst = maxf(worst, _bend()["deg"])
			through += _ice_crossings(hole)
	_check("kala jään alla: suurin taite %.1f° (avannon reunaa lukuun ottamatta, ≤ %.0f°)" % [worst, MAX_BEND], worst <= MAX_BEND)
	_check("kala jään alla: siima kulkee avannon kautta (%d jään läpi)" % through, through == 0)
	f.shock_load = true
	_test_shock_ice()
	_finish()


## Jäällä: avannon ulkopuolella ei pisteitä jään sisällä
func _check_ice(name: String) -> void:
	var c := _ice_crossings(f.current_hole)
	_check("%s: siima kulkee avannon kautta (%d jään läpi)" % [name, c], c == 0)


func _ice_crossings(hole: Vector3) -> int:
	var line := _line()
	var n := 0
	for i in FishingLine.POINTS:
		var p := line.pos[i]
		var out := Vector2(p.x - hole.x, p.z - hole.z).length() > FishingLine.HOLE_RADIUS + 0.01
		if out and p.y > FishingLine.ICE_BOTTOM + 0.005 and p.y < 0.0:
			n += 1
	# Ketjun välit avannon ulkopuolella eivät nouse jään läpi
	for i in FishingLine.POINTS - 1:
		var a := line.pos[i]
		var b := line.pos[i + 1]
		var ao := Vector2(a.x - hole.x, a.z - hole.z).length() > FishingLine.HOLE_RADIUS + 0.01
		var bo := Vector2(b.x - hole.x, b.z - hole.z).length() > FishingLine.HOLE_RADIUS + 0.01
		if ao and bo and (a.y > 0.0) != (b.y > 0.0):
			n += 1
	return n


## Pilkki: sama nykäysmalli (hauki 8 kg, jarru 6 kg katkeaa)
func _test_shock_ice() -> void:
	var snaps := 0
	for s in SEEDS:
		_hook("hauki", 8.0, boat.forward() * Fishing.HOLE_AHEAD + boat.right() * 3.0, -2.0, 6.0)
		f._rng.seed = s
		f._run_intensity = 0.12
		f._run_timer = 1000.0
		for k in 30:
			f._fight(DT)
		f._start_run(boat.right(), 1.0, 3.0)
		var r := _fight_for(0.2, false)
		snaps += 1 if r["snap"] == Fishing.SHOCK_SNAP_TEXT else 0
		_stop_fight()
	_check("pilkki: hauki 8 kg, jarru 6 kg katkeaa nykäisyyn (%d/%d)" % [snaps, SEEDS.size()], snaps == SEEDS.size())

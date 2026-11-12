extends Node
## Koukussa oleva kala pysyy vedessä (CATCHFISH-119):
## godot --headless --fixed-fps 30 -- --day=180 --fightdepthtest
## Kuvat (ikkuna, näytönohjain): --fightdepthtest-shots=KANSIO tallentaa kuvat
## takaa ja sivulta, kun hauki on kelattu veneen viereen (oikea laita ja perä).
##
## Kireä siima veti kalaa suoraan kohti vavan kärkeä, joten kelattu tai veneen
## vetämä kala nousi ilmaan. Testi mittaa joka fysiikka-askeleessa kalan
## korkeuden, välin rungon ääriviivaan ja siiman pituuden
## (docs/suunnitelmat/CATCHFISH-119.md, hyväksymiskriteerit).

const DEPTH := 0.15 # m: kala vähintään näin syvällä pinnan alla
const GAP := 0.3 # m: kala vähintään näin kaukana rungon ääriviivasta
const SLIDE_SPEED := 0.5 # m/s: veneen alta nouseva kala liukuu laidan viereen
const ROD := 0 # testattava vapa

var main: Node
var f: Fishing
var boat: Boat
var _log: Array[String] = []
var _messages: Array[String] = []
var _spot := Vector2.ZERO
var _dir := Vector2.ZERO
var _shots := ""
var _outline := PackedVector2Array()
# Veneen siirto tasaisella nopeudella (m/s), 0 = paikallaan
var _tow := 0.0
# Mittaus ruuduittain (m = mittarit, nollataan tilanteen alussa)
var _measure := false
var m := {}


func _ready() -> void:
	main = get_parent()
	f = main.fishing
	boat = main.boat
	process_physics_priority = 100 # mittaus saman askeleen lopussa, veneen ja vapojen jälkeen
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	f.message.connect(func(t): _messages.append(t))
	for fish in main.population.fish:
		fish["wary"] = 1.0e9 # tärpit tehdään testissä itse
	main.weather.set_process(false) # sää ei muutu kesken testin
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fightdepthtest-shots="):
			_shots = arg.split("=")[1]
	# Rungon ääriviiva tiheästi (oma laskenta, ei pelin apufunktiota)
	var n := 220
	for i in n + 1:
		var z := lerpf(-2.2, 2.2, float(i) / n)
		_outline.append(Vector2(Boat._hull_at(z).x, z))
	for i in range(n, 0, -1):
		var z := lerpf(-2.2, 2.2, float(i) / n)
		_outline.append(Vector2(-Boat._hull_at(z).x, z))
	_wind(3.0, 0.0)
	_find_spot()
	_place_boat()
	_run.call_deferred()


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])
	print(("OK    " if ok else "VIRHE ") + name)


func _finish() -> void:
	print("--- yhteenveto ---")
	for l in _log:
		print(l)
	_release_keys()
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)


func _release_keys() -> void:
	Input.action_release("reel")
	Input.action_release("reel_fast")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


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
	main.camera_rig.yaw = boat.yaw + PI


## Syvä, suora vesialue: tilaa myös veneen siirtoon 7,5 m/s 15 s ajan
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
		for s in range(-40, 140, 4):
			var q := p + d * s
			shallowest = minf(shallowest, lake.depth_at(q.x, q.y) if lake.is_water(q.x, q.y) else 0.0)
		if shallowest > best:
			best = shallowest
			_spot = p
			_dir = d
	print("Testipaikka: matalin kohta %.1f m" % best)


func _v(name: String) -> Variant:
	return f._rod_get(ROD, name)


## Vapa 0 käteen (in_holder = false) tai telineeseen, ei kalaa
func _reset_rod(in_holder: bool) -> void:
	_release_keys()
	f._swap_to(ROD)
	f.state = Fishing.State.READY
	f._fish_index = -1
	f._fish = {}
	f.tension = 0.0
	f._landing_prompt = false
	f.in_holder = in_holder
	f.held = -1 if in_holder else ROD
	main.camera_rig.first_person = false
	main.camera_rig.shot_view = false


## Kala koukkuun kohtaan veneestä (offset, maailman xz) syvyydelle depth
func _hook(sp: String, weight: float, offset: Vector2, depth: float, stamina: float, seed_value: int) -> void:
	var idx := -1
	for i in main.population.fish.size():
		if main.population.fish[i]["sp"] == sp:
			idx = i
			break
	if idx < 0:
		_check("lajia %s on kalakannassa" % sp, false)
		return
	main.population.fish[idx]["weight"] = weight
	f._swap_to(ROD)
	f._rng.seed = seed_value # ryntäykset samat joka ajossa
	f._fish_index = idx
	f._fish = main.population.fish[idx]
	var p := boat.pos + offset
	f._fish_pos = Vector3(p.x, -depth, p.y)
	f.lure_pos = f._fish_pos
	f.line_out = f.rod_tip().distance_to(f._fish_pos)
	f._stamina = stamina
	f._run_intensity = 0.12
	f._run_dir = offset.normalized()
	f._run_timer = 2.0
	f.drag_kg = 3.0
	f._fish_known = true
	f._line_steady = 0.0
	f._line_shock = 0.0
	f._jerk_pending = false
	f._slack_time = 0.0
	f._landing_prompt = false
	f.state = Fishing.State.FIGHT


## Kohdan etäisyys rungon ääriviivasta vaakatasossa (negatiivinen = sisällä)
func _hull_distance(world: Vector3) -> float:
	var l3: Vector3 = boat.hull.global_transform.affine_inverse() * world
	var l := Vector2(l3.x, l3.z)
	var best := INF
	for i in _outline.size():
		var c := Geometry2D.get_closest_point_to_segment(l, _outline[i], _outline[(i + 1) % _outline.size()])
		best = minf(best, l.distance_to(c))
	return -best if Geometry2D.is_point_in_polygon(l, _outline) else best


## Onko kohta rungon sisällä: ääriviivan sisällä kölin ja laidan välissä
func _inside_hull(world: Vector3) -> bool:
	var l: Vector3 = boat.hull.global_transform.affine_inverse() * world
	if absf(l.z) > 2.2 or not Geometry2D.is_point_in_polygon(Vector2(l.x, l.z), _outline):
		return false
	var h := Boat._hull_at(l.z)
	return l.y > h.z and l.y < h.y


## Rungon pohjan korkeus maailmassa: syvin köli (Boat.HULL_STATIONS)
func _hull_bottom_y() -> float:
	var keel := 0.0
	for st in Boat.HULL_STATIONS:
		keel = minf(keel, st[3])
	return boat.hull.global_position.y + keel


func _reset_measure() -> void:
	m = {
		"frames": 0, "max_y": -99.0, "max_node_y": -99.0, "max_over_wave": -99.0,
		"min_gap": 99.0, "max_end": 0.0, "max_short": 0.0, "min_line": 99.0,
		"inside": 0, "prompt_gap": 99.0, "prompt_y": 0.0, "min_gap_deep": 99.0, "max_gap_deep": -99.0, "max_step": 0.0, "max_own_step": 0.0, "prev_tip": Vector3.ZERO, "step_at": Vector3.ZERO, "prev": Vector3.INF, "start": Vector3.INF,
		"prompt_at": -1.0, "min_wave": 0.0, "taut": 0, "lost": false,
	}


func _physics_process(dt: float) -> void:
	if _measure:
		if _v("state") != Fishing.State.FIGHT:
			m["lost"] = true
			_measure = false
		else:
			var pos: Vector3 = _v("_fish_pos")
			var tip: Vector3 = _v("_tip_world")
			var node: MeshInstance3D = _v("_fish_node")
			var line: float = _v("line_out")
			var wave := Waves.swell_height(Vector2(pos.x, pos.z))
			m["frames"] += 1
			m["max_y"] = maxf(m["max_y"], pos.y)
			m["max_node_y"] = maxf(m["max_node_y"], node.global_position.y)
			m["max_over_wave"] = maxf(m["max_over_wave"], pos.y - wave)
			m["min_wave"] = minf(m["min_wave"], wave)
			# Runkoväli koskee kalaa, joka on rungon pohjan (syvin köli) tasolla tai ylempänä
			if pos.y >= _hull_bottom_y():
				m["min_gap"] = minf(m["min_gap"], _hull_distance(pos))
			else:
				m["min_gap_deep"] = minf(m["min_gap_deep"], _hull_distance(pos))
				m["max_gap_deep"] = maxf(m["max_gap_deep"], _hull_distance(pos))
			if m["prev"] != Vector3.INF:
				var step: float = (pos - m["prev"]).length()
				if step > m["max_step"]:
					m["max_step"] = step
					m["step_at"] = pos
				# Kireä siima siirtää kalaa myös vavan kärjen liikkeen verran
				m["max_own_step"] = maxf(m["max_own_step"], step - (tip - m["prev_tip"]).length())
			m["prev"] = pos
			m["prev_tip"] = tip
			if OS.has_environment("FDDEBUG"):
				var hl: Vector3 = boat.hull.global_transform.affine_inverse() * pos
				var tl: Vector3 = boat.hull.global_transform.affine_inverse() * tip
				print("  %d kala (%.2f %.2f %.2f) kärki (%.2f %.2f %.2f) siima %.3f väli %.3f kehote %s" % [m["frames"], hl.x, pos.y, hl.z, tl.x, tip.y, tl.z, line, tip.distance_to(pos), _v("_landing_prompt")])
			if m["start"] == Vector3.INF:
				m["start"] = pos
			m["max_end"] = maxf(m["max_end"], (_v("lure_pos") as Vector3).distance_to(pos))
			# Siima ei saa olla lyhyempi kuin kärjen ja kalan väli (löysä siima on pidempi)
			m["max_short"] = maxf(m["max_short"], tip.distance_to(pos) - line)
			m["min_line"] = minf(m["min_line"], line)
			if tip.distance_to(pos) >= line - 0.001:
				m["taut"] += 1
			if _inside_hull(pos):
				m["inside"] += 1
			if _v("_landing_prompt"):
				if m["prompt_at"] < 0.0:
					m["prompt_at"] = float(m["frames"]) / Engine.physics_ticks_per_second
				m["prompt_gap"] = minf(m["prompt_gap"], _hull_distance(pos))
				m["prompt_y"] = minf(m["prompt_y"], pos.y)
	# Veneen siirto tasaisella nopeudella (vaikuttaa seuraavassa askeleessa)
	if _tow > 0.0:
		boat.velocity = boat.forward() * _tow
		boat.pos += boat.forward() * _tow * dt
		boat._apply_transform()


## Tilanne: kala koukkuun ja mittaus secs sekunnin ajan
func _scenario(sp: String, weight: float, stamina: float, offset: Vector2, depth: float, secs: float, reel: bool, fast: bool, in_holder := false, tow := 0.0, seed_value := 119) -> void:
	_tow = 0.0
	_reset_rod(in_holder)
	_place_boat()
	await _frames(20)
	_hook(sp, weight, offset, depth, stamina, seed_value)
	if reel:
		Input.action_press("reel")
	if fast:
		Input.action_press("reel_fast")
	_reset_measure()
	_tow = tow
	await _frames(1) # ensimmäinen mittaus vasta väsytyksen ensimmäisen askeleen jälkeen
	_measure = true
	await _frames(int(secs * Engine.physics_ticks_per_second))
	_measure = false
	_tow = 0.0
	_release_keys()


## Yhteiset tarkistukset: kala vedessä, rungon ulkopuolella, siiman pää kalassa
func _common(name: String, wave_tolerance := 0.01) -> void:
	_check("%s: kala pysyi koukussa koko mittauksen (%d askelta%s)" % [name, m["frames"], _lost_text()], not m["lost"] and m["frames"] > 30)
	_check("%s: kala enintään −%.2f m korkeudella (ylin %.2f m, malli %.2f m)" % [name, DEPTH, m["max_y"], m["max_node_y"]],
		m["max_y"] <= -DEPTH + 0.01 and m["max_node_y"] <= -DEPTH + 0.01)
	_check("%s: kala vähintään %.2f m aaltopinnan alla (lähimmillään %.3f m)" % [name, DEPTH, -m["max_over_wave"]], m["max_over_wave"] <= -DEPTH + wave_tolerance)
	_check("%s: kala vähintään %.1f m rungon ulkopuolella (lähimmillään %.2f m), ei rungon sisällä (%d askelta)" % [name, GAP, m["min_gap"], m["inside"]], m["min_gap"] >= GAP - 0.02 and m["inside"] == 0)
	_check("%s: siiman pää kalassa (ero %.3f m), siima enintään 0,05 m lyhyempi kuin kärjen ja kalan väli (%.3f m)" % [name, m["max_end"], m["max_short"]],
		m["max_end"] < 0.001 and m["max_short"] <= 0.05)


## Viimeisin pelin viesti, jos kala irtosi kesken mittauksen
func _lost_text() -> String:
	if not m["lost"]:
		return ""
	return ", viesti: %s" % (_messages[-1] if not _messages.is_empty() else "-")


func _prompt(name: String) -> void:
	_check("%s: haavintakehote syttyi (%.1f s), siiman alaraja %.2f m < 3,0 m" % [name, m["prompt_at"], m["min_line"]],
		m["prompt_at"] >= 0.0 and m["prompt_at"] <= 20.0 and m["min_line"] < 3.0)
	_check("%s: kehotteen aikana kala laidan ulkopuolella (lähimmillään %.2f m) ja pinnassa (syvimmillään %.2f m)" % [name, m["prompt_gap"], m["prompt_y"]],
		m["prompt_gap"] > -0.02 and m["prompt_y"] > -1.2)


func _shot(name: String) -> void:
	if _shots == "" or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(_shots)
	for v in [["takaa", PI, 0.35, 6.0], ["sivulta", PI * 0.5, 0.15, 5.0]]:
		main.camera_rig.yaw = boat.yaw + v[1]
		main.camera_rig.pitch = v[2]
		main.camera_rig.distance = v[3]
		await _frames(20)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shots.path_join("%s_%s.png" % [name, v[0]]))
		print("Kuva: %s_%s.png" % [name, v[0]])


func _run() -> void:
	await _frames(30)
	print("Paikka: syvyys %.1f m, vavan kärki %.2f m pinnasta" % [main.lake.depth_at(boat.pos.x, boat.pos.y), f.rod_tip().y])
	var dirs := [["oikea", boat.right()], ["vasen", -boat.right()], ["keula", boat.forward()], ["perä", -boat.forward()]]

	if _shots != "":
		# Kuvat: hauki kelattu veneen viereen oikealta ja perästä
		for d in [dirs[0], dirs[3]]:
			await _scenario("hauki", 3.0, 0.2, d[1] * 8.0, 0.5, 20.0, true, false)
			_common("kuva, hauki %s" % d[0])
			Input.action_press("reel")
			await _shot("hauki_%s" % ("oikea" if d[0] == "oikea" else "pera"))
		_finish()
		return

	# 1) Kelaus veneen viereen neljästä suunnasta: väsynyt hauki ja pirteä ahven
	for d in dirs:
		var name := "väsynyt hauki 3 kg, %s" % d[0]
		await _scenario("hauki", 3.0, 0.2, d[1] * 8.0, 0.5, 20.0, true, false)
		_common(name)
		_prompt(name)
	for d in dirs:
		var name := "pirteä ahven 0,2 kg, %s" % d[0]
		await _scenario("ahven", 0.2, 1.0, d[1] * 8.0, 0.5, 20.0, true, false)
		_common(name)
		_prompt(name)
	await _scenario("hauki", 3.0, 0.2, boat.right() * 8.0, 0.5, 20.0, true, true)
	_common("väsynyt hauki, nopea kelaus")
	_prompt("väsynyt hauki, nopea kelaus")

	# 2) Vene vetää kalaa: 15 m perässä, ei kelausta, käsi- ja telinevapa
	for holder in [false, true]:
		var rod := "telinevapa" if holder else "käsivapa"
		for t in [["ahven 0,3 kg, vene 4 m/s", "ahven", 0.3, 4.0], ["hauki 1,5 kg, vene 7,5 m/s", "hauki", 1.5, 7.5]]:
			var name := "%s, %s" % [t[0], rod]
			await _scenario(t[1], t[2], 0.25, -boat.forward() * 15.0, 0.5, 15.0, false, false, holder, t[3])
			_common(name)
			_check("%s: vene veti kalan pintaan asti (ylin %.2f m)" % [name, m["max_y"]], m["max_y"] > -0.3)

	# 3) Syvällä oleva pirteä kala ei siirry pintarajalle itsestään
	# (made: pelin kalakannassa ei ole kuhaa; mateen tavoitesyvyys on 3,5 m)
	var deep := minf(4.0, main.lake.depth_at(boat.pos.x + boat.right().x * 8.0, boat.pos.y + boat.right().y * 8.0) - 0.5)
	# Siemen 5: kala ei irtoa löysällä siimalla 10 s aikana (irtoaminen on arvontaa)
	await _scenario("made", 1.5, 1.0, boat.right() * 8.0, deep, 10.0, false, false, false, 0.0, 5)
	_check("pirteä made %.1f m syvyydessä, ei kelausta: pysyi syvällä (ylin %.2f m, %d askelta, siima kireällä %d askelta%s)" % [deep, m["max_y"], m["frames"], m["taut"], _lost_text()],
		not m["lost"] and deep > 3.0 and m["taut"] > 30 and m["max_y"] < -2.0)

	# 3b) Kala veneen alla syvällä (PÄÄTÖS 6): runko ei siirrä sitä
	await _scenario("ahven", 1.0, 1.0, boat.right() * 0.3, 1.2, 0.0, false, false)
	f._run_dir = boat.right()
	f._run_intensity = 0.0
	f._run_timer = 1000.0
	_measure = true
	await _frames(180)
	_measure = false
	var moved := Vector2(f._fish_pos.x - m["start"].x, f._fish_pos.z - m["start"].z).length()
	# (kireä siima siirtää kalaa hieman, kun kalastaja kääntää vavan kalaa kohti)
	_check("kala veneen alla 1,2 m syvyydessä: pysyy rungon alla (ääriviivan sisällä %.2f…%.2f m, siirtymä %.2f m, suurin askel %.3f m, %d askelta%s)" % [-m["max_gap_deep"], -m["min_gap_deep"], moved, m["max_step"], m["frames"], _lost_text()],
		not m["lost"] and m["frames"] >= 180 and m["max_gap_deep"] < -0.1 and m["max_step"] < 0.1 and m["max_y"] < _hull_bottom_y())

	# 3c) Väsynyt kala kelataan veneen alta pintaan: ei jää rungon alle eikä sisään
	await _scenario("ahven", 1.0, 0.2, boat.right() * 0.3, 1.2, 12.0, true, false)
	_common("väsynyt ahven veneen alta pintaan")
	_prompt("väsynyt ahven veneen alta pintaan")
	# Suurin sallittu askel: kelaus 0,85 m/s + liuku 0,5 m/s + vavan kärjen liike (+ 0,01 m: kalan oma uinti)
	var step_limit := (Fishing.REEL_SPEED + SLIDE_SPEED) / Engine.physics_ticks_per_second + 0.01
	_check("veneen alta pintaan: ei hyppyä (suurin siirtymä askeleessa %.3f m, ilman vavan kärjen liikettä %.3f m, sallittu %.3f m)" % [m["max_step"], m["max_own_step"], step_limit], m["max_own_step"] <= step_limit)
	_check("veneen alta pintaan: kala nousi pintaan (ylin %.2f m) ja päätyi rungon ulkopuolelle (väli lopussa %.2f m)" % [m["max_y"], _hull_distance(f._fish_pos)],
		m["max_y"] > -0.2 and f._fish_pos.y >= _hull_bottom_y() and _hull_distance(f._fish_pos) >= GAP - 0.02)
	print("veneen alta pintaan: suurin siirtymä yhdessä ruudussa %.2f m kohdassa (rungossa) %s" % [m["max_step"], boat.hull.global_transform.affine_inverse() * (m["step_at"] as Vector3)])

	# 3d) Pirteä hauki pinnassa laidan vieressä ryntää kohti venettä, jarru löysällä:
	# siima ei vedä kalaa, joten vain askeleen lopun varmistus pitää sen rungon ulkopuolella
	_tow = 0.0
	_reset_rod(false)
	_place_boat()
	await _frames(20)
	_hook("hauki", 3.0, boat.right() * 1.2, DEPTH, 1.0, 119)
	f.drag_kg = 0.3
	f._run_dir = -boat.right()
	f._run_intensity = 1.0
	f._run_timer = 1000.0
	_reset_measure()
	await _frames(1)
	_measure = true
	await _frames(int(0.6 * Engine.physics_ticks_per_second))
	_measure = false
	_common("pirteä hauki ryntää laitaa kohti, jarru löysällä")

	# 4) Kova tuuli selällä: kala pysyy aaltopinnan alla myös aallonpohjassa
	# (tuulen suunta, jolla testipaikan pyyhkäisymatka on pisin)
	var hs := 0.0
	var wind_dir := 0.0
	for i in 16:
		Waves.reset(12.0, i * TAU / 16.0)
		if Waves.local_hs(boat.pos) > hs:
			hs = Waves.local_hs(boat.pos)
			wind_dir = i * TAU / 16.0
	_wind(12.0, wind_dir)
	await _frames(60)
	await _scenario("hauki", 3.0, 0.2, boat.right() * 8.0, 0.5, 20.0, true, false)
	_check("kova tuuli 12 m/s: aallokkoa on (Hs %.2f m, syvin aallonpohja kalan kohdalla %.2f m)" % [hs, m["min_wave"]], hs > 0.2 and m["min_wave"] < -0.05)
	_common("kova tuuli 12 m/s, väsynyt hauki", 0.03)
	_wind(3.0, 0.0)
	await _frames(60)

	# 5) Haavinta: väsynyt hauki veneen vieressä, heittonappi kehotteen aikana
	await _scenario("hauki", 3.0, 0.2, boat.right() * 8.0, 0.5, 20.0, true, false)
	_common("haavinta, väsynyt hauki")
	var before: Vector3 = f._fish_pos
	var prompt := f.landing_ready()
	var ev := InputEventAction.new()
	ev.action = "cast"
	ev.pressed = true
	Input.parse_input_event(ev)
	var jump := -1.0
	var landed := false
	for k in 600:
		await _frames(1)
		if f.state == Fishing.State.LANDING and jump < 0.0:
			jump = f._landing_net.fish_position().distance_to(before)
		elif f.state == Fishing.State.LANDED:
			landed = true
			break
		elif f.state == Fishing.State.FIGHT:
			before = f._fish_pos
	ev = InputEventAction.new()
	ev.action = "cast"
	ev.pressed = false
	Input.parse_input_event(ev)
	_check("haavinta: kehote näkyi ja heittonappi aloitti haavinnan", prompt and jump >= 0.0)
	_check("haavinta: kala ei hypännyt haavinnan alussa (%.2f m)" % jump, jump >= 0.0 and jump <= 0.3)
	_check("haavinta päättyi: kala veneessä (tila %s)" % Fishing.State.keys()[f.state], landed)
	_finish()

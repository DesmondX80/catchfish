extends Node
## Kaikuluotaimen ja järven syvyyksien testi:
##   godot --headless --fixed-fps 30 -- --day=180 --sonartest [--sonartest-shots=KANSIO]
## Syvyydet tulevat korkeuskäyristä (syvin kohta noin 7 m), pohjan laatu
## vaihtelee (kova, muta, kasvillisuus) ja kalasta piirtyy kaari, kun vene
## ajaa sen yli, ja myös paikallaan olevan veneen alla (kala uiskentelee).
## Kuvat vaativat ikkunan.

var main: Node
var _log: Array[String] = []
var _step := 0
var _t := 0.0
var _shots := ""
var _fish := -1
var _start := Vector2.ZERO
var _dir := Vector2.ZERO
var _spots: Array[Vector2] = [] # kuvauspaikat pohjatyypeittäin
var _shot := 0


func _ready() -> void:
	main = get_parent()
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sonartest-shots="):
			_shots = arg.split("=")[1]
	for f in main.population.fish:
		f["wary"] = 1.0e9


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _next() -> void:
	_step += 1
	_t = 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	var lake: LakeData = main.lake
	var boat: Boat = main.boat
	match _step:
		0:
			_check_lake(lake)
			_prepare_pass(lake)
			_next()
		1:
			# Vene ajaa tasaisesti kalan yli 1 m/s
			boat.pos = _start + _dir * _t
			boat.velocity = Vector2.ZERO
			if _t > 12.0:
				_check_arc("vene ajaa kalan yli")
				if _shots != "":
					get_viewport().get_texture().get_image().save_png(_shots.path_join("luotain-kalakaari.png"))
				_next()
		2:
			# Vene paikallaan kalan kohdalla: uiskenteleva kala piirtää kaaria
			boat.pos = _start + Vector2(6.0, 0.0)
			boat.velocity = Vector2.ZERO
			if _t > 26.0:
				_check_sway()
				if _shots != "":
					get_viewport().get_texture().get_image().save_png(_shots.path_join("luotain-paikallaan.png"))
				_next()
		3:
			if _shots == "" or _shot >= _spots.size():
				_finish()
				return
			# Paikallaan eri pohjilla: luotain täyttyy saman pohjan kuvalla
			boat.pos = _spots[_shot] + Vector2(_t * 0.6, 0.0)
			boat.velocity = Vector2.ZERO
			if _t > 42.0:
				get_viewport().get_texture().get_image().save_png(_shots.path_join("luotain-pohja-%s.png" % ["kova", "muta", "kasvillisuus"][_shot]))
				_shot += 1
				_t = 0.0


func _check_lake(lake: LakeData) -> void:
	var deepest := 0.0
	var counts := [0, 0, 0]
	var samples := 0
	_spots = [Vector2.INF, Vector2.INF, Vector2.INF]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var size := lake.world_size()
	for i in 6000:
		var p := Vector2(lake.origin_x + rng.randf() * size.x, lake.origin_z + rng.randf() * size.y)
		if not lake.is_water(p.x, p.y):
			continue
		samples += 1
		deepest = maxf(deepest, lake.depth_at(p.x, p.y))
		var b := lake.bottom_at(p.x, p.y)
		counts[b] += 1
		# Kuvauspaikka: pohja pysyy samana 25 m matkan
		if _spots[b] == Vector2.INF and lake.depth_at(p.x, p.y) > 1.5:
			var same := true
			for s in range(0, 26, 5):
				same = same and lake.bottom_at(p.x + s, p.y) == b and lake.is_water(p.x + s, p.y)
			if same:
				_spots[b] = p
	_check("syvin kohta noin 7 m (%.1f m)" % lake.max_depth, lake.max_depth > 6.5 and lake.max_depth <= 7.05)
	_check("syvyydet eivät ole enää arvioita", not lake.depth_estimated)
	_check("pohjan laatu vaihtelee: kova %d, muta %d, kasvillisuus %d / %d" % [counts[0], counts[1], counts[2], samples],
		counts[0] > samples * 0.05 and counts[1] > samples * 0.05 and counts[2] > samples * 0.03)


## Kala keskelle 2 m syvyyteen, ja vene ajaa sen yli suoraa linjaa
func _prepare_pass(lake: LakeData) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var size := lake.world_size()
	for i in 20000:
		var p := Vector2(lake.origin_x + rng.randf() * size.x, lake.origin_z + rng.randf() * size.y)
		var ok := lake.depth_at(p.x, p.y) > 4.0
		for s in range(-8, 9, 2):
			ok = ok and lake.depth_at(p.x + s, p.y) > 3.5
		if ok:
			_start = p - Vector2(6.0, 0.0)
			_dir = Vector2.RIGHT
			break
	# Muut kalat kauas, yksi iso kala ylityskohtaan
	for i in main.population.fish.size():
		var f: Dictionary = main.population.fish[i]
		if _fish < 0 and f["weight"] > 1.0:
			_fish = i
			f["pos"] = _start + Vector2(6.0, 0.0)
			f["depth"] = 2.0
		elif f["pos"].distance_to(_start) < 60.0:
			f["pos"] += Vector2(200.0, 0.0)
		main.population._update_grid(i)
	main.population.set_process(false) # kalat pysyvät paikallaan


## Kalan kaiut: vinoetäisyys pienin kalan kohdalla ja kasvaa molempiin suuntiin
func _check_arc(what: String) -> void:
	var sounder: EchoSounder = main.hud.sounder
	var ranges := []
	for c in sounder._columns:
		for e in c["fish"]:
			ranges.append(e[0])
	if ranges.size() < 5:
		_check("%s: kalasta tuli kaikuja (%d)" % [what, ranges.size()], false)
		return
	var low: float = ranges.min()
	var mid := ranges.find(low)
	var arc: bool = ranges[0] > low + 0.1 and ranges[-1] > low + 0.1 and mid > 0 and mid < ranges.size() - 1
	_check("%s: kalasta piirtyi kaari: %d kaikua, %.2f m → %.2f m → %.2f m" % [what, ranges.size(), ranges[0], low, ranges[-1]], arc and low >= 1.98 and low < 2.5) # kala 2 m syvyydessä, uiskentelee keilan poikki


## Paikallaan: kala lipuu keilan läpi, joten kaiun etäisyys vaihtelee
## (suoraan alla 2 m, reunalla kauempana) eikä piirry tasaiseksi viivaksi
func _check_sway() -> void:
	var sounder: EchoSounder = main.hud.sounder
	var ranges := []
	for c in sounder._columns.slice(-150):
		for e in c["fish"]:
			ranges.append(e[0])
	var ok: bool = ranges.size() > 10 and ranges.min() < 2.2 and ranges.max() > ranges.min() + 0.5
	_check("vene paikallaan: kala lipuu keilan läpi kaarina (%d kaikua, %.2f–%.2f m)" % [ranges.size(), ranges.min() if ranges.size() > 0 else 0.0, ranges.max() if ranges.size() > 0 else 0.0], ok)


func _finish() -> void:
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

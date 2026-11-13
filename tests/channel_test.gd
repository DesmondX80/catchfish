extends Node
## Kodan ruopatun väylän testi (CATCHFISH-101):
##   godot --headless --fixed-fps 30 -- --day=180 --channeltest
## Väylä on järviaineistossa (lake.json: channels) ja alkaa kodan laituripaikalta
## ja päättyy syvään veteen. Syvyys keskilinjalla ja sen sivuilla, pohjan
## kaltevuus väylän alueella, laituripaikka ennallaan ja pelaajan ajo
## laiturilta väylän päähän täydellä kaasulla ilman potkurin pohjakosketusta
## ja matalan varoitusta.

const CENTER_MIN := 1.4 # m keskilinjalla
const SIDE3_MIN := Boat.SHALLOW_WARNING # m 3 m keskilinjan sivuilla
const SIDE5_MIN := Boat.PROP_DEPTH # m 5 m keskilinjan sivuilla
const SIDE_FROM := 10.0 # m laituripaikasta: sivujen syvyys mitataan tästä alkaen (päätös 7)
const PROP_MARGIN := 0.02 # m: perän kohdalla vähintään Boat.PROP_DEPTH + tämä
const SLOPE_MAX := 0.2 # pohjan kaltevuus vierekkäisten solujen välillä
const SLOPE_RADIUS := 15.0 # m keskilinjasta
const BANK_DIST := 4.0 # m: rantatörmä (rantaan enintään tämän verran) ei muutu
const BANK_MAX := 0.7 # m: törmäsolun suurin syvyys (luonnostaan enintään 0,63 m)
const DRIVE_LIMIT := 240.0 # s laiturilta väylän päähän

var main: Node
var lake: LakeData
var _log: Array[String] = []
var _messages: Array[String] = []
var _sounds: Array[String] = []
var _line := PackedVector2Array()


func _ready() -> void:
	main = get_parent()
	TestUtil.calm_weather(main) # tyyni, pysäytetty sää: tulos ei riipu arvotusta säästä
	lake = main.lake
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	main.boat.message.connect(func(text): _messages.append(text))
	main.boat.sound_event.connect(func(sound, _at): _sounds.append(sound))
	_run.call_deferred()


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _finish() -> void:
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)


func _run() -> void:
	_check_start()
	if not _check_data():
		_finish()
		return
	_check_depths()
	_check_slope()
	await _drive()
	_finish()


## e) Laituripaikka ennallaan
func _check_start() -> void:
	var s: Dictionary = lake.starts[0]
	_check("kodan laituripaikka ennallaan (%s: x %.1f, z %.1f, suunta %.1f°, laituri %.1f m)" % [s["id"], s["x"], s["z"], s["yaw_deg"], s["dock_length"]],
		s["id"] == "kota" and is_equal_approx(s["x"], -1314.0) and is_equal_approx(s["z"], 990.0) and is_equal_approx(s["yaw_deg"], 41.2) and is_equal_approx(s["dock_length"], 14.0))


## a) Väylä aineistossa: alkaa kodan laituripaikalta ja päättyy syvään veteen
func _check_data() -> bool:
	var channel: Dictionary = {}
	for ch in lake.channels:
		if ch.get("dock", "") == "kota":
			channel = ch
	_check("järviaineistossa on kodan väylä (%d väylää)" % lake.channels.size(), not channel.is_empty())
	if channel.is_empty():
		return false
	for p in channel["points"]:
		_line.append(Vector2(p[0], p[1]))
	var dock := Vector2(lake.starts[0]["x"], lake.starts[0]["z"])
	var end := _line[_line.size() - 1]
	_check("väylä alkaa laituripaikalta (%.1f m)" % _line[0].distance_to(dock), _line[0].distance_to(dock) <= 10.0)
	_check("väylä päättyy syvään veteen (%.2f m, rantaan %.0f m)" % [lake.depth_at(end.x, end.y), lake.shore_distance(end.x, end.y)],
		lake.depth_at(end.x, end.y) >= 1.5 and lake.shore_distance(end.x, end.y) >= 15.0)
	_check("väylän pituus %.0f m" % _length(), _length() > 400.0 and _length() < 650.0)
	return true


func _length() -> float:
	var length := 0.0
	for i in _line.size() - 1:
		length += _line[i].distance_to(_line[i + 1])
	return length


## b) Syvyys keskilinjalla 1 m välein ja sen sivuilla
func _check_depths() -> void:
	var worst := [INF, INF, INF]
	var at := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	var total := 0.0
	var n := 0
	var along := 0.0
	for i in _line.size() - 1:
		var a := _line[i]
		var b := _line[i + 1]
		var steps := int(a.distance_to(b))
		var side := (b - a).normalized().orthogonal()
		for s in steps + (1 if i == _line.size() - 2 else 0):
			var p := a.lerp(b, float(s) / a.distance_to(b))
			var d := lake.depth_at(p.x, p.y)
			total += d
			n += 1
			var probes := [[p], [p + side * 3.0, p - side * 3.0], [p + side * 5.0, p - side * 5.0]]
			# Laituripaikka on 8 m rannasta: sivut vasta SIDE_FROM metristä alkaen
			for k in (3 if along + s >= SIDE_FROM else 1):
				for q: Vector2 in probes[k]:
					var dq := lake.depth_at(q.x, q.y)
					if dq < worst[k]:
						worst[k] = dq
						at[k] = q
		along += a.distance_to(b)
	_check("keskilinjalla vähintään %.1f m (matalin %.2f m kohdassa %.0f, %.0f)" % [CENTER_MIN, worst[0], at[0].x, at[0].y], worst[0] >= CENTER_MIN)
	_check("3 m sivuilla (%.0f m:stä laiturista) vähintään %.1f m (matalin %.2f m kohdassa %.0f, %.0f)" % [SIDE_FROM, SIDE3_MIN, worst[1], at[1].x, at[1].y], worst[1] >= SIDE3_MIN)
	_check("5 m sivuilla (%.0f m:stä laiturista) vähintään %.1f m (matalin %.2f m kohdassa %.0f, %.0f)" % [SIDE_FROM, SIDE5_MIN, worst[2], at[2].x, at[2].y], worst[2] >= SIDE5_MIN)
	var mean := total / maxi(n, 1)
	_check("väylän pohja 1,5 m (keskilinjan keskisyvyys %.3f m)" % mean, mean >= 1.45 and mean <= 1.55)


## c) Ei pystyseinää: väylän alueella vierekkäisten vesisolujen korkeusero enintään 0,8 m
func _check_slope() -> void:
	var lo := Vector2(INF, INF)
	var hi := -lo
	for p in _line:
		lo = lo.min(p)
		hi = hi.max(p)
	var c0 := floori((lo.x - SLOPE_RADIUS - lake.origin_x) / lake.cell_size)
	var c1 := ceili((hi.x + SLOPE_RADIUS - lake.origin_x) / lake.cell_size)
	var r0 := floori((lo.y - SLOPE_RADIUS - lake.origin_z) / lake.cell_size)
	var r1 := ceili((hi.y + SLOPE_RADIUS - lake.origin_z) / lake.cell_size)
	var worst := 0.0
	var at := Vector2.ZERO
	var bank_deepest := 0.0
	var bank_at := Vector2.ZERO
	var bank_cells := 0
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			if not lake.cell_is_water(c, r) or not _near_line(_cell_point(c, r), SLOPE_RADIUS):
				continue
			if lake.cell_shore_distance(c, r) <= BANK_DIST:
				bank_cells += 1
				if -lake.cell_height(c, r) > bank_deepest:
					bank_deepest = -lake.cell_height(c, r)
					bank_at = _cell_point(c, r)
			for nb in [Vector2i(c + 1, r), Vector2i(c, r + 1)]:
				if not lake.cell_is_water(nb.x, nb.y) or not _near_line(_cell_point(nb.x, nb.y), SLOPE_RADIUS):
					continue
				var slope := absf(lake.cell_height(c, r) - lake.cell_height(nb.x, nb.y)) / lake.cell_size
				if slope > worst:
					worst = slope
					at = _cell_point(c, r)
	_check("väylän pohjassa ei pystyseinää (jyrkin kaltevuus %.3f kohdassa %.0f, %.0f)" % [worst, at.x, at.y], worst <= SLOPE_MAX + 1e-4)
	# Rantatörmä ennallaan (päätös 6): törmäsolut ovat luonnostaan alle BANK_MAX
	# syviä (ennen ruoppausta enintään 0,63 m), ruopattu törmä olisi syvempi
	_check("rantatörmä ennallaan (%d törmäsolua, syvin %.2f m kohdassa %.0f, %.0f)" % [bank_cells, bank_deepest, bank_at.x, bank_at.y], bank_cells > 0 and bank_deepest <= BANK_MAX)


## Solun korkeuden kohta (LakeData.height_at: solun kulma)
func _cell_point(c: int, r: int) -> Vector2:
	return Vector2(lake.origin_x + c * lake.cell_size, lake.origin_z + r * lake.cell_size)


func _near_line(p: Vector2, radius: float) -> bool:
	for i in _line.size() - 1:
		if Geometry2D.get_closest_point_to_segment(p, _line[i], _line[i + 1]).distance_to(p) <= radius:
			return true
	return false


## Piste ja suunta murtoviivalla line matkan s kohdalla
static func _at(line: PackedVector2Array, s: float) -> Array:
	for i in line.size() - 1:
		var seg := line[i].distance_to(line[i + 1])
		if s <= seg or i == line.size() - 2:
			var dir := (line[i + 1] - line[i]).normalized()
			return [line[i] + dir * minf(s, seg), dir]
		s -= seg
	return [line[line.size() - 1], Vector2.UP]


## d) Pelaajan vene laiturista väylän läpi moottorilla täydellä kaasulla:
## laiturissa moottori käyntiin ja vaihde päälle, sitten paikka ja suunta
## ajolinjaa pitkin joka fysiikka-askeleella. Ajolinja: veneen aloituspaikka
## (Boat.setup siirtää rungon irti kannesta), loiva kaarros pohjoisen kautta
## kannen pään ohi (aloitussuunnassa keula osuisi kannen päähän) ja sitten
## väylän keskilinja. Rantatörmä laiturin vieressä on ennallaan (päätös 6),
## joten laiturissa kerran tuleva matalan varoitus sallitaan, mutta potkuri ei
## saa osua pohjaan missään eikä väylällä (SIDE_FROM metristä) varoiteta.
func _drive() -> void:
	var boat: Boat = main.boat
	main.weather.wind_base = 0.0
	main.weather.gust = 0.0
	var start := boat.pos
	var start_yaw := boat.yaw
	var fwd := boat.forward()
	var stern := start - fwd * Boat.LENGTH * 0.5
	_check("laituripaikassa vähintään 1,4 m (%.2f m)" % lake.depth_at(start.x, start.y), lake.depth_at(start.x, start.y) >= 1.4)
	_check("perän kohdalla laiturissa vähintään %.2f m (%.3f m)" % [Boat.PROP_DEPTH + PROP_MARGIN, lake.depth_at(stern.x, stern.y)], lake.depth_at(stern.x, stern.y) >= Boat.PROP_DEPTH + PROP_MARGIN)
	var path := PackedVector2Array()
	boat.velocity = Vector2.ZERO
	boat.yaw_rate = 0.0
	boat.prop_damage = 0.0
	boat.motor_running = true
	_messages.clear()
	_sounds.clear()
	# Laiturissa vaihde päälle pienellä kaasulla (vene pidetään paikallaan)
	for i in 60:
		await get_tree().physics_frame
		boat.throttle = 0.3
		boat.pos = start
		boat.yaw = start_yaw
		boat.velocity = Vector2.ZERO
		boat.yaw_rate = 0.0
	var dock_warned := _messages.any(func(m): return m.begins_with("Matalaa"))
	# Laiturista irti aloitussuunnassa täydellä kaasulla (vene liukuu kannen
	# pään ohi), perän syvyys joka askeleella
	var shallowest := INF # perä koko matkalla
	var shallowest_at := Vector2.ZERO
	var t := 0
	while boat.pos.distance_to(start) < 4.0 and t < 10 * Engine.physics_ticks_per_second:
		await get_tree().physics_frame
		boat.throttle = 1.0
		boat.yaw = start_yaw
		boat.yaw_rate = 0.0
		var b := boat.pos - boat.forward() * Boat.LENGTH * 0.5
		if lake.depth_at(b.x, b.y) < shallowest:
			shallowest = lake.depth_at(b.x, b.y)
			shallowest_at = b
		t += 1
	_check("laiturista irti aloitussuunnassa (%.1f m, %.1f s)" % [boat.pos.distance_to(start), float(t) / Engine.physics_ticks_per_second], boat.pos.distance_to(start) >= 4.0)
	path = PackedVector2Array([boat.pos])
	for p in _line:
		if p.distance_to(start) > 10.0:
			path.append(p)
	var length := 0.0
	for i in path.size() - 1:
		length += path[i].distance_to(path[i + 1])
	var along := 0.0
	var steps := 0
	var channel_min := INF # perä väylällä (SIDE_FROM metristä)
	var channel_messages := -1
	var placed := Vector2.INF
	var dir := Vector2.ZERO
	# physics_frame tulee ennen veneen fysiikka-askelta: edellisen askeleen
	# siirtymä luetaan seuraavan alussa
	while along < length - 0.5 and steps < DRIVE_LIMIT * Engine.physics_ticks_per_second:
		await get_tree().physics_frame
		if placed != Vector2.INF:
			along += maxf((boat.pos - placed).dot(dir), 0.0)
			steps += 1
		if channel_messages < 0 and along >= SIDE_FROM:
			channel_messages = _messages.size()
		boat.throttle = 1.0
		var here: Array = _at(path, along)
		dir = here[1]
		placed = here[0]
		boat.pos = placed
		boat.yaw = atan2(-dir.x, -dir.y)
		boat.yaw_rate = 0.0
		boat.velocity = dir * maxf(boat.velocity.dot(dir), 0.0)
		var back := boat.pos - dir * Boat.LENGTH * 0.5
		var d := lake.depth_at(back.x, back.y)
		if d < shallowest:
			shallowest = d
			shallowest_at = back
		if along >= SIDE_FROM:
			channel_min = minf(channel_min, d)
	var seconds := float(steps) / Engine.physics_ticks_per_second
	_check("ajettiin väylän päähän (%.0f m, %.0f s)" % [along, seconds], along >= length - 0.5)
	_check("perän alla koko matkan vähintään %.2f m (matalin %.3f m kohdassa %.1f, %.1f)" % [Boat.PROP_DEPTH + PROP_MARGIN, shallowest, shallowest_at.x, shallowest_at.y], shallowest >= Boat.PROP_DEPTH + PROP_MARGIN)
	_check("väylällä perän alla vähintään %.1f m (matalin %.2f m)" % [Boat.SHALLOW_WARNING, channel_min], channel_min >= Boat.SHALLOW_WARNING)
	var later := _messages.slice(maxi(channel_messages, 0))
	_check("väylällä ei matalan varoitusta (laiturissa %s)" % ("varoitettiin" if dock_warned or _messages.slice(0, maxi(channel_messages, 0)).any(func(m): return m.begins_with("Matalaa")) else "ei varoitettu"), not later.any(func(m): return m.begins_with("Matalaa")))
	_check("potkuri ei osunut pohjaan (ääni)", not "prop_strike" in _sounds)
	_check("ei potkuriosumaviestiä", not _messages.any(func(m): return m.begins_with("Potkuri osui")))
	_check("potkuri ehjä (vaurio %d %%)" % roundi(boat.prop_damage * 100.0), boat.prop_damage == 0.0)

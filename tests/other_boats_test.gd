extends Node
## Muiden veneiden testi:
##   godot --headless --fixed-fps 30 -- --day=180 --otherboatstest
##   godot --headless --fixed-fps 30 -- --day=40 --otherboatstest (jää: ei veneitä)
## Reitit laiturilta toiselle ja kalapaikalle (syvyys, laiturit), peräaallon
## keinunta pelaajan veneessä (saapuminen, etäisyys, suunta, soutuvene),
## törmäys vieraaseen veneeseen, väistö, ilmestymisen ehdot ja moottorin ääni.

var main: Node
var ob: OtherBoats
var boat: Boat
var lake: LakeData
var _log: Array[String] = []
var _sounds: Array[String] = []
var _messages: Array[String] = []
## Testipaikka avovedessä: piste ja suunta, jonka sivuilla on syvää vettä
var _spot := Vector2.ZERO
var _dir := Vector2.UP


func _ready() -> void:
	main = get_parent()
	main.hud.set_paused_view(false)
	main.birds.auto_spawn = false
	ob = main.other_boats
	boat = main.boat
	lake = main.lake
	boat.sound_event.connect(func(sound, _at): _sounds.append(sound))
	boat.message.connect(func(text): _messages.append(text))
	_run.call_deferred()


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _finish() -> void:
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)


func _frame() -> void:
	await get_tree().physics_frame


func _calm() -> void:
	var w: Weather = main.weather
	w.set_process(false) # tuuli pysyy tyynenä koko testin
	w.wind_base = 0.0
	w.gust = 0.0
	w._wind_target = 0.0
	w._gust_timer = 999.0
	w.rain = 0.0
	w._rain_target = 0.0
	w._change_in = 1e6
	Waves.reset(0.0, w.wind_direction)
	main.sky.minutes = 12.0 * 60.0


func _run() -> void:
	if ob.winter:
		await _winter()
		_finish()
		return
	_calm()
	ob._rng.seed = 68 # toistettavat paikat ja reitit
	_check("ei satunnaisia veneitä testiajossa", not ob.auto_spawn and ob.boats.is_empty())
	var t := 0
	while not ob.grid_ready and t < 900:
		await _frame()
		t += 1
	_check("reittiruudukko valmis %d fysiikka-askeleessa" % t, ob.grid_ready)
	if not ob.grid_ready:
		_finish()
		return
	_find_spot()
	await _row_route()
	await _wake_passes()
	await _collisions()
	await _avoidance()
	await _conditions()
	_finish()


## Avovesipaikka, jonka molemmin puolin 60 m:n päässä kulkee 260 m syvää vettä
func _find_spot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 68
	for i in 4000:
		var p := ob._deep_cell(OtherBoats.Kind.MOTOR)
		var dir := Vector2.from_angle(rng.randi_range(0, 7) * PI / 4.0)
		var side := Vector2(-dir.y, dir.x)
		var ok := true
		for l in [-60.0, -20.0, 0.0, 10.0, 20.0, 60.0]:
			ok = ok and ob._line_clear(OtherBoats.Kind.MOTOR, p + side * l - dir * 150.0, p + side * l + dir * 150.0)
		for s in lake.starts.size():
			ok = ok and p.distance_to(ob.berth_of(s)) > 400.0
		if ok:
			_spot = p
			_dir = dir
			_check("testipaikka avovedessä (%.0f, %.0f)" % [p.x, p.y], true)
			return
	_check("testipaikka avovedessä", false)


## Pelaajan vene paikalleen suuntaan heading (keula), rungon keinunta nollaan
func _place_player(at: Vector2, heading: Vector2) -> void:
	boat.pos = at
	boat.yaw = atan2(-heading.x, -heading.y)
	boat.velocity = Vector2.ZERO
	boat.yaw_rate = 0.0
	boat.motor_running = false
	boat.throttle = 0.0
	boat._bump_cooldown = 0.0
	boat.hull.rotation = Vector3.ZERO
	boat.hull.position = Vector3.ZERO
	boat._apply_transform()
	boat.snap_pose()


func _clear_boats() -> void:
	for b in ob.boats.duplicate():
		ob.remove(b)


## Syvyys rungon kolmesta kohdasta (keula, keskikohta, perä)
func _hull_depth(b: OtherBoat) -> float:
	var f := b.forward() * Boat.LENGTH * 0.45
	return minf(lake.depth_at(b.pos.x + f.x, b.pos.y + f.y), minf(lake.depth_at(b.pos.x, b.pos.y), lake.depth_at(b.pos.x - f.x, b.pos.y - f.y)))


## Seurataan venettä, kunnes se on tilassa goal: syvyys, maa ja laiturit joka
## askeleella. Laituriin tullut vene poistetaan heti, kun pelaaja ei näe sitä.
func _follow(b: OtherBoat, goal: int, limit_s: float, deep_min: float, label: String, each := Callable()) -> bool:
	var berths := [b.route[0], b.route[b.route.size() - 1]]
	var steps := 0
	var worst_deep := INF
	var worst := INF
	var contact := 0.0
	var arrived := false
	while steps < limit_s * 60.0:
		await _frame()
		steps += 1
		if not is_instance_valid(b):
			arrived = goal == OtherBoat.State.DOCKED # laiturissa ollut vene katosi
			break
		contact = b.dock_push_max
		var d := _hull_depth(b)
		worst = minf(worst, d)
		if b.pos.distance_to(berths[0]) > OtherBoats.APPROACH_RADIUS and b.pos.distance_to(berths[1]) > OtherBoats.APPROACH_RADIUS:
			worst_deep = minf(worst_deep, d)
		if each.is_valid():
			each.call()
		if b.state == goal:
			arrived = true
			break
	_check("%s: perillä %.0f s:ssa" % [label, steps / 60.0], arrived)
	_check("%s: ei maalla eikä matalikolla (matalin %.2f m rungon kohdalla)" % [label, worst], worst >= Boat.DRAFT)
	if deep_min > 0.0:
		_check("%s: syvällä osuudella vähintään %.1f m (matalin %.2f m)" % [label, deep_min, worst_deep], worst_deep >= deep_min)
	_check("%s: ei laiturin kannen alla (syvin kosketus %.3f m)" % [label, contact], contact <= 0.05)
	return arrived


## 1. Moottorivene laiturilta toiselle laiturille, moottorin ääni
func _motor_route() -> void:
	var docks := ob.usable_docks(OtherBoats.Kind.MOTOR)
	var ids := docks.map(func(i): return lake.starts[i]["id"])
	_check("moottoriveneiden laiturit %s: uimalaituri ja veneenlasku, ei kotaa" % str(ids), ids.size() == 2 and "uimalaituri" in ids and "veneenlasku" in ids)
	if docks.size() < 2:
		return
	var route := ob.dock_route(OtherBoats.Kind.MOTOR, docks[0], docks[1])
	_check("reitti laiturilta %d laiturille %d (%d pistettä)" % [docks[0], docks[1], route.size()], route.size() >= 2)
	if route.is_empty():
		return
	var length := 0.0
	for i in route.size() - 1:
		length += route[i].distance_to(route[i + 1])
	_place_player(_spot, _dir)
	main.audio.log_enabled = true
	var b := ob.spawn(OtherBoats.Kind.MOTOR, route, docks[1], ob.lake_berth_yaw(docks[0]))
	var heard := [false]
	await _follow(b, OtherBoat.State.DOCKED, length / 1.4 + 120.0, Boat.PROP_DEPTH, "moottorivene %.0f m" % length, func():
		heard[0] = heard[0] or (b._motor_sound.playing and b.velocity.length() > 2.0))
	_check("liikkuvan moottoriveneen moottori soi", heard[0])
	_check("ääniloki kirjaa vieraan moottorin", main.audio.log_lines.any(func(l): return l.contains("loop_start motor_loop (vieras vene)")))
	main.audio.log_enabled = false
	_clear_boats()


## 1b. Soutuvene laiturilta kalapaikalle, kalastaa ja palaa laiturille
func _row_route() -> void:
	var docks := ob.usable_docks(OtherBoats.Kind.ROW)
	_check("soutuveneiden laiturit %s" % str(docks), not docks.is_empty())
	if docks.is_empty():
		return
	var from: int = docks[0]
	var route := PackedVector2Array()
	for i in 5: # kodalta useimmat kalapaikat ovat salmien takana kaukana: arvotaan uudelleen
		route = ob.row_route(from) if route.is_empty() else route
	_check("soutureitti laiturilta %d kalapaikalle (%.0f m)" % [from, OtherBoats.route_length(route)], not route.is_empty() and OtherBoats.route_length(route) <= OtherBoats.ROW_ROUTE_MAX)
	if route.is_empty():
		return
	_place_player(_spot, _dir)
	var b := ob.spawn(OtherBoats.Kind.ROW, route, -1, ob.lake_berth_yaw(from))
	b.home_dock = from
	var limit := OtherBoats.route_length(route) / 1.0 + 60.0 # soutuvauhti salmissa noin 1,2 m/s
	await _follow(b, OtherBoat.State.FISHING, limit, 0.0, "soutuvene kalapaikalle")
	_check("kalapaikalla ankkurissa ja vapa ulkona", b.anchored and b.crew.pose == OtherBoatCrew.Pose.FISHING)
	b.fish_time = 0.0
	await _frame()
	await _frame()
	_check("kalastuksen jälkeen kotiin lähtölaiturille", b.dock == from)
	await _follow(b, OtherBoat.State.DOCKED, OtherBoats.route_length(b.route) / 1.0 + 60.0, 0.0, "soutuvene laiturille")
	_clear_boats()


## 2–3. Peräaalto: ohiajo sivulta etäisyydellä lateral
## Palauttaa [suurin kallistus °, suurin keinunta (kallistus tai nyökkäys) °]
func _pass(kind: int, lateral: float, bow_on: bool, label: String) -> Array:
	var side := Vector2(-_dir.y, _dir.x)
	# Aallot kulkevat 35°:n kulmassa ajosuunnasta poispäin vanasta
	var n := _dir * cos(OtherBoats.KELVIN_DIVERGENT) - side * sin(OtherBoats.KELVIN_DIVERGENT)
	_place_player(_spot, n if bow_on else Vector2(-n.y, n.x))
	var start := -130.0 if kind == OtherBoats.Kind.MOTOR else -40.0
	var route := PackedVector2Array([_spot + side * lateral + _dir * start, _spot + side * lateral + _dir * 150.0])
	var b := ob.spawn(kind, route)
	b.hold_at_end = true
	var cruise := OtherBoat.MOTOR_CRUISE if kind == OtherBoats.Kind.MOTOR else OtherBoat.ROW_CRUISE
	b.velocity = _dir * cruise
	if kind == OtherBoats.Kind.MOTOR:
		b.motor_running = true
		b.throttle = OtherBoat.CRUISE_THROTTLE
		b.state = OtherBoat.State.TRAVEL
	var t := 0.0
	var passed_at := INF
	var onset := INF
	var before_pass := 0.0
	var max_roll := 0.0
	var max_tilt := 0.0
	var waves_db_before: float = main.audio._waves.volume_db
	var waves_db_max := -80.0
	var after30 := INF
	var limit := 150.0 if kind == OtherBoats.Kind.MOTOR else 90.0
	while t < limit:
		await _frame()
		t += 1.0 / 60.0
		var roll := rad_to_deg(absf(boat.hull.rotation.z))
		var pitch := rad_to_deg(absf(boat.hull.rotation.x))
		var along := (b.pos - _spot).dot(_dir)
		if along < 0.0:
			before_pass = maxf(before_pass, maxf(roll, pitch))
		elif passed_at == INF:
			passed_at = t
		if maxf(roll, pitch) > 0.2 and onset == INF:
			onset = t
		max_roll = maxf(max_roll, roll)
		max_tilt = maxf(max_tilt, maxf(roll, pitch))
		waves_db_max = maxf(waves_db_max, main.audio._waves.volume_db)
		if onset != INF and t >= onset + 30.0:
			after30 = maxf(roll, pitch)
			break
	var speed := cruise
	var arrive := passed_at + (lateral - 0.6) / (speed * Wake.KELVIN_SPREAD)
	_check("%s: ennen ohitusta keinunta alle 0,2° (%.2f°)" % [label, before_pass], before_pass < 0.2)
	if kind == OtherBoats.Kind.MOTOR:
		_check("%s: keinunta alkaa V-haaran saapuessa (%.1f s, laskettu %.1f s)" % [label, onset, arrive], onset >= arrive - 1.5 and onset > passed_at)
		_check("%s: 30 s:n kuluttua alle 0,2° (%.2f°)" % [label, after30], after30 < 0.2)
	if kind == OtherBoats.Kind.MOTOR and lateral <= 20.0 and not bow_on:
		_check("%s: aaltoääni voimistuu (%.1f -> %.1f dB)" % [label, waves_db_before, waves_db_max], waves_db_max > waves_db_before + 3.0)
	_check("%s: pelaajan vene ei siirtynyt (%.2f m)" % [label, boat.pos.distance_to(_spot)], boat.pos.distance_to(_spot) < 0.05)
	_clear_boats()
	return [max_roll, max_tilt]


func _wake_passes() -> void:
	_calm()
	var near := await _pass(OtherBoats.Kind.MOTOR, 20.0, false, "ohiajo 20 m kylki aaltoon")
	_check("20 m: suurin kallistus yli 2° (%.1f°)" % near[0], near[0] > 2.0)
	var bow := await _pass(OtherBoats.Kind.MOTOR, 20.0, true, "ohiajo 20 m keula aaltoon")
	_check("kylki aaltoon keinuu enemmän kuin keula aaltoon (%.1f° > %.1f°)" % [near[1], bow[1]], near[1] > bow[1])
	var far := await _pass(OtherBoats.Kind.MOTOR, 60.0, false, "ohiajo 60 m")
	_check("60 m keinuttaa vähemmän kuin 20 m (%.1f° < %.1f°)" % [far[0], near[0]], far[0] < near[0] and far[0] > 0.0)
	var row := await _pass(OtherBoats.Kind.ROW, 10.0, false, "soutuvene 10 m")
	_check("soutuvene ei keinuta (%.2f° < 0,5°)" % row[0], row[0] < 0.5)


## 4. Törmäys: pelaaja ajaa täydellä kaasulla vieraaseen veneeseen
## mode: "push" suoraan kylkeen (pelaaja työntää venettä), "bow" keula keulaa vasten,
## "slide" viistosti (veneet liukuvat ohi)
func _ram(label: String, other_heading: Vector2, approach: Vector2, mode: String, anchored := false) -> void:
	_clear_boats()
	var target := _spot
	var kind := OtherBoats.Kind.ROW if anchored else OtherBoats.Kind.MOTOR
	var b := ob.spawn(kind, PackedVector2Array([target]), -1, atan2(-other_heading.x, -other_heading.y))
	if anchored:
		b.start_fishing(999.0)
	_place_player(target - approach * 14.0, approach)
	boat.motor_running = true
	boat.throttle = 1.0
	_sounds.clear()
	_messages.clear()
	var start_other := b.pos
	var worst := 0.0
	var contact_t := INF
	var toward := []
	var before_hit := 0.0
	var at_hit := INF
	var t := 0.0
	while t < 9.0:
		await _frame()
		t += 1.0 / 60.0
		worst = maxf(worst, (Boat.hull_push(boat.pos, boat.yaw, b.pos, b.yaw)[0] as Vector2).length())
		var closing := (boat.velocity - b.velocity).dot(approach)
		if contact_t == INF and "boat_bump" in _sounds:
			contact_t = t
			at_hit = closing
		elif contact_t == INF:
			before_hit = closing
		if contact_t != INF and t > contact_t + 0.5 and t < contact_t + 1.5:
			toward.append((boat.velocity - b.velocity).dot(approach))
		if t > 4.0:
			boat.throttle = 0.0
	_check("%s: ääriviivat eivät mene päällekkäin (%.3f m)" % [label, worst], worst <= 0.1)
	_check("%s: kolahdus kuuluu" % label, contact_t != INF)
	_check("%s: viesti \"Kolahdus! Vene törmäsi toiseen veneeseen\"" % label, _messages.has("Kolahdus! Vene törmäsi toiseen veneeseen"))
	_check("%s: nopeus kohti venettä pysähtyy iskussa (%.2f -> %.2f m/s)" % [label, before_hit, at_hit], at_hit < before_hit * 0.5)
	if mode == "push":
		# Täydellä kaasulla pelaaja työntää liikkuvaa venettä edellään: suhteellinen nopeus pysähtyy
		var mean: float = toward.reduce(func(a, v): return a + v, 0.0) / maxi(1, toward.size())
		_check("%s: pelaaja työntää venettä, ei mene läpi (suhteellinen nopeus %.2f m/s)" % [label, mean], mean < 0.3)
	if anchored:
		_check("%s: ankkurissa oleva vene ei liiku (%.3f m)" % [label, b.pos.distance_to(start_other)], b.pos.distance_to(start_other) < 0.05)
	if mode == "slide":
		var slid := (boat.pos - target).dot(approach)
		_check("%s: veneet liukuvat ohi (%.1f m törmäyskohdan ohi)" % [label, slid], slid > 2.0)


func _collisions() -> void:
	_calm()
	var side := Vector2(-_dir.y, _dir.x)
	await _ram("kylkeen", _dir, side, "push")
	await _ram("keulaan", -_dir, _dir, "bow")
	await _ram("viistosti", _dir, (side + _dir * 1.4).normalized(), "slide")
	await _ram("ankkurissa olevan soutuveneen kylkeen", _dir, side, "push", true)
	boat.motor_running = false
	boat.throttle = 0.0
	_clear_boats()


## 5. Väistö: pelaaja paikallaan moottoriveneen reitillä
func _avoidance() -> void:
	_place_player(_spot, Vector2(-_dir.y, _dir.x))
	var route := PackedVector2Array([_spot - _dir * 150.0, _spot + _dir * 150.0])
	var b := ob.spawn(OtherBoats.Kind.MOTOR, route)
	b.hold_at_end = true
	b.motor_running = true
	b.state = OtherBoat.State.TRAVEL
	b.velocity = _dir * OtherBoat.MOTOR_CRUISE
	var closest := INF
	var t := 0.0
	while t < 150.0 and (b.pos - _spot).dot(_dir) < 100.0:
		await _frame()
		t += 1.0 / 60.0
		closest = minf(closest, b.pos.distance_to(boat.pos))
	_check("väistö: vene ohittaa pelaajan vähintään 15 m:n päästä (%.1f m)" % closest, closest >= 15.0)
	_check("väistö: vene jatkaa matkaansa (%.0f s)" % t, (b.pos - _spot).dot(_dir) >= 100.0)
	_check("väistö: ei törmäystä", not "boat_bump" in _sounds or closest > 4.0)
	_clear_boats()


## 6. Ehdot: yöllä ei veneitä, päivällä enintään kaksi, hämärtyessä kotiin;
## kova tuuli ja rankkasade estävät lähdön
func _conditions() -> void:
	_place_player(_spot, _dir)
	var w: Weather = main.weather
	w.wind_base = 9.0
	_check("yli 8 m/s tuulella ei lähdetä", not ob.can_launch())
	w.wind_base = 0.0
	w.rain = 0.6
	_check("rankkasateella ei lähdetä", not ob.can_launch())
	w.rain = 0.0
	main.sky.minutes = 60.0
	var night: float = main.sky.daylight()
	ob.auto_spawn = true
	ob._start_checked = false
	for i in 300:
		ob._timer = 0.0
		await _frame()
	_check("yöllä (valoisuus %.2f) ei yhtään venettä" % night, night <= OtherBoats.MIN_DAYLIGHT and ob.boats.is_empty())
	main.sky.minutes = 12.0 * 60.0
	var most := 0
	for i in 1200:
		ob._timer = 0.0
		await _frame()
		most = maxi(most, ob.boats.size())
	_check("päivällä veneitä tulee, enintään 2 kerrallaan (%d)" % most, most >= 1 and most <= OtherBoats.MAX_BOATS)
	ob.auto_spawn = false
	main.sky.minutes = 60.0
	for i in 30:
		await _frame()
	var home := ob.boats.all(func(b): return b.dock >= 0)
	_check("hämärtyessä veneet palaavat laiturille (%d venettä)" % ob.boats.size(), home)
	_clear_boats()


## Jäätalvi: ei veneitä eikä reittiruudukkoa
func _winter() -> void:
	ob.auto_spawn = true
	ob._start_checked = false
	for i in 300:
		ob._timer = 0.0
		await _frame()
	_check("jäällä ei yhtään venettä", ob.boats.is_empty() and not ob.grid_ready)

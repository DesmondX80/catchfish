extends Node
## Pilkkimisen testi: godot --fixed-fps 30 -- --day=40 --icetest [--icetest-shots=KANSIO]
## Kävelee jäälle, kairaa reiän, laskee pilkin, pilkkii nykäisten ja väsyttää kalat.

var main: Node
var _t := 0.0
var _step := 0
var _log: Array[String] = []
var _start := Vector2.ZERO
var _catches := []
var _bites := 0
var _jig_timer := 0.0
var _shots := ""
var _shot_done := {}
var _min_depth_reached := 0.0
var _landed_t := 0.0


func _ready() -> void:
	main = get_parent()
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--icetest-shots="):
			_shots = arg.split("=")[1]
	main.fishing.caught.connect(func(e, _r): _catches.append(e))
	main.sky.minutes = 10.0 * 60.0


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _shot(name: String) -> void:
	if _shots != "" and not _shot_done.has(name):
		_shot_done[name] = true
		get_viewport().get_texture().get_image().save_png(_shots.path_join(name + ".png"))


func _press(action: String, pressed := true) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _next() -> void:
	_step += 1
	_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	var f: Fishing = main.fishing
	var boat: Boat = main.boat
	var rig: CameraRig = main.camera_rig
	match _step:
		0:
			_check("järvi on jäässä", boat.on_ice and f.on_ice)
			_check("vene piilossa, kalastaja seisoo", not boat.wake.visible and boat.angler.pose == Angler.Pose.ICE_STAND)
			_go_to_school()
			_start = boat.pos
			_press("boat_forward")
			_next()
		1:
			Input.action_press("boat_forward") # pidetään pohjassa (ikkunan fokus voi vapauttaa sen)
			rig.yaw = boat.yaw + 0.5
			rig.pitch = 0.25
			rig.distance = 6.0
			if _t > 1.5:
				_shot("j1-kavely")
			if _t > 4.0:
				_press("boat_forward", false)
				_check("käveli %.1f m (%.1f km/h)" % [boat.pos.distance_to(_start), boat.speed_kmh()], boat.pos.distance_to(_start) > 3.0)
				_check("jäällä, vettä alla %.1f m" % boat.depth_below(), main.lake.is_water(boat.pos.x, boat.pos.y))
				_next()
		2:
			if _t > 1.0:
				_press("cast")
				_next()
		3:
			if _t > 1.5:
				_shot("j2-kairaus")
			if f.state != Fishing.State.DRILLING:
				_press("cast", false)
				_check("reikä kairattu (%.1f s)" % _t, f.holes.size() == 1 and f.at_hole())
				_next()
		4:
			if _t > 0.6:
				_press("cast")
				_next()
		5:
			# Pilkki lasketaan: vasen pohjassa, kunnes pilkki on lähellä pohjaa
			Input.action_press("cast")
			var bottom: float = main.lake.depth_at(f.current_hole.x, f.current_hole.z)
			_min_depth_reached = maxf(_min_depth_reached, f.lure_depth())
			var bit := f.state != Fishing.State.RETRIEVING # kala iski jo laskun aikana
			if f.lure_depth() > bottom - 0.4 or bit or _t > 8.0:
				_press("cast", false)
				_check("pilkki laskettu %.1f m syvyyteen (pohja %.1f m)%s" % [f.lure_depth(), bottom, ", tärppi laskun aikana" if bit else ""], f.lure_depth() > bottom - 0.6 or bit)
				_check("kalastaja istuu ämpärillä", boat.angler.pose == Angler.Pose.ICE_SIT)
				_press("reel")
				_next()
		6:
			# Nostetaan pilkki 30 cm pohjasta
			if _t > 0.35:
				_press("reel", false)
				rig.yaw = boat.yaw + 1.3
				rig.pitch = 0.3
				rig.distance = 3.0
				_next()
		7:
			_fish(delta)
			if _t > 1.0:
				_shot("j3-pilkkiminen")
			if _t > (120.0 if _shots != "" else 600.0):
				_finish()


## Pilkitään: nykäisy 1,5 s välein, tärpistä vastaisku, väsytys ja nosto
func _fish(delta: float) -> void:
	var f: Fishing = main.fishing
	match f.state:
		Fishing.State.RETRIEVING:
			_jig_timer -= delta
			if _jig_timer <= 0.0:
				_jig_timer = randf_range(1.2, 2.2)
				_press("twitch")
				_press("twitch", false)
			_press("reel", false)
		Fishing.State.BITE:
			if randf() < 0.15:
				_bites += 1
				_press("cast")
				_press("cast", false)
		Fishing.State.FIGHT:
			_shot("j4-vasytys")
			if f.landing_ready() and f.fish_stamina() < 0.3:
				_press("reel", false)
				_press("cast")
				_press("cast", false)
			else:
				_press("reel", f.tension < f.drag_kg * 0.9)
		Fishing.State.LANDED:
			_landed_t += delta
			if _landed_t > 1.0:
				main.camera_rig.yaw = main.boat.yaw + 1.9 # sivulta, saalis näkyy avannon vieressä
				main.camera_rig.pitch = 0.7
				main.camera_rig.distance = 2.4
			if _landed_t > 1.5:
				_shot("j5-saalis")
				_landed_t = 0.0
				_press("cast")
				_press("cast", false)
		Fishing.State.READY:
			# Pilkki nousi tai kala irtosi: lasketaan uudelleen
			_press("cast")
			await get_tree().create_timer(2.0).timeout
			_press("cast", false)


func _finish() -> void:
	_check("tärppejä %d, saaliita %d" % [_bites, _catches.size()], _catches.size() > 0)
	for e in _catches:
		print("  SAALIS: %s %.2f kg %.0f cm (%s)" % [e["name"], e["weight"], e["length"], e["lure"]])
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)



## Siirtää kalastajan ahvenparven luo (pilkkijä etsii parven kaikuluotaimella)
func _go_to_school() -> void:
	var pop: FishPopulation = main.population
	var lake: LakeData = main.lake
	var best := Vector2.ZERO
	var best_n := 0
	for i in range(0, pop.fish.size(), 13):
		var f: Dictionary = pop.fish[i]
		if f["sp"] != "ahven":
			continue
		var p: Vector2 = f["pos"]
		var depth := lake.depth_at(p.x, p.y)
		if depth < 1.6 or depth > 3.8:
			continue
		var n := pop.fish_near(p, 5.0).size()
		if n > best_n:
			best_n = n
			best = p
	var boat: Boat = main.boat
	boat.pos = best - boat.forward() * 5.0 - boat.forward() * Fishing.HOLE_AHEAD # kävellään 5 m parven päälle
	if not lake.is_water(boat.pos.x, boat.pos.y):
		boat.pos = best - boat.forward() * Fishing.HOLE_AHEAD
	print("Ahvenparvi: %d kalaa 5 m säteellä, syvyys %.1f m" % [best_n, lake.depth_at(best.x, best.y)])

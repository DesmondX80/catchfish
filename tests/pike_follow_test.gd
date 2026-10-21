extends Node
## Kalojen näkyvyyden (#29) ja hauen seurannan (#17) testi:
##   godot --headless --fixed-fps 30 -- --day=180 --piketest
## Vapaasti uivat kalat eivät näy vedessä. Uistinta seuraava hauki näkyy ja
## pysyy uistimen perässä, iskee tasaisesti kelattuun uistimeen veneen vieressä
## ja kääntyy pois, kun uistin pysähtyy.
## --piketest-shots=KANSIO tallentaa kuvan seuraavasta hauesta (vaatii ikkunan).

var main: Node
var _log: Array[String] = []
var _step := 0
var _t := 0.0
var _pike := -1
var _spot := Vector2.ZERO
var _dir := Vector2.ZERO
var _max_gap := 0.0
var _seen_drawn := false
var _gone := 0.0
var _reeling := false # ikkunassa fokuksen menetys vapauttaa näppäimet: pidetään joka ruutu
var _shots := ""
var _shot_index := 0
const SHOT_DISTANCES := [9.0, 6.0, 4.0, 3.0]


func _ready() -> void:
	main = get_parent()
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	for i in main.population.fish.size():
		var f: Dictionary = main.population.fish[i]
		f["wary"] = 1.0e9 # ei tavallisia tärppejä
		if _pike < 0 and f["sp"] == "hauki" and f["weight"] > 1.0:
			_pike = i
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--piketest-shots="):
			_shots = arg.split("=")[1]
	_find_spot()


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _press(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _next() -> void:
	_step += 1
	_t = 0.0


## Paikka, josta on joka suuntaan vähintään 40 m avovettä ja syvyyttä yli 2 m
func _find_spot() -> void:
	var lake: LakeData = main.lake
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var origin := Vector2(lake.start_position.x, lake.start_position.z)
	for i in 20000:
		var p := origin + Vector2(rng.randf_range(-1500, 1500), rng.randf_range(-1500, 1500))
		if not lake.is_water(p.x, p.y) or lake.depth_at(p.x, p.y) < 2.0:
			continue
		var d := Vector2.from_angle(rng.randf() * TAU)
		var open := true
		for s in range(2, 45, 3):
			var q := p + d * s
			open = open and lake.is_water(q.x, q.y) and lake.depth_at(q.x, q.y) > 1.5
		if open:
			_spot = p
			_dir = d
			return


func _hold_boat() -> void:
	var boat: Boat = main.boat
	boat.pos = _spot
	boat.velocity = Vector2.ZERO
	main.camera_rig.yaw = atan2(-_dir.x, -_dir.y)


func _drawn_fish() -> int:
	var n := 0
	for mm in main.fish_visuals._multimeshes.values():
		n += mm.visible_instance_count
	return n


func _physics_process(delta: float) -> void:
	_t += delta
	var f: Fishing = main.fishing
	_hold_boat()
	if _reeling:
		Input.action_press("reel")
	elif Input.is_action_pressed("reel"):
		Input.action_release("reel")
	match _step:
		0:
			# Kaloja aivan veneen vieressä pinnan lähellä: niitä ei saa näkyä
			if _t < 0.2:
				for i in 30:
					var fish: Dictionary = main.population.fish[i]
					fish["pos"] = _spot + Vector2(randf_range(-3, 3), randf_range(-3, 3))
					fish["depth"] = 0.4
					main.population._update_grid(i)
			elif _t > 1.0:
				_check("vapaasti uivat kalat eivät näy vedessä (piirretty %d)" % _drawn_fish(), _drawn_fish() == 0)
				_cast(f)
				_next()
		1:
			if f.state == Fishing.State.RETRIEVING and _t > 1.0:
				_start_follow(f, true)
				_reeling = true

				_next()
		2:
			# Seuraaja kelataan veneelle: pysyy perässä ja iskee viime hetkellä
			if not f.follower.is_empty():
				var gap: float = Vector2(f.follower["pos"].x - f.lure_pos.x, f.follower["pos"].z - f.lure_pos.z).length()
				if _t > 1.0:
					_max_gap = maxf(_max_gap, gap)
				_seen_drawn = _seen_drawn or (f.follower["seen"] and _drawn_fish() == 1)
				if _shots != "":
					# Kuvauskamera veneen yllä katsoo uistimen ja hauen suuntaan
					var at: Vector3 = f.lure_pos.lerp(f.follower["pos"], 0.5)
					var from := Vector3(main.boat.pos.x, 2.6, main.boat.pos.y) - Vector3(at.x - main.boat.pos.x, 0.0, at.z - main.boat.pos.y).normalized() * 1.5
					main.camera_rig.shot = Transform3D(Basis.looking_at(at - from), from)
					main.camera_rig.shot_view = true
				var tip0 := f.rod_tip()
				var to_tip := Vector2(f.lure_pos.x - tip0.x, f.lure_pos.z - tip0.z).length()
				if _shots != "" and _shot_index < SHOT_DISTANCES.size() and to_tip < SHOT_DISTANCES[_shot_index]:
					get_viewport().get_texture().get_image().save_png(_shots.path_join("hauki-seuraa-%d.png" % (_shot_index + 1)))
					print("kuva %d: %.1f m vavan kärjestä, hauki %.2f m syvyydessä" % [_shot_index + 1, to_tip, -f.follower["pos"].y])
					_shot_index += 1
			if f.state == Fishing.State.BITE:
				var tip := f.rod_tip()
				var dist := Vector2(f.lure_pos.x - tip.x, f.lure_pos.z - tip.z).length()
				_check("hauki pysyi uistimen perässä (suurin väli %.2f m)" % _max_gap, _max_gap < 1.6)
				_check("seuraaja näkyy pinnan lähellä veneen vieressä", _seen_drawn)
				_check("hauki iski viime hetkellä (%.1f m vavan kärjestä)" % dist, f._fish_index == _pike and dist < 4.0)
				_check("iskun jälkeen seuraajaa ei piirretä erikseen", f.follower.is_empty())
				f._try_hook(0.0, "") # ei tartu: palataan kelaamaan
				main.camera_rig.shot_view = false
				_next()
			elif f.state == Fishing.State.READY or _t > 60.0:
				_check("hauki iski seuratessaan (tila %d)" % f.state, false)
				_finish()
		3:
			if f.state == Fishing.State.READY:
				_reeling = false
				_cast(f)
				_next()
		4:
			if f.state == Fishing.State.RETRIEVING and _t > 1.0:
				main.population.fish[_pike]["wary"] = 0.0
				_start_follow(f, false)
				_reeling = true
				_next()
		5:
			# Kelataan hetki, sitten uistin pysähtyy: hauki kääntyy pois
			if _t > 3.0:
				_reeling = false
				_check("seuraaja piirretään vedessä", _drawn_fish() == 1)
				_next()
		6:
			if not f.follower.is_empty() and f.follower["leaving"] and _t < 2.0:
				_check("uistin pysähtyi: hauki kääntyi pois (%.1f s)" % _t, true)
				_check("pois kääntynyt hauki on varovainen", main.population.fish[_pike]["wary"] > 0.0)
				_next()
			elif _t >= 2.0:
				_check("uistin pysähtyi: hauki kääntyi pois", false)
				_finish()
		7:
			# Piirto päivittyy ruudun lopussa: tarkistetaan hetki katoamisen jälkeen
			if f.follower.is_empty():
				_gone += delta
			if _gone > 0.2:
				_check("pois kääntynyt hauki katosi näkyvistä (%.1f s)" % _t, _drawn_fish() == 0 and f.state == Fishing.State.RETRIEVING)
				_finish()
			elif _t > 4.0:
				_check("pois kääntynyt hauki katosi näkyvistä", false)
				_finish()

func _cast(f: Fishing) -> void:
	f.state = Fishing.State.READY
	f.power = 0.9
	f._cast()


func _start_follow(f: Fishing, strike: bool) -> void:
	var pike: Dictionary = main.population.fish[_pike]
	pike["pos"] = Vector2(f.lure_pos.x, f.lure_pos.z) + _dir * 2.0
	pike["depth"] = 1.5
	main.population._update_grid(_pike)
	f._start_follow(_pike)
	f.follower["strike"] = strike
	f.follower["strike_at"] = 2.5


func _finish() -> void:
	_reeling = false
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

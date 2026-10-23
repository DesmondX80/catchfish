extends Node
## Uistelumoodin testi: godot --headless --fixed-fps 30 -- --day=180 --trollstriketest
## Vapa 1 telineeseen → uistelumoodi ja FPV-kamera päälle. Vavalla 2 ei heitetä,
## vaan uistin lasketaan vasen hiiri pohjassa veneen perään ja vapa telineeseen.
## FPV:ssä hiiren nappi valitsee vavan sen mukaan, kummalla puolella ruutua se
## näkyy; tärppäävä vapa nostetaan telineestä ja vastaisku annetaan samalla.

const LINE := 20.0

var main: Node
var _log: Array[String] = []
var _messages: Array[String] = []
var _step := 0
var _t := 0.0
var _left := -1
var _right := -1
var _strikes := 0
var _line_start := 0.0
var _fpv_setting := false


func _ready() -> void:
	main = get_parent()
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	main.fishing.message.connect(func(t): _messages.append(t))
	for f in main.population.fish:
		f["wary"] = 1.0e9 # tärppi tehdään testissä itse
	var boat: Boat = main.boat
	var spot := _find_spot()
	boat.pos = spot[0]
	boat.velocity = Vector2.ZERO
	boat.yaw = atan2(-spot[1].x, -spot[1].y)
	boat._apply_transform()
	_fpv_setting = Settings.first_person
	main.camera_rig.first_person = false
	main.camera_rig.yaw = boat.yaw + PI


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _press(action: String, pressed := true) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _tap(action: String) -> void:
	_press(action)
	_press(action, false)


func _next() -> void:
	_step += 1
	_t = 0.0


## Syvä, suora vesialue soutamiseen: [paikka, suunta]
func _find_spot() -> Array:
	var lake: LakeData = main.lake
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var best := -1.0
	var origin := Vector2(lake.start_position.x, lake.start_position.z)
	var spot := [origin, Vector2.UP]
	for i in 6000:
		var p := origin + Vector2(rng.randf_range(-1500, 1500), rng.randf_range(-1500, 1500))
		var d := Vector2.from_angle(rng.randf() * TAU)
		var shallowest := 99.0
		for s in range(-30, 90, 4):
			var q := p + d * s
			shallowest = minf(shallowest, lake.depth_at(q.x, q.y) if lake.is_water(q.x, q.y) else 0.0)
		if shallowest > best:
			best = shallowest
			spot = [p, d]
	return spot


## Uistin veneen perään siima kireällä (kuin heitetty ja kelattu suoraksi)
func _lure_behind(side: float) -> void:
	var f: Fishing = main.fishing
	var boat: Boat = main.boat
	var at := boat.pos - boat.forward() * LINE + boat.right() * side
	f.state = Fishing.State.RETRIEVING
	f.lure_pos = Vector3(at.x, -0.5, at.y)
	f._prev_lure = f.lure_pos
	f.line_out = f.rod_tip().distance_to(f.lure_pos)


## Tärppi telinevapaan: kuin kala olisi iskenyt uistimeen
func _force_bite(rod: int) -> void:
	var f: Fishing = main.fishing
	var pop: FishPopulation = main.population
	var at: Vector3 = f._rod_get(rod, "lure_pos")
	var best := 0
	for i in pop.fish_near(Vector2(at.x, at.z), 60.0):
		if pop.fish[i]["weight"] > 0.4 and pop.fish[i]["weight"] < 2.0:
			best = i
			break
	var cur := f._cur
	f._swap_to(rod)
	f._fish_index = best
	f._fish = pop.fish[best]
	f.state = Fishing.State.BITE
	f._bite_timer = 0.5
	f._swap_to(cur)


func _physics_process(delta: float) -> void:
	_t += delta
	var f: Fishing = main.fishing
	var rig: CameraRig = main.camera_rig
	Input.action_press("boat_forward")
	match _step:
		0:
			if _t > 3.0:
				f.lure_index = 0
				_lure_behind(1.5)
				_check("ei uistelumoodia ennen telinettä", not f.trolling())
				_tap("rod_holder")
				_next()
		1:
			if _t > 0.2:
				_check("vapa 1 telineeseen → uistelumoodi", f.trolling() and f.held == 1)
				_check("uistelumoodissa FPV-kamera päälle", rig.first_person)
				_check("FPV-asetusta ei tallennettu", Settings.first_person == _fpv_setting)
				_tap("cast")
				_next()
		2:
			if _t > 0.2:
				_check("käsivavalla ei heitetä: uistin laskettiin perään (tila %s)" % Fishing.State.keys()[f.state], f.state == Fishing.State.RETRIEVING and f.line_out < 4.0)
				_line_start = f.line_out
				_press("cast")
				_next()
		3:
			Input.action_press("cast")
			if _t > 8.0:
				_press("cast", false)
				_check("vasen hiiri pohjassa siimaa lähti soutaessa (%.1f → %.1f m)" % [_line_start, f.line_out], f.line_out > _line_start + 5.0)
				_next()
		4:
			if _t > 0.5:
				_check("ilman vasenta hiirtä siimaa ei lähde lisää", f.line_out < Fishing.TROLL_MAX_LINE)
				_tap("rod_holder")
				_next()
		5:
			if _t > 0.3:
				_check("molemmat vavat telineissä", f.hands_free() and f.holder_rods().size() == 2)
				_left = f._rod_at_side(true)
				_right = f._rod_at_side(false)
				_check("vasen ja oikea hiiri eri vavoille (vasen %d, oikea %d)" % [_left + 1, _right + 1], _left >= 0 and _right >= 0 and _left != _right)
				rig.yaw += PI
				_next()
		6:
			if _t > 0.2:
				_check("katse toisaalle: puolet vaihtuvat", f._rod_at_side(true) == _right and f._rod_at_side(false) == _left)
				rig.yaw -= PI
				rig.first_person = false
				_tap("cast")
				_next()
		7:
			if _t > 0.2:
				_check("kolmannen persoonan kamerassa hiiri ei nosta vapaa", f.hands_free())
				rig.first_person = true
				_force_bite(_left)
				_tap("cast")
				_strikes += 1
				_next()
		8:
			if _t > 0.2:
				_check("vasen hiiri nosti vasemman vavan", f.held == _left and not f.in_holder)
				if f.state == Fishing.State.FIGHT:
					_check("vastaisku: kala tarttui (%d. yritys): \"%s\"" % [_strikes, _messages[-1]], true)
					_next()
				elif _strikes >= 15:
					_check("vastaisku ei koskaan onnistunut", false)
					_finish()
				else:
					# Ei tarttunut: vapa takaisin telineeseen ja uusi tärppi
					_tap("rod_holder")
					_step = 7
					_t = 0.0
		9:
			# Käsivavassa kala: tärppäävän telinevavan nappi ei nosta sitä
			_force_bite(_right)
			var button := "cast" if f._rod_at_side(true) == _right else "reel"
			_tap(button)
			_next()
		10:
			if _t > 0.2:
				_check("kädet täynnä: käsivapa jäi käteen (%s)" % _messages[-1], f.held == _left and f.state == Fishing.State.FIGHT and _messages[-1].begins_with("Kädet täynnä"))
				_finish()


func _finish() -> void:
	Input.action_release("boat_forward")
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

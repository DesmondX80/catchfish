extends Node
## Moottorin nopeuden ja 0-näppäimen testi: godot --headless --fixed-fps 30 -- --day=180 --motorspeedtest
## Tyynellä syvässä vedessä täydellä kaasulla huippu 27,5–28,5 km/h ja 50 %
## kaasulla noin 19–20 km/h. Näppäin 0 (toiminto motor_idle) vie kaasun heti
## vapaalle eteen- ja peruutuskaasulta ja moottorin käynnistyessä; moottori
## sammuksissa ja jäällä se ei tee mitään. Peruutuksen työntö ennallaan 168 N.

const AREA := 30.0 # m: vene pidetään näin lähellä testipaikkaa

var main: Node
var _log: Array[String] = []
var _messages: Array[String] = []
var _step := 0
var _t := 0.0
var _spot := Vector2.ZERO
var _dir := Vector2.ZERO
var _top := 0.0
var _accel_time := -1.0
var _speed_before := 0.0
var _saved := {}


func _ready() -> void:
	main = get_parent()
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	main.boat.message.connect(func(text): _messages.append(text))
	main.weather.wind_base = 0.0
	_find_spot()


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _next() -> void:
	_step += 1
	_t = 0.0


func _press_idle() -> void:
	var ev := InputEventAction.new()
	ev.action = "motor_idle"
	ev.pressed = true
	Input.parse_input_event(ev)


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)


## Suora syvä väylä (yli 2,5 m) 2 × AREA + 10 m, jotta vauhti ei osu pohjaan
func _find_spot() -> void:
	var lake: LakeData = main.lake
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var size := lake.world_size()
	for i in 200000:
		var p := Vector2(lake.origin_x + rng.randf() * size.x, lake.origin_z + rng.randf() * size.y)
		if lake.depth_at(p.x, p.y) < 2.5:
			continue
		var d := Vector2.from_angle(rng.randf() * TAU)
		var ok := true
		var n := d.orthogonal()
		for s in range(-int(AREA) - 10, int(AREA) + 12, 2):
			for side in [-4.0, 0.0, 4.0]:
				var q: Vector2 = p + d * s + n * side
				ok = ok and lake.depth_at(q.x, q.y) > 2.5
		if ok:
			_spot = p
			_dir = d
			print("Testipaikka: syvyys %.2f m" % lake.depth_at(p.x, p.y))
			return
	print("Testipaikkaa ei löytynyt")


## Vene pidetään suunnassa ja väylällä: liian kauas ajanut siirretään taaksepäin
## nopeutta muuttamatta
func _hold(boat: Boat) -> void:
	boat.yaw = atan2(-_dir.x, -_dir.y)
	boat.yaw_rate = 0.0
	var along := (boat.pos - _spot).dot(_dir)
	if along > AREA:
		boat.pos -= _dir * AREA * 2.0
	elif along < -AREA:
		boat.pos += _dir * AREA * 2.0
	boat.pos = _spot + _dir * (boat.pos - _spot).dot(_dir)


func _physics_process(delta: float) -> void:
	_t += delta
	var boat: Boat = main.boat
	if _step < 9:
		_hold(boat)
	match _step:
		0:
			if _spot == Vector2.ZERO:
				_check("testipaikka löytyi", false)
				_finish()
				return
			boat.pos = _spot - _dir * AREA
			boat.velocity = Vector2.ZERO
			boat.motor_running = true
			boat.throttle = 0.0
			Input.action_press("boat_forward")
			_next()
		1:
			# W pohjassa 20 s: kaasu 100 %, huippunopeus
			var v := boat.speed_kmh()
			_top = maxf(_top, v)
			if _accel_time < 0.0 and v >= 26.6:
				_accel_time = _t
			if _t > 20.0:
				Input.action_release("boat_forward")
				_check("kaasu nousi 100 %%:iin (%.2f)" % boat.throttle, is_equal_approx(boat.throttle, 1.0))
				_check("huippunopeus täydellä kaasulla %.2f km/h (27,5–28,5)" % _top, _top >= 27.5 and _top <= 28.5)
				_check("0 → 26,6 km/h %.1f s:ssa (noin 5 s)" % _accel_time, _accel_time > 3.5 and _accel_time < 6.5)
				_speed_before = boat.speed_kmh()
				_messages.clear()
				_press_idle()
				_next()
		2:
			# Seuraavalla ruudulla kaasu on vapaalla, HUD päivittyy
			if _t > 0.2:
				_check("0 vei kaasun heti vapaalle (%.2f)" % boat.throttle, boat.throttle == 0.0)
				_check("moottori jatkaa käyntiä", boat.motor_running)
				_check("HUD näyttää \"Moottori 0 %\"", main.hud._status.text.contains("Moottori 0 %"))
				_check("0:sta ei ilmoitusta", _messages.is_empty())
				_next()
		3:
			if _t > 5.0:
				var v := boat.speed_kmh()
				_check("vene hidastui liukuen (%.1f → %.1f km/h)" % [_speed_before, v], v < _speed_before * 0.6 and v > 1.0)
				_check("kaasu pysyi vapaalla", boat.throttle == 0.0)
				Input.action_press("boat_forward")
				_next()
		4:
			if _t > 1.0:
				Input.action_release("boat_forward")
				_check("W nostaa kaasua 0:n jälkeen (%.2f)" % boat.throttle, boat.throttle > 0.4 and boat.throttle < 0.8)
				boat.throttle = 0.5
				_top = 0.0
				_next()
		5:
			# 50 % kaasulla 25 s
			_top = maxf(_top, boat.speed_kmh())
			if _t > 25.0:
				_check("50 %% kaasulla %.2f km/h (19–20)" % _top, _top >= 19.0 and _top <= 20.0)
				Input.action_press("boat_back")
				_top = 0.0
				_next()
		6:
			# S pohjassa: kaasu peruutuksen alarajalle, työntö ennallaan 168 N
			if _t > 3.0:
				_top = maxf(_top, boat.speed_kmh() if boat.velocity.dot(boat.forward()) < 0.0 else 0.0)
			if _t > 30.0:
				Input.action_release("boat_back")
				_check("peruutuskaasu alarajalla %.3f (noin -0,19)" % boat.throttle, is_equal_approx(boat.throttle, Boat.REVERSE_THROTTLE) and absf(boat.throttle + 0.19) < 0.005)
				_check("peruutuksen työntö %.1f N (ennallaan 168 N)" % (-boat.throttle * Boat.MOTOR_THRUST), absf(boat.throttle * Boat.MOTOR_THRUST + 168.0) < 0.01)
				_check("peruutusnopeus %.2f km/h (noin 11,5)" % _top, _top >= 11.0 and _top <= 12.0)
				_check("HUD näyttää peruutuksen", main.hud._status.text.contains("Moottori peruutus"))
				_press_idle()
				_next()
		7:
			if _t > 0.2:
				_check("0 peruutuskaasulta → kaasu vapaalla (%.2f)" % boat.throttle, boat.throttle == 0.0)
				# Moottori sammuksiin (Q): soudetaan
				_press("motor_toggle")
				_next()
		8:
			if _t > 2.0 and not _saved.has("off"):
				_saved["off"] = true
				_check("moottori sammui", not boat.motor_running and boat.motor_starting <= 0.0)
				boat.throttle = 0.3 # jäänyt arvo: 0 ei saa koskea siihen soudettaessa
				_messages.clear()
				_press_idle()
			elif _t > 2.4 and _saved.has("off") and not _saved.has("start"):
				_saved["start"] = true
				_check("moottori sammuksissa 0 ei muuta kaasua (%.2f)" % boat.throttle, boat.throttle == 0.3)
				_check("moottori sammuksissa 0 ei käynnistä moottoria", not boat.motor_running and boat.motor_starting <= 0.0 and not boat.paddling)
				_check("moottori sammuksissa 0 ei anna ilmoitusta", _messages.is_empty())
				_check("HUD näyttää yhä airot", main.hud._status.text.contains("Airot"))
				boat.throttle = 0.0
				# Käynnistyvä moottori: 0 nollaa kaasun
				_press("motor_toggle")
			elif _t > 2.8 and _saved.has("start") and not _saved.has("starting"):
				_saved["starting"] = true
				_check("moottori käynnistyy", boat.motor_starting > 0.0)
				boat.throttle = 0.4
				_press_idle()
			elif _t > 3.2 and _saved.has("starting"):
				_check("käynnistyvän moottorin kaasu vapaalle (%.2f)" % boat.throttle, boat.throttle == 0.0)
				_next()
		9:
			# Jäällä 0 ei tee mitään
			if not _saved.has("ice"):
				_saved["ice"] = true
				boat.set_on_ice(true)
				boat.motor_running = true
				boat.throttle = 0.5
				_messages.clear()
				_press_idle()
			elif _t > 0.4:
				_check("jäällä 0 ei tee mitään (%.2f)" % boat.throttle, boat.throttle == 0.5)
				_check("jäällä 0 ei anna ilmoitusta", _messages.is_empty())
				_finish()


func _finish() -> void:
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

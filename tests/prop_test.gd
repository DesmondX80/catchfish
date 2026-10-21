extends Node
## Potkurin pohjakosketuksen testi: godot --headless --fixed-fps 30 -- --day=180 --proptest
## Moottorilla ajetaan syvästä vedestä matalikolle: syvässä potkuri ei osu,
## matalasta varoitetaan, alle metrin syvyydessä pyörivä potkuri osuu pohjaan
## ja vaurioituu, vapaalla ei osu, ja lopulta potkuri menee rikki ja moottori
## sammuu eikä käynnisty enää.

var main: Node
var _log: Array[String] = []
var _messages: Array[String] = []
var _step := 0
var _t := 0.0
var _start := Vector2.ZERO
var _dir := Vector2.ZERO
var _damage := 0.0


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


## Suora linja: ensin 25 m syvää (yli 1,5 m), sitten vähintään 15 m matalikkoa
## (0,4–0.95 m), jossa potkuri osuu pohjaan mutta runko ei vielä
func _find_spot() -> void:
	var lake: LakeData = main.lake
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var size := lake.world_size()
	for i in 200000:
		var p := Vector2(lake.origin_x + rng.randf() * size.x, lake.origin_z + rng.randf() * size.y)
		if lake.depth_at(p.x, p.y) < 0.4 or lake.depth_at(p.x, p.y) > 0.95:
			continue
		var d := Vector2.from_angle(rng.randf() * TAU)
		var ok := true
		for s in range(0, 16, 2):
			var q := p + d * s
			ok = ok and lake.depth_at(q.x, q.y) >= 0.4 and lake.depth_at(q.x, q.y) <= 0.95
		for s in range(8, 34, 2):
			var q := p - d * s
			ok = ok and lake.depth_at(q.x, q.y) > 1.5
		if ok:
			# Matalikon reunasta taaksepäin syvään
			var edge := p
			for s in range(1, 8):
				if lake.depth_at(p.x - d.x * s, p.y - d.y * s) > 0.95:
					edge = p - d * s
					break
			_start = edge - d * 25.0
			_dir = d
			print("Testipaikka: matalikko %.2f m" % lake.depth_at(p.x, p.y))
			return
	print("Testipaikkaa ei löytynyt")


func _physics_process(delta: float) -> void:
	_t += delta
	var boat: Boat = main.boat
	match _step:
		0:
			boat.pos = _start
			boat.yaw = atan2(-_dir.x, -_dir.y)
			boat.velocity = _dir * 3.0
			boat.yaw_rate = 0.0
			boat.motor_running = true
			boat.throttle = 1.0
			_next()
		1:
			# Syvässä täydellä kaasulla: ei osumia
			boat.yaw = atan2(-_dir.x, -_dir.y)
			boat.yaw_rate = 0.0
			if _t > 2.0:
				_check("syvässä potkuri ei osu pohjaan (vaurio %d %%)" % roundi(boat.prop_damage * 100.0), boat.prop_damage == 0.0)
				_next()
		2:
			boat.yaw = atan2(-_dir.x, -_dir.y)
			boat.yaw_rate = 0.0
			if boat.prop_damage > 0.0:
				var stern := boat.pos - boat.forward() * Boat.LENGTH * 0.5
				_check("matalasta varoitettiin ennen osumaa", _messages.any(func(m): return m.begins_with("Matalaa")))
				_check("potkuri osui pohjaan alle metrin syvyydessä (%.2f m, vaurio %d %%)" % [main.lake.depth_at(stern.x, stern.y), roundi(boat.prop_damage * 100.0)], main.lake.depth_at(stern.x, stern.y) < Boat.PROP_DEPTH)
				_check("osumasta ilmoitettiin", _messages.any(func(m): return m.begins_with("Potkuri osui")))
				# Vapaalle: potkuri ei pyöri eikä osu
				boat.throttle = 0.0
				_damage = boat.prop_damage
				_next()
			elif _t > 20.0:
				_check("potkuri osui pohjaan matalikolla", false)
				_finish()
		3:
			boat.throttle = 0.0
			if _t > 2.0:
				_check("vapaalla potkuri ei osu pohjaan", boat.prop_damage == _damage)
				boat.throttle = 1.0
				_next()
		4:
			# Täysi kaasu matalikossa, kunnes potkuri menee rikki
			boat.yaw = atan2(-_dir.x, -_dir.y)
			boat.yaw_rate = 0.0
			if boat.motor_running:
				boat.throttle = 1.0
				var stern := boat.pos - boat.forward() * Boat.LENGTH * 0.5
				if main.lake.depth_at(stern.x, stern.y) >= Boat.PROP_DEPTH:
					boat.pos += _dir * 0.5 # pidetään vene matalikolla
			if boat.prop_broken():
				_check("potkuri meni rikki (%.1f s) ja moottori sammui" % _t, not boat.motor_running)
				_check("rikkinäisestä ilmoitettiin", _messages.any(func(m): return m.begins_with("Potkuri meni rikki")))
				var ev := InputEventAction.new()
				ev.action = "motor_toggle"
				ev.pressed = true
				Input.parse_input_event(ev)
				_next()
			elif _t > 30.0:
				_check("potkuri meni rikki toistuvissa osumissa (vaurio %d %%)" % roundi(boat.prop_damage * 100.0), false)
				_finish()
		5:
			if _t > 2.5:
				_check("rikkinäistä moottoria ei saa käyntiin", not boat.motor_running and boat.motor_starting <= 0.0)
				_check("HUD kertoo rikkinäisestä potkurista", main.hud._status.text.contains("potkuri rikki"))
				_finish()


func _finish() -> void:
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

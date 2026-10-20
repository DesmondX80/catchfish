extends Node
## Laiturikosketuksen testi: godot --headless --fixed-fps 30 -- --day=180 --docktest
## Jokaisella aloituspaikalla ajetaan moottorilla täyttä vauhtia laiturin kylkeen,
## kärkeen ja viistosti kylkeen: runko ei saa mennä laiturin läpi eikä kannen alle,
## törmäyksestä kuuluu kolahdus ja viistossa törmäyksessä vene liukuu laituria pitkin.

const RUN_TIME := 7.0

var main: Node
var _log: Array[String] = []
var _start := 0
var _scenario := 0
var _t := 0.0
var _max_push := 0.0
var _bumps := 0
var _from := Vector2.ZERO
var _crossed := false


func _ready() -> void:
	main = get_parent()
	main.hud.set_paused_view(false)
	var boat: Boat = main.boat
	boat.sound_event.connect(func(sound: String, _at: Vector3) -> void:
		if sound == "boat_bump":
			_bumps += 1)
	_check_starts()
	_begin()


## Vene asetetaan jokaisella aloituspaikalla laiturin viereen eikä kannen alle
func _check_starts() -> void:
	var boat: Boat = main.boat
	for i in main.lake.starts.size():
		var s: Dictionary = main.lake.starts[i]
		var probe := Boat.new()
		main.lake.select_start(i)
		probe.setup(main.lake, main.weather)
		var moved := probe.pos.distance_to(Vector2(s["x"], s["z"]))
		var push := boat._dock_push(probe.pos, probe.yaw)
		_check("%s: vene aloituspaikalla irti laiturista (siirretty %.2f m)" % [s["id"], moved], push.length() < 0.01 and moved < 1.0)
		probe.free()
	main.lake.select_start(0)


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


## Laiturin paikallisista koordinaateista (x kannen poikki, z rantaa kohti) maailmaan
func _world(d: Dictionary, x: float, z: float) -> Vector2:
	return d["center"] + d["x_axis"] * x + d["z_axis"] * z


func _local(d: Dictionary, p: Vector2) -> Vector2:
	var rel: Vector2 = p - d["center"]
	return Vector2(rel.dot(d["x_axis"]), rel.dot(d["z_axis"]))


## Lähtöpaikka ja suunta laiturin paikallisissa koordinaateissa: [x, z, suunta x, suunta z, nimi]
func _scenario_setup(d: Dictionary) -> Array:
	var half: Vector2 = d["half"]
	match _scenario:
		0:
			return [half.x + 7.0, -half.y + 3.0, -1.0, 0.0, "kylkeen"]
		1:
			return [0.0, -half.y - 8.0, 0.0, 1.0, "kärkeen"]
		_:
			return [half.x + 6.0, -half.y + 1.0, -1.0, 0.6, "viistosti"]


func _begin() -> void:
	var d: Dictionary = main.lake.docks[_start]
	var setup := _scenario_setup(d)
	var boat: Boat = main.boat
	var dir: Vector2 = (d["x_axis"] * setup[2] + d["z_axis"] * setup[3]).normalized()
	boat.pos = _world(d, setup[0], setup[1])
	boat.yaw = atan2(-dir.x, -dir.y)
	boat.velocity = dir * 3.0
	boat.yaw_rate = 0.0
	boat.anchored = false
	boat.motor_starting = 0.0
	boat.motor_running = true
	boat.throttle = 1.0
	boat.tiller = 0.0
	boat._bump_cooldown = 0.0
	_from = _local(d, boat.pos)
	_t = 0.0
	_max_push = 0.0
	_bumps = 0
	_crossed = false


func _physics_process(delta: float) -> void:
	var boat: Boat = main.boat
	var d: Dictionary = main.lake.docks[_start]
	_t += delta
	_max_push = maxf(_max_push, boat._dock_push(boat.pos, boat.yaw).length())
	var local := _local(d, boat.pos)
	var half: Vector2 = d["half"]
	# Läpi mennyt vene olisi kannen toisella puolella (kylki) tai sen päällä (kärki)
	if _scenario == 1:
		_crossed = _crossed or local.y > -half.y
	else:
		_crossed = _crossed or local.x < half.x
	if _t < RUN_TIME:
		return
	var s: Dictionary = main.lake.starts[_start]
	var name: String = "%s, %s" % [s["id"], _scenario_setup(d)[4]]
	_check("%s: runko ei mennyt kannen alle (syvin %.2f m)" % [name, _max_push], _max_push < 0.08)
	_check("%s: vene ei mennyt laiturin läpi" % name, not _crossed)
	_check("%s: törmäyksestä kolahdus (%d)" % [name, _bumps], _bumps >= 1)
	if _scenario == 2:
		_check("%s: vene liukui laituria pitkin (%.1f m)" % [name, local.y - _from.y], local.y - _from.y > 2.0)
	boat.motor_running = false
	boat.throttle = 0.0
	_scenario += 1
	if _scenario > 2:
		_scenario = 0
		_start += 1
	if _start >= main.lake.docks.size():
		_finish()
		return
	_begin()


func _finish() -> void:
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

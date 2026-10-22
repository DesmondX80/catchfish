extends Node
## Vastatuulitesti: godot --headless --fixed-fps 30 -- --day=180 --headwindtest
## Tyynellä soudun ja melonnan huippunopeus pysyy maltillisena, ja kovassa
## vastatuulessa (12 m/s, puuskat 20 s välein 18 m/s asti) pääsee etenemään
## sekä soutaen että meloen.

var main: Node
var _log: Array[String] = []
var _step := 0
var _t := 0.0
var _start := Vector2.ZERO
var _top := 0.0
const PHASES := [
	# nimi, mela, tuuli m/s, kesto s
	["soutu tyynellä", false, 0.0, 30.0],
	["melonta tyynellä", true, 0.0, 30.0],
	["soutu vastatuuleen", false, 12.0, 60.0],
	["melonta vastatuuleen", true, 12.0, 60.0],
]


func _ready() -> void:
	main = get_parent()
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	# Selälle, kauas rannasta
	var lake: LakeData = main.lake
	var best: Vector2 = main.boat.pos
	seed(7)
	for i in 20000:
		var p := Vector2(lake.origin_x, lake.origin_z) + Vector2(randf(), randf()) * lake.world_size()
		if lake.is_water(p.x, p.y) and lake.shore_distance(p.x, p.y) > lake.shore_distance(best.x, best.y):
			best = p
	main.boat.pos = best
	_begin()


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _wind_dir() -> Vector2:
	var d: float = main.weather.wind_direction
	return Vector2(sin(d), -cos(d))


func _begin() -> void:
	var boat: Boat = main.boat
	var phase: Array = PHASES[_step]
	if boat.paddling != phase[1]:
		boat.toggle_paddle()
	boat.velocity = Vector2.ZERO
	boat.yaw_rate = 0.0
	main.weather.wind_direction = 1.0
	boat.yaw = PI - main.weather.wind_direction # keula tuuleen
	_start = boat.pos
	_top = 0.0
	_t = 0.0
	Input.action_press("boat_forward")


func _physics_process(delta: float) -> void:
	if _step >= PHASES.size():
		return
	var phase: Array = PHASES[_step]
	var w: Weather = main.weather
	_t += delta
	w.wind_base = phase[2]
	w._wind_target = phase[2]
	w._gust_timer = 999.0
	w.wind_direction = 1.0 # tuuli koilliseen (ei satunnaiskävelyä)
	w.gust = phase[2] * 0.25 * (1.0 - cos(_t * TAU / 20.0))
	var boat: Boat = main.boat
	if _t < 3.0:
		_start = boat.pos # mela tai airot käteen ennen mittausta
		return
	_top = maxf(_top, boat.speed_kmh())
	if Engine.get_physics_frames() % 150 == 0 and phase[2] > 0.0:
		print("  t %.0f keula poikkeaa tuulesta %.0f°, nopeus vastatuuleen %.2f m/s, tuuli %.1f m/s" % [_t, rad_to_deg(boat.forward().angle_to(-_wind_dir())), boat.velocity.dot(-_wind_dir()), w.speed()])
	if _t < phase[3]:
		return
	var upwind := (boat.pos - _start).dot(-_wind_dir())
	var secs: float = phase[3] - 3.0
	if phase[2] == 0.0:
		print("%s: huippunopeus %.1f km/h" % [phase[0], _top])
		_check("%s: %.1f km/h" % [phase[0], _top], _top > 3.0 and _top < 7.5)
	else:
		print("%s: %.1f m %.0f s:ssa (%.2f m/s)" % [phase[0], upwind, secs, upwind / secs])
		_check("%s etenee: %.1f m" % [phase[0], upwind], upwind > 0.15 * secs)
	_step += 1
	Input.action_release("boat_forward")
	if _step < PHASES.size():
		_begin()
	else:
		for l in _log:
			print(l)
		get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

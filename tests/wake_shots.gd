extends Node
## Keula-aallon ja peräaallon kuvat designerin tarkistukseen (vaatii ikkunan):
##   godot --fixed-fps 30 -- --day=180 --wakeshots=/polku/kansioon
## Suora syvä väylä (> 2,5 m), tuuli 0, klo 12, vene pidetään suunnassa.
## 01–05 ja 11–12: 28 km/h (takaa ylhäältä, keula sivulta ja edestä, perä
## läheltä, ylhäältä, harjanne matalalta, FPV), 06: 16 km/h, 07: soutu,
## 08: peruutus, 09: täysi kaasu käännöksessä, 10: 28 km/h illalla klo 22.30.

const LANE := 90.0 # m: väylän puolipituus

var main: Node
var boat: Boat
var _dir := ""
var _spot := Vector2.ZERO
var _lane := Vector2.ZERO
var _hold := false
var _speed := NAN # pakotettu nopeus eteenpäin (m/s)
var _view: Array = [] # [silmä, katsekohta] veneen koordinaateissa (oikea, ylös, eteen)


func _ready() -> void:
	main = get_parent()
	boat = main.boat
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--wakeshots="):
			_dir = arg.split("=")[1]
	DirAccess.make_dir_recursive_absolute(_dir)
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	main.birds.auto_spawn = false
	main.other_boats.auto_spawn = false
	main.weather.set_kind(Weather.Kind.CLEAR, true)
	main.weather.set_process(false)
	_run.call_deferred()


func _calm() -> void:
	main.weather.wind_base = 0.0
	main.weather._wind_target = 0.0
	main.weather.gust = 0.0
	Waves.reset(0.0, main.weather.wind_direction)


## Suora syvä väylä 2 × LANE, myös käännöksen verran sivuille
func _find_lane() -> bool:
	var lake: LakeData = main.lake
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var size := lake.world_size()
	for i in 200000:
		var p := Vector2(lake.origin_x + rng.randf() * size.x, lake.origin_z + rng.randf() * size.y)
		if lake.depth_at(p.x, p.y) < 2.5:
			continue
		var d := Vector2.from_angle(rng.randf() * TAU)
		var n := d.orthogonal()
		var ok := true
		for s in range(-int(LANE), int(LANE) + 2, 3):
			for side in [-12.0, -6.0, 0.0, 6.0, 12.0]:
				var q: Vector2 = p + d * s + n * side
				ok = ok and lake.depth_at(q.x, q.y) > 2.5
			if not ok:
				break
		if ok:
			_spot = p
			_lane = d
			print("Väylä: syvyys %.2f m" % lake.depth_at(p.x, p.y))
			return true
	return false


func _physics_process(_delta: float) -> void:
	if _hold:
		boat.yaw = atan2(-_lane.x, -_lane.y)
		boat.yaw_rate = 0.0
		boat.pos = _spot + _lane * (boat.pos - _spot).dot(_lane)
	if not is_nan(_speed):
		boat.velocity = boat.forward() * _speed


func _process(_delta: float) -> void:
	if _view.is_empty():
		return
	var fw := boat.forward()
	var r := boat.right()
	var b3 := Vector3(boat.pos.x, 0.0, boat.pos.y)
	var eye: Vector3 = b3 + Vector3(r.x, 0, r.y) * _view[0].x + Vector3(0, _view[0].y, 0) + Vector3(fw.x, 0, fw.y) * _view[0].z
	var at: Vector3 = b3 + Vector3(r.x, 0, r.y) * _view[1].x + Vector3(0, _view[1].y, 0) + Vector3(fw.x, 0, fw.y) * _view[1].z
	main.camera_rig.shot = Transform3D(Basis.looking_at(at - eye), eye)
	main.camera_rig.shot_view = true


func _wait(seconds: float) -> void:
	for i in roundi(seconds * 30.0):
		await get_tree().physics_frame


## Vene väylän alkuun: v = nopeus eteenpäin (peruutus negatiivinen)
func _start(v: float, motor: bool, throttle: float) -> void:
	_hold = true
	boat.pos = _spot - _lane * (LANE - 10.0) * signf(v if v != 0.0 else 1.0)
	boat.yaw = atan2(-_lane.x, -_lane.y)
	boat.yaw_rate = 0.0
	boat.velocity = _lane * v
	boat.motor_running = motor
	boat.throttle = throttle
	boat._apply_transform()
	boat.snap_pose()
	boat.wake._samples.clear()


func _shot(name: String, eye: Vector3, at: Vector3) -> void:
	_view = [eye, at]
	await _wait(0.8)
	get_viewport().get_texture().get_image().save_png(_dir.path_join(name + ".png"))
	print("kuva %s: %.1f km/h eteenpäin, syvyys %.1f m, %s" % [name, boat.velocity.dot(boat.forward()) * 3.6,
		boat.depth_below(), main.hud._status.text.get_slice("\n", 0)])


func _run() -> void:
	if not _find_lane():
		print("VIRHE väylää ei löytynyt")
		get_tree().quit(1)
		return
	_calm()
	main.sky.minutes = 12.0 * 60.0
	await _wait(1.0)

	# 28 km/h: täysi kaasu
	_start(7.7, true, 1.0)
	await _wait(3.0)
	await _shot("01-28kmh-takaa-ylhaalta", Vector3(3.0, 5.0, -12.0), Vector3(0, 0, -3.0))
	await _shot("02-28kmh-keula-sivulta", Vector3(6.0, 1.6, 3.0), Vector3(0, 0, 1.5))
	await _shot("03-28kmh-keula-edesta", Vector3(2.5, 2.0, 9.0), Vector3(0, 0, 1.0))
	await _shot("04-28kmh-pera-lahelta", Vector3(3.0, 2.5, -5.0), Vector3(0, 0, -3.5))
	await _shot("05-28kmh-ylhaalta", Vector3(0.0, 16.0, -6.0), Vector3(0, 0, -7.0))
	await _shot("11-28kmh-harjanne-matalalta", Vector3(4.0, 0.4, 1.4), Vector3(0.6, 0.05, 1.6))
	# FPV: kalastajan silmistä eteen ja alas, veneen sisällä ei vettä
	_view = []
	main.camera_rig.shot_view = false
	main.camera_rig.first_person = true
	main.camera_rig.fpv_pitch = 0.45
	main.camera_rig.yaw = boat.yaw
	await _wait(1.0)
	get_viewport().get_texture().get_image().save_png(_dir.path_join("12-28kmh-fpv.png"))
	print("kuva 12-28kmh-fpv: %.1f km/h" % boat.speed_kmh())
	main.camera_rig.first_person = false

	# 16 km/h: vieraan moottoriveneen vauhti
	_start(4.4, true, 0.35)
	_speed = 4.4
	await _wait(5.0)
	await _shot("06-16kmh-ylhaalta", Vector3(0.0, 16.0, -6.0), Vector3(0, 0, -7.0))

	# Soutu 1,5 m/s
	_start(1.5, false, 0.0)
	_speed = 1.5
	Input.action_press("boat_forward")
	await _wait(6.0)
	await _shot("07-soutu-ylhaalta", Vector3(0.0, 12.0, -3.0), Vector3(0, 0, -4.0))
	Input.action_release("boat_forward")

	# Peruutus: peruutuskaasu −0,4
	_speed = NAN
	_start(-3.2, true, -0.4)
	await _wait(5.0)
	await _shot("08-peruutus-ylhaalta", Vector3(0.0, 12.0, 4.0), Vector3(0, 0, 2.0))

	# Käännös: täysi kaasu, ohjaus täysin sivuun 2 s
	_start(7.7, true, 1.0)
	await _wait(3.0)
	_hold = false
	_view = [Vector3(0.0, 16.0, -5.0), Vector3(0, 0, -6.0)]
	Input.action_press("boat_left")
	await _wait(1.2) # + kuvan 0,8 s = 2 s
	await _shot("09-28kmh-kaannos-ylhaalta", Vector3(0.0, 16.0, -5.0), Vector3(0, 0, -6.0))
	Input.action_release("boat_left")

	# Ilta klo 22.30: vaahto ja roiske himmeinä
	main.sky.minutes = 22.5 * 60.0
	_start(7.7, true, 1.0)
	await _wait(3.0)
	await _shot("10-28kmh-ilta", Vector3(4.5, 2.5, -3.0), Vector3(0, 0, 0.5))
	get_tree().quit()

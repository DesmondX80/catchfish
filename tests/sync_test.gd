extends Node
## Ruudun ja fysiikan tahdin testi: godot --headless --fixed-fps 30 -- --day=180 --synctest
## Fysiikka ajetaan 45 Hz:llä ja ruutu 30 Hz:llä, jolloin ruutujen välillä on
## vuorotellen yksi ja kaksi fysiikka-askelta (kuten 144 Hz:n näytöllä).
## Vene liikkuu silti ruudulla tasaisesti, ja FPV-kamera, kädessä oleva vapa,
## veneen pohjalla oleva vapa ja kalasaavi pysyvät joka ruudulla paikallaan
## rungon ja kalastajan suhteen: ne eivät nyi edestakaisin (#78).

const PHYSICS_HZ := 45

var main: Node
var _log: Array[String] = []
var _step := 0
var _t := 0.0
var _rod_err := 0.0 # kädessä olevan vavan tyvi vavan kiinnityskohdasta (m)
## Paikat ruuduittain: veneen, FPV-kameran (rungon suhteen) ja veneen pohjalla
## olevan vavan tyven (rungon suhteen)
var _boat_path: Array[Vector3] = []
var _eye_path: Array[Vector3] = []
var _stowed_path: Array[Vector3] = []
var _tub_err := 0.0
var _start := Vector3.ZERO


func _ready() -> void:
	main = get_parent()
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	process_priority = 100 # kaikkien muiden jälkeen: tarkistetaan ruudulle piirrettävä tila
	Engine.physics_ticks_per_second = PHYSICS_HZ
	for f in main.population.fish:
		f["wary"] = 1.0e9 # ei tärppejä
	main.camera_rig.first_person = true


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _next() -> void:
	_step += 1
	_t = 0.0


## Piste rungon koordinaateissa
func _in_hull(p: Vector3) -> Vector3:
	return main.boat.hull.global_transform.affine_inverse() * p


func _process(delta: float) -> void:
	_t += delta
	var boat: Boat = main.boat
	var fishing: Fishing = main.fishing
	var rig: CameraRig = main.camera_rig
	match _step:
		0:
			# Kalastusasento, vapa kädessä: kamera ja kalastaja kääntyvät tasaisesti
			rig.yaw += 0.04
			if _t > 1.5 and boat.angler.rod_stow_blend() < 0.001:
				_rod_err = maxf(_rod_err, fishing.rod_point(0.0).distance_to(boat.angler.rod_mount.global_position))
			if _t > 4.0:
				_check("kääntyessä vapa pysyy kalastajan käsissä: tyvi %.1f mm kiinnityskohdasta" % (_rod_err * 1000.0), _rod_err < 0.001)
				# Avovedelle, jossa moottorilla pääsee suoraan eteenpäin
				var deepest := boat.pos
				for i in 4000:
					var p := boat.pos + Vector2(randf_range(-400, 400), randf_range(-400, 400))
					if main.lake.depth_at(p.x, p.y) > main.lake.depth_at(deepest.x, deepest.y):
						deepest = p
				boat.pos = deepest
				boat.velocity = Vector2.ZERO
				boat.motor_running = true
				rig.yaw = boat.yaw
				_next()
		1:
			# Moottoriajo suoraan eteenpäin; mitataan, kun kalastaja on
			# siirtynyt moottorille ja vapa veneen pohjalle
			boat.motor_running = true
			boat.throttle = 0.6
			boat.tiller = 0.0
			boat.yaw_rate = 0.0
			if _t < 6.0:
				return
			_boat_path.append(boat.global_position)
			_eye_path.append(_in_hull(rig.camera.global_position))
			_stowed_path.append(_in_hull(fishing.rod_point(0.0)))
			if main.tub != null:
				var expected: Vector3 = boat.hull.global_transform * CatchTub.ON_BOAT.origin
				_tub_err = maxf(_tub_err, main.tub.global_position.distance_to(expected))
			if _t > 9.0:
				_finish()


## Suurin nykäys: paikan toinen differenssi ruudusta toiseen. Tasaisessa
## liikkeessä se on lähes nolla; jos osa ruuduista saa kaksi fysiikka-askelta
## ja osa yhden, nykäys on askeleen pituuden luokkaa.
func _jerk(path: Array[Vector3]) -> float:
	var worst := 0.0
	for i in range(2, path.size()):
		worst = maxf(worst, (path[i] - path[i - 1] * 2.0 + path[i - 2]).length())
	return worst


func _finish() -> void:
	var moved: float = _boat_path[-1].distance_to(_boat_path[0])
	_check("vene liikkuu moottorilla (%.1f m)" % moved, moved > 2.0)
	var boat_jerk := _jerk(_boat_path)
	_check("vene liikkuu ruudulla tasaisesti: suurin nykäys %.1f mm" % (boat_jerk * 1000.0), boat_jerk < 0.003)
	var eye_jerk := _jerk(_eye_path)
	_check("FPV-kamera liikkuu rungon suhteen tasaisesti: suurin nykäys %.1f mm" % (eye_jerk * 1000.0), eye_jerk < 0.003)
	var rod_jerk := _jerk(_stowed_path)
	_check("veneen pohjalla oleva vapa pysyy rungon mukana: suurin nykäys %.1f mm" % (rod_jerk * 1000.0), rod_jerk < 0.002)
	_check("kalasaavi pysyy rungon mukana: suurin poikkeama %.1f mm" % (_tub_err * 1000.0), _tub_err < 0.001)
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

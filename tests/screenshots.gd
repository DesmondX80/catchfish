extends Node
## Ottaa kuvakaappauksia eri tilanteista kansioon, joka annetaan parametrina:
##   godot --fixed-fps 30 -- --screenshots=/polku/kansioon
## Jokainen kuva: valmistelu (setup), odotus kunnes ehto täyttyy (ready), kuva.

var _dir := ""
var _frame := 0
var _index := 0
var _shots: Array[Dictionary] = []
var main: Node


func _ready() -> void:
	main = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="):
			_dir = arg.split("=")[1]
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	var boat: Boat = main.boat
	_shots = [
		{"name": "0b-keula", "hour": 12.0, "yaw": PI + 0.35, "pitch": 0.6, "distance": 4.0,
			"setup": func():
				boat.pos += boat.forward() * 30.0 # avovedelle, pois laiturin luota
				boat.velocity = Vector2.ZERO,
			"ready": func(): return _frame > 20},
		{"name": "0c-keula-sivu", "hour": 12.0, "yaw": -1.3, "pitch": 0.3, "distance": 3.5,
			"ready": func(): return _frame > 10},
		{"name": "0-vene-lahelta", "hour": 12.0, "yaw": PI / 2.0 + 0.3, "pitch": 0.35, "distance": 4.5},
		{"name": "1-laituri", "hour": 7.0, "yaw": 0.0, "pitch": 0.3, "distance": 9.0},
		{"name": "2-yleiskuva", "hour": 9.0, "yaw": 0.6, "pitch": 0.7, "distance": 40.0},
		{"name": "3-soutu-veto", "hour": 10.0, "yaw": PI / 2.0, "pitch": 0.12, "distance": 6.5,
			"setup": func(): Input.action_press("boat_forward"),
			"ready": func(): return _frame > 60 and _phase_between(0.22, 0.3)},
		{"name": "4-soutu-palautus", "hour": 10.0, "yaw": PI / 2.0, "pitch": 0.12, "distance": 6.5,
			"ready": func(): return _phase_between(0.72, 0.8)},
		{"name": "5-soutuvana", "hour": 10.0, "yaw": 0.0, "pitch": 0.45, "distance": 12.0,
			"ready": func(): return _frame > 240},
		{"name": "6-moottorivana", "hour": 11.0, "yaw": 0.15, "pitch": 0.5, "distance": 16.0,
			"setup": func():
				Input.action_release("boat_forward")
				boat.motor_running = true
				boat.throttle = 1.0,
			"ready": func(): return _frame > 300},
		{"name": "7-airot-veneessa", "hour": 11.0, "yaw": 0.6, "pitch": 0.9, "distance": 4.5,
			"setup": func(): boat.throttle = 0.15,
			"ready": func(): return _frame > 90},
		{"name": "8-ilta", "hour": 22.5, "yaw": 2.8, "pitch": 0.2, "distance": 10.0},
		{"name": "9-kalamallit", "hour": 12.0, "yaw": PI / 2.0, "pitch": 0.35, "distance": 1.6,
			"setup": func(): _showcase(0.25),
			"ready": func(): return _frame > 20},
		{"name": "10-kalat-pinnan-alla", "hour": 12.0, "yaw": PI / 2.0, "pitch": 0.6, "distance": 1.6,
			"setup": func(): _showcase(-0.35),
			"ready": func(): return _frame > 20},
		{"name": "11-matalikko", "hour": 12.0, "yaw": 0.4, "pitch": 1.1, "distance": 5.0,
			"setup": func(): _clear_showcase(); _move_near_fish(),
			"ready": func(): return _frame > 60},
		{"name": "12-loysa-siima", "hour": 12.0, "yaw": PI / 2.0, "pitch": 0.15, "distance": 7.0,
			"setup": func():
				main.camera_rig.yaw = main.boat.yaw
				main.fishing.power = 0.55
				main.fishing._cast(),
			"ready": func(): return main.fishing.state == Fishing.State.RETRIEVING and _frame > 60},
		{"name": "13-kelaus-kirea", "hour": 12.0, "yaw": PI / 2.0, "pitch": 0.15, "distance": 7.0,
			"setup": func(): Input.action_press("reel"),
			"ready": func(): return _frame > 75},
		{"name": "14-ahven-koukussa", "hour": 12.0, "yaw": PI / 2.0, "pitch": 0.12, "distance": 6.0,
			"setup": func():
				Input.action_release("reel")
				_hook("ahven", 0.2),
			"ready": func(): return _frame > 40},
		{"name": "15-hauki-koukussa", "hour": 12.0, "yaw": PI / 2.0, "pitch": 0.12, "distance": 6.0,
			"setup": func(): _hook("hauki", 4.0),
			"ready": func(): return _frame > 40},
		{"name": "16-kalastaja-edesta", "hour": 12.0, "yaw": PI - 0.35, "pitch": 0.1, "distance": 2.4,
			"setup": func():
				main.fishing.state = Fishing.State.READY
				main.fishing._fish_index = -1
				main.boat.motor_running = true # moottoriasennossa kasvot keulaan päin
				main.boat.throttle = 0.0,
			"ready": func(): return _frame > 60},
		{"name": "16b-kalastaja-sivulta", "hour": 12.0, "yaw": PI / 2.0, "pitch": 0.1, "distance": 2.6,
			"setup": func(): main.boat.motor_running = false,
			"ready": func(): return _frame > 60},
		{"name": "17-soutaja", "hour": 12.0, "yaw": PI / 2.0 + 0.3, "pitch": 0.2, "distance": 3.6,
			"setup": func(): Input.action_press("boat_forward"),
			"ready": func(): return _frame > 60 and _phase_between(0.3, 0.38)},
		{"name": "18-moottoriajo", "hour": 12.0, "yaw": PI / 2.0 - 0.4, "pitch": 0.25, "distance": 4.0,
			"setup": func():
				Input.action_release("boat_forward")
				main.boat.motor_running = true
				main.boat.throttle = 0.4,
			"ready": func(): return _frame > 90},
		{"name": "19-selkea", "hour": 11.0, "yaw": 0.3, "pitch": 0.08, "distance": 9.0,
			"setup": func():
				main.boat.motor_running = false
				main.boat.throttle = 0.0
				main.weather.set_kind(Weather.Kind.CLEAR, true),
			"ready": func(): return _frame > 30},
		{"name": "20-puolipilvista", "hour": 11.0, "yaw": 0.3, "pitch": 0.08, "distance": 9.0,
			"setup": func(): main.weather.set_kind(Weather.Kind.PARTLY, true),
			"ready": func(): return _frame > 30},
		{"name": "21-pilvista", "hour": 11.0, "yaw": 0.3, "pitch": 0.08, "distance": 9.0,
			"setup": func(): main.weather.set_kind(Weather.Kind.CLOUDY, true),
			"ready": func(): return _frame > 30},
		{"name": "22-sade", "hour": 11.0, "yaw": 0.3, "pitch": 0.08, "distance": 9.0,
			"setup": func(): main.weather.set_kind(Weather.Kind.RAIN, true),
			"ready": func(): return _frame > 90},
		{"name": "23-rankkasade", "hour": 11.0, "yaw": 0.3, "pitch": 0.08, "distance": 9.0,
			"setup": func(): main.weather.set_kind(Weather.Kind.HEAVY_RAIN, true),
			"ready": func(): return _frame > 90},
		{"name": "24-pisararenkaat", "hour": 11.0, "yaw": PI / 2.0, "pitch": 0.75, "distance": 3.0,
			"ready": func(): return _frame > 30},
		{"name": "25-veneenlaskuluiska", "hour": 12.0, "yaw": PI - 0.9, "pitch": 0.45, "distance": 24.0,
			"setup": func():
				main.weather.set_kind(Weather.Kind.CLEAR, true)
				_go_to_start(2),
			"ready": func(): return _frame > 40},
		{"name": "26-luiska-lahelta", "hour": 12.0, "yaw": PI - 1.5, "pitch": 0.2, "distance": 11.0,
			"ready": func(): return _frame > 20},
	]


func _phase_between(a: float, b: float) -> bool:
	var f := fmod(main.boat._row_phase, 1.0)
	return f >= a and f <= b


func _process(_delta: float) -> void:
	if _index >= _shots.size():
		get_tree().quit()
		return
	_frame += 1
	var shot: Dictionary = _shots[_index]
	if _frame == 1:
		main.sky.minutes = shot["hour"] * 60.0
		if shot.has("setup"):
			shot["setup"].call()
	main.camera_rig.yaw = main.boat.yaw + shot["yaw"]
	main.camera_rig.pitch = shot["pitch"]
	main.camera_rig.distance = shot["distance"]
	var ready: bool = shot["ready"].call() if shot.has("ready") else _frame > 15
	if ready or _frame > 900:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_dir.path_join(shot["name"] + ".png"))
		print("kuva ", shot["name"], " ruutu ", _frame)
		_index += 1
		_frame = 0


var _showcase_nodes: Array[Node3D] = []


## Neljä lajia rinnakkain veneen vieressä annetulla korkeudella (y)
func _showcase(y: float) -> void:
	_clear_showcase()
	main.boat.motor_running = false
	main.boat.throttle = 0.0
	main.boat.velocity = Vector2.ZERO
	var boat: Boat = main.boat
	var side := boat.right()
	var fwd := boat.forward()
	var i := 0
	for sp in Species.DATA:
		var node := MeshInstance3D.new()
		node.mesh = FishModels.mesh(sp)
		node.material_override = FishModels.material(sp).duplicate()
		node.material_override.set_shader_parameter("swim_rate", 3.0)
		add_child(node)
		var p := boat.pos - side * 1.7 + fwd * (1.5 - i * 1.0)
		node.global_position = Vector3(p.x, y, p.y)
		node.look_at(node.global_position + Vector3(fwd.x, 0, fwd.y), Vector3.UP)
		node.scale = Vector3.ONE * 0.85
		_showcase_nodes.append(node)
		i += 1


func _clear_showcase() -> void:
	for n in _showcase_nodes:
		n.queue_free()
	_showcase_nodes.clear()


## Vene paikkaan, jonka lähellä on matalassa kaloja
func _move_near_fish() -> void:
	var pop: FishPopulation = main.population
	var lake: LakeData = main.lake
	var best := -1
	var best_count := 0
	for i in range(0, pop.fish.size(), 7):
		var f: Dictionary = pop.fish[i]
		if f["depth"] > 0.9:
			continue
		var near := 0
		for j in pop.fish_near(f["pos"], 6.0):
			if pop.fish[j]["depth"] < 1.2:
				near += 1
		if near > best_count and lake.depth_at(f["pos"].x, f["pos"].y) > 0.6:
			best_count = near
			best = i
	if best >= 0:
		var boat: Boat = main.boat
		boat.pos = pop.fish[best]["pos"] + Vector2(3, 0)
		boat.velocity = Vector2.ZERO
		print("Matalikko: %d kalaa alle 1,2 m syvyydessä 6 m säteellä" % best_count)



## Kala koukussa veneen edessä n. 12 m päässä, ryntää täysillä
func _hook(sp: String, weight: float) -> void:
	var f: Fishing = main.fishing
	var boat: Boat = main.boat
	var idx := 0
	for i in main.population.fish.size():
		if main.population.fish[i]["sp"] == sp:
			idx = i
			break
	main.population.fish[idx]["weight"] = weight
	f._fish_index = idx
	f._fish = main.population.fish[idx]
	var p := boat.pos + boat.forward() * 12.0
	f._fish_pos = Vector3(p.x, -0.6, p.y)
	f.lure_pos = f._fish_pos
	f.line_out = f.rod_tip().distance_to(f._fish_pos)
	f._stamina = 1.0
	f._run_intensity = 1.0
	f._run_dir = boat.forward()
	f._run_timer = 10.0
	f.drag_kg = 6.0
	f.state = Fishing.State.FIGHT



func _go_to_start(i: int) -> void:
	var boat: Boat = main.boat
	main.lake.select_start(i)
	boat.pos = Vector2(main.lake.start_position.x, main.lake.start_position.z)
	boat.yaw = main.lake.start_yaw
	boat.velocity = Vector2.ZERO
	boat.motor_running = false
	boat.throttle = 0.0
	Input.action_release("boat_forward")

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

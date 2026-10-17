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

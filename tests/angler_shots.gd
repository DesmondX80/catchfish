extends Node
## Kalastajan lähikuvat eri asennoista ja suunnista (vaatii ikkunan):
##   godot --fixed-fps 30 -- --day=180 --anglershots=/polku/kansioon
## Talvikuvat: --day=40 (kalastaja jäällä).

var _dir := ""
var _frame := 0
var _index := 0
var _shots: Array[Dictionary] = []
var main: Node


func _ready() -> void:
	main = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--anglershots="):
			_dir = arg.split("=")[1]
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	main.weather.set_kind(Weather.Kind.CLEAR, true)
	var boat: Boat = main.boat
	if boat.on_ice:
		_shots = [
			{"name": "jaa-seisoo", "yaw": PI - 0.5, "pitch": 0.1, "distance": 2.6},
			{"name": "jaa-kavelee", "yaw": PI / 2.0, "pitch": 0.1, "distance": 3.0,
				"setup": func(): Input.action_press("boat_forward"),
				"ready": func(): return _frame > 40},
			{"name": "jaa-sivulta", "yaw": -PI / 2.0 + 0.3, "pitch": 0.15, "distance": 2.6,
				"setup": func(): Input.action_release("boat_forward"),
				"ready": func(): return _frame > 40},
		]
		return
	_shots = [
		{"name": "1-edesta", "yaw": PI - 0.35, "pitch": 0.1, "distance": 2.2,
			"setup": func():
				boat.pos += boat.forward() * 30.0
				boat.velocity = Vector2.ZERO
				boat.motor_running = true # moottoriasennossa kasvot keulaan päin
				boat.throttle = 0.0,
			"ready": func(): return _frame > 60},
		{"name": "2-kasvot", "yaw": PI - 0.25, "pitch": 0.05, "distance": 0.9,
			"ready": func(): return _frame > 20},
		{"name": "2b-kasvot-sivulta", "yaw": PI / 2.0 + 0.9, "pitch": 0.05, "distance": 0.9,
			"ready": func(): return _frame > 20},
		{"name": "3-sivulta", "yaw": PI / 2.0, "pitch": 0.1, "distance": 2.4,
			"setup": func(): boat.motor_running = false,
			"ready": func(): return _frame > 40},
		{"name": "4-takaa", "yaw": 0.25, "pitch": 0.25, "distance": 2.4},
		{"name": "5-soutaa", "yaw": PI / 2.0 + 0.3, "pitch": 0.15, "distance": 3.0,
			"setup": func(): Input.action_press("boat_forward"),
			"ready": func(): return _frame > 90},
		{"name": "6-moottori", "yaw": PI - 0.6, "pitch": 0.15, "distance": 3.0,
			"setup": func():
				Input.action_release("boat_forward")
				boat.motor_running = true
				boat.throttle = 0.0,
			"ready": func(): return _frame > 60},
		{"name": "7-kelaa", "yaw": PI / 2.0 + 0.4, "pitch": 0.1, "distance": 2.6,
			"setup": func():
				boat.motor_running = false
				boat.velocity = Vector2.ZERO
				main.camera_rig.yaw = boat.yaw
				main.fishing.power = 0.6
				main.fishing._cast(),
			"ready": func():
				if main.fishing.state == Fishing.State.RETRIEVING:
					Input.action_press("reel")
				return _frame > 150},
	]


func _process(_delta: float) -> void:
	if _index >= _shots.size():
		get_tree().quit()
		return
	_frame += 1
	var shot: Dictionary = _shots[_index]
	if _frame == 1:
		main.sky.minutes = 12.0 * 60.0
		if shot.has("setup"):
			shot["setup"].call()
	main.camera_rig.yaw = main.boat.yaw + shot["yaw"]
	main.camera_rig.pitch = shot["pitch"]
	main.camera_rig.distance = shot["distance"]
	var ready: bool = shot["ready"].call() if shot.has("ready") else _frame > 15
	if ready or _frame > 600:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_dir.path_join(shot["name"] + ".png"))
		print("kuva ", shot["name"])
		_index += 1
		_frame = 0

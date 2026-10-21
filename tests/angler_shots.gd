extends Node
## Kalastajan lähikuvat eri asennoista ja suunnista (vaatii ikkunan):
##   godot --fixed-fps 30 -- --day=180 --anglershots=/polku/kansioon
## Talvikuvat: --day=40 (kalastaja jäällä, pilkkihaalari ja pipo).
## --anglershots-only=6,8 ottaa vain kuvat, joiden nimi alkaa annetuilla tunnuksilla
## (valmistelut ajetaan silti kaikille, jotta tilanne on sama).

var _dir := ""
var _frame := 0
var _index := 0
var _shots: Array[Dictionary] = []
var _only: PackedStringArray = []
var main: Node


func _ready() -> void:
	main = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--anglershots="):
			_dir = arg.split("=")[1]
		if arg.begins_with("--anglershots-only="):
			_only = arg.split("=")[1].split(",")
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	main.weather.set_kind(Weather.Kind.CLEAR, true)
	var boat: Boat = main.boat
	if boat.on_ice:
		_shots = [
			{"name": "jaa-1-seisoo", "yaw": PI - 0.5, "pitch": 0.1, "distance": 2.6,
				"ready": func(): return _frame > 30},
			{"name": "jaa-2-kasvot", "close": Vector3(0.2, 0.05, -1.1), "look": 0.0},
			{"name": "jaa-3-kavelee", "yaw": PI / 2.0, "pitch": 0.1, "distance": 3.0,
				"setup": func(): Input.action_press("boat_forward"),
				"ready": func(): return _frame > 40},
			{"name": "jaa-4-kairaa", "yaw": PI / 2.0 + 0.4, "pitch": 0.15, "distance": 2.8,
				"setup": func():
					Input.action_release("boat_forward")
					_press("cast", true),
				"ready": func(): return main.fishing.state == Fishing.State.DRILLING and _frame > 40},
			{"name": "jaa-5-pilkkii", "yaw": PI / 2.0 + 0.5, "pitch": 0.15, "distance": 2.8,
				"ready": func():
					# Kairaus loppuun, sitten pilkki avantoon ja kalastaja ämpärille
					if main.fishing.state != Fishing.State.DRILLING and Input.is_action_pressed("cast"):
						_press("cast", false)
					elif main.fishing.state == Fishing.State.READY and main.fishing.at_hole() and _frame % 30 == 0:
						_press("cast", true)
						_press("cast", false)
					return main.fishing.state == Fishing.State.RETRIEVING and _frame > 60},
		]
		return
	_shots = [
		{"name": "1-edesta", "yaw": PI - 0.35, "pitch": 0.1, "distance": 2.2,
			"setup": func():
				boat.pos += boat.forward() * 30.0
				boat.velocity = Vector2.ZERO,
			"ready": func(): return _frame > 40},
		{"name": "2-kasvot", "yaw": PI - 0.2, "pitch": 0.05, "distance": 1.1},
		{"name": "3-sivulta", "yaw": PI / 2.0, "pitch": 0.1, "distance": 2.4},
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
		{"name": "8-lahikuva", "close": Vector3(0.15, 0.05, -1.0), "look": 0.05},
		{"name": "9-kadet", "close": Vector3(0.6, 0.0, -1.4), "look": -0.45},
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


func _press(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


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
	if shot.has("close"):
		_close_up(shot["close"], shot["look"])
	else:
		main.camera_rig.shot_view = false
		main.camera_rig.yaw = main.boat.yaw + shot["yaw"]
		main.camera_rig.pitch = shot["pitch"]
		main.camera_rig.distance = shot["distance"]
	var ready: bool = shot["ready"].call() if shot.has("ready") else _frame > 15
	if shot.has("close") and _frame <= 30:
		ready = false # kamera ehtii siirtyä
	if ready or _frame > 600:
		var wanted := _only.is_empty()
		for prefix in _only:
			wanted = wanted or String(shot["name"]).begins_with(prefix + "-")
		if wanted:
			var img := get_viewport().get_texture().get_image()
			img.save_png(_dir.path_join(shot["name"] + ".png"))
			print("kuva ", shot["name"])
		_index += 1
		_frame = 0


## Lähikuva kalastajan päästä: silmä kalastajan omissa koordinaateissa pään
## suhteen (-Z = kasvojen suunta), kamera katsoo päätä (look = korkeus pään luusta)
func _close_up(eye: Vector3, look: float) -> void:
	var angler: Angler = main.boat.angler
	var head := angler._bone_pos(angler._bones["Head"]) + Vector3(0, 0.12, 0)
	var basis := angler.global_basis.orthonormalized()
	var from := head + basis * eye
	var at := head + Vector3(0, look, 0)
	main.camera_rig.shot = Transform3D(Basis.looking_at(at - from), from)
	main.camera_rig.shot_view = true

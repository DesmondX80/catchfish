extends Node
## FPV-kameran kuvat (vaatii ikkunan):
##   godot --fixed-fps 30 -- --day=180 --fpvshots=/polku/kansioon
## Kalastus eteenpäin ja alas, soutu ja moottoriajo kalastajan silmistä.

var _dir := ""
var _frame := 0
var _index := 0
var _shots: Array[Dictionary] = []
var main: Node


func _ready() -> void:
	main = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fpvshots="):
			_dir = arg.split("=")[1]
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	main.weather.set_kind(Weather.Kind.CLEAR, true)
	main.camera_rig.first_person = true
	_shots = [
		{"name": "1-kalastus", "pitch": 0.25},
		{"name": "2-alas", "pitch": 1.0},
		{"name": "3-sivulle", "pitch": 0.4, "turn": 1.2},
		{"name": "4-soutu", "pitch": 0.3, "turn": -1.2,
			"setup": func(): Input.action_press("boat_forward")},
		{"name": "5-moottori", "pitch": 0.3, "turn": 0.0,
			"setup": func():
				Input.action_release("boat_forward")
				var ev := InputEventAction.new()
				ev.action = "motor_toggle"
				ev.pressed = true
				Input.parse_input_event(ev)
				Input.action_press("boat_forward")},
	]


func _process(_delta: float) -> void:
	_frame += 1
	if _index >= _shots.size():
		get_tree().quit()
		return
	var s: Dictionary = _shots[_index]
	var rig: CameraRig = main.camera_rig
	if _frame == 1:
		if s.has("setup"):
			s["setup"].call()
		rig.fpv_pitch = s["pitch"]
		rig.yaw = main.boat.yaw + s.get("turn", 0.0)
	if _frame == 60:
		DirAccess.make_dir_recursive_absolute(_dir)
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, s["name"]])
		_index += 1
		_frame = 0

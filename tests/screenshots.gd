extends Node
## Ottaa kuvakaappauksia eri tilanteista kansioon, joka annetaan parametrina:
##   godot -- --screenshots=/polku/kansioon

var _dir := ""
var _frame := 0
var _shots := [
	{"name": "1-laituri", "hour": 7.0, "yaw": 0.0, "pitch": 0.3, "distance": 9.0},
	{"name": "2-yleiskuva", "hour": 9.0, "yaw": 0.6, "pitch": 0.7, "distance": 40.0},
	{"name": "3-heitto", "hour": 12.0, "yaw": 0.2, "pitch": 0.15, "distance": 6.0, "cast": true},
	{"name": "4-ilta", "hour": 22.5, "yaw": 2.8, "pitch": 0.2, "distance": 10.0},
]
var _index := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="):
			_dir = arg.split("=")[1]
	GameInput.force_active = true


func _process(_delta: float) -> void:
	_frame += 1
	var main := get_parent()
	if _index >= _shots.size():
		get_tree().quit()
		return
	var shot: Dictionary = _shots[_index]
	if _frame == 1:
		main.sky.minutes = shot["hour"] * 60.0
		main.camera_rig.yaw = main.boat.yaw + shot["yaw"]
		main.camera_rig.pitch = shot["pitch"]
		main.camera_rig.distance = shot["distance"]
		if shot.get("cast", false):
			main.fishing.power = 0.7
			main.fishing._cast()
	elif _frame == 12:
		print("kuva ", shot["name"], " ", Time.get_ticks_msec())
	elif _frame == 15:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_dir.path_join(shot["name"] + ".png"))
		_index += 1
		_frame = 0

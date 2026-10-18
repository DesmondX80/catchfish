extends Node
## Vuodenaikakuvat: godot -- --day=N --seasonshot=/kansio
## Ottaa yleiskuvan ja rantakuvan keskipäivällä selkeällä säällä.

var _dir := ""
var _day := 0
var _frame := 0
var main: Node


func _ready() -> void:
	main = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seasonshot="):
			_dir = arg.split("=")[1]
		elif arg.begins_with("--day="):
			_day = int(arg.split("=")[1])
	main.hud.set_paused_view(false)
	main.sky.minutes = 12.5 * 60.0
	main.weather.set_kind(Weather.Kind.CLEAR, true)


func _process(_delta: float) -> void:
	_frame += 1
	main.sky.minutes = 12.5 * 60.0
	var rig: CameraRig = main.camera_rig
	if _frame == 2:
		rig.yaw = main.boat.yaw + 0.6
		rig.pitch = 0.6
		rig.distance = 40.0
	elif _frame == 40:
		get_viewport().get_texture().get_image().save_png(_dir.path_join("paiva-%03d-yleis.png" % _day))
		rig.yaw = main.boat.yaw + PI - 0.4
		rig.pitch = 0.15
		rig.distance = 12.0
	elif _frame == 70:
		get_viewport().get_texture().get_image().save_png(_dir.path_join("paiva-%03d-ranta.png" % _day))
		print("vuodenaika päivä %d: %s" % [_day, main.current_season().name])
		get_tree().quit()

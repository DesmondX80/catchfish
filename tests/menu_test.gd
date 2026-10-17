extends Node
## Aloitusvalikon testi oikeilla hiiren klikkauksilla:
##   godot -- --menutest=/polku/kuviin
## Päävalikko → Mene kalalle → klikkaus aloituspaikkaan 2 → peli alkaa siitä → kartta (K).

var _dir := ""
var _frame := 0
var _step := 0
var _log: Array[String] = []
var main: Node


func _ready() -> void:
	main = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--menutest="):
			_dir = arg.split("=")[1]


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(_dir.path_join(name + ".png"))


func _click(at: Vector2) -> void:
	# Ikkunan pikseleinä: viewportin koordinaatit skaalataan ikkunan kokoon
	var scale := Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at * scale
		ev.global_position = ev.position
		Input.parse_input_event(ev)


func _move(at: Vector2) -> void:
	var scale := Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size
	var ev := InputEventMouseMotion.new()
	ev.position = at * scale
	ev.global_position = ev.position
	Input.parse_input_event(ev)


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _process(_delta: float) -> void:
	_frame += 1
	match _frame:
		20:
			_shot("m1-paavalikko")
			var go: Button = main.menu._main.find_children("*", "Button", true, false)[0]
			_click(go.get_global_rect().get_center())
		30:
			_check("kartta aukesi", main.menu._map_view.visible)
			var map: LakeMap = main.menu._map
			var target := map.get_global_rect().position + map._start_point(1)
			_move(target)
		34:
			_shot("m2-kartta")
			var map: LakeMap = main.menu._map
			_check("aloituspaikka 2 korostuu hiiren alla", map.hovered == 1)
			_click(map.get_global_rect().position + map._start_point(1))
		_:
			if _step == 0 and main.running:
				_step = 1
				_frame = 1000
				var s: Dictionary = main.lake.starts[1]
				_check("peli alkoi paikasta %s" % s["name"], main.boat.pos.distance_to(Vector2(s["x"], s["z"])) < 1.0)
			if _frame == 1030:
				main.hud.set_paused_view(false)
				main.camera_rig.yaw = main.boat.yaw + PI + 0.5 # katse rantaan päin
				main.camera_rig.pitch = 0.55
				main.camera_rig.distance = 26.0
			if _frame == 1050:
				_shot("m3b-laituri-ja-parkkipaikka")
				main.camera_rig.yaw = main.boat.yaw + 0.6
				main.camera_rig.pitch = 0.25
				main.camera_rig.distance = 9.0
			if _frame == 1060:
				_shot("m3-peli-alkoi")
				var ev := InputEventAction.new()
				ev.action = "map"
				ev.pressed = true
				Input.parse_input_event(ev)
			if _frame == 1070:
				_check("kartta aukesi pelissä", main.hud._map_panel.visible)
				_shot("m4-kartta-pelissa")
				for l in _log:
					print(l)
				get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)
	if _frame > 2000:
		print("VIRHE aikakatkaisu")
		get_tree().quit(1)

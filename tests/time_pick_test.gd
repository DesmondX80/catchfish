extends Node
## Aloituspaikan valinnan aika- ja säävalintojen testi:
##   godot -- --timepicktest=/polku/kuviin
## Kytkin ja aloituspaikka klikataan oikealla hiirellä, pudotusvalikoiden
## valinnat tehdään ohjelmallisesti (select + item_selected).

var _dir := ""
var _log: Array[String] = []
var _step := 0
var _t := 0.0
var main: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--timepicktest="):
			_dir = arg.split("=")[1]


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(_dir.path_join(name + ".png"))


func _click_at(at_viewport: Vector2) -> void:
	var scale := Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size
	var at := at_viewport * scale
	Input.warp_mouse(at)
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		Input.parse_input_event(ev)


func _click(c: Control) -> void:
	_click_at(c.get_global_rect().get_center())


func _next() -> void:
	_step += 1
	_t = 0.0


func _pick(option: OptionButton, index: int) -> void:
	option.select(index)
	option.item_selected.emit(index)


func _process(delta: float) -> void:
	_t += delta
	var m: StartMenu = main.menu
	match _step:
		0:
			if _t > 0.5:
				for b in m.find_children("*", "Button", true, false):
					if b.text == "Mene kalalle":
						_click(b)
				_next()
		1:
			if _t > 0.4:
				_check("kartta aukesi", m._map_view.visible)
				_check("todellinen aika oletuksena pois", not m._map_real.button_pressed)
				_check("vuodenaika- ja kellonaikavalinnat käytössä", not m._season_pick.disabled and not m._time_pick.disabled)
				_check("oletus: kesä, aamu 5.30", m._season_pick.selected == 1 and m._time_pick.selected == 0)
				_click(m._map_real)
				_next()
		2:
			if _t > 0.3:
				_check("todellinen aika päälle -> valinnat lukittu", Settings.real_world and m._season_pick.disabled)
				_click(m._map_real)
				_next()
		3:
			if _t > 0.3:
				_check("pois päältä -> valinnat taas käytössä", not Settings.real_world and not m._season_pick.disabled)
				_pick(m._season_pick, 4) # talvi
				_pick(m._time_pick, 2) # keskipäivä
				_next()
		4:
			if _t > 0.3:
				_check("valittu talvi ja keskipäivä", Settings.season_index == 4 and Settings.time_index == 2)
				_shot("aika-ja-saa-valinta")
				var map: LakeMap = m._map
				_click_at(map.get_global_rect().position + map._start_point(1))
				_next()
		5:
			if main.running:
				_next()
			elif _t > 30.0:
				_check("peli käynnistyi", false)
				_done()
		6:
			if _t > 1.5:
				var sky: SkyTime = main.sky
				_check("kellonaika 12.00 (%s)" % sky.clock_text(), absf(sky.minutes - 720.0) < 3.0)
				_check("vuodenaika talvi (päivä %d)" % sky.day_of_year, sky.day_of_year == 40)
				_check("järvi jäässä, kävellään", main.boat.on_ice)
				main.hud.set_paused_view(false)
				main.camera_rig.pitch = 0.3
				main.camera_rig.distance = 7.0
				_next()
		7:
			if _t > 0.8:
				_shot("talvi-keskipaiva")
				_done()


func _done() -> void:
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

extends Node
## Asetusten testi oikeilla hiiren klikkauksilla ja oikealla verkkohaulla:
##   godot -- --settingstest=/polku/kuviin
## Säätietojen tulkinta tarkistetaan lisäksi valmiilla esimerkkidatalla.

var _dir := ""
var _log: Array[String] = []
var main: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--settingstest="):
			_dir = arg.split("=")[1]
	_parsing_checks()


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(_dir.path_join(name + ".png"))


func _click(control: Control) -> void:
	var scale := Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size
	var at := control.get_global_rect().get_center() * scale
	Input.warp_mouse(at)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		Input.parse_input_event(ev)


func _button(text: String) -> Button:
	for b in main.menu.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			return b
	return null


## Ilmatieteen laitoksen ja Open-Meteon vastausten tulkinta
func _parsing_checks() -> void:
	var xml := ""
	for row in [["08:40", "t2m", "6.6"], ["08:50", "t2m", "6.7"], ["08:50", "ws_10min", "2.5"], ["08:50", "wg_10min", "3.4"],
			["08:50", "wd_10min", "25.0"], ["08:50", "n_man", "6.0"], ["08:50", "wawa", "62.0"], ["08:50", "r_1h", "NaN"]]:
		xml += "<BsWfs:Time>2026-10-18T%s:00Z</BsWfs:Time>\n<BsWfs:ParameterName>%s</BsWfs:ParameterName>\n<BsWfs:ParameterValue>%s</BsWfs:ParameterValue>\n" % row
	var d := RealWeather.parse_fmi(xml)
	_check("FMI: viimeisin lämpötila 6,7 °C", is_equal_approx(d.get("temperature", 0.0), 6.7))
	_check("FMI: kohtalainen sade (wawa 62) -> sade 0,5", is_equal_approx(d.get("precipitation", 0.0), 0.5) and not d["snow"])
	_check("FMI: sateella pilvisyys vähintään 0,9", d.get("cloud", 0.0) >= 0.9)
	_check("FMI: tuuli 2,5 m/s, puuska 3,4", is_equal_approx(d["wind_speed"], 2.5) and is_equal_approx(d["wind_gust"], 3.4))
	_check("FMI: puuttuvat perustiedot -> tyhjä", RealWeather.parse_fmi("<x/>").is_empty())
	var om := RealWeather.parse_open_meteo('{"current":{"time":"2026-10-18T11:45","temperature_2m":2.9,"precipitation":0.0,"snowfall":0.0,"cloud_cover":15,"wind_speed_10m":1.7,"wind_direction_10m":24,"wind_gusts_10m":4.2,"weather_code":0}}')
	_check("Open-Meteo: pilvisyys 15 % -> 0,15, ei sadetta", is_equal_approx(om["cloud"], 0.15) and om["precipitation"] == 0.0)
	_check("lumisade tunnistetaan (wawa 71)", RealWeather.precipitation_from_wawa(71)[1])
	var w := Weather.new()
	w.apply_real({"source": "x", "time": "", "temperature": 1.0, "wind_speed": 3.0, "wind_gust": 5.0, "wind_from_deg": 0.0, "cloud": 0.2, "precipitation": 0.0, "snow": false}, true)
	var v := w.vector().normalized()
	_check("pohjoistuuli puhaltaa etelään (+Z)", v.y > 0.99)
	w.free()


var _step := 0
var _t := 0.0


## Etenee vaihe kerrallaan; _t on vaiheen kesto sekunteina
func _next() -> void:
	_step += 1
	_t = 0.0


func _done() -> void:
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)


func _process(delta: float) -> void:
	_t += delta
	match _step:
		0:
			if _t > 0.5:
				_click(_button("Asetukset"))
				_next()
		1:
			if _t > 0.3:
				_check("Asetukset aukesivat", main.menu._settings.visible and not main.menu._main.visible)
				_check("oletuksena pois päältä", not main.menu._real_toggle.button_pressed)
				_click(main.menu._real_toggle)
				_next()
		2:
			if _t > 0.3:
				_check("valinta kytkeytyi päälle", Settings.real_world)
				_next()
		3:
			var label: String = main.menu._weather_label.text
			if label.begins_with("Nyt Saloisissa") or label.begins_with("Säätietoja") or _t > 25.0:
				_check("sää haettiin verkosta: " + label.replace("\n", " "), label.begins_with("Nyt Saloisissa"))
				_shot("asetukset")
				_click(_button("Takaisin"))
				_next()
		4:
			if _t > 0.3:
				_click(_button("Mene kalalle"))
				_next()
		5:
			if _t > 0.3:
				# Aloituspaikka reagoi klikkaukseen, kun hiiri on ensin sen päällä
				var map: LakeMap = main.menu._map
				_move_to(map.get_global_rect().position + map._start_point(0))
				_next()
		6:
			if _t > 0.3:
				var map: LakeMap = main.menu._map
				_check("aloituspaikka korostuu hiiren alla", map.hovered == 0)
				_click_at(map.get_global_rect().position + map._start_point(0))
				_next()
		7:
			if main.running and main.weather.real_mode:
				_next()
			elif _t > 40.0:
				_check("peli käynnistyi todellisella säällä", false)
				_done()
		8:
			if _t > 2.0:
				var now := Time.get_datetime_dict_from_system()
				var game_minutes: float = main.sky.minutes
				var real_minutes: float = now["hour"] * 60.0 + now["minute"]
				_check("pelin kello = tietokoneen kello (%s)" % main.sky.clock_text(), absf(game_minutes - real_minutes) < 2.0)
				_check("päivämäärä: vuoden %d. päivä" % main.sky.day_of_year, main.sky.day_of_year > 1)
				_check("todellinen sää käytössä: %s" % main.weather.description(), main.weather.real_mode and not is_nan(main.weather.temperature))
				main.hud.set_paused_view(false)
				main.camera_rig.pitch = 0.2
				main.camera_rig.distance = 9.0
				_next()
		9:
			if _t > 1.0:
				_check("lähde: " + main.weather.real_source, main.weather.real_source != "")
				_check("HUD näyttää lämpötilan: " + main.hud._status.text.split("\n")[1], "°C" in main.hud._status.text)
				_shot("peli-todellinen-saa")
				_done()


func _move_to(at_viewport: Vector2) -> void:
	var scale := Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size
	var ev := InputEventMouseMotion.new()
	ev.position = at_viewport * scale
	ev.global_position = ev.position
	Input.parse_input_event(ev)


func _click_at(at_viewport: Vector2) -> void:
	var scale := Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size
	var at := at_viewport * scale
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		Input.parse_input_event(ev)

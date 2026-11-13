extends Node
## Asetusten testi oikeilla hiiren klikkauksilla ja oikealla verkkohaulla (vaatii ikkunan):
##   GALLIUM_DRIVER=d3d12 MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA timeout 300 godot-4.7.2 --fixed-fps 30 --disable-vsync -- --settingstest=/polku/kuviin
## Aja myös ilman --fixed-fps 30 -lippua (CATCHFISH-122: jumi ikkunassa molemmilla).
## Vahtiajastin päättää testin VIRHEeseen, jos se kestää yli TIME_LIMIT sekuntia.
## Säätietojen tulkinta tarkistetaan lisäksi valmiilla esimerkkidatalla.
## Veden laatu: rivi on asetuksissa, valinta tallentuu ja tulee voimaan heti
## myös kesken kalareissun (lähiveden verkko harvenee).

var _dir := ""
var _log: Array[String] = []
var main: Node
var _started_ms := 0 # seinäkello testin alussa (vahtiajastin)
var _finished := false # tulokset tulostettu, odotetaan lopetusta

const TIME_LIMIT := 180.0 # sekuntia seinäkelloa koko testille


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = get_parent()
	_started_ms = Time.get_ticks_msec()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--settingstest="):
			_dir = arg.split("=")[1]
	_parsing_checks()


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(_dir.path_join(name + ".png"))


## Klikkaa painiketta; puuttuva painike päättää testin VIRHEeseen (ei ajonaikaista virhettä)
func _click(control: Control) -> bool:
	if control == null:
		_check("painiketta ei löytynyt (vaihe %d)" % _step, false)
		_done()
		return false
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
	return true


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
	if _finished:
		return
	_finished = true
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)


func _process(delta: float) -> void:
	if _finished:
		return
	_t += delta
	if (Time.get_ticks_msec() - _started_ms) / 1000.0 > TIME_LIMIT:
		_check("settingstest: aikaraja %d s ylittyi vaiheessa %d" % [int(TIME_LIMIT), _step], false)
		_done()
		return
	match _step:
		0:
			if _t > 0.5:
				if _click(_button("Asetukset")):
					_next()
		1:
			if _t > 0.3:
				_check("Asetukset aukesivat", main.menu._settings.visible and not main.menu._main.visible)
				_check("oletuksena pois päältä", not main.menu._real_toggle.button_pressed)
				_water_quality_menu_checks()
				if _click(main.menu._real_toggle):
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
				if _click(_button("Takaisin")):
					_next()
		4:
			if _t > 0.3:
				if _click(_button("Mene kalalle")):
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
				var text: String = main.hud._status.text
				var temp_lines := Array(text.split("\n")).filter(func(l): return "°C" in l)
				_check("HUD näyttää lämpötilan: " + (temp_lines[0] if not temp_lines.is_empty() else "(ei °C-riviä)"), "°C" in text)
				_shot("peli-todellinen-saa")
				_water_quality_game_checks()
				_done()


## Veden laatu alkuvalikon asetuksissa: rivi, oletus Korkea, vaihto tallentuu
func _water_quality_menu_checks() -> void:
	var controls: SettingsControls = main.menu._controls
	var option := controls.water_quality
	_check("Veden laatu -rivi asetuksissa", option != null and option.is_visible_in_tree() and option.item_count == 2)
	_check("veden laatu oletuksena Korkea", option.get_item_text(option.selected) == "Korkea" and Settings.water_quality == "korkea")
	option.select(1)
	option.item_selected.emit(1)
	_check("valinta Matala tallentuu asetuksiin", Settings.water_quality == "matala" and Settings.config().get_value("grafiikka", "veden_laatu") == "matala")
	option.select(0)
	option.item_selected.emit(0)
	_check("valinta Korkea tallentuu asetuksiin", Settings.config().get_value("grafiikka", "veden_laatu") == "korkea")


## Veden laatu kesken kalareissun (Esc-valikon asetukset): lähivesi rakennetaan heti uudelleen
func _water_quality_game_checks() -> void:
	var controls: Array = main.pause_menu.find_children("*", "GridContainer", true, false).filter(func(n): return n is SettingsControls)
	_check("Esc-valikossa on Veden laatu", controls.size() == 1)
	if controls.is_empty():
		return
	var option: OptionButton = controls[0].water_quality
	var high: int = main.world.near_vertex_count()
	option.select(1)
	option.item_selected.emit(1)
	var low: int = main.world.near_vertex_count()
	_check("Matala tulee voimaan heti: lähiveden verteksejä %d -> %d" % [high, low], low > 0 and low < high / 2)
	option.select(0)
	option.item_selected.emit(0)
	_check("Korkea palautuu: %d verteksiä" % main.world.near_vertex_count(), main.world.near_vertex_count() == high)


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

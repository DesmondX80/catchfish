class_name StartMenu
extends CanvasLayer
## Aloitusvalikko: "Mene kalalle" avaa järven kartan, josta valitaan
## aloituspaikka; "Asetukset" (todellinen aika ja sää); "Lopeta peli" sulkee pelin.

signal start_selected(index: int)

var lake: LakeData
var _main: Control
var _map_view: Control
var _map_bg: ColorRect
var _settings: Control
var _real_toggle: CheckButton
var _weather_label: Label
var _real_weather: RealWeather
var _map_real: CheckButton
var _time_section: Array[Control] = []
var _map_title: Label
var _career: CareerView
## Uramoodin kalareissu (aloituspaikka valitaan uran kotinäkymästä)
var career_mode := false
var _season_pick: OptionButton
var _time_pick: OptionButton
var _map: LakeMap
var _loading: Label
var _start_buttons: Array[Button] = []


func setup(lake_data: LakeData) -> void:
	lake = lake_data
	_build()


func _style(color: Color, radius := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(14)
	return sb


func _button(text: String, font_size := 24) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", _style(Color(0.16, 0.3, 0.22)))
	b.add_theme_stylebox_override("hover", _style(Color(0.24, 0.42, 0.3)))
	b.add_theme_stylebox_override("pressed", _style(Color(0.12, 0.22, 0.16)))
	b.add_theme_stylebox_override("focus", _style(Color(0.24, 0.42, 0.3)))
	b.custom_minimum_size = Vector2(320, 0)
	return b


func _label(text: String, font_size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _build() -> void:
	# Taustalla mökin pirtti 3D:nä
	add_child(CabinScene.new())

	# Päävalikko vasemmalla puoliläpinäkyvän paneelin päällä
	_main = MarginContainer.new()
	_main.add_theme_constant_override("margin_left", 70)
	add_child(_main)
	_main.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_main.custom_minimum_size.x = 520
	var center := CenterContainer.new()
	_main.add_child(center)
	var panel := PanelContainer.new()
	var panel_style := _style(Color(0.04, 0.06, 0.05, 0.72), 14)
	panel_style.set_content_margin_all(34)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	box.add_child(_label("CATCHFISH", 72, Color(0.95, 0.85, 0.45)))
	box.add_child(_label("Kotona", 26, Color(0.9, 0.84, 0.72)))
	box.add_child(Control.new())
	var go := _button("Mene kalalle")
	go.pressed.connect(func(): career_mode = false; _show_map())
	box.add_child(go)
	var career := _button("Uramoodi")
	career.pressed.connect(open_career)
	box.add_child(career)
	var settings := _button("Asetukset")
	settings.pressed.connect(_show_settings)
	box.add_child(settings)
	if not OS.has_feature("web"): # selaimessa peli suljetaan sulkemalla välilehti
		var quit := _button("Lopeta peli")
		quit.pressed.connect(func(): get_tree().quit())
		box.add_child(quit)
	if lake.attribution != "":
		var credit := _label(lake.attribution, 12, Color(0.7, 0.72, 0.66))
		credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		credit.custom_minimum_size.x = 320
		box.add_child(Control.new())
		box.add_child(credit)
	go.grab_focus.call_deferred()

	# Aloituspaikan valinta kartalta (tumma tausta mökin päällä)
	_map_bg = ColorRect.new()
	_map_bg.color = Color(0.05, 0.08, 0.07, 0.94)
	add_child(_map_bg)
	_map_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_bg.visible = false
	_map_view = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		_map_view.add_theme_constant_override("margin_" + side, 24)
	add_child(_map_view)
	_map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_view.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_map_view.add_child(row)
	_map = LakeMap.new()
	_map.select_mode = true
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_map)
	_map.setup(lake)
	_map.start_clicked.connect(func(i): start_selected.emit(i))
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 14)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(side)
	# Aika ja sää: todellinen tai itse valittu vuodenaika ja kellonaika
	var time_title := _label("Aika ja sää", 24, Color(0.95, 0.85, 0.45))
	side.add_child(time_title)
	_map_real = CheckButton.new()
	_map_real.text = "Todellinen kellonaika ja sää (Saloinen)"
	_map_real.add_theme_font_size_override("font_size", 16)
	_map_real.toggled.connect(_on_map_real_toggled)
	side.add_child(_map_real)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	side.add_child(grid)
	_season_pick = _picker(grid, "Vuodenaika", Settings.SEASONS, func(i):
		Settings.season_index = i
		Settings.save())
	_time_pick = _picker(grid, "Kellonaika", Settings.TIMES, func(i):
		Settings.time_index = i
		Settings.save())
	var spacer := Control.new()
	side.add_child(spacer)
	_time_section = [time_title, _map_real, grid, spacer]

	_map_title = _label("Valitse aloituspaikka", 24, Color(0.95, 0.85, 0.45))
	side.add_child(_map_title)
	side.add_child(_label("Klikkaa paikkaa kartalla tai listassa", 15, Color(0.75, 0.82, 0.78)))
	for i in lake.starts.size():
		var s: Dictionary = lake.starts[i]
		var b := _button("%d. %s\n%s" % [i + 1, s["name"], s.get("description", "")], 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): start_selected.emit(i))
		b.mouse_entered.connect(func(): _map.hovered = i; _map.queue_redraw())
		side.add_child(b)
		_start_buttons.append(b)
	side.add_child(Control.new())
	var back := _button("Takaisin", 18)
	back.pressed.connect(func(): open_career() if career_mode else _show_main())
	side.add_child(back)

	_career = CareerView.new()
	_career.visible = false
	add_child(_career)
	_career.go_fishing.connect(func(): career_mode = true; _show_map())
	_career.back.connect(_show_main)

	_build_settings()

	_loading = _label("", 30, Color(0.95, 0.85, 0.45))
	add_child(_loading)
	_loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading.visible = false


## Pudotusvalikko nimen kanssa ruudukkoon
func _picker(grid: GridContainer, title: String, items: Array, on_pick: Callable) -> OptionButton:
	var l := _label(title, 16, Color(0.85, 0.88, 0.82))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	grid.add_child(l)
	var pick := OptionButton.new()
	pick.add_theme_font_size_override("font_size", 16)
	pick.custom_minimum_size.x = 250
	for item in items:
		pick.add_item(item[0])
	pick.item_selected.connect(on_pick)
	grid.add_child(pick)
	return pick


func _on_map_real_toggled(on: bool) -> void:
	Settings.real_world = on
	Settings.save()
	_sync_time_controls()


## Kartan aika- ja säävalinnat vastaamaan asetuksia
func _sync_time_controls() -> void:
	_map_real.set_pressed_no_signal(Settings.real_world)
	_season_pick.select(Settings.season_index)
	_time_pick.select(Settings.time_index)
	_season_pick.disabled = Settings.real_world
	_time_pick.disabled = Settings.real_world
	if _real_toggle:
		_real_toggle.set_pressed_no_signal(Settings.real_world)


func _build_settings() -> void:
	_settings = MarginContainer.new()
	_settings.add_theme_constant_override("margin_left", 70)
	add_child(_settings)
	_settings.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	var center := CenterContainer.new()
	_settings.add_child(center)
	var panel := PanelContainer.new()
	var sb := _style(Color(0.04, 0.06, 0.05, 0.82), 14)
	sb.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size.x = 460
	panel.add_child(box)
	box.add_child(_label("Asetukset", 40, Color(0.95, 0.85, 0.45)))

	_real_toggle = CheckButton.new()
	_real_toggle.text = "Todellinen kellonaika ja sää\n(Saloinen, Raahe)"
	_real_toggle.add_theme_font_size_override("font_size", 20)
	_real_toggle.button_pressed = Settings.real_world
	_real_toggle.toggled.connect(_on_real_toggled)
	box.add_child(_real_toggle)

	var info := _label("Kellonaika ja vuodenaika otetaan tietokoneen kellosta (maisema muuttuu vuodenajan mukaan: ruska, lumi), ja sää haetaan Ilmatieteen laitoksen havainnoista Raahen Lapaluodon asemalta (n. 5 km Saloisista) 10 minuutin välein. Ajan nopeutta (T) ei voi silloin muuttaa.", 14, Color(0.8, 0.82, 0.76))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info)
	_weather_label = _label("", 16, Color(0.95, 0.9, 0.75))
	_weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_weather_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_weather_label)
	var credit := _label("Säätiedot: Ilmatieteen laitos ja Open-Meteo (CC BY 4.0)", 12, Color(0.65, 0.68, 0.62))
	box.add_child(credit)
	var back := _button("Takaisin", 20)
	back.pressed.connect(_show_main)
	box.add_child(back)
	_settings.visible = false

	_real_weather = RealWeather.new()
	add_child(_real_weather)
	_real_weather.updated.connect(func(data):
		_weather_label.text = "Nyt Saloisissa: %s\n(%s, klo %s)" % [RealWeather.summary(data), data["source"], data["time"]])
	_real_weather.failed.connect(func(msg):
		_weather_label.text = msg + ". Pelissä käytetään silloin simuloitua säätä.")


func _on_real_toggled(on: bool) -> void:
	Settings.real_world = on
	Settings.save()
	_update_weather_preview()


func _update_weather_preview() -> void:
	if Settings.real_world:
		_weather_label.text = "Haetaan säätietoja..."
		_real_weather.fetch()
	else:
		_weather_label.text = "Pois päältä: vuodenajan ja kellonajan voi valita aloituspaikan valinnassa, ja sää vaihtelee satunnaisesti."


func _show_settings() -> void:
	_main.visible = false
	_settings.visible = true
	_real_toggle.grab_focus()
	_update_weather_preview()


func _show_map() -> void:
	_main.visible = false
	_career.visible = false
	_map_bg.visible = true
	_map_view.visible = true
	_sync_time_controls()
	# Uramoodissa aika on uran kello: vuodenaikaa ja kellonaikaa ei valita
	for c in _time_section:
		c.visible = not career_mode
	_map_title.text = "Uramoodi – %s, klo %s\nValitse aloituspaikka" % [Career.weekday(), Career.clock_text()] if career_mode else "Valitse aloituspaikka"


## Uran kotinäkymä (myös kalareissulta palatessa)
func open_career() -> void:
	_main.visible = false
	_map_view.visible = false
	_map_bg.visible = false
	_settings.visible = false
	career_mode = true
	_career.visible = true
	_career.show_home()
	_start_buttons[0].grab_focus()


func _show_main() -> void:
	_map_view.visible = false
	_map_bg.visible = false
	_settings.visible = false
	_career.visible = false
	career_mode = false
	_main.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and (_map_view.visible or _settings.visible or _career.visible):
		if _map_view.visible and career_mode:
			open_career()
		else:
			_show_main()


func show_loading(place: String) -> void:
	_main.visible = false
	_map_view.visible = false
	_loading.text = "Lähdetään kalaan: %s\n\nLadataan järveä..." % place
	_map_bg.visible = true
	_loading.visible = true

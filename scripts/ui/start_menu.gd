class_name StartMenu
extends CanvasLayer
## Aloitusvalikko: "Mene kalalle" avaa järven kartan, josta valitaan
## aloituspaikka; "Lopeta peli" sulkee pelin.

signal start_selected(index: int)

var lake: LakeData
var _main: Control
var _map_view: Control
var _map_bg: ColorRect
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
	go.pressed.connect(_show_map)
	box.add_child(go)
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
	var title := _label("Valitse aloituspaikka", 28, Color(0.95, 0.85, 0.45))
	side.add_child(title)
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
	back.pressed.connect(_show_main)
	side.add_child(back)

	_loading = _label("", 30, Color(0.95, 0.85, 0.45))
	add_child(_loading)
	_loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading.visible = false


func _show_map() -> void:
	_main.visible = false
	_map_bg.visible = true
	_map_view.visible = true
	_start_buttons[0].grab_focus()


func _show_main() -> void:
	_map_view.visible = false
	_map_bg.visible = false
	_main.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _map_view.visible:
		_show_main()


func show_loading(place: String) -> void:
	_main.visible = false
	_map_view.visible = false
	_loading.text = "Lähdetään kalaan: %s\n\nLadataan järveä..." % place
	_map_bg.visible = true
	_loading.visible = true

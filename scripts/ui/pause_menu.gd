class_name PauseMenu
extends CanvasLayer
## Taukovalikko (Esc): Jatka kalastusta, Ohjeet, Mene kotiin (alkuvalikkoon).
## Peli on pysähdyksissä valikon ollessa auki; tämä solmu toimii tauollakin.

signal resumed
signal going_home

var _box: Control
var _help: Control
var _buttons: Array[Button] = []


func setup(help_text: String) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build(help_text)
	visible = false


func _style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	return sb


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_stylebox_override("normal", _style(Color(0.16, 0.3, 0.22)))
	b.add_theme_stylebox_override("hover", _style(Color(0.24, 0.42, 0.3)))
	b.add_theme_stylebox_override("pressed", _style(Color(0.12, 0.22, 0.16)))
	b.add_theme_stylebox_override("focus", _style(Color(0.24, 0.42, 0.3)))
	b.custom_minimum_size = Vector2(340, 0)
	return b


func _build(help_text: String) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_box = CenterContainer.new()
	add_child(_box)
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	_box.add_child(col)
	var title := Label.new()
	title.text = "Tauko"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	for item in [["Jatka kalastusta", resume], ["Ohjeet", _show_help], ["Mene kotiin", _go_home]]:
		var b := _button(item[0])
		b.pressed.connect(item[1])
		col.add_child(b)
		_buttons.append(b)

	# Ohjeet: sama teksti kuin F1-ohjeessa, ja Takaisin-painike
	_help = CenterContainer.new()
	add_child(_help)
	_help.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var sb := _style(Color(0.03, 0.06, 0.08, 0.92))
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	_help.add_child(panel)
	var help_col := VBoxContainer.new()
	help_col.add_theme_constant_override("separation", 14)
	panel.add_child(help_col)
	var text := Label.new()
	text.text = help_text
	text.add_theme_font_size_override("font_size", 16)
	help_col.add_child(text)
	var back := _button("Takaisin")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_show_menu)
	help_col.add_child(back)
	_buttons.append(back)
	_help.visible = false


## Avaa valikon ja pysäyttää pelin
func open() -> void:
	visible = true
	_show_menu()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resumed.emit()


func _show_menu() -> void:
	_help.visible = false
	_box.visible = true
	_buttons[0].grab_focus()


func _show_help() -> void:
	_box.visible = false
	_help.visible = true
	_buttons[-1].grab_focus()


## Takaisin alkuvalikkoon: peli ladataan alusta (pää-scene käynnistyy valikosta)
func _go_home() -> void:
	going_home.emit()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Main.return_to_menu = true
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("pause"):
		return
	get_viewport().set_input_as_handled()
	if _help.visible:
		_show_menu() # Esc ohjeista takaisin valikkoon
	else:
		resume()

class_name FishBookView
extends Control
## Kalakirja-näkymä (alkuvalikosta ja taukovalikosta): lajit vasemmalla, valitun
## lajin sivu oikealla. Saamaton laji näkyy varjokuvana ilman nimeä ja tietoja.

signal closed

var _buttons: Dictionary = {} # laji -> Button
var _progress: Label
var _name: Label
var _latin: Label
var _picture: FishPicture
var _text: Label
var _stats: Label
var _back: Button
var selected := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.07, 0.94)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	margin.add_child(row)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 12)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(side)
	side.add_child(_label("Kalakirja", 44, Color(0.95, 0.85, 0.45)))
	_progress = _label("", 16, Color(0.75, 0.82, 0.78))
	side.add_child(_progress)
	side.add_child(Control.new())
	for sp in Species.DATA:
		var b := _button("", 22)
		b.pressed.connect(show_species.bind(sp))
		b.focus_entered.connect(show_species.bind(sp))
		side.add_child(b)
		_buttons[sp] = b
	side.add_child(Control.new())
	_back = _button("Takaisin", 20)
	_back.pressed.connect(func(): closed.emit())
	side.add_child(_back)

	var panel := PanelContainer.new()
	var sb := _style(Color(0.86, 0.8, 0.66), 12) # paperinvärinen sivu
	sb.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", sb)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(panel)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	panel.add_child(page)
	var ink := Color(0.16, 0.13, 0.09)
	_name = _label("", 38, ink)
	page.add_child(_name)
	_latin = _label("", 18, Color(0.38, 0.32, 0.24))
	page.add_child(_latin)
	_picture = FishPicture.new()
	page.add_child(_picture)
	_picture.custom_minimum_size = Vector2(640, 250)
	_text = _label("", 17, ink)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 560
	page.add_child(_text)
	_stats = _label("", 17, ink)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_stats)


func _style(color: Color, radius := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(12)
	return sb


func _button(text: String, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", _style(Color(0.16, 0.3, 0.22)))
	b.add_theme_stylebox_override("hover", _style(Color(0.24, 0.42, 0.3)))
	b.add_theme_stylebox_override("pressed", _style(Color(0.12, 0.22, 0.16)))
	b.add_theme_stylebox_override("focus", _style(Color(0.24, 0.42, 0.3)))
	b.custom_minimum_size = Vector2(300, 0)
	return b


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Avaa kirjan: lajilista ajan tasalle ja ensimmäinen saatu laji näkyviin
func open() -> void:
	visible = true
	_progress.text = "Löydetty %d / %d lajia" % [FishBook.unlocked_count(), Species.DATA.size()]
	var first := ""
	for sp in _buttons:
		var b: Button = _buttons[sp]
		if FishBook.unlocked(sp):
			b.text = "%s  (%d)" % [Species.DATA[sp]["name"], FishBook.count(sp)]
			if first == "":
				first = sp
		else:
			b.text = "? ? ?"
	if first == "":
		first = Species.DATA.keys()[0]
	show_species(first)
	_buttons[first].grab_focus.call_deferred()


func show_species(sp: String) -> void:
	selected = sp
	_picture.show_species(sp)
	if not FishBook.unlocked(sp):
		_picture.modulate = Color(0.1, 0.08, 0.06, 0.85) # varjokuva
		_name.text = "Tuntematon laji"
		_latin.text = ""
		_text.text = "Tätä lajia et ole vielä saanut. Sivu avautuu, kun saat ensimmäisen kalan."
		_stats.text = ""
		return
	_picture.modulate = Color.WHITE
	_name.text = Species.DATA[sp]["name"]
	_latin.text = FishBook.TEXTS[sp][0]
	_text.text = FishBook.TEXTS[sp][1]
	var b := FishBook.best(sp)
	var lines: Array[String] = []
	lines.append("Saaliita: %d kpl" % FishBook.count(sp))
	lines.append("Oma ennätys: %s kg, %.0f cm – %s, %s" % [Hud._fi(b["weight"]), b["length"], b.get("lure", ""), Hud._real_date(b.get("date", ""))])
	if b.has("place"):
		lines.append("Ennätyskala saatu lähellä: %s" % b["place"])
	lines.append("Ensimmäinen saalis: %s" % Hud._real_date(FishBook.first_date(sp)))
	lines.append("Vinkki: viihtyy %s m syvyydessä, parhaat syötit %s" % [_depth_text(sp), _best_lures(sp)])
	_stats.text = "\n".join(lines)


func _depth_text(sp: String) -> String:
	var d: Array = Species.DATA[sp]["depth"]
	return ("%.1f–%.1f" % [d[0], d[1]]).replace(".", ",")


## Lajin kolme mieluisinta viehettä tai syöttiä
func _best_lures(sp: String) -> String:
	var prefs: Dictionary = Species.DATA[sp]["lures"]
	var ids := prefs.keys()
	ids.sort_custom(func(a, b): return prefs[a] > prefs[b])
	return ", ".join(ids.slice(0, 3).map(func(id): return Lures.name_of(id).to_lower()))


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		closed.emit()

class_name Hud
extends CanvasLayer
## Pelin käyttöliittymä: tilatiedot, kaikuluotain, kalastuspaneeli, viestit,
## saalisikkuna, saaliskirja ja ohjeet.

var boat: Boat
var fishing: Fishing
var weather: Weather
var sky: SkyTime
var lake: LakeData

var _status: Label
var _fishing_label: Label
var _power_bar: ProgressBar
var _tension_bar: ProgressBar
var _stamina_bar: ProgressBar
var _message: Label
var _message_timer := 0.0
var _prompt: Label
var _catch_panel: PanelContainer
var _catch_label: Label
var _log_panel: PanelContainer
var _log_label: Label
var _help_panel: PanelContainer
var sounder: EchoSounder
var _map_panel: PanelContainer
var _map: LakeMap


func setup(boat_node: Boat, fishing_node: Fishing, weather_node: Weather, sky_time: SkyTime, lake_data: LakeData, population: FishPopulation) -> void:
	boat = boat_node
	fishing = fishing_node
	weather = weather_node
	sky = sky_time
	lake = lake_data
	_build()
	sounder.boat = boat
	sounder.population = population
	boat.message.connect(show_message)
	fishing.message.connect(show_message)
	fishing.caught.connect(_on_caught)


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.06, 0.08, 0.72)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	return sb


## Paneeli ruudun reunaan tai keskelle. Koko näytön kokoiset säiliöt pitävät
## paneelin paikallaan, vaikka sen sisällön koko muuttuu.
func _panel(h: BoxContainer.AlignmentMode, v: BoxContainer.AlignmentMode) -> PanelContainer:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.alignment = v
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var row := HBoxContainer.new()
	row.alignment = h
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL if v == BoxContainer.ALIGNMENT_CENTER else Control.SIZE_SHRINK_BEGIN
	column.add_child(row)
	if v == BoxContainer.ALIGNMENT_CENTER:
		row.alignment = h
		row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _panel_style())
	row.add_child(p)
	return p


func _label(parent: Control, font_size := 16) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l


func _bar(parent: Control, color: Color, title: String) -> ProgressBar:
	var box := HBoxContainer.new()
	parent.add_child(box)
	var l := _label(box, 14)
	l.text = title
	l.custom_minimum_size.x = 90
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(260, 18)
	bar.show_percentage = false
	bar.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)
	return bar


func _build() -> void:
	var begin := BoxContainer.ALIGNMENT_BEGIN
	var center := BoxContainer.ALIGNMENT_CENTER
	var end := BoxContainer.ALIGNMENT_END
	var status_panel := _panel(begin, begin)
	_status = _label(status_panel, 16)

	var sounder_panel := _panel(end, begin)
	var sounder_box := VBoxContainer.new()
	sounder_panel.add_child(sounder_box)
	_label(sounder_box, 13).text = "Kaikuluotain"
	sounder = EchoSounder.new()
	sounder_box.add_child(sounder)

	var fishing_panel := _panel(center, end)
	var fishing_box := VBoxContainer.new()
	fishing_panel.add_child(fishing_box)
	_fishing_label = _label(fishing_box, 16)
	_power_bar = _bar(fishing_box, Color(0.95, 0.75, 0.2), "Heittovoima")
	_tension_bar = _bar(fishing_box, Color(0.9, 0.3, 0.2), "Jännitys")
	_stamina_bar = _bar(fishing_box, Color(0.3, 0.7, 0.9), "Kalan voimat")

	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 26)
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.add_theme_constant_override("outline_size", 6)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message)
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_KEEP_WIDTH, 90)
	_message.offset_left = -500
	_message.offset_right = 500

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_WIDTH)
	_prompt.offset_left = -400
	_prompt.offset_right = 400
	_prompt.offset_top = 60

	_catch_panel = _panel(center, center)
	_catch_label = _label(_catch_panel, 22)
	_catch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_catch_panel.visible = false

	_log_panel = _panel(center, center)
	_log_label = _label(_log_panel, 16)
	_log_panel.visible = false

	# Kartta kesken pelin (K): näyttää veneen sijainnin järvellä
	_map_panel = _panel(center, center)
	var map_box := VBoxContainer.new()
	_map_panel.add_child(map_box)
	_label(map_box, 16).text = "Kartta – %s   (K sulkee)" % lake.name
	_map = LakeMap.new()
	_map.custom_minimum_size = Vector2(560, 760)
	map_box.add_child(_map)
	_map.setup(lake)
	_map.boat = boat
	_map_panel.visible = false

	_help_panel = _panel(center, center)
	var help := _label(_help_panel, 16)
	help.text = help_text(true)
	_help_panel.visible = true

	# HUD:ssa ei ole painikkeita: klikkausten pitää mennä peliin. Kaapattu hiiri
	# on ruudun keskellä, joten muuten keskelle avautuva saalisikkuna söisi ne.
	_ignore_mouse(self)


func _ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(child)


## Näppäinohjeet; start_hint = lisää kehotus klikata aloittaakseen
func help_text(start_hint := true) -> String:
	var lines := [
		"CATCHFISH – %s" % lake.name,
		"",
		"VENE",
		"  W / S        kaasu (moottori) tai soutu eteen/taakse",
		"  A / D        ohjaus",
		"  Q            perämoottori käyntiin / sammuksiin (sammuksissa soudetaan)",
		"  X            ankkuri alas / ylös",
		"",
		"KALASTUS",
		"  Hiiri        kameran ja heittosuunnan kääntö, rulla = zoomaus",
		"  Vasen hiiri  pidä pohjassa = heittovoima, päästä = heitto",
		"               tärpätessä vastaisku, väsytyksen lopussa haavinta",
		"  Oikea hiiri  kelaa (Shift = nopeasti)",
		"  Välilyönti   nykäisy (jigi, lippa)",
		"  E / C        jarru kireämmälle / löysemmälle",
		"  L            vaihda uistin",
		"",
		"PILKKIMINEN (talvella järvi on jäässä)",
		"  W/A/S/D      kävely (Shift = juoksu)",
		"  Vasen hiiri  pidä pohjassa = kairaa reikä; avannolla = laske pilkkiä",
		"  Oikea hiiri  nosta pilkkiä   Välilyönti  nykäisy",
		"",
		"MUUTA",
		"  T            ajan nopeus   Tab  saaliskirja   K  kartta   F1  ohje   M  äänet   Esc  valikko",
		"",
	]
	if start_hint:
		lines.append("Klikkaa hiirellä aloittaaksesi.")
	if lake.attribution != "":
		if start_hint:
			lines.append("")
		lines.append(lake.attribution)
	if lake.depth_estimated:
		lines.append("Järven syvyys on arvioitu – tekoaltaasta ei ole avointa syvyysaineistoa.")
	return "\n".join(lines)


func show_message(text: String) -> void:
	_message.text = text
	_message_timer = 3.5
	_message.modulate.a = 1.0


func _on_caught(entry: Dictionary, record: bool) -> void:
	var text := "%s  %.2f kg  •  %.0f cm\n" % [entry["name"], entry["weight"], entry["length"]]
	text += "Uistin: %s   klo %s" % [entry["lure"], entry["time"]]
	if entry["place"] != "":
		text += "\nPaikka: lähellä %s" % entry["place"]
	if record:
		text = "UUSI ENNÄTYS!\n" + text
	text += "\n\nVasen hiiri: jatka kalastusta"
	_catch_label.text = text
	_catch_panel.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("catch_log"):
		_log_panel.visible = not _log_panel.visible
		if _log_panel.visible:
			_log_label.text = _log_text()
	elif event.is_action_pressed("help"):
		_help_panel.visible = not _help_panel.visible
	elif event.is_action_pressed("map"):
		_map_panel.visible = not _map_panel.visible
		if _map_panel.visible:
			_log_panel.visible = false
			_help_panel.visible = false


func set_paused_view(paused: bool) -> void:
	_help_panel.visible = paused


func _log_text() -> String:
	var lines := ["SAALISKIRJA", ""]
	for sp in Species.DATA:
		var best := CatchLog.personal_best(sp)
		var line := "%-8s %3d kpl" % [Species.DATA[sp]["name"], CatchLog.count(sp)]
		if not best.is_empty():
			line += "   ennätys %.2f kg / %.0f cm (%s)" % [best["weight"], best["length"], best["lure"]]
		lines.append(line)
	lines.append("")
	lines.append("Viimeisimmät:")
	var recent := CatchLog.entries.slice(maxi(0, CatchLog.entries.size() - 8))
	recent.reverse()
	for e in recent:
		lines.append("  %s %.2f kg  klo %s  %s" % [e["name"], e["weight"], e["time"], e["lure"]])
	if CatchLog.entries.is_empty():
		lines.append("  Ei vielä saaliita.")
	lines.append("")
	lines.append("Menetetyt uistimet tällä kerralla: %d" % fishing.lost_lures)
	return "\n".join(lines)


func _process(delta: float) -> void:
	if boat == null:
		return
	_message_timer -= delta
	if _message_timer < 1.0:
		_message.modulate.a = maxf(0.0, _message_timer)

	var motor := "Airot"
	if boat.on_ice:
		motor = "Jalan jäällä"
	elif boat.motor_running:
		motor = "Moottori %d %%" % roundi(boat.throttle * 100.0) if boat.throttle >= 0.0 else "Moottori peruutus"
	elif boat.motor_starting > 0.0:
		motor = "Moottori käynnistyy..."
	var place := lake.nearest_place(boat.pos.x, boat.pos.y)
	var clock := "Klo %s  (todellinen aika)" % sky.clock_text() if sky.real_time else "Klo %s  (aika x%d)" % [sky.clock_text(), int(sky.time_scale())]
	var weather_text := weather.description()
	if not is_nan(weather.temperature):
		weather_text = "%s, %s °C" % [weather_text, ("%.1f" % weather.temperature).replace(".", ",")]
	_status.text = "%s\n%s\nTuuli %.1f m/s %s\n%s   %.1f km/h%s\nSyvyys %.1f m%s" % [
		clock, weather_text,
		weather.speed(), weather.from_text(),
		motor, boat.speed_kmh(), "   ANKKURISSA" if boat.anchored else "",
		boat.depth_below(), ("\nLähellä: " + place) if place != "" else "",
	]

	var l := fishing.lure()
	var info := "%s   •   Jarru %.2f kg (siima kestää %.1f kg)" % [l["name"], fishing.drag_kg, Fishing.LINE_STRENGTH]
	match fishing.state:
		Fishing.State.READY:
			if fishing.on_ice:
				info += "\nAvanto edessä – vasen hiiri laskee pilkin" if fishing.at_hole() else "\nKairaa reikä: vasen hiiri pohjassa (kävele W/A/S/D)"
			else:
				info += "\nValmiina heittoon"
		Fishing.State.DRILLING:
			info += "\nKairataan reikää... %d %%" % int(fishing.power * 100.0)
		Fishing.State.CHARGING:
			info += "\nHeittovoima..."
		Fishing.State.FLYING:
			info += "\nUistin lentää – siimaa %.0f m" % fishing.line_out
		Fishing.State.RETRIEVING, Fishing.State.BITE:
			info += "\nSiimaa %.1f m   •   uistin %.1f m syvyydessä   •   %.1f m/s" % [fishing.line_out, fishing.lure_depth(), fishing.lure_speed]
			if fishing.snagged:
				info += "\nKIINNI!"
		Fishing.State.FIGHT:
			var fish := fishing.hooked_fish()
			info += "\n%s koukussa!   Siimaa %.1f m%s" % [Species.DATA[fish["sp"]]["name"] if not fish.is_empty() else "Kala", fishing.line_out, "   JARRU LAULAA" if fishing.drag_slipping else ""]
		Fishing.State.LANDED:
			info += "\nSaalis jäällä!" if fishing.on_ice else "\nSaalis haavissa!"
	_fishing_label.text = info

	_power_bar.get_parent().visible = fishing.state == Fishing.State.CHARGING or fishing.state == Fishing.State.DRILLING
	_power_bar.get_parent().get_child(0).text = "Kairaus" if fishing.state == Fishing.State.DRILLING else "Heittovoima"
	_power_bar.value = fishing.power
	var tension_visible := fishing.state in [Fishing.State.RETRIEVING, Fishing.State.BITE, Fishing.State.FIGHT]
	_tension_bar.get_parent().visible = tension_visible
	_tension_bar.value = clampf(fishing.tension / Fishing.LINE_STRENGTH, 0.0, 1.0)
	_stamina_bar.get_parent().visible = fishing.state == Fishing.State.FIGHT
	_stamina_bar.value = fishing.fish_stamina()

	_prompt.text = ""
	if fishing.state == Fishing.State.BITE:
		_prompt.text = "TÄRPPI! Vasen hiiri = vastaisku"
	elif fishing.landing_ready():
		_prompt.text = "Kala on avannossa – vasen hiiri = nosta jäälle" if fishing.on_ice else "Kala on veneen vieressä – vasen hiiri = haavi"
	if fishing.state != Fishing.State.LANDED:
		_catch_panel.visible = false

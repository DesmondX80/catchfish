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
var _speech: Label # kalastajan repliikki tekstityksenä
var _speech_timer := 0.0
var _prompt: Label
var _catch_panel: PanelContainer
var _catch_label: Label
var _catch_picture: FishPicture
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

	_speech = Label.new()
	_speech.add_theme_font_size_override("font_size", 22)
	_speech.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	_speech.add_theme_color_override("font_outline_color", Color.BLACK)
	_speech.add_theme_constant_override("outline_size", 6)
	_speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_speech)
	_speech.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_KEEP_WIDTH, 130)
	_speech.offset_left = -500
	_speech.offset_right = 500

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
	var catch_box := VBoxContainer.new()
	_catch_panel.add_child(catch_box)
	_catch_picture = FishPicture.new()
	catch_box.add_child(_catch_picture)
	_catch_label = _label(catch_box, 22)
	_catch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_catch_panel.visible = false

	_log_panel = _panel(BoxContainer.ALIGNMENT_END, center) # saavin vieressä ruudun oikeassa reunassa
	_log_label = _label(_log_panel, 16)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "monospace"])
	_log_label.add_theme_font_override("font", mono)
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
		"  Vasen hiiri  pidä pohjassa = heittovoima (rengas näyttää osumapisteen), päästä = heitto",
		"               tärpätessä vastaisku, väsytyksen lopussa haavinta",
		"  Oikea hiiri  kelaa (Shift = nopeasti)",
		"  Välilyönti   nykäisy (jigi, lippa)",
		"  E / C        jarru kireämmälle / löysemmälle",
		"  L            vaihda uistin",
		"  R            vetouistelu: heitetty vapa telineeseen ja toinen käteen,",
		"               tai vapa telineestä käteen (ensin se, jossa on tärppi)",
		"",
		"PILKKIMINEN (talvella järvi on jäässä)",
		"  W/A/S/D      kävely (Shift = juoksu)",
		"  Vasen hiiri  pidä pohjassa = kairaa reikä; avannolla = laske pilkkiä",
		"  Oikea hiiri  nosta pilkkiä   Välilyönti  nykäisy",
		"",
		"MUUTA",
		"  T            ajan nopeus   Tab  kalasaavi   K  kartta   F1  ohje   M  äänet   Esc  valikko",
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


## Kalastajan repliikki tekstityksenä
func show_speech(text: String) -> void:
	_speech.text = "”%s”" % text
	_speech_timer = 3.0
	_speech.modulate.a = 1.0


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
	_catch_picture.show_species(entry["species"])
	_catch_panel.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("catch_log"):
		_show_tub(not _log_panel.visible)
	elif event.is_action_pressed("help"):
		_help_panel.visible = not _help_panel.visible
	elif event.is_action_pressed("map"):
		_map_panel.visible = not _map_panel.visible
		if _map_panel.visible:
			_show_tub(false)
			_help_panel.visible = false


func set_paused_view(paused: bool) -> void:
	_help_panel.visible = paused


## Tab: kamera saavin yläpuolelle ja saaliin painot sivuikkunaan
func _show_tub(on: bool) -> void:
	_log_panel.visible = on
	get_parent().camera_rig.tub_view = on
	get_parent().tub.set_viewing(on)
	if on:
		_log_label.text = _log_text()


func tub_open() -> bool:
	return _log_panel.visible


## Saavin kalat painoineen; kertakalastuksessa myös koko pelin painavimmat kalat,
## millä saatu ja milloin (koneen päiväys ja kellonaika)
func _log_text() -> String:
	var lines: Array[String] = []
	var trip: Array = get_parent().trip_catch
	var kg := 0.0
	lines.append("SAAVI – tämän kalareissun saalis   (Tab sulkee)")
	lines.append("")
	for e in trip:
		kg += e["weight"]
		lines.append("  %-7s %6s kg  %3.0f cm   %-22s klo %s" % [e["name"], _fi(e["weight"]), e["length"], e["lure"], e["time"]])
	if trip.is_empty():
		lines.append("  Saavi on tyhjä.")
	lines.append("")
	lines.append("Yhteensä %d kalaa, %s kg" % [trip.size(), _fi(kg)])
	if Career.active:
		lines.append("Saalis viedään kotiin säilöön (Esc → Mene kotiin)")
	else:
		lines.append("")
		lines.append("PAINAVIMMAT KALAT")
		lines.append("")
		var top := CatchLog.top(5)
		for i in top.size():
			var e: Dictionary = top[i]
			lines.append("%2d. %-7s %6s kg  %3.0f cm   %-22s %s" % [i + 1, e["name"], _fi(e["weight"]), e["length"], e["lure"], _real_date(e.get("date", ""))])
		if top.is_empty():
			lines.append("  Ei vielä saaliita.")
	return "\n".join(lines)


func _fi(v: float) -> String:
	return ("%.2f" % v).replace(".", ",")


## Koneen päiväys "2026-10-18 20:15:33" -> "18.10.2026 klo 20.15"
func _real_date(s: String) -> String:
	var parts := s.split(" ")
	if parts.size() < 2:
		return s
	var d := parts[0].split("-")
	var t := parts[1].split(":")
	if d.size() < 3 or t.size() < 2:
		return s
	return "%d.%d.%s klo %s.%s" % [int(d[2]), int(d[1]), d[0], t[0], t[1]]


func _process(delta: float) -> void:
	if boat == null:
		return
	_message_timer -= delta
	if _message_timer < 1.0:
		_message.modulate.a = maxf(0.0, _message_timer)
	_speech_timer -= delta
	if _speech_timer < 1.0:
		_speech.modulate.a = maxf(0.0, _speech_timer)

	var motor := "Airot"
	if boat.on_ice:
		motor = "Jalan jäällä"
	elif boat.motor_running:
		motor = "Moottori %d %%" % roundi(boat.throttle * 100.0) if boat.throttle >= 0.0 else "Moottori peruutus"
	elif boat.motor_starting > 0.0:
		motor = "Moottori käynnistyy..."
	var place := lake.nearest_place(boat.pos.x, boat.pos.y)
	var clock := "Klo %s  (todellinen aika)" % sky.clock_text() if sky.real_time else "Klo %s  (aika x%d)" % [sky.clock_text(), int(sky.time_scale())]
	if Career.active:
		# Päivä vaihtuu reissulla, kun kello ohittaa puolenyön
		var day := Career.day + int(sky.minutes / 1440.0)
		clock = "Päivä %d (%s) %s" % [day, Career.WEEKDAYS[(day - 1) % 7].left(2), clock]
	var trip: Array = get_parent().trip_catch
	var kg := 0.0
	for e in trip:
		kg += e["weight"]
	clock += "\nSaavi: %d kalaa, %s kg (Tab)" % [trip.size(), ("%.2f" % kg).replace(".", ",")]
	if _log_panel.visible:
		_log_label.text = _log_text() # uusi saalis näkyy heti
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
	var lure_name: String = l["name"]
	if fishing.limited:
		lure_name = "%s (%d kpl)" % [lure_name, fishing.lure_count()] if fishing.has_lure() else "Ei uistimia – osta kaupasta"
	var info := "%s   •   Jarru %.2f kg (siima kestää %.1f kg)" % [lure_name, fishing.drag_kg, Fishing.LINE_STRENGTH]
	if fishing.hands_free():
		info = "Vavat telineissä – soutele ja odota tärppiä (R = ota vapa)   •   Jarru %.2f kg" % fishing.drag_kg
	for r in fishing.holder_rods():
		var st := "siimaa %.0f m, %.1f m syvyydessä" % [r["line"], r["depth"]]
		if r["state"] == Fishing.State.BITE:
			st = "TÄRPPI!"
		elif r["state"] == Fishing.State.FIGHT:
			st = "%s koukussa!" % r["fish"]
		elif r["state"] == Fishing.State.READY:
			st = "siima katkesi"
		elif r["snagged"]:
			st = "KIINNI!"
		info += "\nTelineessä vapa %d: %s – %s" % [r["number"], r["lure"], st]
	if fishing.hands_free():
		_fishing_label.text = info
		_power_bar.get_parent().visible = false
		_tension_bar.get_parent().visible = false
		_stamina_bar.get_parent().visible = false
		_prompt.text = "Tärppi telineessä – R = ota vapa käteen" if fishing.alert_rod() >= 0 else ""
		_catch_panel.visible = false
		return
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
			var aim: Dictionary = fishing.cast_preview
			if not aim.is_empty():
				info += "  noin %.0f m" % aim["distance"]
				if not aim["water"]:
					info += {LakeData.Ground.REEDS: " – KAISLIKKOON!", LakeData.Ground.FOREST: " – PUSIKKOON!"}.get(aim["ground"], " – RANTAAN!")
		Fishing.State.FLYING:
			info += "\nUistin lentää – siimaa %.0f m" % fishing.line_out
		Fishing.State.RETRIEVING, Fishing.State.BITE:
			info += "\nSiimaa %.1f m   •   uistin %.1f m syvyydessä   •   %.1f m/s" % [fishing.line_out, fishing.lure_depth(), fishing.lure_speed]
			if fishing.snagged:
				info += "\nKIINNI!"
		Fishing.State.FIGHT:
			info += "\n%s koukussa!   Siimaa %.1f m%s" % [fishing.fish_name(), fishing.line_out, "   JARRU LAULAA" if fishing.drag_slipping else ""]
		Fishing.State.LANDING:
			info += "\nNostetaan jäälle..." if fishing.on_ice else "\nHaavitaan..."
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
	if fishing.alert_rod() >= 0:
		_prompt.text = "Tärppi telineessä – R = ota vapa käteen"
	if fishing.state == Fishing.State.BITE:
		_prompt.text = "TÄRPPI! Vasen hiiri = vastaisku"
	elif fishing.landing_ready():
		_prompt.text = "Kala on avannossa – vasen hiiri = nosta jäälle" if fishing.on_ice else "Kala on veneen vieressä – vasen hiiri = haavi"
	if fishing.state != Fishing.State.LANDED:
		_catch_panel.visible = false

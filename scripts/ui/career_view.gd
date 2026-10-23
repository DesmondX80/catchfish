class_name CareerView
extends MarginContainer
## Uramoodin kotinäkymä mökissä: päivän tiedot, kalareissulle lähtö, kalojen
## myynti, kalastustarvikeliike (myös kalastonhoitomaksu ja toisen vavan lupa)
## ja nukkuminen.

signal go_fishing
signal back

var _panel: VBoxContainer
var _message := ""
var _confirm_new := false
var _sleep_hours := 8

const WARN := Color(1.0, 0.85, 0.5) # sama kuin _flash

var _shop_scroll: ScrollContainer


func _ready() -> void:
	add_theme_constant_override("margin_left", 70)
	set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	var center := CenterContainer.new()
	add_child(center)
	var panel := PanelContainer.new()
	var sb := _style(Color(0.04, 0.06, 0.05, 0.84), 14)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 12)
	_panel.custom_minimum_size.x = 500
	panel.add_child(_panel)
	show_home()


func _style(color: Color, radius := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(10)
	return sb


func _button(text: String, on_press: Callable, font_size := 20, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", _style(Color(0.16, 0.3, 0.22)))
	b.add_theme_stylebox_override("hover", _style(Color(0.24, 0.42, 0.3)))
	b.add_theme_stylebox_override("pressed", _style(Color(0.12, 0.22, 0.16)))
	b.add_theme_stylebox_override("focus", _style(Color(0.24, 0.42, 0.3)))
	b.add_theme_stylebox_override("disabled", _style(Color(0.12, 0.14, 0.13)))
	b.pressed.connect(on_press)
	(parent if parent else _panel).add_child(b)
	return b


func _label(text: String, font_size := 17, color := Color(0.88, 0.9, 0.84), parent: Control = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(parent if parent else _panel).add_child(l)
	return l


func _title(text: String) -> void:
	_label(text, 34, Color(0.95, 0.85, 0.45))


func _clear() -> void:
	for c in _panel.get_children():
		c.queue_free()


func _eur(v: float) -> String:
	return ("%.2f €" % v).replace(".", ",")


func _kg(v: float) -> String:
	return ("%.2f kg" % v).replace(".", ",")


func _day_line() -> String:
	return "Päivä %d – %s %s, klo %s" % [Career.day, Career.weekday(), Career.date_text(), Career.clock_text()]


func _flash() -> void:
	if _message != "":
		_label(_message, 16, WARN)
		_message = ""


# --- Koti -----------------------------------------------------------------------

func show_home() -> void:
	_clear()
	_title("Uramoodi")
	_label(_day_line(), 20, Color(0.95, 0.92, 0.8))
	_label("Rahaa: %s" % _eur(Career.money), 18)
	_label("Maine: %d  (myyntihinnat +%d %%)" % [Career.fame, Career.price_bonus_percent()], 18)
	if Career.fee_valid():
		_label("Kalastonhoitomaksu: " + Career.fee_until_text(), 18)
	else:
		_label("Kalastonhoitomaksu: ei maksettu – vain onki ja pilkki sallittu", 18, WARN)
	if Career.rod_permit_valid():
		_label("Toisen vavan lupa: %s%s" % [Career.rod_permit_text(), "" if Career.fee_valid() else " (vaatii myös kalastonhoitomaksun)"], 18)
	else:
		_label("Toisen vavan lupa: ei lupaa – yksi vapa", 18)
	var advice := fee_advice()
	if advice != "":
		_label(advice, 16, WARN)
	_label("Säilössä: %d kalaa, %s" % [Career.storage_count(), _kg(Career.storage_kg())], 18)
	var owned: Array = []
	for l in Lures.all():
		var n := int(Career.lures.get(l["id"], 0))
		if n > 0:
			owned.append("%s %d" % [l["name"].split(" ")[0], n])
	_label("Uistimet: " + (", ".join(owned) if not owned.is_empty() else "ei yhtään"), 16)
	var nets: Array = []
	for n in Nets.LIST:
		var k := int(Career.lures.get(n["id"], 0))
		if k > 0:
			nets.append("%s %d" % [n["name"].trim_prefix("Verkko "), k])
	if not nets.is_empty() or not Career.nets.is_empty():
		_label("Verkot: %s%s" % [", ".join(nets) if not nets.is_empty() else "ei veneessä", "   •   järvessä pyytämässä %d" % Career.nets.size() if not Career.nets.is_empty() else ""], 16)
	_flash()
	var go := _button("Lähde kalalle", func(): go_fishing.emit(), 22)
	_button("Myy kaloja", show_market)
	_button("Kalastustarvikeliike", show_shop)
	_button("Nuku", show_sleep)
	_button("Takaisin alkuvalikkoon", func(): back.emit())
	var new_text := "Vahvista: aloita alusta (nykyinen ura poistuu)" if _confirm_new else "Aloita uusi ura"
	_button(new_text, _on_new_career, 14)
	go.grab_focus.call_deferred()


## Neuvo kotinäkymään, kun maksua ei ole eikä vuodenaikaan sopivaa onkea tai
## pilkkiä: maksa tai osta onki, tai (rahat lopussa) aloita uusi ura
static func fee_advice() -> String:
	if Career.fee_valid():
		return ""
	var frozen := Season.from_day(Career.day_of_year()).frozen()
	var allowed: Array = Lures.ICE if frozen else Lures.LIST.filter(func(l): return l["kind"] in ["bobber", "bottom"])
	if allowed.any(func(l): return int(Career.lures.get(l["id"], 0)) > 0):
		return ""
	var cheapest := 1e9
	for l in Lures.ICE + Lures.LIST.filter(func(l): return l["kind"] in ["bobber", "bottom"]):
		cheapest = minf(cheapest, l["price"])
	if Career.money + 0.001 >= cheapest or Career.storage_count() > 0:
		return "Kalastonhoitomaksu pitää maksaa ennen virvelikalastusta – maksa se kalastustarvikeliikkeessä. Ilman maksua saa onkia ja pilkkiä (osta onki liikkeestä)."
	return "Rahat eivät riitä onkeen eikä kalastonhoitomaksuun – voit aloittaa uuden uran."


func _on_new_career() -> void:
	if not _confirm_new:
		_confirm_new = true
	else:
		_confirm_new = false
		Career.new_career()
		_message = "Uusi ura alkoi: maanantai 1.6. aamulla"
	show_home()


# --- Kalojen myynti -------------------------------------------------------------

func show_market() -> void:
	_clear()
	_title("Kalojen myynti")
	_label(_day_line(), 16)
	var bonus := " Maineen hintalisä: +%d %%." % Career.price_bonus_percent() if Career.price_bonus_percent() > 0 else ""
	_label("Päivän kilohinnat: Luonnonvarakeskuksen kalan tuottajahinnat, joissa päivittäistä vaihtelua." + bonus, 13, Color(0.7, 0.74, 0.68))
	var total := 0.0
	for item in Career.sale_species():
		var sp: String = item[0]
		var n := Career.storage_count(sp)
		var kg := Career.storage_kg(sp)
		var price := Career.price(sp)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_panel.add_child(row)
		var text := "%s: %s/kg" % [item[1], _eur(price)]
		if n > 0:
			text += "\n   %d kpl, %s = %s" % [n, _kg(kg), _eur(kg * price)]
			total += kg * price
		var l := _label(text, 16, Color(0.88, 0.9, 0.84), row)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := _button("Myy", func(): _sell(sp), 16, row)
		b.disabled = n == 0
	_label("Rahaa: %s" % _eur(Career.money), 18)
	_flash()
	var all := _button("Myy kaikki (%s)" % _eur(total), func(): _sell(""), 20)
	all.disabled = Career.storage_count() == 0
	_button("Takaisin", show_home)


func _sell(species: String) -> void:
	var earned := Career.sell(species)
	_message = "Myyty: %s" % _eur(earned)
	show_market()


# --- Kalastustarvikeliike -------------------------------------------------------

func show_shop() -> void:
	var scroll_at := _shop_scroll.scroll_vertical if is_instance_valid(_shop_scroll) else 0
	_clear()
	_title("Kalastustarvikeliike")
	_label("Rahaa: %s" % _eur(Career.money), 18)
	# Tuotteet vierivät (hiiren rulla), otsikko ja Takaisin pysyvät paikallaan
	_shop_scroll = ScrollContainer.new()
	_shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shop_scroll.custom_minimum_size.y = maxf(200.0, get_viewport_rect().size.y - 330.0)
	_panel.add_child(_shop_scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_scroll.add_child(list)
	_label("Kalastonhoitomaksu (virveli ja verkot; onki ja pilkki yhdellä vavalla ilman)", 16, Color(0.95, 0.85, 0.45), list)
	_label("Voimassa: " + (Career.fee_until_text().trim_prefix("voimassa ") if Career.fee_valid() else "ei maksettu"), 16, Color(0.88, 0.9, 0.84), list)
	for f in Career.FEES:
		var b := _shop_row(list, "%s – %s" % [f["name"], _eur(f["price"])], "Maksa", func(): _pay_fee(f))
		b.disabled = not Career.can_pay_fee(f["id"])
	var permit := "Tekoaltaan lupa toiselle vavalle (31.12. asti, vaatii myös kalastonhoitomaksun) – %s" % _eur(Career.ROD_PERMIT_PRICE)
	if Career.rod_permit_valid():
		permit += "   (%s)" % Career.rod_permit_text()
	var pb := _shop_row(list, permit, "Maksa", _pay_rod_permit)
	pb.disabled = not Career.can_pay_rod_permit()
	for group in [["Avovesi (virveli ja onki)", Lures.LIST], ["Talvi (pilkki)", Lures.ICE], ["Verkot (30 m, avovesikaudella; jäävät järveen pyytämään)", Nets.LIST]]:
		_label(group[0], 16, Color(0.95, 0.85, 0.45), list)
		for l in group[1]:
			var have := int(Career.lures.get(l["id"], 0))
			var b := _shop_row(list, "%s – %s   (sinulla %d)" % [l["name"], _eur(l["price"]), have], "Osta", func(): _buy(l))
			b.disabled = Career.money + 0.001 < l["price"]
	_shop_scroll.set_deferred("scroll_vertical", scroll_at) # osto ei hyppää listan alkuun
	_flash()
	_button("Takaisin", show_home)


## Liikkeen rivi: teksti ja painike
func _shop_row(parent: Control, text: String, button: String, on_press: Callable) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var lbl := _label(text, 16, Color(0.88, 0.9, 0.84), row)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return _button(button, on_press, 16, row)


func _pay_fee(f: Dictionary) -> void:
	_message = "Kalastonhoitomaksu maksettu: %s" % Career.fee_until_text() if Career.pay_fee(f["id"]) else "Rahat eivät riitä"
	show_shop()


func _pay_rod_permit() -> void:
	_message = "Toisen vavan lupa maksettu: %s" % Career.rod_permit_text() if Career.pay_rod_permit() else "Rahat eivät riitä"
	show_shop()


func _buy(lure: Dictionary) -> void:
	_message = "Ostettu: %s" % lure["name"] if Career.buy(lure) else "Rahat eivät riitä"
	show_shop()


# --- Nukkuminen -----------------------------------------------------------------

func show_sleep() -> void:
	_clear()
	_title("Nukkuminen")
	_label(_day_line(), 16)
	_label("Kuinka kauan nukutaan?", 18)
	var slider := HSlider.new()
	slider.min_value = 1
	slider.max_value = 16
	slider.step = 1
	slider.value = _sleep_hours
	slider.custom_minimum_size.x = 400
	_panel.add_child(slider)
	var preview := _label("", 18, Color(0.95, 0.92, 0.8))
	var update := func(v: float):
		_sleep_hours = int(v)
		var end := fmod(Career.minutes + v * 60.0, 1440.0)
		var next_day := Career.minutes + v * 60.0 >= 1440.0
		preview.text = "%d h  →  herätys %sklo %02d:%02d" % [int(v), "seuraavana päivänä " if next_day else "", int(end) / 60, int(end) % 60]
	slider.value_changed.connect(update)
	update.call(slider.value)
	_flash()
	_button("Nuku", func(): _sleep(), 22)
	_button("Takaisin", show_home)


func _sleep() -> void:
	var days := Career.sleep(_sleep_hours)
	_message = "Heräsit: päivä %d – %s klo %s%s" % [Career.day, Career.weekday(), Career.clock_text(), " (uusi päivä)" if days > 0 else ""]
	show_home()

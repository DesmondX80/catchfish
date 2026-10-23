class_name SettingsControls
extends GridContainer
## Ohjauksen ja äänten asetukset (alkuvalikon Asetukset ja taukovalikko):
## hiiren herkkyys, käänteinen pystyohjaus, veden laatu ja äänenvoimakkuudet väylittäin.
## Muutokset tulevat voimaan heti ja tallennetaan.

var sensitivity: HSlider
var invert: CheckButton
var water_quality: OptionButton
## Äänenvoimakkuuden liukusäätimet väylän nimellä
var volume_sliders := {}


func _init() -> void:
	columns = 3
	add_theme_constant_override("h_separation", 14)
	add_theme_constant_override("v_separation", 10)

	sensitivity = _slider("Hiiren herkkyys", Settings.SENSITIVITY_MIN, Settings.SENSITIVITY_MAX, 0.05,
			Settings.mouse_sensitivity, func(v): return "%.2f×" % v)
	sensitivity.value_changed.connect(func(v):
		Settings.mouse_sensitivity = v
		Settings.save())

	add_child(_label("Käänteinen pystyohjaus"))
	invert = CheckButton.new()
	invert.button_pressed = Settings.invert_y
	invert.toggled.connect(func(on):
		Settings.invert_y = on
		Settings.save())
	add_child(invert)
	add_child(Control.new())

	# Veden laatu: Korkea (tarkat aallot) tai Matala (kevyempi, selaimen oletus)
	add_child(_label("Veden laatu"))
	water_quality = OptionButton.new()
	for q in Settings.WATER_QUALITIES:
		water_quality.add_item(q[1])
	water_quality.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(water_quality)
	var hint := Label.new()
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.6))
	add_child(hint)
	var show_quality := func(i: int):
		water_quality.select(i)
		hint.text = Settings.WATER_QUALITIES[i][2]
	for i in Settings.WATER_QUALITIES.size():
		if Settings.WATER_QUALITIES[i][0] == Settings.water_quality:
			show_quality.call(i)
	water_quality.item_selected.connect(func(i):
		show_quality.call(i)
		Settings.set_water_quality(Settings.WATER_QUALITIES[i][0]))

	for b in Settings.BUSES:
		var bus: String = b[0]
		var s := _slider(b[1], 0.0, 1.0, 0.05, Settings.volumes[bus], func(v): return "%d %%" % roundi(v * 100.0))
		s.value_changed.connect(func(v):
			Settings.set_volume(bus, v)
			Settings.save())
		volume_sliders[bus] = s


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(0.85, 0.88, 0.82))
	return l


## Rivi: nimi, liukusäädin ja arvo tekstinä
func _slider(title: String, min_value: float, max_value: float, step: float, value: float, fmt: Callable) -> HSlider:
	add_child(_label(title))
	var s := HSlider.new()
	s.min_value = min_value
	s.max_value = max_value
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(200, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(s)
	var shown := _label(fmt.call(value))
	shown.custom_minimum_size.x = 56
	add_child(shown)
	s.value_changed.connect(func(v): shown.text = fmt.call(v))
	return s

extends Node
## Uramoodin testi oikeilla hiiren klikkauksilla: godot -- --careertest=/kansio
## Uusi ura (ei kalastonhoitomaksua) → uistimen osto → vuorokausimaksu → kalareissu (saalis + menetetty uistin) → kotiin →
## kalojen myynti → nukkuminen yli puolenyön (päivä vaihtuu, vuorokausimaksu päättyy).

var _dir := ""
var _log: Array[String] = []
var _step := 0
var _t := 0.0
var _money_before := 0.0
var _fish_value := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--careertest="):
			_dir = arg.split("=")[1]
	reparent.call_deferred(get_tree().root) # säilyy kotiin palatessa (scene ladataan uudelleen)


func _main() -> Node:
	return get_tree().current_scene


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(_dir.path_join(name + ".png"))


func _click(c: Control) -> void:
	if c == null:
		_check("painike löytyi", false)
		return
	var scale := Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size
	var at := c.get_global_rect().get_center() * scale
	Input.warp_mouse(at)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		Input.parse_input_event(ev)


func _button(prefix: String, index := 0) -> Button:
	var found := []
	for b in get_tree().root.find_children("*", "Button", true, false):
		if b.text.begins_with(prefix) and b.is_visible_in_tree():
			found.append(b)
	return found[index] if index < found.size() else null


func _texts() -> String:
	var all := []
	for l in get_tree().root.find_children("*", "Label", true, false):
		if l.is_visible_in_tree():
			all.append(l.text)
	return "\n".join(all)


func _next() -> void:
	_step += 1
	_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.4:
		return
	var m := _main()
	match _step:
		0:
			_click(_button("Uramoodi"))
			_next()
		1:
			var t := _texts()
			_check("uran kotinäkymä: päivä 1, maanantai", "Päivä 1 – maanantai 1.6." in t)
			_check("aloitusrahat 50 €", "Rahaa: 50,00 €" in t)
			_check("ei kalastonhoitomaksua: tila ja neuvo näkyvät", not Career.fee_valid() and "Kalastonhoitomaksu: ei maksettu – vain onki ja pilkki sallittu" in t and "maksa se kalastustarvikeliikkeessä" in t)
			_shot("u1-koti")
			_click(_button("Kalastustarvikeliike"))
			_next()
		2:
			_click(_button("Osta", 0)) # ensimmäinen rivi: lusikka
			_next()
		3:
			_check("lusikka ostettu: 44 € jäljellä, 3 kpl", is_equal_approx(Career.money, 44.0) and Career.lures.get("lusikka", 0) == 3)
			_check("vuosimaksu (47 €) pois käytöstä 44 eurolla", _button("Maksa", 0) != null and _button("Maksa", 0).disabled)
			_click(_button("Maksa", 2)) # vuorokausimaksu 6 €
			_step = 30
			_t = 0.0
		30:
			_check("vuorokausimaksu maksettu: 38 € jäljellä", is_equal_approx(Career.money, 38.0) and Career.fee_valid())
			_check("vuosimaksun Maksa pois käytöstä", _button("Maksa", 0).disabled)
			_check("liikkeessä: voimassa 1.6. asti", "Voimassa: 1.6. asti" in _texts() and "Kalastonhoitomaksu maksettu: voimassa 1.6. asti" in _texts())
			_shot("u2-kauppa")
			_click(_button("Takaisin"))
			_step = 4
			_t = 0.0
		4:
			_click(_button("Lähde kalalle"))
			_next()
		5:
			_check("kartta uramoodissa, aika ja sää -valinnat piilossa", m.menu._map_view.visible and not m.menu._map_real.is_visible_in_tree())
			var map: LakeMap = m.menu._map
			var scale := Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size
			var at := (map.get_global_rect().position + map._start_point(0)) * scale
			var move := InputEventMouseMotion.new()
			move.position = at
			move.global_position = at
			Input.parse_input_event(move)
			_next()
		6:
			var map: LakeMap = m.menu._map
			var scale := Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size
			var at := (map.get_global_rect().position + map._start_point(0)) * scale
			for pressed in [true, false]:
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = pressed
				ev.position = at
				ev.global_position = at
				Input.parse_input_event(ev)
			_next()
		7:
			if not (m.running if "running" in m else false):
				return
			_check("kalareissu uramoodissa klo 07:00", Career.active and m.fishing.limited and m.sky.clock_text() == "07:00")
			_check("maksu voimassa: virveliuistimet käyvät (lusikka)", m.fishing.license and m.fishing.lure()["id"] == "lusikka")
			# Saalis: väsytetty kala haaviin
			var f: Fishing = m.fishing
			f._fish_index = 0
			f._fish = m.population.fish[0]
			f._stamina = 0.1
			f.state = Fishing.State.FIGHT
			f._try_land()
			_next()
		8:
			# Haavinta-animaatio (n. 2 s), sitten saalis on kalarepussa
			if m.fishing.state == Fishing.State.LANDING:
				return
			var f: Fishing = m.fishing
			_fish_value = m.trip_catch[0]["weight"] * Career.price(m.trip_catch[0]["species"])
			# Uistin menetetään
			f._lose_lure("Siima katkesi (testi)")
			_check("menetetty uistin vähenee varastosta (lusikka 2)", Career.lures.get("lusikka", 0) == 2)
			m.sky.minutes += 90.0 # reissu kestää 1,5 h
			m.hud.set_paused_view(false)
			_next()
		9:
			_check("saavi HUD:ssa: " + m.hud._status.text.split("\n")[1], "Saavi: 1 kalaa" in m.hud._status.text)
			_shot("u3-reissu")
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_ESCAPE
			ev.keycode = KEY_ESCAPE
			ev.pressed = true
			Input.parse_input_event(ev)
			ev = ev.duplicate()
			ev.pressed = false
			Input.parse_input_event(ev)
			_next()
		10:
			_click(_button("Mene kotiin"))
			_next()
		11:
			if _t < 1.5:
				return
			var t := _texts()
			_check("kotona: saalis säilössä (1 kala)", Career.storage_count() == 1 and "Säilössä: 1 kalaa" in t)
			_check("kotikello reissun jälkeen 08:30", Career.clock_text() == "08:30")
			_money_before = Career.money
			_click(_button("Myy kaloja"))
			_next()
		12:
			_shot("u4-myynti")
			_click(_button("Myy kaikki"))
			_next()
		13:
			_check("kalat myyty %.2f €" % _fish_value, absf(Career.money - _money_before - _fish_value) < 0.02 and Career.storage_count() == 0)
			_click(_button("Takaisin"))
			_next()
		14:
			_click(_button("Nuku"))
			_next()
		15:
			var slider: HSlider = get_tree().root.find_children("*", "HSlider", true, false)[0]
			slider.value = 16
			_shot("u5-nukkuminen")
			_click(_button("Nuku"))
			_next()
		16:
			var t := _texts()
			_check("nukuttiin yli puolenyön: päivä 2, tiistai klo 00:30", Career.day == 2 and Career.weekday() == "tiistai" and Career.clock_text() == "00:30" and "Päivä 2 – tiistai" in t)
			_check("vuorokausimaksu päättyi", not Career.fee_valid() and "Kalastonhoitomaksu: ei maksettu" in t)
			_shot("u6-uusi-paiva")
			for l in _log:
				print(l)
			get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)
	if _t > 40.0:
		_check("vaihe %d jumittui" % _step, false)
		for l in _log:
			print(l)
		get_tree().quit(1)

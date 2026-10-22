extends Node
## Taukovalikon testi oikealla Esc-näppäimellä ja hiiren klikkauksilla:
##   godot -- --pausetest   (vaatii ikkunan)
## Esc avaa valikon ja pysäyttää pelin → Ohjeet → Takaisin → Asetukset (äänet,
## hiiren herkkyys ja käänteinen ohjaus) → Esc → Jatka kalastusta →
## Esc → Esc jatkaa → Esc → Mene kotiin avaa alkuvalikon.
## --shots=KANSIO tallentaa kuvat taukovalikosta ja kotinäkymästä.

var _frame := 0
var _log: Array[String] = []
var _clock := 0.0
var main: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = get_parent()
	main.hud.set_paused_view(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Testi siirtyy pää-scenen ulkopuolelle, jotta se säilyy kotiin palatessa
	reparent.call_deferred(get_tree().root)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.split("=")[1]


var _shots := ""


func _shot(name: String) -> void:
	if _shots != "":
		get_viewport().get_texture().get_image().save_png(_shots.path_join(name + ".png"))


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _click(button: Button) -> void:
	var scale := Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size
	var at := button.get_global_rect().get_center() * scale
	Input.warp_mouse(at)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		Input.parse_input_event(ev)


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _finish(name: String, ok: bool) -> void:
	_check(name, ok)
	for l in _log:
		print(l)


func _process(_delta: float) -> void:
	_frame += 1
	if _frame >= 80 or not is_instance_valid(main):
		return _late()
	var pm: PauseMenu = main.pause_menu
	var b := pm._buttons # Jatka, Ohjeet, Kalakirja, Asetukset, Mene kotiin, Takaisin
	match _frame:
		10:
			_clock = main.sky.minutes
			_key(KEY_ESCAPE)
		18:
			_shot("tauko-valikko")
		20:
			_check("Esc avasi valikon", pm.visible and pm._box.visible)
			_check("peli on tauolla", get_tree().paused)
			_check("aika ei kulu tauolla", is_equal_approx(main.sky.minutes, _clock))
			_check("hiiri vapaana", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
			_click(b[1])
		26:
			_check("Ohjeet aukesivat", pm._help.visible and not pm._box.visible)
			_click(b[-1])
		32:
			_check("Takaisin palasi valikkoon", pm._box.visible and not pm._help.visible)
			_check("painikkeen teksti on Asetukset", b[3].text == "Asetukset")
			_click(b[3])
		38:
			_check("Asetukset aukesivat", pm._settings.visible and not pm._box.visible)
			_shot("tauko-asetukset")
			var controls: SettingsControls = pm._settings.find_children("*", "SettingsControls", true, false)[0]
			controls.volume_sliders["Efektit"].value = 0.5
			controls.volume_sliders["Puhe"].value = 0.0
			controls.sensitivity.value = 2.0
			_click(controls.invert)
		42:
			var fx := AudioServer.get_bus_index("Efektit")
			_check("efektien voimakkuus 50 %% (%.1f dB)" % AudioServer.get_bus_volume_db(fx), absf(AudioServer.get_bus_volume_db(fx) - linear_to_db(0.5)) < 0.01)
			_check("puhe nollassa mykistää väylän", AudioServer.is_bus_mute(AudioServer.get_bus_index("Puhe")))
			_check("hiiren herkkyys 2,0 ja käänteinen ohjaus", is_equal_approx(Settings.mouse_sensitivity, 2.0) and Settings.invert_y)
			_check("kalastajan puhe soi Puhe-väylällä", main.voice._player.bus == &"Puhe")
			_key(KEY_ESCAPE)
		46:
			_check("Esc asetuksista palasi valikkoon", pm.visible and pm._box.visible and not pm._settings.visible)
			_click(b[0])
		50:
			_check("Jatka kalastusta sulki valikon", not pm.visible)
			_check("peli jatkuu", not get_tree().paused)
			_check("hiiri kaapattu peliin", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
			_clock = main.camera_rig.pitch
			var ev := InputEventMouseMotion.new()
			ev.relative = Vector2(0, 20)
			Input.parse_input_event(ev)
		54:
			# Käänteinen ohjaus ja herkkyys 2: hiiri alas kääntää kameraa ylös 20 * 2 * 0,0035
			var turned: float = main.camera_rig.pitch - _clock
			_check("hiiri alas kääntää käänteisenä toiseen suuntaan (%.3f)" % turned, absf(turned + 0.14) < 0.001)
			Settings.invert_y = false
			Settings.mouse_sensitivity = 1.0
			_key(KEY_ESCAPE)
		60:
			_check("Esc avasi valikon uudelleen", pm.visible)
			_key(KEY_ESCAPE)
		66:
			_check("toinen Esc jatkoi peliä", not pm.visible and not get_tree().paused)
			_key(KEY_ESCAPE)
		72:
			_check("painikkeen teksti on Mene kotiin", b[4].text == "Mene kotiin")
			_click(b[4])


## Kotiin paluun jälkeen: pää-scene on ladattu uudelleen
func _late() -> void:
	match _frame:
		110:
			var home: Node = get_tree().current_scene
			_check("Mene kotiin avasi alkuvalikon", not is_instance_valid(main) and home.menu != null and home.menu._main.visible)
			_check("peli ei ole käynnissä kotona", not home.running and not get_tree().paused)
			var texts: Array = home.menu.find_children("*", "Label", true, false).map(func(l): return l.text)
			_check("alkuvalikossa lukee Kotona", "Kotona" in texts)
			_check("hiiri vapaana valikossa", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
			_shot("koti-valikko")
		112:
			_finish("valmis", true)
			get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

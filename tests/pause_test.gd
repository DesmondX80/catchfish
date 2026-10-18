extends Node
## Taukovalikon testi oikealla Esc-näppäimellä ja hiiren klikkauksilla:
##   godot -- --pausetest   (vaatii ikkunan)
## Esc avaa valikon ja pysäyttää pelin → Ohjeet → Takaisin → Jatka kalastusta →
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
	if _frame >= 60:
		return _late()
	var pm: PauseMenu = main.pause_menu
	var b := pm._buttons # Jatka, Ohjeet, Mene kotiin, Takaisin
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
			_click(b[3])
		32:
			_check("Takaisin palasi valikkoon", pm._box.visible and not pm._help.visible)
			_click(b[0])
		38:
			_check("Jatka kalastusta sulki valikon", not pm.visible)
			_check("peli jatkuu", not get_tree().paused)
			_check("hiiri kaapattu peliin", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
			_key(KEY_ESCAPE)
		44:
			_check("Esc avasi valikon uudelleen", pm.visible)
			_key(KEY_ESCAPE)
		50:
			_check("toinen Esc jatkoi peliä", not pm.visible and not get_tree().paused)
			_key(KEY_ESCAPE)
		56:
			_check("painikkeen teksti on Mene kotiin", b[2].text == "Mene kotiin")
			_click(b[2])



## Kotiin paluun jälkeen: pää-scene on ladattu uudelleen
func _late() -> void:
	match _frame:
		90:
			var home: Node = get_tree().current_scene
			_check("Mene kotiin avasi alkuvalikon", not is_instance_valid(main) and home.menu != null and home.menu._main.visible)
			_check("peli ei ole käynnissä kotona", not home.running and not get_tree().paused)
			var texts: Array = home.menu.find_children("*", "Label", true, false).map(func(l): return l.text)
			_check("alkuvalikossa lukee Kotona", "Kotona" in texts)
			_check("hiiri vapaana valikossa", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
			_shot("koti-valikko")
		92:
			_finish("valmis", true)
			get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

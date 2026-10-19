extends Node
## Kalasaavin testi: godot --headless --fixed-fps 30 -- --day=180 --tubtest [--tubtest-shots=KANSIO]
## (talvella --day=40: saavi jäällä kalastajan vieressä)
## Reissun kalat näkyvät saavissa, juuri saatu kala vasta saalisikkunan jälkeen.
## Tab vie kameran saavin yläpuolelle ja näyttää painot sivuikkunassa.

var main: Node
var _log: Array[String] = []
var _step := 0
var _t := 0.0
var _shots := ""


func _ready() -> void:
	main = get_parent()
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tubtest-shots="):
			_shots = arg.split("=")[1]


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _tap(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _next() -> void:
	_step += 1
	_t = 0.0


func _entry(sp: String, weight: float) -> Dictionary:
	return {"species": sp, "name": Species.DATA[sp]["name"], "weight": weight, "length": snappedf(Species.length_cm(sp, weight), 0.5), "lure": "Lusikka 15 g", "time": "07:00"}


func _fish_in_tub() -> int:
	return main.tub._fish_root.get_child_count()


func _process(delta: float) -> void:
	_t += delta
	var f: Fishing = main.fishing
	var tub: CatchTub = main.tub
	var cam: Camera3D = main.camera_rig.camera
	match _step:
		0:
			if _t > 1.0:
				_check("saavi on %s, tyhjä" % ("jäällä" if main.boat.on_ice else "veneessä"), _fish_in_tub() == 0 and tub.global_position.distance_to(main.boat.global_position) < 2.5)
				for e in [_entry("hauki", 2.4), _entry("ahven", 0.3), _entry("sarki", 0.15)]:
					main.trip_catch.append(e)
				_next()
		1:
			if _t > 0.2:
				_check("saavissa 3 kalaa", _fish_in_tub() == 3)
				# Uusi saalis: kala on vielä haavissa / veneen pohjalla
				f._last_catch = _entry("made", 1.2)
				main.trip_catch.append(f._last_catch)
				f.state = Fishing.State.LANDED
				_next()
		2:
			if _t > 0.2:
				_check("juuri saatu kala ei vielä ole saavissa", _fish_in_tub() == 3)
				f.state = Fishing.State.READY # saalisikkuna suljettu
				_next()
		3:
			if _t > 0.2:
				_check("kala siirtyi saaviin (4 kalaa)", _fish_in_tub() == 4)
				_tap("catch_log")
				_next()
		4:
			if _t > 1.5:
				var above := cam.global_position - tub.view_point()
				_check("Tab: kamera saavin yläpuolella (%.2f m ylempänä, %.2f m sivussa)" % [above.y, Vector2(above.x, above.z).length()], main.hud.tub_open() and above.y > 0.5 and Vector2(above.x, above.z).length() < 0.35)
				var text: String = main.hud._log_label.text
				_check("sivuikkunassa painot ja yhteispaino", text.contains("2,40 kg") and text.contains("0,30 kg") and text.contains("Yhteensä 4 kalaa, 4,05 kg"))
				if _shots != "":
					get_viewport().get_texture().get_image().save_png(_shots.path_join("s1-saavi-%s.png" % ("jaa" if main.boat.on_ice else "vene")))
				_tap("catch_log")
				_next()
		5:
			if _t > 1.5:
				var dist := cam.global_position.distance_to(tub.view_point())
				_check("Tab sulki saavinäkymän, kamera palasi (%.1f m saavista)" % dist, not main.hud.tub_open() and dist > 3.0)
				for l in _log:
					print(l)
				get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

extends Node
## FPV-kameran testi:
##   godot --headless --fixed-fps 30 -- --day=180 --fpvtest
## P vaihtaa kameran kalastajan silmiin: kamera on pään kohdalla, pää on
## piilotettu, katsesuunta on heittosuunta ja rulla ei zoomaa. Erikoiskuvassa
## (saavi) pää näkyy taas, ja P palauttaa kameran veneen taakse.

var main: Node
var _log: Array[String] = []
var _step := 0
var _t := 0.0


func _ready() -> void:
	main = get_parent()
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	for f in main.population.fish:
		f["wary"] = 1.0e9 # ei tärppejä


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _press(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _next() -> void:
	_step += 1
	_t = 0.0


func _rig() -> CameraRig:
	return main.camera_rig


func _head() -> Vector3:
	return main.boat.angler.posed_position("Head")


## Näkyykö pää (luurangon muokkaimen tulos on väliaikainen, joten
## tarkistetaan piilotuspyyntö ja päähineen näkyvyys)
func _head_shown() -> bool:
	var a: Angler = main.boat.angler
	return not a.hide_head and a._head_root.visible


func _process(delta: float) -> void:
	_t += delta
	var rig := _rig()
	match _step:
		0:
			if _t > 1.0:
				_check("alussa kamera veneen takana", not rig.first_person and rig.camera.global_position.distance_to(_head()) > 3.0)
				_check("alussa pää näkyy", _head_shown())
				_press("camera_view")
				_next()
		1:
			if _t > 1.5:
				var d: float = rig.camera.global_position.distance_to(_head())
				_check("P: FPV päällä ja tallennettu asetuksiin", rig.first_person and Settings.first_person)
				_check("FPV: kamera pään kohdalla (%.2f m)" % d, d < 0.3)
				_check("FPV: pää piilotettu", not _head_shown())
				_check("FPV: kädet näkyvät", main.boat.angler.posed_position("Middle1.R").distance_to(rig.camera.global_position) < 1.2)
				var fwd := -rig.camera.global_basis.z
				var aim: Vector2 = rig.aim_direction()
				_check("FPV: katse heittosuuntaan", Vector2(fwd.x, fwd.z).normalized().dot(aim) > 0.99)
				var before: float = rig.distance
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_WHEEL_UP
				ev.pressed = true
				rig._unhandled_input(ev)
				_check("FPV: rulla ei zoomaa", rig.distance == before)
				# Hiiri kääntää katsetta ylös ja alas omassa rajassaan
				var look := InputEventMouseMotion.new()
				look.relative = Vector2(0, 5000)
				rig._unhandled_input(look)
				_check("FPV: katse alaspäin rajattu", is_equal_approx(rig.fpv_pitch, 1.3))
				look.relative = Vector2(0, -5000)
				rig._unhandled_input(look)
				_check("FPV: katse ylöspäin rajattu", is_equal_approx(rig.fpv_pitch, -1.0))
				rig.fpv_pitch = 0.3
				rig.tub_view = true
				_next()
		2:
			if _t > 1.5:
				_check("saavin kuva toimii FPV:ssä", rig.camera.global_position.distance_to(main.tub.view_point()) < 1.0)
				_check("saavin kuvassa pää näkyy", _head_shown())
				rig.tub_view = false
				_next()
		3:
			if _t > 1.5:
				_check("saavin jälkeen takaisin silmiin", rig.camera.global_position.distance_to(_head()) < 0.3 and main.boat.angler.hide_head)
				_press("camera_view")
				_next()
		4:
			if _t > 1.5:
				_check("P uudelleen: kamera veneen takana", not rig.first_person and rig.camera.global_position.distance_to(_head()) > 3.0)
				_check("pää näkyy taas", _head_shown())
				_finish()


func _finish() -> void:
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

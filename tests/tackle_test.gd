extends Node
## Kalapakin testi: godot --headless --fixed-fps 30 -- --day=180 --tackletest
## (talvella pilkkirasia: --day=40). L avaa pakin ja kamera siirtyy sen
## yläpuolelle, lokerossa on jokainen uistin ja onki, klikkaus valitsee
## uistimen ja sulkee pakin, uramoodissa puuttuvaa uistinta ei voi valita
## ja heiton aikana pakkia ei avata.
## Kuva avatusta pakista: lisää --tackleshots=KANSIO (vaatii ikkunan).

var main: Node
var box: TackleBox
var _log: Array[String] = []
var _dir := ""


func _ready() -> void:
	main = get_parent()
	box = main.tackle_box
	GameInput.force_active = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tackleshots="):
			_dir = arg.split("=")[1]
	await _wait(1.0)
	await _run()
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _wait(seconds: float) -> void:
	for i in int(seconds * 30.0):
		await get_tree().process_frame


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await get_tree().process_frame


## Hiiren tapahtumat annetaan suoraan pakille: headless-tilassa
## Input.parse_input_event ei välitä hiiren paikkaa
func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		box._unhandled_input(ev)
		await get_tree().process_frame


## Lokeron keskipiste ruudulla
func _screen_pos(id: String) -> Vector2:
	for c in box.compartments:
		if c["id"] == id:
			return get_viewport().get_camera_3d().unproject_position(c["holder"].global_position)
	return Vector2(-1, -1)


func _run() -> void:
	var f: Fishing = main.fishing
	var winter: bool = main.boat.on_ice
	var expected: Array = (Lures.ICE if winter else Lures.LIST).map(func(l): return l["id"])
	var ids: Array = box.compartments.map(func(c): return c["id"])
	ids.sort()
	expected.sort()
	_check("%s: lokeroissa %s" % ["pilkkirasia" if winter else "kalapakki", ", ".join(ids)], ids == expected)
	var dist: float = box.global_position.distance_to(main.boat.global_position)
	_check("pakki %s (%.1f m)" % ["jäällä kalastajan vieressä" if winter else "veneessä kalastajan edessä", dist], dist < 1.5)
	_check("pakki on aluksi kiinni", not box.is_open)

	await _press("lure_next")
	_check("L avaa pakin", box.is_open)
	await _wait(1.0)
	var cam: Camera3D = main.camera_rig.camera
	var to_box := cam.global_position.distance_to(box.global_position)
	_check("kamera pakin yläpuolella (%.2f m)" % to_box, to_box < 1.0 and cam.global_position.y > box.global_position.y)
	var target: String = expected[1] if expected[1] != f.lure()["id"] else expected[0]
	var at := _screen_pos(target)
	var ev := InputEventMouseMotion.new()
	ev.position = at
	box._unhandled_input(ev)
	await get_tree().process_frame
	_check("hiiren alla oleva lokero korostuu: %s" % box.hovered, box.hovered == target)
	_check("tekstissä uistimen nimi: \"%s\"" % box._label.text, Lures.name_of(target) in box._label.text)
	if _dir != "":
		main.hud.set_paused_view(false)
		await _wait(0.5)
		get_viewport().get_texture().get_image().save_png(_dir.path_join("kalapakki_%s.png" % ("talvi" if winter else "kesa")))
	await _click(at)
	_check("klikkaus valitsi uistimen: %s" % f.lure()["id"], f.lure()["id"] == target)
	_check("pakki sulkeutui valinnan jälkeen", not box.is_open)
	await _wait(0.2)
	_check("vedessä/vavan päässä uistimen oma malli", f._lure_node.mesh == LureModels.mesh(target))
	await _wait(1.0)
	var back := cam.global_position.distance_to(box.global_position)
	_check("kamera palasi (%.1f m pakista)" % back, back > 1.5)

	# Uramoodi: uistin, jota ei ole varastossa, ei käy
	f.limited = true
	f.inventory = {expected[0]: 1}
	f.lure_index = 0
	await _press("lure_next")
	await _wait(0.8)
	at = _screen_pos(expected[1])
	await _click(at)
	_check("puuttuvaa uistinta ei voi valita: \"%s\"" % box._label.text, box.is_open and f.lure()["id"] == expected[0] and "ei varastossa" in box._label.text)
	await _press("pause")
	_check("Esc sulkee pakin", not box.is_open)
	_check("Esc ei avannut taukovalikkoa", not main.pause_menu.visible)
	f.limited = false
	f.inventory = {}

	# Kesken heiton pakkia ei avata
	if not winter:
		f.state = Fishing.State.RETRIEVING
		await _press("lure_next")
		_check("kesken kelauksen pakki ei aukea", not box.is_open)
		f.state = Fishing.State.READY
	# Mallit: jokaisella uistimella oma malli
	var sizes := []
	for l in Lures.all():
		sizes.append("%s %.0f cm" % [l["id"], LureModels.length(l["id"]) * 100.0])
	_check("uistinmallit: %s" % ", ".join(sizes), Lures.all().all(func(l): return LureModels.length(l["id"]) > 0.03 and LureModels.length(l["id"]) < 0.12))

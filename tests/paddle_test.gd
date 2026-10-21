extends Node
## Melan ja airojen testi: godot --headless --fixed-fps 30 -- --day=180 --paddletest [--paddletest-shots=KANSIO]
## Vene on alussa laiturin vieressä: laituria kohti oleva airo ei mahdu, vaan
## se on veneen kylkeä pitkin eikä mene laiturin läpi. Melalla (V) vene
## melotaan irti laiturista kylkeä vedoittain vaihtaen, D melotaan vasemmalta
## (vene kääntyy oikealle), ja kauempana laiturista soudetaan taas molemmilla airoilla.

var main: Node
var _log: Array[String] = []
var _messages: Array[String] = []
var _sounds := {}
var _step := 0
var _t := 0.0
var _shots := ""
var _start := Vector2.ZERO
var _yaw := 0.0
var _start_yaw := 0.0
var _sides := {}
var _oar_in_dock := false
var _blade_dry_in_pull := false


func _ready() -> void:
	main = get_parent()
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--paddletest-shots="):
			_shots = arg.split("=")[1]
	main.boat.message.connect(func(text): _messages.append(text))
	main.boat.sound_event.connect(func(sound, _at): _sounds[sound] = _sounds.get(sound, 0) + 1)
	_start = main.boat.pos
	_start_yaw = main.boat.yaw


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _next() -> void:
	_step += 1
	_t = 0.0
	for a in ["boat_forward", "boat_back", "boat_left", "boat_right"]:
		Input.action_release(a)


func _shot(name: String) -> void:
	if _shots != "":
		get_viewport().get_texture().get_image().save_png(_shots.path_join(name + ".png"))


func _calm() -> void:
	var w: Weather = main.weather
	w.wind_base = 0.0
	w.gust = 0.0
	w._wind_target = 0.0
	w._gust_timer = 999.0


func _physics_process(delta: float) -> void:
	_t += delta
	_calm()
	var boat: Boat = main.boat
	var lake: LakeData = main.lake
	# Kumpikaan airo ei saa olla laiturin kannen kohdalla
	for oar in boat._oars:
		var b: Vector3 = oar["blade"].global_position
		_oar_in_dock = _oar_in_dock or lake.near_dock(Vector2(b.x, b.z), 0.0)
	if boat._paddle_stroking and boat._paddle_phase > 0.15 and boat._paddle_phase < 0.35:
		_sides[boat._paddle_side] = true
		_blade_dry_in_pull = _blade_dry_in_pull or boat.paddle_blade().y > 0.0
	match _step:
		0:
			if _t > 1.0 and not Input.is_action_pressed("boat_forward"):
				_check("laiturin puoleinen (vasen) airo ei mahdu, oikea mahtuu", boat.oar_blocked[0] and not boat.oar_blocked[1])
				Input.action_press("boat_forward")
			if _t > 4.0:
				_check("ilmoitus: airo ei mahdu, ota mela", _messages.any(func(m): return m.begins_with("Laituri on liian lähellä – vasen airo")))
				_check("airo ei mennyt laiturin läpi", not _oar_in_dock)
				_shot("mela-1-airo-kyljessa")
				_next()
				boat.toggle_paddle()
		1:
			if _t > 1.0 and not Input.is_action_pressed("boat_forward"):
				_check("mela käteen, airot veneeseen (asento %s)" % Angler.Pose.keys()[boat.angler.pose], boat.paddling and boat.angler.pose == Angler.Pose.PADDLE)
				# Yhdellä airolla soutaminen käänsi keulan laituriin: takaisin aloitusasentoon
				boat.pos = _start
				boat.yaw = _start_yaw
				boat.velocity = Vector2.ZERO
				boat.yaw_rate = 0.0
				Input.action_press("boat_forward")
			if _t > 3.0 and _t < 3.05:
				_shot("mela-2-melotaan")
			if _t > 15.0:
				var moved := boat.pos.distance_to(_start)
				_check("melottiin eteen irti laiturista (%.1f m, %.1f km/h)" % [moved, boat.speed_kmh()], moved > 6.0)
				_check("kylki vaihtui vedoittain", _sides.size() == 2)
				_check("lapa vedessä vedon aikana", not _blade_dry_in_pull)
				_check("melonnan ääni (%d vetoa)" % _sounds.get("paddle_stroke", 0), _sounds.get("paddle_stroke", 0) >= 5)
				_check("airo ei mennyt laiturin läpi", not _oar_in_dock)
				_next()
				_sides.clear()
				_yaw = boat.yaw
				Input.action_press("boat_right")
		2:
			if _t > 8.0:
				var turned := wrapf(boat.yaw - _yaw, -PI, PI)
				_check("D: melotaan vasemmalta, vene kääntyy oikealle (%.0f°)" % rad_to_deg(turned), turned < -0.3 and _sides.keys() == [-1.0])
				_next()
				boat.toggle_paddle()
		3:
			if _t > 2.0 and not Input.is_action_pressed("boat_forward"):
				_check("mela pois", not boat.paddling and boat.angler.pose != Angler.Pose.PADDLE)
				_check("laiturista irti: molemmat airot mahtuvat", not boat.oar_blocked[0] and not boat.oar_blocked[1])
				_sounds.erase("oar_stroke")
				Input.action_press("boat_forward")
			if _t > 8.0:
				_check("soudetaan molemmilla airoilla (%.1f km/h)" % boat.speed_kmh(), boat._rowing and boat.speed_kmh() > 2.0)
				_check("airovedon ääni (%d)" % _sounds.get("oar_stroke", 0), _sounds.get("oar_stroke", 0) >= 2)
				_finish()


func _finish() -> void:
	_next()
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

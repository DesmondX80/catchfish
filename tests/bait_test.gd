extends Node
## Onki ja syötit: godot --headless --fixed-fps 30 -- --day=180 --baittest [--baittest-shots=KANSIO]
## Koho-ongen mato roikkuu kohon alla säädetyssä syvyydessä (G syventää,
## vain ennen heittoa),
## pohjaongen mato noin 0,5 m pohjan yläpuolella. Tärpissä koho nykii ensin:
## liian aikainen vastaisku pelästyttää kalan, kohon uppoamisen jälkeen kala tarttuu.
## Koho kelluu aallokon mukana ja kallistelee.

const LINE := 15.0

var main: Node
var _log: Array[String] = []
var _messages: Array[String] = []
var _step := 0
var _t := 0.0
var _spot := Vector2.ZERO
var _dir := Vector2.ZERO
var _tries := 0
var _shots := ""
var _bob_min := INF
var _bob_max := -INF
var _bob_tilt := 0.0


func _ready() -> void:
	main = get_parent()
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	main.fishing.message.connect(func(t): _messages.append(t))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--baittest-shots="):
			_shots = arg.split("=")[1]
	for f in main.population.fish:
		f["wary"] = 1.0e9 # tärpit tehdään testissä itse
	_find_spot()
	# Kohtalainen tuuli, jotta koho keinuu aallokossa (aallokko riippuu tuulesta ja pyyhkäisymatkasta)
	main.weather.wind_base = 5.0
	main.weather._wind_target = 5.0
	Waves.reset(5.0, main.weather.wind_direction)


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _tap(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


## Kohon korkeus aaltopinnasta (0 = kelluu pinnalla)
func _float_y(f: Fishing) -> float:
	var p := f._bobber_node.global_position
	return p.y - Waves.swell_height(Vector2(p.x, p.z))


func _next() -> void:
	_step += 1
	_t = 0.0


func _find_spot() -> void:
	var lake: LakeData = main.lake
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var best := -1.0
	var origin := Vector2(lake.start_position.x, lake.start_position.z)
	for i in 4000:
		var p := origin + Vector2(rng.randf_range(-1500, 1500), rng.randf_range(-1500, 1500))
		var d := Vector2.from_angle(rng.randf() * TAU)
		var shallowest := 99.0
		var deepest := 0.0
		for s in range(-20, 3, 2):
			var q := p + d * s
			shallowest = minf(shallowest, lake.depth_at(q.x, q.y) if lake.is_water(q.x, q.y) else 0.0)
			deepest = maxf(deepest, lake.depth_at(q.x, q.y))
		# Tasainen, enintään 4 m syvä paikka (syvänteissä uistin vajoaa liian syvälle)
		if shallowest > best and deepest <= 4.0:
			best = shallowest
			_spot = p
			_dir = d


func _select(id: String) -> void:
	var f: Fishing = main.fishing
	f.lure_index = f.lures().map(func(l): return l["id"]).find(id)


## Syötti heitetty LINE metrin päähän, siima löysällä
func _place() -> void:
	var f: Fishing = main.fishing
	var boat: Boat = main.boat
	boat.pos = _spot
	boat.velocity = Vector2.ZERO
	boat._apply_transform()
	var at := _spot - _dir * LINE
	f.state = Fishing.State.RETRIEVING
	f.lure_on_land = false
	f.snagged = false
	f.lure_speed = 0.0
	f.lure_pos = Vector3(at.x, 0.0, at.y)
	f._prev_lure = f.lure_pos
	f.line_out = LINE + 3.0


## Kala maistelee matoa (kuten fishing.gd:n tärpin alussa)
func _force_bite() -> void:
	var f: Fishing = main.fishing
	var p := Vector2(f.lure_pos.x, f.lure_pos.z)
	var near: Array = main.population.fish_near(p, 40.0)
	f._fish_index = near[0] if not near.is_empty() else 0
	f._fish = main.population.fish[f._fish_index]
	f.state = Fishing.State.BITE
	f._bite_timer = Fishing.BAIT_SINK_TIME + 1.2
	_tries += 1


func _process(delta: float) -> void:
	_t += delta
	var f: Fishing = main.fishing
	var boat: Boat = main.boat
	boat.pos = _spot
	boat.velocity = Vector2.ZERO
	var bottom := main.lake.depth_at(f.lure_pos.x, f.lure_pos.z) as float
	if _t > 20.0:
		_check("testi jumittui vaiheeseen %d (tila %d)" % [_step, f.state], false)
		_step = 7
		_t = 99.0
	match _step:
		0:
			if _t > 0.5:
				_select("koho")
				f.state = Fishing.State.READY
				for i in 5:
					_tap("float_deeper") # ennen heittoa: 1,0 -> 1,5 m
				_next()
		1:
			if _t > 0.2 and f.float_depth > 1.4:
				_check("G syventää ennen heittoa: kohon syvyys %.1f m" % f.float_depth, absf(f.float_depth - 1.5) < 0.01)
				_check("vavan kärjessä roikkuu mato (ei uistinpalloa)", f._worm_node.visible and not f._lure_node.visible)
				if _shots != "":
					# Lähikuva madosta (lainataan haavinnan kamerakuvaa)
					var w: Vector3 = f._worm_node.global_position + Vector3(0, -0.04, 0)
					var eye := w + Vector3(0.18, 0.03, 0.12)
					main.camera_rig.shot = Transform3D(Basis.looking_at(w - eye), eye)
					main.camera_rig.shot_view = true
					_step = 11
					_t = 0.0
				else:
					_place()
					_step = 10
					_t = 0.0
		11:
			# Kuva seuraa matoa (vapa liikkuu kalastajan kädessä)
			var w: Vector3 = f._worm_node.global_position + Vector3(0, -0.04, 0)
			var eye := w + Vector3(0.18, 0.03, 0.12)
			main.camera_rig.shot = Transform3D(Basis.looking_at(w - eye), eye)
			if _t > 1.5:
				get_viewport().get_texture().get_image().save_png(_shots.path_join("mato.png"))
				main.camera_rig.shot_view = false
				_place()
				_step = 10
				_t = 0.0
		10:
			if f._bobber_node.visible and _t > 0.5:
				var y: float = f._bobber_node.global_position.y
				_bob_min = minf(_bob_min, y)
				_bob_max = maxf(_bob_max, y)
				_bob_tilt = maxf(_bob_tilt, f._bobber_node.global_basis.y.normalized().angle_to(Vector3.UP))
			if _t > 4.0:
				_check("koho-ongen mato kohon alla %.2f m syvyydessä (asetus 1,5 m)" % f.lure_depth(), absf(f.lure_depth() - 1.5) < 0.1)
				_check("koho näkyy aaltopinnalla", f._bobber_node.visible and absf(_float_y(f)) < 0.01)
				_check("koho nousee ja laskee aallokon mukana (%.2f m)" % (_bob_max - _bob_min), _bob_max - _bob_min > 0.03)
				_check("koho kallistelee (%.0f°)" % rad_to_deg(_bob_tilt), _bob_tilt > deg_to_rad(2.0) and _bob_tilt < deg_to_rad(25.0))
				_check("koho on oikean kokoinen", absf(f._bobber_node.global_basis.y.length() - Fishing.BOBBER_SCALE) < 0.01)
				_bob_min = INF
				_bob_max = -INF
				_bob_tilt = 0.0
				var cam: Camera3D = main.camera_rig.camera
				var to_bobber := cam.global_position.distance_to(f._bobber_node.global_position)
				_check("kamera zoomaa kohon lähelle (%.1f m)" % to_bobber, main.camera_rig.bobber_view and to_bobber < 3.5)
				_check("kohon alla olevaa siimaa ei piirretä", f._line_mesh.get_surface_count() == 1)
				_check("mato ei näy veden alla", not f._lure_node.visible and not f._worm_node.visible)
				if _shots != "":
					main.camera_rig.yaw = boat.yaw + PI + 0.3
					main.camera_rig.pitch = 0.3
					get_viewport().get_texture().get_image().save_png(_shots.path_join("koho.png"))
				for i in 3:
					_tap("float_deeper") # vedessä ei voi säätää
				_step = 2
				_t = 0.0
		2:
			if _t > 1.0:
				_check("kohon syvyyttä ei voi säätää heiton jälkeen (%.1f m)" % f.float_depth, absf(f.float_depth - 1.5) < 0.01 and _messages.any(func(m): return m.contains("vain ennen heittoa")))
				_force_bite()
				_next()
		3:
			if _t > 0.3:
				var nibbling := _float_y(f) > -0.05
				_tap("cast") # liian aikaisin
				_check("koho nykii vielä pinnalla, kun kala maistelee (%.2f m)" % _float_y(f), nibbling)
				_step = 30 # odotetaan, että painallus käsitellään
				_t = 0.0
		30:
			if _t > 0.2:
				_check("liian aikaisesta vastaiskusta varoitetaan", _messages.any(func(m): return m.contains("Liian aikaisin")))
				f.state = Fishing.State.RETRIEVING # jos kala tarttui, aloitetaan alusta
				f._fish_index = -1
				_force_bite()
				_step = 4
				_t = 0.0
		4:
			if f._bite_timer < Fishing.BAIT_SINK_TIME - 0.2:
				_check("koho upposi pinnan alle (%.2f m)" % _float_y(f), _float_y(f) < -0.1 and _messages.any(func(m): return m.contains("KOHO UPPOSI")))
				_tap("cast")
				_next()
		5:
			if _t > 0.2:
				if f.state == Fishing.State.FIGHT:
					_check("vastaisku kohon uppoamisen jälkeen: kala tarttui (%d. yritys)" % (_tries - 1), true)
					f.state = Fishing.State.READY
					_next()
				elif _tries > 8:
					_check("kala ei tarttunut kohon uppoamisen jälkeenkään", false)
					_next()
				else:
					f.state = Fishing.State.RETRIEVING
					_force_bite()
					_step = 4
		6:
			_select("pohja")
			_place()
			_next()
		7:
			if _t > 7.0:
				_check("pohjaongen mato %.2f m syvyydessä, %.2f m pohjan yläpuolella (pohja %.1f m)" % [f.lure_depth(), bottom - f.lure_depth(), bottom], absf(bottom - f.lure_depth() - 0.5) < 0.1)
				_check("pohjaongessa ei kohoa", not f._bobber_node.visible)
				_check("pohjaongen mato ei näy veden alla", not f._lure_node.visible and not f._worm_node.visible)
				_check("pohjaongessa kamera ei zoomaa", not main.camera_rig.bobber_view)
				for l in _log:
					print(l)
				get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

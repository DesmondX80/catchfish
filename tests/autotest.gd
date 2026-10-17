extends Node
## Automaattinen pelitesti tasapainon säätämiseen: ajaa veneellä, kalastaa
## puoli tuntia ja tulostaa tulokset. Käynnistys:
##   godot --headless --fixed-fps 30 -- --autotest

var main: Node
var frame := 0
var phase := "boot"
var phase_t := 0.0
var stats := {"casts": 0, "bites": 0, "hooked": 0, "caught": 0, "messages": {}}
var start_pos := Vector2.ZERO
var catches := []

func _ready() -> void:
	main = get_parent()
	# --start=N: aloituspaikka (0 = oletus)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--start="):
			var i := int(arg.split("=")[1])
			main.lake.select_start(i)
			main.boat.pos = Vector2(main.lake.start_position.x, main.lake.start_position.z)
			main.boat.yaw = main.lake.start_yaw
			print("Aloituspaikka: ", main.lake.starts[i]["name"])

## --mouse: vasemman hiiren toiminnot oikeina hiiren klikkauksina, hiiri kaapattuna
var _real_mouse := "--mouse" in OS.get_cmdline_user_args()
var _mouse_down := false


func press(action: String, pressed := true) -> void:
	if _real_mouse and action == "cast":
		if pressed == _mouse_down:
			return
		_mouse_down = pressed
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		var center := Vector2(DisplayServer.window_get_size()) / 2.0
		Input.warp_mouse(center)
		mb.position = center
		mb.global_position = center
		Input.parse_input_event(mb)
		return
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)
	if pressed: Input.action_press(action)
	else: Input.action_release(action)

func _process(delta: float) -> void:
	frame += 1
	phase_t += delta
	if frame == 2:
		if _real_mouse:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			main.hud.set_paused_view(false)
		else:
			GameInput.force_active = true
		main.fishing.message.connect(func(t): stats["messages"][t.split("!")[0].left(40)] = stats["messages"].get(t.split("!")[0].left(40), 0) + 1)
		main.boat.message.connect(func(t): print("  vene: ", t))
		main.fishing.caught.connect(func(e, r): catches.append(e))
		print("Kaloja: ", main.population.count_by_species(), "  syvyys alussa %.2f m" % main.boat.depth_below())
		start_pos = main.boat.pos
		press("motor_toggle"); press("motor_toggle", false)
		phase = "motor"; phase_t = 0
	var boat = main.boat
	var f = main.fishing
	match phase:
		"motor":
			if phase_t > 1.5 and phase_t < 4.0: press("boat_forward")
			elif phase_t >= 4.0: press("boat_forward", false)
			if phase_t > 25.0:
				print("Moottorilla 25 s: matka %.0f m, nopeus %.1f km/h, kaasu %.2f, syvyys %.1f m, paikka %s" % [boat.pos.distance_to(start_pos), boat.speed_kmh(), boat.throttle, boat.depth_below(), main.lake.nearest_place(boat.pos.x, boat.pos.y)])
				press("boat_back")
				phase = "stop"; phase_t = 0
		"stop":
			if boat.throttle <= 0.0:
				press("boat_back", false)
				press("motor_toggle"); press("motor_toggle", false)
				press("anchor_toggle"); press("anchor_toggle", false)
				main.sky.minutes = 6.5 * 60
				if "--spot=reeds" in OS.get_cmdline_user_args():
					_move_to_reed_edge()
				phase = "fish"; phase_t = 0
				print("Ankkuroitu, nopeus %.1f km/h" % boat.speed_kmh())
		"fish":
			main.camera_rig.yaw = boat.yaw + sin(stats["casts"] * 1.7) * 0.8
			match f.state:
				Fishing.State.READY:
					press("reel", false)
					press("cast")
				Fishing.State.CHARGING:
					if f.power > (0.32 if "--spot=reeds" in OS.get_cmdline_user_args() else 0.8):
						press("cast", false)
						stats["casts"] += 1
				Fishing.State.RETRIEVING:
					# kelataan välillä tauotellen
					press("reel", fmod(phase_t, 3.0) < 2.4)
				Fishing.State.BITE:
					if randf() < 0.1:
						stats["bites"] += 1
						press("cast"); press("cast", false)
				Fishing.State.FIGHT:
					if f.landing_ready() and f.fish_stamina() < 0.3:
						press("cast"); press("cast", false)
					else:
						press("reel", f.tension < f.drag_kg * 0.9)
				Fishing.State.LANDED:
					press("cast", false)
					press("cast"); press("cast", false)
			if frame % 900 == 0: print("  t=%.0f s tila=%d heittoja=%d kalat=%d" % [phase_t, f.state, stats["casts"], catches.size()])
			if phase_t > (60.0 if "--short" in OS.get_cmdline_user_args() else 1800.0):
				report()
				get_tree().quit()

func report() -> void:
	print("\n30 min kalastusta (klo 6:30–7:00), heittoja %d" % stats["casts"])
	for e in catches:
		print("  SAALIS: %s %.2f kg %.0f cm (%s)" % [e["name"], e["weight"], e["length"], e["lure"]])
	print("Viestit: ")
	for k in stats["messages"]:
		print("  %3d × %s" % [stats["messages"][k], k])
	print("Menetetyt uistimet: %d" % main.fishing.lost_lures)


## Siirtää veneen hyvälle haukipaikalle: n. 25 m kaislikon reunasta, keula rantaan päin
func _move_to_reed_edge() -> void:
	var lake: LakeData = main.lake
	var boat: Boat = main.boat
	var best := Vector2.ZERO
	var best_score := -1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 4000:
		var p := boat.pos + Vector2(rng.randf_range(-700, 700), rng.randf_range(-700, 700))
		var shore := lake.shore_distance(p.x, p.y)
		if not lake.is_water(p.x, p.y) or shore < 22.0 or shore > 30.0 or lake.depth_at(p.x, p.y) < 1.2:
			continue
		var score: float = main.population.habitat_score("hauki", p)
		if score > best_score:
			best_score = score
			best = p
	# Keula kohti lähintä rantaa
	var to_shore := Vector2.ZERO
	var nearest := 1e9
	for a in 36:
		var dir := Vector2.from_angle(a * TAU / 36.0)
		for d in range(2, 60, 2):
			var q := best + dir * d
			if not lake.is_water(q.x, q.y):
				if d < nearest:
					nearest = d
					to_shore = dir
				break
	boat.pos = best
	boat.velocity = Vector2.ZERO
	boat.yaw = atan2(-to_shore.x, -to_shore.y)
	boat.anchor_point = best
	print("Siirretty kaislikon reunaan: syvyys %.1f m, rantaan %.0f m, hauen elinpaikka %.2f, lähellä %s" % [lake.depth_at(best.x, best.y), nearest, best_score, lake.nearest_place(best.x, best.y)])

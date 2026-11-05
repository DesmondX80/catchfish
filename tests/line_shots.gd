extends Node
## Siiman kuvat (CATCHFISH-86): samat tilanteet kuin suunnitelman nykytilan
## kuvissa sekä katkennut pätkä ja välkkeen tarkistus kääntyvällä kameralla.
## Lokiin tulostuu piirretyn siiman suurin taitekulma (>>-rivit).
##   godot --fixed-fps 30 --disable-vsync -- --day=180 --lineshots=KANSIO   (talvi: --day=40)
## Näytönohjaimella (WSL): GALLIUM_DRIVER=d3d12 MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA

var _dir := ""
var _frame := 0
var _index := 0
var _shots: Array[Dictionary] = []
var main: Node
var _spot := Vector2.ZERO
var _sdir := Vector2.ZERO
var f: Fishing


func _ready() -> void:
	main = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lineshots="):
			_dir = arg.split("=")[1]
	DirAccess.make_dir_recursive_absolute(_dir)
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	for f in main.population.fish:
		f["wary"] = 1.0e9
	main.weather.set_kind(Weather.Kind.PARTLY, true)
	main.weather.wind_base = 3.0
	f = main.fishing
	if f.on_ice:
		_winter()
		return
	_find_spot()
	var boat: Boat = main.boat
	boat.pos = _spot
	boat.velocity = Vector2.ZERO
	boat.yaw = atan2(-_sdir.x, -_sdir.y)
	boat._apply_transform()
	_shots = [
		{"name": "01-heitto-lennossa", "hour": 12.0, "frames": 14,
			"setup": func():
				_rig(0.0, 0.32, 8.0)
				f.lure_index = _lure("lusikka")
				f.power = 0.7
				f._cast(),
			"cam": func(): _orbit(PI / 2.0, 0.12, 9.0)},
		{"name": "02-loysa-heiton-jalkeen-sivu", "hour": 12.0, "frames": 70,
			"cam": func(): _orbit(PI / 2.0, 0.12, 9.0)},
		{"name": "03-loysa-pelikamera", "hour": 12.0, "frames": 30,
			"cam": func(): _orbit(0.0, 0.32, 8.0)},
		{"name": "04-loysa-vesiraja-lahikuva", "hour": 12.0, "frames": 30,
			"cam": func(): _close_entry()},
		{"name": "05-kelaus-kirea-sivu", "hour": 12.0, "frames": 90,
			"setup": func(): Input.action_press("reel"),
			"cam": func(): _orbit(PI / 2.0, 0.12, 9.0)},
		{"name": "06-kirea-vesiraja-lahikuva", "hour": 12.0, "frames": 20,
			"cam": func(): _close_entry()},
		{"name": "07-kirea-taivasta-vasten", "hour": 12.0, "frames": 20,
			"cam": func(): _against_sky()},
		{"name": "08-pitka-heitto-pelikamera", "hour": 12.0, "frames": 120,
			"setup": func():
				Input.action_release("reel")
				_reset_rod()
				_rig(0.0, 0.32, 8.0)
				f.power = 1.0
				f._cast(),
			"cam": func(): _orbit(0.0, 0.32, 8.0)},
		{"name": "09-pitka-heitto-kaukaa-sivulta", "hour": 12.0, "frames": 20,
			"cam": func(): _orbit(PI / 2.0 - 0.5, 0.25, 25.0)},
		{"name": "10-pitka-kelaus-pelikamera", "hour": 12.0, "frames": 150,
			"setup": func(): Input.action_press("reel"),
			"cam": func(): _orbit(0.0, 0.32, 8.0)},
		{"name": "11-fpv-kirea", "hour": 12.0, "frames": 45,
			"setup": func():
				main.camera_rig.first_person = true
				main.camera_rig.fpv_pitch = 0.2,
			"cam": func(): main.camera_rig.yaw = main.boat.yaw},
		{"name": "12-fpv-alas", "hour": 12.0, "frames": 30,
			"setup": func(): main.camera_rig.fpv_pitch = 0.7,
			"cam": func(): main.camera_rig.yaw = main.boat.yaw},
		{"name": "13-koho-sivu", "hour": 12.0, "frames": 100,
			"setup": func():
				Input.action_release("reel")
				main.camera_rig.first_person = false
				_reset_rod()
				f.lure_index = _lure("koho")
				_rig(0.0, 0.32, 8.0)
				f.power = 0.5
				f._cast(),
			"cam": func(): _orbit(PI / 2.0, 0.12, 8.0)},
		{"name": "14-koho-lahikuva", "hour": 12.0, "frames": 30,
			"cam": func(): _close_entry()},
		{"name": "15-kova-tuuli-loysa", "hour": 12.0, "frames": 90,
			"setup": func():
				_reset_rod()
				main.weather.wind_base = 12.0
				main.weather.wind_direction = main.boat.yaw + PI / 2.0
				f.lure_index = _lure("lusikka")
				_rig(0.0, 0.32, 8.0)
				f.power = 0.6
				f._cast(),
			"cam": func(): _orbit(0.0, 0.7, 10.0)},
		{"name": "16-kova-tuuli-sivu", "hour": 12.0, "frames": 20,
			"cam": func(): _orbit(PI / 2.0, 0.12, 9.0)},
		{"name": "17-hauki-vasytys-sivu", "hour": 12.0, "frames": 40,
			"setup": func():
				main.weather.wind_base = 3.0
				_reset_rod()
				_hook("hauki", 4.0, main.boat.forward() * 12.0, -0.8),
			"cam": func(): _orbit(PI / 2.0, 0.12, 7.0)},
		{"name": "18-hauki-pelikamera", "hour": 12.0, "frames": 20,
			"cam": func(): _orbit(0.0, 0.32, 8.0)},
		{"name": "19-hauki-vesiraja-lahikuva", "hour": 12.0, "frames": 20,
			"cam": func(): _close_entry()},
		{"name": "20-kala-veneen-alla", "hour": 12.0, "frames": 40,
			"setup": func():
				_reset_rod()
				_hook("ahven", 1.0, -main.boat.right() * 1.5, -2.5)
				f._run_dir = -main.boat.right(),
			"cam": func(): _orbit(PI / 2.0 + 0.2, 0.25, 6.0)},
		{"name": "21-kala-veneen-alla-toiselta-puolelta", "hour": 12.0, "frames": 15,
			"cam": func(): _orbit(-PI / 2.0, 0.25, 6.0)},
		{"name": "22-ilta-kirea", "hour": 21.8, "frames": 40,
			"setup": func():
				_reset_rod()
				_hook("hauki", 3.0, main.boat.forward() * 15.0, -0.8),
			"cam": func(): _orbit(PI / 2.0 - 0.3, 0.15, 7.0)},
		{"name": "23-uistelu-sivu", "hour": 12.0, "frames": 150,
			"setup": func():
				_reset_rod()
				f.lure_index = _lure("lusikka")
				_lure_behind(25.0, 1.5)
				_tap("rod_holder"),
			"press": "boat_forward",
			"cam": func(): _orbit(PI / 2.0 + 0.6, 0.3, 12.0)},
		{"name": "24-uistelu-perasta-ylhaalta", "hour": 12.0, "frames": 20,
			"press": "boat_forward",
			"cam": func(): _orbit(PI, 0.6, 9.0)},
		{"name": "25-uistelu-fpv-taakse", "hour": 12.0, "frames": 45,
			"press": "boat_forward",
			"setup": func():
				main.camera_rig.first_person = true
				main.camera_rig.fpv_pitch = 0.25,
			"cam": func(): main.camera_rig.yaw = main.boat.yaw + PI},
		{"name": "26-katkennut-patka-sivu", "hour": 12.0, "frames": 60,
			"setup": func():
				Input.action_release("boat_forward")
				main.camera_rig.first_person = false
				f._take_rod(0, "")
				f.held = 0
				_reset_rod()
				_hook("hauki", 4.0, main.boat.forward() * 10.0, -0.8)
				f._lose_fish("Siima katkesi!", true),
			"cam": func(): _orbit(PI / 2.0, 0.12, 5.0)},
		{"name": "27-katkennut-patka-pelikamera", "hour": 12.0, "frames": 20,
			"cam": func(): _orbit(0.0, 0.32, 6.0)},
		{"name": "28-loysa-40m-pelikamera", "hour": 12.0, "frames": 120,
			"setup": func():
				f._tie_line()
				_reset_rod()
				f.lure_index = _lure("vaappu")
				_rig(0.0, 0.32, 8.0)
				f.power = 1.0
				f._cast(),
			"cam": func(): _orbit(0.0, 0.32, 8.0)},
		{"name": "29-pinnan-alla-sivu", "hour": 12.0, "frames": 40,
			"setup": func():
				_reset_rod()
				_hook("hauki", 2.0, main.boat.forward() * 6.0, -1.5),
			"cam": func(): _orbit(PI / 2.0, 0.05, 4.0)},
		# Välke: kireä siima, kamera kääntyy hitaasti; kuvat peräkkäisistä ruuduista
		{"name": "30-valke-1", "hour": 12.0, "frames": 40,
			"setup": func():
				_reset_rod()
				_hook("hauki", 3.0, main.boat.forward() * 18.0, -0.8),
			"cam": func(): _orbit(0.25 + _frame * 0.002, 0.3, 8.0)},
		{"name": "30-valke-2", "hour": 12.0, "frames": 1,
			"cam": func(): _orbit(0.25 + 40 * 0.002 + 0.002, 0.3, 8.0)},
		{"name": "30-valke-3", "hour": 12.0, "frames": 1,
			"cam": func(): _orbit(0.25 + 40 * 0.002 + 0.004, 0.3, 8.0)},
		{"name": "30-valke-4", "hour": 12.0, "frames": 1,
			"cam": func(): _orbit(0.25 + 40 * 0.002 + 0.006, 0.3, 8.0)},
	]


func _winter() -> void:
	var boat: Boat = main.boat
	_shots = [
		{"name": "w1-pilkki-avanto", "hour": 12.0, "frames": 90,
			"setup": func():
				var front := boat.pos + boat.forward() * Fishing.HOLE_AHEAD
				var hole := Vector3(front.x, 0.0, front.y)
				f.holes.append(hole)
				f._add_hole_visual(hole)
				f.current_hole = hole
				f.state = Fishing.State.RETRIEVING
				f.lure_pos = Vector3(hole.x, -1.5, hole.z)
				f.line_out = f.rod_tip().distance_to(Vector3(hole.x, 0, hole.z)) + 1.5,
			"cam": func(): _orbit(PI / 2.0, 0.15, 3.5)},
		{"name": "w2-vasytys-jaan-alla", "hour": 12.0, "frames": 40,
			"setup": func():
				_hook("ahven", 0.6, boat.forward() * Fishing.HOLE_AHEAD + boat.right() * 4.0, -2.0),
			"cam": func(): _orbit(PI / 2.0 + 0.4, 0.35, 5.0)},
		{"name": "w3-vasytys-jaan-alla-sivu", "hour": 12.0, "frames": 15,
			"cam": func(): _orbit(-PI / 2.0, 0.15, 5.0)},
		{"name": "w4-pelikamera-lunta-vasten", "hour": 12.0, "frames": 15,
			"cam": func(): _orbit(0.4, 0.32, 4.0)},
		{"name": "w5-katkennut-patka", "hour": 12.0, "frames": 50,
			"setup": func(): f._lose_fish("Siima katkesi!", true),
			"cam": func(): _orbit(PI / 2.0, 0.15, 3.0)},
	]


func _lure(id: String) -> int:
	var list: Array = main.fishing.lures()
	for i in list.size():
		if list[i]["id"] == id:
			return i
	return 0


func _rig(yaw: float, pitch: float, dist: float) -> void:
	var rig: CameraRig = main.camera_rig
	rig.shot_view = false
	rig.yaw = main.boat.yaw + yaw
	rig.pitch = pitch
	rig.distance = dist


func _orbit(yaw: float, pitch: float, dist: float) -> void:
	_rig(yaw, pitch, dist)


func _look(eye: Vector3, target: Vector3) -> void:
	var rig: CameraRig = main.camera_rig
	rig.shot = Transform3D(Basis.looking_at(target - eye), eye)
	rig.shot_view = true


## Lähikuva kohdasta, jossa siima menee veteen, sivulta matalalta
func _close_entry() -> void:
	var pts := _points(main.fishing._line_mesh)
	if pts.size() < 2:
		return
	var entry: Vector3 = pts[-1]
	for p in pts:
		if p.y <= 0.02:
			entry = p
			break
	var chord: Vector3 = pts[-1] - pts[0]
	var perp := Vector3(-chord.z, 0, chord.x).normalized()
	_look(entry + perp * 2.2 + Vector3(0, 0.35, 0), entry + Vector3(0, 0.1, 0))


## Kireä siima taivasta vasten: kamera matalalla siiman alla
func _against_sky() -> void:
	var pts := _points(main.fishing._line_mesh)
	if pts.size() < 2:
		return
	var mid: Vector3 = pts[pts.size() / 3]
	var chord: Vector3 = pts[-1] - pts[0]
	var perp := Vector3(-chord.z, 0, chord.x).normalized()
	_look(Vector3(mid.x, 0.3, mid.z) + perp * 1.5, mid + Vector3(0, 0.6, 0))


func _points(mesh: ArrayMesh) -> PackedVector3Array:
	return FishingLine.curve_points(mesh)


## Suurin taitekulma peräkkäisten siimasegmenttien välillä
## Suurin taitekulma piirretyssä siimassa (2 cm:n välein kuten --linetest).
## Erikseen kaikki taitteet ja suurin taite sallittujen kiinnekohtien
## ulkopuolella: vavan kärki ja siiman pää (0,15 m), veneen laita (0,25 m
## rungosta), avanto ja yli 0,5 m syvyys (häivytetty näkymättömiin).
## Hyväksymiskriteeri koskee vain jälkimmäistä ("muualla").
func _report(name: String) -> void:
	var hull_inv: Transform3D = main.boat.hull.global_transform.affine_inverse()
	var hole := f._line_hole()
	for i in f.rod_count():
		var mesh: ArrayMesh = f._rod_get(i, "_line_mesh")
		var pts := _resampled(_points(mesh))
		if pts.size() < 3:
			continue
		var worst := 0.0
		var at := 0
		var why := ""
		var free := 0.0
		var free_at := 0
		for k in range(1, pts.size() - 1):
			var a: Vector3 = pts[k] - pts[k - 1]
			var b: Vector3 = pts[k + 1] - pts[k]
			if a.length() < 1e-4 or b.length() < 1e-4:
				continue
			var ang := rad_to_deg(a.angle_to(b))
			var reason := _allowed(pts, k, hull_inv, hole)
			if ang > worst:
				worst = ang
				at = k
				why = reason
			if reason == "" and ang > free:
				free = ang
				free_at = k
		var below := 0
		for p in pts:
			if p.y < -0.01:
				below += 1
		print(">> %s vapa %d: pisteitä %d, suurin taite %.1f° pisteessä %d/%d (%.2f, %.2f, %.2f)%s; muualla suurin %.1f° pisteessä %d (%s), vedessä %d pistettä, line_out %.1f, jännitys %.2f kg, tila %s" % [
			name, i + 1, pts.size(), worst, at, pts.size() - 1, pts[at].x, pts[at].y, pts[at].z,
			" [sallittu: %s]" % why if why != "" else "", free, free_at, "OK" if free <= 5.0 else "YLI 5°", below,
			f._rod_get(i, "line_out"), f._rod_get(i, "tension"), Fishing.State.keys()[f._rod_get(i, "state")]])


## Miksi taite kohdassa k on sallittu (tyhjä = ei sallittu)
func _allowed(pts: PackedVector3Array, k: int, hull_inv: Transform3D, hole: Vector3) -> String:
	var p: Vector3 = pts[k]
	if p.distance_to(pts[0]) < 0.15:
		return "vavan kärki"
	if p.distance_to(pts[pts.size() - 1]) < 0.15:
		return "siiman pää"
	if hole != Vector3.INF and p.distance_to(hole) < 0.02:
		return "avanto"
	var l := hull_inv * p
	if absf(l.z) <= 2.45 and l.y <= 0.9 and l.y >= -0.55:
		var h := Boat._hull_at(clampf(l.z, -2.2, 2.2))
		if absf(l.x) < h.x + 0.25 and l.y < h.y + 0.25 and l.y > h.z - 0.25:
			return "veneen laita"
	if not f.on_ice and p.y < -0.5 and main.lake.is_water(p.x, p.z):
		return "syvällä, häivytetty"
	return ""


func _resampled(pts: PackedVector3Array, step := 0.02) -> PackedVector3Array:
	if pts.size() < 4:
		return pts
	var out := PackedVector3Array([pts[0]])
	var carry := 0.0
	for k in range(1, pts.size()):
		var a: Vector3 = pts[k - 1]
		var b: Vector3 = pts[k]
		var seg := a.distance_to(b)
		var t := step - carry
		while t <= seg:
			out.append(a.lerp(b, t / seg))
			t += step
		carry = seg - (t - step)
	if out[out.size() - 1].distance_to(pts[pts.size() - 1]) > step * 0.25:
		out.append(pts[pts.size() - 1])
	return out


func _reset_rod() -> void:
	f.state = Fishing.State.READY
	f._fish_index = -1
	f.tension = 0.0
	f.line_out = 0.0


func _hook(sp: String, weight: float, offset: Vector2, depth: float) -> void:
	var boat: Boat = main.boat
	var idx := 0
	for i in main.population.fish.size():
		if main.population.fish[i]["sp"] == sp:
			idx = i
			break
	main.population.fish[idx]["weight"] = weight
	f._fish_index = idx
	f._fish = main.population.fish[idx]
	var p := boat.pos + offset
	f._fish_pos = Vector3(p.x, depth, p.y)
	f.lure_pos = f._fish_pos
	f.line_out = f.rod_tip().distance_to(f._fish_pos)
	f._stamina = 1.0
	f._run_intensity = 1.0
	f._run_dir = offset.normalized()
	f._run_timer = 10.0
	f.drag_kg = 4.0
	f._fish_known = true
	f.state = Fishing.State.FIGHT


func _lure_behind(dist: float, side: float) -> void:
	var boat: Boat = main.boat
	var at := boat.pos - boat.forward() * dist + boat.right() * side
	f.state = Fishing.State.RETRIEVING
	f.lure_pos = Vector3(at.x, -0.5, at.y)
	f._prev_lure = f.lure_pos
	f.line_out = f.rod_tip().distance_to(f.lure_pos)


func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var ev2 := InputEventAction.new()
	ev2.action = action
	ev2.pressed = false
	Input.parse_input_event(ev2)


func _find_spot() -> void:
	var lake: LakeData = main.lake
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var best := -1.0
	var origin := Vector2(lake.start_position.x, lake.start_position.z)
	for i in 6000:
		var p := origin + Vector2(rng.randf_range(-1500, 1500), rng.randf_range(-1500, 1500))
		var d := Vector2.from_angle(rng.randf() * TAU)
		var shallowest := 99.0
		for s in range(-40, 70, 4):
			var q := p + d * s
			shallowest = minf(shallowest, lake.depth_at(q.x, q.y) if lake.is_water(q.x, q.y) else 0.0)
		if shallowest > best:
			best = shallowest
			_spot = p
			_sdir = d


func _process(_delta: float) -> void:
	var limit := int(OS.get_environment("LINESHOTS_MAX")) if OS.has_environment("LINESHOTS_MAX") else _shots.size()
	if _index >= mini(limit, _shots.size()):
		get_tree().quit()
		return
	_frame += 1
	var shot: Dictionary = _shots[_index]
	if _frame == 1:
		main.sky.minutes = shot["hour"] * 60.0
		if shot.has("setup"):
			shot["setup"].call()
	if shot.has("press"):
		Input.action_press(shot["press"])
	shot["cam"].call()
	if _frame >= shot["frames"]:
		_report(shot["name"])
		var only := OS.get_environment("LINESHOTS_ONLY").split(",", false)
		if only.is_empty() or (shot["name"] as String).get_slice("-", 0) in only:
			get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, shot["name"]])
		_index += 1
		_frame = 0

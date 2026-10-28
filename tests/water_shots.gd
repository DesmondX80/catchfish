extends Node
## Veden kuvat ja ruudun aika (CATCHFISH-77, vaatii ikkunan):
##   godot --fixed-fps 30 -- --day=180 --watershots=/polku/kansioon [--waterquality=matala] [--watershots-timing]
## Kuvat järvestä eri tuulilla selällä FPV- ja kolmannen persoonan korkeudelta,
## ylätuulen ja alatuulen rannassa, puuskassa ja ylhäältä. Tuuli puhaltaa
## pohjoiseen, ja kamera katsoo sen mukana poispäin keskipäivän auringosta
## (kuten --foamshots). Lopuksi aloitusnäkymä laiturista (aloituspaikka 0,
## kapea lahti) pelin kameralla eri tuulilla pelin alkutuulen suunnasta. Lopuksi mitataan keskimääräinen ruudun aika 300
## ruudun ajalta samasta kuvakulmasta (8 m/s, kolmas persoona).
## --watershots-timing: vain ruudun aika, ei kuvia.
## --watershots-only=01,17,19: vain nämä kuvat (numerot), ei ruudun aikaa.

const TIMING_FRAMES := 300
const SHOTS := [
	# nimi, tuuli (m/s), puuska (m/s), silmän korkeus, katseen etäisyys, paikka
	["01-tyyni-fpv", 0.5, 0.0, 1.3, 8.0, "selka"],
	["02-tyyni-3p", 0.5, 0.0, 3.0, 14.0, "selka"],
	["03-2ms-fpv", 2.0, 0.0, 1.3, 8.0, "selka"],
	["04-2ms-3p", 2.0, 0.0, 3.0, 14.0, "selka"],
	["05-4ms-fpv", 4.0, 0.0, 1.3, 8.0, "selka"],
	["06-4ms-3p", 4.0, 0.0, 3.0, 14.0, "selka"],
	["07-8ms-fpv", 8.0, 0.0, 1.3, 8.0, "selka"],
	["08-8ms-3p", 8.0, 0.0, 3.0, 14.0, "selka"],
	["09-12ms-fpv", 12.0, 0.0, 1.3, 8.0, "selka"],
	["10-12ms-3p", 12.0, 0.0, 3.0, 14.0, "selka"],
	["11-8ms-kauas", 8.0, 0.0, 2.0, 60.0, "selka"],
	["12-8ms-ylatuulen-ranta", 8.0, 0.0, 3.0, 14.0, "ylatuuli"],
	["13-8ms-alatuulen-ranta", 8.0, 0.0, 3.0, 30.0, "alatuuli"],
	["14-puuska", 3.0, 3.0, 8.0, 40.0, "selka"],
	["15-8ms-ylhaalta", 8.0, 0.0, 12.0, 6.0, "selka"],
	# Vana aallokossa: vene ajaa pohjoiseen, kamera veneen takana ja yläpuolella
	["16-vana-6ms", 6.0, 0.0, 5.0, 12.0, "vene"],
	["17-laituri-0.5ms", 0.5, 0.0, 0.0, 0.0, "laituri"],
	["18-laituri-2ms", 2.0, 0.0, 0.0, 0.0, "laituri"],
	["19-laituri-3ms", 3.0, 0.0, 0.0, 0.0, "laituri"],
	["20-laituri-5ms", 5.0, 0.0, 0.0, 0.0, "laituri"],
	["21-laituri-8ms", 8.0, 0.0, 0.0, 0.0, "laituri"],
]

var _dir := ""
var _frame := 0
var _index := 0
var main: Node
var _places := {}
var _timing_start := 0
var _gpu_total := 0.0
var _gpu_frames := PackedFloat32Array()
var _only: PackedStringArray = []
var _start := Vector2.ZERO
var _start_yaw := 0.0
var _start_dir := 0.0


func _ready() -> void:
	main = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--watershots="):
			_dir = arg.split("=")[1]
		elif arg.begins_with("--watershots-only="):
			_only = arg.split("=")[1].split(",")
		elif arg == "--watershots-timing":
			_index = SHOTS.size()
		elif arg.begins_with("--watershots-scale="):
			get_viewport().scaling_3d_scale = float(arg.split("=")[1]) # raskaampi piirto mittaukseen
	DirAccess.make_dir_recursive_absolute(_dir)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	main.hud.visible = false
	main.weather.set_kind(Weather.Kind.CLEAR, true)
	_start = main.boat.pos
	_start_yaw = main.boat.yaw
	_start_dir = main.weather.wind_direction
	_find_places()
	main.boat.pos = _places["selka"] + Vector2(40.0, 10.0) # vene sivussa, ei varjoa kuvaan
	print("veden laatu: %s" % Settings.water_quality)


## Kuvauspaikat: selkä (pyyhkäisymatka n. 2 km, pohjoiseen avointa vettä),
## ylätuulen ranta (rannan suojassa, vettä pohjoiseen) ja alatuulen ranta
## (pitkä pyyhkäisymatka, ranta 40–90 m pohjoisessa)
func _find_places() -> void:
	var lake: LakeData = main.lake
	seed(77)
	var best := {"selka": -1.0, "ylatuuli": -1.0, "alatuuli": -1.0}
	for i in 30000:
		var p := Vector2(lake.origin_x, lake.origin_z) + Vector2(randf(), randf()) * lake.world_size()
		if lake.depth_at(p.x, p.y) < 1.0:
			continue
		var f := lake.fetch_at(p.x, p.y, 0.0)
		var open := 0.0
		while open < 120.0 and lake.is_water(p.x, p.y - open):
			open += 5.0
		if f > 1800.0 and f < 2400.0 and open >= 120.0 and lake.shore_distance(p.x, p.y) > best["selka"]:
			best["selka"] = lake.shore_distance(p.x, p.y)
			_places["selka"] = p
		var shore_d := lake.shore_distance(p.x, p.y)
		if f > 30.0 and f < 150.0 and shore_d > 30.0 and shore_d < 90.0 and open >= 60.0 and open > best["ylatuuli"]:
			best["ylatuuli"] = open
			_places["ylatuuli"] = p
		if f > 1200.0 and open >= 40.0 and open <= 90.0 and f > best["alatuuli"]:
			best["alatuuli"] = f
			_places["alatuuli"] = p
	for k in _places:
		var p: Vector2 = _places[k]
		print("%s: (%.0f, %.0f), pyyhkäisymatka %.0f m, rantaan %.0f m" % [k, p.x, p.y, lake.fetch_at(p.x, p.y, 0.0), lake.shore_distance(p.x, p.y)])


func _set_view(shot: Array) -> void:
	main.sky.minutes = 12.0 * 60.0
	var w: Weather = main.weather
	w.wind_base = shot[1]
	w._wind_target = shot[1]
	w.wind_direction = _start_dir if shot[5] == "laituri" else 0.0
	w.gust = shot[2]
	w._gust_target = 0.0
	var boat: Boat = main.boat
	boat.velocity = Vector2.ZERO
	if shot[5] == "laituri":
		main.camera_rig.shot_view = false # pelin oma kamera veneen takana
		return
	if shot[5] == "vene":
		boat.yaw = 0.0
		boat.velocity = Vector2(0.0, -3.0) # 3 m/s pohjoiseen
		var eye_b := Vector3(boat.pos.x + 3.0, shot[3], boat.pos.y + 8.0)
		var at_b := Vector3(boat.pos.x, 0.0, boat.pos.y + 4.0)
		main.camera_rig.shot = Transform3D(Basis.looking_at(at_b - eye_b), eye_b)
		main.camera_rig.shot_view = true
		return
	var from: Vector2 = _places[shot[5]]
	var eye := Vector3(from.x, shot[3], from.y)
	var at := Vector3(from.x, 0.0, from.y - shot[4])
	main.camera_rig.shot = Transform3D(Basis.looking_at(at - eye), eye)
	main.camera_rig.shot_view = true


func _process(_delta: float) -> void:
	while not _only.is_empty() and _index < SHOTS.size() and not _only.has(String(SHOTS[_index][0]).left(2)):
		_index += 1
	if not _only.is_empty() and _index >= SHOTS.size():
		get_tree().quit()
		return
	if _index < SHOTS.size():
		var shot: Array = SHOTS[_index]
		_frame += 1
		if _frame == 1:
			Waves.reset(shot[1], _start_dir if shot[5] == "laituri" else 0.0) # aallokko heti tuulen mukaiseksi
			if shot[5] == "vene":
				main.boat.pos = _places["selka"]
			elif shot[5] == "laituri":
				main.boat.pos = _start
				main.boat.yaw = _start_yaw
		_set_view(shot)
		if _frame > (150 if shot[5] == "vene" else 45 if shot[5] == "laituri" else 30):
			var img := get_viewport().get_texture().get_image()
			img.save_png(_dir.path_join(shot[0] + ".png"))
			print("kuva %s: vaahtoa %.2f %% kuvan alaosasta" % [shot[0], _white_fraction(img) * 100.0])
			_index += 1
			_frame = 0
		return
	# Ruudun aika samasta kuvakulmasta
	_set_view(SHOTS[7])
	_frame += 1
	if _frame == 30:
		Waves.reset(8.0, 0.0)
		_timing_start = Time.get_ticks_usec()
		_gpu_total = 0.0
		_gpu_frames.clear()
	elif _frame > 30:
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
		_gpu_total += gpu
		_gpu_frames.append(gpu)
		if _frame == 30 + TIMING_FRAMES:
			var ms := (Time.get_ticks_usec() - _timing_start) / 1000.0 / TIMING_FRAMES
			_gpu_frames.sort()
			print("ruudun aika (%s, %s): keskimäärin %.2f ms, GPU %.2f ms (mediaani %.2f ms), lähiveden verteksejä %d" % [Settings.water_quality, SHOTS[7][0], ms, _gpu_total / TIMING_FRAMES, _gpu_frames[_gpu_frames.size() / 2], main.world.near_vertex_count()])
			get_tree().quit()


## Valkoisten pikseleiden osuus kuvan alaosassa (vesi; taivas on yläosassa)
func _white_fraction(img: Image) -> float:
	var count := 0
	var total := 0
	for y in range(img.get_height() * 6 / 10, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			total += 1
			if c.v > 0.8 and c.s < 0.15:
				count += 1
	return float(count) / total

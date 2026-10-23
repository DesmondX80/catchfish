extends Node
## Välkkymisen ja nykimisen mittaus (vaatii ikkunan):
##   godot --fixed-fps 60 --resolution 480x270 -- --day=180 --jittershots=/polku/kansioon [--jitter-still] [--jitter-noshadow] [--jitter-stopsun] [--jitter-hz=60]
## Kamera kääntyy hitaasti ja tasaisesti (--jitter-still: pysyy paikallaan, jolloin
## reunojen aliasointi ei näy mutta keinuvan veneen välke näkyy). Tasaisessa liikkeessä pikselin väri
## muuttuu ruudusta toiseen vain yhteen suuntaan, joten edestakainen vaihtelu
## (A → B → A) on välkettä tai nykimistä: päällekkäiset pinnat, eri tahdissa
## päivittyvät osat tai varjon reunat. Jokaisesta kuvasta tallennetaan
## viimeinen ruutu, jossa heiluvat pikselit on merkitty punaisella, ja
## tulostetaan heiluvien pikselien määrä. Kuvat ajetaan sekä fysiikan
## tahdissa (60 Hz) että eri tahdissa (45 Hz, kuten 144 Hz:n näytöllä).

const FRAMES := 48 # mitattavat ruudut kuvaa kohden
const SETTLE := 40 # ruutuja ennen mittausta (kamera ehtii paikalleen)
const THRESHOLD := 20 # kirkkauden muutos (0–255), joka lasketaan muutokseksi

var _dir := ""
var _frame := 0
var _index := 0
var _shots: Array[Dictionary] = []
var _prev := PackedByteArray()
var _prev_delta := PackedInt32Array()
var _counts := PackedInt32Array()
var main: Node


func _ready() -> void:
	main = get_parent()
	var still := false
	var rates := [60, 45]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--jittershots="):
			_dir = arg.split("=")[1]
		elif arg == "--jitter-still":
			still = true
		elif arg == "--jitter-noshadow":
			main.sky.sun.shadow_enabled = false
		elif arg == "--jitter-stopsun":
			main.sky.set_process(false) # aurinko ja varjot paikallaan
		elif arg.begins_with("--jitter-hz="):
			rates = [int(arg.split("=")[1])]
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	main.weather.set_kind(Weather.Kind.CLEAR, true)
	main.weather.wind_base = 0.5
	main.weather._wind_target = 0.5
	main.sky.minutes = 15.0 * 60.0
	var views: Array[Dictionary] = [
		# nimi, FPV, kameran kallistus, kääntö veneen suunnasta, kääntönopeus (rad/ruutu)
		{"name": "perä", "fpv": false, "pitch": 0.45, "turn": 0.25, "distance": 4.0, "speed": 0.002},
		{"name": "sivu", "fpv": false, "pitch": 0.3, "turn": 1.3, "distance": 5.0, "speed": 0.002},
		{"name": "fpv-eteen", "fpv": true, "pitch": 0.35, "turn": 0.0, "speed": 0.003},
		{"name": "fpv-sivulle", "fpv": true, "pitch": 0.6, "turn": 1.0, "speed": 0.003},
		{"name": "fpv-perään", "fpv": true, "pitch": 0.9, "turn": 2.6, "speed": 0.003},
		{"name": "saavi", "fpv": false, "pitch": 0.45, "turn": 0.0, "distance": 4.0, "speed": 0.002, "tub": true},
	]
	for hz in rates:
		for v in views:
			var s := v.duplicate()
			s["hz"] = hz
			if still:
				s["speed"] = 0.0
			_shots.append(s)


func _process(_delta: float) -> void:
	if _index >= _shots.size():
		get_tree().quit()
		return
	var s: Dictionary = _shots[_index]
	var rig: CameraRig = main.camera_rig
	_frame += 1
	if _frame == 1:
		Engine.physics_ticks_per_second = s["hz"]
		rig.first_person = s["fpv"]
		rig.tub_view = s.get("tub", false)
		if s["fpv"]:
			rig.fpv_pitch = s["pitch"]
		else:
			rig.pitch = s["pitch"]
			rig.distance = s.get("distance", 6.0)
		rig.yaw = main.boat.yaw + s["turn"]
		_prev = PackedByteArray()
		_prev_delta = PackedInt32Array()
		_counts = PackedInt32Array()
	rig.yaw += s["speed"]
	if _frame < SETTLE:
		return
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_L8)
	var data := img.get_data()
	var n := data.size()
	if _counts.is_empty():
		_counts.resize(n)
		_prev_delta.resize(n)
	if not _prev.is_empty():
		for i in n:
			var d := data[i] - _prev[i]
			var p := _prev_delta[i]
			if (d > THRESHOLD and p < -THRESHOLD) or (d < -THRESHOLD and p > THRESHOLD):
				_counts[i] += 1
			_prev_delta[i] = d
	_prev = data
	if _frame >= SETTLE + FRAMES:
		_save(s)
		_index += 1
		_frame = 0


func _save(s: Dictionary) -> void:
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var w := img.get_width()
	var total := 0
	for i in _counts.size():
		if _counts[i] >= 2:
			total += 1
			img.set_pixel(i % w, i / w, Color(1, 0, 0).lerp(Color(1, 1, 0), clampf((_counts[i] - 2) / 8.0, 0.0, 1.0)))
	DirAccess.make_dir_recursive_absolute(_dir)
	var name := "%s-%dhz" % [s["name"], s["hz"]]
	img.save_png("%s/%s.png" % [_dir, name])
	print("%-16s heiluvia pikseleitä %d" % [name, total])

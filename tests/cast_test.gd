extends Node
## Heiton tähtäimen testi: godot --headless --fixed-fps 30 -- --day=180 --casttest [--casttest-shots=KANSIO]
## Heitetään eri voimilla avoveteen ja kohti rantaa: tähtäimen arvio osumapisteestä
## vastaa uistimen todellista putoamispaikkaa, ja rantaan menevästä heitosta varoitetaan.

const POWERS := [0.3, 0.65, 1.0]

var main: Node
var _log: Array[String] = []
var _step := 0
var _t := 0.0
var _cast := 0
var _preview: Dictionary = {}
var _open_dir := Vector2.ZERO
var _shore_dir := Vector2.ZERO
var _shore_pos := Vector2.ZERO
var _shots := ""


func _ready() -> void:
	main = get_parent()
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--casttest-shots="):
			_shots = arg.split("=")[1]
	for f in main.population.fish:
		f["wary"] = 1.0e9 # ei tärppejä
	_find_shore_spot()


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _press(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _next() -> void:
	_step += 1
	_t = 0.0


## Paikka, josta on toiseen suuntaan avovettä ja toiseen ranta noin 20 metrin päässä
func _find_shore_spot() -> void:
	var lake: LakeData = main.lake
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var origin := Vector2(lake.start_position.x, lake.start_position.z)
	for i in 20000:
		var p := origin + Vector2(rng.randf_range(-1200, 1200), rng.randf_range(-1200, 1200))
		if not lake.is_water(p.x, p.y) or lake.depth_at(p.x, p.y) < 1.0:
			continue
		var d := Vector2.from_angle(rng.randf() * TAU)
		var open := true
		for s in range(2, 45, 3):
			var q := p + d * s
			open = open and lake.is_water(q.x, q.y)
		var shore := -d
		var land_at := -1
		for s in range(2, 30):
			var q := p + shore * s
			if not lake.is_water(q.x, q.y):
				land_at = s
				break
		if open and land_at >= 14 and land_at <= 22:
			_shore_pos = p
			_open_dir = d
			_shore_dir = shore
			print("Testipaikka: avovettä 45 m, ranta %d m päässä" % land_at)
			return
	print("Testipaikkaa ei löytynyt")


func _aim(dir: Vector2) -> void:
	var boat: Boat = main.boat
	boat.pos = _shore_pos
	boat.velocity = Vector2.ZERO
	main.camera_rig.yaw = atan2(-dir.x, -dir.y)


func _physics_process(delta: float) -> void:
	_t += delta
	var f: Fishing = main.fishing
	var toward_shore := _cast >= POWERS.size()
	_aim(_shore_dir if toward_shore else _open_dir)
	match _step:
		0:
			if _t > 0.5:
				f.state = Fishing.State.READY
				_press("cast", true)
				_next()
		1:
			# Ladataan heittovoimaa, kunnes tavoitevoima on saavutettu
			var target: float = 1.0 if toward_shore else POWERS[_cast]
			if f.state == Fishing.State.CHARGING and f.power >= target:
				_preview = f.cast_preview.duplicate()
				_check("tähtäin näkyy heittoa ladatessa", f._aim_marker.visible and not _preview.is_empty())
				if _shots != "" and (toward_shore or _cast == POWERS.size() - 1):
					get_viewport().get_texture().get_image().save_png(_shots.path_join("tahtain-%s.png" % ("ranta" if toward_shore else "vesi")))
				_press("cast", false)
				_next()
		2:
			if f.state == Fishing.State.RETRIEVING:
				var landed: Vector3 = f.lure_pos
				var p: Vector3 = _preview["point"]
				var err := Vector2(landed.x - p.x, landed.z - p.z).length()
				if toward_shore:
					_check("rantaan menevästä heitosta varoitetaan (arvio %.0f m, maalle)" % _preview["distance"], not _preview["water"] and f.lure_on_land)
				else:
					_check("voima %.2f: arvio %.1f m, uistin putosi %.2f m päähän arviosta" % [POWERS[_cast], _preview["distance"], err], _preview["water"] and not f.lure_on_land and err < 1.0)
				_check("tähtäin piiloon heiton jälkeen", not f._aim_marker.visible)
				_cast += 1
				if _cast > POWERS.size():
					_finish()
				else:
					_step = 0
					_t = 0.0
			elif _t > 10.0:
				_check("heitto ei pudonnut (tila %d)" % f.state, false)
				_finish()


func _finish() -> void:
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

extends Node
## Uistinten uintisyvyyden testi: godot --headless --fixed-fps 30 -- --day=180 --luretest
## Jokaiselle avovesiuistimelle: lepo heiton jälkeen, kelaus, kelauksen tauko,
## nopea kelaus ja uistelu. Lusikat ja lipat vajoavat levossa nopeasti ja
## nousevat kelatessa hiljalleen, mutta pysyvät pinnan alla. Vaaput kelluvat
## levossa pinnalla ja uivat vedettäessä tavoitesyvyydessään.

const LINE := 22.0 # uistimen etäisyys veneestä kelauksen alussa (m)
const TROLL_SPEED := 0.9 # m/s, soutuvauhti

var main: Node
var _log: Array[String] = []
var _spot := Vector2.ZERO
var _dir := Vector2.ZERO
var _lure := 0
var _phase := ""
var _t := 0.0
var _boat_pos := Vector2.ZERO
var _min_depth := 0.0
var _max_rise := 0.0
var _prev_depth := 0.0
var _phase_start_depth := 0.0


func _ready() -> void:
	main = get_parent()
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	for f in main.population.fish:
		f["wary"] = 1.0e9 # ei tärppejä kesken mittausten
	_find_spot()
	_start_lure(0)


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _press(action: String, pressed := true) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


## Syvä vesialue, jossa uistelusuunnassa on syvää koko testimatkan
func _find_spot() -> void:
	var lake: LakeData = main.lake
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var best := -1.0
	var origin := Vector2(lake.start_position.x, lake.start_position.z)
	for i in 6000:
		var p := origin + Vector2(rng.randf_range(-1500, 1500), rng.randf_range(-1500, 1500))
		var d := Vector2.from_angle(rng.randf() * TAU)
		var shallowest := 99.0
		for s in range(-30, 25, 3):
			var q := p + d * s
			shallowest = minf(shallowest, lake.depth_at(q.x, q.y) if lake.is_water(q.x, q.y) else 0.0)
		if shallowest > best:
			best = shallowest
			_spot = p
			_dir = d
	print("Testipaikka: matalin kohta %.1f m" % best)


func _lure_data() -> Dictionary:
	return main.fishing.lure()


func _depth() -> float:
	return main.fishing.lure_depth()


func _bottom() -> float:
	var p: Vector3 = main.fishing.lure_pos
	return main.lake.depth_at(p.x, p.z)


## Uistin juuri pudonnut veteen LINE metrin päähän, siima löysällä
func _start_lure(i: int) -> void:
	_lure = i
	var f: Fishing = main.fishing
	f.lure_index = i
	_boat_pos = _spot
	_place_boat()
	f.state = Fishing.State.RETRIEVING
	f.snagged = false
	f.lure_on_land = false
	f.lure_speed = 0.0
	var at := _spot - _dir * LINE
	f.lure_pos = Vector3(at.x, 0.0, at.y)
	f._prev_lure = f.lure_pos
	f._leave_slack()
	_set_phase("rest")


func _place_boat() -> void:
	var boat: Boat = main.boat
	boat.pos = _boat_pos
	boat.velocity = Vector2.ZERO
	boat.yaw = atan2(-_dir.x, -_dir.y) # keula uistelusuuntaan
	main.camera_rig.yaw = boat.yaw + PI # heittosuunta perään
	# Vavan kärki heti uuteen paikkaan, jotta siiman pituus lasketaan oikein
	boat._apply_transform()
	main.fishing._aim_angler(1.0)
	main.fishing._update_rod(0.0)


func _set_phase(p: String) -> void:
	_phase = p
	_t = 0.0
	_min_depth = 99.0
	_max_rise = 0.0
	_prev_depth = _depth()
	_phase_start_depth = _prev_depth


func _physics_process(dt: float) -> void:
	_t += dt
	var f: Fishing = main.fishing
	if _phase == "troll":
		_boat_pos += _dir * TROLL_SPEED * dt
	_place_boat()
	f.snagged = false # mitataan uintisyvyyttä: pohjakiinni (ja siiman katkeaminen) ohitetaan
	if f.state != Fishing.State.RETRIEVING:
		_check("%s: tila vaihtui kesken (%d)" % [_lure_data()["name"], f.state], false)
		_next_lure()
		return
	var depth := _depth()
	if _t > 1.0:
		_min_depth = minf(_min_depth, depth)
	_max_rise = maxf(_max_rise, (_prev_depth - depth) / dt)
	_prev_depth = depth
	var l := _lure_data()
	var sink: bool = l["kind"] == "sink"
	var name: String = l["name"]
	match _phase:
		"rest":
			if _t > 4.0:
				if sink:
					_check("%s vajoaa levossa: %.1f m 4 s:ssa (pohja %.1f m)" % [name, depth, _bottom()], depth > minf(_bottom() - 0.2, 2.0))
				else:
					_check("%s kelluu levossa pinnalla: %.2f m" % [name, depth], depth < 0.02)
				_press("reel")
				_set_phase("reel")
		"reel":
			if _t > 12.0:
				if sink:
					_check("%s pysyy pinnan alla kelatessa: matalin %.2f m" % [name, _min_depth], _min_depth >= 0.25)
					_check("%s nousee hiljalleen: nopein nousu %.2f m/s" % [name, _max_rise], _max_rise <= 0.35)
				else:
					var target := minf(l["max_dive"], _bottom() - 0.05)
					_check("%s ui kelatessa tavoitesyvyydessä: %.2f m (tavoite %.2f m)" % [name, depth, target], absf(depth - target) < 0.3)
				_press("reel", false)
				_set_phase("pause")
		"pause":
			# vaappu ehtii nousta tavoitesyvyydestään pinnalle
			if _t > (5.0 if sink else l["max_dive"] / l["float"] + 1.5):
				if sink:
					_check("%s vajoaa kelauksen tauolla: %.2f → %.2f m" % [name, _phase_start_depth, depth], depth > _phase_start_depth + 0.5 or depth > _bottom() - 0.2)
				else:
					_check("%s nousee tauolla pinnalle: %.2f m" % [name, depth], depth < 0.05)
				_start_troll()
		"troll":
			if _t > 15.0:
				if sink:
					_check("%s pysyy uistellessa pinnan alla: matalin %.2f m, nyt %.2f m" % [name, _min_depth, depth], _min_depth >= 0.25)
				else:
					var target := minf(l["max_dive"], _bottom() - 0.05)
					_check("%s ui uistellessa tavoitesyvyydessä: %.2f m (tavoite %.2f m)" % [name, depth, target], absf(depth - target) < 0.3)
				if sink:
					_start_fast()
				else:
					_next_lure()
		"fast":
			if _t > 10.0:
				_check("%s pysyy nopeassa kelauksessa pinnan alla: matalin %.2f m" % [name, _min_depth], _min_depth >= 0.25)
				_press("reel", false)
				_press("reel_fast", false)
				_next_lure()


## Uistelu: uistin LINE metriä veneen perässä pohjassa (tai pinnalla), siima kireällä
func _start_troll() -> void:
	var f: Fishing = main.fishing
	_boat_pos = _spot
	_place_boat()
	var at := _spot - _dir * LINE
	var sink: bool = _lure_data()["kind"] == "sink"
	var depth := minf(main.lake.depth_at(at.x, at.y) - 0.1, 3.0) if sink else 0.0
	f.lure_pos = Vector3(at.x, -depth, at.y)
	f._prev_lure = f.lure_pos
	f.lure_speed = 0.0
	f.line_out = f.rod_tip().distance_to(f.lure_pos)
	_set_phase("troll")


## Nopea kelaus pohjasta
func _start_fast() -> void:
	_start_troll()
	_press("reel")
	_press("reel_fast")
	_set_phase("fast")


func _next_lure() -> void:
	_press("reel", false)
	_press("reel_fast", false)
	if _lure + 1 < main.fishing.lures().size():
		_start_lure(_lure + 1)
	else:
		for l in _log:
			print(l)
		get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

class_name Fishing
extends Node3D
## Virvelillä kalastus: heitto, uistimen uinti, tärppi ja vastaisku,
## väsytys jarrulla sekä haavinta.

signal message(text: String)
signal caught(entry: Dictionary, record: bool)
signal sound_event(sound: String, at: Vector3)

enum State { READY, CHARGING, FLYING, RETRIEVING, BITE, FIGHT, LANDED }

const ROD_LENGTH := 2.1
const LINE_STRENGTH := 6.5 # kg, 0,28 mm monofiili
const REEL_SPEED := 0.85 # m/s
const REEL_SPEED_FAST := 1.6
const CAST_ANGLE := deg_to_rad(32.0)
const GRAVITY := 9.81

var boat: Boat
var camera_rig: CameraRig
var lake: LakeData
var population: FishPopulation
var weather: Weather
var sky: SkyTime

var state := State.READY
var lure_index := 0
var drag_kg := 3.0
var power := 0.0
var line_out := 0.0
var tension := 0.0
var drag_slipping := false
var lure_pos := Vector3.ZERO
var lure_speed := 0.0
var lure_on_land := false
var snagged := false
var lost_lures := 0

var _lure_vel := Vector3.ZERO
var _prev_lure := Vector3.ZERO
var _twitch := 0.0
var _bite_timer := 0.0
var _check_timer := 0.0
var _fish_index := -1
var _fish: Dictionary = {}
var _fish_pos := Vector3.ZERO
var _stamina := 1.0
var _run_timer := 0.0
var _run_dir := Vector2.ZERO
var _run_intensity := 0.0
var _slack_time := 0.0
var _landing_prompt := false
var _last_catch: Dictionary = {}
var _rng := RandomNumberGenerator.new()

var _rod_pivot: Node3D
var _rod_tip: Node3D
var _line_mesh: ImmediateMesh
var _lure_node: MeshInstance3D
var _fish_node: MeshInstance3D


func setup(boat_node: Boat, rig: CameraRig, lake_data: LakeData, fish_pop: FishPopulation, weather_node: Weather, sky_time: SkyTime) -> void:
	boat = boat_node
	camera_rig = rig
	lake = lake_data
	population = fish_pop
	weather = weather_node
	sky = sky_time
	_rng.randomize()
	_build_visuals()


func lure() -> Dictionary:
	return Lures.LIST[lure_index]


func lure_depth() -> float:
	return maxf(0.0, -lure_pos.y)


func rod_tip() -> Vector3:
	return _rod_tip.global_position


func hooked_fish() -> Dictionary:
	return _fish if state == State.FIGHT else {}


func fish_stamina() -> float:
	return _stamina


func landing_ready() -> bool:
	return _landing_prompt


func last_catch() -> Dictionary:
	return _last_catch


func _unhandled_input(event: InputEvent) -> void:
	if not GameInput.active():
		return
	if event.is_action_pressed("cast"):
		match state:
			State.READY:
				state = State.CHARGING
				power = 0.0
			State.BITE:
				_try_hook(0.85, "Vastaisku!")
			State.FIGHT:
				if _landing_prompt:
					_try_land()
			State.LANDED:
				state = State.READY
	elif event.is_action_released("cast") and state == State.CHARGING:
		_cast()
	elif event.is_action_pressed("lure_next") and state == State.READY:
		lure_index = (lure_index + 1) % Lures.LIST.size()
		_lure_node.mesh.material.albedo_color = lure()["color"]
		message.emit("Uistin: " + lure()["name"])
	elif event.is_action_pressed("twitch") and state == State.RETRIEVING and not lure_on_land:
		line_out = maxf(0.0, line_out - 0.5)
		_twitch = 1.0
	elif event.is_action_pressed("drag_up", true):
		drag_kg = minf(10.0, drag_kg + 0.25)
	elif event.is_action_pressed("drag_down", true):
		drag_kg = maxf(0.5, drag_kg - 0.25)


func _physics_process(dt: float) -> void:
	_aim_angler(dt)
	_twitch = move_toward(_twitch, 0.0, dt * 3.0)
	match state:
		State.READY, State.LANDED:
			lure_pos = rod_tip() + Vector3(0, -0.35, 0)
			line_out = 0.35
			tension = 0.0
		State.CHARGING:
			power = minf(1.0, power + dt / 1.1)
			lure_pos = rod_tip() + Vector3(0, -0.35, 0)
		State.FLYING:
			_fly(dt)
		State.RETRIEVING:
			_retrieve(dt)
		State.BITE:
			_bite(dt)
		State.FIGHT:
			_fight(dt)
	_update_visuals()


func _aim_angler(dt: float) -> void:
	var target := wrapf(camera_rig.yaw - boat.yaw, -PI, PI)
	boat.angler.rotation.y = lerp_angle(boat.angler.rotation.y, target, minf(1.0, dt * 6.0))
	var pitch := 0.7
	match state:
		State.CHARGING:
			pitch = 0.7 + power * 0.9 # vapa taaksepäin
		State.FLYING:
			pitch = 0.25
		State.RETRIEVING, State.BITE:
			pitch = 0.35
		State.FIGHT:
			pitch = 0.8 + clampf(tension / LINE_STRENGTH, 0.0, 1.0) * 0.5
	_rod_pivot.rotation.x = lerpf(_rod_pivot.rotation.x, pitch, minf(1.0, dt * 8.0))


func _cast() -> void:
	var dir := camera_rig.aim_direction()
	var speed: float = 6.0 + 20.0 * power * (0.7 + 0.3 * lure()["cast"])
	_lure_vel = Vector3(dir.x * cos(CAST_ANGLE), sin(CAST_ANGLE), dir.y * cos(CAST_ANGLE)) * speed
	lure_pos = rod_tip()
	sound_event.emit("cast_swish", rod_tip())
	state = State.FLYING
	snagged = false
	lure_on_land = false


func _fly(dt: float) -> void:
	var wind := weather.vector()
	var rel := _lure_vel - Vector3(wind.x, 0, wind.y)
	var k: float = 0.014 / lure()["cast"]
	_lure_vel += (Vector3(0, -GRAVITY, 0) - rel * rel.length() * k) * dt
	lure_pos += _lure_vel * dt
	line_out = rod_tip().distance_to(lure_pos)
	var ground := lake.height_at(lure_pos.x, lure_pos.z)
	var in_water := lake.is_water(lure_pos.x, lure_pos.z)
	if in_water and lure_pos.y <= 0.0:
		lure_pos.y = 0.0
		state = State.RETRIEVING
		_prev_lure = lure_pos
		sound_event.emit("lure_splash", lure_pos)
		message.emit("Heitto %.0f m" % Vector2(lure_pos.x - boat.pos.x, lure_pos.z - boat.pos.y).length())
	elif not in_water and lure_pos.y <= ground:
		lure_pos.y = ground
		lure_on_land = true
		state = State.RETRIEVING
		_prev_lure = lure_pos
		var g := lake.ground_at(lure_pos.x, lure_pos.z)
		if (g == LakeData.Ground.FOREST or g == LakeData.Ground.REEDS) and _rng.randf() < 0.5:
			snagged = true
			message.emit("Uistin tarttui %s! Kelaa irti" % ("kaislikkoon" if g == LakeData.Ground.REEDS else "puskaan"))
		else:
			message.emit("Heitto meni rannalle")


func _reel_speed() -> float:
	if not Input.is_action_pressed("reel") or not GameInput.active():
		return 0.0
	return REEL_SPEED_FAST if Input.is_action_pressed("reel_fast") else REEL_SPEED


func _retrieve(dt: float) -> void:
	var reel := _reel_speed()
	if snagged:
		tension = drag_kg if reel > 0.0 else 0.0
		if reel > 0.0:
			if _rng.randf() < 0.35 * dt:
				snagged = false
				message.emit("Uistin irtosi!")
			elif _rng.randf() < 0.12 * dt * (drag_kg / LINE_STRENGTH) * 2.0:
				_lose_lure("Siima katkesi – uistin jäi kiinni")
		return

	line_out = maxf(0.0, line_out - reel * dt)
	_constrain_lure()
	var tip := rod_tip()
	var moved := Vector2(lure_pos.x - _prev_lure.x, lure_pos.z - _prev_lure.z).length()
	lure_speed = lerpf(lure_speed, moved / dt, minf(1.0, dt * 5.0))
	tension = 0.2 if reel > 0.0 else 0.05

	if lure_on_land:
		lure_pos.y = lake.height_at(lure_pos.x, lure_pos.z)
		if lake.is_water(lure_pos.x, lure_pos.z):
			lure_on_land = false
			lure_pos.y = 0.0
	else:
		_lure_depth_dynamics(dt)
		if not lake.is_water(lure_pos.x, lure_pos.z):
			lure_on_land = true
		_check_timer -= dt
		if _check_timer <= 0.0:
			_check_timer = 0.2
			var idx := population.check_lure(Vector2(lure_pos.x, lure_pos.z), lure_depth(), lure_speed, _twitch, lure(), sky.hour(), weather.speed(), 0.2)
			if idx >= 0:
				_fish_index = idx
				_fish = population.fish[idx]
				state = State.BITE
				_bite_timer = _rng.randf_range(0.6, 1.0)
				sound_event.emit("bite_tick", rod_tip())
				message.emit("TÄRPPI! Vastaisku – vasen hiiri!")
	_prev_lure = lure_pos

	if line_out < 1.0 or tip.distance_to(lure_pos) < 1.0:
		state = State.READY


## Kelataanko juuri nyt (äänille)
func is_reeling() -> bool:
	return state in [State.RETRIEVING, State.BITE, State.FIGHT] and _reel_speed() > 0.0 and not snagged


func reel_speed() -> float:
	return _reel_speed()


## Siima vetää uistinta kohti vavan kärkeä, kun siimaa on kelattu sisään
func _constrain_lure() -> void:
	var tip := rod_tip()
	var d := lure_pos - tip
	if d.length() > line_out:
		lure_pos = tip + d.normalized() * line_out


func _lure_depth_dynamics(dt: float) -> void:
	var l := lure()
	var depth := lure_depth()
	var bottom := lake.depth_at(lure_pos.x, lure_pos.z)
	if l["kind"] == "sink":
		depth += (l["sink"] - l["lift"] * lure_speed) * dt
	else:
		if lure_speed > 0.05:
			var target: float = l["max_dive"] * clampf(lure_speed / 0.9, 0.0, 1.0)
			depth = move_toward(depth, target, 0.6 * lure_speed * dt)
		else:
			depth -= l["float"] * dt
	depth = clampf(depth, 0.0, maxf(0.0, bottom - 0.05))
	lure_pos.y = minf(-depth, lure_pos.y) if lure_pos.y > 0.0 else -depth
	# Uistin laahaa pohjaa: voi tarttua kiinni
	if bottom > 0.0 and depth >= bottom - 0.06 and lure_speed > 0.15:
		if _rng.randf() < l["snag"] * dt:
			snagged = true
			message.emit("Pohjakiinni! Kelaa tai nykäise irti")


func _bite(dt: float) -> void:
	_bite_timer -= dt
	lure_pos += Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)) * dt * 0.5
	if _reel_speed() > 0.0 and _bite_timer < 0.4:
		_try_hook(0.45, "Kala tarttui kelatessa!")
	elif _bite_timer <= 0.0:
		_try_hook(0.15, "Kala koukuttui itse!")


func _try_hook(chance: float, success_text: String) -> void:
	if _rng.randf() < chance:
		state = State.FIGHT
		_stamina = 1.0
		_fish_pos = lure_pos
		_run_timer = 0.0
		_slack_time = 0.0
		_landing_prompt = false
		message.emit(success_text)
	else:
		population.spook(_fish_index)
		_fish_index = -1
		_fish = {}
		state = State.RETRIEVING
		message.emit("Kala ei tarttunut")


func _fight(dt: float) -> void:
	var data: Dictionary = Species.DATA[_fish["sp"]]
	var weight: float = _fish["weight"]
	var fish_power: float = data["power"]
	var tip := rod_tip()

	# Kalan käytös: pakoryntäyksiä ja lepoa
	_run_timer -= dt
	if _run_timer <= 0.0:
		var away := Vector2(_fish_pos.x - boat.pos.x, _fish_pos.z - boat.pos.y).normalized()
		if _stamina > 0.2 and _rng.randf() < 0.45 + 0.4 * _stamina:
			_run_dir = away.rotated(_rng.randf_range(-1.6, 1.6))
			_run_intensity = _rng.randf_range(0.5, 1.0)
			_run_timer = _rng.randf_range(1.5, 4.5)
		else:
			_run_dir = away.rotated(_rng.randf_range(-2.5, 2.5))
			_run_intensity = 0.12
			_run_timer = _rng.randf_range(1.0, 3.0)

	var swim_speed := _run_intensity * (0.4 + 1.6 * _stamina) * fish_power * (1.0 + 0.25 * log(1.0 + weight))
	var next := _fish_pos + Vector3(_run_dir.x, 0, _run_dir.y) * swim_speed * dt
	if lake.is_water(next.x, next.z):
		_fish_pos = next
	else:
		_run_dir = -_run_dir
	var bottom := lake.depth_at(_fish_pos.x, _fish_pos.z)
	var target_depth := 0.3 if _stamina < 0.3 else clampf(lerpf(data["depth"][0], data["depth"][1], 0.5), 0.3, maxf(0.3, bottom - 0.2))
	_fish_pos.y = -move_toward(-_fish_pos.y, target_depth, dt * 0.5)

	# Siima, jarru ja jännitys
	var pull := (_run_intensity * (0.3 + 0.7 * _stamina) * fish_power * 0.95 + 0.12) * weight
	var reel := _reel_speed()
	var effort := 0.6 if reel > 0.0 else 0.0
	var dist := tip.distance_to(_fish_pos)
	drag_slipping = false
	if dist >= line_out:
		var wanted := pull + effort
		if wanted > drag_kg:
			drag_slipping = true
			line_out = dist # jarru antaa siimaa
			tension = drag_kg
		else:
			_fish_pos = tip + (_fish_pos - tip).normalized() * line_out
			line_out = maxf(0.5, line_out - reel * dt * clampf(1.0 - pull / drag_kg, 0.25, 1.0))
			tension = wanted
		_slack_time = maxf(0.0, _slack_time - dt * 2.0)
	else:
		tension = 0.05
		line_out = maxf(dist, line_out - reel * 2.0 * dt)
		if line_out - dist > 0.8:
			_slack_time += dt

	if tension > LINE_STRENGTH:
		_lose_fish("Siima katkesi! Jarru oli liian kireällä", true)
		return
	if _slack_time > 1.5 and _rng.randf() < (0.5 if _fish["sp"] == "hauki" else 0.3) * dt:
		_lose_fish("Kala irtosi löysällä siimalla", false)
		return
	# Hauki ravistelee päätään ja taimen hyppää: löysä siima on silloin vaarallinen
	if _stamina > 0.3 and _fish_pos.y > -0.6 and _rng.randf() < 0.08 * dt:
		sound_event.emit("fish_splash", _fish_pos)
		message.emit("Taimen hyppää!" if _fish["sp"] == "taimen" else "%s rimpuilee pinnassa!" % data["name"])
		if tension < 0.5 * weight and _rng.randf() < 0.3:
			_lose_fish("Kala ravisteli itsensä irti", false)
			return

	_stamina = clampf(_stamina - (tension / maxf(weight, 0.2)) * 0.03 * dt / fish_power - _run_intensity * 0.006 * dt + (0.004 * dt if tension < 0.3 else 0.0), 0.0, 1.0)
	lure_pos = _fish_pos
	_landing_prompt = line_out < 3.2 and _fish_pos.y > -1.2
	tension = maxf(tension, 0.0)


func _try_land() -> void:
	if _stamina < 0.35:
		var sp: String = _fish["sp"]
		var weight: float = _fish["weight"]
		var entry := {
			"species": sp,
			"name": Species.DATA[sp]["name"],
			"weight": snappedf(weight, 0.01),
			"length": snappedf(Species.length_cm(sp, weight), 0.5),
			"lure": lure()["name"],
			"time": sky.clock_text(),
			"place": lake.nearest_place(boat.pos.x, boat.pos.y),
			"date": Time.get_datetime_string_from_system(false, true),
		}
		sound_event.emit("net_landing", _fish_pos)
		var record := CatchLog.add(entry)
		population.remove_and_replace(_fish_index)
		_fish_index = -1
		_fish = {}
		_last_catch = entry
		_landing_prompt = false
		state = State.LANDED
		caught.emit(entry, record)
	else:
		_run_intensity = 1.0
		_run_dir = Vector2(_fish_pos.x - boat.pos.x, _fish_pos.z - boat.pos.y).normalized()
		_run_timer = 2.5
		sound_event.emit("fish_splash", _fish_pos)
		message.emit("Kala on vielä pirteä ja pakenee haavin luota!")


func _lose_fish(text: String, lose_lure: bool) -> void:
	if not lose_lure and _fish_pos.y > -1.0:
		sound_event.emit("fish_splash", _fish_pos)
	population.spook(_fish_index)
	_fish_index = -1
	_fish = {}
	_landing_prompt = false
	tension = 0.0
	if lose_lure:
		_lose_lure(text)
	else:
		state = State.RETRIEVING
		message.emit(text)


func _lose_lure(text: String) -> void:
	sound_event.emit("line_snap", rod_tip())
	lost_lures += 1
	snagged = false
	state = State.READY
	message.emit(text)


# --- Ulkonäkö ---------------------------------------------------------------

func _build_visuals() -> void:
	_rod_pivot = Node3D.new()
	_rod_pivot.position = Vector3(0.22, 0.72, -0.1)
	boat.angler.add_child(_rod_pivot)
	var rod := MeshInstance3D.new()
	var rod_mesh := CylinderMesh.new()
	rod_mesh.top_radius = 0.006
	rod_mesh.bottom_radius = 0.018
	rod_mesh.height = ROD_LENGTH
	var rod_mat := StandardMaterial3D.new()
	rod_mat.albedo_color = Color(0.1, 0.1, 0.12)
	rod_mesh.material = rod_mat
	rod.mesh = rod_mesh
	# Vapa osoittaa eteenpäin (-Z) ja kallistuu ylös pivotin X-kierrolla
	rod.rotation.x = -PI / 2.0
	rod.position = Vector3(0, 0, -ROD_LENGTH / 2.0)
	_rod_pivot.add_child(rod)
	_rod_tip = Node3D.new()
	_rod_tip.position = Vector3(0, 0, -ROD_LENGTH)
	_rod_pivot.add_child(_rod_tip)

	_line_mesh = ImmediateMesh.new()
	var line := MeshInstance3D.new()
	line.mesh = _line_mesh
	line.top_level = true
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(0.9, 0.9, 0.85, 0.8)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line.material_override = line_mat
	add_child(line)

	_lure_node = MeshInstance3D.new()
	var lure_mesh := SphereMesh.new()
	lure_mesh.radius = 0.04
	lure_mesh.height = 0.12
	var lure_mat := StandardMaterial3D.new()
	lure_mat.albedo_color = lure()["color"]
	lure_mat.metallic = 0.6
	lure_mat.roughness = 0.3
	lure_mesh.material = lure_mat
	_lure_node.mesh = lure_mesh
	_lure_node.top_level = true
	add_child(_lure_node)

	_fish_node = MeshInstance3D.new()
	var fish_mesh := SphereMesh.new()
	fish_mesh.radius = 0.5
	fish_mesh.height = 1.0
	_fish_node.mesh = fish_mesh
	_fish_node.material_override = StandardMaterial3D.new()
	_fish_node.top_level = true
	_fish_node.visible = false
	add_child(_fish_node)


func _update_visuals() -> void:
	var tip := rod_tip()
	_lure_node.global_position = lure_pos
	_line_mesh.clear_surfaces()
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var slack := clampf(1.0 - tension / 2.0, 0.0, 1.0)
	var span := tip.distance_to(lure_pos)
	var sag := slack * minf(span * 0.06, 2.5)
	for i in 17:
		var t := i / 16.0
		var p := tip.lerp(lure_pos, t)
		p.y -= sag * 4.0 * t * (1.0 - t)
		if p.y < 0.0 and lure_pos.y >= -0.01 and not lure_on_land:
			p.y = maxf(p.y, -0.02) # siima lepää pinnalla
		_line_mesh.surface_add_vertex(p)
	_line_mesh.surface_end()

	# Koukussa oleva kala näkyy, kun se on lähellä pintaa
	var show_fish := state == State.FIGHT and _fish_pos.y > -0.8 and boat.global_position.distance_to(_fish_pos) < 12.0
	_fish_node.visible = show_fish
	if show_fish:
		var len_m := Species.length_cm(_fish["sp"], _fish["weight"]) / 100.0
		var dir := Vector3(_run_dir.x, 0, _run_dir.y)
		_fish_node.global_position = _fish_pos
		if dir.length() > 0.01:
			_fish_node.look_at(_fish_pos + dir, Vector3.UP)
		_fish_node.scale = Vector3(len_m * 0.16, len_m * 0.2, len_m)
		_fish_node.material_override.albedo_color = Species.DATA[_fish["sp"]]["color"]

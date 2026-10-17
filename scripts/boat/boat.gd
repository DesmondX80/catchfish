class_name Boat
extends Node3D
## Soutuvene perämoottorilla. Oma yksinkertainen vesifysiikka: työntövoima,
## vastus (pituussuunnassa pieni, sivusuunnassa suuri), tuulen ajelehtiminen,
## ankkuri ja karilleajo järven syvyysdatan perusteella.

signal message(text: String)
signal sound_event(sound: String, at: Vector3)

const LENGTH := 4.4
const MASS := 260.0 # vene + kalastaja + moottori, kg
const YAW_INERTIA := 650.0
const MOTOR_THRUST := 420.0 # N täydellä kaasulla (~5 hv, huippunopeus ~20 km/h)
const ROW_FORCE := 150.0 # N vedon aikana
const ROW_TURN := 320.0 # Nm, kun soudetaan vain toisella airolla
const DRAFT := 0.3 # syväys metreinä
const WINDAGE := 0.85 # 0.5 * ilman tiheys * Cd * A
const STROKE_TIME := 1.6 # s / airoveto

var lake: LakeData
var weather: Weather

var pos := Vector2.ZERO # maailman XZ
var velocity := Vector2.ZERO # m/s
var yaw := 0.0 # 0 = keula pohjoiseen (-Z)
var yaw_rate := 0.0

var motor_running := false
var motor_starting := 0.0
var throttle := 0.0 # -0.4 (peruutus) .. 1
var tiller := 0.0 # -1 .. 1
var anchored := false
var anchor_point := Vector2.ZERO
var anchor_rope := 0.0

var angler: Node3D # kalastaja kääntyy heittosuuntaan
var hull: Node3D # aaltojen keinuttama osa
var _motor: Node3D
var wake: Wake
var _oars: Array[Dictionary] = [] # {side, pivot, blade}
var _row_phase := 0.0
var _rowing := false
var _oar_activity := [0.0, 0.0] # vasen, oikea: 1 = soutaa eteen, -1 = taakse, 0 = lepää
var _unstow_timer := 0.0
var _bump_cooldown := 0.0
var _time := 0.0


func setup(lake_data: LakeData, weather_node: Weather) -> void:
	lake = lake_data
	weather = weather_node
	pos = Vector2(lake.start_position.x, lake.start_position.z)
	yaw = lake.start_yaw
	_build_visuals()
	_apply_transform()


func forward() -> Vector2:
	return Vector2(-sin(yaw), -cos(yaw))


func right() -> Vector2:
	return Vector2(cos(yaw), -sin(yaw))


func speed_kmh() -> float:
	return velocity.length() * 3.6


func depth_below() -> float:
	return lake.depth_at(pos.x, pos.y)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("motor_toggle"):
		if motor_running or motor_starting > 0.0:
			motor_running = false
			motor_starting = 0.0
			throttle = 0.0
			_unstow_timer = 1.5
			sound_event.emit("motor_stop", _stern_position())
			message.emit("Moottori sammutettu – airot hankaimiin")
		else:
			motor_starting = 1.6
			sound_event.emit("motor_start", _stern_position())
			message.emit("Airot veneeseen ja nykäiset käynnistysnarusta...")
	elif event.is_action_pressed("anchor_toggle"):
		if anchored:
			anchored = false
			sound_event.emit("anchor_up", global_position + Vector3(0, 0, 0))
			message.emit("Ankkuri nostettu")
		else:
			var depth := depth_below()
			anchored = true
			anchor_point = pos
			anchor_rope = depth * 2.0 + 2.0
			sound_event.emit("anchor_drop", global_position)
			message.emit("Ankkuri laskettu (syvyys %.1f m)" % depth)


func _physics_process(dt: float) -> void:
	_time += dt
	_bump_cooldown -= dt
	if motor_starting > 0.0:
		motor_starting -= dt
		if motor_starting <= 0.0:
			motor_running = true
			message.emit("Moottori käy")

	var drive := Input.get_axis("boat_back", "boat_forward")
	var steer := Input.get_axis("boat_right", "boat_left")
	var fwd := forward()
	var side := right()
	var v_fwd := velocity.dot(fwd)
	var v_side := velocity.dot(side)
	var force := Vector2.ZERO
	var torque := 0.0

	if motor_running:
		throttle = clampf(throttle + drive * 0.6 * dt, -0.4, 1.0)
		tiller = move_toward(tiller, steer, 2.5 * dt)
		var angle := tiller * 0.6
		var thrust := MOTOR_THRUST * throttle
		force += fwd * thrust * cos(angle)
		torque += thrust * sin(angle) * 2.1 + v_fwd * tiller * 45.0
		_rowing = false
	else:
		tiller = move_toward(tiller, 0.0, 2.0 * dt)
		# Käännös soudetaan toisella airolla: oikea airo eteen kääntää vasemmalle
		_oar_activity = [clampf(drive - steer, -1.0, 1.0), clampf(drive + steer, -1.0, 1.0)]
		_rowing = motor_starting <= 0.0 and _unstow_timer <= 0.0 and (_oar_activity[0] != 0.0 or _oar_activity[1] != 0.0)
		if _rowing:
			var before := fmod(_row_phase, 1.0)
			_row_phase += dt / STROKE_TIME
			var f := fmod(_row_phase, 1.0)
			var power := sin(PI * f / 0.45) if f < 0.45 else 0.0
			var left: float = _oar_activity[0]
			var right_oar: float = _oar_activity[1]
			force += fwd * (left + right_oar) * 0.5 * ROW_FORCE * power
			torque += (right_oar - left) * 0.5 * ROW_TURN * power
			if before < 0.45 and f >= 0.45:
				_leave_swirls()
			elif before < 0.95 and f >= 0.95:
				_blade_sounds("oar_catch")
		else:
			_row_phase = 0.0

	# Veden vastus
	force -= fwd * (v_fwd * absf(v_fwd) * 13.0 + v_fwd * 10.0)
	force -= side * (v_side * absf(v_side) * 180.0 + v_side * 60.0)
	torque -= yaw_rate * (500.0 + absf(v_fwd) * 300.0)

	# Tuuli
	var rel_wind := weather.vector() - velocity
	force += rel_wind * rel_wind.length() * WINDAGE

	# Ankkuriköysi
	if anchored:
		var d := pos - anchor_point
		if d.length() > anchor_rope:
			force -= d.normalized() * (d.length() - anchor_rope) * 900.0 + velocity * 250.0
		torque -= yaw_rate * 300.0

	velocity += force / MASS * dt
	yaw_rate += torque / YAW_INERTIA * dt
	yaw = wrapf(yaw + yaw_rate * dt, -PI, PI)

	var new_pos := pos + velocity * dt
	var old_clearance := _min_depth(pos, yaw)
	var new_clearance := _min_depth(new_pos, yaw)
	if new_clearance < DRAFT and new_clearance < old_clearance:
		if velocity.length() > 0.5 and _bump_cooldown <= 0.0:
			sound_event.emit("boat_bump", global_position)
			if velocity.length() > 1.0:
				message.emit("Kolahdus! Vene osui pohjaan")
			_bump_cooldown = 3.0
		velocity *= -0.15
		yaw_rate *= 0.5
	else:
		pos = new_pos

	_unstow_timer = maxf(0.0, _unstow_timer - dt)
	var stern := pos - fwd * LENGTH * 0.5
	wake.track(stern, side, velocity.length())
	_animate(dt)
	_apply_transform()


## Pienin syvyys keulassa, keskellä ja perässä
func _min_depth(p: Vector2, heading: float) -> float:
	var f := Vector2(-sin(heading), -cos(heading)) * LENGTH * 0.45
	return minf(lake.depth_at(p.x + f.x, p.y + f.y), minf(lake.depth_at(p.x, p.y), lake.depth_at(p.x - f.x, p.y - f.y)))


func _apply_transform() -> void:
	position = Vector3(pos.x, 0.0, pos.y)
	rotation = Vector3(0.0, yaw, 0.0)


func _animate(dt: float) -> void:
	# Vene keinuu samoissa aalloissa kuin vesipinta: korkeus keskeltä,
	# keulan ja perän sekä laitojen korkeuserosta kallistukset
	var fwd := forward()
	var side := right()
	var h_bow := Waves.swell_height(pos + fwd * LENGTH * 0.45)
	var h_stern := Waves.swell_height(pos - fwd * LENGTH * 0.45)
	var h_left := Waves.swell_height(pos - side * 0.7)
	var h_right := Waves.swell_height(pos + side * 0.7)
	var planing := clampf(velocity.dot(fwd) * 0.012 * throttle, -0.05, 0.06) # keula nousee kaasulla
	var heel := clampf(yaw_rate * velocity.length() * 0.05, -0.08, 0.08) # kallistus käännöksessä
	hull.position.y = lerpf(hull.position.y, Waves.swell_height(pos), minf(1.0, dt * 6.0))
	hull.rotation.x = lerpf(hull.rotation.x, atan2(h_bow - h_stern, LENGTH * 0.9) + planing, minf(1.0, dt * 4.0))
	hull.rotation.z = lerpf(hull.rotation.z, atan2(h_left - h_right, 1.4) + heel, minf(1.0, dt * 4.0))
	_motor.rotation.y = -tiller * 0.6
	if motor_running:
		_motor.position.y = 0.55 + sin(_time * 60.0) * 0.004
	_animate_oars(dt)


# --- Airot -------------------------------------------------------------------

const OAR_LENGTH := 2.2
const BLADE_OUT := 1.85 # lavan keskikohdan etäisyys hankaimesta
const OARLOCK := Vector3(0.68, 0.45, 0.2)


## Soutuvaiheet (soutaja istuu selkä keulaan päin):
##  0.00–0.45 veto: lapa pystyssä veden alla, liikkuu keulan puolelta perään
##  0.45–0.55 irrotus: lapa nousee pinnasta ja kääntyy vaakatasoon
##  0.55–0.93 palautus: lapa ilmassa takaisin keulan puolelle
##  0.93–1.00 otto: lapa kääntyy pystyyn ja painuu veteen
## Palauttaa [pyyhkäisykulma (rad, + = perään päin), laskukulma (rad), lavan kierto (rad)]
func _stroke_pose(f: float) -> Array:
	var catch_sweep := deg_to_rad(-35.0)
	var finish_sweep := deg_to_rad(30.0)
	var deep := deg_to_rad(21.0) # lapa n. 15 cm veden alla
	var high := deg_to_rad(8.0) # lapa ilmassa
	var square := PI / 2.0
	if f < 0.45:
		var u := f / 0.45
		return [lerpf(catch_sweep, finish_sweep, u), deep + deg_to_rad(3.0) * sin(PI * u), square]
	elif f < 0.55:
		var u := (f - 0.45) / 0.1
		return [finish_sweep, lerpf(deep, high, u), lerpf(square, 0.0, u)]
	elif f < 0.93:
		var u := smoothstep(0.0, 1.0, (f - 0.55) / 0.38)
		return [lerpf(finish_sweep, catch_sweep, u), high, 0.0]
	var u := (f - 0.93) / 0.07
	return [catch_sweep, lerpf(high, deep, u), lerpf(0.0, square, u)]


func _animate_oars(dt: float) -> void:
	var stowed := motor_running or motor_starting > 0.0
	var f := fmod(_row_phase, 1.0)
	for i in _oars.size():
		var oar: Dictionary = _oars[i]
		var s: float = oar["side"]
		var target: Transform3D
		var feather := 0.0
		if stowed:
			# Pitkittäin tuhtojen päällä, lavat keulaan päin
			target = Transform3D(Basis(Vector3.UP, s * PI / 2.0), Vector3(s * 0.36, 0.25, 1.15))
		else:
			var activity: float = _oar_activity[i] if _rowing else 0.0
			var sweep := 0.0
			var dip := deg_to_rad(15.0) # lepoasennossa lapa lepää pinnalla
			if activity != 0.0:
				var pose := _stroke_pose(f)
				sweep = pose[0] * signf(activity) # taaksepäin soudettaessa liike menee toisin päin
				dip = pose[1]
				feather = pose[2]
			# Vasen airo osoittaa -X, oikea +X: kulmien etumerkit peilataan
			var basis := Basis(Vector3.UP, -s * sweep) * Basis(Vector3.BACK, -s * dip)
			target = Transform3D(basis, Vector3(OARLOCK.x * s, OARLOCK.y, OARLOCK.z))
		var pivot: Node3D = oar["pivot"]
		var rate := 3.5 if stowed or _unstow_timer > 0.0 else 18.0
		pivot.transform = pivot.transform.interpolate_with(target, minf(1.0, dt * rate))
		# Lavan malli on pystyssä; feather 0 = vaakatasossa, PI/2 = pystyssä
		var blade: Node3D = oar["blade"]
		blade.rotation.x = lerp_angle(blade.rotation.x, PI / 2.0 - feather, minf(1.0, dt * rate))


## Vedon lopussa lavat jättävät pyörteen veteen, ja lavoista tippuu vettä
func _leave_swirls() -> void:
	for i in _oars.size():
		if _oar_activity[i] == 0.0:
			continue
		var blade: Node3D = _oars[i]["blade"]
		var p := blade.global_position
		wake.add_swirl(Vector2(p.x, p.z), 1.0 + absf(_oar_activity[i]) * 0.3)
	_blade_sounds("oar_drip")


func _blade_sounds(sound: String) -> void:
	for i in _oars.size():
		if _oar_activity[i] != 0.0:
			sound_event.emit(sound, _oars[i]["blade"].global_position)


func _stern_position() -> Vector3:
	var stern := pos - forward() * LENGTH * 0.5
	return Vector3(stern.x, 0.5, stern.y)


# --- Ulkonäkö ---------------------------------------------------------------

func _material(color: Color, cull_disabled := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	if cull_disabled:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	mi.mesh = mesh
	mi.position = at
	parent.add_child(mi)
	return mi


func _build_visuals() -> void:
	hull = Node3D.new()
	add_child(hull)

	var hull_mesh := MeshInstance3D.new()
	hull_mesh.mesh = _hull_mesh()
	hull_mesh.material_override = _material(Color(0.82, 0.84, 0.8), true)
	hull.add_child(hull_mesh)

	var wood := Color(0.55, 0.42, 0.28)
	for z in [-0.9, 0.25, 1.45]:
		_box(hull, Vector3(1.3, 0.05, 0.3), Vector3(0, 0.2, z), wood)

	# Perämoottori
	_motor = Node3D.new()
	_motor.position = Vector3(0, 0.55, 2.3)
	hull.add_child(_motor)
	_box(_motor, Vector3(0.32, 0.4, 0.45), Vector3(0, 0.15, 0.1), Color(0.15, 0.2, 0.45))
	_box(_motor, Vector3(0.08, 1.1, 0.12), Vector3(0, -0.5, 0.15), Color(0.2, 0.2, 0.2))
	_box(_motor, Vector3(0.05, 0.05, 0.6), Vector3(0, 0.2, -0.35), Color(0.1, 0.1, 0.1)) # ohjausaisa

	# Airot hankaimissa: vasen (-X) ja oikea (+X). Airon varsi alkaa hieman
	# hankaimen sisäpuolelta (kahva) ja lapa on varren ulkopäässä.
	for s in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(OARLOCK.x * s, OARLOCK.y, OARLOCK.z)
		hull.add_child(pivot)
		var shaft := _box(pivot, Vector3(OAR_LENGTH, 0.045, 0.045), Vector3((OAR_LENGTH / 2.0 - 0.45) * s, 0, 0), wood)
		var blade := _box(pivot, Vector3(0.5, 0.14, 0.02), Vector3(BLADE_OUT * s, 0, 0), wood)
		shaft.name = "Shaft"
		_oars.append({"side": s, "pivot": pivot, "blade": blade})

	wake = Wake.new()
	add_child(wake)

	# Kalastaja pelastusliivissä keskituhdolla
	angler = Node3D.new()
	angler.position = Vector3(0, 0.22, 0.25)
	hull.add_child(angler)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.22
	capsule.height = 0.85
	capsule.material = _material(Color(0.95, 0.45, 0.1))
	body.mesh = capsule
	body.position = Vector3(0, 0.45, 0)
	angler.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.26
	sphere.material = _material(Color(0.9, 0.72, 0.6))
	head.mesh = sphere
	head.position = Vector3(0, 1.02, 0)
	angler.add_child(head)
	var cap := _box(angler, Vector3(0.28, 0.08, 0.3), Vector3(0, 1.13, -0.03), Color(0.2, 0.3, 0.2))
	cap.rotation.x = -0.1


## Veneen runko poikkileikkauksista: keula -Z, perä +Z
func _hull_mesh() -> Mesh:
	var stations := [
		# z, puolileveys, pohjan syvyys
		[-2.2, 0.05, 0.05],
		[-1.8, 0.4, -0.12],
		[-1.0, 0.68, -0.22],
		[0.0, 0.76, -0.25],
		[1.2, 0.72, -0.24],
		[2.2, 0.62, -0.2],
	]
	var gunwale := 0.45
	var sections := []
	for s in stations:
		var z: float = s[0]
		var w: float = s[1]
		var b: float = s[2]
		var g := gunwale + (0.12 if z < -1.5 else 0.0) # keula hieman korkeampi
		sections.append([
			Vector3(-w, g, z), Vector3(-w * 0.85, b * 0.2, z), Vector3(0, b, z),
			Vector3(w * 0.85, b * 0.2, z), Vector3(w, g, z),
		])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in sections.size() - 1:
		var a: Array = sections[i]
		var b: Array = sections[i + 1]
		for j in a.size() - 1:
			st.add_vertex(a[j]); st.add_vertex(b[j]); st.add_vertex(a[j + 1])
			st.add_vertex(a[j + 1]); st.add_vertex(b[j]); st.add_vertex(b[j + 1])
	# Peräpeili
	var stern: Array = sections[-1]
	for j in range(1, stern.size() - 1):
		st.add_vertex(stern[0]); st.add_vertex(stern[j]); st.add_vertex(stern[j + 1])
	st.generate_normals()
	return st.commit()

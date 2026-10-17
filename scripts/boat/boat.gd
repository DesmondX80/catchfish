class_name Boat
extends Node3D
## Soutuvene perämoottorilla. Oma yksinkertainen vesifysiikka: työntövoima,
## vastus (pituussuunnassa pieni, sivusuunnassa suuri), tuulen ajelehtiminen,
## ankkuri ja karilleajo järven syvyysdatan perusteella.

signal message(text: String)

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
var _oars: Array[Node3D] = []
var _row_phase := 0.0
var _rowing := false
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
			message.emit("Moottori sammutettu – airot käyttöön")
		else:
			motor_starting = 1.2
			message.emit("Nykäiset käynnistysnarusta...")
	elif event.is_action_pressed("anchor_toggle"):
		if anchored:
			anchored = false
			message.emit("Ankkuri nostettu")
		else:
			var depth := depth_below()
			anchored = true
			anchor_point = pos
			anchor_rope = depth * 2.0 + 2.0
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
		_rowing = drive != 0.0 or steer != 0.0
		if _rowing:
			_row_phase += dt / STROKE_TIME
			var f := fmod(_row_phase, 1.0)
			var power := sin(PI * f / 0.45) if f < 0.45 else 0.0
			force += fwd * drive * ROW_FORCE * power
			torque += steer * ROW_TURN * power

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
		if velocity.length() > 1.0 and _bump_cooldown <= 0.0:
			message.emit("Kolahdus! Vene osui pohjaan")
			_bump_cooldown = 3.0
		velocity *= -0.15
		yaw_rate *= 0.5
	else:
		pos = new_pos

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
	var wave := 0.004 + weather.speed() * 0.004
	hull.position.y = sin(_time * 1.3) * wave * 2.0
	hull.rotation.x = sin(_time * 1.1 + 0.5) * wave + clampf(velocity.dot(forward()) * 0.012 * throttle, -0.05, 0.06)
	hull.rotation.z = sin(_time * 0.9) * wave * 1.5 + clampf(yaw_rate * velocity.length() * 0.05, -0.08, 0.08)
	_motor.rotation.y = -tiller * 0.6
	var row := fmod(_row_phase, 1.0) if _rowing else 0.0
	for i in _oars.size():
		var s := 1.0 if i == 0 else -1.0
		_oars[i].rotation = Vector3(0.0, s * (0.5 - sin(row * TAU) * 0.6), s * -0.25 - cos(row * TAU) * 0.1 * s)
	if motor_running:
		_motor.position.y = 0.55 + sin(_time * 60.0) * 0.004


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

	# Airot hankaimissa
	for s in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.68 * s, 0.45, 0.2)
		hull.add_child(pivot)
		var oar := _box(pivot, Vector3(2.2, 0.05, 0.05), Vector3(0.9 * s, 0, 0), wood)
		var blade := _box(oar, Vector3(0.45, 0.02, 0.14), Vector3(0.95 * s, 0, 0), wood)
		blade.rotation.x = 0.2
		_oars.append(pivot)

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

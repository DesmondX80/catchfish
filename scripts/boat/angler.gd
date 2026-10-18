class_name Angler
extends Node3D
## Kalastaja veneessä: maastopuku, lippalakki ja kasvot. Asento riippuu
## tilanteesta, ja kädet ohjataan käänteiskinematiikalla (IK) oikeisiin kohtiin:
##  - kalastus: oikea käsi vavassa kelan kohdalla, vasen kelan kammella kelatessa
##  - soutu: selkä keulaan päin, kädet airojen kahvoilla, vartalo nojaa vedon mukana
##  - moottoriajo: perätuhdolla, oikea käsi ohjausaisalla, vapa veneen pohjalla

enum Pose { FISHING, ROWING, MOTOR, ICE_STAND, ICE_SIT, ICE_DRILL }

const SKIN := Color(0.86, 0.66, 0.52)
const BOOTS := Color(0.12, 0.14, 0.1)
const UPPER_ARM := 0.3
const FOREARM := 0.29
const SEATS := {
	Pose.FISHING: Vector3(0, 0.225, 0.25), # keskituhto
	Pose.ROWING: Vector3(0, 0.225, 0.25),
	Pose.MOTOR: Vector3(-0.28, 0.225, 1.35), # perätuhto, vasemmalla puolella
	# Jäällä (veneen solmu on jään tasolla): seisten lantio 0,85 m, ämpärin päällä 0,32 m
	Pose.ICE_STAND: Vector3(0, 0.85, 0),
	Pose.ICE_SIT: Vector3(0, 0.32, 0),
	Pose.ICE_DRILL: Vector3(0, 0.85, 0.1),
}

var boat: Boat
var fishing: Fishing
var pose := Pose.FISHING
var aim_yaw := 0.0 # kalastuksen suunta (kalastus asettaa)

var torso: Node3D # vartalo, kallistuu soudettaessa
var rod_mount: Node3D # vavan kiinnityskohta rinnan edessä
var _camo: ShaderMaterial
var _arms := [] # [{side, upper, fore, hand}]
var _since_rowing := 10.0
var _rod_stow := 0.0 # 0 = vapa kädessä, 1 = veneen pohjalla
var _sit_legs: Node3D
var _stand_legs: Node3D
var _bucket: Node3D
var _walk_phase := 0.0


func _ready() -> void:
	_camo = ShaderMaterial.new()
	_camo.shader = load("res://shaders/camo.gdshader")
	_build()


func setup(boat_node: Boat, fishing_node: Fishing) -> void:
	boat = boat_node
	fishing = fishing_node


func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	return m


func _part(parent: Node3D, mesh: PrimitiveMesh, at: Vector3, mat: Material, scale_by := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.scale = scale_by
	parent.add_child(mi)
	return mi


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 4
	return c


func _build() -> void:
	var skin := _material(SKIN)
	var boots := _material(BOOTS)
	# Lantio ja jalat (kasvot -Z:aan päin): istuma-asento ja seisoma-asento
	_part(self, _capsule(0.16, 0.36), Vector3(0, 0.1, 0), _camo, Vector3(1.0, 0.6, 0.9)).rotation.z = PI / 2.0
	_sit_legs = Node3D.new()
	add_child(_sit_legs)
	_stand_legs = Node3D.new()
	_stand_legs.visible = false
	add_child(_stand_legs)
	for s in [-1.0, 1.0]:
		var thigh := _part(_sit_legs, _capsule(0.075, 0.44), Vector3(s * 0.11, 0.1, -0.2), _camo)
		thigh.rotation.x = PI / 2.0 - 0.08
		_part(_sit_legs, _capsule(0.06, 0.42), Vector3(s * 0.12, -0.08, -0.42), _camo)
		var boot := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.11, 0.1, 0.26)
		boot.mesh = box
		boot.material_override = boots
		boot.position = Vector3(s * 0.12, -0.27, -0.47)
		_sit_legs.add_child(boot)
		# Seisova jalka: lonkasta alas, kävellessä heiluu (lantion solmu kääntyy)
		var hip := Node3D.new()
		hip.name = "Hip" + ("R" if s > 0 else "L")
		hip.position = Vector3(s * 0.11, 0.08, 0)
		_stand_legs.add_child(hip)
		_part(hip, _capsule(0.075, 0.46), Vector3(0, -0.22, 0), _camo)
		_part(hip, _capsule(0.06, 0.44), Vector3(0.01 * s, -0.63, 0), _camo)
		var sboot := MeshInstance3D.new()
		var sbox := BoxMesh.new()
		sbox.size = Vector3(0.11, 0.1, 0.26)
		sboot.mesh = sbox
		sboot.material_override = boots
		sboot.position = Vector3(0.01 * s, -0.88, -0.05)
		hip.add_child(sboot)
	# Pilkkiämpäri istuimena
	_bucket = Node3D.new()
	_bucket.visible = false
	add_child(_bucket)
	var bucket_mesh := CylinderMesh.new()
	bucket_mesh.top_radius = 0.15
	bucket_mesh.bottom_radius = 0.13
	bucket_mesh.height = 0.3
	_part(_bucket, bucket_mesh, Vector3(0, -0.17, 0.02), _material(Color(0.2, 0.35, 0.6)))
	var lid := CylinderMesh.new()
	lid.top_radius = 0.16
	lid.bottom_radius = 0.16
	lid.height = 0.03
	_part(_bucket, lid, Vector3(0, -0.01, 0.02), _material(Color(0.85, 0.85, 0.8)))

	torso = Node3D.new()
	torso.position = Vector3(0, 0.14, 0)
	add_child(torso)
	# Takki: rintakehä hieman leveämpi kuin syvä
	_part(torso, _capsule(0.17, 0.56), Vector3(0, 0.25, 0), _camo, Vector3(1.15, 1.0, 0.8))
	_part(torso, _capsule(0.12, 0.3), Vector3(0, 0.47, 0), _camo, Vector3(1.5, 0.6, 0.9)).rotation.z = PI / 2.0 # hartiat
	# Kaula ja pää
	_part(torso, _capsule(0.05, 0.14), Vector3(0, 0.6, 0), skin)
	var head := Node3D.new()
	head.position = Vector3(0, 0.74, 0)
	torso.add_child(head)
	var skull := SphereMesh.new()
	skull.radius = 0.105
	skull.height = 0.25
	_part(head, skull, Vector3.ZERO, skin)
	var nose := BoxMesh.new()
	nose.size = Vector3(0.025, 0.045, 0.04)
	_part(head, nose, Vector3(0, -0.01, -0.105), skin)
	var eye := SphereMesh.new()
	eye.radius = 0.012
	eye.height = 0.024
	for s in [-1.0, 1.0]:
		_part(head, eye, Vector3(s * 0.038, 0.03, -0.092), _material(Color(0.08, 0.06, 0.05)))
		var ear := SphereMesh.new()
		ear.radius = 0.025
		ear.height = 0.05
		_part(head, ear, Vector3(s * 0.103, 0.0, 0.0), skin, Vector3(0.5, 1.0, 0.8))
	# Lippalakki: kupu ja lippa eteenpäin
	var crown := CylinderMesh.new()
	crown.top_radius = 0.085
	crown.bottom_radius = 0.112
	crown.height = 0.085
	_part(head, crown, Vector3(0, 0.07, 0.005), _camo)
	var top := SphereMesh.new()
	top.radius = 0.085
	top.height = 0.06
	top.is_hemisphere = true
	_part(head, top, Vector3(0, 0.112, 0.005), _camo)
	var visor := BoxMesh.new()
	visor.size = Vector3(0.17, 0.012, 0.1)
	var v := _part(head, visor, Vector3(0, 0.035, -0.135), _camo)
	v.rotation.x = 0.12

	rod_mount = Node3D.new()
	rod_mount.position = Vector3(0.2, 0.28, -0.18)
	torso.add_child(rod_mount)

	# Kädet: olkavarsi, kyynärvarsi ja käsi asetetaan IK:lla maailman koordinaatteihin
	for s in [-1.0, 1.0]:
		var arm := {"side": s}
		for key in ["upper", "fore"]:
			var mi := MeshInstance3D.new()
			mi.mesh = _capsule(0.05 if key == "upper" else 0.043, 1.0)
			mi.material_override = _camo
			mi.top_level = true
			add_child(mi)
			arm[key] = mi
		var hand := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.045
		hm.height = 0.09
		hand.mesh = hm
		hand.material_override = skin
		hand.top_level = true
		hand.scale = Vector3(0.8, 0.6, 1.1)
		add_child(hand)
		arm["hand"] = hand
		_arms.append(arm)


func rod_stowed() -> bool:
	return _rod_stow > 0.5


## Vavan sijainti veneen pohjalla oikealla laidalla, kärki keulaan
func rod_stow_transform() -> Transform3D:
	if boat.on_ice:
		# Jäällä vapa on kalastajan vieressä jäällä
		return boat.global_transform * Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.45, 0.03, -0.2))
	return boat.hull.global_transform * Transform3D(Basis.IDENTITY, Vector3(0.45, 0.27, 1.25))


## Vapa kädessä ↔ veneen pohjalla, pehmeästi siirtyen (0..1)
func rod_stow_blend() -> float:
	return smoothstep(0.0, 1.0, _rod_stow)


func _choose_pose() -> int:
	if fishing == null:
		return Pose.FISHING
	if boat.on_ice:
		if fishing.state == Fishing.State.DRILLING:
			return Pose.ICE_DRILL
		if fishing.busy() or fishing.at_hole():
			return Pose.ICE_SIT
		return Pose.ICE_STAND
	if fishing.state != Fishing.State.READY and fishing.state != Fishing.State.LANDED:
		return Pose.FISHING
	if boat.motor_running or boat.motor_starting > 0.0:
		return Pose.MOTOR
	if _since_rowing < 0.8:
		return Pose.ROWING
	return Pose.FISHING


func _process(delta: float) -> void:
	if boat == null:
		return
	_since_rowing = 0.0 if boat._rowing else _since_rowing + delta
	pose = _choose_pose()
	var rod_in_hand := pose == Pose.FISHING or pose == Pose.ICE_SIT
	_rod_stow = move_toward(_rod_stow, 0.0 if rod_in_hand else 1.0, delta * 2.5)
	var standing := pose == Pose.ICE_STAND or pose == Pose.ICE_DRILL
	_stand_legs.visible = standing
	_sit_legs.visible = not standing
	_bucket.visible = pose == Pose.ICE_SIT
	# Kävellessä jalat heiluvat askelten tahdissa
	var walk := boat.velocity.length() if pose == Pose.ICE_STAND else 0.0
	_walk_phase += delta * walk * 4.2
	var swing := sin(_walk_phase) * clampf(walk / 1.4, 0.0, 1.0) * 0.45
	_stand_legs.get_node("HipR").rotation.x = swing
	_stand_legs.get_node("HipL").rotation.x = -swing

	# Istumapaikka ja suunta
	var seat: Vector3 = SEATS[pose]
	position = position.lerp(seat, minf(1.0, delta * 3.0))
	var yaw := aim_yaw
	if pose == Pose.ROWING:
		yaw = PI # selkä keulaan päin
	elif pose == Pose.MOTOR:
		yaw = 0.0
	rotation.y = lerp_angle(rotation.y, yaw, minf(1.0, delta * 5.0))

	# Soutaessa vartalo nojaa eteen otossa ja taakse vedon lopussa
	var lean := 0.0
	if pose == Pose.ROWING and boat._rowing:
		var f := fmod(boat._row_phase, 1.0)
		lean = lerpf(-0.35, 0.25, f / 0.45) if f < 0.45 else lerpf(0.25, -0.35, (f - 0.45) / 0.55)
	elif (pose == Pose.FISHING or pose == Pose.ICE_SIT) and fishing.state == Fishing.State.FIGHT:
		lean = 0.12 + clampf(fishing.tension / 6.0, 0.0, 0.2) # nojaa taakse kalan vetäessä
	torso.rotation.x = lerpf(torso.rotation.x, lean, minf(1.0, delta * 8.0))

	_update_arms()


## Kummankin käden kohde maailmassa asennon mukaan
func _hand_targets() -> Array:
	var right := Vector3.ZERO
	var left := Vector3.ZERO
	match pose:
		Pose.ROWING:
			# Kumpikin käsi tarttuu lähempänä olevan airon kahvaan
			var handles := boat.oar_handles()
			var r_sh := _shoulder(1.0)
			right = handles[0] if r_sh.distance_to(handles[0]) < r_sh.distance_to(handles[1]) else handles[1]
			left = handles[1] if right == handles[0] else handles[0]
		Pose.MOTOR:
			right = boat.tiller_handle()
			left = global_transform * Vector3(-0.12, 0.12, -0.32) # polvella
		Pose.ICE_DRILL:
			var grips := fishing.auger_grips()
			right = grips[0]
			left = grips[1]
		Pose.ICE_STAND:
			# Kädet sivuilla, heiluvat kävellessä vastakkain jalkojen kanssa
			var arm_swing := sin(_walk_phase) * clampf(boat.velocity.length() / 1.4, 0.0, 1.0) * 0.18
			right = global_transform * Vector3(0.3, -0.08, -arm_swing)
			left = global_transform * Vector3(-0.3, -0.08, arm_swing)
		_:
			right = fishing.rod_point(0.3) # kelan jalan kohdalla
			left = fishing.reel_knob() if fishing.is_reeling() else fishing.rod_point(0.55)
			if rod_stow_blend() > 0.01:
				right = right.lerp(global_transform * Vector3(0.15, 0.12, -0.3), rod_stow_blend())
				left = left.lerp(global_transform * Vector3(-0.15, 0.12, -0.3), rod_stow_blend())
	return [right, left]


func _shoulder(s: float) -> Vector3:
	return torso.global_transform * Vector3(s * 0.21, 0.47, 0.0)


func _update_arms() -> void:
	var targets := _hand_targets()
	for arm in _arms:
		var s: float = arm["side"]
		var shoulder := _shoulder(s)
		var target: Vector3 = targets[0] if s > 0.0 else targets[1]
		# Kyynärpää osoittaa alas ja hieman sivulle
		var pole := shoulder + torso.global_basis * Vector3(s * 0.35, -0.5, 0.15)
		var elbow := _solve_elbow(shoulder, target, pole)
		var wrist := elbow + (target - elbow).normalized() * minf(FOREARM, elbow.distance_to(target))
		_place_limb(arm["upper"], shoulder, elbow)
		_place_limb(arm["fore"], elbow, wrist)
		var hand: MeshInstance3D = arm["hand"]
		var dir := (wrist - elbow).normalized()
		var f := _frame(dir)
		# Käsi jatkaa kyynärvarren suuntaan (pitkittäin Z-akselilla)
		hand.global_transform = Transform3D(Basis(f[0] * 0.8, f[1] * 0.6, dir * 1.1), wrist + dir * 0.04)


## Kaksiluinen IK: kyynärpään paikka kosinilauseella, taivutus kohti pole-pistettä
func _solve_elbow(a: Vector3, target: Vector3, pole: Vector3) -> Vector3:
	var to := target - a
	var d := clampf(to.length(), 0.05, UPPER_ARM + FOREARM - 0.001)
	var dir := to.normalized()
	var cos_a := (UPPER_ARM * UPPER_ARM + d * d - FOREARM * FOREARM) / (2.0 * UPPER_ARM * d)
	var angle := acos(clampf(cos_a, -1.0, 1.0))
	var bend := (pole - a) - dir * (pole - a).dot(dir)
	if bend.length() < 0.001:
		bend = Vector3.DOWN
	bend = bend.normalized()
	return a + (dir * cos(angle) + bend * sin(angle)) * UPPER_ARM


## Kapseli kahden pisteen väliin (kapselin akseli on Y)
func _place_limb(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var length := maxf(a.distance_to(b), 0.01)
	var dir := (b - a) / length
	var f := _frame(dir)
	mi.global_transform = Transform3D(Basis(f[0], dir * length, f[1]), (a + b) * 0.5)


## Kaksi kohtisuoraa akselia annetulle suunnalle
func _frame(dir: Vector3) -> Array:
	var ref := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var x := ref.cross(dir).normalized()
	return [x, x.cross(dir).normalized()]

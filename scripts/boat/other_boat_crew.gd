class_name OtherBoatCrew
extends Node3D
## Vieraan veneen (OtherBoat) kalastaja: sama hahmomalli kuin pelaajan kalastajalla
## (Angler), oranssi kelluntaliivi päällä. Yksinkertaistettu istuma-asento:
##  - moottoriajo: perätuhdolla, oikea käsi ohjausaisalla
##  - soutu: keskituhdolla selkä keulaan, kädet airojen kahvoilla
##  - kalastus: keskituhdolla kasvot oikealle laidalle, vapa kädessä
## Jalat taivutetaan lattialle ja kädet ohjataan kohteisiin käänteiskinematiikalla
## kuten Anglerissa.

enum Pose { MOTOR, ROWING, FISHING }

const SEATS := {
	Pose.MOTOR: Vector3(-0.12, 0.225, 1.35), # perätuhto, hieman vasemmalla (Angler.SEATS)
	Pose.ROWING: Vector3(0, 0.225, 0.25), # keskituhto
	Pose.FISHING: Vector3(0, 0.225, 0.25),
}
const FACING := {Pose.MOTOR: 0.0, Pose.ROWING: PI, Pose.FISHING: -PI / 2.0}
const VEST := Color(0.95, 0.4, 0.05) # kelluntaliivi
const VEST_TRIM := Color(0.75, 0.28, 0.04)
## Housujen värit venekohtaisesti
const TROUSERS: Array[Color] = [Color(0.12, 0.15, 0.24), Color(0.2, 0.2, 0.18), Color(0.28, 0.22, 0.14)]
## Vapa kalastaessa rungon koordinaateissa: tyvi keskituhdon edessä, kärki oikean laidan yli
const ROD_BUTT := Vector3(0.22, 0.42, 0.22)
const ROD_DIR := Vector3(0.87, 0.5, 0.0)
const ROD_LENGTH := 2.1

var boat: OtherBoat
var pose := Pose.MOTOR
var torso_lean := 0.0

var _model: Node3D
var _skel: Skeleton3D
var _bones := {}
## Omat materiaalit: pidetään tallessa, jotta ne vapautetaan vasta mallin jälkeen
var _materials := {}
var _hands := [Vector3.ZERO, Vector3.ZERO] # [oikea, vasen] maailmassa
var _rod: Node3D
var _line: MeshInstance3D


func setup(boat_node: OtherBoat, variant: int) -> void:
	boat = boat_node
	_model = Angler.MODEL.instantiate()
	_model.rotation.y = PI # malli katsoo +Z:aan, kalastaja -Z:aan
	_model.position.y = Angler.SIT_HIP - 0.9 # lantio istuimella
	add_child(_model)
	_skel = _model.find_child("Skeleton3D", true, false)
	for i in _skel.get_bone_count():
		_bones[_skel.get_bone_name(i)] = i
	var pack := _skel.find_child("Backpack", false, false)
	if pack:
		pack.queue_free()
	# Omat mattapintaiset materiaalit: liivi oranssi, housut veneen mukaan
	var colors := {"Green": VEST, "LightGreen": VEST_TRIM, "Brown": TROUSERS[variant % TROUSERS.size()], "Skin": Angler.SKIN}
	for mi in _skel.find_children("*", "MeshInstance3D", false, false):
		var mesh: Mesh = mi.mesh
		for i in mesh.get_surface_count():
			var src := mesh.surface_get_material(i) as BaseMaterial3D
			var key := src.resource_name
			if not _materials.has(key):
				var m: StandardMaterial3D = src.duplicate()
				m.metallic = 0.0
				m.roughness = 0.85
				if colors.has(key):
					m.albedo_color = colors[key]
				_materials[key] = m
			mi.set_surface_override_material(i, _materials[key])
	var anim: AnimationPlayer = _model.find_child("AnimationPlayer", true, false)
	anim.get_animation("CharacterArmature|Idle_Neutral").loop_mode = Animation.LOOP_LINEAR
	anim.play("CharacterArmature|Idle_Neutral")
	var poser := CrewPoser.new()
	poser.crew = self
	_skel.add_child(poser)
	_build_rod()
	set_pose(Pose.MOTOR)


## Vapa ja siima kalastusasentoa varten (rungon solmun lapsi)
func _build_rod() -> void:
	_rod = Node3D.new()
	_rod.visible = false
	boat.hull.add_child(_rod)
	var blank := CylinderMesh.new()
	blank.top_radius = 0.004
	blank.bottom_radius = 0.011
	blank.height = ROD_LENGTH
	blank.radial_segments = 6
	blank.rings = 1
	var rod_mesh := MeshInstance3D.new()
	rod_mesh.mesh = blank
	rod_mesh.material_override = _matte(Color(0.1, 0.1, 0.12))
	var dir := ROD_DIR.normalized()
	var x := dir.cross(Vector3.BACK).normalized()
	rod_mesh.transform = Transform3D(Basis(x, dir, x.cross(dir)), ROD_BUTT + dir * ROD_LENGTH * 0.5)
	_rod.add_child(rod_mesh)
	# Siima kärjestä suoraan alas veteen
	var tip := ROD_BUTT + dir * ROD_LENGTH
	var line := CylinderMesh.new()
	line.top_radius = 0.0015
	line.bottom_radius = 0.0015
	line.height = tip.y
	line.radial_segments = 4
	line.rings = 1
	_line = MeshInstance3D.new()
	_line.mesh = line
	_line.material_override = _matte(Color(0.85, 0.85, 0.8))
	_line.position = Vector3(tip.x, tip.y * 0.5, tip.z)
	_rod.add_child(_line)


func _matte(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
	return m


func set_pose(p: int) -> void:
	pose = p
	position = SEATS[p]
	rotation.y = FACING[p]
	if _rod:
		_rod.visible = p == Pose.FISHING


## Vavan kohta rungon koordinaateissa (0 = tyvi, 1 = kärki) maailmassa
func _rod_point(t: float) -> Vector3:
	return boat.hull.global_transform * (ROD_BUTT + ROD_DIR.normalized() * ROD_LENGTH * t)


func _process(_delta: float) -> void:
	if boat == null:
		return
	var right := Vector3.ZERO
	var left := Vector3.ZERO
	match pose:
		Pose.MOTOR:
			right = boat.tiller_handle()
			left = global_transform * Vector3(-0.14, 0.12, -0.4) # polvella
		Pose.ROWING:
			# Selkä keulaan: oikea käsi vasemman airon (−X) kahvalla rungon suunnassa
			var handles := boat.oar_handles()
			right = handles[0]
			left = handles[1]
		Pose.FISHING:
			right = _rod_point(0.14) # kelan kohdalla
			left = _rod_point(0.03) # kahvan tyvi
	_hands = [right, left]


func _bone_world(bone: int) -> Transform3D:
	return _skel.global_transform * _skel.get_bone_global_pose(bone)


func _bone_pos(bone: int) -> Vector3:
	return _skel.global_transform * _skel.get_bone_global_pose(bone).origin


func _set_bone_world(bone: int, t: Transform3D) -> void:
	_skel.set_bone_global_pose(bone, _skel.global_transform.affine_inverse() * t)


## Kääntää luun (sen Y-akselin) osoittamaan pisteeseen pienimmällä kierrolla
func _aim(bone: int, target: Vector3) -> void:
	var t := _bone_world(bone)
	var want := target - t.origin
	if want.length_squared() < 1e-8:
		return
	t.basis = Basis(Quaternion(t.basis.y.normalized(), want.normalized())) * t.basis
	_set_bone_world(bone, t)


func _turn(bone: int, axis: Vector3, angle: float) -> void:
	var t := _bone_world(bone)
	t.basis = Basis(axis.normalized(), angle) * t.basis
	_set_bone_world(bone, t)


## Animaation jälkeen: selän kallistus, jalat lattialle ja kädet kohteisiin
func apply_pose() -> void:
	if boat == null or _hands[0] == Vector3.ZERO:
		return
	var b := global_basis.orthonormalized()
	_turn(_bones["Abdomen"], b.x, torso_lean * 0.5)
	_turn(_bones["Chest"], b.x, torso_lean * 0.5)
	_sit_legs()
	_arm_ik(1.0, _hands[0], b)
	_arm_ik(-1.0, _hands[1], b)
	for side in ["L", "R"]:
		for finger in Angler.FINGERS:
			for j in [1, 2, 3]:
				var bone: int = _bones["%s%d.%s" % [finger, j, side]]
				_turn(bone, _bone_world(bone).basis.x, -1.1 if j == 1 else -0.9)


## Reidet vaakaan eteen ja sääret alas, jalkapohjat veneen pohjalle (kuten Angler)
func _sit_legs() -> void:
	for side in ["L", "R"]:
		var s := 1.0 if side == "R" else -1.0
		var upper: int = _bones["UpperLeg." + side]
		var lower: int = _bones["LowerLeg." + side]
		var foot: int = _bones["Foot." + side]
		var hip_local := to_local(_bone_pos(upper))
		var thigh := _bone_pos(upper).distance_to(_bone_pos(lower))
		var shin := _bone_pos(lower).distance_to(_bone_pos(foot))
		var knee_local := hip_local + Vector3(s * 0.04, -0.05, -thigh)
		var drop := clampf(knee_local.y - Angler.BOAT_FLOOR, 0.0, shin)
		var foot_local := knee_local + Vector3(s * 0.02, -drop, -sqrt(shin * shin - drop * drop))
		_aim(upper, to_global(knee_local))
		_aim(lower, to_global(foot_local))
		var ft := _bone_world(foot)
		ft.origin = to_global(foot_local)
		_set_bone_world(foot, ft)


## Kaksiluinen IK: olkavarsi ja kyynärvarsi, kyynärpää alas ja sivulle (kuten Angler)
func _arm_ik(s: float, target: Vector3, b: Basis) -> void:
	var side := "R" if s > 0.0 else "L"
	var upper: int = _bones["UpperArm." + side]
	var lower: int = _bones["LowerArm." + side]
	var wrist: int = _bones["Wrist." + side]
	var shoulder := _bone_pos(upper)
	var upper_len := shoulder.distance_to(_bone_pos(lower))
	var fore_len := _bone_pos(lower).distance_to(_bone_pos(wrist))
	var hand_len := _bone_pos(wrist).distance_to(_bone_pos(_bones["Middle1." + side]))
	var stretch := clampf(shoulder.distance_to(target) - (upper_len + fore_len + hand_len) + 0.02, 0.0, Angler.MAX_STRETCH)
	upper_len += stretch * 0.5
	fore_len += stretch * 0.5
	var pole := shoulder + b * Vector3(s * 0.35, -0.5, 0.15)
	var to := target - shoulder
	var d := clampf(to.length(), 0.05, upper_len + fore_len + hand_len - 0.001)
	var dir := to.normalized()
	var l2 := fore_len + hand_len
	var angle := acos(clampf((upper_len * upper_len + d * d - l2 * l2) / (2.0 * upper_len * d), -1.0, 1.0))
	var bend := (pole - shoulder) - dir * (pole - shoulder).dot(dir)
	bend = bend.normalized() if bend.length() > 0.001 else Vector3.DOWN
	var elbow := shoulder + (dir * cos(angle) + bend * sin(angle)) * upper_len
	_aim(upper, elbow)
	if stretch > 0.0:
		var lt := _bone_world(lower)
		lt.origin = elbow
		_set_bone_world(lower, lt)
	_aim(lower, target)
	if stretch > 0.0:
		var wt := _bone_world(wrist)
		wt.origin = elbow + (target - elbow).normalized() * fore_len
		_set_bone_world(wrist, wt)
	_aim(wrist, target + (target - elbow).normalized() * 0.1)


## Luurangon muokkain: ajetaan animaation jälkeen joka ruudulla
class CrewPoser extends SkeletonModifier3D:
	var crew: OtherBoatCrew

	func _process_modification() -> void:
		crew.apply_pose()

class_name Angler
extends Node3D
## Kalastaja veneessä ja jäällä. Hahmo on Quaterniuksen riggattu malli
## (assets/characters, CC0): kesällä maastoasu ja lippalakki, talvella
## pilkkihaalari ja pipo. Asento riippuu tilanteesta, ja raajat ohjataan
## luurangon luilla käänteiskinematiikalla (IK) oikeisiin kohtiin:
##  - kalastus: oikea käsi vavassa kelan kohdalla, vasen kelan kammella kelatessa
##  - soutu: selkä keulaan päin, kädet airojen kahvoilla, vartalo nojaa vedon mukana
##  - moottoriajo: perätuhdolla, oikea käsi ohjausaisalla, vapa veneen pohjalla
## Istuessa jalat taivutetaan polvista lattialle. Jäällä kävellessä käytetään
## mallin omaa kävelyanimaatiota.

enum Pose { FISHING, ROWING, MOTOR, ICE_STAND, ICE_SIT, ICE_DRILL, ANCHOR, PADDLE }

const MODEL := preload("res://assets/characters/adventurer.glb")
const SEATS := {
	Pose.FISHING: Vector3(0, 0.225, 0.25), # keskituhto
	Pose.ROWING: Vector3(0, 0.225, 0.25),
	Pose.PADDLE: Vector3(0, 0.225, 0.25), # keskituhdolla kasvot keulaan
	Pose.MOTOR: Vector3(-0.12, 0.225, 1.35), # perätuhto, hieman vasemmalla
	Pose.ANCHOR: Vector3(0, 0.225, -0.9), # etutuhto: ankkurin lasku ja nosto keulasta
	# Jäällä (veneen solmu on jään tasolla): seisten lantio 0,85 m, ämpärin päällä 0,32 m
	Pose.ICE_STAND: Vector3(0, 0.85, 0),
	Pose.ICE_SIT: Vector3(0, 0.32, 0),
	Pose.ICE_DRILL: Vector3(0, 0.85, -0.3), # lähellä kairaa
}
const SIT_HIP := 0.1 # lantion luu istuimen yläpuolella
const STAND_FEET := -0.85 # jalkapohjat solmun alapuolella seistessä
## Jalkapohjien taso istuessa: veneen pohja / keulan jalkataso / jää ämpärin edessä
const SIT_FLOOR := {Pose.ICE_SIT: -0.32, Pose.ANCHOR: Boat.FOOT_STEP - 0.225}
const BOAT_FLOOR := -0.36
## Polvien nosto istuessa: keulan kapeassa kärjessä jalat pidetään lähellä tuhtoa
const KNEE_LIFT := {Pose.ANCHOR: 0.14}
## Vaatteiden värit materiaalin nimen mukaan: kesällä mallin omat, talvella pilkkihaalari
const WINTER_COLORS := {
	"Green": Color(0.55, 0.07, 0.05), # haalarin yläosa punainen
	"LightGreen": Color(0.08, 0.08, 0.09), # olkapäät ja kaulus mustat
	"Brown": Color(0.08, 0.08, 0.09), # housuosa musta
	"Brown2": Color(0.55, 0.07, 0.05), # polvipaikat ja taskut punaiset
	"Grey": Color(0.15, 0.15, 0.16),
}
## Päähineiden korkeus pään luusta ja reuna, jonka yläpuolelta tukka leikataan
const CAP_Y := 0.19
const CAP_RIM := 0.14
const BEANIE_Y := 0.175
const BEANIE_RIM := 0.125
const MAX_STRETCH := 0.15 # käsivarren nivelten venymä enintään (m)
const POSED_BONES := ["Hips", "Head", "Middle1.L", "Middle1.R", "Foot.L", "Foot.R"]
const FINGERS := ["Index", "Middle", "Ring", "Pinky"]
## Mallin oma iho on suoraan auringossa lähes valkoinen: hieman tummempi ja lämpimämpi
const SKIN := Color(0.62, 0.43, 0.31)

var boat: Boat
var fishing: Fishing
var pose := Pose.FISHING
var aim_yaw := 0.0 # kalastuksen suunta (kalastus asettaa)

var torso: Node3D # vartalon kallistus (soutu, väsytys); vavan kiinnityskohta seuraa sitä
var rod_mount: Node3D # vavan kiinnityskohta rinnan edessä
var _camo: ShaderMaterial
var _model: Node3D
var _skel: Skeleton3D
var _anim: AnimationPlayer
var _bones := {} # luiden indeksit nimen mukaan
var _materials := {} # nimi -> [materiaali, kesäväri]
var _cap: Node3D
var _hair: ShaderMaterial
var _beanie: Node3D
var _sleeves: Array[Node3D] = []
var _winter := false
var _hand_targets_now := [Vector3.ZERO, Vector3.ZERO]
var _posed := {} # luun nimi -> paikka maailmassa muokkauksen jälkeen (muokkaimen tulos on väliaikainen)
var _arms_ik := true
var _sit := 1.0 # 1 = istuu, 0 = seisoo (pehmeä siirtymä)
var _since_rowing := 10.0
var _rod_stow := 0.0 # 0 = vapa kädessä, 1 = veneen pohjalla
var _bucket: Node3D
## FPV-kamerassa pää (tukka, parta ja päähine) piilotetaan, kädet ja vapa näkyvät
var hide_head := false
var _head_root: Node3D
const HIDDEN_HEAD_SCALE := 0.001


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
	m.roughness = 0.85
	return m


func _part(parent: Node3D, mesh: PrimitiveMesh, at: Vector3, mat: Material, scale_by := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.scale = scale_by
	parent.add_child(mi)
	return mi


func _build() -> void:
	_model = MODEL.instantiate()
	_model.rotation.y = PI # malli katsoo +Z:aan, kalastaja -Z:aan
	add_child(_model)
	_skel = _model.find_child("Skeleton3D", true, false)
	_anim = _model.find_child("AnimationPlayer", true, false)
	for i in _skel.get_bone_count():
		_bones[_skel.get_bone_name(i)] = i
	# Reppu jää rannalle
	var pack := _skel.find_child("Backpack", false, false)
	if pack:
		pack.queue_free()
	# Mallin materiaalit ovat kiiltäviä: mattapinta, ja omat kopiot talvivärejä varten
	for mi in _skel.find_children("*", "MeshInstance3D", false, false):
		var mesh: Mesh = mi.mesh
		for i in mesh.get_surface_count():
			var src := mesh.surface_get_material(i) as BaseMaterial3D
			var key := src.resource_name
			if not _materials.has(key):
				var m: StandardMaterial3D = src.duplicate()
				m.metallic = 0.0
				m.roughness = 0.85
				if key == "Skin":
					m.albedo_color = SKIN
				_materials[key] = [m, m.albedo_color]
			mi.set_surface_override_material(i, _materials[key][0])
	for anim_name in ["CharacterArmature|Idle_Neutral", "CharacterArmature|Walk", "CharacterArmature|Run"]:
		_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_anim.play("CharacterArmature|Idle_Neutral")

	# Luiden ohjaus animaation jälkeen
	var poser := AnglerPoser.new()
	poser.angler = self
	_skel.add_child(poser)

	# Päähineet päähän: lippalakki kesällä, pipo talvella
	var head := BoneAttachment3D.new()
	head.bone_name = "Head"
	_skel.add_child(head)
	var head_root := Node3D.new()
	head_root.scale = Vector3.ONE / _model_scale() # armatuurin skaalaus pois
	head_root.rotation.y = PI # luun +Z on kasvojen suunta
	head.add_child(head_root)
	_head_root = head_root
	_cap = _build_cap(head_root)
	_beanie = _build_beanie(head_root)
	_beanie.visible = false
	# Tuuhea tukka ei mahdu päähineen alle: hiukset leikataan päähineen
	# reunasta ylöspäin, parta ja niskan hiukset jäävät
	_hair = ShaderMaterial.new()
	_hair.shader = load("res://shaders/hair_cut.gdshader")
	_hair.set_shader_parameter("color", _materials["Hair"][1])
	for mi in _skel.find_children("*", "MeshInstance3D", false, false):
		for i in mi.mesh.get_surface_count():
			if mi.mesh.surface_get_material(i).resource_name == "Hair":
				mi.set_surface_override_material(i, _hair)
	# Talvella haalarin hihat kyynärvarsiin
	for side in ["L", "R"]:
		var att := BoneAttachment3D.new()
		att.bone_name = "LowerArm." + side
		_skel.add_child(att)
		var sleeve_root := Node3D.new()
		sleeve_root.scale = Vector3.ONE / _model_scale()
		att.add_child(sleeve_root)
		var sleeve := CylinderMesh.new()
		sleeve.top_radius = 0.048
		sleeve.bottom_radius = 0.058
		sleeve.height = 0.24
		sleeve.radial_segments = 8
		_part(sleeve_root, sleeve, Vector3(0, 0.12, 0), _materials["Green"][0])
		var cuff := CylinderMesh.new()
		cuff.top_radius = 0.05
		cuff.bottom_radius = 0.05
		cuff.height = 0.04
		cuff.radial_segments = 8
		_part(sleeve_root, cuff, Vector3(0, 0.235, 0), _materials["LightGreen"][0])
		sleeve_root.visible = false
		_sleeves.append(sleeve_root)

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
	rod_mount = Node3D.new()
	rod_mount.position = Vector3(0.2, 0.28, -0.18)
	torso.add_child(rod_mount)
	_set_winter(false)


## Armatuurin skaalaus maailmaan (glTF-malli on senttimetreinä)
func _model_scale() -> float:
	return (_skel.get_parent() as Node3D).scale.x


## Maastokuvioinen lippalakki: kupu ja lippa eteenpäin (-Z)
func _build_cap(parent: Node3D) -> Node3D:
	var cap := Node3D.new()
	cap.position = Vector3(0, CAP_Y, 0.0)
	parent.add_child(cap)
	var crown := CylinderMesh.new()
	crown.top_radius = 0.1
	crown.bottom_radius = 0.122
	crown.height = 0.08
	_part(cap, crown, Vector3.ZERO, _camo)
	var top := SphereMesh.new()
	top.radius = 0.1
	top.height = 0.05
	top.is_hemisphere = true
	_part(cap, top, Vector3(0, 0.04, 0), _camo)
	var visor := BoxMesh.new()
	visor.size = Vector3(0.18, 0.012, 0.12)
	_part(cap, visor, Vector3(0, -0.032, -0.165), _camo).rotation.x = 0.1
	return cap


## Neulottu pipo: kupu, käänne ja tupsu
func _build_beanie(parent: Node3D) -> Node3D:
	var beanie := Node3D.new()
	beanie.position = Vector3(0, BEANIE_Y, 0.0)
	parent.add_child(beanie)
	var knit := _material(Color(0.1, 0.16, 0.36))
	var stripe := _material(Color(0.85, 0.85, 0.8))
	var dome := SphereMesh.new()
	dome.radius = 0.13
	dome.height = 0.2
	dome.is_hemisphere = true
	_part(beanie, dome, Vector3(0, 0.0, 0), knit, Vector3(1.0, 1.15, 1.05))
	var band := CylinderMesh.new()
	band.top_radius = 0.133
	band.bottom_radius = 0.136
	band.height = 0.06
	_part(beanie, band, Vector3(0, -0.01, 0), knit, Vector3(1.0, 1.0, 1.05))
	var ring := CylinderMesh.new()
	ring.top_radius = 0.135
	ring.bottom_radius = 0.135
	ring.height = 0.018
	_part(beanie, ring, Vector3(0, 0.03, 0), stripe, Vector3(1.0, 1.0, 1.05))
	var pompom := SphereMesh.new()
	pompom.radius = 0.045
	pompom.height = 0.09
	_part(beanie, pompom, Vector3(0, 0.235, 0), stripe)
	return beanie


## Kesä- tai talviasu
func _set_winter(on: bool) -> void:
	_winter = on
	for key in _materials:
		var m: StandardMaterial3D = _materials[key][0]
		m.albedo_color = WINTER_COLORS[key] if on and WINTER_COLORS.has(key) else _materials[key][1]
	_cap.visible = not on
	_beanie.visible = on
	_hair.set_shader_parameter("cut", (BEANIE_RIM if on else CAP_RIM) / _model_scale())
	for s in _sleeves:
		s.visible = on


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
	if boat.anchor and boat.anchor.handling():
		return Pose.ANCHOR
	if fishing.busy():
		return Pose.FISHING
	if boat.motor_running or boat.motor_starting > 0.0:
		return Pose.MOTOR
	if boat.paddling:
		return Pose.PADDLE
	if _since_rowing < 0.8:
		return Pose.ROWING
	return Pose.FISHING


func _process(delta: float) -> void:
	if boat == null:
		return
	if boat.on_ice != _winter:
		_set_winter(boat.on_ice)
	_since_rowing = 0.0 if boat._rowing else _since_rowing + delta
	pose = _choose_pose()
	var rod_in_hand := pose == Pose.FISHING or pose == Pose.ICE_SIT
	_rod_stow = move_toward(_rod_stow, 0.0 if rod_in_hand else 1.0, delta * 2.5)
	var standing := pose == Pose.ICE_STAND or pose == Pose.ICE_DRILL
	_sit = move_toward(_sit, 0.0 if standing else 1.0, delta * 4.0)
	_bucket.visible = pose == Pose.ICE_SIT
	# Malli istuu lantio istuimella tai seisoo jalat maassa
	var hip_height := 0.9 # mallin lantion korkeus seistessä
	_model.position.y = lerpf(STAND_FEET, SIT_HIP - hip_height, _sit)

	# Seisten: kävely- tai lepoanimaatio jalkojen tahtiin
	var walk := boat.velocity.length() if pose == Pose.ICE_STAND else 0.0
	var anim := "CharacterArmature|Idle_Neutral"
	if walk > 2.0:
		anim = "CharacterArmature|Run"
	elif walk > 0.2:
		anim = "CharacterArmature|Walk"
	if _anim.current_animation != anim:
		_anim.play(anim, 0.25)
	_anim.speed_scale = clampf(walk / (3.5 if walk > 2.0 else 1.4), 0.6, 1.4) if walk > 0.2 else 1.0
	_arms_ik = pose != Pose.ICE_STAND

	# Istumapaikka ja suunta
	var seat: Vector3 = SEATS[pose]
	position = position.lerp(seat, minf(1.0, delta * 3.0))
	var yaw := aim_yaw
	if pose == Pose.ROWING:
		yaw = PI # selkä keulaan päin
	elif pose == Pose.MOTOR or pose == Pose.ANCHOR or pose == Pose.PADDLE:
		yaw = 0.0 # kasvot keulaan
	rotation.y = lerp_angle(rotation.y, yaw, minf(1.0, delta * 5.0))

	# Soutaessa vartalo nojaa eteen otossa ja taakse vedon lopussa
	var lean := 0.0
	if pose == Pose.ROWING and boat._rowing:
		var f := fmod(boat._row_phase, 1.0)
		lean = lerpf(-0.35, 0.25, f / 0.45) if f < 0.45 else lerpf(0.25, -0.35, (f - 0.45) / 0.55)
	elif (pose == Pose.FISHING or pose == Pose.ICE_SIT) and fishing.state == Fishing.State.FIGHT and not fishing.hands_free():
		lean = 0.12 + clampf(fishing.tension / 6.0, 0.0, 0.2) # nojaa taakse kalan vetäessä
	elif fishing.net_active():
		lean = -fishing.net_lean() # nojaa eteen ojentaessaan haavia
	elif pose == Pose.ICE_DRILL:
		lean = -0.3 # nojaa kairan kahvoihin
	elif pose == Pose.ANCHOR:
		lean = -0.35 # kurottaa keulan köyteen
	elif pose == Pose.PADDLE and boat._paddle_stroking:
		var f := boat._paddle_phase
		lean = lerpf(-0.3, 0.1, f / 0.5) if f < 0.5 else lerpf(0.1, -0.3, (f - 0.5) / 0.5) # kurottaa ottoon
	torso.rotation.x = lerpf(torso.rotation.x, lean, minf(1.0, delta * 8.0))

	if _arms_ik:
		_hand_targets_now = _hand_targets()


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
		Pose.PADDLE:
			var grips: Array = boat.paddle_hands()
			right = grips[0]
			left = grips[1]
		Pose.ANCHOR:
			var hands: Array = boat.anchor.hand_points()
			right = hands[0]
			left = hands[1]
		Pose.MOTOR:
			right = boat.tiller_handle()
			left = global_transform * Vector3(-0.14, 0.12, -0.4) # polvella
		Pose.ICE_DRILL:
			# Kumpikin käsi tarttuu lähempään kairan kahvaan
			var grips := fishing.auger_grips()
			var r_sh := _shoulder(1.0)
			var swap: bool = r_sh.distance_to(grips[1]) < r_sh.distance_to(grips[0])
			right = grips[1] if swap else grips[0]
			left = grips[0] if swap else grips[1]
		_ when fishing.hands_free():
			# Vavat telineissä: kädet polvilla
			right = global_transform * Vector3(0.14, 0.12, -0.4)
			left = global_transform * Vector3(-0.14, 0.12, -0.4)
		_:
			right = fishing.rod_point(0.3) # kelan jalan kohdalla
			left = fishing.reel_knob() if fishing.is_reeling() else fishing.rod_point(0.1) # kahvan tyvi
			if fishing.net_active():
				# Haavinta: oikea käsi haavin varren päässä; vasen pitää vapaa,
				# kunnes kala on haavissa, ja tarttuu sitten varteen nostoon
				var grips := fishing.net_grips()
				left = grips[1] if grips.size() > 1 else right
				right = grips[0]
			if rod_stow_blend() > 0.01:
				right = right.lerp(global_transform * Vector3(0.15, 0.12, -0.38), rod_stow_blend())
				left = left.lerp(global_transform * Vector3(-0.15, 0.12, -0.38), rod_stow_blend())
	return [right, left]


## Olkanivel maailmassa (s = 1 oikea, -1 vasen)
func _shoulder(s: float) -> Vector3:
	return _bone_pos(_bones["UpperArm.R" if s > 0.0 else "UpperArm.L"])


# --- Luurangon ohjaus -----------------------------------------------------------

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
	var q := Quaternion(t.basis.y.normalized(), want.normalized())
	t.basis = Basis(q) * t.basis
	_set_bone_world(bone, t)


## Kiertää luuta maailman akselin ympäri
func _turn(bone: int, axis: Vector3, angle: float) -> void:
	var t := _bone_world(bone)
	t.basis = Basis(axis.normalized(), angle) * t.basis
	_set_bone_world(bone, t)


## Animaation jälkeen: selän kallistus, istuma-asennon jalat, kädet IK:lla ja otteen sormet
func apply_pose() -> void:
	if boat == null:
		return
	var b := global_basis.orthonormalized()
	# Selkä taipuu lantiosta ja rinnasta (sama kallistus kuin vavan kiinnityskohdalla)
	var lean := torso.rotation.x
	_turn(_bones["Abdomen"], b.x, lean * 0.5)
	_turn(_bones["Chest"], b.x, lean * 0.5)
	if _sit > 0.01:
		_sit_legs(b)
	if _arms_ik:
		for s in [1.0, -1.0]:
			_arm_ik(s, _hand_targets_now[0] if s > 0.0 else _hand_targets_now[1], b)
	_grip()
	# Hiusten leikkaus seuraa päätä
	var head_pose := _skel.get_bone_global_pose(_bones["Head"])
	_hair.set_shader_parameter("head_inv", Projection(head_pose.affine_inverse()))
	for bone_name in POSED_BONES:
		_posed[bone_name] = _bone_pos(_bones[bone_name])
	# FPV: pää kutistetaan kameran sisään (paikka säilyy kameraa varten)
	_head_root.visible = not hide_head
	if hide_head:
		head_pose.basis = head_pose.basis.scaled_local(Vector3.ONE * HIDDEN_HEAD_SCALE)
		_skel.set_bone_global_pose(_bones["Head"], head_pose)


## Luun paikka maailmassa sellaisena kuin se näkyy (asento ja IK mukana)
func posed_position(bone_name: String) -> Vector3:
	return _posed.get(bone_name, _bone_pos(_bones[bone_name]))


## Istuessa reidet vaakaan eteen ja sääret alas, jalkapohjat lattialle
func _sit_legs(b: Basis) -> void:
	var floor_y: float = SIT_FLOOR.get(pose, BOAT_FLOOR)
	for side in ["L", "R"]:
		var s := 1.0 if side == "R" else -1.0
		var upper: int = _bones["UpperLeg." + side]
		var lower: int = _bones["LowerLeg." + side]
		var foot: int = _bones["Foot." + side]
		var hip := _bone_pos(upper)
		var thigh := hip.distance_to(_bone_pos(lower))
		var shin := _bone_pos(lower).distance_to(_bone_pos(foot))
		var hip_local := to_local(hip)
		var lift: float = KNEE_LIFT.get(pose, 0.0)
		var knee_local := hip_local + Vector3(s * (0.04 - lift * 0.2), -0.05 + lift, -sqrt(thigh * thigh - lift * lift))
		var drop := clampf(knee_local.y - floor_y, 0.0, shin)
		var foot_local := knee_local + Vector3(s * 0.02, -drop, -sqrt(shin * shin - drop * drop))
		var knee := to_global(knee_local)
		var foot_pos := to_global(foot_local)
		# Seisovasta asennosta istuvaan pehmeästi
		var stand_knee := _bone_pos(lower)
		var stand_foot := _bone_pos(foot)
		knee = stand_knee.lerp(knee, _sit)
		foot_pos = stand_foot.lerp(foot_pos, _sit)
		_aim(upper, knee)
		_aim(lower, foot_pos)
		var ft := _bone_world(foot)
		ft.origin = foot_pos
		_set_bone_world(foot, ft)


## Kaksiluinen IK: olkavarsi ja kyynärvarsi, ranne jatkaa kyynärvarren suuntaan
func _arm_ik(s: float, target: Vector3, b: Basis) -> void:
	var side := "R" if s > 0.0 else "L"
	var upper: int = _bones["UpperArm." + side]
	var lower: int = _bones["LowerArm." + side]
	var wrist: int = _bones["Wrist." + side]
	var shoulder := _bone_pos(upper)
	var upper_len := shoulder.distance_to(_bone_pos(lower))
	var fore_len := _bone_pos(lower).distance_to(_bone_pos(wrist))
	# Kohde on rystysten kohdalla (koukistetut sormet kiertyvät sen ympärille),
	# joten ranne jää kämmenen mitan verran ennen kohdetta
	var hand_len := _bone_pos(wrist).distance_to(_bone_pos(_bones["Middle1." + side]))
	# Mallin käsivarret ovat lyhyet: kaukana olevaan kohteeseen nivelet venyvät
	# hieman (kyynärpää ja ranne siirtyvät luun suuntaan)
	var stretch := clampf(shoulder.distance_to(target) - (upper_len + fore_len + hand_len) + 0.02, 0.0, MAX_STRETCH)
	upper_len += stretch * 0.5
	fore_len += stretch * 0.5
	var pole := shoulder + b * Vector3(s * 0.35, -0.5, 0.15) # kyynärpää alas ja sivulle
	var elbow := _solve_elbow(shoulder, target, pole, upper_len, fore_len + hand_len)
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
	# Kämmenselkä (luun Z) ylöspäin: kierto jaetaan kyynärvarren ja ranteen kesken
	var w := _bone_world(wrist)
	var axis := w.basis.y.normalized()
	var back := w.basis.z.normalized()
	var want := Vector3.UP - axis * axis.y
	if want.length() > 0.1:
		var twist := (back - axis * back.dot(axis)).signed_angle_to(want, axis)
		_turn(lower, axis, twist * 0.6)
		_turn(wrist, _bone_world(wrist).basis.y, twist * 0.4)


## Kyynärpään paikka kosinilauseella, taivutus kohti pole-pistettä
func _solve_elbow(a: Vector3, target: Vector3, pole: Vector3, l1: float, l2: float) -> Vector3:
	var to := target - a
	var d := clampf(to.length(), 0.05, l1 + l2 - 0.001)
	var dir := to.normalized()
	var cos_a := (l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d)
	var angle := acos(clampf(cos_a, -1.0, 1.0))
	var bend := (pole - a) - dir * (pole - a).dot(dir)
	if bend.length() < 0.001:
		bend = Vector3.DOWN
	bend = bend.normalized()
	return a + (dir * cos(angle) + bend * sin(angle)) * l1


## Sormet koukussa otteeseen (vapa, airot, ohjausaisa)
func _grip() -> void:
	if not _arms_ik:
		return
	for side in ["L", "R"]:
		for finger in FINGERS:
			for j in [1, 2, 3]:
				var bone: int = _bones["%s%d.%s" % [finger, j, side]]
				var t := _bone_world(bone)
				_turn(bone, t.basis.x, -1.1 if j == 1 else -0.9)
		_turn(_bones["Thumb2." + side], _bone_world(_bones["Thumb2." + side]).basis.x, -0.5)


## Luurangon muokkain: ajetaan animaation jälkeen joka ruudulla
class AnglerPoser extends SkeletonModifier3D:
	var angler: Angler

	func _process_modification() -> void:
		angler.apply_pose()

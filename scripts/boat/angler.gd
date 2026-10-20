class_name Angler
extends Node3D
## Kalastaja veneessä: kesällä maastotakki, kelluntaliivi, lippalakki ja
## kumisaappaat, talvella pilkkihaalari, pipo ja lapaset. Katse seuraa uistinta,
## kohoa, kalaa tai avantoa, ja silmät räpyttelevät. Asento riippuu
## tilanteesta, ja kädet ohjataan käänteiskinematiikalla (IK) oikeisiin kohtiin:
##  - kalastus: oikea käsi vavassa kelan kohdalla, vasen kelan kammella kelatessa
##  - soutu: selkä keulaan päin, kädet airojen kahvoilla, vartalo nojaa vedon mukana
##  - moottoriajo: perätuhdolla, oikea käsi ohjausaisalla, vapa veneen pohjalla

enum Pose { FISHING, ROWING, MOTOR, ICE_STAND, ICE_SIT, ICE_DRILL }

const SKIN := Color(0.86, 0.66, 0.52)
const BOOTS := Color(0.13, 0.2, 0.12) # vihreät kumisaappaat
const TROUSERS := Color(0.24, 0.23, 0.17)
const WINTER_SUIT := Color(0.13, 0.14, 0.17)
const WINTER_ACCENT := Color(0.6, 0.11, 0.09) # haalarin olkapäät ja kaulus, pipon sävy
const MITTEN := Color(0.2, 0.2, 0.22)
const BEARD := Color(0.4, 0.3, 0.2)
const HEAD_YAW_LIMIT := 1.2 # rad, pään kääntö vartaloon nähden
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
var winter := false
var _head: Node3D
var _eyes: Array[Node3D] = []
var _cap: Node3D
var _beanie: Node3D
var _vest: Node3D
var _jacket_parts: Array[MeshInstance3D] = []
var _trouser_parts: Array[MeshInstance3D] = []
var _accent_parts: Array[MeshInstance3D] = [] # hartiat ja kaulus
var _trousers: StandardMaterial3D
var _winter_suit: StandardMaterial3D
var _winter_accent: StandardMaterial3D
var _mitten: StandardMaterial3D
var _skin: StandardMaterial3D
var _blink_in := 3.0
var _glance := 0.0 # soutaessa vilkaisu olan yli menosuuntaan


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
	_trousers = _material(TROUSERS)
	_winter_suit = _material(WINTER_SUIT)
	_winter_accent = _material(WINTER_ACCENT)
	_mitten = _material(MITTEN)
	_skin = skin
	var boots := _material(BOOTS)
	var sole := _material(Color(0.05, 0.05, 0.05))
	# Lantio ja jalat (kasvot -Z:aan päin): istuma-asento ja seisoma-asento
	_trouser_parts.append(_part(self, _capsule(0.16, 0.36), Vector3(0, 0.1, 0), _trousers, Vector3(1.0, 0.6, 0.9)))
	_trouser_parts[-1].rotation.z = PI / 2.0
	_sit_legs = Node3D.new()
	add_child(_sit_legs)
	_stand_legs = Node3D.new()
	_stand_legs.visible = false
	add_child(_stand_legs)
	for s in [-1.0, 1.0]:
		var thigh := _part(_sit_legs, _capsule(0.078, 0.44), Vector3(s * 0.11, 0.1, -0.2), _trousers)
		thigh.rotation.x = PI / 2.0 - 0.08
		_trouser_parts.append(thigh)
		_trouser_parts.append(_part(_sit_legs, _capsule(0.062, 0.42), Vector3(s * 0.12, -0.08, -0.42), _trousers))
		_boot(_sit_legs, Vector3(s * 0.12, -0.27, -0.42), boots, sole)
		# Seisova jalka: lonkasta alas, kävellessä heiluu (lantion solmu kääntyy)
		var hip := Node3D.new()
		hip.name = "Hip" + ("R" if s > 0 else "L")
		hip.position = Vector3(s * 0.11, 0.08, 0)
		_stand_legs.add_child(hip)
		_trouser_parts.append(_part(hip, _capsule(0.078, 0.46), Vector3(0, -0.22, 0), _trousers))
		_trouser_parts.append(_part(hip, _capsule(0.062, 0.44), Vector3(0.01 * s, -0.63, 0), _trousers))
		_boot(hip, Vector3(0.01 * s, -0.88, 0.0), boots, sole)
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
	# Takki: rintakehä hieman leveämpi kuin syvä, kaulus ja vetoketju
	_jacket_parts.append(_part(torso, _capsule(0.17, 0.56), Vector3(0, 0.25, 0), _camo, Vector3(1.15, 1.0, 0.8)))
	var shoulders := _part(torso, _capsule(0.12, 0.3), Vector3(0, 0.47, 0), _camo, Vector3(1.5, 0.6, 0.9))
	shoulders.rotation.z = PI / 2.0
	_accent_parts.append(shoulders)
	var collar := CylinderMesh.new()
	collar.top_radius = 0.07
	collar.bottom_radius = 0.1
	collar.height = 0.08
	_accent_parts.append(_part(torso, collar, Vector3(0, 0.56, 0.0), _camo))
	# Kelluntaliivi veneessä: oranssi, heijastinnauha rinnan yli ja vetoketju edessä
	_vest = Node3D.new()
	torso.add_child(_vest)
	var vest_mat := _material(Color(0.95, 0.4, 0.07))
	_part(_vest, _capsule(0.186, 0.5), Vector3(0, 0.29, 0), vest_mat, Vector3(1.15, 1.0, 0.82))
	var band := CylinderMesh.new()
	band.top_radius = 0.188
	band.bottom_radius = 0.188
	band.height = 0.035
	_part(_vest, band, Vector3(0, 0.38, 0), _material(Color(0.85, 0.87, 0.86)), Vector3(1.15, 1.0, 0.82))
	var zip := BoxMesh.new()
	zip.size = Vector3(0.012, 0.3, 0.01)
	_part(_vest, zip, Vector3(0, 0.28, -0.156), _material(Color(0.15, 0.15, 0.15)))
	# Kaula ja pää
	_part(torso, _capsule(0.05, 0.14), Vector3(0, 0.6, 0), skin)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.74, 0)
	torso.add_child(_head)
	_build_face(skin)
	_build_hats()

	rod_mount = Node3D.new()
	rod_mount.position = Vector3(0.2, 0.28, -0.18)
	torso.add_child(rod_mount)

	# Kädet: olkavarsi, kyynärvarsi ja käsi asetetaan IK:lla maailman koordinaatteihin
	for s in [-1.0, 1.0]:
		var arm := {"side": s}
		for key in ["upper", "fore"]:
			var mi := MeshInstance3D.new()
			mi.mesh = _capsule(0.056 if key == "upper" else 0.048, 1.0)
			mi.material_override = _camo
			mi.top_level = true
			add_child(mi)
			arm[key] = mi
			_jacket_parts.append(mi)
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
	set_winter(false)


## Kumisaapas: varsi säären ympärillä, terä eteenpäin ja musta pohja
func _boot(parent: Node3D, ankle: Vector3, boots: Material, sole: Material) -> void:
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.074
	shaft.bottom_radius = 0.068
	shaft.height = 0.26
	shaft.radial_segments = 12
	_part(parent, shaft, ankle + Vector3(0, 0.12, 0), boots)
	var foot := BoxMesh.new()
	foot.size = Vector3(0.115, 0.09, 0.28)
	_part(parent, foot, ankle + Vector3(0, 0.0, -0.06), boots)
	var toe := SphereMesh.new()
	toe.radius = 0.058
	toe.height = 0.09
	_part(parent, toe, ankle + Vector3(0, -0.005, -0.2), boots, Vector3(1.0, 1.0, 0.9))
	var sole_box := BoxMesh.new()
	sole_box.size = Vector3(0.12, 0.025, 0.3)
	_part(parent, sole_box, ankle + Vector3(0, -0.055, -0.07), sole)


## Kasvot: silmät (räpyttelevät), kulmakarvat, nenä, korvat, suu ja lyhyt parta
func _build_face(skin: Material) -> void:
	var skull := SphereMesh.new()
	skull.radius = 0.105
	skull.height = 0.25
	_part(_head, skull, Vector3.ZERO, skin)
	var nose := CapsuleMesh.new()
	nose.radius = 0.016
	nose.height = 0.055
	var n := _part(_head, nose, Vector3(0, -0.012, -0.103), skin)
	n.rotation.x = -0.25
	var hair := _material(BEARD)
	var white := _material(Color(0.92, 0.9, 0.86))
	var dark := _material(Color(0.08, 0.06, 0.05))
	var eye_white := SphereMesh.new()
	eye_white.radius = 0.016
	eye_white.height = 0.03
	var pupil := SphereMesh.new()
	pupil.radius = 0.009
	pupil.height = 0.018
	var brow := BoxMesh.new()
	brow.size = Vector3(0.036, 0.009, 0.012)
	for s in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(s * 0.037, 0.014, -0.091)
		_head.add_child(eye)
		_part(eye, eye_white, Vector3.ZERO, white, Vector3(1.0, 0.8, 0.6))
		_part(eye, pupil, Vector3(0, 0, -0.008), dark)
		_eyes.append(eye)
		var b := _part(_head, brow, Vector3(s * 0.038, 0.036, -0.096), hair)
		b.rotation.z = -s * 0.12
		var ear := SphereMesh.new()
		ear.radius = 0.025
		ear.height = 0.05
		_part(_head, ear, Vector3(s * 0.103, 0.0, 0.0), skin, Vector3(0.5, 1.0, 0.8))
	# Lyhyt parta leuan alla, viikset ja suu
	var beard := SphereMesh.new()
	beard.radius = 0.082
	beard.height = 0.09
	_part(_head, beard, Vector3(0, -0.085, -0.026), hair)
	var moustache := CapsuleMesh.new()
	moustache.radius = 0.011
	moustache.height = 0.06
	var m := _part(_head, moustache, Vector3(0, -0.044, -0.101), hair)
	m.rotation.z = PI / 2.0
	var mouth := BoxMesh.new()
	mouth.size = Vector3(0.03, 0.007, 0.01)
	_part(_head, mouth, Vector3(0, -0.062, -0.101), _material(Color(0.45, 0.2, 0.18)))


## Kesällä lippalakki, talvella tupsupipo
func _build_hats() -> void:
	_cap = Node3D.new()
	_head.add_child(_cap)
	var crown := CylinderMesh.new()
	crown.top_radius = 0.085
	crown.bottom_radius = 0.112
	crown.height = 0.085
	_part(_cap, crown, Vector3(0, 0.084, 0.005), _camo)
	var top := SphereMesh.new()
	top.radius = 0.085
	top.height = 0.06
	top.is_hemisphere = true
	_part(_cap, top, Vector3(0, 0.126, 0.005), _camo)
	var visor := BoxMesh.new()
	visor.size = Vector3(0.17, 0.012, 0.1)
	var v := _part(_cap, visor, Vector3(0, 0.05, -0.135), _camo)
	v.rotation.x = 0.18

	_beanie = Node3D.new()
	_head.add_child(_beanie)
	var knit := _material(WINTER_ACCENT)
	var dome := SphereMesh.new()
	dome.radius = 0.114
	dome.height = 0.13
	dome.is_hemisphere = true
	_part(_beanie, dome, Vector3(0, 0.05, 0.005), knit, Vector3(1.0, 1.25, 1.0))
	var cuff := CylinderMesh.new()
	cuff.top_radius = 0.115
	cuff.bottom_radius = 0.117
	cuff.height = 0.045
	_part(_beanie, cuff, Vector3(0, 0.06, 0.005), _material(Color(0.88, 0.86, 0.82)))
	var pompom := SphereMesh.new()
	pompom.radius = 0.035
	pompom.height = 0.07
	_part(_beanie, pompom, Vector3(0, 0.22, 0.005), knit)


## Vaatetus vuodenajan mukaan: kesällä maastotakki, kelluntaliivi ja lippis,
## talvella tumma pilkkihaalari punaisin olkapäin, pipo ja lapaset
func set_winter(on: bool) -> void:
	winter = on
	for mi in _jacket_parts:
		mi.material_override = _winter_suit if on else _camo
	for mi in _accent_parts:
		mi.material_override = _winter_accent if on else _camo
	for mi in _trouser_parts:
		mi.material_override = _winter_suit if on else _trousers
	_vest.visible = not on
	_cap.visible = not on
	_beanie.visible = on
	for arm in _arms:
		arm["hand"].material_override = _mitten if on else _skin


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
	if fishing.busy():
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
	elif (pose == Pose.FISHING or pose == Pose.ICE_SIT) and fishing.state == Fishing.State.FIGHT and not fishing.hands_free():
		lean = 0.12 + clampf(fishing.tension / 6.0, 0.0, 0.2) # nojaa taakse kalan vetäessä
	elif fishing.net_active():
		lean = -fishing.net_lean() # nojaa eteen ojentaessaan haavia
	torso.rotation.x = lerpf(torso.rotation.x, lean, minf(1.0, delta * 8.0))

	_update_arms()
	_update_head(delta)


## Mihin kalastaja katsoo (maailmassa), tai Vector3.INF = suoraan eteen
func look_target() -> Vector3:
	if fishing == null:
		return Vector3.INF
	match pose:
		Pose.ICE_SIT:
			return fishing.current_hole if fishing.current_hole != Vector3.INF else Vector3.INF
		Pose.ICE_DRILL:
			return global_transform * Vector3(0, -0.85, -0.6) # kairan terä
		Pose.MOTOR:
			var ahead := boat.pos + boat.forward() * 25.0
			return Vector3(ahead.x, 0.5, ahead.y)
		Pose.ROWING:
			if _glance > 0.0:
				var bow := boat.pos + boat.forward() * 20.0
				return Vector3(bow.x, 0.5, bow.y)
			return Vector3.INF
	if fishing.net_active() or fishing.state in [Fishing.State.FLYING, Fishing.State.RETRIEVING, Fishing.State.BITE, Fishing.State.FIGHT, Fishing.State.LANDING]:
		# Uistin, koho tai kala: katse kohtaan, jossa siima menee veteen
		return Vector3(fishing.lure_pos.x, maxf(fishing.lure_pos.y, 0.0), fishing.lure_pos.z)
	return Vector3.INF


## Pää kääntyy katseen kohteeseen (rajoitetusti), silmät räpyttelevät
func _update_head(delta: float) -> void:
	if pose == Pose.ROWING:
		# Soutaja vilkaisee välillä olan yli, ettei aja rantaan
		_glance -= delta
		if _glance < -6.0:
			_glance = 1.2
	else:
		_glance = 0.0
	var yaw := 0.0
	var pitch := -0.08
	var target := look_target()
	if target != Vector3.INF:
		# Kohde kaulan koordinaatistossa (vartalon suunta, pään oma kierto ei mukana)
		var neck := torso.global_transform * Transform3D(Basis.IDENTITY, _head.position)
		var local := neck.affine_inverse() * target
		yaw = clampf(atan2(-local.x, -local.z), -HEAD_YAW_LIMIT, HEAD_YAW_LIMIT)
		pitch = clampf(atan2(local.y, Vector2(local.x, local.z).length()), -0.7, 0.35)
	var rate := minf(1.0, delta * 4.0)
	_head.rotation.y = lerp_angle(_head.rotation.y, yaw, rate)
	_head.rotation.x = lerp_angle(_head.rotation.x, pitch, rate)
	_blink_in -= delta
	var open := 1.0
	if _blink_in < 0.0:
		open = 0.1
		if _blink_in < -0.12:
			_blink_in = randf_range(2.0, 5.5)
	for eye in _eyes:
		eye.scale.y = open


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
		_ when fishing.hands_free():
			# Vavat telineissä: kädet polvilla
			right = global_transform * Vector3(0.12, 0.12, -0.32)
			left = global_transform * Vector3(-0.12, 0.12, -0.32)
		_:
			right = fishing.rod_point(0.3) # kelan jalan kohdalla
			left = fishing.reel_knob() if fishing.is_reeling() else fishing.rod_point(0.55)
			if fishing.net_active():
				# Haavinta: oikea käsi haavin varren päässä; vasen pitää vapaa,
				# kunnes kala on haavissa, ja tarttuu sitten varteen nostoon
				var grips := fishing.net_grips()
				left = grips[1] if grips.size() > 1 else right
				right = grips[0]
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

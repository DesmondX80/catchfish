class_name LandingNet
extends Node3D
## Haavinta omana animaationaan. Avovedessä kalastaja ojentaa haavin veteen,
## kala ohjataan pää edellä haaviin, haavi nostetaan sätkivän kalan kanssa
## (vettä valuu) ja käännetään laidan yli veneen pohjalle. Jäällä kala
## nostetaan avannosta jäälle. Animaation ajan kamera kuvaa haavintaa
## veneen ulkopuolelta (camera_shot).
##
## Haavin kehän keskipiste on solmun origossa, ja varsi osoittaa paikallista
## +Z:aa kohti kalastajaa.

signal sound(name: String, at: Vector3)
signal finished

const BOAT_TIME := 3.4
const ICE_TIME := 2.2
# Vaiheiden rajat (s): ojennus, kauhaisu, nosto, käännös veneeseen, lasku pohjalle
const REACH := 0.8
const SCOOP := 1.3
const LIFT := 2.1
const SWING := 2.9
## Varren pää (oikea käsi) ja keskikohta (vasen käsi nostossa) haavin koordinaateissa
const GRIP_END := Vector3(0, 0.55, 1.45)
const GRIP_MID := Vector3(0, 0.36, 0.95)

var boat: Boat
var t := 0.0
var _on_ice := false
var _active := false
var _from := Vector3.ZERO # kalan paikka haavinnan alussa
var _hole := Vector3.ZERO
var _species := ""
var _len_m := 0.5
var _side := Vector2.RIGHT # veneen laita, jonka puolella kala on
var _net: Node3D
var _bag: Node3D # verkkopussin kiinnityskohta kehässä (pussi heiluu siitä)
var _fish: MeshInstance3D
var _drips: CPUParticles3D
var _splashed := false
var _shot := Transform3D.IDENTITY


func setup(boat_node: Boat) -> void:
	boat = boat_node
	_build()


## Aloittaa haavinnan kalan nykyisestä paikasta
func start(fish_pos: Vector3, species: String, weight: float, on_ice: bool, hole: Vector3) -> void:
	t = 0.0
	_active = true
	_on_ice = on_ice
	_from = fish_pos
	_hole = hole
	_species = species
	_len_m = Species.length_cm(species, weight) / 100.0
	_splashed = false
	# Kala haavitaan sen puoleisen laidan yli (keulan tai perän edessäkin)
	var to_fish := Vector2(fish_pos.x - boat.pos.x, fish_pos.z - boat.pos.y)
	_side = boat.right() * (1.0 if to_fish.dot(boat.right()) >= 0.0 else -1.0)
	_net.visible = not on_ice
	_fish.mesh = FishModels.mesh(species)
	_fish.material_override = FishModels.material(species).duplicate()
	_fish.visible = true
	_shot = _camera_shot()
	update(0.0)


func active() -> bool:
	return _active


## Haavi kalastajan käsissä (avovesi)
func net_in_hands() -> bool:
	return _active and not _on_ice


## Kalastajan kädet: [oikea, vasen]. Vasen käsi pitää vapaa, kunnes kala on
## haavissa (tyhjä = vapa), ja tarttuu sitten varteen nostoa varten.
func grips() -> Array:
	var right := _net.global_transform * GRIP_END
	if t < SCOOP:
		return [right]
	return [right, _net.global_transform * GRIP_MID]


## Kalastaja nojaa eteen ojentaessaan haavia
func lean() -> float:
	if not net_in_hands():
		return 0.0
	return 0.3 * (smoothstep(0.0, REACH, t) - smoothstep(SCOOP, LIFT, t))


## Kamera haavinnan ajan: veneen ulkopuolelta viistosti edestä kalan puolelta
func camera_shot() -> Transform3D:
	return _shot


func update(dt: float) -> void:
	if not _active:
		return
	t += dt
	if _on_ice:
		_ice_lift()
		if t >= ICE_TIME:
			_end()
		return
	_boat_netting(dt)
	if t >= BOAT_TIME:
		_end()


## Ruudun tahdissa: haavi seuraa ruudulla näkyvää venettä (Fishing.follow_boat)
func follow_boat() -> void:
	if _active and not _on_ice:
		_boat_netting(0.0)


func _end() -> void:
	_active = false
	_net.visible = false
	_fish.visible = false
	_drips.emitting = false
	finished.emit()


func _side3() -> Vector3:
	return Vector3(_side.x, 0, _side.y)


func _camera_shot() -> Transform3D:
	var fwd := Vector3(boat.forward().x, 0, boat.forward().y)
	var side := _side3()
	if _on_ice:
		var hole := Vector3(_hole.x, 0.0, _hole.z)
		var eye := hole + side * 1.4 + fwd * 1.1 + Vector3(0, 0.95, 0)
		return Transform3D(Basis.looking_at(hole + Vector3(0, 0.3, 0) - eye), eye)
	var gunwale := Vector3(boat.pos.x, 0.75, boat.pos.y) + side * 0.9
	var look := gunwale - side * 0.35 + Vector3(0, -0.05, 0)
	# Veden päältä viistosti edestä tai takaa (rannan puolella toisesta suunnasta)
	var eye := gunwale + side * 1.7 + fwd * 1.5 + Vector3(0, 0.45, 0)
	for along in [1.5, -1.5, 0.0]:
		var e: Vector3 = gunwale + side * 1.7 + fwd * along + Vector3(0, 0.45, 0)
		if boat.lake.is_water(e.x, e.z):
			eye = e
			break
	eye.y = maxf(eye.y, boat.lake.height_at(eye.x, eye.z) + 0.6)
	return Transform3D(Basis.looking_at(look - eye), eye)


## Avovesi: haavin reitti ja kala haavissa
func _boat_netting(dt: float) -> void:
	var side := _side3()
	var center := Vector3(boat.global_position.x, 0.0, boat.global_position.z)
	var raised := center + side * 0.75 + Vector3(0, 0.95, 0) # haavi pystyssä laidan yllä
	var beside := Vector3(_from.x, -0.05, _from.z) + side * 0.15 # vedenpinnassa kalan takana
	var under := Vector3(_from.x, -0.4, _from.z)
	var over_rail := center + side * 0.85 + Vector3(0, 1.0, 0)
	var above_floor := center + side * 0.1 + Vector3(0, 0.7, 0)
	var on_floor := center + side * 0.05 + Vector3(0, 0.3, 0)
	var p: Vector3
	if t < REACH:
		p = raised.lerp(beside, smoothstep(0.0, REACH, t))
	elif t < SCOOP:
		p = beside.lerp(under, smoothstep(REACH, SCOOP, t))
	elif t < LIFT:
		var u := smoothstep(SCOOP, LIFT, t)
		p = under.lerp(over_rail, u)
		p.y += sin(u * PI) * 0.1 # kaari ylös
	elif t < SWING:
		var u := smoothstep(LIFT, SWING, t)
		p = over_rail.lerp(above_floor, u)
		p.y += sin(u * PI) * 0.15 # laidan yli
	else:
		p = above_floor.lerp(on_floor, smoothstep(SWING, BOAT_TIME, t))
	# Varsi osoittaa kalastajaa kohti; ojennettaessa kehä kallistuu veteen
	var toward := center + Vector3(0, 0.6, 0) - p
	var yaw := atan2(toward.x, toward.z) if Vector2(toward.x, toward.z).length() > 0.05 else boat.yaw
	var tilt := 0.35 * (smoothstep(0.3, REACH, t) - smoothstep(SCOOP, LIFT, t))
	_net.global_transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt), p)
	# Verkkopussi heiluu kalan painosta
	var sway := sin(t * 11.0) * 0.12 * (smoothstep(SCOOP, LIFT, t) - smoothstep(SWING, BOAT_TIME, t))
	_bag.rotation = Vector3(sway, 0, sway * 0.6)

	# Kala: vedessä kunnes ohjataan pää edellä haaviin, sitten kyljellään haavissa
	var len_m := minf(_len_m, 0.7)
	var in_net := _net.global_transform * Vector3(0, -0.14, 0)
	var basis := Basis(Vector3.UP, boat.yaw + 1.2)
	var at := Vector3(_from.x, -0.15, _from.z)
	var wiggle := 12.0
	if t >= REACH:
		var u := smoothstep(REACH, SCOOP, t)
		at = at.lerp(in_net, u)
		basis = basis.slerp(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, PI / 2.0 * 0.8), u)
		basis = basis * Basis(Vector3.UP, sin(t * 14.0) * 0.25 * u) # sätkii haavissa
		wiggle = lerpf(12.0, 22.0, u) if t < SWING else 10.0
	_fish.global_transform = Transform3D(basis.orthonormalized().scaled(Vector3.ONE * len_m), at)
	_fish.material_override.set_shader_parameter("swim_rate", wiggle)
	if t >= REACH + 0.25 and not _splashed:
		_splashed = true
		sound.emit("net_landing", under)
		sound.emit("fish_splash", under)
	# Nostossa vettä valuu verkosta
	_drips.global_position = _net.global_transform * Vector3(0, -0.35, 0)
	_drips.emitting = t > SCOOP and t < SWING and p.y > 0.0


## Jää: kala nostetaan siimasta pää edellä avannosta ja lasketaan kyljelleen jäälle
func _ice_lift() -> void:
	var hole := Vector3(_hole.x, 0.0, _hole.z)
	var up := hole + Vector3(0, 0.45, 0)
	var side := boat.right()
	var rest := hole + Vector3(side.x * 0.45, 0.05, side.y * 0.45)
	var p := Vector3(hole.x, -0.4, hole.z).lerp(up, smoothstep(0.0, 0.9, t)).lerp(rest, smoothstep(1.2, ICE_TIME, t))
	var lying := Basis(Vector3.UP, boat.yaw + 0.3) * Basis(Vector3.BACK, PI / 2.0)
	var basis := Basis(Vector3.RIGHT, -PI / 2.0).slerp(lying, smoothstep(1.2, ICE_TIME, t))
	basis = basis * Basis(Vector3.FORWARD, sin(t * 12.0) * 0.3 * (1.0 - smoothstep(1.4, ICE_TIME, t))) # sätkii siimassa
	_fish.global_transform = Transform3D(basis.orthonormalized().scaled(Vector3.ONE * _len_m), p)
	_fish.material_override.set_shader_parameter("swim_rate", 14.0)
	if t > 0.5 and not _splashed:
		_splashed = true
		sound.emit("fish_splash", hole)


func _build() -> void:
	_net = Node3D.new()
	_net.top_level = true
	_net.visible = false
	add_child(_net)
	var alu := StandardMaterial3D.new()
	alu.albedo_color = Color(0.75, 0.77, 0.8)
	alu.metallic = 0.7
	alu.roughness = 0.35
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = Color(0.12, 0.14, 0.12, 0.55)
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var hoop := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.27
	torus.outer_radius = 0.3
	torus.material = alu
	hoop.mesh = torus
	_net.add_child(hoop)
	_bag = Node3D.new()
	_net.add_child(_bag)
	var bag := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.28
	cone.bottom_radius = 0.06
	cone.height = 0.4
	cone.material = mesh_mat
	bag.mesh = cone
	bag.position = Vector3(0, -0.2, 0)
	_bag.add_child(bag)
	var handle := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.016
	cyl.bottom_radius = 0.016
	cyl.height = 1.3
	cyl.material = alu
	handle.mesh = cyl
	handle.rotation.x = PI / 2.0 - 0.45 # varsi nousee viistosti kohti kalastajaa
	handle.position = Vector3(0, 0.28, 0.85)
	_net.add_child(handle)

	_fish = MeshInstance3D.new()
	_fish.top_level = true
	_fish.visible = false
	_fish.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fish)

	# Vesipisarat verkosta nostettaessa
	_drips = CPUParticles3D.new()
	_drips.top_level = true
	_drips.emitting = false
	_drips.amount = 40
	_drips.lifetime = 0.6
	_drips.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_drips.emission_sphere_radius = 0.12
	_drips.direction = Vector3.DOWN
	_drips.initial_velocity_min = 0.2
	_drips.initial_velocity_max = 0.6
	_drips.gravity = Vector3(0, -9.8, 0)
	_drips.scale_amount_min = 0.6
	_drips.scale_amount_max = 1.2
	var drop := SphereMesh.new()
	drop.radius = 0.008
	drop.height = 0.02
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.6, 0.7, 0.75, 0.7)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.05
	drop.material = water
	_drips.mesh = drop
	add_child(_drips)

class_name CatchTub
extends Node3D
## Kalasaavi: muovisaavi veneen pohjalla perätuhdon takana (jäällä kalastajan
## vieressä). Reissun kalat uivat saavissa 3D-malleina; Tab näyttää saavin
## ylhäältä.

const SIZE := Vector3(0.52, 0.28, 0.38) # pituus, korkeus, leveys
## Pohjan keskikohta veneen rungossa: perätuhdon takana oikealla, pituus veneen
## suuntaan, ettei perämoottorin ohjausaisa peitä saavia ylhäältä katsottaessa.
## Pohja on 3 mm lattian yläpuolella: samassa tasossa pohja ja lattia välkkyivät.
const ON_BOAT := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(0.12, -0.127, 1.84))
const ON_ICE := Vector3(0.75, 0.003, 0.35) # jäällä kalastajan oikealla puolella (pohja jään yläpuolella)
const WATER_LEVEL := 0.7 # osuus saavin korkeudesta

var boat: Boat
var fishing: Fishing
var catches: Array = [] # reissun saalis (main.trip_catch)
var _fish_root: Node3D
var _shown := -1 # montako kalaa saavissa nyt näkyy
var _lamp: OmniLight3D


func setup(boat_node: Boat, fishing_node: Fishing, trip_catch: Array) -> void:
	boat = boat_node
	fishing = fishing_node
	catches = trip_catch
	top_level = true
	_build()


## Saavia katsottaessa lamppu valaisee sen (myös pimeällä)
func set_viewing(on: bool) -> void:
	_lamp.visible = on


## Kamera katsoo saavia tästä pisteestä alas. Lasketaan veneen tämänhetkisestä
## asennosta: kameran _process voi ajaa ennen saavin omaa, ja edellisen framen
## paikka saisi kuvan tärisemään veneen liikkuessa.
func view_point() -> Vector3:
	return _placement() * Vector3(0, SIZE.y * WATER_LEVEL, 0)


## Saavin paikka veneessä tai jäällä
func _placement() -> Transform3D:
	if boat.on_ice:
		return boat.global_transform * Transform3D(Basis.IDENTITY, ON_ICE)
	return boat.hull.global_transform * ON_BOAT


## Näyttää saavissa reissun kalat. Juuri saatu kala on vielä haavissa tai
## veneen pohjalla, kunnes saalisikkuna suljetaan.
func _show_catch() -> void:
	var n := catches.size()
	if n > 0 and fishing.state == Fishing.State.LANDED:
		n -= 1
	if n == _shown:
		return
	_shown = n
	for c in _fish_root.get_children():
		c.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for i in n:
		var e: Dictionary = catches[i]
		var sp: String = e["species"]
		if not FishModels.PROFILES.has(sp):
			continue # vanhan tallennuksen laji, jolla ei ole mallia
		var fish := MeshInstance3D.new()
		fish.mesh = FishModels.mesh(sp)
		var mat: ShaderMaterial = FishModels.material(sp).duplicate()
		mat.set_shader_parameter("swim_rate", rng.randf_range(0.8, 1.6)) # kalat liikahtelevat
		fish.material_override = mat
		fish.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var len_m: float = e["length"] / 100.0
		# Kalat vuorotellen eri suuntiin saavin pituussuunnassa; pitkä kala vinottain
		var yaw := PI / 2.0 if i % 2 == 0 else -PI / 2.0
		if len_m > SIZE.x - 0.06:
			yaw += 0.6 if i % 2 == 0 else -0.6
		yaw += rng.randf_range(-0.25, 0.25)
		var side := (float(i % 3) - 1.0) * SIZE.z * 0.25
		var layer := SIZE.y * (0.15 + 0.08 * floori(i / 3.0))
		fish.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, rng.randf_range(-0.3, 0.3)), Vector3(rng.randf_range(-0.04, 0.04), minf(layer, SIZE.y * 0.62), side)).scaled_local(Vector3.ONE * len_m)
		_fish_root.add_child(fish)


func _process(_delta: float) -> void:
	if boat == null:
		return
	global_transform = _placement()
	_show_catch()


func _build() -> void:
	var plastic := StandardMaterial3D.new()
	plastic.albedo_color = Color(0.2, 0.42, 0.32)
	plastic.roughness = 0.6
	plastic.cull_mode = BaseMaterial3D.CULL_DISABLED # sisäpuoli näkyy ylhäältä
	# Saavi: soikea, hieman ylöspäin levenevä astia (litistetty sylinteri ilman kantta)
	var tub := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.44
	cyl.height = 1.0
	cyl.cap_top = false
	cyl.radial_segments = 28
	cyl.material = plastic
	tub.mesh = cyl
	tub.scale = Vector3(SIZE.x, SIZE.y, SIZE.z)
	tub.position = Vector3(0, SIZE.y / 2.0, 0)
	add_child(tub)
	# Reunus ja kahvat
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.48
	torus.outer_radius = 0.53
	torus.material = plastic
	rim.mesh = torus
	rim.scale = Vector3(SIZE.x, 0.4, SIZE.z)
	rim.position = Vector3(0, SIZE.y, 0)
	add_child(rim)
	for s in [-1.0, 1.0]:
		var handle := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.04, 0.025, 0.14)
		box.material = plastic
		handle.mesh = box
		handle.position = Vector3(s * (SIZE.x / 2.0 + 0.02), SIZE.y - 0.02, 0)
		add_child(handle)
	# Vesi: läpikuultava humusvesi, jonka läpi kalat näkyvät ylhäältä
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.49
	disc.bottom_radius = 0.49
	disc.height = 0.002
	disc.radial_segments = 28
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.25, 0.2, 0.08, 0.35)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.05
	water_mat.metallic = 0.2
	disc.material = water_mat
	water.mesh = disc
	water.scale = Vector3(SIZE.x * 0.98, 1.0, SIZE.z * 0.98)
	water.position = Vector3(0, SIZE.y * WATER_LEVEL, 0)
	add_child(water)
	_fish_root = Node3D.new()
	add_child(_fish_root)
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0, 0.9, 0)
	_lamp.omni_range = 1.6
	_lamp.light_energy = 0.8
	_lamp.light_color = Color(1.0, 0.95, 0.85)
	_lamp.visible = false
	add_child(_lamp)

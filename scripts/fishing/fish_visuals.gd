class_name FishVisuals
extends Node3D
## Näyttää veneen lähellä olevat kalat vedessä. Kalakannan data päivittyy
## harvakseltaan, joten näkyvä kala ui pehmeästi kohti datan sijaintia.
## Tummassa humusvedessä kalat näkyvät vain pinnan lähellä (fish.gdshader).

const RADIUS := 40.0
const MAX_PER_SPECIES := 400
const QUERY_INTERVAL := 0.3

var population: FishPopulation
var boat: Boat
var fishing: Fishing
var lake: LakeData

var _multimeshes := {} # laji -> MultiMesh
var _states := {} # kalan indeksi -> {pos, heading, phase, speed}
var _query_timer := 0.0
var _nearby: Array[int] = []
var _time := 0.0


func setup(pop: FishPopulation, boat_node: Boat, fishing_node: Fishing, lake_data: LakeData) -> void:
	population = pop
	boat = boat_node
	fishing = fishing_node
	lake = lake_data
	for sp in Species.DATA:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = FishModels.mesh(sp)
		mm.instance_count = MAX_PER_SPECIES
		mm.visible_instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = FishModels.material(sp)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_multimeshes[sp] = mm


func _process(delta: float) -> void:
	_time += delta
	_query_timer -= delta
	if _query_timer <= 0.0:
		_query_timer = QUERY_INTERVAL
		_nearby = population.fish_near(boat.pos, RADIUS)
		var keep := {}
		for i in _nearby:
			keep[i] = true
			if not _states.has(i):
				var f: Dictionary = population.fish[i]
				_states[i] = {
					"pos": Vector3(f["pos"].x, -f["depth"], f["pos"].y),
					"heading": randf() * TAU,
					"phase": randf(),
					"speed": 0.0,
				}
		for i in _states.keys():
			if not keep.has(i):
				_states.erase(i)

	var counts := {}
	for sp in _multimeshes:
		counts[sp] = 0
	var hooked := fishing.hooked_indices()
	for i in _states:
		if i in hooked or i >= population.fish.size():
			continue
		var f: Dictionary = population.fish[i]
		var sp: String = f["sp"]
		if counts[sp] >= MAX_PER_SPECIES:
			continue
		var s: Dictionary = _states[i]
		_swim(s, f, delta)
		var length: float = Species.length_cm(sp, f["weight"]) / 100.0
		var basis := Basis(Vector3.UP, s["heading"]).scaled(Vector3.ONE * length)
		var mm: MultiMesh = _multimeshes[sp]
		mm.set_instance_transform(counts[sp], Transform3D(basis, s["pos"]))
		# Uintitahti: hidas risteily, nopeampi kun kala kiirehtii
		mm.set_instance_custom_data(counts[sp], Color(s["phase"], 2.5 + s["speed"] * 14.0, 0.0, 0.0))
		counts[sp] += 1
	for sp in _multimeshes:
		_multimeshes[sp].visible_instance_count = counts[sp]


## Kala ui kohti datan sijaintia ja kääntyilee luontevasti
func _swim(s: Dictionary, f: Dictionary, dt: float) -> void:
	var target := Vector3(f["pos"].x, -f["depth"], f["pos"].y)
	var pos: Vector3 = s["pos"]
	var to := target - pos
	var flat := Vector2(to.x, to.z)
	if flat.length() > 8.0:
		s["pos"] = target # kala on vaihtanut paikkaa (esim. uusi kala)
		return
	var wander := sin(_time * 0.35 + s["phase"] * 10.0) * 0.6
	var desired: float = atan2(-to.x, -to.z) + wander if flat.length() > 0.4 else s["heading"] + wander * dt
	s["heading"] = lerp_angle(s["heading"], desired, minf(1.0, dt * 1.2))
	var speed := clampf(flat.length() * 0.35, 0.05, 0.6)
	s["speed"] = lerpf(s["speed"], speed, minf(1.0, dt * 2.0))
	var fwd := Vector3(-sin(s["heading"]), 0.0, -cos(s["heading"]))
	pos += fwd * s["speed"] * dt
	pos.y = lerpf(pos.y, target.y, minf(1.0, dt * 0.5))
	var bottom := lake.depth_at(pos.x, pos.z)
	pos.y = clampf(pos.y, -maxf(0.2, bottom - 0.1), -0.15)
	s["pos"] = pos

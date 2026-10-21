class_name FishVisuals
extends Node3D
## Vedessä näkyvät kalat. Tummassa humusvedessä vapaasti uivia kaloja ei näe
## (ne ovat kalakannan dataa, ja kaikuluotain näyttää ne), joten tässä
## piirretään vain uistinta seuraava hauki (Fishing.visible_fish()).
## Koukussa olevan kalan piirtää Fishing itse. Humusvesi haalistaa kalan
## syvyyden mukaan (fish.gdshader), joten seuraaja tulee näkyviin vasta
## pinnan lähellä.

const MAX_PER_SPECIES := 4

var fishing: Fishing

var _multimeshes := {} # laji -> MultiMesh
var _phase := randf()


func setup(fishing_node: Fishing) -> void:
	fishing = fishing_node
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


func _process(_delta: float) -> void:
	var counts := {}
	for sp in _multimeshes:
		counts[sp] = 0
	for f in fishing.visible_fish():
		var sp: String = f["sp"]
		if counts[sp] >= MAX_PER_SPECIES:
			continue
		var length: float = Species.length_cm(sp, f["weight"]) / 100.0
		var basis := Basis(Vector3.UP, f["heading"]).scaled(Vector3.ONE * length)
		var mm: MultiMesh = _multimeshes[sp]
		mm.set_instance_transform(counts[sp], Transform3D(basis, f["pos"]))
		# Uintitahti: hidas risteily, nopeampi kun kala kiirehtii
		mm.set_instance_custom_data(counts[sp], Color(_phase, 2.5 + f["speed"] * 10.0, 0.0, 0.0))
		counts[sp] += 1
	for sp in _multimeshes:
		_multimeshes[sp].visible_instance_count = counts[sp]

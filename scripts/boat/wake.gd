class_name Wake
extends MeshInstance3D
## Veneen perävana: perän takana vaahtoava kulku-uoma ja sivuille leviävät
## V-muotoiset aallot (Kelvinin aallot, puolikulma n. 19,5°). Vanan voimakkuus
## riippuu nopeudesta. Lisäksi airojen vedoista jää pieniä pyörteitä.

const SAMPLE_DISTANCE := 0.7 # m
const LIFETIME := 14.0 # s
const SWIRL_LIFETIME := 5.0
const KELVIN_SPREAD := 0.354 # tan(19,5°)

var _samples: Array[Dictionary] = [] # {p, right, speed, t}
var _swirls: Array[Dictionary] = [] # {p, t, size}
var _mesh := ImmediateMesh.new()
var _verts := PackedVector3Array()
var _colors := PackedColorArray()
var _time := 0.0
var material: ShaderMaterial


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/wake.gdshader")
	material_override = material


## Kutsutaan joka fysiikkaruudulla: perän sijainti, veneen sivusuunta ja nopeus
func track(stern: Vector2, right: Vector2, speed: float) -> void:
	if speed < 0.15:
		return
	if _samples.is_empty() or _samples[-1]["p"].distance_to(stern) >= SAMPLE_DISTANCE:
		_samples.append({"p": stern, "right": right, "speed": speed, "t": _time})


func add_swirl(p: Vector2, size := 1.0) -> void:
	_swirls.append({"p": p, "t": _time, "size": size})


func _process(delta: float) -> void:
	_time += delta
	while not _samples.is_empty() and _time - _samples[0]["t"] > LIFETIME:
		_samples.pop_front()
	while not _swirls.is_empty() and _time - _swirls[0]["t"] > SWIRL_LIFETIME:
		_swirls.pop_front()
	_rebuild()


func _rebuild() -> void:
	_mesh.clear_surfaces()
	_verts.clear()
	_colors.clear()
	for i in range(_samples.size() - 1):
		var a := _samples[i]
		var b := _samples[i + 1]
		if a["p"].distance_to(b["p"]) > SAMPLE_DISTANCE * 4.0:
			continue # aukko vanassa (vene pysähtyi välillä)
		var age_a: float = _time - a["t"]
		var age_b: float = _time - b["t"]
		# Kulku-uoma perän takana: levenee ja haalenee
		_strip(a, b, age_a, age_b, 0.0, func(s, age): return 0.45 + age * 0.12 + s * 0.08,
			func(s, age): return clampf((s - 0.8) / 4.0, 0.0, 0.75) * exp(-age / 4.0))
		# Kelvinin aallot molemmille sivuille: leviävät iän ja nopeuden mukaan
		for side in [-1.0, 1.0]:
			_strip(a, b, age_a, age_b, side, func(s, age): return 0.18 + age * 0.04,
				func(s, age): return clampf((s - 0.6) / 3.5, 0.0, 0.55) * exp(-age / 5.0))
	for swirl in _swirls:
		_ring(swirl)
	if _verts.is_empty():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in _verts.size():
		_mesh.surface_set_color(_colors[i])
		_mesh.surface_add_vertex(_verts[i])
	_mesh.surface_end()


## Vaahtonauha kahden näytteen välillä. side 0 = keskellä, ±1 = sivuaalto.
func _strip(a: Dictionary, b: Dictionary, age_a: float, age_b: float, side: float, width_fn: Callable, alpha_fn: Callable) -> void:
	var pts := []
	for s in [[a, age_a], [b, age_b]]:
		var sample: Dictionary = s[0]
		var age: float = s[1]
		var speed: float = sample["speed"]
		var right: Vector2 = sample["right"]
		var center: Vector2 = sample["p"] + right * side * (0.6 + age * speed * KELVIN_SPREAD)
		var w: float = width_fn.call(speed, age)
		var alpha: float = alpha_fn.call(speed, age)
		pts.append([center - right * w, center + right * w, alpha])
	if pts[0][2] < 0.01 and pts[1][2] < 0.01:
		return
	var quad := [[pts[0][0], pts[0][2]], [pts[0][1], pts[0][2]], [pts[1][1], pts[1][2]], [pts[1][0], pts[1][2]]]
	for idx in [0, 1, 2, 0, 2, 3]:
		var v: Array = quad[idx]
		_colors.append(Color(1, 1, 1, v[1]))
		_verts.append(Vector3(v[0].x, 0.0, v[0].y))


## Airon pyörre: laajeneva, haalistuva rengas
func _ring(swirl: Dictionary) -> void:
	var age: float = _time - swirl["t"]
	var r: float = (0.12 + age * 0.12) * swirl["size"]
	var w := 0.04 + age * 0.02
	var alpha := 0.35 * exp(-age / 1.4)
	var c: Vector2 = swirl["p"]
	var segments := 14
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		var quad := [c + d0 * (r - w), c + d0 * (r + w), c + d1 * (r + w), c + d1 * (r - w)]
		for idx in [0, 1, 2, 0, 2, 3]:
			_colors.append(Color(1, 1, 1, alpha))
			_verts.append(Vector3(quad[idx].x, 0.0, quad[idx].y))

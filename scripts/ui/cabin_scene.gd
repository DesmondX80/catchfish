class_name CabinScene
extends Node3D
## Alkuvalikon taustanäkymä: kodikas mökin pirtti. Hirsiseinät, lankkulattia,
## ikkunat sivuseinillä, takka nurkassa lepattavine tulineen, pirtinpöytä
## tuoleineen sekä takaseinällä vanha kuvaputki-TV, jossa pyörii kalastusohjelma. Huoneen koordinaatit: x -3..3, z -4.6 (takaseinä)..0, y 0..2.6.

const W := 3.0 # puolileveys
const D := 4.6 # syvyys
const H := 2.6 # korkeus
const LOG_R := 0.11

var _fire_light: OmniLight3D
var _flames: Array[MeshInstance3D] = []
var _tv_light: OmniLight3D
var tv_screen: MeshInstance3D
var _time := 0.0
var _rng := RandomNumberGenerator.new()
## Ikkunanäkymän vuodenaika: todellisessa ajassa tämän päivän mukaan
var season := Season.from_day(165)


func _ready() -> void:
	_rng.seed = 11
	if Settings.real_world:
		var t := Time.get_datetime_dict_from_system()
		var jan1 := Time.get_unix_time_from_datetime_dict({"year": t["year"], "month": 1, "day": 1})
		var today := Time.get_unix_time_from_datetime_dict({"year": t["year"], "month": t["month"], "day": t["day"]})
		season = Season.from_day(int((today - jan1) / 86400.0) + 1)
	else:
		season = Season.from_day(Settings.season_day())
	_environment()
	_camera()
	_floor_and_ceiling()
	_walls()
	_windows()
	_fireplace()
	_table_and_chairs()
	_tv()
	_details()


func _mat(color: Color, roughness := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


func _box(size: Vector3, at: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	b.material = mat
	mi.mesh = b
	mi.position = at
	parent.add_child(mi)
	return mi


func _cyl(radius: float, height: float, at: Vector3, mat: Material, parent: Node3D = self, segments := 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = segments
	c.material = mat
	mi.mesh = c
	mi.position = at
	parent.add_child(mi)
	return mi


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.04, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.42, 0.32)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# Päivänvalo ikkunoista (heikko, viileä)
	for side in [-1.0, 1.0]:
		var spot := SpotLight3D.new()
		spot.light_color = Color(0.85, 0.9, 1.0)
		spot.light_energy = 2.2
		spot.spot_range = 7.0
		spot.spot_angle = 55.0
		spot.position = Vector3(side * (W + 0.6), 1.9, -2.3)
		add_child(spot)
		spot.look_at(Vector3(0, 0.3, -2.3), Vector3.UP)


func _camera() -> void:
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.position = Vector3(-0.4, 1.55, 0.2)
	add_child(cam)
	cam.look_at(Vector3(0.55, 0.95, -3.4), Vector3.UP)
	cam.make_current()


func _floor_and_ceiling() -> void:
	var plank_colors := [Color(0.48, 0.32, 0.18), Color(0.44, 0.29, 0.16), Color(0.52, 0.35, 0.2)]
	var mats := plank_colors.map(func(c): return _mat(c, 0.75))
	var x := -W
	var i := 0
	while x < W:
		_box(Vector3(0.18, 0.05, D + 0.5), Vector3(x + 0.09, -0.025, -D / 2.0), mats[i % mats.size()])
		x += 0.19
		i += 1
	_box(Vector3(W * 2.0 + 0.4, 0.05, D + 0.5), Vector3(0, H + 0.025, -D / 2.0), _mat(Color(0.4, 0.28, 0.17)))
	var beam := _mat(Color(0.3, 0.2, 0.12))
	for z in [-0.6, -2.0, -3.4]:
		_box(Vector3(W * 2.0, 0.18, 0.16), Vector3(0, H - 0.09, z), beam)


## Hirret: vaakasuorat pölkyt, sävyt vaihtelevat hirsittäin
func _walls() -> void:
	var tones := [Color(0.62, 0.43, 0.24), Color(0.57, 0.39, 0.21), Color(0.66, 0.47, 0.27), Color(0.54, 0.37, 0.2)]
	var mats := tones.map(func(c): return _mat(c))
	var rows := int(H / (LOG_R * 1.9))
	for k in rows:
		var y := LOG_R + k * LOG_R * 1.9
		var back := _cyl(LOG_R, W * 2.0 + 0.3, Vector3(0, y, -D - LOG_R), mats[(k + 1) % mats.size()])
		back.rotation.z = PI / 2.0
		for side in [-1.0, 1.0]:
			var wall := _cyl(LOG_R, D + 0.6, Vector3(side * (W + LOG_R), y, -D / 2.0), mats[(k + (2 if side > 0 else 0)) % mats.size()])
			wall.rotation.x = PI / 2.0
	# Hirsien päät takanurkissa
	var end := _mat(Color(0.75, 0.6, 0.42))
	for k in rows:
		for side in [-1.0, 1.0]:
			var stub := _cyl(LOG_R * 0.98, 0.02, Vector3(side * (W + LOG_R), LOG_R + k * LOG_R * 1.9, 0.31), end)
			stub.rotation.x = PI / 2.0


func _windows() -> void:
	var frame := _mat(Color(0.9, 0.88, 0.82), 0.6)
	var view_shader := load("res://shaders/window_view.gdshader")
	for side in [-1.0, 1.0]:
		for zc in [-1.4, -3.2]:
			var x: float = side * (W - 0.005)
			var glass := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(1.0, 0.9)
			var m := ShaderMaterial.new()
			m.shader = view_shader
			m.set_shader_parameter("seed", zc * side)
			m.set_shader_parameter("snow", season.snow)
			m.set_shader_parameter("autumn", maxf(season.autumn * season.leaves, season.grass_dry * 0.4))
			quad.material = m
			glass.mesh = quad
			glass.position = Vector3(x, 1.45, zc)
			glass.rotation.y = -side * PI / 2.0
			add_child(glass)
			# Karmit ja ristikko
			var inward: float = -side * 0.04
			for dz in [-0.52, 0.0, 0.52]:
				_box(Vector3(0.08, 1.04, 0.07), Vector3(x + inward, 1.45, zc + dz), frame)
			for dy in [-0.48, 0.0, 0.48]:
				_box(Vector3(0.08, 0.07, 1.1), Vector3(x + inward, 1.45 + dy, zc), frame)
			_box(Vector3(0.22, 0.05, 1.2), Vector3(x - side * 0.1, 0.98, zc), frame) # ikkunalauta


## Takka oikeassa takanurkassa: kivimuuraus, tulipesä, halot ja lepattava tuli
func _fireplace() -> void:
	var root := Node3D.new()
	root.position = Vector3(W - 0.75, 0, -D + 0.75)
	root.rotation.y = -PI / 4.0 # vinosti nurkassa: paikallinen +z (tulipesä) osoittaa huoneen keskelle
	add_child(root)
	var stone_tones := [Color(0.52, 0.5, 0.47), Color(0.45, 0.44, 0.42), Color(0.6, 0.57, 0.52), Color(0.4, 0.38, 0.36)]
	var stones := stone_tones.map(func(c): return _mat(c, 0.95))
	# Muuraus kivirivistöinä
	var y := 0.0
	var row := 0
	while y < 1.25:
		var h := _rng.randf_range(0.16, 0.22)
		var x := -0.75
		while x < 0.75:
			var w := minf(_rng.randf_range(0.22, 0.36), 0.75 - x)
			var opening := y < 0.75 and absf(x + w / 2.0) < 0.36 # tulipesän aukko
			var depth := 0.15 if opening else 0.62
			_box(Vector3(w - 0.015, h - 0.015, depth), Vector3(x + w / 2.0, y + h / 2.0, -0.31 + depth / 2.0 - 0.31 + 0.31), stones[(row + int(x * 7.0)) % stones.size()], root)
			x += w
		y += h
		row += 1
	# Hylly ja savupiippu kattoon
	_box(Vector3(1.7, 0.08, 0.72), Vector3(0, 1.29, 0.0), _mat(Color(0.32, 0.21, 0.12)), root)
	_box(Vector3(0.8, H - 1.33, 0.55), Vector3(0, 1.33 + (H - 1.33) / 2.0, -0.05), stones[1], root)
	# Tulipesän pohja, halot ja liekit
	_box(Vector3(0.7, 0.04, 0.45), Vector3(0, 0.02, 0.02), _mat(Color(0.08, 0.07, 0.06)), root)
	var wood := _mat(Color(0.35, 0.22, 0.12))
	for a in [-0.35, 0.35, 0.0]:
		var piece := _cyl(0.055, 0.5, Vector3(0, 0.09 + absf(a) * 0.05, 0.05), wood, root, 8)
		piece.rotation = Vector3(PI / 2.0, a, PI / 2.0)
	for k in 5:
		var flame := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = _rng.randf_range(0.05, 0.09)
		cone.height = _rng.randf_range(0.2, 0.36)
		cone.radial_segments = 6
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.albedo_color = Color(1.0, 0.55 + k * 0.06, 0.15)
		cone.material = fm
		flame.mesh = cone
		flame.position = Vector3(-0.2 + k * 0.1, 0.14 + cone.height / 2.0, 0.05 + (k % 2) * 0.05)
		root.add_child(flame)
		_flames.append(flame)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.68, 0.42)
	_fire_light.omni_range = 7.0
	_fire_light.light_energy = 2.5
	_fire_light.shadow_enabled = true
	_fire_light.position = Vector3(0, 0.45, 0.45)
	root.add_child(_fire_light)


func _chair(at: Vector3, facing: float, wood: Material) -> void:
	var chair := Node3D.new()
	chair.position = at
	chair.rotation.y = facing
	add_child(chair)
	_box(Vector3(0.44, 0.05, 0.42), Vector3(0, 0.46, 0), wood, chair)
	for x in [-0.19, 0.19]:
		for z in [-0.18, 0.18]:
			_box(Vector3(0.045, 0.46, 0.045), Vector3(x, 0.23, z), wood, chair)
		_box(Vector3(0.045, 0.5, 0.045), Vector3(x, 0.73, 0.18), wood, chair) # selkänoja
	for y in [0.68, 0.86]:
		_box(Vector3(0.42, 0.07, 0.03), Vector3(0, y, 0.19), wood, chair)


func _table_and_chairs() -> void:
	var wood := _mat(Color(0.5, 0.33, 0.18), 0.7)
	var dark := _mat(Color(0.38, 0.24, 0.13), 0.75)
	var cz := -2.5
	_box(Vector3(1.9, 0.07, 0.85), Vector3(0.2, 0.76, cz), wood) # pöytälevy
	for x in [-0.6, 1.0]:
		_box(Vector3(0.08, 0.72, 0.6), Vector3(x, 0.36, cz), dark) # pukkijalat
	_box(Vector3(1.5, 0.06, 0.06), Vector3(0.2, 0.18, cz), dark)
	for x in [-0.35, 0.75]:
		_chair(Vector3(x, 0, cz - 0.72), 0.0, dark)
		_chair(Vector3(x, 0, cz + 0.72), PI, dark)
	# Pöydällä: öljylamppu, kahvikupit ja leipäkori
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(1.0, 0.85, 0.55)
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.7, 0.35)
	glass.emission_energy_multiplier = 1.6
	_cyl(0.07, 0.04, Vector3(0.2, 0.815, cz), _mat(Color(0.25, 0.2, 0.12)), self, 12)
	_cyl(0.05, 0.16, Vector3(0.2, 0.915, cz), glass, self, 12)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.75, 0.45)
	lamp.light_energy = 0.9
	lamp.omni_range = 3.0
	lamp.position = Vector3(0.2, 1.0, cz)
	add_child(lamp)
	var cup := _mat(Color(0.9, 0.9, 0.86), 0.4)
	for p in [Vector3(-0.35, 0.83, cz - 0.22), Vector3(0.75, 0.83, cz + 0.2)]:
		_cyl(0.04, 0.08, p, cup, self, 10)
	_box(Vector3(0.3, 0.08, 0.2), Vector3(-0.15, 0.83, cz + 0.15), _mat(Color(0.6, 0.45, 0.25)))


## Vanha puukuorinen kuvaputki-TV lipaston päällä takaseinällä, pöydän takana
func _tv() -> void:
	var root := Node3D.new()
	root.position = Vector3(0.45, 0, -D + 0.3)
	root.rotation.y = -0.12 # hieman kameraa kohti
	add_child(root)
	var dresser := _mat(Color(0.36, 0.23, 0.13), 0.7)
	var dark := _mat(Color(0.27, 0.17, 0.1), 0.75)
	_box(Vector3(1.1, 0.6, 0.48), Vector3(0, 0.3, 0), dresser, root)
	_box(Vector3(1.14, 0.04, 0.52), Vector3(0, 0.62, 0), dark, root)
	for x in [-0.27, 0.27]: # laatikot ja vetimet
		_box(Vector3(0.5, 0.24, 0.02), Vector3(x, 0.38, 0.245), dark, root)
		_box(Vector3(0.1, 0.025, 0.03), Vector3(x, 0.42, 0.26), _mat(Color(0.75, 0.62, 0.35), 0.4), root)
	# TV: puujäljitelmäkuori, musta etupaneeli, kupera ruutu ja nupit oikealla
	var tv := Node3D.new()
	tv.position = Vector3(-0.05, 0.64, 0.0)
	root.add_child(tv)
	var shell := _mat(Color(0.42, 0.27, 0.15), 0.55)
	var black := _mat(Color(0.07, 0.07, 0.07), 0.6)
	_box(Vector3(0.84, 0.6, 0.44), Vector3(0, 0.3, -0.02), shell, tv)
	_box(Vector3(0.52, 0.42, 0.18), Vector3(0, 0.3, -0.3), black, tv) # kuvaputken takaosa
	_box(Vector3(0.78, 0.54, 0.02), Vector3(0, 0.3, 0.205), black, tv)
	tv_screen = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.58, 0.44)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/tv_fishing.gdshader")
	quad.material = m
	tv_screen.mesh = quad
	tv_screen.position = Vector3(-0.07, 0.3, 0.218)
	tv.add_child(tv_screen)
	var knob := _mat(Color(0.8, 0.78, 0.72), 0.35)
	for k in 2:
		var kn := _cyl(0.03, 0.03, Vector3(0.3, 0.42 - k * 0.12, 0.22), knob, tv, 12)
		kn.rotation.x = PI / 2.0
	_box(Vector3(0.08, 0.1, 0.01), Vector3(0.3, 0.14, 0.218), _mat(Color(0.2, 0.2, 0.2), 0.9), tv) # kaiutinsäleikkö
	var led := StandardMaterial3D.new()
	led.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	led.albedo_color = Color(1.0, 0.15, 0.1)
	_box(Vector3(0.015, 0.015, 0.01), Vector3(0.3, 0.06, 0.218), led, tv)
	# Sisäantenni ("pupunkorvat")
	var metal := _mat(Color(0.7, 0.7, 0.72), 0.3)
	_cyl(0.05, 0.03, Vector3(0.1, 0.615, -0.05), black, tv, 12)
	for side in [-1.0, 1.0]:
		var ear := _cyl(0.004, 0.55, Vector3(0.1 + side * 0.12, 0.84, -0.05), metal, tv, 6)
		ear.rotation.z = -side * 0.45
	# Ruudun hohde valaisee pöytää ja seinää sinertävästi
	_tv_light = OmniLight3D.new()
	_tv_light.light_color = Color(0.65, 0.75, 1.0)
	_tv_light.omni_range = 3.0
	_tv_light.light_energy = 0.5
	_tv_light.position = Vector3(-0.07, 0.3, 0.5)
	tv.add_child(_tv_light)


func _details() -> void:
	# Räsymatto pöydän alle
	var stripes := [Color(0.55, 0.15, 0.12), Color(0.82, 0.78, 0.66), Color(0.2, 0.3, 0.5), Color(0.82, 0.78, 0.66)]
	for k in 12:
		_box(Vector3(2.4, 0.012, 0.16), Vector3(0.2, 0.006, -3.4 + k * 0.165), _mat(stripes[k % stripes.size()], 1.0))
	# Virvelit seinällä vasemmalla ja lippalakki naulakossa
	var rod := _mat(Color(0.1, 0.1, 0.12), 0.4)
	for k in 2:
		var r := _cyl(0.008, 2.0, Vector3(-W + 0.16, 1.75 + k * 0.18, -2.3), rod, self, 6)
		r.rotation.x = PI / 2.0
	for z in [-3.2, -1.4]:
		_box(Vector3(0.12, 0.06, 0.04), Vector3(-W + 0.08, 1.7, z), _mat(Color(0.3, 0.2, 0.12)))
	# Puulaatikko takan viereen
	var box_mat := _mat(Color(0.42, 0.28, 0.15))
	_box(Vector3(0.5, 0.4, 0.4), Vector3(W - 0.4, 0.2, -D + 1.9), box_mat)
	for k in 4:
		var piece := _cyl(0.05, 0.42, Vector3(W - 0.52 + (k % 2) * 0.22, 0.44 + (k / 2) * 0.09, -D + 1.9), _mat(Color(0.45, 0.32, 0.2)), self, 8)
		piece.rotation.z = PI / 2.0


func _process(delta: float) -> void:
	_time += delta
	# Tuli lepattaa: valon voimakkuus ja liekkien korkeus vaihtelevat
	var flicker := 0.75 + 0.15 * sin(_time * 11.0) + 0.1 * sin(_time * 23.7 + 1.3) + _rng.randf_range(-0.06, 0.06)
	_fire_light.light_energy = 1.5 * flicker
	for i in _flames.size():
		var f := _flames[i]
		f.scale.y = 0.8 + 0.3 * sin(_time * (9.0 + i * 1.7) + i)
		f.scale.x = 1.0 + 0.1 * sin(_time * 13.0 + i * 2.0)
	# TV:n valo elää kuvan mukana; leikkauksissa (8 s välein) välähtää
	(tv_screen.mesh.material as ShaderMaterial).set_shader_parameter("time", _time)
	var since_cut := fmod(_time, 8.0)
	_tv_light.light_energy = 0.45 + 0.08 * sin(_time * 1.7) + 0.04 * sin(_time * 7.3) + (0.4 if since_cut < 0.15 else 0.0)

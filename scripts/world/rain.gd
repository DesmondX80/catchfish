class_name Rain
extends GPUParticles3D
## Sadepisarat kameran ympärillä. Pisarat ovat ohuita viiruja, jotka
## kallistuvat tuulen mukana; määrä seuraa sateen voimakkuutta.
## Lumisateella (todellinen sää) hiutaleet leijuvat hitaasti.

const AREA := 26.0 # m, sadealueen leveys kameran ympärillä
const HEIGHT := 16.0
const FALL_SPEED := 9.0 # m/s, sadepisaran putoamisnopeus

var weather: Weather
var camera: Camera3D
var _process_mat: ParticleProcessMaterial
var _rain_mesh: Mesh
var _snow_mesh: Mesh
var _snowing := false


func setup(weather_node: Weather, cam: Camera3D) -> void:
	weather = weather_node
	camera = cam
	amount = 7000
	lifetime = HEIGHT / FALL_SPEED * 1.15
	local_coords = false # pisarat eivät liiku kameran mukana
	visibility_aabb = AABB(Vector3(-AREA, -HEIGHT * 1.5, -AREA), Vector3(AREA * 2, HEIGHT * 3, AREA * 2))
	_process_mat = ParticleProcessMaterial.new()
	_process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_process_mat.emission_box_extents = Vector3(AREA, 0.5, AREA)
	_process_mat.gravity = Vector3.ZERO
	_process_mat.initial_velocity_min = FALL_SPEED * 0.9
	_process_mat.initial_velocity_max = FALL_SPEED * 1.1
	_process_mat.spread = 2.0
	_process_mat.particle_flag_align_y = true # viiru osoittaa liikkeen suuntaan
	process_material = _process_mat
	_rain_mesh = _streak_mesh()
	_snow_mesh = _flake_mesh()
	draw_pass_1 = _rain_mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitting = false


## Kaksi ristikkäistä kapeaa nelikulmiota: viiru näkyy joka suunnasta
func _streak_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.008
	var h := 0.45
	for axis in [Vector3.RIGHT, Vector3.BACK]:
		var a: Vector3 = axis * w
		var quad := [-a + Vector3(0, -h, 0), a + Vector3(0, -h, 0), a + Vector3(0, h, 0), -a + Vector3(0, h, 0)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color(1, 1, 1, 0.0 if quad[i].y > 0.0 else 1.0)) # häivytys yläpäähän
			st.add_vertex(quad[i])
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.78, 0.82, 0.88, 0.35)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	return st.commit()


## Lumihiutale: pieni valkoinen neliö, aina kameraan päin
func _flake_mesh() -> Mesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.035)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.95, 0.96, 1.0, 0.85)
	q.material = mat
	return q


func _set_snow(on: bool) -> void:
	_snowing = on
	draw_pass_1 = _snow_mesh if on else _rain_mesh
	var speed := 1.3 if on else FALL_SPEED
	_process_mat.initial_velocity_min = speed * 0.8
	_process_mat.initial_velocity_max = speed * 1.2
	_process_mat.spread = 25.0 if on else 2.0 # hiutaleet leijailevat
	_process_mat.particle_flag_align_y = not on
	lifetime = HEIGHT / speed * 1.15


func _process(_delta: float) -> void:
	if weather == null or camera == null:
		return
	if weather.snow != _snowing:
		_set_snow(weather.snow)
	var r := weather.rain
	emitting = r > 0.02
	amount_ratio = clampf(r, 0.05, 1.0)
	global_position = camera.global_position + Vector3(0, HEIGHT * 0.6, 0)
	# Tuuli kallistaa sadetta
	var wind := weather.vector()
	var fall := 1.3 if _snowing else FALL_SPEED
	_process_mat.direction = Vector3(wind.x / fall, -1.0, wind.y / fall).normalized()

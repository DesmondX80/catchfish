class_name FishPicture
extends SubViewportContainer
## Saadun kalan kuva saalisikkunaan: kalan 3D-malli omassa pienessä
## maailmassaan, kääntyilee hitaasti kyljeltä toiselle.

var _viewport: SubViewport
var _fish: MeshInstance3D
var _time := 0.0


func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(420, 190)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.8)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)
	var light := DirectionalLight3D.new()
	light.light_energy = 1.3
	light.rotation = Vector3(-0.9, 0.6, 0.0)
	_viewport.add_child(light)
	var cam := Camera3D.new()
	cam.fov = 32.0
	cam.position = Vector3(1.15, 0.08, 0.0)
	_viewport.add_child(cam)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	_fish = MeshInstance3D.new()
	_viewport.add_child(_fish)


## Näyttää lajin kalan (malli skaalataan kuvaan, oikea koko näkyy tekstissä)
func show_species(sp: String) -> void:
	_fish.mesh = FishModels.mesh(sp)
	var mat: ShaderMaterial = FishModels.material(sp).duplicate()
	mat.set_shader_parameter("swim_rate", 1.2)
	_fish.material_override = mat
	_time = 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_fish.position = Vector3(0, 0.02, 0)
	_fish.rotation = Vector3(0.0, sin(_time * 0.6) * 0.45, sin(_time * 1.1) * 0.06)

class_name CameraRig
extends Node3D
## Kolmannen persoonan kamera veneen takana. Hiiri kääntää kameraa, ja
## kameran katsesuunta on myös heittosuunta.

var boat: Boat
var lake: LakeData
var camera: Camera3D
var yaw := 0.0
var pitch := 0.32
var distance := 8.0


func setup(target: Boat, lake_data: LakeData) -> void:
	boat = target
	lake = lake_data
	yaw = boat.yaw
	camera = Camera3D.new()
	camera.fov = 65.0
	camera.near = 0.1
	camera.far = 4000.0
	add_child(camera)
	camera.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and GameInput.active():
		yaw -= event.relative.x * 0.0035
		pitch = clampf(pitch + event.relative.y * 0.0035, -0.15, 1.3)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(3.0, distance * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(40.0, distance * 1.1)


## Vaakasuora suunta, johon kamera katsoo (heittosuunta)
func aim_direction() -> Vector2:
	return Vector2(-sin(yaw), -cos(yaw))


func _process(_delta: float) -> void:
	var target := boat.global_position + Vector3(0, 1.5, 0)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	var cam_pos := target + offset
	var ground := maxf(lake.height_at(cam_pos.x, cam_pos.z), 0.0)
	cam_pos.y = maxf(cam_pos.y, ground + 0.5)
	camera.global_position = cam_pos
	camera.look_at(target + Vector3(-sin(yaw), 0, -cos(yaw)) * 2.0, Vector3.UP)

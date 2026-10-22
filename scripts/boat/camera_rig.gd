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
var tub: CatchTub
## Avattu kalapakki: kamera katsoo pakkia ylhäältä
var box: TackleBox
var _box_blend := 0.0
const BOBBER_DISTANCE := 2.2 # m kohosta veneen suuntaan
const BOBBER_HEIGHT := 0.9 # m vedenpinnan yläpuolella
## Tab: kamera katsoo kalasaavia ylhäältä
var tub_view := false
var _tub_blend := 0.0
## Onkiessa kamera katsoo kohoa läheltä veneen suunnasta
var bobber_view := false
var bobber_pos := Vector3.ZERO
var _bobber_blend := 0.0
var _bobber_eye := Vector3.ZERO
## Haavinnan kamerakuva (LandingNet.camera_shot)
var shot := Transform3D.IDENTITY
var shot_view := false
var _shot_blend := 0.0


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
		var look: Vector2 = event.relative * Settings.mouse_look_scale() * 0.0035
		yaw -= look.x
		pitch = clampf(pitch + look.y, -0.15, 1.3)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(3.0, distance * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(40.0, distance * 1.1)


## Vaakasuora suunta, johon kamera katsoo (heittosuunta)
func aim_direction() -> Vector2:
	return Vector2(-sin(yaw), -cos(yaw))


func _process(delta: float) -> void:
	var target := boat.global_position + Vector3(0, 1.5, 0)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	var cam_pos := target + offset
	var ground := maxf(lake.height_at(cam_pos.x, cam_pos.z), 0.0)
	cam_pos.y = maxf(cam_pos.y, ground + 0.5)
	camera.global_position = cam_pos
	camera.look_at(target + Vector3(-sin(yaw), 0, -cos(yaw)) * 2.0, Vector3.UP)
	_bobber_blend = move_toward(_bobber_blend, 1.0 if bobber_view else 0.0, delta * 1.5)
	if _bobber_blend > 0.0:
		var to_boat := Vector3(boat.global_position.x - bobber_pos.x, 0, boat.global_position.z - bobber_pos.z)
		var back := to_boat.normalized() if to_boat.length() > 0.5 else Vector3(sin(yaw), 0, cos(yaw))
		var eye := bobber_pos + back * BOBBER_DISTANCE + Vector3(0, BOBBER_HEIGHT, 0)
		# Kamera seuraa kohoa pehmeästi (koho nykii ja liikkuu kelatessa)
		_bobber_eye = eye if _bobber_eye == Vector3.ZERO else _bobber_eye.lerp(eye, minf(1.0, delta * 3.0))
		var close := Transform3D(Basis.looking_at(bobber_pos + Vector3(0, 0.05, 0) - _bobber_eye), _bobber_eye)
		camera.global_transform = camera.global_transform.interpolate_with(close, smoothstep(0.0, 1.0, _bobber_blend))
	else:
		_bobber_eye = Vector3.ZERO
	_tub_blend = move_toward(_tub_blend, 1.0 if tub_view and tub != null else 0.0, delta * 3.0)
	if _tub_blend > 0.0 and tub != null:
		# Saavin yläpuolelta suoraan alas, kuva veneen suuntaisesti (keula ylhäällä).
		# Kamera on perämoottorin ohjausaisan alapuolella, ja saavi on ruudun
		# vasemmalla puolella, koska painot näkyvät oikealla.
		var bow := Vector3(-sin(boat.yaw), 0, -cos(boat.yaw))
		var right := Vector3(cos(boat.yaw), 0, -sin(boat.yaw))
		var center := tub.view_point()
		var above := Transform3D(Basis.looking_at(Vector3.DOWN, bow), center + Vector3(0, 0.65, 0) + right * 0.25)
		camera.global_transform = camera.global_transform.interpolate_with(above, smoothstep(0.0, 1.0, _tub_blend))
	_box_blend = move_toward(_box_blend, 1.0 if box != null and box.is_open else 0.0, delta * 3.0)
	if _box_blend > 0.0 and box != null:
		camera.global_transform = camera.global_transform.interpolate_with(box.view_transform(), smoothstep(0.0, 1.0, _box_blend))
	_shot_blend = move_toward(_shot_blend, 1.0 if shot_view else 0.0, delta * 2.5)
	if _shot_blend > 0.0:
		camera.global_transform = camera.global_transform.interpolate_with(shot, smoothstep(0.0, 1.0, _shot_blend))

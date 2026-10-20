extends Node
## Kalastajahahmon testi: godot --headless --fixed-fps 30 -- --day=180 --anglertest
## Kesä- ja talvivaatetus vaihtuvat, katse seuraa heitettyä uistinta, moottoriajossa
## kalastaja katsoo menosuuntaan, soutaja vilkaisee olan yli ja silmät räpyttelevät.

var main: Node
var _log: Array[String] = []
var _step := 0
var _t := 0.0
var _blinked := false
var _glanced := false
var _lure_angle := INF
var _body_off := 0.0


func _ready() -> void:
	main = get_parent()
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	for f in main.population.fish:
		f["wary"] = 1.0e9 # ei tärppejä
	var boat: Boat = main.boat
	boat.pos += boat.forward() * 30.0 # avovedelle
	boat.velocity = Vector2.ZERO
	var a: Angler = boat.angler
	_check("kesällä kelluntaliivi ja lippis", a._vest.visible and a._cap.visible and not a._beanie.visible)
	boat.set_on_ice(true)
	_check("talvella pipo ja haalari, ei liiviä", a._beanie.visible and not a._vest.visible and not a._cap.visible and a._jacket_parts[0].material_override == a._winter_suit)
	boat.set_on_ice(false)
	_check("takaisin kesävaatteisiin", a._vest.visible and a._jacket_parts[0].material_override == a._camo)


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _next() -> void:
	_step += 1
	_t = 0.0


## Pään katsesuunnan ja kohteen suunnan välinen kulma vaakatasossa
func _head_angle_to(target: Vector3) -> float:
	var head: Node3D = main.boat.angler._head
	var fwd := -head.global_basis.z
	var to := target - head.global_position
	return absf(Vector2(fwd.x, fwd.z).angle_to(Vector2(to.x, to.z)))


func _physics_process(delta: float) -> void:
	_t += delta
	var boat: Boat = main.boat
	var a: Angler = boat.angler
	var fishing: Fishing = main.fishing
	if a._eyes[0].scale.y < 0.5:
		_blinked = true
	match _step:
		0:
			# Heitto sivulle: vartalo kääntyy heittosuuntaan, pää seuraa uistinta
			main.camera_rig.yaw = boat.yaw + 0.9
			fishing.power = 0.7
			fishing._cast()
			_next()
		1:
			# Uistimen lennettyä kamera (ja vartalo) kääntyy 0,7 rad sivuun: pään on käännyttävä takaisin
			if _t > 1.5:
				main.camera_rig.yaw = boat.yaw + 0.2
			if fishing.state == Fishing.State.RETRIEVING and _t > 2.8:
				var lure := Vector3(fishing.lure_pos.x, 0.0, fishing.lure_pos.z)
				_lure_angle = _head_angle_to(lure)
				var torso_fwd := -a.torso.global_basis.z
				var to := lure - a.torso.global_position
				_body_off = absf(Vector2(torso_fwd.x, torso_fwd.z).angle_to(Vector2(to.x, to.z)))
			if _t > 3.0:
				_check("vartalo käännetty pois uistimesta (%.2f rad)" % _body_off, _body_off > 0.4)
				_check("katse silti uistimessa (poikkeama %.2f rad)" % _lure_angle, _lure_angle < 0.15)
				fishing.state = Fishing.State.READY
				boat.motor_running = true
				boat.throttle = 0.5
				_next()
		2:
			if _t > 3.0:
				var ahead := boat.global_position + Vector3(boat.forward().x, 0, boat.forward().y) * 25.0
				var angle := _head_angle_to(ahead)
				_check("moottoriajossa katse menosuuntaan (poikkeama %.2f rad)" % angle, angle < 0.15)
				boat.motor_running = false
				boat.throttle = 0.0
				Input.action_press("boat_forward")
				_next()
		3:
			# Soutaja istuu selkä keulaan: vilkaisu olan yli kääntää pään yli 0,8 rad
			if absf(a._head.rotation.y) > 0.8:
				_glanced = true
			if _t > 9.0:
				Input.action_release("boat_forward")
				_check("soutaja vilkaisee olan yli", _glanced)
				_check("silmät räpyttelevät", _blinked)
				_finish()


func _finish() -> void:
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

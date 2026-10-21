extends Node
## Kalastajahahmon testi:
##   godot --headless --fixed-fps 30 -- --day=180 --anglertest   (kesä: vene)
##   godot --headless --fixed-fps 30 -- --day=40 --anglertest    (talvi: jää)
## Kesällä kalastaja istuu veneessä: kädet ylettyvät vapaan, airoihin ja
## ohjausaisaan, jalkapohjat ovat pohjalaudoilla ja päässä on lippalakki.
## Talvella päällä on pilkkihaalari ja pipo, ja kalastaja kävelee jäällä.

const HAND_REACH := 0.08 # kämmenen etäisyys kohteesta enintään (m)

var main: Node
var _log: Array[String] = []
var _step := 0
var _t := 0.0


func _ready() -> void:
	main = get_parent()
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	for f in main.population.fish:
		f["wary"] = 1.0e9 # ei tärppejä


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _press(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _next() -> void:
	_step += 1
	_t = 0.0


func _angler() -> Angler:
	return main.boat.angler


## Otteen kohta (keskisormen rystynen) maailmassa: s = 1 oikea, -1 vasen
func _palm(s: float) -> Vector3:
	var a := _angler()
	return a.posed_position("Middle1.R" if s > 0.0 else "Middle1.L")


## Kummankin käden etäisyys kohteestaan
func _hand_errors() -> Array:
	var a := _angler()
	var targets := a._hand_targets()
	return [_palm(1.0).distance_to(targets[0]), _palm(-1.0).distance_to(targets[1])]


func _check_hands(name: String) -> void:
	var e := _hand_errors()
	_check("%s: kädet kohteissa (oikea %.2f m, vasen %.2f m)" % [name, e[0], e[1]], e[0] < HAND_REACH and e[1] < HAND_REACH)


func _physics_process(delta: float) -> void:
	_t += delta
	var boat: Boat = main.boat
	var a := _angler()
	if boat.on_ice:
		_winter_steps()
		return
	match _step:
		0:
			if _t > 1.5:
				_check("malli ladattu: luuranko ja %d luuta" % a._skel.get_bone_count(), a._skel != null and a._skel.get_bone_count() > 50)
				_check("kesä: lippalakki päässä, pipo ja hihat piilossa", a._cap.visible and not a._beanie.visible and not a._sleeves[0].visible)
				_check("kalastusasento", a.pose == Angler.Pose.FISHING)
				_check_hands("vapa kädessä")
				# Jalkapohjat pohjalaudoilla (veneen pohja 0,14 m vesirajan alla)
				var foot_y := a.posed_position("Foot.L").y - boat.hull.global_position.y
				_check("istuu: jalkapohjat veneen pohjalla (%.2f m)" % foot_y, foot_y > -0.2 and foot_y < -0.05)
				var hip_y := a.posed_position("Hips").y - boat.hull.global_position.y
				_check("istuu: lantio tuhdon tasolla (%.2f m)" % hip_y, hip_y > 0.2 and hip_y < 0.45)
				_press("boat_forward", true)
				_next()
		1:
			if _t > 3.0:
				_check("soutuasento", a.pose == Angler.Pose.ROWING)
				_check_hands("airot")
				_press("boat_forward", false)
				boat.motor_running = true
				boat.throttle = 0.0
				_next()
		2:
			if _t > 2.0:
				_check("moottoriasento", a.pose == Angler.Pose.MOTOR)
				var e := _hand_errors()
				_check("oikea käsi ohjausaisalla (%.2f m)" % e[0], e[0] < HAND_REACH)
				_finish()


func _winter_steps() -> void:
	var a := _angler()
	match _step:
		0:
			if _t > 1.5:
				_check("talvi: pipo päässä, lippalakki piilossa", a._beanie.visible and not a._cap.visible)
				_check("talvi: haalarin hihat", a._sleeves[0].visible and a._sleeves[1].visible)
				var top: StandardMaterial3D = a._materials["Green"][0]
				_check("talvi: pilkkihaalarin väri", top.albedo_color.is_equal_approx(Angler.WINTER_COLORS["Green"]))
				_check("seisoo jäällä", a.pose == Angler.Pose.ICE_STAND)
				var feet: float = a.posed_position("Foot.L").y - main.boat.global_position.y
				_check("jalat jäällä (%.2f m)" % feet, absf(feet) < 0.12)
				_press("boat_forward", true)
				_next()
		1:
			if _t > 1.5:
				_check("kävelyanimaatio", a._anim.current_animation.ends_with("Walk"))
				_press("boat_forward", false)
				_press("cast", true) # kairaus
				_next()
		2:
			if _t > 1.0:
				_check("kairausasento", a.pose == Angler.Pose.ICE_DRILL)
				# Kampi kiertää kairan ympäri: kaukaisella puolella käsi ei aivan yllä
				var e := _hand_errors()
				_check("kairan kahvat: nuppi (%.2f m) ja kampi (%.2f m)" % [e[0], e[1]], minf(e[0], e[1]) < HAND_REACH and maxf(e[0], e[1]) < 0.3)
				_finish()


func _finish() -> void:
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

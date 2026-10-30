extends Node
## Ankkurin testi: godot --headless --fixed-fps 30 -- --day=180 --anchortest [--anchortest-shots=KANSIO]
## Ankkuri lasketaan keulasta ja vajoaa pohjaan (vasta silloin vene on
## ankkurissa), köysi on löysä veneen ollessa lähellä ja kiristyy, kun veneellä
## yritetään lähteä, tuulessa vene kääntyy keula ankkuria kohti, ja nostettu
## ankkuri päätyy veneeseen. Kalastaja käsittelee köyttä etutuhdolla.
## Köyttä on syvyys + 0,5 m eikä sitä tule lisää ajettaessa, lasku ja nosto
## etenevät 1 m/s, ja liikkuvasta veneestä laskettu ankkuri kulkee keulan alla.
## Köyttä käsitellessä ei voi ajaa eikä soutaa, X vie kaasun vapaalle, ja
## nostossa köysi ei veny: väli on joka ruudulla enintään ulkona olevan köyden
## mittainen, myös vene täydeltä kaasulta tai 5 m/s liu'ussa. Liu'ussa ankkuri
## pysyy keulan takana rungon pohjan alla ja nousee vasta veneen hidastuttua, ja
## köysi kulkee keulavantaa pitkin eikä rungon läpi, myös vauhdissa perutussa laskussa.

var main: Node
var _log: Array[String] = []
var _messages: Array[String] = []
var _step := 0
var _t := 0.0
var _spot := Vector2.ZERO
var _depth := 0.0
var _shots := ""
var _saw_anchor_pose := false
var _max_over := -INF # nostossa suurin (väli - ulkona oleva köysi)
var _dragged := false # ankkuri lähti nostossa veneen perään
var _still := true # vene pysyi paikallaan, vaikka W oli pohjassa
var _max_keel := -INF # keulan takana renkaan suurin korkeus rungon koordinaateissa
var _rope_in_hull := false # näkyvä köysi kulki rungon sisällä
var _start := Vector2.ZERO


func _ready() -> void:
	main = get_parent()
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--anchortest-shots="):
			_shots = arg.split("=")[1]
	main.boat.message.connect(func(text): _messages.append(text))
	_find_spot()


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _next() -> void:
	_step += 1
	_t = 0.0


func _shot(name: String) -> void:
	if _shots != "":
		get_viewport().get_texture().get_image().save_png(_shots.path_join(name + ".png"))


## Avovettä joka suuntaan, syvyys 2,5–4 m
func _find_spot() -> void:
	var lake: LakeData = main.lake
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var size := lake.world_size()
	for i in 20000:
		var p := Vector2(lake.origin_x + rng.randf() * size.x, lake.origin_z + rng.randf() * size.y)
		var d := lake.depth_at(p.x, p.y)
		if d < 2.5 or d > 4.0:
			continue
		var ok := true
		for a in 8:
			var q := p + Vector2.from_angle(a * TAU / 8.0) * 40.0
			ok = ok and lake.depth_at(q.x, q.y) > 1.5
		if ok:
			_spot = p
			_depth = d
			return


func _calm() -> void:
	var w: Weather = main.weather
	w.wind_base = 0.0
	w.gust = 0.0
	w._wind_target = 0.0
	w._gust_timer = 999.0


func _physics_process(delta: float) -> void:
	_t += delta
	var boat: Boat = main.boat
	var anchor: BoatAnchor = boat.anchor
	_saw_anchor_pose = _saw_anchor_pose or boat.angler.pose == Angler.Pose.ANCHOR
	if anchor.state == BoatAnchor.State.RAISING:
		_max_over = maxf(_max_over, anchor.bow_chock().distance_to(anchor.ring()) - anchor.rope_out)
		_track_hull(boat, anchor)
	match _step:
		0:
			_calm()
			boat.pos = _spot
			boat.velocity = Vector2.ZERO
			boat.yaw_rate = 0.0
			if _t > 0.5:
				boat.toggle_anchor()
				_check("ankkuri lasketaan, vene ei vielä ankkurissa", anchor.state == BoatAnchor.State.LOWERING and not boat.anchored)
				_next()
		1:
			_calm()
			boat.velocity = Vector2.ZERO
			if _t > 1.0 and _t < 1.1:
				_shot("ankkuri-1-laskee")
			if boat.anchored:
				var bottom: float = main.lake.depth_at(anchor.xz.x, anchor.xz.y)
				var bow := anchor.bow_chock()
				_check("ankkuri vajosi pohjaan (%.1f s, ankkuri %.2f m, pohja %.2f m)" % [_t, -anchor.height, bottom], absf(-anchor.height - bottom) < 0.15 and _t > 1.0)
				_check("ankkuri laskettiin keulasta (%.1f m keulasta)" % Vector2(anchor.xz.x - bow.x, anchor.xz.y - bow.z).length(), Vector2(anchor.xz.x - bow.x, anchor.xz.y - bow.z).length() < 1.5)
				_check("kalastaja laski ankkurin etutuhdolla", _saw_anchor_pose)
				_check("köysi näkyy", anchor._rope[0].visible)
				_check("ankkuri ei näy veden alla", not anchor._anchor.visible)
				_check("köysi ei näy veden alla", anchor._rope.all(func(seg): return not seg.visible or seg.global_position.y > anchor._water_level() - 0.05))
				_check("ilmoitus: ankkuri pohjassa", _messages.any(func(m): return m.begins_with("Ankkuri pohjassa")))
				_check("lasku 1 m/s (%.1f s, syvyys %.1f m)" % [_t, bottom], _t > bottom and _t < bottom + 1.5)
				_check("köyttä syvyys + 0,5 m (%.2f m)" % boat.anchor_rope, absf(boat.anchor_rope - (bottom + 0.5)) < 0.1)
				_next()
			elif _t > 15.0:
				_check("ankkuri vajosi pohjaan", false)
				_finish()
		2:
			_calm()
			if _t > 1.0:
				_check("veneen ollessa lähellä köysi on löysä", not anchor.taut())
				_shot("ankkuri-2-loysa")
				boat.motor_running = true
				boat.throttle = 1.0
				_next()
		3:
			# Yritetään ajaa pois ankkuri pohjassa
			_calm()
			Input.action_press("boat_forward")
			if _t > 8.0:
				Input.action_release("boat_forward")
				var bow := anchor.bow_chock()
				var away := Vector2(bow.x - anchor.xz.x, bow.z - anchor.xz.y).length()
				_check("köysi kiristyi ja piti veneen (%.1f m ankkurista, köyttä %.1f m)" % [away, boat.anchor_rope], anchor.taut() and away < boat.anchor_rope + 0.5)
				_check("ajaessa köyttä ei tullut lisää (keula %.2f m ankkurista, ulottuma %.2f m)" % [away, boat.anchor_reach()], away <= boat.anchor_reach() + 0.2 and absf(boat.anchor_rope - (_depth_at_anchor() + 0.5)) < 0.1)
				_check("ilmoitus: köysi kiristyy, nosta ensin ankkuri", _messages.any(func(m): return m.begins_with("Ankkuriköysi kiristyy")))
				_check("kalastaja huusi: Perkele, ankkuri!", main.voice.last_line == "anchor")
				_shot("ankkuri-3-kirea")
				boat.motor_running = false
				boat.throttle = 0.0
				var w: Weather = main.weather
				w.wind_base = 6.0
				w._wind_target = 6.0
				w.wind_direction = boat.yaw + PI / 2.0 # sivutuuli
				_next()
		4:
			# Tuulessa vene kääntyy keula ankkuria kohti
			main.weather.wind_base = 6.0
			if _t > 40.0:
				var bow := anchor.bow_chock()
				var to_anchor := Vector2(anchor.xz.x - bow.x, anchor.xz.y - bow.z).normalized()
				var angle := rad_to_deg(acos(clampf(boat.forward().dot(to_anchor), -1.0, 1.0)))
				_check("tuulessa keula kääntyi ankkuria kohti (%.0f°)" % angle, angle < 35.0)
				_calm()
				boat.velocity = Vector2.ZERO
				boat.toggle_anchor()
				_check("nostettaessa vene irtoaa heti", not boat.anchored and anchor.state == BoatAnchor.State.RAISING)
				_next()
		5:
			_calm()
			if _t > 2.0 and _t < 2.1:
				_shot("ankkuri-4-nostaa")
			if anchor.state == BoatAnchor.State.STOWED:
				_check("ankkuri nostettiin veneeseen (%.1f s)" % _t, _messages.any(func(m): return m.begins_with("Ankkuri nostettu")))
				_check("nosto noin 1 m/s (%.1f s, syvyys %.1f m)" % [_t, _depth_at_anchor()], _t > _depth_at_anchor() * 0.8 and _t < _depth_at_anchor() + 3.0)
				_check("köysi ei näy nostetulla ankkurilla", not anchor._rope[0].visible)
				_next()
			elif _t > 30.0:
				_check("ankkuri nostettiin veneeseen", false)
				_finish()
		6:
			if _t > 1.0:
				_check("kalastaja palasi kalastamaan", boat.angler.pose == Angler.Pose.FISHING)
				_calm()
				boat.toggle_anchor()
				_next()
		7:
			# Ankkuri lasketaan liikkuvasta veneestä: se kulkee keulan alla
			_calm()
			boat.velocity = boat.forward() * 1.5
			if _t > 1.2:
				var bow := anchor.bow_chock()
				var off := Vector2(anchor.xz.x - bow.x, anchor.xz.y - bow.z).length()
				_check("liikkuvasta veneestä laskettu ankkuri keulan alla (%.2f m)" % off, anchor.state != BoatAnchor.State.STOWED and off < 0.5)
				boat.velocity = Vector2.ZERO
				boat.motor_running = true
				_messages.clear()
				_next()
		8:
			# Ajoyritys ankkuria laskiessa: kädet köydellä
			_calm()
			Input.action_press("boat_forward")
			if _t > 0.5:
				Input.action_release("boat_forward")
				_check("W laskussa ei nosta kaasua (%.2f)" % boat.throttle, anchor.state == BoatAnchor.State.LOWERING and boat.throttle == 0.0)
				_check("laskussa ilmoitus kädet köydellä kerran", _count("Kädet ankkurin köydellä – odota, että ankkuri on pohjassa") == 1)
				_next()
		9:
			_calm()
			if boat.anchored:
				boat.throttle = 1.0
				_next()
			elif _t > 15.0:
				_check("ankkuri vajosi pohjaan", false)
				_finish()
		10:
			# Täysi kaasu ankkuri pohjassa, W yhä pohjassa, kun X painetaan
			_calm()
			_side_camera()
			Input.action_press("boat_forward")
			if _t > 3.0:
				_messages.clear()
				_reset_tracking()
				boat.tiller = 0.5
				boat.toggle_anchor()
				_check("X vie kaasun vapaalle ja aisan keskelle", boat.throttle == 0.0 and boat.tiller == 0.0)
				_check("moottori jää käymään", boat.motor_running)
				_next()
		11:
			# Pohjassa pysynyt W ei peitä kaasun ilmoitusta, uusi painallus antaa ilmoituksen
			_calm()
			_side_camera()
			if _t < 0.5:
				Input.action_press("boat_forward")
			elif _t < 0.7:
				Input.action_release("boat_forward")
			else:
				Input.action_press("boat_forward")
			if _t > 1.0 and _t < 1.1:
				_shot("ankkuri-5-nosto-kaasulla")
			if _t > 1.5:
				Input.action_release("boat_forward")
				_check("ilmoitus: kaasu vapaalle, ankkuria nostetaan", _messages.size() > 0 and _messages[0] == "Kaasu vapaalle – ankkuria nostetaan...")
				_check("pohjassa pysynyt W ei tuonut ilmoitusta heti, uusi painallus toi kerran", _messages.size() == 2 and _count("Kädet ankkurin köydellä – odota, että ankkuri on veneessä") == 1)
				_check("W nostossa ei muuta kaasua (%.2f)" % boat.throttle, boat.throttle == 0.0)
				_next()
		12:
			_calm()
			if anchor.state == BoatAnchor.State.STOWED:
				var total := _t + 1.5
				_check("nosto kaasulta: köysi ei venynyt (yli %.2f m)" % _max_over, _max_over <= 0.1)
				_check_hull("nosto kaasulta")
				_check("nosto kaasulta syvyys + enintään 3 s (%.1f s, syvyys %.1f m)" % [total, _depth_at_anchor()], total < _depth_at_anchor() + 3.0)
				Input.action_press("boat_forward")
				_next()
			elif _t > 30.0:
				_check("ankkuri nostettiin veneeseen", false)
				_finish()
		13:
			_calm()
			if _t > 0.5:
				Input.action_release("boat_forward")
				_check("ankkurin tultua W nostaa kaasun (%.2f)" % boat.throttle, boat.throttle > 0.2)
				boat.throttle = 0.0
				boat.velocity = Vector2.ZERO
				boat.yaw_rate = 0.0
				boat.pos = _spot
				boat.toggle_anchor()
				_next()
		14:
			_calm()
			_side_camera()
			boat.velocity = Vector2.ZERO
			if boat.anchored:
				_reset_tracking()
				_start = anchor.xz
				boat.toggle_anchor()
				boat.velocity = boat.forward() * 5.0
				_next()
			elif _t > 15.0:
				_check("ankkuri vajosi pohjaan", false)
				_finish()
		15:
			# Vene liukuu 5 m/s, kun X painetaan: ankkuri laahautuu perässä
			_calm()
			_side_camera()
			if _t > 1.0 and _t < 1.1:
				_shot("ankkuri-6-nosto-liussa")
			if anchor.state == BoatAnchor.State.RAISING and anchor.xz.distance_to(_start) > 0.5:
				_dragged = true
			if _t < delta * 1.5:
				_check("liu'ussa vene irtoaa heti (%.1f m/s)" % boat.velocity.length(), boat.velocity.length() > 4.0)
			if anchor.state == BoatAnchor.State.STOWED:
				_check("liu'ussa köysi ei venynyt (yli %.2f m)" % _max_over, _max_over <= 0.1)
				_check("liu'ussa ankkuri laahautui perässä", _dragged)
				_check_hull("liu'ussa")
				_check("liukunosto päättyi veneen hidastuttua (%.1f s, %.2f m/s)" % [_t, boat.velocity.length()], boat.velocity.length() < BoatAnchor.SLIDE_SPEED)
				boat.motor_running = false
				boat.velocity = Vector2.ZERO
				boat.yaw_rate = 0.0
				boat.pos = _spot
				boat.toggle_anchor()
				_next()
			elif _t > 30.0:
				_check("ankkuri nostettiin veneeseen", false)
				_finish()
		16:
			_calm()
			boat.velocity = Vector2.ZERO
			if boat.anchored:
				boat.toggle_anchor()
				Input.action_press("boat_forward")
				_next()
			elif _t > 15.0:
				_check("ankkuri vajosi pohjaan", false)
				_finish()
		17:
			# Soutu ja melonta nostossa: W pohjassa, vene ei kiihdy
			_calm()
			if _t > 1.2:
				boat.paddling = true
			if boat._rowing or boat._paddle_stroking or boat.velocity.length() > 0.02:
				_still = false
			if _t > 2.2:
				_check("airot ja mela eivät vedä nostossa", _still and anchor.state == BoatAnchor.State.RAISING)
				boat.paddling = false
				_next()
		18:
			_calm()
			if anchor.state == BoatAnchor.State.STOWED:
				_next()
			elif _t > 30.0:
				_check("ankkuri nostettiin veneeseen", false)
				_finish()
		19:
			# Pohjassa pysynyt W alkaa soutaa heti, kun ankkuri on veneessä
			_calm()
			if _t > 2.0:
				Input.action_release("boat_forward")
				_check("ankkurin tultua soutu toimii (%.2f m/s)" % boat.velocity.length(), boat._rowing and boat.velocity.length() > 0.2)
				boat.velocity = Vector2.ZERO
				boat.yaw_rate = 0.0
				boat.pos = _spot
				boat.toggle_anchor()
				_next()
		20:
			# Lasku vauhdissa ja noin 1 s päästä X: lyhyt köysi, ankkuri jää keulan taakse
			_calm()
			boat.velocity = boat.forward() * 4.0
			if _t > 1.0:
				_reset_tracking()
				boat.toggle_anchor()
				_check("vauhdissa perutussa laskussa ankkuria nostetaan", anchor.state == BoatAnchor.State.RAISING)
				_next()
		21:
			_calm()
			if anchor.state == BoatAnchor.State.STOWED:
				_check("perutussa laskussa köysi ei venynyt (yli %.2f m)" % _max_over, _max_over <= 0.1)
				_check_hull("perutussa laskussa")
				_check("perutun laskun nosto päättyi veneen hidastuttua (%.1f s, %.2f m/s)" % [_t, boat.velocity.length()], boat.velocity.length() < BoatAnchor.SLIDE_SPEED)
				_finish()
			elif _t > 30.0:
				_check("ankkuri nostettiin veneeseen", false)
				_finish()


func _reset_tracking() -> void:
	_max_over = -INF
	_max_keel = -INF
	_rope_in_hull = false


## Nostossa: ankkurin korkeus keulan takana ja näkyvän köyden kulku rungon sisällä
func _track_hull(boat: Boat, anchor: BoatAnchor) -> void:
	var chock := anchor.bow_chock()
	var ring := anchor.ring()
	var to_hull := boat.hull.global_transform.affine_inverse()
	if Vector2(ring.x - chock.x, ring.z - chock.z).dot(boat.forward()) < -0.1:
		_max_keel = maxf(_max_keel, (to_hull * ring).y)
	for i in BoatAnchor.ROPE_SEGMENTS: # viimeinen pala on käsien ja keulan välissä
		var seg: MeshInstance3D = anchor._rope[i]
		var local: Vector3 = to_hull * seg.global_position
		if seg.visible and local.z > -1.9 and local.y > -0.1:
			_rope_in_hull = true


func _check_hull(when: String) -> void:
	_check("%s ankkuri pysyi keulan takana rungon pohjan alla (rengas %.2f m)" % [when, _max_keel], _max_keel < -0.3)
	_check("%s köysi ei kulkenut rungon läpi" % when, not _rope_in_hull)


func _side_camera() -> void:
	main.camera_rig.yaw = main.boat.yaw + PI / 2.0 - 0.5
	main.camera_rig.pitch = 0.22
	main.camera_rig.distance = 5.0


func _count(prefix: String) -> int:
	return _messages.filter(func(m): return m.begins_with(prefix)).size()


func _depth_at_anchor() -> float:
	var anchor: BoatAnchor = main.boat.anchor
	return main.lake.depth_at(anchor.xz.x, anchor.xz.y)


func _finish() -> void:
	Input.action_release("boat_forward")
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

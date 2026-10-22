extends Node
## Ankkurin testi: godot --headless --fixed-fps 30 -- --day=180 --anchortest [--anchortest-shots=KANSIO]
## Ankkuri lasketaan keulasta ja vajoaa pohjaan (vasta silloin vene on
## ankkurissa), köysi on löysä veneen ollessa lähellä ja kiristyy, kun veneellä
## yritetään lähteä, tuulessa vene kääntyy keula ankkuria kohti, ja nostettu
## ankkuri päätyy veneeseen. Kalastaja käsittelee köyttä etutuhdolla.
## Köyttä on syvyys + 0,5 m eikä sitä tule lisää ajettaessa, lasku ja nosto
## etenevät 1 m/s, ja liikkuvasta veneestä laskettu ankkuri kulkee keulan alla.

var main: Node
var _log: Array[String] = []
var _messages: Array[String] = []
var _step := 0
var _t := 0.0
var _spot := Vector2.ZERO
var _depth := 0.0
var _shots := ""
var _saw_anchor_pose := false


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
				_finish()


func _depth_at_anchor() -> float:
	var anchor: BoatAnchor = main.boat.anchor
	return main.lake.depth_at(anchor.xz.x, anchor.xz.y)


func _finish() -> void:
	Input.action_release("boat_forward")
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

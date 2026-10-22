class_name Boat
extends Node3D
## Soutuvene perämoottorilla. Oma yksinkertainen vesifysiikka: työntövoima,
## vastus (pituussuunnassa pieni, sivusuunnassa suuri), tuulen ajelehtiminen,
## ankkuri ja karilleajo järven syvyysdatan perusteella. Perämoottorin potkuri
## ulottuu lähes metrin syvyyteen: matalassa se osuu pohjaan ja voi mennä rikki.
## Airot eivät mahdu laiturin viereen: laituria kohti oleva airo nostetaan
## veneen kylkeen, ja vene saadaan irti laiturista melalla.

signal message(text: String)
signal sound_event(sound: String, at: Vector3)
signal voice(event: String) # kalastajan repliikki (angler_voice.gd)

const LENGTH := 4.4
const MASS := 260.0 # vene + kalastaja + moottori, kg
const YAW_INERTIA := 650.0
const MOTOR_THRUST := 420.0 # N täydellä kaasulla (~5 hv, huippunopeus ~20 km/h)
const ROW_FORCE := 150.0 # N vedon aikana
const ROW_TURN := 320.0 # Nm, kun soudetaan vain toisella airolla
const DRAFT := 0.3 # syväys metreinä
const WINDAGE := 0.85 # 0.5 * ilman tiheys * Cd * A
const STROKE_TIME := 1.6 # s / airoveto
## Perämoottorin potkuri: alle metrin syvyydessä pyörivä potkuri osuu pohjaan
const PROP_DEPTH := 1.0 # m: tätä matalammassa potkuri osuu pohjaan
const SHALLOW_WARNING := 1.3 # m: varoitus matalasta moottorilla ajettaessa
const PROP_MIN_THROTTLE := 0.05 # kaasu, jolla potkuri pyörii (vapaalla ei)
## Mela: yksi lapa kerrallaan veneen kyljellä, heikompi kuin airot
const PADDLE_FORCE := 120.0 # N vedon huippu paikallaan; veto heikkenee vauhdin kasvaessa
const PADDLE_BLADE_SPEED := 3.0 # m/s: lavan nopeus vedossa, tätä kovempaa ei melalla pääse
const PADDLE_TURN := 170.0 # Nm
const PADDLE_STROKE := 1.3 # s / melanveto
const OAR_DOCK_MARGIN := 0.25 # m: airon ja laiturin väli, jota lähempänä airoa ei voi käyttää

var lake: LakeData
var weather: Weather

var pos := Vector2.ZERO # maailman XZ
var velocity := Vector2.ZERO # m/s
var yaw := 0.0 # 0 = keula pohjoiseen (-Z)
var yaw_rate := 0.0

var motor_running := false
var motor_starting := 0.0
var throttle := 0.0 # -0.4 (peruutus) .. 1
var tiller := 0.0 # -1 .. 1
## Ankkurissa: ankkuri on pohjassa (anchor_point), köyttä anchor_rope metriä
var anchored := false
var anchor_point := Vector2.ZERO
var anchor_rope := 0.0
var anchor: BoatAnchor # ankkurin ja köyden malli ja animaatio
var _rope_warned := false
## Mela käytössä: airot ovat veneessä ja melotaan veneen kyljeltä
var paddling := false
var _paddle: Node3D
var _paddle_phase := 0.0
var _paddle_side := 1.0 # 1 = oikea kylki, -1 = vasen
var _paddle_from := 1.0 # palautuksessa lapa siirtyy tältä kyljeltä _paddle_side-kyljelle
var _paddle_dir := 1.0 # 1 = eteen, -1 = taakse
var _paddle_stroking := false
var _paddle_top := Vector3.ZERO # melan kahva rungon koordinaateissa
var _paddle_blade := Vector3.ZERO # lavan keskikohta rungon koordinaateissa
## Airo laituria vasten: [vasen, oikea]; estetty airo nostetaan veneen kylkeen
var oar_blocked := [false, false]
var _blocked_warn_cooldown := 0.0

var angler: Angler
## Talvi: järvi on jäässä, vene piilotetaan ja kalastaja kävelee jäällä
var on_ice := false
const WALK_SPEED := 1.4 # m/s
const RUN_SPEED := 2.8
const TURN_SPEED := 2.2 # rad/s
var _step_dist := 0.0
var hull: Node3D # aaltojen keinuttama osa
var _motor: Node3D # kääntyvä osa: kopa, varsi ja ohjausaisa
var _prop: Node3D
var wake: Wake
var _oars: Array[Dictionary] = [] # {side, pivot, blade}
var _row_phase := 0.0
var _rowing := false
var _oar_activity := [0.0, 0.0] # vasen, oikea: 1 = soutaa eteen, -1 = taakse, 0 = lepää
var _unstow_timer := 0.0
var _bump_cooldown := 0.0
## Potkurin vaurio 0..1: vääntynyt potkuri heikentää työntöä, 1 = rikki
var prop_damage := 0.0
var _strike_cooldown := 0.0
var _shallow_warned := false
var _time := 0.0
var _dock_contact := Vector2.ZERO # viimeisimmän laiturikosketuksen kohta (_dock_push)


func setup(lake_data: LakeData, weather_node: Weather) -> void:
	lake = lake_data
	weather = weather_node
	pos = Vector2(lake.start_position.x, lake.start_position.z)
	yaw = lake.start_yaw
	# Aloituspaikan suunta voi poiketa laiturin suunnasta: vene laiturin viereen, ei kannen alle
	for i in 10:
		var push := _dock_push(pos, yaw)
		if push == Vector2.ZERO:
			break
		pos += push * 1.05
	_build_visuals()
	_apply_transform()


func forward() -> Vector2:
	return Vector2(-sin(yaw), -cos(yaw))


func right() -> Vector2:
	return Vector2(cos(yaw), -sin(yaw))


func speed_kmh() -> float:
	return velocity.length() * 3.6


func depth_below() -> float:
	return lake.depth_at(pos.x, pos.y)


## Jäätila: vene, airot, moottori ja vana piiloon, kalastaja jäälle
func set_on_ice(on: bool) -> void:
	on_ice = on
	for child in hull.get_children():
		if child != angler:
			child.visible = not on
	wake.visible = not on
	hull.position = Vector3.ZERO
	hull.rotation = Vector3.ZERO
	anchored = false
	paddling = false
	if anchor:
		anchor.stow()
		anchor.visible = not on # ankkuri on veneen mukana talviteloilla
	motor_running = false
	_apply_transform()


func _unhandled_input(event: InputEvent) -> void:
	if on_ice:
		if event.is_action_pressed("motor_toggle") or event.is_action_pressed("anchor_toggle") or event.is_action_pressed("paddle_toggle"):
			message.emit("Järvi on jäässä – vene on talviteloilla")
		return
	if event.is_action_pressed("motor_toggle"):
		if motor_running or motor_starting > 0.0:
			motor_running = false
			motor_starting = 0.0
			throttle = 0.0
			_unstow_timer = 1.5
			sound_event.emit("motor_stop", _stern_position())
			message.emit("Moottori sammutettu – airot hankaimiin")
		elif prop_broken():
			message.emit("Potkuri on rikki – moottorilla ei pääse, soudetaan")
		else:
			motor_starting = 1.6
			paddling = false
			sound_event.emit("motor_start", _stern_position())
			message.emit("Airot veneeseen ja nykäiset käynnistysnarusta...")
	elif event.is_action_pressed("anchor_toggle"):
		toggle_anchor()
	elif event.is_action_pressed("paddle_toggle"):
		toggle_paddle()


## Mela käteen tai pois (V). Melalla pääsee irti laiturista, kun airot eivät mahdu.
func toggle_paddle() -> void:
	if motor_running or motor_starting > 0.0:
		message.emit("Sammuta ensin moottori (Q) – sitten mela")
		return
	if angler and angler.fishing and angler.fishing.busy():
		message.emit("Kelaa ensin uistin ylös – sitten mela")
		return
	paddling = not paddling
	_paddle_stroking = false
	_unstow_timer = 0.0 if paddling else 1.0
	message.emit("Mela käteen – airot veneeseen" if paddling else "Mela veneen pohjalle – airot hankaimiin")


func paddle_in_hand() -> bool:
	return paddling and not (angler and angler.fishing and angler.fishing.busy())


## Ankkuri alas tai ylös (X). Ankkuri lasketaan keulasta ja vene on ankkurissa,
## kun ankkuri on pohjassa; nostettaessa vene irtoaa heti.
func toggle_anchor() -> void:
	if angler and angler.fishing and angler.fishing.busy():
		message.emit("Kelaa ensin uistin ylös – sitten ankkuri")
		return
	if anchor.state == BoatAnchor.State.STOWED or anchor.state == BoatAnchor.State.RAISING:
		anchor.lower()
		sound_event.emit("anchor_drop", anchor.bow_chock())
		message.emit("Ankkuri lasketaan keulasta...")
	else:
		anchor.raise()
		anchored = false
		sound_event.emit("anchor_up", anchor.bow_chock())
		message.emit("Ankkuria nostetaan...")


## Ankkuriköyden kulkukohta keulassa veneen keskeltä (BoatAnchor.BOW_CHOCK)
const BOW_ROPE := 2.2
## Kireän ankkuriköyden kääntövoima (keula ankkuria kohti)
const ANCHOR_TURN := 1500.0


## Kuinka kauas (vaakasuunnassa) keula pääsee ankkurista: köysi kulkee keulasta
## pohjaan, joten vaakaulottuma on köyden pituudesta jäljelle jäävä osa, vähintään 1 m
func anchor_reach() -> float:
	var depth := lake.depth_at(anchor_point.x, anchor_point.y) + 0.5
	return sqrt(maxf(1.0, anchor_rope * anchor_rope - depth * depth))


func _on_anchor_bottom(depth: float) -> void:
	anchored = true
	anchor_point = anchor.xz
	anchor_rope = depth + 0.5 # köyttä syvyys + puoli metriä
	message.emit("Ankkuri pohjassa (syvyys %.1f m)" % depth)


## Kävely jäällä ja rannalla: W/S eteen ja taakse, A/D kääntyy, Shift juoksee.
## Avannolla istuessa (kalastus käynnissä) ei kävellä.
func _walk(dt: float) -> void:
	var drive := Input.get_axis("boat_back", "boat_forward")
	var steer := Input.get_axis("boat_right", "boat_left")
	if angler and angler.fishing and angler.fishing.busy():
		drive = 0.0
		steer = 0.0
	yaw = wrapf(yaw + steer * TURN_SPEED * dt, -PI, PI)
	var speed := RUN_SPEED if Input.is_action_pressed("reel_fast") else WALK_SPEED
	var target := forward() * drive * speed
	velocity = velocity.move_toward(target, dt * 6.0)
	var next := pos + velocity * dt
	var size := lake.world_size()
	if next.x > lake.origin_x + 5.0 and next.x < lake.origin_x + size.x - 5.0 and next.y > lake.origin_z + 5.0 and next.y < lake.origin_z + size.y - 5.0:
		_step_dist += pos.distance_to(next)
		pos = next
	if _step_dist > 0.75:
		_step_dist = 0.0
		sound_event.emit("snow_step", global_position)
	_apply_transform()


func _physics_process(dt: float) -> void:
	if on_ice:
		_walk(dt)
		return
	_time += dt
	_bump_cooldown -= dt
	_strike_cooldown -= dt
	if motor_starting > 0.0:
		motor_starting -= dt
		if motor_starting <= 0.0:
			motor_running = true
			message.emit("Moottori käy")

	var drive := Input.get_axis("boat_back", "boat_forward")
	var steer := Input.get_axis("boat_right", "boat_left")
	var fwd := forward()
	var side := right()
	var v_fwd := velocity.dot(fwd)
	var v_side := velocity.dot(side)
	var force := Vector2.ZERO
	var torque := 0.0

	if motor_running:
		throttle = clampf(throttle + drive * 0.6 * dt, -0.4, 1.0)
		tiller = move_toward(tiller, steer, 2.5 * dt)
		var angle := tiller * 0.6
		var thrust := MOTOR_THRUST * throttle * (1.0 - 0.6 * prop_damage)
		force += fwd * thrust * cos(angle)
		torque += thrust * sin(angle) * 2.1 + v_fwd * tiller * 45.0
		_rowing = false
	else:
		tiller = move_toward(tiller, 0.0, 2.0 * dt)
		# Käännös soudetaan toisella airolla: oikea airo eteen kääntää vasemmalle
		_oar_activity = [clampf(drive - steer, -1.0, 1.0), clampf(drive + steer, -1.0, 1.0)]
		_update_oar_blocks()
		if paddling:
			_oar_activity = [0.0, 0.0]
			var push := _paddle_stroke(dt, drive, steer)
			force += fwd * push.x
			torque += push.y
		for i in 2:
			if oar_blocked[i] and _oar_activity[i] != 0.0:
				_oar_activity[i] = 0.0
				if motor_starting <= 0.0 and _unstow_timer <= 0.0 and _blocked_warn_cooldown <= 0.0:
					_blocked_warn_cooldown = 8.0
					message.emit("Laituri on liian lähellä – %s airo ei mahdu. Ota mela (V)" % ["vasen", "oikea"][i])
		_rowing =motor_starting <= 0.0 and _unstow_timer <= 0.0 and (_oar_activity[0] != 0.0 or _oar_activity[1] != 0.0)
		if _rowing:
			var before := fmod(_row_phase, 1.0)
			_row_phase += dt / STROKE_TIME
			var f := fmod(_row_phase, 1.0)
			var power := sin(PI * f / 0.45) if f < 0.45 else 0.0
			var left: float = _oar_activity[0]
			var right_oar: float = _oar_activity[1]
			force += fwd * (left + right_oar) * 0.5 * ROW_FORCE * power
			torque += (right_oar - left) * 0.5 * ROW_TURN * power
			if before < 0.45 and f >= 0.45:
				_leave_swirls()
			elif before < 0.95 and f >= 0.95:
				_blade_sounds("oar_stroke")
		else:
			_row_phase = 0.0

	# Veden vastus
	force -= fwd * (v_fwd * absf(v_fwd) * 13.0 + v_fwd * 10.0)
	force -= side * (v_side * absf(v_side) * 180.0 + v_side * 60.0)
	torque -= yaw_rate * (500.0 + absf(v_fwd) * 300.0)

	# Tuuli
	var rel_wind := weather.vector() - velocity
	force += rel_wind * rel_wind.length() * WINDAGE

	# Ankkuriköysi vetää keulasta: vene kääntyy keula ankkuria kohti. Köyden
	# vaakaulottuma on köyden pituus miinus syvyys (köysi kulkee pohjaan).
	if anchored:
		var bow_offset := fwd * BOW_ROPE
		var d := pos + bow_offset - anchor_point
		var reach := anchor_reach()
		if d.length() > reach - 0.05:
			# Köysi kireällä: vene kääntyy keula ankkuria kohti (tuuli painaa perää)
			var to_anchor := -d.normalized()
			torque -= (fwd.x * to_anchor.y - fwd.y * to_anchor.x) * ANCHOR_TURN
		if d.length() > reach:
			var pull := -d.normalized() * (d.length() - reach) * 900.0 - velocity * 250.0
			force += pull
			torque -= bow_offset.x * pull.y - bow_offset.y * pull.x
			# Lähtöyritys ankkuri pohjassa: köysi kiristyy
			if not _rope_warned and (absf(drive) > 0.0 and (motor_running or _rowing)):
				_rope_warned = true
				message.emit("Ankkuriköysi kiristyy – nosta ensin ankkuri (X)")
				voice.emit("anchor")
		elif d.length() < reach - 1.0:
			_rope_warned = false
		torque -= yaw_rate * 300.0

	velocity += force / MASS * dt
	yaw_rate += torque / YAW_INERTIA * dt
	yaw = wrapf(yaw + yaw_rate * dt, -PI, PI)

	var new_pos := pos + velocity * dt
	if anchored:
		# Köysi ei veny: keula pysyy köyden ulottumalla ankkurista, eikä vene
		# jatka liikettään ankkurista poispäin
		var bow := new_pos + fwd * BOW_ROPE - anchor_point
		var reach := anchor_reach()
		if bow.length() > reach:
			var out := bow.normalized()
			new_pos -= out * (bow.length() - reach)
			velocity -= out * maxf(0.0, velocity.dot(out))
	new_pos += _dock_collision(new_pos)
	var old_clearance := _min_depth(pos, yaw)
	var new_clearance := _min_depth(new_pos, yaw)
	if new_clearance < DRAFT and new_clearance < old_clearance:
		if velocity.length() > 0.5 and _bump_cooldown <= 0.0:
			sound_event.emit("boat_bump", global_position)
			if velocity.length() > 1.0:
				message.emit("Kolahdus! Vene osui pohjaan")
			_bump_cooldown = 3.0
		velocity *= -0.15
		yaw_rate *= 0.5
	else:
		pos = new_pos

	_unstow_timer = maxf(0.0, _unstow_timer - dt)
	_blocked_warn_cooldown -= dt
	var stern := pos - fwd * LENGTH * 0.5
	if motor_running:
		_check_propeller(stern)
	wake.track(stern, side, velocity.length())
	_animate(dt)
	_apply_transform()
	anchor.update(dt) # rungon uuden asennon mukaan


func prop_broken() -> bool:
	return prop_damage >= 1.0


## Potkuri perässä: matalassa pyörivä potkuri osuu pohjaan. Vaurio kasvaa
## kaasun ja sen mukaan, kuinka syvälle potkuri iskee pohjaan; rikkoutunut
## potkuri sammuttaa moottorin.
func _check_propeller(stern: Vector2) -> void:
	var depth := lake.depth_at(stern.x, stern.y)
	var spinning := absf(throttle) >= PROP_MIN_THROTTLE
	if depth < SHALLOW_WARNING and depth >= PROP_DEPTH and spinning and not _shallow_warned:
		_shallow_warned = true
		message.emit("Matalaa (%.1f m)! Varo potkuria – alle metrissä se osuu pohjaan" % depth)
	elif depth >= SHALLOW_WARNING + 0.3:
		_shallow_warned = false
	if depth >= PROP_DEPTH or not spinning or _strike_cooldown > 0.0:
		return
	_strike_cooldown = 0.6
	var hit := clampf((PROP_DEPTH - depth) / 0.5, 0.2, 1.0) # kuinka syvälle pohjaan
	prop_damage = minf(1.0, prop_damage + (0.08 + 0.22 * absf(throttle)) * hit)
	velocity *= 0.8
	sound_event.emit("prop_strike", global_position - Vector3(forward().x, 0.0, forward().y) * LENGTH * 0.5)
	if prop_broken():
		motor_running = false
		throttle = 0.0
		_unstow_timer = 1.5
		message.emit("Potkuri meni rikki! Moottori sammui – airot hankaimiin")
	elif prop_damage > 0.5:
		message.emit("Potkuri osui pohjaan! Potkuri on pahasti vääntynyt (%d %%)" % roundi(prop_damage * 100.0))
	else:
		message.emit("Potkuri osui pohjaan (%.1f m)! Nosta kaasua tai aja syvemmälle" % depth)


## Rungon ääriviiva ylhäältä reunalistoineen (paikallinen x oikealle, y perään),
## samat mitat kuin HULL_STATIONS
const OUTLINE: Array[Vector2] = [
	Vector2(0.0, -2.2), Vector2(0.32, -1.9), Vector2(0.54, -1.5), Vector2(0.69, -1.0),
	Vector2(0.78, 0.0), Vector2(0.76, 1.0), Vector2(0.64, 2.2), Vector2(-0.64, 2.2),
	Vector2(-0.76, 1.0), Vector2(-0.78, 0.0), Vector2(-0.69, -1.0), Vector2(-0.54, -1.5),
	Vector2(-0.32, -1.9),
]


## Rungon ääriviiva maailmassa
func _outline(p: Vector2, heading: float) -> PackedVector2Array:
	var side := Vector2(cos(heading), -sin(heading))
	var back := Vector2(sin(heading), cos(heading))
	var poly := PackedVector2Array()
	for o in OUTLINE:
		poly.append(p + side * o.x + back * o.y)
	return poly


## Siirtymä, jolla runko kohdassa p pääsee irti laitureista: syvin rungon piste
## laiturin kannen alla tai syvin laiturin kulma rungon sisällä
func _dock_push(p: Vector2, heading: float) -> Vector2:
	var best := Vector2.ZERO
	var poly := _outline(p, heading)
	for v in poly:
		var push := lake.dock_push(v)
		if push.length() > best.length():
			best = push
			_dock_contact = v
	for d in lake.docks:
		var half: Vector2 = d["half"]
		if p.distance_to(d["center"]) > half.length() + LENGTH:
			continue
		for corner in lake.dock_corners(d):
			if not Geometry2D.is_point_in_polygon(corner, poly):
				continue
			# Rungon lähin reuna siirtyy kulman kohdalle
			var nearest := Vector2.ZERO
			for i in poly.size():
				var edge := Geometry2D.get_closest_point_to_segment(corner, poly[i], poly[(i + 1) % poly.size()])
				if nearest == Vector2.ZERO or (corner - edge).length() < nearest.length():
					nearest = corner - edge
			if nearest.length() > best.length():
				best = nearest
				_dock_contact = corner
	return best


## Laiturikosketus: runko työnnetään irti kannesta ja laituria kohti oleva
## nopeus pysäytetään (hieman kimmoten), jolloin vene liukuu laituria pitkin.
## Palauttaa siirtymän, joka lisätään uuteen paikkaan.
func _dock_collision(new_pos: Vector2) -> Vector2:
	var push := _dock_push(new_pos, yaw)
	if push == Vector2.ZERO:
		return push
	var n := push.normalized()
	var v_in := velocity.dot(n)
	if v_in < 0.0:
		if v_in < -0.4 and _bump_cooldown <= 0.0:
			sound_event.emit("boat_bump", global_position)
			if v_in < -1.0:
				message.emit("Kolahdus! Vene törmäsi laituriin")
			_bump_cooldown = 3.0
		var impulse := -n * v_in * 1.2 * MASS
		velocity += impulse / MASS
		# Kosketuskohdan isku kääntää venettä: keula kääntyy irti laiturin
		# kulmasta eikä jää siihen kiinni
		var r := _dock_contact - new_pos
		yaw_rate = yaw_rate * 0.6 - (r.x * impulse.y - r.y * impulse.x) / YAW_INERTIA
	return push
func _min_depth(p: Vector2, heading: float) -> float:
	var f := Vector2(-sin(heading), -cos(heading)) * LENGTH * 0.45
	return minf(lake.depth_at(p.x + f.x, p.y + f.y), minf(lake.depth_at(p.x, p.y), lake.depth_at(p.x - f.x, p.y - f.y)))


func _apply_transform() -> void:
	var ground := maxf(lake.height_at(pos.x, pos.y), 0.0) if on_ice and lake else 0.0
	position = Vector3(pos.x, ground, pos.y)
	rotation = Vector3(0.0, yaw, 0.0)


func _animate(dt: float) -> void:
	# Vene keinuu samoissa aalloissa kuin vesipinta: korkeus keskeltä,
	# keulan ja perän sekä laitojen korkeuserosta kallistukset
	var fwd := forward()
	var side := right()
	var h_bow := Waves.swell_height(pos + fwd * LENGTH * 0.45)
	var h_stern := Waves.swell_height(pos - fwd * LENGTH * 0.45)
	var h_left := Waves.swell_height(pos - side * 0.7)
	var h_right := Waves.swell_height(pos + side * 0.7)
	var planing := clampf(velocity.dot(fwd) * 0.012 * throttle, -0.05, 0.06) # keula nousee kaasulla
	var heel := clampf(yaw_rate * velocity.length() * 0.05, -0.08, 0.08) # kallistus käännöksessä
	hull.position.y = lerpf(hull.position.y, Waves.swell_height(pos), minf(1.0, dt * 6.0))
	hull.rotation.x = lerpf(hull.rotation.x, atan2(h_bow - h_stern, LENGTH * 0.9) + planing, minf(1.0, dt * 4.0))
	hull.rotation.z = lerpf(hull.rotation.z, atan2(h_left - h_right, 1.4) + heel, minf(1.0, dt * 4.0))
	_motor.rotation.y = -tiller * 0.6
	if motor_running:
		_motor.position.y = 0.55 + sin(_time * 60.0) * 0.004
	if motor_running and absf(throttle) > PROP_MIN_THROTTLE and not prop_broken():
		_prop.rotation.z += dt * 45.0 * signf(throttle)
	_animate_oars(dt)
	_animate_paddle(dt)


# --- Airot -------------------------------------------------------------------

const OAR_LENGTH := 2.2
const BLADE_OUT := 1.85 # lavan keskikohdan etäisyys hankaimesta
const OAR_HANDLE_IN := 0.45 # kahvan pään etäisyys hankaimesta veneen sisään

## Puinen soutuairo (2,55 m): kahvan päässä nuppi ja ohuempi kädensija, pyöreä
## varsi ja pitkä, vähitellen levenevä lapa, jonka kärki on pyöristetty.
## Kahvan pää origossa, lapa -Y:n suuntaan (sama muoto kuin PADDLE_PROFILE).
const OAR_PROFILE := [
	# y, puolileveys, puolipaksuus
	[0.0, 0.012, 0.012], [-0.006, 0.019, 0.019], [-0.03, 0.019, 0.019],
	[-0.04, 0.015, 0.015], [-0.15, 0.016, 0.016], [-0.18, 0.022, 0.022],
	[-1.3, 0.022, 0.022], [-1.62, 0.024, 0.018], [-1.8, 0.042, 0.014],
	[-2.0, 0.062, 0.01], [-2.2, 0.072, 0.008], [-2.46, 0.075, 0.007],
	[-2.52, 0.068, 0.006], [-2.54, 0.052, 0.005], [-2.55, 0.026, 0.004],
]
const OARLOCK := Vector3(0.68, 0.45, 0.65) # soutajan (keskituhto) perän puolella


## Soutuvaiheet (soutaja istuu selkä keulaan päin):
##  0.00–0.45 veto: lapa pystyssä veden alla, liikkuu keulan puolelta perään
##  0.45–0.55 irrotus: lapa nousee pinnasta ja kääntyy vaakatasoon
##  0.55–0.93 palautus: lapa ilmassa takaisin keulan puolelle
##  0.93–1.00 otto: lapa kääntyy pystyyn ja painuu veteen
## Palauttaa [pyyhkäisykulma (rad, + = perään päin), laskukulma (rad), lavan kierto (rad)]
func _stroke_pose(f: float) -> Array:
	var catch_sweep := deg_to_rad(-35.0)
	var finish_sweep := deg_to_rad(30.0)
	var deep := deg_to_rad(21.0) # lapa n. 15 cm veden alla
	var high := deg_to_rad(8.0) # lapa ilmassa
	var square := PI / 2.0
	if f < 0.45:
		var u := f / 0.45
		return [lerpf(catch_sweep, finish_sweep, u), deep + deg_to_rad(3.0) * sin(PI * u), square]
	elif f < 0.55:
		var u := (f - 0.45) / 0.1
		return [finish_sweep, lerpf(deep, high, u), lerpf(square, 0.0, u)]
	elif f < 0.93:
		var u := smoothstep(0.0, 1.0, (f - 0.55) / 0.38)
		return [lerpf(finish_sweep, catch_sweep, u), high, 0.0]
	var u := (f - 0.93) / 0.07
	return [catch_sweep, lerpf(high, deep, u), lerpf(0.0, square, u)]


func _animate_oars(dt: float) -> void:
	var stowed := motor_running or motor_starting > 0.0 or paddling
	var f := fmod(_row_phase, 1.0)
	for i in _oars.size():
		var oar: Dictionary = _oars[i]
		var s: float = oar["side"]
		var target: Transform3D
		var feather := 0.0
		if stowed:
			# Pitkittäin tuhtojen päällä, lavat keulaan päin
			target = Transform3D(Basis(Vector3.UP, s * PI / 2.0), Vector3(s * 0.36, 0.25, 1.15))
		elif oar_blocked[i]:
			# Laituri vieressä: airo hankaimessa veneen kylkeä pitkin, lapa perään päin
			var shipped := Basis(Vector3.UP, -s * deg_to_rad(82.0)) * Basis(Vector3.BACK, -s * deg_to_rad(4.0))
			target = Transform3D(shipped, Vector3(OARLOCK.x * s, OARLOCK.y, OARLOCK.z))
		else:
			var activity: float = _oar_activity[i] if _rowing else 0.0
			var sweep := 0.0
			var dip := deg_to_rad(15.0) # lepoasennossa lapa lepää pinnalla
			if activity != 0.0:
				var pose := _stroke_pose(f)
				sweep = pose[0] * signf(activity) # taaksepäin soudettaessa liike menee toisin päin
				dip = pose[1]
				feather = pose[2]
			# Vasen airo osoittaa -X, oikea +X: kulmien etumerkit peilataan
			var basis := Basis(Vector3.UP, -s * sweep) * Basis(Vector3.BACK, -s * dip)
			target = Transform3D(basis, Vector3(OARLOCK.x * s, OARLOCK.y, OARLOCK.z))
		var pivot: Node3D = oar["pivot"]
		var rate := 3.5 if stowed or oar_blocked[i] or _unstow_timer > 0.0 else 18.0
		if stowed and oar_blocked[i]:
			rate = 60.0 # laiturin puolelta airo nostetaan suoraan veneeseen, ei kääntäen laiturin läpi
		pivot.transform = pivot.transform.interpolate_with(target, minf(1.0, dt * rate))
		# Lavan malli on pystyssä; feather 0 = vaakatasossa, PI/2 = pystyssä
		var roll: Node3D = oar["roll"]
		roll.rotation.x = lerp_angle(roll.rotation.x, PI / 2.0 - feather, minf(1.0, dt * rate))


## Osuisiko airo laituriin: airon pyyhkäisemä alue (otosta vedon loppuun,
## hankaimesta lavan kärkeen) verrataan laiturien kansiin
func _update_oar_blocks() -> void:
	oar_blocked = [false, false]
	var near := false
	for d in lake.docks:
		near = near or pos.distance_to(d["center"]) < (d["half"] as Vector2).length() + OAR_LENGTH + LENGTH
	if not near:
		return
	var side := right()
	var back := -forward()
	for i in 2:
		var s: float = [-1.0, 1.0][i]
		for sweep_deg in range(-35, 31, 5):
			var sweep := deg_to_rad(sweep_deg)
			for r in [0.6, 1.0, 1.4, 1.8, 2.1]:
				var lx: float = s * (OARLOCK.x + r * cos(sweep))
				var lz: float = OARLOCK.z + r * sin(sweep)
				if lake.near_dock(pos + side * lx + back * lz, OAR_DOCK_MARGIN):
					oar_blocked[i] = true
					break
			if oar_blocked[i]:
				break


## Melanveto (kalastaja istuu kasvot keulaan): veto 0–0.5 lapa vedessä keulan
## puolelta perään, irrotus 0.5–0.6, palautus ilmassa 0.6–0.92 (kyljen vaihto
## veneen yli), otto 0.92–1. Suoraan melottaessa kylki vaihtuu joka vedolla;
## A/D melotaan vain toiselta kyljeltä, jolloin vene kääntyy.
## Palauttaa (työntövoima eteen N, vääntö Nm).
func _paddle_stroke(dt: float, drive: float, steer: float) -> Vector2:
	var want := paddle_in_hand() and (drive != 0.0 or steer != 0.0)
	if not _paddle_stroking:
		if not want:
			return Vector2.ZERO
		_paddle_stroking = true
		_paddle_phase = 0.92 # aloitetaan otosta
		_paddle_dir = -1.0 if drive < 0.0 else 1.0
		_paddle_side = signf(steer) * _paddle_dir if steer != 0.0 else 1.0
		_paddle_from = _paddle_side
	var before := _paddle_phase
	_paddle_phase += dt / PADDLE_STROKE
	if before < 0.97 and _paddle_phase >= 0.97:
		sound_event.emit("paddle_stroke", paddle_blade())
	if _paddle_phase >= 1.0:
		_paddle_phase -= 1.0
	if before < 0.5 and _paddle_phase >= 0.5:
		var b := paddle_blade()
		wake.add_swirl(Vector2(b.x, b.z), 1.0)
		sound_event.emit("oar_drip", b)
		# Seuraava veto ohjauksen mukaan; ilman ohjausta lopetetaan
		if not want:
			_paddle_stroking = false
			return Vector2.ZERO
		_paddle_dir = -1.0 if drive < 0.0 else 1.0
		_paddle_from = _paddle_side
		_paddle_side = signf(steer) * _paddle_dir if steer != 0.0 else -_paddle_side
	if _paddle_phase >= 0.5:
		return Vector2.ZERO
	var power := sin(PI * _paddle_phase / 0.5)
	# Lapa ottaa vedestä sitä paremmin kiinni, mitä hitaammin vene liikkuu:
	# vastatuuleen pääsee etenemään, mutta tyynellä matkavauhti pysyy maltillisena
	var grip := clampf(1.0 - _paddle_dir * velocity.dot(forward()) / PADDLE_BLADE_SPEED, 0.0, 1.5)
	return Vector2(_paddle_dir * PADDLE_FORCE * grip * power, _paddle_side * _paddle_dir * PADDLE_TURN * power)


## Melan kahva ja lavan keskikohta rungon koordinaateissa asennon mukaan
func _paddle_pose() -> Array:
	if not paddle_in_hand():
		# Veneen pohjalla vasenta kylkeä pitkin
		return [Vector3(-0.38, -0.08, -0.55), Vector3(-0.38, -0.08, 0.75)]
	if not _paddle_stroking:
		# Poikittain sylissä, lapa oikean laidan yli
		return [Vector3(-0.42, 0.48, -0.2), Vector3(0.82, 0.42, -0.2)]
	var s := _paddle_side
	var catch_z := -0.55 if _paddle_dir > 0.0 else 0.75
	var finish_z := 0.75 if _paddle_dir > 0.0 else -0.55
	var f := _paddle_phase
	var blade: Vector3
	# Kahvan suunta lavasta: tavallisesti kohti pistettä laidan yläpuolella
	# lavan puolella, jottei varsi kulje laidan läpi
	var up := Vector3.ZERO
	if f < 0.5:
		var u := f / 0.5
		blade = Vector3(s * 1.05, -0.2 - 0.08 * sin(PI * u), lerpf(catch_z, finish_z, u))
	elif f < 0.6:
		blade = Vector3(_paddle_from * 1.05, lerpf(-0.2, 0.3, (f - 0.5) / 0.1), finish_z)
	elif f < 0.92:
		# Palautus matalalla laidan ulkopuolella; kylki vaihdetaan keulan puolella
		# nostamalla mela kalastajan edestä veneen yli
		var u := (f - 0.6) / 0.32
		var cross := smoothstep(0.0, 1.0, clampf(u * 2.0 - 1.0, 0.0, 1.0)) if _paddle_from != s else 0.0
		var side := lerpf(_paddle_from, s, cross)
		blade = Vector3(side * 1.05, 0.3 + 0.45 * sin(PI * cross), lerpf(finish_z, catch_z, smoothstep(0.0, 1.0, minf(1.0, u * 2.0))))
		if cross > 0.0 and cross < 1.0:
			up = Vector3(-side * 0.9, 0.6, 0.25).normalized()
	else:
		blade = Vector3(s * 1.05, lerpf(0.3, -0.2, (f - 0.92) / 0.08), catch_z)
	if up == Vector3.ZERO:
		up = (Vector3(blade.x * 0.6, 0.95, lerpf(0.0, blade.z, 0.4)) - blade).normalized()
	return [blade + up * 1.25, blade]


func _animate_paddle(dt: float) -> void:
	var target := _paddle_pose()
	var k := minf(1.0, dt * (20.0 if _paddle_stroking and paddle_in_hand() else 4.0))
	_paddle_top = _paddle_top.lerp(target[0], k)
	_paddle_blade = _paddle_blade.lerp(target[1], k)
	var y := (_paddle_top - _paddle_blade).normalized()
	# Vedossa lavan pinta poikittain veneeseen nähden, palautuksessa käännettynä
	var feather := _paddle_stroking and _paddle_phase >= 0.55 and _paddle_phase < 0.92
	var x := y.cross(Vector3.RIGHT if feather else Vector3.BACK)
	if x.length() < 0.3:
		x = y.cross(Vector3.UP)
	x = x.normalized()
	_paddle.transform = Transform3D(Basis(x, y, x.cross(y)), _paddle_top)


## Melan lavan keskikohta maailmassa
func paddle_blade() -> Vector3:
	return hull.global_transform * _paddle_blade


## Kädet melassa maailmassa: [oikea, vasen]. Lapaa vastapäinen käsi kahvassa,
## toinen varressa lavan puolella.
func paddle_hands() -> Array:
	var top := hull.global_transform * _paddle_top
	var low := hull.global_transform * _paddle_top.lerp(_paddle_blade, 0.45)
	var side := _paddle_side if _paddle_stroking else 1.0
	return [low, top] if side > 0.0 else [top, low]


## Vedon lopussa lavat jättävät pyörteen veteen, ja lavoista tippuu vettä
func _leave_swirls() -> void:
	for i in _oars.size():
		if _oar_activity[i] == 0.0:
			continue
		var blade: Node3D = _oars[i]["blade"]
		var p := blade.global_position
		wake.add_swirl(Vector2(p.x, p.z), 1.0 + absf(_oar_activity[i]) * 0.3)
	_blade_sounds("oar_drip")


func _blade_sounds(sound: String) -> void:
	for i in _oars.size():
		if _oar_activity[i] != 0.0:
			sound_event.emit(sound, _oars[i]["blade"].global_position)


func _stern_position() -> Vector3:
	var stern := pos - forward() * LENGTH * 0.5
	return Vector3(stern.x, 0.5, stern.y)


# --- Ulkonäkö ---------------------------------------------------------------

func _material(color: Color, cull_disabled := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	if cull_disabled:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _build_visuals() -> void:
	hull = Node3D.new()
	add_child(hull)

	_build_hull()
	_build_motor()

	# Airot hankaimissa: vasen (-X) ja oikea (+X). Airon varsi alkaa hieman
	# hankaimen sisäpuolelta (kahva) ja lapa on varren ulkopäässä.
	var oar_shape := _lathe_mesh(OAR_PROFILE)
	var pine := _pine_material()
	var sleeve_shape := CylinderMesh.new() # musta kumiholkki hankaimen kohdalla
	sleeve_shape.top_radius = 0.027
	sleeve_shape.bottom_radius = 0.027
	sleeve_shape.height = 0.2
	sleeve_shape.radial_segments = 12
	sleeve_shape.rings = 1
	sleeve_shape.material = _material(Color(0.06, 0.06, 0.06))
	for s in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(OARLOCK.x * s, OARLOCK.y, OARLOCK.z)
		hull.add_child(pivot)
		# Airo kiertyy varren ympäri (lavan kääntö): koko malli on roll-solmun lapsi
		var roll := Node3D.new()
		pivot.add_child(roll)
		var oar_mesh := MeshInstance3D.new()
		oar_mesh.name = "Shaft"
		oar_mesh.mesh = oar_shape
		oar_mesh.material_override = pine
		# Profiili kulkee -Y:hen; Z-kierto kääntää sen airon suuntaan ja lavan pystyyn
		oar_mesh.transform = Transform3D(Basis(Vector3.BACK, s * PI / 2.0), Vector3(-OAR_HANDLE_IN * s, 0, 0))
		roll.add_child(oar_mesh)
		var sleeve := MeshInstance3D.new()
		sleeve.mesh = sleeve_shape
		sleeve.transform = Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(0.08 * s, 0, 0))
		roll.add_child(sleeve)
		var blade := Node3D.new() # lavan keskikohta: äänet, vana ja laiturin tarkistus
		blade.position = Vector3(BLADE_OUT * s, 0, 0)
		roll.add_child(blade)
		_oars.append({"side": s, "pivot": pivot, "roll": roll, "blade": blade})

	# Mela: kahva paikallisessa origossa, varsi ja lapa -Y:n suuntaan
	_paddle = Node3D.new()
	hull.add_child(_paddle)
	var paddle_mesh := MeshInstance3D.new()
	paddle_mesh.mesh = _lathe_mesh(PADDLE_PROFILE)
	paddle_mesh.material_override = _pine_material()
	_paddle.add_child(paddle_mesh)
	var rest := _paddle_pose()
	_paddle_top = rest[0]
	_paddle_blade = rest[1]

	wake = Wake.new()
	add_child(wake)

	anchor = BoatAnchor.new()
	add_child(anchor)
	anchor.setup(self)
	anchor.reached_bottom.connect(_on_anchor_bottom)
	anchor.stowed.connect(func(): message.emit("Ankkuri nostettu veneeseen"))

	# Kalastaja keskituhdolla (asento ja kädet: angler.gd)
	angler = Angler.new()
	angler.position = Angler.SEATS[Angler.Pose.FISHING]
	hull.add_child(angler)


## Airojen kahvat maailmassa: [vasen airo, oikea airo]
func oar_handles() -> Array:
	var handles := []
	for oar in _oars:
		var s: float = oar["side"]
		handles.append(oar["pivot"].global_transform * Vector3(-0.38 * s, 0, 0))
	return handles


## Perämoottorin ohjausaisan kahva maailmassa
func tiller_handle() -> Vector3:
	return _motor.global_transform * Vector3(0, 0.2, -0.88)


## Puinen kanoottimela (n. 1,5 m): levenevä kämmenkahva, pyöreä varsi, pitkä
## kaula ja lapa, joka levenee kärkeä kohti ja jonka kärki on suora ja
## kulmista pyöristetty. Poikkileikkaus on soikio: varressa pyöreä, lavassa
## ohut ja keskeltä paksumpi. Kahva origossa, lapa -Y:n suuntaan (keskikohta -1,25).
const PADDLE_PROFILE := [
	# y, puolileveys, puolipaksuus
	[0.0, 0.035, 0.008], [-0.006, 0.05, 0.013], [-0.03, 0.045, 0.015],
	[-0.07, 0.028, 0.016], [-0.12, 0.018, 0.016], [-0.16, 0.016, 0.016],
	[-0.86, 0.016, 0.016], [-0.95, 0.022, 0.015], [-1.04, 0.04, 0.012],
	[-1.14, 0.058, 0.01], [-1.26, 0.07, 0.009], [-1.38, 0.076, 0.008],
	[-1.46, 0.077, 0.007], [-1.49, 0.071, 0.006], [-1.505, 0.056, 0.005],
	[-1.512, 0.03, 0.004],
]


## Pyörähdysmäinen puuesine profiilista [y, puolileveys, puolipaksuus], -Y:n suuntaan
func _lathe_mesh(profile: Array) -> Mesh:
	var sides := 12
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := []
	for p in profile:
		var ring := []
		for k in sides:
			var a := TAU * k / sides
			ring.append(Vector3(p[1] * cos(a), p[0], p[2] * sin(a)))
		rings.append(ring)
	var length: float = -profile[-1][0]
	for i in rings.size() - 1:
		for k in sides:
			var k2 := (k + 1) % sides
			var quad := [rings[i][k], rings[i + 1][k], rings[i + 1][k2], rings[i][k2]]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for j in tri:
					var v: Vector3 = quad[j]
					# Syy kulkee pituussuunnassa: u kiertää, v pitkin melaa
					st.set_uv(Vector2((k + (1 if j >= 2 else 0)) / float(sides), -v.y / length))
					st.add_vertex(v)
	# Päätyjen kannet
	for end in [[0, 1.0], [rings.size() - 1, -1.0]]:
		var ring: Array = rings[end[0]]
		var center := Vector3(0, ring[0].y, 0)
		for k in sides:
			var a: Vector3 = ring[k]
			var b: Vector3 = ring[(k + 1) % sides]
			for v in ([center, a, b] if end[1] > 0.0 else [center, b, a]):
				st.set_uv(Vector2(0.5, -v.y / length))
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


## Lakattu mänty: vaalea, pitkittäinen syykuvio
func _pine_material() -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.09
	noise.fractal_octaves = 3
	var grain := NoiseTexture2D.new()
	grain.width = 32
	grain.height = 512
	grain.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.74, 0.55, 0.33))
	ramp.set_color(1, Color(0.86, 0.69, 0.47))
	grain.color_ramp = ramp
	var m := StandardMaterial3D.new()
	m.albedo_texture = grain
	m.uv1_scale = Vector3(1.0, 0.05, 1.0) # syy venyy pituussuunnassa
	m.roughness = 0.45
	return m


## Kolmio rungon verkkoon; sisäpinnalle kiertosuunta käännetään
func _add_triangle(st: SurfaceTool, tri: Array, inward: bool) -> void:
	if inward:
		tri = [tri[0], tri[2], tri[1]]
	for v in tri:
		st.add_vertex(v)


# --- Runko -------------------------------------------------------------------

## Lasikuituisen soutuveneen muoto asemittain: z, laidan puolileveys, laidan
## korkeus, köli. Keula on korkea ja viisto, leveimmillään vene on keskeltä.
const HULL_STATIONS := [
	[-2.2, 0.0, 0.64, 0.3], # keulapiikin yläpää: laidat yhtyvät
	[-1.9, 0.3, 0.57, -0.08],
	[-1.5, 0.52, 0.51, -0.19],
	[-1.0, 0.67, 0.47, -0.24],
	[-0.4, 0.745, 0.452, -0.25],
	[0.3, 0.76, 0.448, -0.25],
	[1.0, 0.735, 0.452, -0.24],
	[1.7, 0.68, 0.46, -0.235],
	[2.2, 0.62, 0.47, -0.21], # peräpeili
]
const STRAKES := 4 # limisaumaa jäljittelevät kylkiaskelmat
const STRAKE_STEP := 0.02
const FLOOR_Y := -0.13 # valetun pohjan pinta (pakki ja saavi seisovat tällä)
const FOOT_STEP := 0.0 # keulan jalkataso: etutuhdolla istuvan jalat ja ankkuri
const FOOT_STEP_Z := -1.15 # jalkatason takareuna
const FIBERGLASS := Color(0.93, 0.93, 0.89)
const INSIDE := Color(0.85, 0.8, 0.64)
const RUB_RAIL := Color(0.1, 0.14, 0.3)


func _shiny(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _part(parent: Node3D, mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


func _box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _cyl_mesh(radius: float, height: float, segments := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	return c


## Sylinteri pisteestä a pisteeseen b
func _rod_between(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mi := _part(parent, _cyl_mesh(radius, a.distance_to(b)), (a + b) / 2.0, mat)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.basis = Basis(x, y, x.cross(y))
	return mi


## Rungon mitat kohdassa z: Vector3(laidan puolileveys, laidan korkeus, köli)
func _hull_at(z: float) -> Vector3:
	var st := HULL_STATIONS
	var i := 0
	while i < st.size() - 2 and z > st[i + 1][0]:
		i += 1
	var t := clampf((z - st[i][0]) / (st[i + 1][0] - st[i][0]), 0.0, 1.0)
	var r := Vector3.ZERO
	for c in 3:
		var pre: float = st[maxi(i - 1, 0)][c + 1]
		var post: float = st[mini(i + 2, st.size() - 1)][c + 1]
		r[c] = cubic_interpolate(st[i][c + 1], st[i + 1][c + 1], pre, post, t)
	r.x = maxf(r.x, 0.0)
	return r


## Poikkileikkauksen piste (x, y) kölistä (s = 0) laitaan (s = 1). Pohjan
## V-muoto jyrkkenee keulaa kohti ja loivenee perässä lähes tasaiseksi, ja
## kyljet levenevät ylöspäin.
func _section(z: float, s: float) -> Vector2:
	var h := _hull_at(z)
	var bow := clampf((-0.8 - z) / 1.4, 0.0, 1.0)
	var rise := h.y - h.z
	var aft := clampf((z - 0.8) / 1.4, 0.0, 1.0)
	var p1 := Vector2(h.x * lerpf(0.62, 0.68, aft), h.z + rise * lerpf(lerpf(0.03, 0.3, bow), 0.01, aft))
	var p2 := Vector2(h.x * 0.92, h.z + rise * 0.45)
	var u := 1.0 - s
	return Vector2(0.0, h.z) * u * u * u + p1 * 3.0 * u * u * s + p2 * 3.0 * u * s * s + Vector2(h.x, h.y) * s * s * s


## Ulkopinnan kylkiaskelma: jokaisen kaistan alareuna on ulompana (limisauma)
func _strake(s: float) -> float:
	var u := (s - 0.2) / 0.8 * STRAKES
	if u <= 0.0 or u >= STRAKES:
		return 0.0
	return STRAKE_STEP * (1.0 - fmod(u, 1.0))


## Rungon pinnan piste; ulkopinnalla kylkiaskelmat (side: -1 vasen, 1 oikea)
func _hull_point(z: float, s: float, side: float, outer: bool) -> Vector3:
	var p := _section(z, s)
	if outer:
		var d := _section(z, minf(s + 0.001, 1.0)) - _section(z, maxf(s - 0.001, 0.0))
		var n := Vector2(d.y, -d.x).normalized()
		p += n * _strake(s) * clampf(_hull_at(z).x / 0.25, 0.0, 1.0)
	return Vector3(side * p.x, p.y, z)


## Sisäpinnan puolileveys korkeudella y (0, jos köli on ylempänä)
func _half_width_at(z: float, y: float) -> float:
	var lo := 0.0
	var hi := 1.0
	if _section(z, 0.0).y >= y:
		return 0.0
	if _section(z, 1.0).y <= y:
		return _section(z, 1.0).x
	for k in 20:
		var mid := (lo + hi) / 2.0
		if _section(z, mid).y < y:
			lo = mid
		else:
			hi = mid
	return _section(z, lo).x


## Rungon z-kohdat: tiheämmin keulassa, jossa muoto muuttuu nopeasti
func _hull_rows(count: int) -> Array:
	var zs := []
	for i in count:
		zs.append(-2.2 + 4.4 * pow(i / float(count - 1), 1.3))
	return zs


## Runko poikkileikkauksista (keula -Z, perä +Z): ulkopinta kylkiaskelmineen tai
## sisäpinta, jonka normaalit osoittavat sisään. Peräpeili umpeen.
func _hull_mesh(inward := false) -> Mesh:
	var samples := []
	for i in 25:
		samples.append(i / 24.0)
	if not inward:
		for k in STRAKES: # askelman kohdalle kaksi pistettä, jotta reuna on terävä
			var b := 0.2 + 0.8 * k / STRAKES
			samples.append_array([b - 0.002, b + 0.002])
	samples.sort()
	var sections := []
	for z in _hull_rows(45):
		var row := []
		for i in range(samples.size() - 1, -1, -1):
			row.append(_hull_point(z, samples[i], -1.0, not inward))
		for i in range(1, samples.size()):
			row.append(_hull_point(z, samples[i], 1.0, not inward))
		sections.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in sections.size() - 1:
		var a: Array = sections[i]
		var b: Array = sections[i + 1]
		for j in a.size() - 1:
			for tri in [[a[j], b[j], a[j + 1]], [a[j + 1], b[j], b[j + 1]]]:
				_add_triangle(st, tri, inward)
	var stern: Array = sections[-1]
	var top := Vector3(0, stern[0].y, stern[0].z)
	for j in stern.size() - 1:
		_add_triangle(st, [top, stern[j], stern[j + 1]], inward)
	st.generate_normals()
	return st.commit()


## Laidan reunalista: suorakaideprofiili laidan yläreunan ja ulkopinnan yli
func _rail_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var zs := _hull_rows(41)
	for side in [-1.0, 1.0]:
		var rings := []
		for z in zs:
			var h := _hull_at(z)
			var x: float = side * h.x
			rings.append([
				Vector3(x - side * 0.02, h.y + 0.012, z), Vector3(x + side * 0.022, h.y + 0.012, z),
				Vector3(x + side * 0.022, h.y - 0.035, z), Vector3(x - side * 0.02, h.y - 0.035, z),
			])
		for i in rings.size() - 1:
			for k in 4:
				var a: Vector3 = rings[i][k]
				var b: Vector3 = rings[i][(k + 1) % 4]
				var c: Vector3 = rings[i + 1][(k + 1) % 4]
				var d: Vector3 = rings[i + 1][k]
				for v in [a, b, c, a, c, d]:
					st.add_vertex(v)
	st.generate_normals()
	return st.commit()


## Vaakasuora valettu taso rungon sisällä: korkeus y(z), z-väli from..to
func _deck_mesh(from: float, to: float, height: Callable) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev := []
	for i in 31:
		var z := lerpf(from, to, i / 30.0)
		var y: float = height.call(z)
		var x := maxf(_half_width_at(z, y) - 0.004, 0.0)
		var row := [Vector3(-x, y, z), Vector3(x, y, z)]
		if not prev.is_empty():
			for v in [prev[0], row[0], prev[1], prev[1], row[0], row[1]]:
				st.add_vertex(v)
		prev = row
	st.generate_normals()
	return st.commit()


## Pystysuora valettu seinämä poikkileikkauksen muotoisena korkeuksien y0..y1 välissä
func _bulkhead_mesh(z: float, y0: float, y1: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 8:
		var ya := lerpf(y0, y1, i / 8.0)
		var yb := lerpf(y0, y1, (i + 1) / 8.0)
		var xa := maxf(_half_width_at(z, ya) - 0.004, 0.0)
		var xb := maxf(_half_width_at(z, yb) - 0.004, 0.0)
		var a := [Vector3(-xa, ya, z), Vector3(xa, ya, z), Vector3(xb, yb, z), Vector3(-xb, yb, z)]
		for v in [a[0], a[1], a[2], a[0], a[2], a[3]]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func _build_hull() -> void:
	# Runko: valkoinen kiiltävä lasikuitu, sisäpuoli kermanvärinen. Sisäpuoli on
	# oma verkkonsa, jonka normaalit osoittavat sisään, jotta valaistus on oikein.
	for side in [[false, FIBERGLASS], [true, INSIDE]]:
		var mi := MeshInstance3D.new()
		mi.mesh = _hull_mesh(side[0])
		var m := _material(side[1])
		m.roughness = 0.3
		mi.material_override = m
		hull.add_child(mi)
	_part(hull, _rail_mesh(), Vector3.ZERO, _shiny(RUB_RAIL, 0.35))

	# Valettu pohja, keulakansi ja tuhdot (korkeudet kuten kalastajan istumapaikoissa)
	var molded := _shiny(INSIDE, 0.45)
	_part(hull, _deck_mesh(-2.0, 2.19, func(_z): return FLOOR_Y), Vector3.ZERO, _shiny(INSIDE.darkened(0.08), 0.8))
	_part(hull, _deck_mesh(-2.2, -1.8, func(z): return _hull_at(z).y - 0.02), Vector3.ZERO, molded)
	_part(hull, _deck_mesh(-2.0, FOOT_STEP_Z, func(_z): return FOOT_STEP), Vector3.ZERO, molded)
	_part(hull, _bulkhead_mesh(FOOT_STEP_Z, FLOOR_Y, FOOT_STEP), Vector3.ZERO, molded)
	for z in [-0.9, 0.25, 1.45]:
		var w := minf(_half_width_at(z - 0.15, 0.2), _half_width_at(z + 0.15, 0.2))
		_part(hull, _box_mesh(Vector3(w * 2.0, 0.045, 0.3)), Vector3(0, 0.2025, z), molded)
		_part(hull, _box_mesh(Vector3(w * 2.0 - 0.04, 0.06, 0.02)), Vector3(0, 0.15, z - 0.14), molded) # etureunan helma

	# Peräpeilin moottorilevy ja kromiset hankaimet laidalla
	var stern := _hull_at(2.2)
	_part(hull, _box_mesh(Vector3(0.34, 0.22, 0.02)), Vector3(0, stern.y - 0.11, 2.21), _shiny(Color(0.12, 0.12, 0.13), 0.5))
	var chrome := _shiny(Color(0.82, 0.83, 0.85), 0.2, 0.9)
	for s in [-1.0, 1.0]:
		var w := _hull_at(OARLOCK.z).x
		_part(hull, _box_mesh(Vector3(w - OARLOCK.x + 0.03, 0.012, 0.06)), Vector3(s * (OARLOCK.x + w) / 2.0, OARLOCK.y + 0.018, OARLOCK.z), chrome)
		for dz in [-0.035, 0.035]:
			_part(hull, _cyl_mesh(0.006, 0.07, 8), Vector3(OARLOCK.x * s, OARLOCK.y + 0.055, OARLOCK.z + dz), chrome)
	# Keulan kiinnityslenkki
	var eye := _part(hull, _cyl_mesh(0.02, 0.012, 12), Vector3(0, 0.62, -2.21), chrome)
	eye.rotation.z = PI / 2.0


# --- Perämoottori ------------------------------------------------------------

## Pyöristetty laatikko (superellipsoidi): pienempi e = kulmikkaampi
func _rounded_box_mesh(size: Vector3, e := 0.3) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spow := func(x: float) -> float: return signf(x) * pow(absf(x), e)
	var lat := 12
	var lon := 24
	var grid := []
	for i in lat + 1:
		var v := -PI / 2.0 + PI * i / lat
		var row := []
		for j in lon + 1:
			var u := TAU * j / lon
			var cv: float = spow.call(cos(v))
			row.append(Vector3(cv * spow.call(cos(u)) * size.x, spow.call(sin(v)) * size.y, cv * spow.call(sin(u)) * size.z) / 2.0)
		grid.append(row)
	for i in lat:
		for j in lon:
			for v in [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j], grid[i + 1][j + 1], grid[i][j + 1]]:
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


## Pieni nelitahtinen ohjausaisaperämoottori: musta kopa punaisella raidalla,
## kiinnike peräpeilissä, varsi, kavitaatiolevy, vaihteistokotelo ja
## kolmilapainen potkuri. Ohjauksessa kääntyy _motor (origo kääntöakselilla),
## kiinnike pysyy rungossa.
func _build_motor() -> void:
	var black := _shiny(Color(0.045, 0.045, 0.05), 0.3)
	var dark := _shiny(Color(0.16, 0.16, 0.17), 0.55)
	var rubber := _shiny(Color(0.08, 0.08, 0.08), 0.95)
	var g := _hull_at(2.2).y
	# Kiinnike peräpeilin yli ja kiristysruuvit veneen puolella
	_part(hull, _box_mesh(Vector3(0.17, 0.24, 0.05)), Vector3(0, g - 0.09, 2.245), black)
	_part(hull, _box_mesh(Vector3(0.17, 0.04, 0.12)), Vector3(0, g + 0.02, 2.2), black)
	for x in [-0.05, 0.05]:
		var screw := _part(hull, _cyl_mesh(0.008, 0.08, 8), Vector3(x, g - 0.12, 2.15), dark)
		screw.rotation.x = PI / 2.0
		var handle := _part(hull, _cyl_mesh(0.007, 0.07, 8), Vector3(x, g - 0.12, 2.11), dark)
		handle.rotation.z = PI / 2.0

	_motor = Node3D.new()
	_motor.position = Vector3(0, 0.55, 2.3)
	hull.add_child(_motor)
	_part(_motor, _box_mesh(Vector3(0.1, 0.24, 0.08)), Vector3(0, -0.13, -0.03), black) # kääntöpukki
	# Kopa ja sen alaosa
	_part(_motor, _rounded_box_mesh(Vector3(0.3, 0.3, 0.46)), Vector3(0, 0.2, 0.03), black)
	_part(_motor, _rounded_box_mesh(Vector3(0.23, 0.14, 0.34), 0.5), Vector3(0, 0.03, 0.02), black)
	var red := _shiny(Color(0.75, 0.08, 0.06), 0.4)
	var silver := _shiny(Color(0.7, 0.7, 0.72), 0.3, 0.6)
	for s in [-1.0, 1.0]:
		_part(_motor, _box_mesh(Vector3(0.004, 0.016, 0.3)), Vector3(s * 0.151, 0.19, 0.05), red)
		_part(_motor, _box_mesh(Vector3(0.004, 0.005, 0.26)), Vector3(s * 0.151, 0.172, 0.07), silver)
	_part(_motor, _box_mesh(Vector3(0.14, 0.025, 0.035)), Vector3(0, 0.355, 0.2), dark) # kantokahva
	_part(_motor, _box_mesh(Vector3(0.03, 0.02, 0.06)), Vector3(0.12, 0.04, -0.06), dark) # vaihdevipu
	# Varsi, kavitaatiolevy, vaihteistokotelo, skegi
	_part(_motor, _box_mesh(Vector3(0.075, 0.7, 0.13)), Vector3(0, -0.39, 0.03), black)
	_part(_motor, _box_mesh(Vector3(0.2, 0.012, 0.3)), Vector3(0, -0.745, 0.07), black)
	_part(_motor, _box_mesh(Vector3(0.06, 0.14, 0.12)), Vector3(0, -0.81, 0.03), black)
	var torpedo := _part(_motor, _cyl_mesh(0.042, 0.26), Vector3(0, -0.9, 0.04), black)
	torpedo.rotation.x = PI / 2.0
	var nose := SphereMesh.new()
	nose.radius = 0.042
	nose.height = 0.084
	_part(_motor, nose, Vector3(0, -0.9, -0.09), black)
	_part(_motor, _box_mesh(Vector3(0.012, 0.12, 0.09)), Vector3(0, -0.99, 0.1), black)
	# Potkuri: napa ja kolme kierrettyä lapaa
	_prop = Node3D.new()
	_prop.position = Vector3(0, -0.9, 0.19)
	_motor.add_child(_prop)
	var hub := _part(_prop, _cyl_mesh(0.026, 0.07), Vector3.ZERO, dark)
	hub.rotation.x = PI / 2.0
	for k in 3:
		var arm := Node3D.new()
		arm.rotation.z = TAU * k / 3.0
		_prop.add_child(arm)
		var blade := _part(arm, _rounded_box_mesh(Vector3(0.07, 0.1, 0.008), 0.7), Vector3(0, 0.07, 0), dark)
		blade.rotation.y = 0.6 # lavan nousu
	# Ohjausaisa: nivel kopan edessä, varsi ja kumikahva
	var hinge := _part(_motor, _cyl_mesh(0.035, 0.09), Vector3(0, 0.07, -0.2), black)
	hinge.rotation.z = PI / 2.0
	_rod_between(_motor, Vector3(0, 0.07, -0.2), Vector3(0, 0.2, -0.78), 0.017, black)
	_rod_between(_motor, Vector3(0, 0.2, -0.78), Vector3(0, 0.2, -0.98), 0.023, rubber)
	_part(_motor, _cyl_mesh(0.012, 0.02, 8), Vector3(0, 0.11, -0.25), red) # hätäsammutin

class_name Boat
extends Node3D
## Soutuvene perämoottorilla. Oma yksinkertainen vesifysiikka: työntövoima,
## vastus (pituussuunnassa pieni, sivusuunnassa suuri), tuulen ajelehtiminen,
## ankkuri ja karilleajo järven syvyysdatan perusteella. Perämoottorin potkuri
## ulottuu lähes metrin syvyyteen: matalassa se osuu pohjaan ja voi mennä rikki.

signal message(text: String)
signal sound_event(sound: String, at: Vector3)

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

var angler: Angler
## Talvi: järvi on jäässä, vene piilotetaan ja kalastaja kävelee jäällä
var on_ice := false
const WALK_SPEED := 1.4 # m/s
const RUN_SPEED := 2.8
const TURN_SPEED := 2.2 # rad/s
var _step_dist := 0.0
var hull: Node3D # aaltojen keinuttama osa
var _motor: Node3D
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
	if anchor:
		anchor.stow()
		anchor.visible = not on # ankkuri on veneen mukana talviteloilla
	motor_running = false
	_apply_transform()


func _unhandled_input(event: InputEvent) -> void:
	if on_ice:
		if event.is_action_pressed("motor_toggle") or event.is_action_pressed("anchor_toggle"):
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
			sound_event.emit("motor_start", _stern_position())
			message.emit("Airot veneeseen ja nykäiset käynnistysnarusta...")
	elif event.is_action_pressed("anchor_toggle"):
		toggle_anchor()


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


func _on_anchor_bottom(depth: float) -> void:
	anchored = true
	anchor_point = anchor.xz
	anchor_rope = depth * 2.0 + 2.0 # köyttä noin kaksi kertaa syvyys
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
		_rowing = motor_starting <= 0.0 and _unstow_timer <= 0.0 and (_oar_activity[0] != 0.0 or _oar_activity[1] != 0.0)
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
				_blade_sounds("oar_catch")
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
		var bow_offset := fwd * (LENGTH * 0.47)
		var d := pos + bow_offset - anchor_point
		var depth := lake.depth_at(anchor_point.x, anchor_point.y) + 0.5
		var reach := sqrt(maxf(1.0, anchor_rope * anchor_rope - depth * depth))
		if d.length() > reach:
			var pull := -d.normalized() * (d.length() - reach) * 900.0 - velocity * 250.0
			force += pull
			torque -= bow_offset.x * pull.y - bow_offset.y * pull.x
			# Lähtöyritys ankkuri pohjassa: köysi kiristyy
			if not _rope_warned and (absf(drive) > 0.0 and (motor_running or _rowing)):
				_rope_warned = true
				message.emit("Ankkuriköysi kiristyy – nosta ensin ankkuri (X)")
		elif d.length() < reach - 1.0:
			_rope_warned = false
		torque -= yaw_rate * 300.0

	velocity += force / MASS * dt
	yaw_rate += torque / YAW_INERTIA * dt
	yaw = wrapf(yaw + yaw_rate * dt, -PI, PI)

	var new_pos := pos + velocity * dt
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


## Rungon ääriviiva ylhäältä (paikallinen x oikealle, y perään), samat mitat kuin _hull_mesh
const OUTLINE: Array[Vector2] = [
	Vector2(0.0, -2.2), Vector2(0.4, -1.8), Vector2(0.68, -1.0), Vector2(0.76, 0.0),
	Vector2(0.72, 1.2), Vector2(0.62, 2.2), Vector2(-0.62, 2.2), Vector2(-0.72, 1.2),
	Vector2(-0.76, 0.0), Vector2(-0.68, -1.0), Vector2(-0.4, -1.8),
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
		velocity -= n * v_in * 1.2
		yaw_rate *= 0.6
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
	_animate_oars(dt)


# --- Airot -------------------------------------------------------------------

const OAR_LENGTH := 2.2
const BLADE_OUT := 1.85 # lavan keskikohdan etäisyys hankaimesta
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
	var stowed := motor_running or motor_starting > 0.0
	var f := fmod(_row_phase, 1.0)
	for i in _oars.size():
		var oar: Dictionary = _oars[i]
		var s: float = oar["side"]
		var target: Transform3D
		var feather := 0.0
		if stowed:
			# Pitkittäin tuhtojen päällä, lavat keulaan päin
			target = Transform3D(Basis(Vector3.UP, s * PI / 2.0), Vector3(s * 0.36, 0.25, 1.15))
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
		var rate := 3.5 if stowed or _unstow_timer > 0.0 else 18.0
		pivot.transform = pivot.transform.interpolate_with(target, minf(1.0, dt * rate))
		# Lavan malli on pystyssä; feather 0 = vaakatasossa, PI/2 = pystyssä
		var blade: Node3D = oar["blade"]
		blade.rotation.x = lerp_angle(blade.rotation.x, PI / 2.0 - feather, minf(1.0, dt * rate))


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


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	mi.mesh = mesh
	mi.position = at
	parent.add_child(mi)
	return mi


func _build_visuals() -> void:
	hull = Node3D.new()
	add_child(hull)

	# Runko: ulkopinta valkoinen, sisäpuoli harmaanvihreäksi maalattu. Sisäpuoli on
	# oma verkkonsa, jonka normaalit osoittavat sisään, jotta valaistus on oikein.
	for side in [[false, Color(0.82, 0.84, 0.8)], [true, Color(0.47, 0.44, 0.36)]]:
		var mi := MeshInstance3D.new()
		mi.mesh = _hull_mesh(side[0])
		mi.material_override = _material(side[1])
		hull.add_child(mi)

	var wood := Color(0.55, 0.42, 0.28)
	for z in [-0.9, 0.25, 1.45]:
		_box(hull, Vector3(1.3, 0.05, 0.3), Vector3(0, 0.2, z), wood)
	# Pohjalaudat
	for x in [-0.22, 0.0, 0.22]:
		_box(hull, Vector3(0.18, 0.025, 2.9), Vector3(x, -0.14, 0.15), Color(0.48, 0.37, 0.25))

	# Perämoottori
	_motor = Node3D.new()
	_motor.position = Vector3(0, 0.55, 2.3)
	hull.add_child(_motor)
	_box(_motor, Vector3(0.32, 0.4, 0.45), Vector3(0, 0.15, 0.1), Color(0.15, 0.2, 0.45))
	_box(_motor, Vector3(0.08, 1.1, 0.12), Vector3(0, -0.5, 0.15), Color(0.2, 0.2, 0.2))
	_box(_motor, Vector3(0.05, 0.05, 0.9), Vector3(0, 0.2, -0.5), Color(0.1, 0.1, 0.1)) # ohjausaisa
	_box(_motor, Vector3(0.07, 0.07, 0.16), Vector3(0, 0.2, -0.88), Color(0.05, 0.05, 0.05)) # kahva

	# Airot hankaimissa: vasen (-X) ja oikea (+X). Airon varsi alkaa hieman
	# hankaimen sisäpuolelta (kahva) ja lapa on varren ulkopäässä.
	for s in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(OARLOCK.x * s, OARLOCK.y, OARLOCK.z)
		hull.add_child(pivot)
		var shaft := _box(pivot, Vector3(OAR_LENGTH, 0.045, 0.045), Vector3((OAR_LENGTH / 2.0 - 0.45) * s, 0, 0), wood)
		var blade := _box(pivot, Vector3(0.5, 0.14, 0.02), Vector3(BLADE_OUT * s, 0, 0), wood)
		shaft.name = "Shaft"
		_oars.append({"side": s, "pivot": pivot, "blade": blade})

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


## Kolmio rungon verkkoon; sisäpinnalle kiertosuunta käännetään
func _add_triangle(st: SurfaceTool, tri: Array, inward: bool) -> void:
	if inward:
		tri = [tri[0], tri[2], tri[1]]
	for v in tri:
		st.add_vertex(v)


## Veneen runko poikkileikkauksista: keula -Z, perä +Z
func _hull_mesh(inward := false) -> Mesh:
	var stations := [
		# z, puolileveys, pohjan syvyys
		[-2.2, 0.0, 0.05], # keulapiikki: laidat yhtyvät, ei aukkoa
		[-1.8, 0.4, -0.12],
		[-1.0, 0.68, -0.22],
		[0.0, 0.76, -0.25],
		[1.2, 0.72, -0.24],
		[2.2, 0.62, -0.2],
	]
	var gunwale := 0.45
	var sections := []
	for s in stations:
		var z: float = s[0]
		var w: float = s[1]
		var b: float = s[2]
		var g := gunwale + (0.12 if z < -1.5 else 0.0) # keula hieman korkeampi
		sections.append([
			Vector3(-w, g, z), Vector3(-w * 0.85, b * 0.2, z), Vector3(0, b, z),
			Vector3(w * 0.85, b * 0.2, z), Vector3(w, g, z),
		])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in sections.size() - 1:
		var a: Array = sections[i]
		var b: Array = sections[i + 1]
		for j in a.size() - 1:
			for tri in [[a[j], b[j], a[j + 1]], [a[j + 1], b[j], b[j + 1]]]:
				_add_triangle(st, tri, inward)
	# Peräpeili
	var stern: Array = sections[-1]
	for j in range(1, stern.size() - 1):
		_add_triangle(st, [stern[0], stern[j], stern[j + 1]], inward)
	st.generate_normals()
	return st.commit()

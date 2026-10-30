class_name OtherBoat
extends Node3D
## Vieras vene (OtherBoats): moottorivene tai soutuvene, joka kulkee reittiä
## laiturilta kalapaikalle tai toiselle laiturille. Yksinkertaistettu fysiikka
## samoilla vakioilla kuin pelaajan veneessä (Boat): perämoottorin työntö ja
## ohjausaisa tai airovedot, sama veden vastus. Ohjaus seuraa reittiä ja väistää
## pelaajaa, toisia veneitä ja verkkojen pyykkejä. Moottoriveneen perään jää
## vaahtovana (Wake) ja peräaaltojen historia (wake_wave), joka keinuttaa
## pelaajan venettä.

signal sound_event(sound: String, at: Vector3)

enum State { STARTING, TRAVEL, ANCHORING, FISHING, DOCKED }

const CRUISE_THROTTLE := 0.7 # matkanopeus noin 4,4 m/s
const MOTOR_CRUISE := 4.4 # m/s
const ROW_CRUISE := 1.5 # m/s, pelaajan soutuvauhti
const SLOW_SPEED := 1.5 # m/s: laiturin lähellä, matalassa ja käännöksissä
const MOTOR_START_TIME := 1.6 # s, kuten pelaajan moottorissa
## Väistö: reitti kiertää pelaajan tai toisen veneen vähintään näin kaukaa
const AVOID_RADIUS := {OtherBoats.Kind.MOTOR: 15.0, OtherBoats.Kind.ROW: 6.0}
const AVOID_MARGIN := 4.0
const NEAR_SLOW := 10.0 # pelaaja tätä lähempänä: hiljennetään ja käännytään poispäin
const NEAR_STOP := 4.0 # pelaaja tätä lähempänä: pysähdytään
const BUMP_PAUSE := 3.0 # s törmäyksen jälkeen paikallaan
const ARRIVE_DISTANCE := 2.5
const STUCK_TIME := 90.0 # s ilman etenemistä: vene katoaa, kun pelaaja ei näe
## Runko- ja reunalistavärit: tummanvihreä, harmaa (alumiinin näköinen) ja
## valkoinen punaisella reunalistalla
const COLORS := [
	[Color(0.13, 0.3, 0.19), Color(0.08, 0.09, 0.08)],
	[Color(0.5, 0.52, 0.55), Color(0.22, 0.23, 0.25)],
	[Color(0.93, 0.93, 0.89), Color(0.72, 0.08, 0.06)],
]
const SWELL_DISTANCE := 120.0 # m kamerasta: kauempana vene ei keinu aallokossa

var manager: OtherBoats
var lake: LakeData
var kind := OtherBoats.Kind.MOTOR
var variant := 0
var state := State.TRAVEL

var pos := Vector2.ZERO
var velocity := Vector2.ZERO
var yaw := 0.0 # 0 = keula pohjoiseen (-Z), kuten Boat
var yaw_rate := 0.0
var throttle := 0.0
var tiller := 0.0
var motor_running := false
var anchored := false
var docked := false
## Reitti maailman XZ-pisteinä; päättyy laiturille (dock >= 0) tai kalapaikalle
var route := PackedVector2Array()
var dock := -1
var home_dock := -1 # soutuvene palaa lähtölaiturilleen
var fish_time := 0.0
var home_retry := 0.0 # s: reittiä laiturille ei löytynyt, uusi yritys tämän jälkeen
## Testit: ilman reitin päätä vene ei kalasta eikä pysähdy laituriin, vaan jää paikalleen
var hold_at_end := false

var hull: Node3D
var wake: Wake
var crew: OtherBoatCrew
var _motor: Node3D
var _prop: Node3D
var _oars: Array[Dictionary] = []
var _row_phase := 0.0
var _rowing := false
var _oar_activity := [0.0, 0.0]
var _starting := 0.0
var _pause := 0.0
var _seg := 0 # reitin osa, jota seurataan
var _stuck := 0.0
var _avoid_side := 0.0 # väistön puoli: 1 tai -1 (0 = ei väistetä)
var _wait := 0.0
var _time := 0.0
var _motor_sound: AudioStreamPlayer3D
## Testit: syvin laiturikosketus (m): runko liukuu kantta pitkin kuten pelaajan vene
var dock_push_max := 0.0
## Peräaaltojen historia (sama näytteistys kuin Wake.track): {p, right, speed, t}
var _wave_samples: Array[Dictionary] = []
var _pose_prev: Array[Transform3D] = []
var _pose_now: Array[Transform3D] = []


func setup(boats: OtherBoats, boat_kind: int, at: Vector2, heading: float, color_variant: int) -> void:
	manager = boats
	lake = boats.lake
	kind = boat_kind
	variant = color_variant
	pos = at
	yaw = heading
	hull = Node3D.new()
	add_child(hull)
	var colors: Array = COLORS[variant % COLORS.size()]
	Boat.build_hull(hull, colors[0], colors[1])
	if kind == OtherBoats.Kind.MOTOR:
		var parts := Boat.build_motor(hull)
		_motor = parts[0]
		_prop = parts[1]
	_oars = Boat.build_oars(hull)
	wake = Wake.new()
	add_child(wake)
	crew = OtherBoatCrew.new()
	hull.add_child(crew)
	crew.setup(self, variant)
	if kind == OtherBoats.Kind.MOTOR and manager.audio:
		_motor_sound = manager.audio.other_motor_loop(self)
	_apply_transform()
	_pose_now = [transform, hull.transform]
	_pose_prev = _pose_now


func forward() -> Vector2:
	return Vector2(-sin(yaw), -cos(yaw))


func right() -> Vector2:
	return Vector2(cos(yaw), -sin(yaw))


## Ankkurissa tai laiturissa vene ei liiku törmäyksestä (Boat._boat_collision)
func fixed() -> bool:
	return anchored or docked


## Pelaajan vene törmäsi: nopeuden muutos (liikkuva vene) ja tauko ennen jatkoa
func bumped(dv: Vector2, _at: Vector2) -> void:
	if not fixed():
		velocity += dv
	_pause = BUMP_PAUSE


## Uusi reitti; päättyy laiturille dock (>= 0) tai kalapaikalle (-1)
func set_route(points: PackedVector2Array, end_dock: int) -> void:
	route = points
	dock = end_dock
	_seg = 0
	_wait = 0.0
	_stuck = 0.0
	docked = false
	if anchored:
		anchored = false
		sound_event.emit("anchor_up", Vector3(pos.x, 0.5, pos.y))
	if kind == OtherBoats.Kind.MOTOR and not motor_running:
		state = State.STARTING
		_starting = MOTOR_START_TIME
		sound_event.emit("motor_start", _stern3())
	else:
		state = State.TRAVEL
	crew.set_pose(OtherBoatCrew.Pose.MOTOR if kind == OtherBoats.Kind.MOTOR else OtherBoatCrew.Pose.ROWING)


## Ankkuriin kalastamaan (myös pelin alussa järvellä oleva vene)
func start_fishing(seconds: float) -> void:
	route = PackedVector2Array()
	state = State.FISHING
	anchored = true
	fish_time = seconds
	_stop_motor(false)
	crew.set_pose(OtherBoatCrew.Pose.FISHING)


func _process(_delta: float) -> void:
	if _pose_now.is_empty():
		return
	var f := Engine.get_physics_interpolation_fraction()
	transform = _pose_prev[0].interpolate_with(_pose_now[0], f)
	hull.transform = _pose_prev[1].interpolate_with(_pose_now[1], f)


func _physics_process(dt: float) -> void:
	if not _pose_now.is_empty():
		transform = _pose_now[0]
		hull.transform = _pose_now[1]
	_simulate(dt)
	_pose_prev = _pose_now
	_pose_now = [transform, hull.transform]


func _simulate(dt: float) -> void:
	_time += dt
	_pause -= dt
	home_retry -= dt
	var fwd := forward()
	var side := right()
	var v_fwd := velocity.dot(fwd)
	var v_side := velocity.dot(side)
	var force := Vector2.ZERO
	var torque := 0.0

	if state == State.STARTING:
		_starting -= dt
		if _starting <= 0.0:
			motor_running = true
			state = State.TRAVEL
	elif state == State.FISHING:
		fish_time -= dt
		if fish_time <= 0.0:
			manager.send_home(self)
	var steer := _steer(dt) # [haluttu nopeus, suuntavirhe]
	var want: float = steer[0]
	var err: float = steer[1]

	if kind == OtherBoats.Kind.MOTOR:
		var target := 0.0
		if motor_running and state == State.TRAVEL:
			# Kaasu vastuksen mukaan (13 v² + 10 v) ja korjaus nopeuserosta
			target = clampf((13.0 * want * want + 10.0 * want) / Boat.MOTOR_THRUST + (want - v_fwd) * 0.3, -0.4, 1.0)
			if want <= 0.0:
				target = clampf(-v_fwd * 0.3, -0.4, 0.0) # jarrutus peruutuksella
		throttle = move_toward(throttle, target, 0.6 * dt)
		tiller = move_toward(tiller, clampf(err * 1.8 - yaw_rate * 0.8, -1.0, 1.0) if motor_running else 0.0, 2.5 * dt)
		var angle := tiller * 0.6
		var thrust := Boat.MOTOR_THRUST * throttle if motor_running else 0.0
		force += fwd * thrust * cos(angle)
		torque += thrust * sin(angle) * 2.1 + v_fwd * tiller * 45.0
	else:
		var drive := 0.0
		var turn := 0.0
		if state == State.TRAVEL and want > 0.0:
			drive = clampf(1.0 - absf(err) * 0.9, 0.0, 1.0) * clampf(want / ROW_CRUISE, 0.3, 1.0)
			turn = clampf(err * 2.0 - yaw_rate * 1.5, -1.0, 1.0)
		_oar_activity = [clampf(drive - turn, -1.0, 1.0), clampf(drive + turn, -1.0, 1.0)]
		_rowing = state == State.TRAVEL and (absf(_oar_activity[0]) > 0.05 or absf(_oar_activity[1]) > 0.05)
		if _rowing:
			var before := fmod(_row_phase, 1.0)
			_row_phase += dt / Boat.STROKE_TIME
			var f := fmod(_row_phase, 1.0)
			var power := sin(PI * f / 0.45) if f < 0.45 else 0.0
			var left: float = _oar_activity[0]
			var right_oar: float = _oar_activity[1]
			force += fwd * (left + right_oar) * 0.5 * Boat.ROW_FORCE * power
			torque += (right_oar - left) * 0.5 * Boat.ROW_TURN * power
			if before < 0.45 and f >= 0.45:
				for i in _oars.size():
					if _oar_activity[i] != 0.0:
						var b: Vector3 = _oars[i]["blade"].global_position
						wake.add_swirl(Vector2(b.x, b.z), 1.0 + absf(_oar_activity[i]) * 0.3)
			elif before < 0.93 and f >= 0.93:
				sound_event.emit("oar_catch", _oars[1]["blade"].global_position)
			elif before < 0.95 and f >= 0.95:
				sound_event.emit("oar_stroke", _oars[1]["blade"].global_position)
		else:
			_row_phase = 0.0

	# Veden vastus kuten pelaajan veneessä
	force -= fwd * (v_fwd * absf(v_fwd) * 13.0 + v_fwd * 10.0)
	force -= side * (v_side * absf(v_side) * 180.0 + v_side * 60.0)
	torque -= yaw_rate * (500.0 + absf(v_fwd) * 300.0)
	velocity += force / Boat.MASS * dt
	yaw_rate += torque / Boat.YAW_INERTIA * dt
	if fixed():
		# Ankkurissa ja laiturissa vene pysyy paikallaan
		velocity = velocity.move_toward(Vector2.ZERO, 2.0 * dt)
		yaw_rate = move_toward(yaw_rate, 0.0, 0.5 * dt)
	yaw = wrapf(yaw + yaw_rate * dt, -PI, PI)
	pos += velocity * dt
	var push: Vector2 = Boat.dock_push_at(lake, pos, yaw)[0]
	if push != Vector2.ZERO:
		dock_push_max = maxf(dock_push_max, push.length())
		pos += push
		var n := push.normalized()
		velocity -= n * minf(0.0, velocity.dot(n))

	var stern := pos - fwd * Boat.LENGTH * 0.5
	var speed := velocity.length()
	wake.track(stern, side, speed)
	_record_wave(stern, side, speed)
	if state == State.TRAVEL:
		_stuck = _stuck + dt if speed < 0.2 and _pause <= 0.0 else 0.0
	_animate(dt)
	_apply_transform()
	if _motor_sound:
		manager.audio.drive_motor(_motor_sound, motor_running, throttle, dt)


## Reitin seuraus: tähtäyspiste reitillä hieman edellä, nopeus tilanteen mukaan,
## väistö. Palauttaa [haluttu nopeus, suuntavirhe (rad, + = vasemmalle)].
func _steer(dt: float) -> Array:
	if state != State.TRAVEL or route.size() < 2:
		return [0.0, 0.0]
	# Edetään reitin osalta seuraavalle, kun vene on ohittanut osan pään
	while _seg < route.size() - 2:
		var a := route[_seg]
		var b := route[_seg + 1]
		var t := (pos - a).dot(b - a) / maxf(0.01, (b - a).length_squared())
		if t < 1.0 and pos.distance_to(b) > 6.0:
			break
		_seg += 1
	var end := route[route.size() - 1]
	var left_m := pos.distance_to(route[_seg + 1])
	for i in range(_seg + 1, route.size() - 1):
		left_m += route[i].distance_to(route[i + 1])
	if left_m < ARRIVE_DISTANCE:
		_arrive()
		return [0.0, 0.0]
	var cruise := MOTOR_CRUISE if kind == OtherBoats.Kind.MOTOR else ROW_CRUISE
	var want := cruise
	# Moottorivene hiljaa laiturin lähellä ja matalassa (laiturin ja syvän veden väli)
	if kind == OtherBoats.Kind.MOTOR and (manager.in_approach(kind, pos) or manager.near_berth(pos, 30.0)):
		want = SLOW_SPEED
	want = minf(want, maxf(0.5, left_m * 0.25)) # perillä pysähdytään
	var target := _lookahead(maxf(6.0, velocity.length() * 2.5))
	var dir := (target - pos).normalized()
	# Laiturilla on pelaaja: odotetaan kauempana, kunnes laituri vapautuu
	var player := manager.player_pos()
	if dock >= 0 and left_m < 40.0 and player.distance_to(end) < AVOID_RADIUS[kind]:
		_wait += dt
		if _wait > 60.0:
			manager.send_home(self, dock)
		return [0.0, 0.0]
	var avoid := _avoid(dir)
	dir = avoid[0]
	# Pelaaja aivan vieressä: hiljennetään ja käännytään poispäin, lähellä pysähdytään
	var dp := player.distance_to(pos)
	if dp < NEAR_STOP:
		want = 0.0
	elif dp < NEAR_SLOW:
		want = minf(want, 1.0)
		var away := (pos - player).normalized()
		if dir.dot(away) < 0.3:
			dir = (dir + away * 1.5).normalized()
	var err := wrapf(atan2(-dir.x, -dir.y) - yaw, -PI, PI)
	if absf(err) > 0.6:
		want = minf(want, SLOW_SPEED)
	if _pause > 0.0:
		want = 0.0
	return [want, err]


## Piste reitillä matkan ahead päässä veneen kohdalta eteenpäin
func _lookahead(ahead: float) -> Vector2:
	var a := route[_seg]
	var b := route[_seg + 1]
	var t := clampf((pos - a).dot(b - a) / maxf(0.01, (b - a).length_squared()), 0.0, 1.0)
	var p := a.lerp(b, t)
	var left := ahead
	var i := _seg
	while i < route.size() - 1:
		var seg_end := route[i + 1]
		var d := p.distance_to(seg_end)
		if d >= left:
			return p + (seg_end - p).normalized() * left
		left -= d
		p = seg_end
		i += 1
	return route[route.size() - 1]


## Väistö: jos pelaaja, toinen vene tai verkon pyykki on edessä kulkusuunnassa
## lähempänä kuin väistösäde, ohjataan säteen tangentin suuntaan esteen
## vastakkaiselle puolelle (puoli pysyy samana, kunnes este on ohitettu) tai
## toiselle puolelle, jos vesi ei sillä puolella riitä. Palauttaa [suunta, väistetäänkö].
func _avoid(dir: Vector2) -> Array:
	var look := 70.0 if kind == OtherBoats.Kind.MOTOR else 25.0
	var best: Array = []
	var best_d := INF
	for o in manager.obstacles_for(self):
		var at: Vector2 = o[0]
		var r: float = o[1] + AVOID_MARGIN
		var rel := at - pos
		var d := rel.length()
		if d > look + r or d >= best_d:
			continue
		if (rel.dot(dir) > 0.0 and absf(rel.cross(dir)) < r) or d < r:
			best = [at, r]
			best_d = d
	if best.is_empty():
		_avoid_side = 0.0
		return [dir, false]
	var rel: Vector2 = best[0] - pos
	var r: float = best[1]
	var rel_n := rel.normalized()
	if best_d <= r:
		# Liian lähellä: poispäin esteestä reitin suuntaan kallistuen
		return [(dir - rel_n * 1.5).normalized(), true]
	if _avoid_side == 0.0:
		# Este reitin vasemmalla puolella: ohitetaan oikealta ja päinvastoin
		var obstacle_side := signf(dir.cross(rel))
		_avoid_side = -obstacle_side if obstacle_side != 0.0 else 1.0
	var ang := asin(clampf(r / best_d, 0.0, 1.0))
	for k in 2:
		var side := _avoid_side * (1.0 if k == 0 else -1.0)
		# Tangentti, jota pitkin este jää puolelle -side
		var t := rel_n.rotated(ang)
		if -signf(t.cross(rel)) != side:
			t = rel_n.rotated(-ang)
		if manager.navigable(kind, pos + t * 15.0):
			_avoid_side = side
			return [t, true]
	return [dir, true]


## Laiturissa: odotetaan katoamista (OtherBoats poistaa, kun pelaaja ei näe)
func moor(dock_index: int) -> void:
	dock = dock_index
	route = PackedVector2Array()
	state = State.DOCKED
	docked = true
	anchored = false
	_stop_motor(true)
	crew.set_pose(OtherBoatCrew.Pose.MOTOR if kind == OtherBoats.Kind.MOTOR else OtherBoatCrew.Pose.ROWING)


func _arrive() -> void:
	if hold_at_end:
		state = State.ANCHORING
		_stop_motor(true)
		return
	if dock >= 0:
		moor(dock)
	else:
		state = State.ANCHORING
		_stop_motor(true)
		anchored = true
		fish_time = manager.fishing_time()
		state = State.FISHING
		sound_event.emit("anchor_drop", Vector3(pos.x, 0.5, pos.y))
		crew.set_pose(OtherBoatCrew.Pose.FISHING)


func _stop_motor(sound: bool) -> void:
	throttle = 0.0
	if motor_running and sound:
		sound_event.emit("motor_stop", _stern3())
	motor_running = false


func _stern3() -> Vector3:
	var s := pos - forward() * Boat.LENGTH * 0.5
	return Vector3(s.x, 0.5, s.y)


# --- Peräaallot ----------------------------------------------------------------

func _record_wave(stern: Vector2, side: Vector2, speed: float) -> void:
	while not _wave_samples.is_empty() and _time - _wave_samples[0]["t"] > OtherBoats.WAKE_HISTORY:
		_wave_samples.pop_front()
	if speed < OtherBoats.WAKE_MIN_SPEED:
		return
	if _wave_samples.is_empty() or _wave_samples[-1]["p"].distance_to(stern) >= Wake.SAMPLE_DISTANCE:
		_wave_samples.append({"p": stern, "right": side, "speed": speed, "t": _time})


## Peräaalto kohdassa p: Kelvinin hajaantuvien aaltojen ryhmä, joka saapuu, kun
## vanan V-haara (Wake.KELVIN_SPREAD) ehtii p:n kohdalle. Aallot kulkevat 35°:n
## kulmassa veneen kulkusuunnasta, aallonpituus ja jakso nopeuden mukaan
## (λ = 2π (v cos 35°)² / g), noin 4–5 harjaa. Korkeus vaimenee etäisyyden
## (d^-1/3) ja ajan mukaan. Palauttaa {} tai {at, dir, k, omega, since, amp}.
func wake_wave(p: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_along := 1.0
	for s in _wave_samples:
		var right_s: Vector2 = s["right"]
		var rel: Vector2 = p - s["p"]
		var along := absf(rel.dot(Vector2(right_s.y, -right_s.x)))
		if along < best_along:
			best_along = along
			best = s
	if best.is_empty():
		return {}
	var right_s: Vector2 = best["right"]
	var lateral: float = (p - best["p"]).dot(right_s)
	var dist := absf(lateral)
	var speed: float = best["speed"]
	var age_arrive := maxf(0.0, dist - 0.6) / (speed * Wake.KELVIN_SPREAD)
	var since: float = _time - best["t"] - age_arrive
	var c := speed * cos(OtherBoats.KELVIN_DIVERGENT) # aallon vaihenopeus
	var k := OtherBoats.GRAVITY / (c * c)
	var omega := OtherBoats.GRAVITY / c
	var duration := OtherBoats.WAKE_CRESTS * TAU / omega
	if since < 0.0 or since > duration:
		return {}
	var ref_age := (OtherBoats.WAKE_REF - 0.6) / (MOTOR_CRUISE * Wake.KELVIN_SPREAD)
	var amp := OtherBoats.WAKE_HEIGHT * smoothstep(OtherBoats.WAKE_MIN_SPEED, MOTOR_CRUISE, speed)
	amp *= minf(1.5, pow(maxf(dist, 4.0) / OtherBoats.WAKE_REF, -1.0 / 3.0))
	amp *= minf(1.0, exp(-(age_arrive - ref_age) / OtherBoats.WAKE_FADE))
	amp *= sin(PI * since / duration) # ryhmän verho: harjat voimistuvat ja hiipuvat
	var fwd_s := Vector2(right_s.y, -right_s.x)
	var out := right_s * signf(lateral)
	var dir := fwd_s * cos(OtherBoats.KELVIN_DIVERGENT) + out * sin(OtherBoats.KELVIN_DIVERGENT)
	return {"at": p, "dir": dir, "k": k, "omega": omega, "since": since, "amp": amp}


# --- Ulkonäkö -------------------------------------------------------------------

func _apply_transform() -> void:
	position = Vector3(pos.x, 0.0, pos.y)
	rotation = Vector3(0.0, yaw, 0.0)


func _animate(dt: float) -> void:
	# Lähivedessä vene keinuu aallokossa kuten pelaajan vene, kauempana vesi on tasaista
	var fwd := forward()
	var side := right()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var near := cam != null and cam.global_position.distance_to(global_position) < SWELL_DISTANCE
	var h_bow := Waves.swell_height(pos + fwd * Boat.LENGTH * 0.45) if near else 0.0
	var h_stern := Waves.swell_height(pos - fwd * Boat.LENGTH * 0.45) if near else 0.0
	var h_left := Waves.swell_height(pos - side * 0.7) if near else 0.0
	var h_right := Waves.swell_height(pos + side * 0.7) if near else 0.0
	var h_mid := Waves.swell_height(pos) if near else 0.0
	var planing := clampf(velocity.dot(fwd) * 0.012 * throttle, -0.05, 0.06)
	var heel := clampf(yaw_rate * velocity.length() * 0.05, -0.08, 0.08)
	hull.position.y = lerpf(hull.position.y, h_mid, minf(1.0, dt * 6.0))
	hull.rotation.x = lerpf(hull.rotation.x, atan2(h_bow - h_stern, Boat.LENGTH * 0.9) + planing, minf(1.0, dt * 4.0))
	hull.rotation.z = lerpf(hull.rotation.z, atan2(h_left - h_right, 1.4) + heel, minf(1.0, dt * 4.0))
	if _motor:
		_motor.rotation.y = -tiller * 0.6
		if motor_running:
			_motor.position.y = 0.55 + sin(_time * 60.0) * 0.004
			_prop.rotation.z += dt * 45.0 * signf(throttle)
	_animate_oars(dt)
	if crew:
		var lean := 0.0
		if _rowing:
			var f := fmod(_row_phase, 1.0)
			lean = lerpf(-0.35, 0.25, f / 0.45) if f < 0.45 else lerpf(0.25, -0.35, (f - 0.45) / 0.55)
		crew.torso_lean = lerpf(crew.torso_lean, lean, minf(1.0, dt * 8.0))


## Airot: soudettaessa samaa vetorytmiä kuin pelaajalla (Boat._stroke_pose),
## moottorilla ja kalastaessa airot ovat veneessä
func _animate_oars(dt: float) -> void:
	var stowed := kind == OtherBoats.Kind.MOTOR or state == State.FISHING or state == State.DOCKED
	var f := fmod(_row_phase, 1.0)
	for i in _oars.size():
		var oar: Dictionary = _oars[i]
		var s: float = oar["side"]
		var target: Transform3D
		var feather := 0.0
		if stowed:
			target = Transform3D(Basis(Vector3.UP, s * PI / 2.0), Vector3(s * 0.36, 0.25, 1.15))
		else:
			var activity: float = _oar_activity[i] if _rowing else 0.0
			var sweep := 0.0
			var dip := deg_to_rad(15.0)
			if activity != 0.0:
				var pose := Boat._stroke_pose(f)
				sweep = pose[0] * signf(activity)
				dip = pose[1]
				feather = pose[2]
			var basis := Basis(Vector3.UP, -s * sweep) * Basis(Vector3.BACK, -s * dip)
			target = Transform3D(basis, Vector3(Boat.OARLOCK.x * s, Boat.OARLOCK.y, Boat.OARLOCK.z))
		var pivot: Node3D = oar["pivot"]
		var rate := 3.5 if stowed else 18.0
		pivot.transform = pivot.transform.interpolate_with(target, minf(1.0, dt * rate))
		var roll: Node3D = oar["roll"]
		roll.rotation.x = lerp_angle(roll.rotation.x, PI / 2.0 - feather, minf(1.0, dt * rate))


## Airojen kahvat maailmassa: [vasen, oikea] (kuten Boat.oar_handles)
func oar_handles() -> Array:
	var handles := []
	for oar in _oars:
		var s: float = oar["side"]
		handles.append(oar["pivot"].global_transform * Vector3(-0.38 * s, 0, 0))
	return handles


## Ohjausaisan kahva maailmassa (kuten Boat.tiller_handle); soutuveneessä polvella
func tiller_handle() -> Vector3:
	if _motor:
		return _motor.global_transform * Vector3(0, 0.2, -0.88)
	return crew.global_transform * Vector3(0.14, 0.12, -0.4)

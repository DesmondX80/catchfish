extends Node
## Vetouistelun testi: godot --headless --fixed-fps 30 -- --day=180 --trolltest [--trolltest-shots=KANSIO]
## Lusikka vapaan 1 ja vaappu vapaan 2, molemmat R:llä telineisiin, soudetaan.
## Telinevapaan tulee tärppi, vapa otetaan R:llä käteen, kala väsytetään ja
## haavitaan. Lopuksi toinen vapa otetaan telineestä ja kelataan sisään.

const LINE := 20.0

var main: Node
var _log: Array[String] = []
var _messages: Array[String] = []
var _step := 0
var _t := 0.0
var _spot := Vector2.ZERO
var _dir := Vector2.ZERO
var _forced := 0
var _catches := []
var _identified := false
var _landing_checked := false
var _shots := ""
var _shot_done := {}


func _ready() -> void:
	main = get_parent()
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	main.fishing.message.connect(func(t): _messages.append(t))
	main.fishing.caught.connect(func(e, _r): _catches.append(e))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--trolltest-shots="):
			_shots = arg.split("=")[1]
	for f in main.population.fish:
		f["wary"] = 1.0e9 # tärppi tehdään testissä itse
	_find_spot()
	var boat: Boat = main.boat
	boat.pos = _spot
	boat.velocity = Vector2.ZERO
	boat.yaw = atan2(-_dir.x, -_dir.y)
	boat._apply_transform()
	main.camera_rig.yaw = boat.yaw + PI


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _press(action: String, pressed := true) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


## Kuvakaappaus kameran asennosta (suunta veneeseen nähden, korkeus, etäisyys)
func _shot(name: String, yaw: float, pitch: float, distance: float) -> void:
	if _shots == "":
		return
	var rig: CameraRig = main.camera_rig
	rig.yaw = main.boat.yaw + yaw
	rig.pitch = pitch
	rig.distance = distance
	if fmod(_t, 4.0) > 1.5 and not _shot_done.has(name):
		_shot_done[name] = true
		get_viewport().get_texture().get_image().save_png(_shots.path_join(name + ".png"))


func _tap(action: String) -> void:
	_press(action)
	_press(action, false)


func _next() -> void:
	_step += 1
	_t = 0.0


## Syvä, suora vesialue soutamiseen
func _find_spot() -> void:
	var lake: LakeData = main.lake
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var best := -1.0
	var origin := Vector2(lake.start_position.x, lake.start_position.z)
	for i in 6000:
		var p := origin + Vector2(rng.randf_range(-1500, 1500), rng.randf_range(-1500, 1500))
		var d := Vector2.from_angle(rng.randf() * TAU)
		var shallowest := 99.0
		for s in range(-30, 70, 4):
			var q := p + d * s
			shallowest = minf(shallowest, lake.depth_at(q.x, q.y) if lake.is_water(q.x, q.y) else 0.0)
		if shallowest > best:
			best = shallowest
			_spot = p
			_dir = d
	print("Testipaikka: matalin kohta %.1f m" % best)


## Uistin veneen perään siima kireällä (kuin heitetty ja kelattu suoraksi)
func _lure_behind(side: float) -> void:
	var f: Fishing = main.fishing
	var boat: Boat = main.boat
	var at := boat.pos - boat.forward() * LINE + boat.right() * side
	f.state = Fishing.State.RETRIEVING
	f.lure_pos = Vector3(at.x, -0.5, at.y)
	f._prev_lure = f.lure_pos
	f.line_out = f.rod_tip().distance_to(f.lure_pos)


func _physics_process(delta: float) -> void:
	_t += delta
	var f: Fishing = main.fishing
	var boat: Boat = main.boat
	if _step <= 4:
		Input.action_press("boat_forward") # vene liikkeelle ennen uistinten laskua, ettei lusikka vajoa pohjaan
	match _step:
		0:
			if _t > 3.0:
				f.lure_index = 0 # lusikka
				_lure_behind(1.5)
				_next()
		1:
			if _t > 0.2:
				_tap("rod_holder")
				_next()
		2:
			if _t > 0.2:
				_check("vapa 1 telineeseen, vapa 2 käteen", f.held == 1 and f.holder_rods().size() == 1 and not f.in_holder)
				_check("kalastaja ei ole kiinni telinevavassa", not f.busy())
				f.lure_index = 1 # kelluva vaappu
				_lure_behind(-1.5)
				_next()
		3:
			if _t > 0.2:
				_tap("rod_holder")
				_next()
		4:
			if _t > 0.2:
				_check("molemmat vavat telineissä, kädet vapaina", f.hands_free() and f.holder_rods().size() == 2)
				var lures := f.holder_rods().map(func(r): return r["lure"])
				_check("telineissä eri uistimet: %s" % ", ".join(lures), lures[0] != lures[1])
				_next()
		5:
			Input.action_press("boat_forward")
			# Kuvat soudun aikana; ikkunassa piirto on hidasta, joten kuva-ajo loppuu tähän
			if _shots != "":
				_shot("v1-vetouistelu" if _t < 4.0 else "v2-vapatelineet", 2.4 if _t < 4.0 else PI - 0.5, 0.35 if _t < 4.0 else 0.25, 7.0 if _t < 4.0 else 3.0)
				if _t > 4.0 and _t < 4.1:
					_shot_done.erase("v2-vapatelineet")
				if _t > 6.0:
					_finish()
					return
			if _t > 25.0:
				var rods := f.holder_rods()
				_check("soudetaan: %.1f km/h, asento %s" % [boat.speed_kmh(), Angler.Pose.keys()[boat.angler.pose]], boat.speed_kmh() > 2.0 and boat.angler.pose == Angler.Pose.ROWING)
				for i in 2:
					var speed: float = f._rod_get(i, "lure_speed")
					_check("vapa %d: %s kulkee perässä %.2f m/s, %.1f m syvyydessä, siimaa %.0f m" % [i + 1, rods[i]["lure"], speed, rods[i]["depth"], rods[i]["line"]], speed > 0.4 and rods[i]["state"] == Fishing.State.RETRIEVING)
				_check("lusikka ui uistellessa 1,5 m syvyydessä (%.2f m)" % rods[0]["depth"], absf(rods[0]["depth"] - 1.5) < 0.2)
				_check("vaappu ui tavoitesyvyydessä", absf(rods[1]["depth"] - 1.6) < 0.3)
				_force_bite(0)
				_next()
		6:
			Input.action_press("boat_forward")
			var st: int = f._rod_get(0, "state")
			if st == Fishing.State.FIGHT:
				_check("telinevapaan tarttui kala itsestään (%d. tärppi)" % _forced, true)
				_check("viestissä vavan numero: \"%s\"" % _messages[-1], _messages[-1].begins_with("Vapa 1:"))
				_check("HUD kehottaa ottamaan vavan", f.alert_rod() == 0)
				_next()
			elif st == Fishing.State.RETRIEVING:
				if _forced >= 8:
					_check("telinevavan kala ei koskaan tarttunut", false)
					_finish()
				else:
					_force_bite(0)
		7:
			if _t > 1.0:
				_press("boat_forward", false)
				_tap("rod_holder")
				_next()
		8:
			if _t > 0.2:
				_check("R otti tärppäävän vavan 1 käteen kesken soudun", f.held == 0 and not f.in_holder and f.state == Fishing.State.FIGHT)
				_check("vapa 2 jäi telineeseen", f.holder_rods().size() == 1 and f.holder_rods()[0]["number"] == 2)
				_check("kalastaja väsyttää", boat.angler.pose == Angler.Pose.FISHING)
				_check("kaukana olevan kalan lajia ei tunnista: \"%s\"" % f.fish_name(), f.fish_name() == "Kala")
				_press("reel")
				_next()
		9:
			# Väsytys: kelataan ja haavitaan, kun kala on veneen vieressä
			Input.action_press("reel")
			_shot("v3-vasytys-telineesta", 2.0, 0.3, 6.0)
			if f.landing_ready() and not _identified:
				_identified = true
				_check("laji tunnistettiin veneen vieressä: %s" % f.fish_name(), f.fish_name() != "Kala")
				_check("kalastaja huusi lajin: \"%s\"" % main.hud._speech.text, main.voice.last_line == "fish_" + f._fish["sp"])
			if f.landing_ready() and f.fish_stamina() < 0.35:
				_press("reel", false)
				_tap("cast")
			if f.state == Fishing.State.LANDING and not _landing_checked and f._landing_net.t > 1.8:
				_landing_checked = true
				var net := f._landing_net
				var cam: Camera3D = main.camera_rig.camera
				var cam_dist := cam.global_position.distance_to(boat.global_position)
				_check("haavinnan kamera veneen vierellä (%.1f m)" % cam_dist, cam_dist < 5.0 and main.camera_rig.shot_view)
				_check("nostossa molemmat kädet haavin varressa", net.grips().size() == 2 and f.net_active())
				_check("kala nousee haavissa veden yläpuolelle (%.2f m)" % net._fish.global_position.y, net._fish.visible and net._fish.global_position.y > 0.0)
			if f.state == Fishing.State.LANDED:
				_check("haavinnan jälkeen kamera palaa", not main.camera_rig.shot_view)
				_check("kala haavittu: %s" % (_catches[0]["name"] if _catches.size() > 0 else "?"), _catches.size() == 1)
				_next()
			elif f.state != Fishing.State.FIGHT and f.state != Fishing.State.LANDING:
				_check("kala karkasi väsytyksessä (%s)" % _messages[-1], false)
				_finish()
			elif _t > 180.0:
				_check("väsytys kesti liian kauan", false)
				_finish()
		10:
			_shot("v4-saalis", 1.2, 0.5, 4.0)
			if _t > (2.0 if _shots != "" else 0.5):
				_tap("cast") # saalis pois haavista
				_next()
		11:
			if _t > 0.2:
				_tap("rod_holder")
				_next()
		12:
			if _t > 0.2:
				_check("vapa 1 veneeseen, vapa 2 telineestä käteen", f.held == 1 and not f.in_holder and f.holder_rods().is_empty())
				_press("reel")
				_next()
		13:
			Input.action_press("reel")
			if f.state == Fishing.State.READY:
				_press("reel", false)
				_check("vapa 2 kelattu sisään (%.0f s)" % _t, true)
				_finish()
			elif _t > 60.0:
				_check("vapaa 2 ei saatu kelattua sisään (tila %d)" % f.state, false)
				_finish()


## Tärppi telinevapaan: kuin kala olisi iskenyt uistimeen
func _force_bite(rod: int) -> void:
	var f: Fishing = main.fishing
	var pop: FishPopulation = main.population
	var at: Vector3 = f._rod_get(rod, "lure_pos")
	var best := -1
	for i in pop.fish_near(Vector2(at.x, at.z), 60.0):
		var w: float = pop.fish[i]["weight"]
		if w > 0.4 and w < 2.0:
			best = i
			break
	if best < 0:
		best = 0
	var cur := f.held
	f._swap_to(rod)
	f._fish_index = best
	f._fish = pop.fish[best]
	f.state = Fishing.State.BITE
	f._bite_timer = 0.3
	if cur >= 0:
		f._swap_to(cur)
	_forced += 1


func _finish() -> void:
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

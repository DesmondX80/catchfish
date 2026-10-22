class_name Fishing
extends Node3D
## Virvelillä kalastus: heitto, uistimen uinti, tärppi ja vastaisku,
## väsytys jarrulla sekä haavinta.
##
## Veneessä on kaksi vapaa. Heitellessä käytetään yhtä, vetouistelussa
## molempia: heitetty vapa laitetaan R-näppäimellä vapatelineeseen ja
## toinen otetaan käteen. Vavan tila on tämän solmun muuttujissa
## (ROD_VARS), ja ne vaihdetaan sen mukaan, mitä vapaa käsitellään.

signal message(text: String)
signal caught(entry: Dictionary, record: bool)
signal sound_event(sound: String, at: Vector3)
signal lure_lost(lure_id: String)
## Kalastajan repliikin aihe (angler_voice.gd): bite, hooked, lost, snap, snag,
## shore, landed, big, small, hole, fish_<laji> (laji tunnistettu)
signal voice(event: String)

enum State { READY, CHARGING, FLYING, RETRIEVING, BITE, FIGHT, LANDED, DRILLING, LANDING }

const ROD_LENGTH := 2.1
const ROD_SEGMENTS := 16
const ROD_POWER := 1.4 # kg: tällä vedolla kärki taipuu n. 2/3 maksimistaan
const ROD_MAX_BEND := 1.75 # rad, kärjen suurin taipuma
const ROD_STIFFNESS := 160.0 # jousivakio taipuman dynamiikalle
const ROD_DAMPING := 7.0 # pieni vaimennus: kärki värähtää hetken
const LINE_WEIGHT := 0.004 # N/m: siiman paino ja tuulen työntö roikkumalle
const LINE_STRENGTH := 6.5 # kg, 0,28 mm monofiili
const REEL_SPEED := 0.85 # m/s
const REEL_SPEED_FAST := 1.6
const CAST_ANGLE := deg_to_rad(32.0)
const SINK_MIN_DEPTH := 0.3 # m: vedettävä lusikka/lippa pysyy vähintään tässä syvyydessä
const SINK_MAX_RISE := 0.3 # m/s: uppoavan uistimen suurin nousunopeus
const RUN_MIN_SPEED := 0.15 # m/s: tätä hitaammin lusikka vajoaa kohti pohjaa
const RUN_FULL_SPEED := 0.45 # m/s: tällä nopeudella lusikka ui uintisyvyydessään
const DIVE_FULL_SPEED := 0.5 # m/s: tällä nopeudella vaappu ui tavoitesyvyydessään
const DIVE_PER_METER := 0.35 # vaapun sukellus (m) vedettyä metriä kohden
const GRAVITY := 9.81
const ROD_COUNT := 2
## Koukussa olevan kalan lajin tunnistaa vasta, kun kala näkyy humusvedessä:
## lähellä venettä ja pinnan tuntumassa (jäällä avannon suulla)
const IDENTIFY_DISTANCE := 6.0 # m veneestä
const IDENTIFY_DEPTH := 1.5 # m
const IDENTIFY_SPLASH := 15.0 # m: pinnassa rimpuileva kala tunnistetaan kauempaakin
## Hauen seuranta (#17): osa kaukana veneestä tulevista hauen iskuista muuttuu
## seurannaksi, ja seuraaja iskee yleensä viime hetkellä veneen vieressä
const FOLLOW_CHANCE := 0.6
const FOLLOW_MIN_DISTANCE := 7.0 # m: uistin vähintään näin kaukana vavan kärjestä
const FOLLOW_STRIKE_CHANCE := 0.65 # iskee tasaisesti kelattuun uistimeen
const FOLLOW_TWITCH_CHANCE := 0.45 # nykäisy veneen lähellä saa iskemään
const FOLLOW_STOP_SPEED := 0.25 # m/s: kelaamatta tätä hitaampi uistin on pysähtynyt (vajoaa)
const FOLLOW_FAST_SPEED := 1.3 # m/s: tätä nopeampaa hauki ei jaksa seurata
## Käyttämätön vapa veneen pohjalla vasemmalla laidalla, kärki keulaan
const SPARE_ROD := Transform3D(Basis.IDENTITY, Vector3(-0.45, 0.27, 1.25))
## Vapakohtaiset muuttujat: tallennetaan vavan vaihtuessa
const ROD_VARS := [
	"state", "in_holder", "lure_index", "power", "line_out", "tension", "drag_slipping",
	"lure_pos", "lure_speed", "lure_on_land", "snagged", "_lure_vel", "_prev_lure",
	"_twitch", "_bite_timer", "_check_timer", "_fish_index", "_fish", "_fish_pos",
	"_stamina", "_run_timer", "_run_dir", "_run_intensity", "_slack_time",
	"_landing_prompt", "_fish_known", "_rod_pivot", "_rod_pitch", "_rod_mesh", "_rod_points",
	"_tip_world", "_bend", "_bend_vel", "_bend_dir", "_reel_handle", "_line_mesh",
	"_lure_node", "_fish_node", "_bobber_node", "_worm_node", "float_depth",
]

var boat: Boat
var camera_rig: CameraRig
var lake: LakeData
var population: FishPopulation
var weather: Weather
var sky: SkyTime

var state := State.READY
## Vetouistelu: tämä vapa on vapatelineessä
var in_holder := false
## Kädessä olevan vavan numero (0..1), -1 = molemmat vavat telineissä
var held := 0
var _rods: Array[Dictionary] = []
var _holders: Node3D
## Heiton tähtäin: {point, water, distance, ground} heittoa ladatessa, muuten tyhjä
var cast_preview: Dictionary = {}
var _aim_marker: MeshInstance3D
var _aim_material: StandardMaterial3D
var _aim_arc: ImmediateMesh
var _aim_arc_node: MeshInstance3D
var _cur := 0 # vapa, jonka tila on nyt muuttujissa
## Talvi: pilkkiminen avannosta (jäällä ei heitetä, vaan kairataan reikä)
var on_ice := false
var rod_length := ROD_LENGTH
var holes: Array[Vector3] = []
var current_hole := Vector3.INF
## Uramoodi: uistinvarasto (id -> kpl). Tyhjä = vapaa kalastus, kaikki uistimet käytössä.
var inventory: Dictionary = {}
var limited := false
const HOLE_AHEAD := 0.75 # avanto kalastajan edessä (m)
const DRILL_TIME := 3.0 # s
var _auger: Node3D
# Haavinta (animaatio: landing_net.gd)
var _landing_net: LandingNet
var _landing_entry: Dictionary = {}
var _landing_record := false
var _landing_species := ""
var _landing_weight := 0.0
var _holes_node: Node3D
var lure_index := 0
var drag_kg := 3.0
var power := 0.0
var line_out := 0.0
var tension := 0.0
var drag_slipping := false
var lure_pos := Vector3.ZERO
var lure_speed := 0.0
var lure_on_land := false
var snagged := false
var lost_lures := 0

var _lure_vel := Vector3.ZERO
var _prev_lure := Vector3.ZERO
var _twitch := 0.0
var _bite_timer := 0.0
var _check_timer := 0.0
var _fish_index := -1
var _fish: Dictionary = {}
var _fish_pos := Vector3.ZERO
var _stamina := 1.0
var _run_timer := 0.0
var _run_dir := Vector2.ZERO
var _run_intensity := 0.0
var _slack_time := 0.0
var _landing_prompt := false
var _fish_known := false # koukussa olevan kalan laji tunnistettu
## Uistinta seuraava hauki: {rod, index, sp, weight, pos, heading, speed, ...}, tyhjä = ei seuraajaa
var follower: Dictionary = {}
var _last_catch: Dictionary = {}
var _rng := RandomNumberGenerator.new()

var _rod_pivot: Node3D
var _rod_pitch := 0.7
var _rod_mesh: ImmediateMesh
var _rod_points := PackedVector3Array()
var _tip_world := Vector3.ZERO
var _bend := 0.0 # kärjen taipuma (rad)
var _bend_vel := 0.0
var _bend_dir := Vector3.DOWN
var _reel_handle: Node3D
var _line_mesh: ImmediateMesh
var _lure_node: MeshInstance3D
var _bobber_node: Node3D # koho-ongen koho
var _worm_node: MeshInstance3D # ongen mato koukussa
static var _worm_mesh: ArrayMesh
## Koho-ongen syötin syvyys kohon alla (F/G, vain ennen heittoa)
var float_depth := 1.0
const FLOAT_DEPTH_MIN := 0.3
const FLOAT_DEPTH_MAX := 4.0
const BOBBER_SCALE := 2.2 # koho hieman oikeaa isompi, jotta sen näkee kaukaa
## Syöttitärppi: kala nykii syöttiä ensin, ja koho painuu pinnan alle vasta
## tämän verran ennen kuin kala päästää irti – vastaisku vasta silloin
const BAIT_SINK_TIME := 1.0
const BOTTOM_BAIT_HEIGHT := 0.5 # m: pohjaongen mato pohjan yläpuolella
const BOTTOM_BAIT_MIN_DEPTH := 0.3 # m: matalassa mato pysyy pinnan alla
var _fish_node: MeshInstance3D


func setup(boat_node: Boat, rig: CameraRig, lake_data: LakeData, fish_pop: FishPopulation, weather_node: Weather, sky_time: SkyTime) -> void:
	boat = boat_node
	camera_rig = rig
	lake = lake_data
	population = fish_pop
	weather = weather_node
	sky = sky_time
	_rng.randomize()
	_build_visuals()
	_update_rod(0.0) # vavan kärjen sijainti heti alussa


func lures() -> Array:
	var all: Array = Lures.ICE if on_ice else Lures.LIST
	if not limited:
		return all
	return all.filter(func(l): return int(inventory.get(l["id"], 0)) > 0)


func has_lure() -> bool:
	return not lures().is_empty()


func lure() -> Dictionary:
	var list := lures()
	if list.is_empty():
		return (Lures.ICE if on_ice else Lures.LIST)[0] # vain ulkonäköä varten
	return list[lure_index % list.size()]


## Syöttiväline (koho- tai pohjaonki, mato)
func bait() -> bool:
	return lure()["kind"] in ["bobber", "bottom"]


func lure_count() -> int:
	return int(inventory.get(lure()["id"], 0)) if limited else -1


## Talvitila: lyhyt pilkkivapa ja pilkit
func set_on_ice(on: bool) -> void:
	_swap_to(0)
	held = 0
	in_holder = false
	for i in range(1, _rods.size()):
		_set_rod_visible(i, not on) # pilkillä on yksi vapa
	_holders.visible = not on
	on_ice = on
	rod_length = 0.65 if on else ROD_LENGTH
	lure_index = 0
	_lure_node.mesh.material.albedo_color = lure()["color"]


## Kalastus käynnissä: kalastaja istuu paikallaan (ei kävellä)
func busy() -> bool:
	return not in_holder and state != State.READY and state != State.LANDED


## Vetouistelu: molemmat vavat telineissä, kädet vapaina soutamiseen
func hands_free() -> bool:
	return held < 0


## Kalastajan edessä oleva avanto, tai Vector3.INF
func hole_in_front() -> Vector3:
	var front := boat.pos + boat.forward() * HOLE_AHEAD
	for h in holes:
		if Vector2(h.x, h.z).distance_to(front) < 0.45:
			return h
	return Vector3.INF


func at_hole() -> bool:
	return on_ice and hole_in_front() != Vector3.INF


## Jääkairan kahvat: [oikea käsi ylhäällä, vasen kammella]
func auger_grips() -> Array:
	return [_auger.global_transform * Vector3(0, 1.0, 0), _auger.global_transform * Vector3(0.16, 0.78, 0)]


func lure_depth() -> float:
	return maxf(0.0, -lure_pos.y) + 0.0 # + 0.0 poistaa negatiivisen nollan ("-0.0 m")


## Taipuneen vavan kärki maailmassa
func rod_tip() -> Vector3:
	return _tip_world


func hooked_fish() -> Dictionary:
	return _fish if state == State.FIGHT else {}


## Koukussa olevan kalan nimi, tai "Kala", jos lajia ei vielä tunnista
func fish_name() -> String:
	return _fish_name(_fish, _fish_known)


func _fish_name(fish: Dictionary, known: bool) -> String:
	return Species.DATA[fish["sp"]]["name"] if known and not fish.is_empty() else "Kala"


func fish_stamina() -> float:
	return _stamina


func landing_ready() -> bool:
	return _landing_prompt


func last_catch() -> Dictionary:
	return _last_catch


# --- Kaksi vapaa ja vapatelineet ---------------------------------------------

func rod_count() -> int:
	return 1 if on_ice else mini(ROD_COUNT, _rods.size())


## Vaihtaa toisen vavan tilan muuttujiin
func _swap_to(i: int) -> void:
	if i == _cur or i >= _rods.size():
		return
	_save_rod()
	_cur = i
	var r: Dictionary = _rods[i]
	for v in ROD_VARS:
		set(v, r[v])
	# Uistinlista voi muuttua (uistin loppui), joten vapa muistaa uistimensa nimellä
	var idx := lures().map(func(l): return l["id"]).find(r["lure_id"])
	if idx >= 0:
		lure_index = idx


func _save_rod() -> void:
	var r: Dictionary = _rods[_cur]
	for v in ROD_VARS:
		r[v] = get(v)
	r["lure_id"] = lure()["id"]


## Vavan muuttuja ilman vaihtoa
func _rod_get(i: int, v: String) -> Variant:
	return get(v) if i == _cur else _rods[i][v]


## Toinen vapa on piilossa jäällä (pilkillä on yksi vapa)
func _rods_hidden_on_ice() -> bool:
	return on_ice and _cur > 0


func _set_rod_visible(i: int, on: bool) -> void:
	for v in ["_rod_pivot", "_lure_node"]:
		_rod_get(i, v).visible = on
	for v in ["_rod_mesh", "_line_mesh"]:
		var mesh: ImmediateMesh = _rod_get(i, v)
		if not on:
			mesh.clear_surfaces()


## Telineessä oleva vapa, jossa on tärppi tai kala, tai -1
func alert_rod() -> int:
	for i in rod_count():
		if _rod_get(i, "in_holder") and _rod_get(i, "state") in [State.BITE, State.FIGHT]:
			return i
	return -1


func _first_rod(in_holder_wanted: bool) -> int:
	for i in rod_count():
		if i != held and _rod_get(i, "in_holder") == in_holder_wanted:
			return i
	return -1


## Telineissä olevien vapojen tilat HUDia varten
func holder_rods() -> Array:
	var list := []
	for i in rod_count():
		if not _rod_get(i, "in_holder"):
			continue
		var fish: Dictionary = _rod_get(i, "_fish")
		var st: int = _rod_get(i, "state")
		list.append({
			"number": i + 1,
			"state": st,
			"lure": Lures.name_of(lure()["id"] if i == _cur else _rods[i]["lure_id"]),
			"line": _rod_get(i, "line_out"),
			"depth": maxf(0.0, -_rod_get(i, "lure_pos").y) + 0.0,
			"snagged": _rod_get(i, "snagged"),
			"fish": _fish_name(fish, _rod_get(i, "_fish_known")) if st == State.FIGHT else "",
		})
	return list


## Koukussa olevien tai tärppäävien kalojen indeksit (kaikki vavat)
func hooked_indices() -> Array:
	var list := []
	for i in rod_count():
		if _rod_get(i, "state") in [State.BITE, State.FIGHT]:
			list.append(_rod_get(i, "_fish_index"))
	return list


## Jarru antaa siimaa jossain vavassa (ääni kuuluu myös telineestä)
func drag_screaming() -> bool:
	for i in rod_count():
		if _rod_get(i, "state") == State.FIGHT and _rod_get(i, "drag_slipping"):
			return true
	return false


## R: heitetty vapa telineeseen ja toinen käteen, tai vapa telineestä käteen
## (ensin se, jossa on tärppi)
func _rod_holder_key() -> void:
	if on_ice:
		return
	if held >= 0:
		if state == State.RETRIEVING and not lure_on_land:
			in_holder = true
			_bend_vel += 2.0 # vapa heilahtaa telineeseen
			sound_event.emit("oar_catch", rod_tip()) # kopsahdus telineeseen
			held = -1
			var next := alert_rod()
			if next < 0:
				next = _first_rod(false)
			if next >= 0:
				_take_rod(next, "Vapa %d telineeseen – vapa %d käteen" % [_cur + 1, next + 1])
			else:
				message.emit("Vapa %d telineeseen – molemmat vavat telineissä, soutele ja odota tärppiä" % (_cur + 1))
		elif state == State.READY or state == State.LANDED:
			var next := alert_rod()
			if next < 0:
				next = _first_rod(true)
			if next < 0:
				message.emit("Heitä uistin veneen perään ja paina R, niin vapa menee telineeseen")
				return
			state = State.READY
			held = -1 # vapa veneen pohjalle
			_take_rod(next, "Vapa %d telineestä käteen" % (next + 1))
		else:
			message.emit("Kädet täynnä – kelaa uistin ylös tai laita vapa telineeseen")
	else:
		var next := alert_rod()
		if next < 0:
			next = _first_rod(true)
		if next >= 0:
			_take_rod(next, "Vapa %d telineestä käteen" % (next + 1))


func _take_rod(i: int, text: String) -> void:
	_swap_to(i)
	held = i
	if in_holder:
		in_holder = false
		_bend_vel -= 2.0
	_lure_node.mesh.material.albedo_color = lure()["color"]
	if state == State.BITE:
		text += " – TÄRPPI! Vastaisku – vasen hiiri!"
	elif state == State.FIGHT:
		text += " – kala koukussa, väsytä!"
	message.emit(text)


## Viesti vavasta: telineessä olevan vavan viestissä on vavan numero
func _msg(text: String) -> void:
	message.emit("Vapa %d: %s" % [_cur + 1, text] if in_holder else text)


## Lusikka/vaappu on jo toisessa vavassa veden alla (uramoodissa uistimia on rajallisesti)
func _lure_free(l: Dictionary) -> bool:
	if not limited:
		return true
	var in_use := 0
	for i in rod_count():
		if i != _cur and _rods[i]["lure_id"] == l["id"] and _rods[i]["state"] != State.READY and _rods[i]["state"] != State.LANDED:
			in_use += 1
	return int(inventory.get(l["id"], 0)) > in_use


## Valitsee vapaan uistimen, jos nykyinen on jo toisessa vavassa
func _pick_free_lure() -> bool:
	var list := lures()
	for k in list.size():
		var idx := (lure_index + k) % list.size()
		if _lure_free(list[idx]):
			if idx != lure_index % list.size():
				lure_index = idx
				_lure_node.mesh.material.albedo_color = lure()["color"]
				message.emit("Uistin: " + lure()["name"])
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not GameInput.active():
		return
	if event.is_action_pressed("rod_holder"):
		_rod_holder_key()
		return
	if held < 0:
		# Kädet vapaina: vain jarrua voi säätää
		if event.is_action_pressed("cast"):
			message.emit("Vavat ovat telineissä – R ottaa vavan käteen")
		if not (event.is_action_pressed("drag_up", true) or event.is_action_pressed("drag_down", true)):
			return
	if event.is_action_pressed("cast") and state == State.READY and not has_lure():
		message.emit("Ei uistimia – osta lisää kalastustarvikeliikkeestä")
		return
	if event.is_action_pressed("cast") and state == State.READY and not on_ice and not _pick_free_lure():
		message.emit("Uistimet ovat jo toisessa vavassa – osta lisää kalastustarvikeliikkeestä")
		return
	if on_ice and _ice_input(event):
		return
	if event.is_action_pressed("cast"):
		match state:
			State.READY:
				state = State.CHARGING
				power = 0.0
			State.BITE:
				if bait() and not on_ice and _bite_timer > BAIT_SINK_TIME:
					_msg("Liian aikaisin – kala vasta maistelee!")
					_try_hook(0.3, "Vastaisku!")
				else:
					_try_hook(0.85, "Vastaisku!")
			State.FIGHT:
				if _landing_prompt:
					_try_land()
			State.LANDED:
				state = State.READY
	elif event.is_action_released("cast") and state == State.CHARGING:
		_cast()
	elif event.is_action_pressed("lure_next") and state == State.READY:
		if not has_lure():
			message.emit("Ei uistimia – osta lisää kalastustarvikeliikkeestä")
			return
		lure_index = (lure_index + 1) % lures().size()
		for k in lures().size(): # ohitetaan toisessa vavassa olevat
			if _lure_free(lure()):
				break
			lure_index = (lure_index + 1) % lures().size()
		_lure_node.mesh.material.albedo_color = lure()["color"]
		message.emit("Uistin: " + lure()["name"] + (" (%d kpl)" % lure_count() if limited else ""))
	elif event.is_action_pressed("twitch") and state == State.RETRIEVING and not lure_on_land:
		line_out = maxf(0.0, line_out - 0.5)
		_twitch = 1.0
	elif (event.is_action_pressed("float_deeper", true) or event.is_action_pressed("float_shallower", true)) and lure()["kind"] == "bobber" and not on_ice:
		# Koho siirretään siimalla oikeaan kohtaan ennen heittoa
		if state != State.READY and state != State.LANDED:
			message.emit("Kohon syvyyden voi säätää vain ennen heittoa")
			return
		var step := 0.1 if event.is_action_pressed("float_deeper", true) else -0.1
		float_depth = clampf(snappedf(float_depth + step, 0.1), FLOAT_DEPTH_MIN, FLOAT_DEPTH_MAX)
		message.emit("Kohon syvyys %.1f m" % float_depth)
	elif event.is_action_pressed("drag_up", true):
		drag_kg = minf(10.0, drag_kg + 0.25)
	elif event.is_action_pressed("drag_down", true):
		drag_kg = maxf(0.5, drag_kg - 0.25)


func _physics_process(dt: float) -> void:
	for i in rod_count():
		_swap_to(i)
		_process_rod(dt, i == held)
	# Muuttujiin jää kädessä oleva vapa (HUD, äänet ja kalastaja lukevat sitä),
	# kädet vapaina se vapa, jossa on tärppi
	if held >= 0:
		_swap_to(held)
	elif alert_rod() >= 0:
		_swap_to(alert_rod())
	_update_aim(dt)
	# Onkiessa kamera katsoo kohoa läheltä
	camera_rig.bobber_view = held >= 0 and _bobber_node.visible and state in [State.RETRIEVING, State.BITE]
	if camera_rig.bobber_view:
		camera_rig.bobber_pos = _bobber_pos()


# --- Heiton tähtäin ------------------------------------------------------------

## Heittoa ladatessa: arvio osumapisteestä (sama lentofysiikka kuin heitossa)
func _update_aim(dt: float) -> void:
	var aiming := held >= 0 and state == State.CHARGING and not on_ice
	_aim_marker.visible = aiming
	_aim_arc_node.visible = aiming
	_aim_arc.clear_surfaces()
	if not aiming:
		cast_preview = {}
		return
	var pos := rod_tip()
	var vel := _cast_velocity()
	var step_dt := maxf(dt, 1.0 / 60.0)
	var points := PackedVector3Array([pos])
	var water := false
	for i in 600:
		var step := _flight_step(pos, vel, step_dt)
		pos = step[0]
		vel = step[1]
		if i % 3 == 0:
			points.append(pos)
		if lake.is_water(pos.x, pos.z):
			if pos.y <= 0.0:
				pos.y = 0.0
				water = true
				break
		elif pos.y <= lake.height_at(pos.x, pos.z):
			pos.y = lake.height_at(pos.x, pos.z)
			break
	points.append(pos)
	var ground := -1 if water else lake.ground_at(pos.x, pos.z)
	var distance := Vector2(pos.x - boat.pos.x, pos.z - boat.pos.y).length()
	cast_preview = {"point": pos, "water": water, "distance": distance, "ground": ground}
	var color := Color(0.35, 0.95, 0.9) if water else Color(1.0, 0.45, 0.15)
	_aim_material.albedo_color = color
	# Rengas kallistuu kameraa kohti, jotta se erottuu matalalta katsottuna
	# kaukaakin (vaakasuora rengas näkyisi vain viivana)
	var to_cam := (camera_rig.camera.global_position - pos).normalized()
	var normal := Vector3.UP.lerp(to_cam, 0.8).normalized()
	var size := 0.6 + distance * 0.035
	_aim_marker.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)).scaled(Vector3.ONE * size), pos + Vector3(0, size * 0.7, 0))
	# Lentorata katkoviivana
	_aim_arc.surface_begin(Mesh.PRIMITIVE_LINES)
	_aim_arc.surface_set_color(Color(color, 0.85))
	for i in range(0, points.size() - 1, 2):
		_aim_arc.surface_add_vertex(points[i])
		_aim_arc.surface_add_vertex(points[i + 1])
	_aim_arc.surface_end()


func _build_aim() -> void:
	_aim_material = StandardMaterial3D.new()
	_aim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aim_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aim_material.no_depth_test = true # näkyy aaltojen ja kaislojen läpi
	_aim_marker = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.8
	ring.outer_radius = 1.0
	ring.rings = 24
	ring.material = _aim_material
	_aim_marker.mesh = ring
	_aim_marker.top_level = true
	_aim_marker.visible = false
	_aim_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_aim_marker)
	_aim_arc = ImmediateMesh.new()
	_aim_arc_node = MeshInstance3D.new()
	_aim_arc_node.mesh = _aim_arc
	_aim_arc_node.top_level = true
	_aim_arc_node.visible = false
	_aim_arc_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var arc_mat := StandardMaterial3D.new()
	arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arc_mat.vertex_color_use_as_albedo = true
	arc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aim_arc_node.material_override = arc_mat
	add_child(_aim_arc_node)


func _process_rod(dt: float, in_hand: bool) -> void:
	if in_hand:
		_aim_angler(dt)
	else:
		# Telineessä, tai käyttämättömänä veneen pohjalla
		_rod_pivot.global_transform = boat.hull.global_transform * (holder_transform(_cur) if in_holder else SPARE_ROD)
	_update_rod(dt)
	_twitch = move_toward(_twitch, 0.0, dt * 3.0)
	match state:
		State.READY, State.LANDED:
			var hang := 0.12 if on_ice else 0.35
			if not in_hand:
				hang = 0.02 # uistin vavan kärjessä veneen pohjalla
			lure_pos = rod_tip() + Vector3(0, -hang, 0)
			line_out = hang
			tension = 0.0
		State.DRILLING:
			_drill(dt)
		State.LANDING:
			_landing_net.update(dt)
		State.CHARGING:
			power = minf(1.0, power + dt / 1.1)
			lure_pos = rod_tip() + Vector3(0, -0.35, 0)
		State.FLYING:
			_fly(dt)
		State.RETRIEVING:
			if on_ice:
				_ice_retrieve(dt)
			else:
				_retrieve(dt)
		State.BITE:
			_bite(dt)
		State.FIGHT:
			_fight(dt)
	if not follower.is_empty() and follower["rod"] == _cur:
		_update_follow(dt)
	_update_visuals()


func _aim_angler(dt: float) -> void:
	var target := wrapf(camera_rig.yaw - boat.yaw, -PI, PI)
	if state == State.FIGHT or state == State.BITE or state == State.LANDING:
		# Väsytyksessä ja haavittaessa kalastaja kääntyy kalaa kohti, ettei se taivu selän taakse
		var to_fish := Vector2(lure_pos.x - boat.pos.x, lure_pos.z - boat.pos.y)
		if to_fish.length() > 0.5:
			target = wrapf(atan2(-to_fish.x, -to_fish.y) - boat.yaw, -PI, PI)
	if on_ice:
		target = 0.0 # avanto on kalastajan edessä
	boat.angler.aim_yaw = target
	var pitch := 0.7
	match state:
		State.CHARGING:
			pitch = 0.7 + power * 0.9 # vapa taaksepäin
		State.FLYING:
			pitch = 0.25
		State.RETRIEVING, State.BITE:
			pitch = 0.35
		State.FIGHT:
			pitch = 0.8 + clampf(tension / LINE_STRENGTH, 0.0, 1.0) * 0.5
	if on_ice:
		# Pilkkivapa osoittaa avantoon; kalan vetäessä ja nykäistessä kärki nousee
		pitch = -0.55 + _twitch * 0.3
		if state == State.FIGHT:
			pitch = -0.4 + clampf(tension / 3.0, 0.0, 1.0) * 0.6
	_rod_pitch = lerpf(_rod_pitch, pitch, minf(1.0, dt * 8.0))
	# Vapa kalastajan käsissä tai veneen pohjalla (soudettaessa ja moottoriajossa)
	var in_hands := boat.angler.rod_mount.global_transform * Transform3D(Basis(Vector3.RIGHT, _rod_pitch), Vector3.ZERO)
	_rod_pivot.global_transform = in_hands.interpolate_with(boat.angler.rod_stow_transform(), boat.angler.rod_stow_blend())


func _cast() -> void:
	_lure_vel = _cast_velocity()
	lure_pos = rod_tip()
	_bend_vel -= 9.0 * power # vapa ponnahtaa suoraksi ja kärki värähtää
	sound_event.emit("cast_swish", rod_tip())
	state = State.FLYING
	snagged = false
	lure_on_land = false


## Uistimen lento: painovoima ja ilmanvastus tuulen suhteen. Palauttaa
## [paikka, nopeus]. Sama laskenta ennustaa heiton osumapisteen (tähtäin).
func _flight_step(pos: Vector3, vel: Vector3, dt: float) -> Array:
	var wind := weather.vector()
	var rel := vel - Vector3(wind.x, 0, wind.y)
	var k: float = 0.014 / lure()["cast"]
	vel += (Vector3(0, -GRAVITY, 0) - rel * rel.length() * k) * dt
	return [pos + vel * dt, vel]


## Heiton alkunopeus nykyisellä heittovoimalla ja kameran suuntaan
func _cast_velocity() -> Vector3:
	var dir := camera_rig.aim_direction()
	var speed: float = 6.0 + 20.0 * power * (0.7 + 0.3 * lure()["cast"])
	return Vector3(dir.x * cos(CAST_ANGLE), sin(CAST_ANGLE), dir.y * cos(CAST_ANGLE)) * speed


func _fly(dt: float) -> void:
	var step := _flight_step(lure_pos, _lure_vel, dt)
	lure_pos = step[0]
	_lure_vel = step[1]
	line_out = rod_tip().distance_to(lure_pos)
	var ground := lake.height_at(lure_pos.x, lure_pos.z)
	var in_water := lake.is_water(lure_pos.x, lure_pos.z)
	if in_water and lure_pos.y <= 0.0:
		lure_pos.y = 0.0
		state = State.RETRIEVING
		_prev_lure = lure_pos
		_leave_slack()
		sound_event.emit("lure_splash", lure_pos)
		message.emit("Heitto %.0f m" % Vector2(lure_pos.x - boat.pos.x, lure_pos.z - boat.pos.y).length())
	elif not in_water and lure_pos.y <= ground:
		lure_pos.y = ground
		lure_on_land = true
		state = State.RETRIEVING
		_prev_lure = lure_pos
		_leave_slack()
		voice.emit("shore")
		var g := lake.ground_at(lure_pos.x, lure_pos.z)
		if (g == LakeData.Ground.FOREST or g == LakeData.Ground.REEDS) and _rng.randf() < 0.5:
			snagged = true
			message.emit("Uistin tarttui %s! Kelaa irti" % ("kaislikkoon" if g == LakeData.Ground.REEDS else "puskaan"))
		else:
			message.emit("Heitto meni rannalle")


## Vapateline perälaudan kulmassa (veneen paikallisissa koordinaateissa, +Z = perä):
## vapa osoittaa taakse, viistosti sivulle ja ylös
func holder_transform(i: int) -> Transform3D:
	var side := 1.0 if i == 0 else -1.0
	return Transform3D(Basis.looking_at(Vector3(0.5 * side, 0.75, 1.0)), Vector3(0.55 * side, 0.42, 1.7))


func _reel_speed() -> float:
	if _cur != held or not Input.is_action_pressed("reel") or not GameInput.active():
		return 0.0
	return REEL_SPEED_FAST if Input.is_action_pressed("reel_fast") else REEL_SPEED


func _retrieve(dt: float) -> void:
	var reel := _reel_speed()
	if snagged:
		var pulling := reel > 0.0
		var span := rod_tip().distance_to(lure_pos)
		if in_holder and span > line_out:
			pulling = true # vene vetää: jarru antaa siimaa
			line_out = span
		tension = drag_kg if pulling else 0.0
		if pulling:
			if _rng.randf() < 0.35 * dt:
				snagged = false
				_msg("Uistin irtosi!")
			elif _rng.randf() < 0.12 * dt * (drag_kg / LINE_STRENGTH) * 2.0:
				_lose_lure("Siima katkesi – uistin jäi kiinni")
		return

	line_out = maxf(0.0, line_out - reel * dt)
	_constrain_lure()
	var tip := rod_tip()
	var moved := Vector2(lure_pos.x - _prev_lure.x, lure_pos.z - _prev_lure.z).length()
	lure_speed = lerpf(lure_speed, moved / dt, minf(1.0, dt * 5.0))
	tension = _retrieve_tension(tip, reel)

	if lure_on_land:
		lure_pos.y = lake.height_at(lure_pos.x, lure_pos.z)
		if lake.is_water(lure_pos.x, lure_pos.z):
			lure_on_land = false
			lure_pos.y = 0.0
	else:
		_lure_depth_dynamics(dt)
		if not lake.is_water(lure_pos.x, lure_pos.z):
			lure_on_land = true
		_check_timer -= dt
		# Seuraavan hauen aikana muut kalat eivät iske (hauki päättää itse)
		if _check_timer <= 0.0 and not _following():
			_check_timer = 0.2
			var idx := population.check_lure(Vector2(lure_pos.x, lure_pos.z), lure_depth(), lure_speed, _twitch, lure(), sky.hour(), weather.speed(), 0.2, weather.cloud_cover, weather.feeding_factor())
			if idx >= 0:
				if _may_follow(idx):
					_start_follow(idx)
				else:
					_start_bite(idx)
	_prev_lure = lure_pos

	if line_out < 1.0 or tip.distance_to(lure_pos) < 1.0:
		state = State.READY


## Tärppi: kala iskee uistimeen
func _start_bite(idx: int) -> void:
	_fish_index = idx
	_fish = population.fish[idx]
	state = State.BITE
	_bite_timer = _rng.randf_range(0.6, 1.0)
	_bend_vel += 3.0 # vavan kärki nykäisee
	sound_event.emit("bite_tick", rod_tip())
	voice.emit("bite")
	if bait():
		# Kala maistelee matoa ensin: koho nykii, vavan kärki värähtää
		_bite_timer = BAIT_SINK_TIME + _rng.randf_range(0.8, 2.0)
		_bend_vel -= 2.0
		_msg("R = ota vapa käteen – kala maistelee matoa" if in_holder else ("Koho nykii... odota, että se uppoaa!" if lure()["kind"] == "bobber" else "Vavan kärki nykii... odota!"))
	else:
		_msg("TÄRPPI! R = ota vapa käteen" if in_holder else "TÄRPPI! Vastaisku – vasen hiiri!")


# --- Hauki seuraa uistinta -----------------------------------------------------
# Kun hauki iskisi kaukana veneestä heitellessä, se voi iskun sijaan lähteä
# seuraamaan uistinta. Humusvedessä seuraaja näkyy vasta pinnan lähellä
# veneen vieressä (fish.gdshader). Tasaisesti kelattuna hauki iskee yleensä
# viime hetkellä veneen vieressä; nykäisy lähellä venettä houkuttelee iskuun.
# Jos uistin pysähtyy tai sitä kelataan liian lujaa, hauki kääntyy pois.

## Seuraako hauki tämän vavan uistinta
func _following() -> bool:
	return not follower.is_empty() and follower["rod"] == _cur and not follower["leaving"]


func _may_follow(idx: int) -> bool:
	if in_holder or bait() or on_ice or _cur != held or not follower.is_empty():
		return false
	if population.fish[idx]["sp"] != "hauki":
		return false
	var tip := rod_tip()
	if Vector2(lure_pos.x - tip.x, lure_pos.z - tip.z).length() < FOLLOW_MIN_DISTANCE:
		return false
	return _rng.randf() < FOLLOW_CHANCE


func _start_follow(idx: int) -> void:
	var f: Dictionary = population.fish[idx]
	var start := Vector3(f["pos"].x, -f["depth"], f["pos"].y)
	follower = {
		"rod": _cur,
		"index": idx,
		"sp": f["sp"],
		"weight": f["weight"],
		"pos": start.lerp(lure_pos, 0.5),
		"heading": atan2(-(lure_pos.x - start.x), -(lure_pos.z - start.z)),
		"speed": 0.5,
		"last_lure": lure_pos,
		"strike": _rng.randf() < FOLLOW_STRIKE_CHANCE, # iskeekö tasaisesti kelattuun
		"strike_at": _rng.randf_range(1.6, 3.5), # m vavan kärjestä
		"stopped": 0.0,
		"fast": 0.0,
		"twitched": false,
		"seen": false,
		"leaving": false,
		"timer": 0.0,
		"time": _rng.randf() * TAU,
	}


## Seuraajan liike ja päätökset (kutsutaan seurattavan vavan vuorolla)
func _update_follow(dt: float) -> void:
	var f := follower
	if f["leaving"]:
		# Kääntyy pois ja painuu syvemmälle, jolloin humusvesi kätkee sen
		f["timer"] -= dt
		var fwd := Vector3(-sin(f["heading"]), 0.0, -cos(f["heading"]))
		f["speed"] = lerpf(f["speed"], 1.6, minf(1.0, dt * 3.0))
		f["pos"] += fwd * f["speed"] * dt + Vector3.DOWN * 0.7 * dt
		if f["timer"] <= 0.0:
			follower = {}
		return
	if state != State.RETRIEVING or in_holder or snagged or lure_on_land:
		_follow_leave("Hauki kääntyi pois veneen vierestä" if state == State.READY else "")
		return
	var motion: Vector3 = (lure_pos - f["last_lure"]) / maxf(dt, 0.001)
	f["last_lure"] = lure_pos
	var flat := Vector2(motion.x, motion.z)
	var tip := rod_tip()
	var to_tip := Vector2(lure_pos.x - tip.x, lure_pos.z - tip.z).length()
	# Uistimen perässä: lähellä venettä hauki kirii aivan kiinni
	var gap := lerpf(0.35, 1.1, clampf(to_tip / 10.0, 0.0, 1.0))
	var back := Vector3(-flat.x, 0.0, -flat.y).normalized() if flat.length() > 0.05 else Vector3(-sin(f["heading"]), 0.0, -cos(f["heading"])) * -1.0
	# Hauki kaartelee uistimen perässä puolelta toiselle, jolloin veneestä
	# näkee sen kyljen eikä vain kuonoa
	f["time"] += dt
	var side := Vector3(back.z, 0.0, -back.x)
	var target := lure_pos + back * gap + side * sin(f["time"] * 1.1) * 0.45 + Vector3.DOWN * 0.12
	# Veneen lähellä hauki nousee uistimen perässä pinnan tuntumaan
	target.y = lerpf(maxf(target.y, -0.6), target.y, clampf((to_tip - 3.0) / 7.0, 0.0, 1.0))
	var bottom := lake.depth_at(target.x, target.z)
	target.y = clampf(target.y, -maxf(0.2, bottom - 0.1), -0.08)
	var before: Vector3 = f["pos"]
	f["pos"] = before.lerp(target, minf(1.0, dt * 2.5))
	var step: Vector3 = f["pos"] - before
	f["speed"] = step.length() / maxf(dt, 0.001)
	var look: Vector3 = lure_pos - f["pos"]
	if Vector2(look.x, look.z).length() > 0.05:
		f["heading"] = lerp_angle(f["heading"], atan2(-look.x, -look.z), minf(1.0, dt * 6.0))
	# Näkyviin pinnan lähellä veneen vieressä
	if not f["seen"] and f["pos"].y > -1.2 and to_tip < 8.0:
		f["seen"] = true
		_msg("Hauki seuraa uistinta! Kelaa tasaisesti")
		voice.emit("fish_hauki")
	# Väärä uistinliike: pysähdys (ei kelata, eikä uistin liiku) tai liian kova
	# vauhti. Kelattaessa löysää siimaa hauki odottaa uistimen vieressä.
	f["stopped"] = f["stopped"] + dt if lure_speed < FOLLOW_STOP_SPEED and _reel_speed() <= 0.0 else 0.0
	f["fast"] = f["fast"] + dt if lure_speed > FOLLOW_FAST_SPEED else 0.0
	if f["stopped"] > 0.8:
		_follow_leave("Uistin pysähtyi – hauki kääntyi pois")
		return
	if f["fast"] > 1.2:
		_follow_leave("Liian kova vauhti – hauki jäi jälkeen")
		return
	# Isku viime hetkellä, tai nykäisy veneen lähellä houkuttelee
	var strike: bool = f["strike"] and to_tip < f["strike_at"]
	if _twitch > 0.9 and not f["twitched"] and to_tip < 6.0:
		f["twitched"] = true
		strike = strike or _rng.randf() < FOLLOW_TWITCH_CHANCE
	elif _twitch < 0.5:
		f["twitched"] = false
	if strike:
		var idx: int = f["index"]
		follower = {}
		sound_event.emit("fish_splash", lure_pos)
		_start_bite(idx)


func _follow_leave(text: String) -> void:
	follower["leaving"] = true
	follower["timer"] = 2.0
	follower["heading"] = follower["heading"] + PI + _rng.randf_range(-0.6, 0.6)
	population.spook(follower["index"])
	if text != "" and follower["seen"]:
		_msg(text)


## Vedessä näkyvät kalat (FishVisuals): vain uistinta seuraava hauki
func visible_fish() -> Array:
	return [] if follower.is_empty() else [follower]


## Piste vavalla annetun matkan päässä tyvestä (kalastajan kädet)
func rod_point(distance: float) -> Vector3:
	if _rod_points.size() < 2:
		return _rod_pivot.global_position
	var seg := rod_length / ROD_SEGMENTS
	var f := clampf(distance / seg, 0.0, ROD_SEGMENTS - 0.001)
	var i := int(f)
	return _rod_points[i].lerp(_rod_points[i + 1], f - i)


## Kelan kammen nuppi (vasen käsi kelatessa)
func reel_knob() -> Vector3:
	return _reel_handle.global_transform * Vector3(0.012, -0.06, 0)


## Kelataanko juuri nyt (äänille)
func is_reeling() -> bool:
	return state in [State.RETRIEVING, State.BITE, State.FIGHT] and _reel_speed() > 0.0 and not snagged


func reel_speed() -> float:
	return _reel_speed()


## Heiton aikana kelalta purkautuu siimaa hieman yli välimatkan, joten siima
## jää löysälle kaarelle veden päälle. Kelaus kiristää sen ensin suoraksi.
func _leave_slack() -> void:
	line_out = rod_tip().distance_to(lure_pos) * 1.05 + 0.6


## Siiman jännitys kelatessa: löysä siima ei vedä, kireällä siimalla uistimen
## vesivastus kasvaa nopeuden neliönä. Maalla uistin laahaa maata.
func _retrieve_tension(tip: Vector3, reel: float) -> float:
	var slack := line_out - tip.distance_to(lure_pos)
	if slack > 0.05:
		return 0.0
	if lure_on_land:
		return 0.25 if reel > 0.0 else 0.0
	return 0.02 + lure()["pull"] * lure_speed * lure_speed


## Vavan taipuma: kärkeen vaikuttava veto taivuttaa vapaa siiman suuntaan.
## Taipuma on suurin kärjessä (nopea toiminta), ja jousto värähtelee hetken.
func _update_rod(dt: float) -> void:
	var base := _rod_pivot.global_position
	var dir0 := (-_rod_pivot.global_basis.z).normalized()
	var straight_tip := base + dir0 * rod_length
	var load := 0.015 # uistimen paino
	var pull_dir := Vector3.DOWN
	match state:
		State.CHARGING:
			load += power * 0.25 # heiton lataus taivuttaa vapaa
		State.FLYING, State.RETRIEVING, State.BITE, State.FIGHT:
			var to_lure := lure_pos - straight_tip
			if to_lure.length() > 0.05:
				pull_dir = to_lure.normalized()
			load = maxf(load, tension)
	var target := ROD_MAX_BEND * (1.0 - exp(-load / ROD_POWER))
	target = minf(target, dir0.angle_to(pull_dir) * 0.85) # ei taivu siiman suunnan ohi
	_bend_vel += (ROD_STIFFNESS * (target - _bend) - ROD_DAMPING * _bend_vel) * dt
	_bend = clampf(_bend + _bend_vel * dt, -0.6, ROD_MAX_BEND)
	if _bend_dir.dot(pull_dir) > 0.9999:
		_bend_dir = pull_dir # slerp ei toimi lähes samansuuntaisilla vektoreilla
	else:
		_bend_dir = _bend_dir.slerp(pull_dir, minf(1.0, dt * 10.0)).normalized()
	var axis := dir0.cross(_bend_dir)
	if axis.length() < 0.001:
		axis = dir0.cross(Vector3.UP)
	axis = axis.normalized()
	# Uusi taulukko: pakatut taulukot jaetaan viittauksena, ja vavat vaihtavat
	# muuttujiaan (ROD_VARS), joten clear() tyhjentäisi myös toisen vavan pisteet
	_rod_points = PackedVector3Array()
	var p := base
	_rod_points.append(p)
	for i in ROD_SEGMENTS:
		var s := (i + 0.5) / ROD_SEGMENTS
		p += dir0.rotated(axis, _bend * s * s) * (rod_length / ROD_SEGMENTS)
		_rod_points.append(p)
	_tip_world = p
	if _reel_handle:
		_reel_handle.rotation.x -= _reel_speed() * dt * 8.0


## Siima vetää uistinta kohti vavan kärkeä, kun siimaa on kelattu sisään.
## Veto siirtää uistinta vaakasuunnassa: syvyyden määrää uistimen oma
## uintitapa (_lure_depth_dynamics), ei siiman kulma. Vasta aivan veneen
## vieressä lyhyt siima nostaa uistimen ylös.
func _constrain_lure() -> void:
	var tip := rod_tip()
	var d := lure_pos - tip
	if d.length() <= line_out:
		return
	var dy := minf(absf(d.y), line_out)
	var h := Vector2(d.x, d.z)
	var max_h := sqrt(maxf(0.0, line_out * line_out - dy * dy))
	if h.length() > max_h:
		h = h.normalized() * max_h
	lure_pos = Vector3(tip.x + h.x, tip.y + signf(d.y) * dy, tip.z + h.y)


func _lure_depth_dynamics(dt: float) -> void:
	var l := lure()
	var depth := lure_depth()
	var bottom := lake.depth_at(lure_pos.x, lure_pos.z)
	if l["kind"] == "bobber":
		# Koho-onki: mato roikkuu kohon alla; vedettäessä koho laahaa sitä
		# lähempänä pintaa
		var target := float_depth if lure_speed < 0.25 else minf(float_depth, 0.4)
		depth = move_toward(depth, target, (l["sink"] if target > depth else 0.6) * dt)
	elif l["kind"] == "bottom":
		# Pohjaonki: paino on pohjassa, ja mato leijuu tafsin päässä
		# noin puolen metrin korkeudella pohjasta
		depth = move_toward(depth, maxf(BOTTOM_BAIT_MIN_DEPTH, bottom - BOTTOM_BAIT_HEIGHT), l["sink"] * dt)
	elif l["kind"] == "sink" and l.has("run_depth") and lure_speed > RUN_MIN_SPEED:
		# Lusikka: levossa vajoaa pohjaan, kelatessa ja uistellessa ui
		# uintisyvyydessään – syvältä se nousee sinne hiljalleen.
		# Nopeasti kelattaessa se ui matalammalla.
		var run: float = l["run_depth_fast"] if _reel_speed() >= REEL_SPEED_FAST else l["run_depth"]
		var target: float = lerpf(bottom, run, smoothstep(RUN_MIN_SPEED, RUN_FULL_SPEED, lure_speed))
		if target < depth:
			depth = move_toward(depth, target, SINK_MAX_RISE * dt)
		else:
			depth = move_toward(depth, target, l["sink"] * dt)
	elif l["kind"] == "sink":
		# Levossa vajoaa nopeasti, vedettäessä nousee hiljalleen kohti
		# pintaa – nousu hidastuu matalassa, eikä uistin nouse pinnalle
		var rate: float = l["sink"] - l["lift"] * lure_speed
		if depth < SINK_MIN_DEPTH:
			depth = move_toward(depth, SINK_MIN_DEPTH, l["sink"] * dt)
		elif rate < 0.0:
			var ease := clampf((depth - SINK_MIN_DEPTH) / 0.8, 0.0, 1.0)
			depth = maxf(SINK_MIN_DEPTH, depth + maxf(rate, -SINK_MAX_RISE) * ease * dt)
		else:
			depth += rate * dt
	else:
		# Vaappu kelluu levossa pinnalla ja vedettäessä sukeltaa
		# tavoitesyvyyteensä, jossa se ui tasaisesti
		var target: float = l["max_dive"] * smoothstep(0.05, DIVE_FULL_SPEED, lure_speed)
		if target > depth:
			depth = move_toward(depth, target, DIVE_PER_METER * lure_speed * dt)
		else:
			depth = move_toward(depth, target, l["float"] * dt)
	depth = clampf(depth, 0.0, maxf(0.0, bottom - 0.05))
	lure_pos.y = minf(-depth, lure_pos.y) if lure_pos.y > 0.0 else -depth
	# Uistin laahaa pohjaa: voi tarttua kiinni
	if bottom > 0.0 and depth >= bottom - 0.06 and lure_speed > 0.15:
		if _rng.randf() < l["snag"] * dt:
			snagged = true
			voice.emit("snag")
			_msg("Pohjakiinni! Kelaa tai nykäise irti")


func _bite(dt: float) -> void:
	var before := _bite_timer
	_bite_timer -= dt
	if bait() and not on_ice:
		# Syötti: kala nykii, ja lopuksi vie syötin (koho painuu pinnan alle)
		if _rng.randf() < 3.0 * dt:
			_bend_vel += 1.5
		if before > BAIT_SINK_TIME and _bite_timer <= BAIT_SINK_TIME:
			_bend_vel += 4.0
			sound_event.emit("bite_tick", rod_tip())
			_msg(("KOHO UPPOSI!" if lure()["kind"] == "bobber" else "SIIMA KIRISTYY!") + (" R = ota vapa käteen" if in_holder else " Vastaisku – vasen hiiri!"))
		if _reel_speed() > 0.0 and _bite_timer < 0.4:
			_try_hook(0.45, "Kala tarttui kelatessa!")
		elif _bite_timer <= 0.0:
			_try_hook(0.25 if in_holder else 0.1, "Kala koukuttui itse!")
		return
	if not on_ice:
		lure_pos += Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)) * dt * 0.5
	if _reel_speed() > 0.0 and _bite_timer < 0.4:
		_try_hook(0.45, "Kala tarttui kelatessa!")
	elif _bite_timer <= 0.0:
		if in_holder:
			# Vetouistelussa veneen vauhti iskee koukun kalaan
			_try_hook(0.25 + 0.5 * clampf(boat.velocity.length(), 0.0, 1.0), "Kala tarttui! R = ota vapa käteen")
		else:
			_try_hook(0.15, "Kala koukuttui itse!")


func _try_hook(chance: float, success_text: String) -> void:
	if _rng.randf() < chance:
		state = State.FIGHT
		_stamina = 1.0
		_fish_pos = lure_pos
		_run_timer = 0.0
		_slack_time = 0.0
		_landing_prompt = false
		_fish_known = false
		voice.emit("hooked")
		_msg(success_text)
	else:
		population.spook(_fish_index)
		_fish_index = -1
		_fish = {}
		state = State.RETRIEVING
		_msg("Kala ei tarttunut")


func _fight(dt: float) -> void:
	var data: Dictionary = Species.DATA[_fish["sp"]]
	var weight: float = _fish["weight"]
	var fish_power: float = data["power"]
	var tip := rod_tip()

	# Kalan käytös: pakoryntäyksiä ja lepoa
	_run_timer -= dt
	if _run_timer <= 0.0:
		var away := Vector2(_fish_pos.x - boat.pos.x, _fish_pos.z - boat.pos.y).normalized()
		if _stamina > 0.2 and _rng.randf() < 0.45 + 0.4 * _stamina:
			_run_dir = away.rotated(_rng.randf_range(-1.6, 1.6))
			_run_intensity = _rng.randf_range(0.5, 1.0)
			_bend_vel += _run_intensity * 4.0 # ryntäys nykäisee vavan kärkeä
			_run_timer = _rng.randf_range(1.5, 4.5)
		else:
			_run_dir = away.rotated(_rng.randf_range(-2.5, 2.5))
			_run_intensity = 0.12
			_run_timer = _rng.randf_range(1.0, 3.0)

	var swim_speed := _run_intensity * (0.4 + 1.6 * _stamina) * fish_power * (1.0 + 0.25 * log(1.0 + weight))
	var next := _fish_pos + Vector3(_run_dir.x, 0, _run_dir.y) * swim_speed * dt
	if lake.is_water(next.x, next.z):
		_fish_pos = next
	else:
		_run_dir = -_run_dir
	var bottom := lake.depth_at(_fish_pos.x, _fish_pos.z)
	var target_depth := 0.3 if _stamina < 0.3 else clampf(lerpf(data["depth"][0], data["depth"][1], 0.5), 0.3, maxf(0.3, bottom - 0.2))
	_fish_pos.y = -move_toward(-_fish_pos.y, target_depth, dt * 0.5)
	# Jäällä siima kulkee avannon kautta: avanto on siiman taitekohta
	var anchor := tip
	var tip_to_anchor := 0.0
	var hole_dist := 0.0
	if on_ice:
		anchor = Vector3(current_hole.x, 0.0, current_hole.z)
		tip_to_anchor = tip.distance_to(anchor)
		hole_dist = Vector2(_fish_pos.x - anchor.x, _fish_pos.z - anchor.z).length()
		if hole_dist > 0.1:
			_fish_pos.y = minf(_fish_pos.y, -0.2) # jään alla

	# Siima, jarru ja jännitys
	var pull := (_run_intensity * (0.3 + 0.7 * _stamina) * fish_power * 0.95 + 0.12) * weight
	var reel := _reel_speed()
	var effort := 0.6 if reel > 0.0 else 0.0
	var dist := tip_to_anchor + anchor.distance_to(_fish_pos)
	drag_slipping = false
	if dist >= line_out:
		var wanted := pull + effort
		if wanted > drag_kg:
			drag_slipping = true
			line_out = dist # jarru antaa siimaa
			tension = drag_kg
		else:
			_fish_pos = anchor + (_fish_pos - anchor).normalized() * (line_out - tip_to_anchor)
			line_out = maxf(tip_to_anchor + 0.15 if on_ice else 0.5, line_out - reel * dt * clampf(1.0 - pull / drag_kg, 0.25, 1.0))
			tension = wanted
		_slack_time = maxf(0.0, _slack_time - dt * 2.0)
	else:
		tension = 0.05
		line_out = maxf(dist, line_out - reel * 2.0 * dt)
		if line_out - dist > 0.8:
			_slack_time += dt

	if tension > LINE_STRENGTH:
		_lose_fish("Siima katkesi! Jarru oli liian kireällä", true)
		return
	if _slack_time > 1.5 and _rng.randf() < (0.5 if _fish["sp"] == "hauki" else 0.3) * dt:
		_lose_fish("Kala irtosi löysällä siimalla", false)
		return
	# Hauki ravistelee päätään pinnassa: löysä siima on silloin vaarallinen
	if _stamina > 0.3 and _fish_pos.y > -0.6 and (not on_ice or hole_dist < 0.3) and _rng.randf() < 0.08 * dt:
		sound_event.emit("fish_splash", _fish_pos)
		if Vector2(_fish_pos.x - boat.pos.x, _fish_pos.z - boat.pos.y).length() < IDENTIFY_SPLASH and not on_ice:
			_recognize_fish()
		_msg("%s rimpuilee pinnassa!" % fish_name())
		if tension < 0.5 * weight and _rng.randf() < 0.3:
			_lose_fish("Kala ravisteli itsensä irti", false)
			return

	_identify_fish(hole_dist)
	_stamina = clampf(_stamina - (tension / maxf(weight, 0.2)) * 0.03 * dt / fish_power - _run_intensity * 0.006 * dt + (0.004 * dt if tension < 0.3 else 0.0), 0.0, 1.0)
	lure_pos = _fish_pos
	if on_ice:
		_landing_prompt = line_out - tip_to_anchor < 0.8 and hole_dist < 0.5
	else:
		_landing_prompt = line_out < 3.2 and _fish_pos.y > -1.2
	tension = maxf(tension, 0.0)


## Kalan laji selviää, kun kala tulee näkyviin
func _identify_fish(hole_dist: float) -> void:
	if _fish_known:
		return
	var near := hole_dist < 1.2 if on_ice else Vector2(_fish_pos.x - boat.pos.x, _fish_pos.z - boat.pos.y).length() < IDENTIFY_DISTANCE
	if near and -_fish_pos.y < IDENTIFY_DEPTH:
		_recognize_fish()


## Laji tunnistettu: kalastaja huutaa sen ääneen ("Hauki!")
func _recognize_fish() -> void:
	if _fish_known:
		return
	_fish_known = true
	voice.emit("fish_" + _fish["sp"])


func _try_land() -> void:
	if _stamina < 0.35:
		var sp: String = _fish["sp"]
		var weight: float = _fish["weight"]
		var entry := {
			"species": sp,
			"name": Species.DATA[sp]["name"],
			"weight": snappedf(weight, 0.01),
			"length": snappedf(Species.length_cm(sp, weight), 0.5),
			"lure": lure()["name"],
			"time": sky.clock_text(),
			"place": lake.nearest_place(boat.pos.x, boat.pos.y),
			"date": Time.get_datetime_string_from_system(false, true),
		}
		# Kertakalastuksen saaliit ennätyslistalle; uramoodin saalis menee saaviin
		_landing_record = false if Career.active else CatchLog.add(entry)
		FishBook.add(entry) # kalakirjaan kaikki saaliit, myös uramoodin
		_landing_entry = entry
		_landing_species = sp
		_landing_weight = weight
		population.remove_and_replace(_fish_index)
		_fish_index = -1
		_fish = {}
		_landing_prompt = false
		tension = 0.0
		state = State.LANDING # animaatio: haavi (avovesi) tai nosto avannosta (jää)
		_landing_net.start(_fish_pos, sp, weight, on_ice, current_hole)
		camera_rig.shot = _landing_net.camera_shot()
		camera_rig.shot_view = true
	else:
		_run_intensity = 1.0
		_run_dir = Vector2(_fish_pos.x - boat.pos.x, _fish_pos.z - boat.pos.y).normalized()
		_run_timer = 2.5
		sound_event.emit("fish_splash", _fish_pos)
		message.emit("Kala on vielä pirteä ja pakenee haavin luota!")


func _lose_fish(text: String, lose_lure: bool) -> void:
	if not lose_lure and _fish_pos.y > -1.0:
		sound_event.emit("fish_splash", _fish_pos)
	population.spook(_fish_index)
	_fish_index = -1
	_fish = {}
	_landing_prompt = false
	tension = 0.0
	if lose_lure:
		_lose_lure(text)
	else:
		state = State.RETRIEVING
		voice.emit("lost")
		_msg(text)


func _lose_lure(text: String) -> void:
	sound_event.emit("line_snap", rod_tip())
	lost_lures += 1
	if limited:
		var id: String = lure()["id"]
		inventory[id] = maxi(0, int(inventory.get(id, 0)) - 1)
		lure_lost.emit(id)
		if inventory[id] == 0:
			lure_index = 0
			text += " – %s loppui" % Lures.name_of(id) if has_lure() else " – uistimet loppuivat"
			_lure_node.mesh.material.albedo_color = lure()["color"]
	snagged = false
	state = State.READY
	voice.emit("snap")
	_msg(text)


# --- Ulkonäkö ---------------------------------------------------------------

func _build_visuals() -> void:
	_build_auger()
	_build_aim()
	_landing_net = LandingNet.new()
	add_child(_landing_net)
	_landing_net.setup(boat)
	_landing_net.sound.connect(func(n, at): sound_event.emit(n, at))
	_landing_net.finished.connect(_finish_landing)
	_build_holders()
	# Kaksi vapaa: kumpikin omine kelan, siiman ja uistimen solmuineen
	for i in ROD_COUNT:
		_build_rod_visuals()
		_rods.append({"lure_id": lure()["id"]})
		_cur = i
		_save_rod()
	_swap_to(0)


## Vapatelineet: putket perälaudan kulmissa
func _build_holders() -> void:
	_holders = Node3D.new()
	boat.hull.add_child(_holders)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.1)
	mat.roughness = 0.5
	for i in ROD_COUNT:
		var xf := holder_transform(i)
		var tube := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.022
		cyl.bottom_radius = 0.022
		cyl.height = 0.28
		cyl.material = mat
		tube.mesh = cyl
		# Sylinterin akseli (Y) vavan suuntaan (-Z), putken pohja telineen kohdalla
		tube.transform = Transform3D(xf.basis * Basis(Vector3.RIGHT, -PI / 2.0), xf * Vector3(0, 0, -0.14))
		_holders.add_child(tube)
		var foot := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.06, 0.08, 0.1)
		box.material = mat
		foot.mesh = box
		foot.position = xf.origin + Vector3(0, -0.02, 0)
		_holders.add_child(foot)


func _build_rod_visuals() -> void:
	_rod_pivot = Node3D.new()
	_rod_pivot.top_level = true # sijainti lasketaan itse: kädessä tai veneen pohjalla
	boat.angler.rod_mount.add_child(_rod_pivot)
	# Vapa piirretään joka ruudulla taipuneena (ImmediateMesh maailman koordinaateissa)
	_rod_mesh = ImmediateMesh.new()
	var rod := MeshInstance3D.new()
	rod.mesh = _rod_mesh
	rod.top_level = true
	var rod_mat := StandardMaterial3D.new()
	rod_mat.vertex_color_use_as_albedo = true
	rod_mat.roughness = 0.35
	rod.material_override = rod_mat
	_rod_pivot.add_child(rod) # piilotetaan vavan mukana (top_level: sijainti maailmassa)
	_build_reel()

	_line_mesh = ImmediateMesh.new()
	var line := MeshInstance3D.new()
	line.mesh = _line_mesh
	line.top_level = true
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(0.9, 0.9, 0.85, 0.8)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line.material_override = line_mat
	_rod_pivot.add_child(line)

	_lure_node = MeshInstance3D.new()
	var lure_mesh := SphereMesh.new()
	lure_mesh.radius = 0.04
	lure_mesh.height = 0.12
	var lure_mat := StandardMaterial3D.new()
	lure_mat.albedo_color = lure()["color"]
	lure_mat.metallic = 0.6
	lure_mat.roughness = 0.3
	lure_mesh.material = lure_mat
	_lure_node.mesh = lure_mesh
	_lure_node.top_level = true
	add_child(_lure_node)
	_build_bobber()
	_worm_node = MeshInstance3D.new()
	_worm_node.mesh = _worm()
	_worm_node.top_level = true
	_worm_node.visible = false
	add_child(_worm_node)

	_fish_node = MeshInstance3D.new()
	_fish_node.top_level = true
	_fish_node.visible = false
	_fish_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fish_node)


func _update_visuals() -> void:
	_lure_node.global_position = lure_pos
	# Ongen syötti (mato) ei näy veden alla; vavan kärjessä se roikkuu koukussa
	var shown := not (bait() and lure_pos.y < -0.02 and state in [State.RETRIEVING, State.BITE, State.FIGHT]) and not _rods_hidden_on_ice()
	_lure_node.visible = shown and not bait()
	_worm_node.visible = shown and bait()
	if _worm_node.visible:
		var t := Time.get_ticks_msec() / 1000.0 + _cur * 1.7
		_worm_node.global_transform = Transform3D(Basis(Vector3.UP, t * 0.8) * Basis(Vector3.RIGHT, sin(t * 2.3) * 0.25), lure_pos)
	_bobber_node.visible = lure()["kind"] == "bobber" and not on_ice and not lure_on_land and state in [State.RETRIEVING, State.BITE, State.FIGHT]
	if _bobber_node.visible:
		_bobber_node.global_transform = Transform3D(_bobber_tilt().scaled(Vector3.ONE * BOBBER_SCALE), _bobber_pos())
	_draw_rod()
	_draw_line()

	# Koukussa oleva kala: lajin malli rimpuilee nopealla uintiliikkeellä.
	# Humusvesi haalistaa syvällä olevan kalan (fish.gdshader).
	var show_fish := state == State.FIGHT and _fish_known # kala näkyy, kun sen tunnistaa
	_fish_node.visible = show_fish
	if show_fish:
		var sp: String = _fish["sp"]
		if _fish_node.mesh != FishModels.mesh(sp):
			_fish_node.mesh = FishModels.mesh(sp)
			_fish_node.material_override = FishModels.material(sp).duplicate()
		_fish_node.material_override.set_shader_parameter("swim_rate", 6.0 + _run_intensity * 14.0)
		var len_m := Species.length_cm(sp, _fish["weight"]) / 100.0
		var dir := Vector3(_run_dir.x, 0, _run_dir.y)
		_fish_node.global_position = _fish_pos
		if dir.length() > 0.01:
			_fish_node.look_at(_fish_pos + dir, Vector3.UP)
		_fish_node.scale = Vector3.ONE * len_m
	elif state == State.LANDED and not _last_catch.is_empty() and not on_ice:
		# Saalis veneen pohjalla kalastajan jalkojen edessä
		_place_fish_model(_last_catch["species"], _last_catch["length"] / 100.0, boat.hull.global_transform * Transform3D(Basis(Vector3.UP, 1.2) * Basis(Vector3.BACK, PI / 2.0), Vector3(0.1, -0.05, -0.35)), 1.0)
	elif on_ice and state == State.LANDED and not _last_catch.is_empty():
		# Saalis jäällä avannon vieressä, kyljellään
		var sp: String = _last_catch["species"]
		if _fish_node.mesh != FishModels.mesh(sp):
			_fish_node.mesh = FishModels.mesh(sp)
			_fish_node.material_override = FishModels.material(sp).duplicate()
		_fish_node.material_override.set_shader_parameter("swim_rate", 1.5) # sätkii hiljalleen
		var side := boat.right()
		var at := Vector3(current_hole.x + side.x * 0.45, 0.05, current_hole.z + side.y * 0.45)
		_fish_node.global_transform = Transform3D(Basis(Vector3.UP, boat.yaw + 0.3) * Basis(Vector3.BACK, PI / 2.0), at)
		_fish_node.scale = Vector3.ONE * _last_catch["length"] / 100.0
		_fish_node.visible = true


## Kela vavan kahvaan: runko, kela ja pyörivä kampi
func _build_reel() -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.12, 0.14)
	dark.metallic = 0.5
	dark.roughness = 0.4
	var silver := StandardMaterial3D.new()
	silver.albedo_color = Color(0.7, 0.72, 0.75)
	silver.metallic = 0.8
	silver.roughness = 0.3
	var reel := Node3D.new()
	reel.position = Vector3(0, -0.06, -0.3)
	_rod_pivot.add_child(reel)
	var parts := [
		[BoxMesh.new(), Vector3(0.012, 0.05, 0.03), Vector3(0, 0.035, 0), dark], # jalka
		[CylinderMesh.new(), Vector3(0.032, 0.05, 0.0), Vector3(0, 0, 0.005), dark], # runko
		[CylinderMesh.new(), Vector3(0.027, 0.03, 0.0), Vector3(0, 0, -0.035), silver], # kela
	]
	for part in parts:
		var mi := MeshInstance3D.new()
		var mesh: PrimitiveMesh = part[0]
		var size: Vector3 = part[1]
		if mesh is BoxMesh:
			mesh.size = size
		else:
			mesh.top_radius = size.x
			mesh.bottom_radius = size.x
			mesh.height = size.y
			mi.rotation.x = PI / 2.0 # kelan akseli vavan suuntaan
		mesh.material = part[3]
		mi.mesh = mesh
		mi.position = part[2]
		reel.add_child(mi)
	_reel_handle = Node3D.new()
	_reel_handle.position = Vector3(0.04, 0, 0.005)
	reel.add_child(_reel_handle)
	for arm in [[Vector3(0.006, 0.06, 0.006), Vector3(0, -0.03, 0)], [Vector3(0.02, 0.012, 0.012), Vector3(0.012, -0.06, 0)]]:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = arm[0]
		box.material = dark
		mi.mesh = box
		mi.position = arm[1]
		_reel_handle.add_child(mi)


## Vapa putkena taipuneen keskilinjan ympärille: korkkikahva ja ohenevat nikamat
func _draw_rod() -> void:
	_rod_mesh.clear_surfaces()
	if _rod_points.size() < 2:
		return
	var sides := 6
	var prev_ring := []
	_rod_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in _rod_points.size():
		var s := float(i) / (_rod_points.size() - 1)
		var a: Vector3 = _rod_points[maxi(i - 1, 0)]
		var b: Vector3 = _rod_points[mini(i + 1, _rod_points.size() - 1)]
		var dir := (b - a).normalized()
		var side := dir.cross(Vector3.UP)
		if side.length() < 0.01:
			side = dir.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(dir).normalized()
		var handle := s * rod_length < 0.4
		var r := 0.016 if handle else lerpf(0.01, 0.0025, s)
		var col := Color(0.62, 0.48, 0.3) if handle else Color(0.08, 0.1, 0.16)
		var ring := []
		for k in sides:
			var ang := TAU * k / sides
			var n := side * cos(ang) + up * sin(ang)
			ring.append([_rod_points[i] + n * r, n, col])
		if i > 0:
			for k in sides:
				var k2 := (k + 1) % sides
				for v in [prev_ring[k], ring[k], ring[k2], prev_ring[k], ring[k2], prev_ring[k2]]:
					_rod_mesh.surface_set_normal(v[1])
					_rod_mesh.surface_set_color(v[2])
					_rod_mesh.surface_add_vertex(v[0])
		prev_ring = ring
	_rod_mesh.surface_end()


## Koho pinnalla syötin yläpuolella. Se kelluu aallokon mukana samassa
## aaltomallissa kuin vesipinta ja vene. Tärpissä koho nykii ja lopuksi painuu
## pinnan alle; väsytyksessä kala vetää sen pinnan alle.
func _bobber_pos() -> Vector3:
	var y := Waves.swell_height(Vector2(lure_pos.x, lure_pos.z))
	if state == State.BITE:
		if _bite_timer > BAIT_SINK_TIME:
			y -= absf(sin(_bite_timer * 17.0)) * 0.03 # nykii
		else:
			y -= 0.18 # upposi
	elif state == State.FIGHT:
		y -= 0.25
	return Vector3(lure_pos.x, y, lure_pos.z)


## Kohon kallistus: pinnan suuntainen aallon rinteessä, ja lisäksi se
## keinuu pienissä laineissa sitä enemmän, mitä kovempi tuuli on
func _bobber_tilt() -> Basis:
	var p := Vector2(lure_pos.x, lure_pos.z)
	var e := 0.2
	var normal := Vector3(
		Waves.swell_height(p - Vector2(e, 0)) - Waves.swell_height(p + Vector2(e, 0)),
		2.0 * e,
		Waves.swell_height(p - Vector2(0, e)) - Waves.swell_height(p + Vector2(0, e))).normalized()
	var t := Waves.time
	var rock := 0.04 + Waves.strength * 0.22 # rad
	var axis_x := sin(t * 2.9 + p.x * 0.7) * 0.7 + sin(t * 4.3 + p.y) * 0.3
	var axis_z := sin(t * 2.3 + p.y * 0.7) * 0.7 + sin(t * 3.7 + p.x) * 0.3
	return Basis(Vector3.RIGHT, axis_x * rock) * Basis(Vector3.BACK, axis_z * rock) * Basis(Quaternion(Vector3.UP, normal))


## Mato koukussa: kaareva, kapeneva putki, jossa tummempi vyö. Roikkuu
## kiinnityskohdasta (origo) alaspäin noin 7 cm.
static func _worm() -> ArrayMesh:
	if _worm_mesh:
		return _worm_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 24
	var sides := 8
	var length := 0.075
	var points := []
	for i in rings + 1:
		var u := float(i) / rings
		# Mato on puolivälistä koukussa: molemmat päät roikkuvat ja kiemurtelevat
		var y := -length * absf(u * 2.0 - 1.0) * 0.6 - 0.004 # keskeltä koukussa, päät roikkuvat
		var x := (u - 0.5) * 0.035 + sin(u * PI * 3.0) * 0.006
		var z := cos(u * PI * 2.0) * 0.005
		points.append(Vector3(x, y, z))
	var pink := Color(0.78, 0.42, 0.42)
	var band := Color(0.6, 0.28, 0.3)
	var prev := []
	for i in points.size():
		var u := float(i) / rings
		var a: Vector3 = points[maxi(i - 1, 0)]
		var b: Vector3 = points[mini(i + 1, points.size() - 1)]
		var dir := (b - a).normalized()
		var side := dir.cross(Vector3.FORWARD).normalized()
		if side.length() < 0.1:
			side = dir.cross(Vector3.UP).normalized()
		var up := side.cross(dir).normalized()
		var r := 0.0032 * clampf(minf(u, 1.0 - u) * 6.0, 0.35, 1.0) # kapenevat päät
		var col := band if absf(u - 0.3) < 0.05 else pink.darkened(0.1 * sin(u * 60.0)) # vyö ja renkaat
		var ring := []
		for k in sides:
			var ang := TAU * k / sides
			var n := side * cos(ang) + up * sin(ang)
			ring.append([points[i] + n * r, n, col])
		if i > 0:
			for k in sides:
				var k2 := (k + 1) % sides
				for v in [prev[k], ring[k], ring[k2], prev[k], ring[k2], prev[k2]]:
					st.set_color(v[2])
					st.set_normal(v[1])
					st.add_vertex(v[0])
		prev = ring
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.35 # kostea pinta
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	_worm_mesh = st.commit()
	return _worm_mesh


## Koho: punainen yläpää, valkoinen alapää ja keltainen tikku. Hieman
## oikeaa isompi, jotta sen näkee pelikamerasta heittomatkan päästä.
func _build_bobber() -> void:
	_bobber_node = Node3D.new()
	_bobber_node.scale = Vector3.ONE * BOBBER_SCALE
	_bobber_node.top_level = true
	_bobber_node.visible = false
	add_child(_bobber_node)
	for part in [[Color(0.9, 0.12, 0.08), 0.012], [Color(0.95, 0.95, 0.92), -0.012]]:
		var mi := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.022
		sphere.height = 0.04
		var mat := StandardMaterial3D.new()
		mat.albedo_color = part[0]
		sphere.material = mat
		mi.mesh = sphere
		mi.position = Vector3(0, part[1], 0)
		mi.scale = Vector3(1.0, 0.7, 1.0)
		_bobber_node.add_child(mi)
	var stick := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.003
	cyl.bottom_radius = 0.003
	cyl.height = 0.08
	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = Color(1.0, 0.85, 0.1)
	yellow.emission_enabled = true
	yellow.emission = Color(0.5, 0.4, 0.0) # erottuu kaukaakin
	cyl.material = yellow
	stick.mesh = cyl
	stick.position = Vector3(0, 0.06, 0)
	_bobber_node.add_child(stick)


## Siima vavan kärjestä uistimelle (tai kalalle):
## - roikkuma riippuu jännityksestä (kireä siima on suora)
## - ylimääräinen siima (siimaa ulkona enemmän kuin välimatka) roikkuu kaarella
## - tuuli taivuttaa löysää siimaa sivulle
## - vedessä siima lepää pinnalla ja painuu suoraan uistimelle
func _draw_line() -> void:
	_line_mesh.clear_surfaces()
	var tip := rod_tip()
	var end := _bobber_pos() if _bobber_node.visible else lure_pos # koho-ongella siima kohoon (kohon alla oleva siima ei näy)
	var span := tip.distance_to(end)
	if span < 0.02:
		return
	var in_water := state in [State.RETRIEVING, State.BITE, State.FIGHT] and not lure_on_land
	var excess := 0.0
	if state in [State.RETRIEVING, State.BITE, State.FIGHT]:
		excess = maxf(0.0, line_out - span)
	var tension_n := tension * 9.81 + 0.25
	var sag := maxf(LINE_WEIGHT * span * span / (8.0 * tension_n), sqrt(3.0 * span * excess / 8.0))
	sag = minf(sag, span * 0.45)
	var chord := end - tip
	var flat := Vector3(chord.x, 0, chord.z)
	var perp := Vector3(-flat.z, 0, flat.x).normalized() if flat.length() > 0.01 else Vector3.ZERO
	var wind := weather.vector()
	var bow := clampf(Vector3(wind.x, 0, wind.y).dot(perp) * 0.08 * sag, -span * 0.2, span * 0.2)
	var n := 32
	var entry_t := -1.0
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in n + 1:
		var t := float(i) / n
		var hump := 4.0 * t * (1.0 - t)
		var p := tip.lerp(end, t)
		p.y -= sag * hump
		p += perp * bow * hump
		if in_water:
			if entry_t < 0.0 and p.y <= 0.0:
				entry_t = t
			if entry_t >= 0.0:
				var u := (t - entry_t) / maxf(1.0 - entry_t, 0.001)
				p.y = maxf(p.y, lerpf(0.0, end.y, u)) # pinnalta suoraan uistimelle
		_line_mesh.surface_add_vertex(p)
	_line_mesh.surface_end()




# --- Pilkkiminen ----------------------------------------------------------------

## Talven ohjaus: vasen hiiri kairaa (pidä pohjassa) tai laskee pilkin avantoon.
## Palauttaa true, jos tapahtuma käsiteltiin.
func _ice_input(event: InputEvent) -> bool:
	if event.is_action_pressed("cast") and state == State.READY:
		var hole := hole_in_front()
		if hole != Vector3.INF:
			current_hole = hole
			state = State.RETRIEVING
			lure_pos = Vector3(hole.x, -0.02, hole.z)
			line_out = rod_tip().distance_to(Vector3(hole.x, 0.0, hole.z)) + 0.02
			sound_event.emit("lure_splash", lure_pos)
			message.emit("Pilkki avantoon – vasen hiiri laskee, oikea nostaa, välilyönti nykäisee")
		else:
			var front := boat.pos + boat.forward() * HOLE_AHEAD
			if not lake.is_water(front.x, front.y) or lake.depth_at(front.x, front.y) < 0.4:
				message.emit("Kairaa reikä jäälle, jossa on vettä alla")
			else:
				state = State.DRILLING
				power = 0.0
				_auger.global_position = Vector3(front.x, 0.0, front.y)
				_auger.visible = true
				sound_event.emit("ice_drill", _auger.global_position)
		return true
	if event.is_action_released("cast") and state == State.DRILLING:
		state = State.READY
		_auger.visible = false
		message.emit("Kairaus keskeytyi")
		return true
	if event.is_action_pressed("twitch") and state == State.RETRIEVING:
		_twitch = 1.0
		return true
	return false


func _drill(dt: float) -> void:
	power = minf(1.0, power + dt / DRILL_TIME)
	_auger.rotation.y += dt * 9.0
	_auger.position.y = -power * 0.35 # kaira painuu jäähän
	if power >= 1.0:
		var front := boat.pos + boat.forward() * HOLE_AHEAD
		var hole := Vector3(front.x, 0.0, front.y)
		holes.append(hole)
		_add_hole_visual(hole)
		_auger.visible = false
		state = State.READY
		voice.emit("hole")
		message.emit("Reikä valmis (jää %d cm) – vasen hiiri laskee pilkin" % _rng.randi_range(35, 55))


## Pilkki avannossa: vasen hiiri pohjassa laskee siimaa, oikea kelaa ylös,
## välilyönti nykäisee pilkkiä ylös, minkä jälkeen se vajoaa takaisin.
func _ice_retrieve(dt: float) -> void:
	var h := current_hole
	var tip := rod_tip()
	var tip_to_hole := tip.distance_to(Vector3(h.x, 0.0, h.z))
	var reel := _reel_speed()
	if Input.is_action_pressed("cast") and GameInput.active():
		line_out += 0.8 * dt
	line_out = maxf(tip_to_hole, line_out - reel * dt)
	var bottom := lake.depth_at(h.x, h.z)
	var target := clampf(line_out - tip_to_hole, 0.0, maxf(0.0, bottom - 0.03))
	target = maxf(0.0, target - _twitch * 0.3) # nykäisy nostaa pilkkiä
	var depth := lure_depth()
	var before := depth
	if target > depth:
		depth = move_toward(depth, target, lure()["sink"] * dt * 1.6) # vajoaa
	else:
		depth = move_toward(depth, target, 3.0 * dt) # siima nostaa
	lure_pos = Vector3(h.x, -depth, h.z)
	lure_speed = lerpf(lure_speed, absf(depth - before) / dt, minf(1.0, dt * 6.0))
	var slack := line_out - tip_to_hole - depth
	tension = 0.0 if slack > 0.05 else 0.02 + lure()["pull"] * lure_speed
	_check_timer -= dt
	if _check_timer <= 0.0 and depth > 0.2:
		_check_timer = 0.2
		var idx := population.check_lure(Vector2(h.x, h.z), depth, lure_speed, _twitch, lure(), sky.hour(), 2.0, 0.2, weather.cloud_cover, weather.feeding_factor())
		if idx >= 0:
			_fish_index = idx
			_fish = population.fish[idx]
			state = State.BITE
			_bite_timer = _rng.randf_range(0.6, 1.0)
			_bend_vel += 3.0 # vavan kärki nykäisee
			sound_event.emit("bite_tick", tip)
			voice.emit("bite")
			message.emit("TÄRPPI! Vastaisku – vasen hiiri!")
	if depth <= 0.01 and reel > 0.0 and line_out <= tip_to_hole + 0.01:
		state = State.READY # pilkki ylhäällä


func _add_hole_visual(hole: Vector3) -> void:
	var slush := StandardMaterial3D.new()
	slush.albedo_color = Color(0.78, 0.8, 0.82)
	slush.roughness = 0.9
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.03, 0.05, 0.06)
	water.roughness = 0.1
	water.metallic = 0.3
	for part in [[0.36, 0.03, slush], [0.075, 0.035, water]]:
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = part[0]
		cyl.bottom_radius = part[0] * 1.1
		cyl.height = part[1]
		cyl.radial_segments = 20
		cyl.material = part[2]
		mi.mesh = cyl
		mi.position = hole + Vector3(0, part[1] / 2.0, 0)
		_holes_node.add_child(mi)


## Jääkaira: varsi, terä, kampi ja kahva
func _build_auger() -> void:
	_holes_node = Node3D.new()
	_holes_node.top_level = true
	add_child(_holes_node)
	_auger = Node3D.new()
	_auger.top_level = true
	_auger.visible = false
	add_child(_auger)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.7, 0.72, 0.75)
	steel.metallic = 0.8
	steel.roughness = 0.35
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(0.15, 0.3, 0.65)
	var grip := StandardMaterial3D.new()
	grip.albedo_color = Color(0.1, 0.1, 0.1)
	var parts := [
		[CylinderMesh.new(), 0.018, 1.0, Vector3(0, 0.5, 0), Vector3.ZERO, blue], # varsi
		[CylinderMesh.new(), 0.075, 0.35, Vector3(0, 0.15, 0), Vector3.ZERO, steel], # kierreterä
		[CylinderMesh.new(), 0.012, 0.32, Vector3(0.0, 1.0, 0), Vector3(0, 0, PI / 2.0), grip], # kahva
		[CylinderMesh.new(), 0.01, 0.17, Vector3(0.08, 0.78, 0), Vector3(0, 0, PI / 2.0), blue], # kampi
		[CylinderMesh.new(), 0.014, 0.1, Vector3(0.16, 0.82, 0), Vector3.ZERO, grip], # kammen nuppi
	]
	for part in parts:
		var mi := MeshInstance3D.new()
		var cyl: CylinderMesh = part[0]
		cyl.top_radius = part[1]
		cyl.bottom_radius = part[1]
		cyl.height = part[2]
		cyl.material = part[5]
		mi.mesh = cyl
		mi.position = part[3]
		mi.rotation = part[4]
		_auger.add_child(mi)


# --- Haavinta -------------------------------------------------------------------

func net_active() -> bool:
	return state == State.LANDING and _landing_net.net_in_hands()


## Kalastajan kädet haavinnassa: [oikea, vasen] (vain oikea = vasen pitää vapaa)
func net_grips() -> Array:
	return _landing_net.grips()


## Kalastaja nojaa eteen haavia ojentaessaan
func net_lean() -> float:
	return _landing_net.lean() if state == State.LANDING else 0.0


func _finish_landing() -> void:
	camera_rig.shot_view = false
	_last_catch = _landing_entry
	state = State.LANDED
	caught.emit(_landing_entry, _landing_record)
	var kg: float = _landing_entry["weight"]
	voice.emit("big" if kg >= 2.0 or _landing_record else ("small" if kg < 0.08 else "landed"))


func _place_fish_model(sp: String, len_m: float, xf: Transform3D, wiggle: float) -> void:
	if _fish_node.mesh != FishModels.mesh(sp):
		_fish_node.mesh = FishModels.mesh(sp)
		_fish_node.material_override = FishModels.material(sp).duplicate()
	_fish_node.material_override.set_shader_parameter("swim_rate", wiggle)
	_fish_node.global_transform = Transform3D(xf.basis.orthonormalized().scaled(Vector3.ONE * len_m), xf.origin)
	_fish_node.visible = true

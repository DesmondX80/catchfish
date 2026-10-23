extends Node
## Verkkokalastuksen testi: godot --headless --fixed-fps 30 -- --day=180 --nettest
## (talvi: --day=40 --nettest)  [--nettest-shots=KANSIO: kuvat laskusta ja nostosta, vaatii ikkunan]
## Verkko lasketaan perästä veneen kulkiessa (30 m, kaksi pyykkiä, linja vedessä),
## matalaan ei voi laskea, ja tunteja myöhemmin pyykin luota nostettaessa vene
## liukuu verkkoa pitkin, kalastaja vetää verkkoa laidan yli, kalat näkyvät verkossa ja tulevat
## saaviin ja kalakirjaan (sama saalis kuin saalismallin laskema). Saalismalli on
## toistettava, silmäkoko ratkaisee kalojen koon, ja verkko säilyy uran
## tallennuksen (JSON) yli. Talvella verkkoa ei voi laskea.

var main: Node
var _log: Array[String] = []
var _messages: Array[String] = []
var _summaries: Array[String] = []
var _step := 0
var _t := 0.0
var _spot := Vector2.ZERO
var _heading := 0.0
var _expected: Array = []
var _catch_before := 0
var _book_before := 0
var _haul_start := Vector2.ZERO
var _saw_net_pose := false
var _saw_fish_in_net := false
var _max_speed_warned := false
var _shots := ""
var _shot_timer := 0.0
var _close_frames := 0


func _ready() -> void:
	main = get_parent()
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	main.nets.message.connect(func(text): _messages.append(text))
	main.nets.summary.connect(func(text): _summaries.append(text))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--nettest-shots="):
			_shots = arg.split("=")[1]
	if main.boat.on_ice:
		_winter()
		return
	_find_spot()
	_model_checks()


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _next() -> void:
	_step += 1
	_t = 0.0


## Kuvakaappaus sivulta veneen perän puoleen: kamera from-suunnassa (rungon koordinaatit)
func _aim(from: Vector3, at: Vector3) -> void:
	var rig: CameraRig = main.camera_rig
	var hull: Transform3D = main.boat.hull.global_transform
	var eye := hull * from
	rig.shot = Transform3D.IDENTITY.looking_at(hull * at - eye, Vector3.UP).translated(eye)
	rig.shot_view = true


func _shot(name: String) -> void:
	if _shots != "":
		get_viewport().get_texture().get_image().save_png(_shots.path_join(name + ".png"))


func _finish() -> void:
	print("\n".join(_log))
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)


func _winter() -> void:
	var nets: NetControl = main.nets
	_check("talvella järvi on jäässä verkoille", nets.frozen)
	nets.toggle()
	_check("talvella verkkoa ei voi laskea", nets.nets.is_empty() and _messages.any(func(m): return m.contains("jäässä")))
	_check("talvella ei verkkotilaa HUDissa", nets.status_text() == "")
	_finish()


## Avovettä: syvyys 2–3,5 m ja suunta, johon 40 m on vähintään 1,5 m vettä
func _find_spot() -> void:
	var lake: LakeData = main.lake
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var size := lake.world_size()
	for i in 20000:
		var p := Vector2(lake.origin_x + rng.randf() * size.x, lake.origin_z + rng.randf() * size.y)
		var d := lake.depth_at(p.x, p.y)
		if d < 2.0 or d > 3.5 or lake.near_dock(p, 30.0):
			continue
		for a in 8:
			var yaw := a * TAU / 8.0
			var fwd := Vector2(-sin(yaw), -cos(yaw)) # Boat.forward()
			var ok := true
			for k in range(-5, 46, 5):
				var q := p + fwd * k
				ok = ok and lake.depth_at(q.x, q.y) > 1.5
			if ok:
				_spot = p
				_heading = yaw
				return


func _calm() -> void:
	var w: Weather = main.weather
	w.wind_base = 0.0
	w.gust = 0.0
	w._wind_target = 0.0
	w._gust_timer = 999.0


## Saalismalli ilman pelinäkymää: toistettavuus, silmäkoko, tallennus
func _model_checks() -> void:
	var lake: LakeData = main.lake
	var doy := func(m): return int(m / 1440.0)
	var line := []
	var fwd := Vector2(-sin(_heading), -cos(_heading))
	for i in 31:
		var p := _spot + fwd * i
		line.append(p.x)
		line.append(p.y)
	var net := {"id": "verkko35", "points": line, "laid_at": 180 * 1440.0 + 19 * 60, "seed": 5, "wear": 0}
	var a := Nets.catch_between(net, lake, net["laid_at"], net["laid_at"] + 720.0, doy)
	var b := Nets.catch_between(net, lake, net["laid_at"], net["laid_at"] + 720.0, doy)
	_check("saalismalli on toistettava (%d kalaa)" % a["fish"].size(), a == b)
	var short := Nets.catch_between(net, lake, net["laid_at"], net["laid_at"] + 60.0, doy)
	_check("lyhyt pyynti tuo vähemmän kuin yö (%d < %d)" % [short["fish"].size(), a["fish"].size()], short["fish"].size() < a["fish"].size())
	# Silmäkoko: pieni silmä pyytää pieniä kaloja, iso isoja
	var mean := {}
	for id in ["verkko22", "verkko50"]:
		var kg := 0.0
		var n := 0
		for s in 30:
			var d := net.duplicate()
			d["id"] = id
			d["seed"] = s
			for f in Nets.catch_between(d, lake, d["laid_at"], d["laid_at"] + 720.0, doy)["fish"]:
				kg += f["weight"]
				n += 1
		mean[id] = kg / maxi(n, 1)
	_check("22 mm:n kalat pienempiä kuin 50 mm:n (%.2f < %.2f kg)" % [mean["verkko22"], mean["verkko50"]], mean["verkko22"] < mean["verkko50"] * 0.5)
	_check("silmäkoon valinta: 35 mm pitää 22 cm ahvenesta, ei 10 cm ahvenesta", Nets.selectivity("ahven", 35.0, 22.0) > 0.9 and Nets.selectivity("ahven", 35.0, 10.0) < 0.05)
	# Uran tallennus: JSON-kierroksen jälkeen sama verkko ja sama saalis
	var loaded: Dictionary = JSON.parse_string(JSON.stringify({"nets": [net]}))["nets"][0]
	var c := Nets.catch_between(loaded, lake, loaded["laid_at"], loaded["laid_at"] + 720.0, doy)
	_check("verkko säilyy tallennuksen yli (sama linja ja saalis)", Nets.points(loaded) == Nets.points(net) and c["fish"].size() == a["fish"].size())
	_check("uran kello: päivä 1 klo 7 on 1.6. (vuodenpäivä 152)", Career.day_of_year_at(1 * 1440.0 + 420.0) == 152)
	# Jäiden aikaan verkko ei pyydä
	var frozen := Nets.catch_between(net, lake, 40 * 1440.0, 40 * 1440.0 + 720.0, doy)
	_check("jäiden aikaan verkko ei pyydä", frozen["fish"].is_empty())


func _physics_process(delta: float) -> void:
	if main.boat.on_ice:
		return
	_t += delta
	var boat: Boat = main.boat
	var nets: NetControl = main.nets
	_saw_net_pose = _saw_net_pose or boat.angler.pose == Angler.Pose.NET
	_calm()
	match _step:
		0:
			# Matalaan ei lasketa
			var shallow := _shallow_spot()
			boat.pos = shallow + boat.forward() * Boat.LENGTH * 0.5
			boat.velocity = Vector2.ZERO
			if _t > 0.3:
				nets.toggle()
				_check("matalaan ei voi laskea verkkoa", nets.nets.is_empty() and _messages.any(func(m): return m.begins_with("Liian matalaa")))
				_next()
		1:
			boat.yaw = _heading
			boat.yaw_rate = 0.0
			boat.pos = _spot + boat.forward() * Boat.LENGTH * 0.5 # perä paikan päällä
			boat.velocity = Vector2.ZERO
			if _t > 0.5:
				var before := nets.count("verkko35")
				nets.selected = 1 # 35 mm
				_check("lasku alkaa", nets.start_laying() and nets.laying != null)
				_check("verkko otettiin varastosta", nets.count("verkko35") == before - 1)
				_next()
		2:
			# Vene kulkee eteen 1 m/s: verkko valuu laidan yli veneen reitille
			boat.velocity = boat.forward() * (2.2 if _t < 3.0 else 1.0)
			boat.yaw_rate = 0.0
			if _shots != "" and nets.laying and _t > 4.0:
				_aim(Vector3(3.2, 1.6, 3.4), Vector3(0.7, 0.3, 1.8))
				if _t > 6.0 and _t < 6.05:
					_shot("verkko-1-lasku")
			if nets.laying and _t > 1.0 and _t < 1.1:
				var entry := GillNet.lay_entry(boat)
				var rel := entry - boat.pos
				_check_once("laskettava verkko näkyy löysänä nippuna, ei perän ristikkona", nets.laying._loose.visible and nets.laying._loose_mesh.get_surface_count() == 2)
				_check_once("verkko valuu oikean laidan yli perän läheltä (sivulle %.2f m, taakse %.2f m)" % [rel.dot(boat.right()), -rel.dot(boat.forward())], rel.dot(boat.right()) > 0.9 and -rel.dot(boat.forward()) > 1.5 and -rel.dot(boat.forward()) < Boat.LENGTH * 0.5 + 0.6)
			_max_speed_warned = _max_speed_warned or _messages.any(func(m): return m.begins_with("Hiljempaa"))
			if nets.laying == null:
				var net: GillNet = nets.nets[0]
				var pts := net.points()
				var all_water := true
				for p in pts:
					all_water = all_water and main.lake.depth_at(p.x, p.y) > 0.8
				_check("verkko laskettu kokonaan (%.1f m, %d pistettä)" % [net.laid_length, pts.size()], absf(net.laid_length - Nets.LENGTH) < 0.6 and pts.size() >= 30)
				_check("verkon linja vedessä", all_water)
				_check("liian kova vauhti varoitti ja verkko jarrutti", _max_speed_warned)
				_check("molemmat pyykit näkyvät", net._buoys[0].visible and net._buoys[1].visible)
				_check("pyykki pinnalla (%.2f m)" % net._buoys[1].global_position.y, absf(net._buoys[1].global_position.y) < 0.4)
				_check("verkko pyytää: tila SET", net.state == GillNet.State.SET)
				_check("verkko näkyy kartalla", nets.map_lines().size() == 1 and nets.map_lines()[0]["points"].size() >= 30)
				_next()
			elif _t > 60.0:
				_check("lasku valmistui", false)
				_finish()
		3:
			# Yö kuluu: 12 tuntia, sitten pyykin luo (toinen pää)
			boat.velocity = Vector2.ZERO
			if _t > 0.5:
				main.sky.minutes += 12.0 * 60.0
				var net: GillNet = nets.nets[0]
				var end: Vector2 = net.ends()[1]
				boat.yaw = wrapf(_heading + PI, -PI, PI) # keula takaisin päin, perä pyykillä
				boat.pos = end + boat.forward() * (Boat.LENGTH * 0.5 + 1.5)
				_next()
		4:
			boat.velocity = Vector2.ZERO
			if _t > 0.3:
				var nets_net: GillNet = nets.nets[0]
				_check("pyykin luona vihje nostosta", nets.status_text().begins_with("N: nosta verkko"))
				_expected = Nets.catch_between(nets_net.data, main.lake, float(nets_net.data["laid_at"]), nets.now_abs(), nets.day_of_year_at)["fish"]
				_catch_before = main.trip_catch.size()
				_book_before = 0
				for sp in Species.DATA:
					_book_before += FishBook.count(sp)
				_haul_start = boat.pos
				nets.toggle()
				_check("nosto alkaa pyykin luota", nets.hauling != null)
				_next()
		5:
			var net: GillNet = nets.hauling
			if net and _shots != "":
				_shot_timer = _shot_timer + delta if _once.has("shot2") else 0.0
				var rising := -1
				for i in net._fish_nodes.size():
					if net._fish_nodes[i].visible and net.haul_fish[i]["at_m"] - net.haul_s < 1.0:
						rising = i
						break
				if _shot_timer > 0.5:
					_aim(Vector3(-0.4, 1.9, 0.2), Vector3(0.5, -0.1, 1.2)) # veneen sisältä: kasa ja kalastaja
				elif rising >= 0 and not _once.has("shot2"):
					# Lähikuva verkossa nousevasta kalasta
					var f: Vector3 = net._fish_nodes[rising].global_position
					var r := Vector3(boat.right().x, 0.0, boat.right().y)
					var eye := f + r * 1.3 + Vector3.UP * 0.5 - Vector3(boat.forward().x, 0.0, boat.forward().y) * 0.6
					main.camera_rig.shot = Transform3D.IDENTITY.looking_at(f - eye, Vector3.UP).translated(eye)
					main.camera_rig.shot_view = true
					_close_frames += 1
					if _close_frames > 45:
						_once["shot2"] = true
						_shot("verkko-2-nosto")
				else:
					_aim(Vector3(2.8, 1.3, 3.6), Vector3(0.8, 0.2, 2.0))
				if _shot_timer > 2.5 and not _once.has("shot4"):
					_once["shot4"] = true
					_shot("verkko-3-kasa")
			if net:
				if net.haul_s > 1.0:
					_check_once("nostossa verkko nousee löysänä laidan yli", net._loose.visible and net._loose_mesh.get_surface_count() == 2)
				for f in net._fish_nodes:
					if f.visible and not _saw_fish_in_net:
						_saw_fish_in_net = true
						var rel := Vector2(f.global_position.x, f.global_position.z) - boat.pos
						_check("kala roikkuu verkossa oikean laidan ulkopuolella (%.2f m sivulle)" % rel.dot(boat.right()), rel.dot(boat.right()) > 0.6)
				_check_once("nostossa kalastajan kädet verkolla", boat.net_hands.size() == 2)
			if nets.hauling == null:
				var got: int = main.trip_catch.size() - _catch_before
				var book := 0
				for sp in Species.DATA:
					book += FishBook.count(sp)
				_check("saaliiksi tuli mallin saalis (%d kalaa)" % got, got == _expected.size() and got > 0)
				_check("verkkokalat kalakirjaan", book - _book_before == got)
				_check("merkinnässä verkon nimi", main.trip_catch.back()["lure"] == "Verkko 35 mm")
				_check("kalat näkyivät verkossa nostettaessa", _saw_fish_in_net)
				_check("kalastaja nosti perätuhdolla", _saw_net_pose)
				_check("vene liukui verkkoa pitkin (%.1f m)" % boat.pos.distance_to(_haul_start), boat.pos.distance_to(_haul_start) > 20.0)
				_check("verkko palasi veneeseen", nets.nets.is_empty() and nets.count("verkko35") == NetControl.FREE_NETS)
				_check("noston yhteenveto", _summaries.size() == 1 and _summaries[0].begins_with("VERKKO NOSTETTU"))
				_check("kädet vapaina noston jälkeen", boat.net_hands.is_empty() and boat.stern_pull == Vector2.ZERO)
				_finish()
			elif _t > 120.0:
				_check("nosto valmistui", false)
				_finish()


var _once := {}


func _check_once(name: String, ok: bool) -> void:
	if not _once.has(name):
		_once[name] = true
		_check(name, ok)


func _shallow_spot() -> Vector2:
	var lake: LakeData = main.lake
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var size := lake.world_size()
	for i in 50000:
		var p := Vector2(lake.origin_x + rng.randf() * size.x, lake.origin_z + rng.randf() * size.y)
		var d := lake.depth_at(p.x, p.y)
		if d > 0.5 and d < 0.9 and not lake.near_dock(p, 20.0):
			return p
	return _spot

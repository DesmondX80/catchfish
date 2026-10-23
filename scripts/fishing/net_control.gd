class_name NetControl
extends Node
## Verkkokalastus: verkon lasku ja nosto (N), silmäkoon valinta (B), järvessä
## olevat verkot ja niiden saalis. Verkko lasketaan laidan yli perän läheltä
## soutaen tai ajaen,
## ja se jää pyytämään. Nosto alkaa pyykin luota: kalastaja vetää verkkoa
## laidan yli perän läheltä, ja vene liukuu verkkoa pitkin. Saalis lasketaan koko
## pyyntiajalta (Nets.catch_between) ja kirjataan kuten vapakalat.
## Uramoodissa verkot ostetaan kaupasta ja ne jäävät järveen reissujen yli
## (Career.nets); kertakalastuksessa verkkoja on kolme kutakin silmäkokoa ja ne
## katoavat reissun lopussa.

signal message(text: String)
signal summary(text: String) # noston yhteenveto

const START_MIN_DEPTH := 1.2 # m: verkon laskun alussa vähintään
const LAY_MIN_DEPTH := 0.8 # m: tätä matalammassa lasku päättyy
const LAY_MAX_SPEED := 1.5 # m/s: kovempaa verkko purkautuu jarruttaen
const LAY_MIN_LENGTH := 5.0 # m: lyhyempi lasku perutaan (verkko takaisin veneeseen)
const HAUL_REACH := 4.0 # m: pyykki enintään näin kaukana perästä
const HAUL_MAX_SPEED := 0.8 # m/s: nostoon pysähdytään pyykin luo
const FREE_NETS := 3 # kertakalastus: kutakin silmäkokoa

var boat: Boat
var lake: LakeData
var sky: SkyTime
var fishing: Fishing
var trip_catch: Array
var nets: Array[GillNet] = []
var inventory: Dictionary = {}
var selected := 0 # Nets.LIST-indeksi
var frozen := false
var laying: GillNet = null
var hauling: GillNet = null
var _speed_warned := false
var _haul_summary: Array = []
var _haul_tears := 0


func setup(boat_node: Boat, lake_data: LakeData, sky_time: SkyTime, fishing_node: Fishing, catch: Array, is_frozen: bool) -> void:
	boat = boat_node
	lake = lake_data
	sky = sky_time
	fishing = fishing_node
	trip_catch = catch
	frozen = is_frozen
	if Career.active:
		inventory = Career.lures # sama sanakirja kuin uistimilla
		if frozen and not Career.nets.is_empty():
			Career.nets = []
			Career.save_game()
			message.emit.call_deferred("Verkot jäivät jään alle – ne menetettiin")
		for data in Career.nets:
			_add_net(data, false)
	else:
		for n in Nets.LIST:
			inventory[n["id"]] = FREE_NETS
	# Valitaan silmäkoko, jota on varastossa
	for i in Nets.LIST.size():
		if count(Nets.LIST[i]["id"]) > 0:
			selected = i
			break


func count(id: String) -> int:
	return int(inventory.get(id, 0))


func selected_net() -> Dictionary:
	return Nets.LIST[selected]


## Absoluuttinen kello (päivä * 1440 + minuutit)
func now_abs() -> float:
	if Career.active:
		return Career.abs_minutes(sky.minutes)
	return sky.day_of_year * 1440.0 + sky.minutes


func day_of_year_at(abs_min: float) -> int:
	if Career.active:
		return Career.day_of_year_at(abs_min)
	return (int(abs_min / 1440.0) - 1) % 365 + 1


func stern() -> Vector2:
	return boat.pos - boat.forward() * Boat.LENGTH * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if not GameInput.active():
		return
	if (laying or hauling) and event.is_action_pressed("cast"):
		get_viewport().set_input_as_handled() # ei heitetä verkon päälle
		message.emit("Verkko on kesken – ei heitetä nyt")
	elif event.is_action_pressed("net_toggle"):
		toggle()
	elif event.is_action_pressed("net_mesh"):
		cycle_mesh()


func cycle_mesh() -> void:
	if laying or hauling:
		return
	selected = (selected + 1) % Nets.LIST.size()
	var n := selected_net()
	message.emit("Verkko: %s (%s) – %d kpl" % [n["name"], n["hint"], count(n["id"])])


## N: lasku loppuu, nosto alkaa pyykin luona tai uusi lasku alkaa
func toggle() -> void:
	if hauling:
		return
	if laying:
		_finish_laying("")
		return
	if frozen:
		message.emit("Järvi on jäässä – verkkoa ei voi laskea")
		return
	var near := near_net()
	if near:
		start_haul(near)
	else:
		start_laying()


## Verkko, jonka pyykki on perän lähellä, tai null
func near_net() -> GillNet:
	var best: GillNet = null
	var best_d := HAUL_REACH
	for n in nets:
		if n.state != GillNet.State.SET:
			continue
		var d: float = n.nearest_end(GillNet.lay_entry(boat))[1]
		if d <= best_d:
			best = n
			best_d = d
	return best


## Syy, miksi verkkoa ei voi nyt käsitellä, tai tyhjä
func _blocked() -> String:
	if boat.anchored or boat.anchor.handling():
		return "Nosta ensin ankkuri (X)"
	if fishing.state != Fishing.State.READY or not fishing.holder_rods().is_empty():
		return "Kelaa ensin siimat sisään – verkko sotkeutuisi"
	if boat.paddling:
		return "Laita mela pois (V)"
	return ""


func start_laying() -> bool:
	var why := _blocked()
	if not fishing.license:
		why = "Verkkokalastus vaatii kalastonhoitomaksun" # nosto on sallittu ilman maksua
	var n := selected_net()
	var p := stern()
	if why == "" and count(n["id"]) <= 0:
		why = "Ei verkkoa: %s – vaihda silmäkokoa (B)%s" % [n["name"], " tai osta kaupasta" if Career.active else ""]
	if why == "" and nets.size() >= Nets.MAX_IN_LAKE:
		why = "Järvessä on jo %d verkkoa – nosta ensin jokin niistä" % Nets.MAX_IN_LAKE
	if why == "" and (not lake.is_water(p.x, p.y) or lake.depth_at(p.x, p.y) < START_MIN_DEPTH):
		why = "Liian matalaa verkolle – vähintään %s m" % str(START_MIN_DEPTH).replace(".", ",")
	if why == "" and lake.near_dock(p, 6.0):
		why = "Ei laiturin viereen – soudata kauemmas"
	if why != "":
		message.emit(why)
		return false
	inventory[n["id"]] = count(n["id"]) - 1
	var start := GillNet.lay_entry(boat) # verkko painuu veteen laidan vieressä
	var data := {"id": n["id"], "points": [start.x, start.y], "laid_at": now_abs(), "seed": randi(), "wear": 0}
	laying = _add_net(data, true)
	_speed_warned = false
	message.emit("Pyykki ja kivi veteen – souda hitaasti, verkko valuu laidan yli (N lopettaa)")
	return true


func _add_net(data: Dictionary, lay: bool) -> GillNet:
	var net := GillNet.new()
	add_child(net)
	net.setup(boat, lake, data, lay)
	net.fish_up.connect(_on_fish_up.bind(net))
	nets.append(net)
	return net


func _finish_laying(reason: String) -> void:
	var net := laying
	laying = null
	boat.stern_pull = Vector2.ZERO
	if net.laid_length < LAY_MIN_LENGTH:
		# Liian lyhyt: verkko otetaan takaisin veneeseen
		inventory[net.data["id"]] = count(net.data["id"]) + 1
		_remove(net)
		message.emit("%sVerkko otettiin takaisin veneeseen" % (reason + " – " if reason != "" else ""))
		return
	# Laskuaika siitä, kun verkko on kokonaan vedessä
	net.data["laid_at"] = now_abs()
	net.finish_laying()
	_sync_career()
	var text := "%s pyytää: %.0f m. Nosta myöhemmin pyykin luota (N)" % [Nets.find(net.data["id"])["name"], net.laid_length]
	message.emit((reason + " – " if reason != "" else "Toinen pyykki veteen. ") + text)


func start_haul(net: GillNet) -> bool:
	var why := _blocked()
	if why == "" and (boat.motor_running or boat.motor_starting > 0.0):
		why = "Sammuta moottori ennen verkon nostoa (Q)"
	if why == "" and boat.velocity.length() > HAUL_MAX_SPEED:
		why = "Pysähdy pyykin luo nostaaksesi verkon"
	if why != "":
		message.emit(why)
		return false
	var end: int = net.nearest_end(GillNet.lay_entry(boat))[0]
	var caught := Nets.catch_between(net.data, lake, float(net.data["laid_at"]), now_abs(), day_of_year_at)
	var mid := Nets.point_at(net.points(), 0.5)
	var place := lake.nearest_place(mid.x, mid.y)
	var name: String = Nets.find(net.data["id"])["name"]
	var fish := []
	for f in caught["fish"]:
		var entry := Fishing.catch_entry(f["species"], f["weight"], name, sky.clock_text(), place)
		fish.append({"entry": entry, "at": f["at"]})
	_haul_tears = caught["tears"]
	if Career.active:
		net.data["wear"] = int(net.data.get("wear", 0)) + _haul_tears
	_haul_summary = []
	hauling = net
	net.start_haul(end, fish)
	net.hauled.connect(_on_hauled.bind(net), CONNECT_ONE_SHOT)
	message.emit("Verkon nosto alkaa – pyykki veneeseen")
	return true


func _on_fish_up(index: int, net: GillNet) -> void:
	var entry: Dictionary = net.haul_fish[index]["entry"]
	var r := Fishing.record_catch(entry)
	trip_catch.append(entry)
	_haul_summary.append([entry, r["record"], r["new_species"]])
	message.emit("Verkossa: %s %s kg" % [entry["name"], ("%.2f" % entry["weight"]).replace(".", ",")])


func _on_hauled(net: GillNet) -> void:
	hauling = null
	boat.stern_pull = Vector2.ZERO
	boat.net_hands = []
	var id: String = net.data["id"]
	var ruined: bool = Career.active and int(net.data.get("wear", 0)) >= Nets.WEAR_LIMIT
	if not ruined:
		inventory[id] = count(id) + 1
	_remove(net)
	_sync_career()
	var lines: Array[String] = []
	var kg := 0.0
	for s in _haul_summary:
		var e: Dictionary = s[0]
		kg += e["weight"]
		var tag := ""
		if s[2]:
			tag = "   UUSI LAJI KALAKIRJAAN!"
		elif s[1]:
			tag = "   UUSI ENNÄTYS!"
		lines.append("%s  %s kg  %.0f cm%s" % [e["name"], ("%.2f" % e["weight"]).replace(".", ","), e["length"], tag])
	var head := "VERKKO NOSTETTU – %s\n" % Nets.find(id)["name"]
	if lines.is_empty():
		head += "Ei kaloja tällä kertaa."
	else:
		head += "%d kalaa, %s kg\n\n%s" % [lines.size(), ("%.2f" % kg).replace(".", ","), "\n".join(lines)]
	if _haul_tears > 0:
		head += "\n\nIso hauki repi verkkoon reiän%s" % (" – verkko on pilalla" if ruined else "")
	summary.emit(head)


func _remove(net: GillNet) -> void:
	nets.erase(net)
	net.queue_free()


func _sync_career() -> void:
	if not Career.active:
		return
	Career.nets = []
	for n in nets:
		if n.state == GillNet.State.SET:
			Career.nets.append(n.data)


## Reissun loppu: kesken jäänyt lasku päätetään ja kesken jäänyt nosto viedään loppuun
func end_trip() -> void:
	if laying:
		_finish_laying("")
	if hauling:
		while hauling and not hauling.haul_step(1.0):
			pass
	_sync_career()


func _physics_process(dt: float) -> void:
	if boat == null:
		return
	if laying:
		_update_laying()
	elif hauling:
		_update_hauling(dt)


func _update_laying() -> void:
	var p := stern()
	laying.lay_step(GillNet.lay_entry(boat))
	# Liian kova vauhti: verkko purkautuu kireällä ja jarruttaa
	var speed := boat.velocity.length()
	if speed > LAY_MAX_SPEED:
		boat.stern_pull = -boat.velocity / speed * (speed - LAY_MAX_SPEED) * 700.0
		if not _speed_warned:
			_speed_warned = true
			message.emit("Hiljempaa – verkko purkautuu kireällä")
	else:
		boat.stern_pull = Vector2.ZERO
	if laying.laid_length >= Nets.LENGTH - 0.01:
		_finish_laying("")
	elif not lake.is_water(p.x, p.y) or lake.depth_at(p.x, p.y) < LAY_MIN_DEPTH:
		_finish_laying("Liian matalaa")


func _update_hauling(dt: float) -> void:
	var net := hauling
	boat.net_hands = net.hand_points()
	# Vene liukuu verkkoa pitkin: laidan vesikohta vedetään nostokohdan päälle
	var target := net.haul_point(net.haul_s)
	var d := target - GillNet.lay_entry(boat)
	boat.stern_pull = d * 500.0 - boat.velocity * 300.0
	net.haul_step(dt)


## HUD: verkkotilanne ja vihje
func status_text() -> String:
	if frozen:
		return ""
	if laying:
		return "Verkkoa laskettu %.0f / %.0f m (N lopettaa)" % [laying.laid_length, Nets.LENGTH]
	if hauling:
		return "Verkkoa nostettu %.0f m" % hauling.haul_s
	var n := selected_net()
	var text := "Verkko %s: %d kpl (B vaihtaa, N laskee)" % [n["name"].trim_prefix("Verkko "), count(n["id"])]
	if not nets.is_empty():
		text += "   •   järvessä %d" % nets.size()
	var near := near_net()
	if near:
		var laid: float = near.data["laid_at"]
		var hours := (now_abs() - laid) / 60.0
		text = "N: nosta verkko (%s, pyytänyt %s h)" % [Nets.find(near.data["id"])["name"].trim_prefix("Verkko "), ("%.1f" % hours).replace(".", ",")]
	return text


## Kartalle: [{points, label}]
func map_lines() -> Array:
	var list := []
	for n in nets:
		list.append({"points": n.points(), "label": Nets.find(n.data["id"])["name"].trim_prefix("Verkko ")})
	return list

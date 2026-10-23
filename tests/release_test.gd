extends Node
## Kalastonhoitomaksun, toisen vavan luvan, kalan vapautuksen ja maineen testi:
## godot --headless --fixed-fps 30 -- --day=180 --releasetest   (talvi: --day=40)
## [--releasetest-shots=KANSIO: kuvat saalisikkunasta ja vapautuksesta, vaatii ikkunan]
## Uran maksut: voimassaolo (vuorokausi, 7 vrk, 31.12. ja vuodenvaihde),
## päällekkäinen maksu, liian pienet rahat, toisen vavan lupa, mainekaava, hintalisä,
## konkurssin tunnistus ja vanha tallennus. Pelissä: Z vapauttaa haavissa
## (talvella jäällä) olevan kalan, joka ei jää saaviin eikä mene säilöön;
## ilman maksua vain onki ja pilkki, verkkoa ei lasketa mutta nosto toimii, ja
## toinen siima ei mene veteen ilman lupaa ja maksua.

var main: Node
var _log: Array[String] = []
var _messages: Array[String] = []
var _sounds: Array[String] = []
var _step := 0
var _t := 0.0
var _spot := Vector2.ZERO
var _heading := 0.0
var _book_before := 0
var _expected := 0
var _catch_before := 0
var _shots := ""


func _ready() -> void:
	main = get_parent()
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	main.fishing.message.connect(func(text): _messages.append(text))
	main.nets.message.connect(func(text): _messages.append(text))
	main.fishing.sound_event.connect(func(sound, _at): _sounds.append(sound))
	for f in main.population.fish:
		f["wary"] = 3600.0 # oikeat kalat eivät iske väliin
	main.birds.auto_spawn = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--releasetest-shots="):
			_shots = arg.split("=")[1]
	_career_checks()
	_find_spot()


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _next() -> void:
	_step += 1
	_t = 0.0


func _finish() -> void:
	GameInput.force_active = false
	print("\n".join(_log))
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)


func _shot(name: String) -> void:
	if _shots != "":
		get_viewport().get_texture().get_image().save_png(_shots.path_join(name + ".png"))


func _press(action: String, pressed := true) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _tap(action: String) -> void:
	_press(action)
	_press(action, false)


## Hiiren nappi suoraan virvelille: tulos näkyy heti (ei odoteta seuraavaa ruutua)
func _cast(pressed := true) -> void:
	var ev := InputEventAction.new()
	ev.action = "cast"
	ev.pressed = pressed
	main.fishing._unhandled_input(ev)


## Z-näppäin fyysisenä näppäimenä (näppäinasettelu ei vaikuta)
func _key_z() -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_Z
		ev.keycode = KEY_Z
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _calm() -> void:
	var w: Weather = main.weather
	w.wind_base = 0.0
	w.gust = 0.0
	w._wind_target = 0.0
	w._gust_timer = 999.0


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


# --- Uran laskenta ilman pelinäkymää -------------------------------------------

func _career_checks() -> void:
	var c := Career
	c.new_career()
	_check("uusi ura: 50 €, ei maksua, ei lupaa, maine 0", is_equal_approx(c.money, 50.0) and not c.fee_valid() and not c.rod_permit_valid() and c.fame == 0)
	_check("kalenterivuoden loppu 1.6. alkaen on 31.12. (päivä %d)" % c.year_end_day(), c.date_text(c.year_end_day()) == "31.12.")

	# Vuorokausimaksu: ostopäivän loppuun
	c.day = 1
	_check("vuorokausimaksu 6 €", c.pay_fee("vrk") and is_equal_approx(c.money, 44.0) and c.fee_valid())
	_check("vuorokausimaksu: %s" % c.fee_until_text(), c.fee_until_text() == "voimassa 1.6. asti")
	_check("uusi vuorokausimaksu samana päivänä ei pidennä (pois käytöstä)", not c.can_pay_fee("vrk") and not c.pay_fee("vrk") and is_equal_approx(c.money, 44.0))
	c.day = 2
	_check("vuorokausimaksu päättyi seuraavana päivänä", not c.fee_valid() and c.fee_until_text() == "ei maksettu")

	# Viikkomaksu: ostopäivä ja 6 seuraavaa päivää
	c.new_career()
	c.day = 1
	_check("viikkomaksu 16 €: voimassa 7.6. asti", c.pay_fee("viikko") and is_equal_approx(c.money, 34.0) and c.fee_until == 7 and c.fee_until_text() == "voimassa 7.6. asti")
	_check("viikkomaksun päälle vuorokausimaksu ei pidennä", not c.can_pay_fee("vrk"))
	c.day = 7
	_check("viikkomaksu voimassa 7. päivänä", c.fee_valid())
	c.day = 5
	_check("päällekkäinen viikkomaksu: myöhempi päättymispäivä, ei summausta (11.6.)", c.pay_fee("viikko") and c.fee_until == 11)
	c.day = 12
	_check("viikkomaksu päättyi", not c.fee_valid())

	# Vuosimaksu: 31.12. loppuun, vuodenvaihteessa päättyy
	c.new_career()
	c.day = 1
	var end := c.year_end_day()
	_check("vuosimaksu 47 €: voimassa 31.12. asti", c.pay_fee("vuosi") and is_equal_approx(c.money, 3.0) and c.fee_until == end and c.fee_until_text() == "voimassa 31.12. asti")
	_check("vuosimaksun päälle viikkomaksu ei pidennä", not c.can_pay_fee("viikko"))
	c.money = 100.0
	_check("vuosimaksu jo voimassa: uusi vuosimaksu pois käytöstä", not c.can_pay_fee("vuosi"))
	c.day = end
	_check("vuosimaksu voimassa 31.12. (päivä %d)" % end, c.fee_valid() and c.date_text() == "31.12.")
	c.day = end + 1
	_check("vuodenvaihde 1.1.: vuosimaksu päättyi", not c.fee_valid() and c.date_text() == "1.1.")
	_check("uusi vuosimaksu 1.1. on voimassa seuraavan 31.12. asti", c.pay_fee("vuosi") and c.fee_until == end + 365)

	# Vuoden lopussa viikkomaksu jatkuu yli vuodenvaihteen; vuosimaksu ei silloin pidennä
	c.new_career()
	c.day = end - 2
	_check("viikkomaksu 29.12. jatkuu vuodenvaihteen yli (4.1. asti)", c.pay_fee("viikko") and c.fee_until_text() == "voimassa 4.1. asti")
	c.money = 100.0
	_check("viikkomaksun aikana vuosimaksu ei pidentäisi (pois käytöstä)", not c.can_pay_fee("vuosi"))

	# Liian pienet rahat
	c.new_career()
	c.money = 40.0
	_check("vuosimaksu 40 eurolla ei onnistu", not c.can_pay_fee("vuosi") and not c.pay_fee("vuosi") and is_equal_approx(c.money, 40.0) and not c.fee_valid())
	c.money = 5.0
	_check("vuorokausimaksu 5 eurolla ei onnistu", not c.pay_fee("vrk") and is_equal_approx(c.money, 5.0))

	# Toisen vavan lupa
	c.new_career()
	c.day = 1
	_check("toisen vavan lupa 10 € ilman maksua: lupa voimassa 31.12. asti", c.pay_rod_permit() and is_equal_approx(c.money, 40.0) and c.rod_permit_valid() and c.rod_permit_text() == "voimassa 31.12. asti")
	_check("lupa ilman maksua: toinen vapa ei sallittu", not c.second_rod_allowed())
	_check("voimassa olevaa lupaa ei voi ostaa uudelleen", not c.can_pay_rod_permit() and not c.pay_rod_permit())
	c.pay_fee("vrk")
	_check("lupa ja maksu: toinen vapa sallittu", c.second_rod_allowed())
	c.day = 2
	_check("maksu loppui: lupa säilyy, toinen vapa ei sallittu", c.rod_permit_valid() and not c.second_rod_allowed())
	c.day = end
	_check("lupa voimassa 31.12.", c.rod_permit_valid())
	c.day = end + 1
	_check("vuodenvaihde: lupa päättyi", not c.rod_permit_valid())
	c.money = 9.0
	_check("lupa 9 eurolla ei onnistu", not c.pay_rod_permit() and is_equal_approx(c.money, 9.0))

	# Mainekaava ja ison kalan rajat
	var cases := [
		["kiiski", 0.04, 0], ["kiiski", 0.05, 1], ["kiiski", 0.06, 6],
		["ahven", 0.39, 1], ["ahven", 0.40, 6], ["ahven", 0.45, 6],
		["sarki", 0.29, 1], ["sarki", 0.30, 6],
		["made", 1.69, 2], ["made", 1.70, 7],
		["lahna", 1.00, 1], ["lahna", 2.49, 3], ["lahna", 2.50, 8],
		["hauki", 3.20, 4], ["hauki", 4.99, 5], ["hauki", 5.00, 10], ["hauki", 6.20, 12],
	]
	var wrong := []
	for k in cases:
		var got := Career.release_fame(k[0], k[1])
		if got != k[2]:
			wrong.append("%s %.2f kg: %d (pitäisi %d)" % [k[0], k[1], got, k[2]])
	_check("mainekaava ison kalan taulukon rajoilla (%d tapausta) %s" % [cases.size(), ", ".join(wrong)], wrong.is_empty())

	# Hintalisä: +1 % / täysi 10 mainetta, enintään +25 %
	c.new_career()
	var base := c.price("ahven")
	c.fame = 27
	var p27 := c.price("ahven")
	_check("maine 27: hintalisä 2 %", Career.MAX_PRICE_BONUS == 25 and c.fame == 27 and c.price_bonus_percent() == 2)
	c.fame = 0
	_check("hintalisä 0 % mainella 0", c.price_bonus_percent() == 0 and is_equal_approx(c.price("ahven"), base))
	c.fame = 27
	var raw: float = Career.PRICES["ahven"] * (1.0 + sin(c.day * 1.7 + "ahven".hash() % 100) * 0.1 + sin(c.day * 0.43 + 5) * 0.05)
	_check("maine 27: +2 %% (%.2f → %.2f €/kg)" % [base, p27], is_equal_approx(p27, snappedf(raw * 1.02, 0.01)))
	c.fame = 250
	_check("maine 250: +25 %", c.price_bonus_percent() == 25)
	c.fame = 300
	_check("maine 300: enintään +25 %", c.price_bonus_percent() == 25 and is_equal_approx(c.price("ahven"), snappedf(raw * 1.25, 0.01)))
	c.storage = [{"species": "ahven", "name": "Ahven", "weight": 2.0, "length": 40.0, "day": 1}]
	var shown := c.price("ahven")
	var money_before := c.money
	var earned := c.sell("ahven")
	_check("myynti maineen hinnalla (%.2f €)" % earned, is_equal_approx(earned, snappedf(2.0 * shown, 0.01)) and is_equal_approx(c.money, money_before + earned))
	c.add_fame(5)
	_check("maine kasvaa (add_fame)", c.fame == 305)

	# Konkurssi: ei maksua, ei onkea, rahat eivät riitä onkeen eikä säilössä ole myytävää
	c.new_career()
	_check("uuden uran neuvo: maksa tai osta onki", CareerView.fee_advice().begins_with("Kalastonhoitomaksu pitää maksaa ennen virvelikalastusta"))
	c.money = 2.0
	_check("konkurssi: ehdotetaan uutta uraa", CareerView.fee_advice().begins_with("Rahat eivät riitä onkeen eikä kalastonhoitomaksuun"))
	c.money = 3.0
	_check("3 €: riittää pohjaonkeen, ei konkurssia", CareerView.fee_advice().begins_with("Kalastonhoitomaksu pitää maksaa"))
	c.money = 0.0
	c.storage = [{"species": "ahven", "name": "Ahven", "weight": 0.2, "length": 25.0, "day": 1}]
	_check("rahat lopussa, mutta säilössä myytävää: ei konkurssia", CareerView.fee_advice().begins_with("Kalastonhoitomaksu pitää maksaa"))
	c.storage = []
	c.lures["pohja"] = 1
	_check("pohjaonki varastossa: ei neuvoa", CareerView.fee_advice() == "")
	c.lures.erase("pohja")
	c.pay_fee("vrk") # ei rahaa
	c.money = 10.0
	c.pay_fee("vrk")
	_check("maksu voimassa: ei neuvoa", CareerView.fee_advice() == "")
	c.new_career()
	c.day = 1 + 40 - Career.START_DAY_OF_YEAR + 365 # 9.2.: talvi, pilkki varastossa
	_check("talvella pilkki varastossa: ei neuvoa", c.day_of_year() == 40 and CareerView.fee_advice() == "")
	c.lures.erase("pilkki")
	c.money = 0.0
	_check("talvella ilman pilkkiä ja rahaa: konkurssi", CareerView.fee_advice().begins_with("Rahat eivät riitä"))

	# Tallennus: uudet kentät säilyvät, vanha ura.json latautuu oletusarvoin
	c.new_career()
	c.pay_fee("viikko")
	c.pay_rod_permit()
	c.fame = 33
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	c.new_career()
	c.from_dict(saved)
	_check("maksu, lupa ja maine säilyvät tallennuksessa", c.fee_until == 7 and c.rod_permit_until == c.year_end_day() and c.fame == 33)
	var old: Dictionary = JSON.parse_string('{"day": 12, "minutes": 600.0, "money": 17.5, "storage": [], "lures": {"lusikka": 1}, "nets": []}')
	c.from_dict(old)
	_check("vanha ura.json: rahat ennallaan, maine 0, ei maksua eikä lupaa", c.day == 12 and is_equal_approx(c.money, 17.5) and c.fame == 0 and not c.fee_valid() and not c.rod_permit_valid())
	c.new_career()


# --- Pelissä ------------------------------------------------------------------

## Kala väsytetty haavin luo (talvella avannolle) ja nostetaan
func _land(sp: String, weight: float) -> void:
	var f: Fishing = main.fishing
	f._fish_index = 0
	var fish: Dictionary = main.population.fish[0]
	fish["sp"] = sp
	fish["weight"] = weight
	f._fish = fish
	f._stamina = 0.1
	if f.on_ice:
		f.current_hole = Vector3(main.boat.pos.x, 0.0, main.boat.pos.y) + Vector3(main.boat.forward().x, 0, main.boat.forward().y) * Fishing.HOLE_AHEAD
		f._fish_pos = f.current_hole + Vector3(0, -1.0, 0)
	else:
		var side: Vector2 = main.boat.pos + main.boat.right() * 2.0
		f._fish_pos = Vector3(side.x, -0.3, side.y)
	f.state = Fishing.State.FIGHT
	f._try_land()


func _book_total() -> int:
	var n := 0
	for sp in Species.DATA:
		n += FishBook.count(sp)
	return n


func _physics_process(delta: float) -> void:
	_t += delta
	var f: Fishing = main.fishing
	var boat: Boat = main.boat
	var nets: NetControl = main.nets
	_calm()
	if not f.on_ice and _step < 5:
		boat.yaw = _heading
		boat.yaw_rate = 0.0
		boat.pos = _spot + boat.forward() * Boat.LENGTH * 0.5
		boat.velocity = Vector2.ZERO
	match _step:
		0:
			if _t < 1.0:
				return
			# Uramoodin reissu ilman maksua: vain onki ja pilkki
			Career.new_career()
			Career.active = true
			f.limited = true
			f.inventory = Career.lures
			f.license = false
			f.rod_permit = false
			f.lure_index = 0
			if f.on_ice:
				_check("talvella ilman maksua pilkki käy", f.has_lure() and f.lure()["id"] == "pilkki")
				_check("pilkkirasiassa ei maksuhuomautusta", f.lure_allowed("tasuri") and f.select_lure("pilkki") == "")
			else:
				_check("ilman maksua aloitusuistimet (lusikka, jigi) eivät käy", not f.has_lure())
				_messages.clear()
				_cast()
				_cast(false)
				_check("heitto ilman maksua: ilmoitus (%s)" % ", ".join(_messages), f.state == Fishing.State.READY and _messages.has("Virvelikalastus vaatii kalastonhoitomaksun"))
				Career.lures["koho"] = 2
				_check("koho-onki käy ilman maksua", f.lures().size() == 1 and f.lure()["id"] == "koho")
				_messages.clear()
				var err := f.select_lure("lusikka")
				_check("lusikkaa ei voi valita kalapakista: \"%s\"" % err, err == "Virvelikalastus vaatii kalastonhoitomaksun" and _messages.has(err))
				_check("pohjaongen valinta: ei varastossa", f.select_lure("pohja").contains("ei varastossa"))
				_check("koho-ongen voi valita", f.select_lure("koho") == "")
				main.tackle_box.hovered = "lusikka"
				main.tackle_box._update_label()
				_check("kalapakki kertoo syyn: \"%s\"" % main.tackle_box._label.text, main.tackle_box._label.text.contains("vaatii kalastonhoitomaksun"))
				main.tackle_box.hovered = ""
				f.license = true
				_check("maksulla kaikki uistimet käyvät", f.lures().size() == 3 and f.select_lure("lusikka") == "")
				f.license = false
			_book_before = _book_total()
			_land("ahven", 0.45)
			_next()
		1:
			if f.state == Fishing.State.LANDING:
				return
			if _t < (1.5 if _shots != "" else 0.3): # kuvassa saalisikkuna ehtii piirtyä
				return
			_check("saalis haavissa: saavissa 1 kala", f.state == Fishing.State.LANDED and main.trip_catch.size() == 1)
			_check("kalakirjaan kirjattu haavinnassa", _book_total() == _book_before + 1)
			var text: String = main.hud._catch_label.text
			_check("saalisikkuna: \"%s\"" % text.get_slice("\n\n", 1), text.contains("Vasen hiiri: kala saaviin   •   Z: vapauta kala (+6 mainetta)"))
			_shot("vapautus-1-saalisikkuna")
			_sounds.clear()
			_key_z()
			_next()
		2:
			if _t < 0.2:
				return
			_shot("vapautus-2-vapautettu")
			_check("Z vapautti kalan: tila valmis heittoon", f.state == Fishing.State.READY and f.last_catch().is_empty())
			_check("vapautettu kala ei ole saavissa", main.trip_catch.is_empty())
			_check("fish_splash kuului", _sounds.has("fish_splash"))
			_check("ilmoitus: \"%s\"" % main.hud._message.text, main.hud._message.text == "Ahven 0,45 kg vapautettu – maine +6 (yhteensä 6)")
			_check("maine +6", Career.fame == 6 and main.released_count == 1 and main.released_fame == 6)
			_check("kalastaja: \"%s\"" % main.hud._speech.text, main.voice.last_line == "release" and main.hud._speech.text.contains("Mene kasvamaan.") and main.voice._player.stream == main.voice._streams["release"])
			_check("kalakirja ennallaan vapautuksen jälkeen", _book_total() == _book_before + 1)
			_check("saalisikkuna sulkeutui ja kala katosi", not main.hud._catch_panel.visible and not f._fish_node.visible)
			_check("saavissa vapautusrivi", main.hud._log_text().contains("Tällä reissulla vapautettu: 1 kalaa, maine +6"))
			_key_z()
			_check("Z ei tee mitään valmiina", f.state == Fishing.State.READY and Career.fame == 6 and main.released_count == 1)
			# Toinen kala saaviin vasemmalla hiirellä
			_land("hauki", 6.2)
			_next()
		3:
			if f.state == Fishing.State.LANDING:
				_key_z()
				return
			if _t < 0.3:
				return
			_check("Z ei tee mitään haavinnan aikana", Career.fame == 6 and main.trip_catch.size() == 1)
			_check("iso hauki: +12 mainetta saalisikkunassa", main.hud._catch_label.text.contains("(+12 mainetta)"))
			_cast()
			_cast(false)
			_check("vasen hiiri: kala saaviin", f.state == Fishing.State.READY and main.trip_catch.size() == 1 and main.trip_catch[0]["species"] == "hauki")
			# Vapautettu kala ei mene säilöön
			Career.end_trip(main.trip_catch, 0.0)
			_check("kotona säilössä vain saaviin pantu kala", Career.storage_count() == 1 and Career.storage[0]["species"] == "hauki")
			# Kertakalastus: vapautus ilman mainetta
			Career.active = false
			_land("kiiski", 0.04)
			_next()
		4:
			if f.state == Fishing.State.LANDING:
				return
			if _t < 0.3:
				return
			_check("kertakalastus: saalisikkunassa ei mainetta", main.hud._catch_label.text.contains("Z: vapauta kala") and not main.hud._catch_label.text.contains("mainetta"))
			_key_z()
			_next()
		5:
			if _t < 0.2:
				return
			_check("kertakalastus: \"%s\", maine ennallaan" % main.hud._message.text, main.hud._message.text == "Kiiski 0,04 kg vapautettu" and Career.fame == 6 and f.state == Fishing.State.READY)
			_check("kertakalastus: kala pois saavista", main.trip_catch.size() == 1)
			Career.active = true
			if f.on_ice:
				_finish()
				return
			# Verkko: lasku ilman maksua estetty
			_messages.clear()
			_check("verkkoa ei lasketa ilman maksua", not nets.start_laying() and nets.laying == null and _messages.has("Verkkokalastus vaatii kalastonhoitomaksun"))
			# Järveen jäänyt verkko: nosto ilman maksua
			var line := []
			var fwd := Vector2(-sin(_heading), -cos(_heading))
			for i in 31:
				var p := _spot + fwd * i
				line.append(p.x)
				line.append(p.y)
			var data := {"id": "verkko35", "points": line, "laid_at": nets.now_abs() - 12.0 * 60.0, "seed": 5, "wear": 0}
			var net: GillNet = nets._add_net(data, false)
			_expected = Nets.catch_between(data, main.lake, float(data["laid_at"]), nets.now_abs(), nets.day_of_year_at)["fish"].size()
			_catch_before = main.trip_catch.size()
			_next()
		6:
			if _t < 0.3:
				return
			_check("verkon nosto ilman maksua alkaa", nets.start_haul(nets.nets[0]) and nets.hauling != null)
			_step = 10
			_t = 0.0
		10:
			if nets.hauling != null:
				if _t > 120.0:
					_check("nosto valmistui", false)
					_finish()
				return
			_check("verkon saalis saaviin ilman maksua (%d kalaa)" % _expected, main.trip_catch.size() == _catch_before + _expected)
			if main.hud._net_panel.visible:
				_tap("cast") # yhteenveto kiinni
			# Toinen vapa: vapa 1 telineeseen uistellen
			Career.lures["koho"] = 2
			f.select_lure("koho")
			var at := boat.pos - boat.forward() * 12.0
			f.state = Fishing.State.RETRIEVING
			f.lure_pos = Vector3(at.x, -0.5, at.y)
			f._prev_lure = f.lure_pos
			f.line_out = f.rod_tip().distance_to(f.lure_pos)
			_next()
		11:
			if _t < 0.2:
				return
			_tap("rod_holder")
			_next()
		12:
			if _t < 0.2:
				return
			_check("vapa 1 telineeseen ilman lupaa, vapa 2 käteen", f.held == 1 and f.holder_rods().size() == 1 and f.trolling() and f.state == Fishing.State.READY)
			var cases := [
				[false, false, "Toinen vapa vaatii kalastonhoitomaksun ja tekoaltaan luvan – R ottaa telinevavan käteen"],
				[false, true, "Toinen vapa vaatii kalastonhoitomaksun – R ottaa telinevavan käteen"],
				[true, false, "Toinen vapa vaatii tekoaltaan luvan (10 €) – R ottaa telinevavan käteen"],
			]
			for k in cases:
				f.license = k[0]
				f.rod_permit = k[1]
				_messages.clear()
				_cast()
				_cast(false)
				_check("toinen siima ei veteen (maksu %s, lupa %s): \"%s\"" % [k[0], k[1], ", ".join(_messages)], f.state == Fishing.State.READY and _messages.has(k[2]))
			f.license = true
			f.rod_permit = true
			_cast()
			_check("lupa ja maksu: toinen siima veteen", f.state == Fishing.State.RETRIEVING and f.held == 1)
			_cast(false)
			_finish()
	if _t > 40.0 and _step != 10:
		_check("vaihe %d jumittui" % _step, false)
		_finish()

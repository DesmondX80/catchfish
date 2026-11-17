extends Node
## Siemenen testi: godot --headless --fixed-fps 30 -- --day=180 --seed=171 --seedtest
## Lisäksi pelin kutsupolku main.gd:ssä alaprosesseina (tuntematon testilippu,
## valikkotestin etusija).
## --seed=N kiinnittää pelin satunnaislukugeneraattorit: jokainen alijärjestelmä
## saa oman siemenensä GameSeed.of(nimi):stä, ja sama siemen antaa saman sään ja
## kalakannan.

const SEED := 171 # sama kuin ajokomennon --seed

var main: Node
var _log: Array[String] = []


func _ready() -> void:
	main = get_parent()
	_checks.call_deferred()


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _checks() -> void:
	_check("lippu luettiin: GameSeed.base = %d" % GameSeed.base, GameSeed.base == SEED)
	var systems := {
		"weather": main.weather, "fish_population": main.population, "fishing": main.fishing,
		"birds": main.birds, "other_boats": main.other_boats, "game_audio": main.audio,
		"angler_voice": main.voice,
	}
	for key in systems:
		var rng: RandomNumberGenerator = systems[key]._rng
		_check("%s: siemen GameSeed.of(\"%s\")" % [key, key], rng.seed == GameSeed.of(key))
	_weather_checks()
	_population_checks()
	_global_checks()
	_flag_checks()
	await _subprocess_checks()
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)


## Säätila, jonka uusi Weather arpoo _ready():ssä nykyisellä siemenellä
func _new_weather() -> Array:
	var w := Weather.new()
	add_child(w)
	var values := [w.wind_base, w.wind_direction, w.kind, w.pressure]
	w.queue_free()
	return values


func _weather_checks() -> void:
	var a := _new_weather()
	var b := _new_weather()
	_check("sama siemen, sama sää: tuuli %.2f m/s, suunta %.2f rad, säätila %d, paine %.1f hPa" % a, a == b)
	GameSeed.base = SEED + 1
	var c := _new_weather()
	GameSeed.base = SEED
	_check("eri siemen, eri sää: tuuli %.2f m/s, suunta %.2f rad" % [c[0], c[1]], c != a)


## Kalamäärä ja 50 ensimmäisen kalan paikka ja paino
func _new_population() -> Array:
	var p := FishPopulation.new()
	add_child(p)
	p.setup(main.lake)
	var values := [p.fish.size()]
	for i in mini(50, p.fish.size()):
		values.append([p.fish[i]["pos"], p.fish[i]["weight"]])
	p.queue_free()
	return values


func _population_checks() -> void:
	var a := _new_population()
	var b := _new_population()
	_check("sama siemen, sama kalakanta: %d kalaa, 50 ensimmäisen paikka ja paino samat" % a[0], a[0] > 0 and a == b)


## Globaali randf()/randi(): GameSeed.setup() siementää sen perussiemenellä
func _global_checks() -> void:
	GameSeed.setup()
	var a := [randi(), randf()]
	randi() # tila etenee: ilman siementämistä seuraava setup() jatkaisi tästä
	GameSeed.setup()
	var b := [randi(), randf()]
	_check("globaali randf: sama siemen, samat luvut (%d, %.4f)" % a, a == b)


## Valikon ohitus ja testilippujen tunnistus luetaan taulukosta TestFlags
func _flag_checks() -> void:
	for args in [["--seed=5"], ["--audio-log"], ["--day=40"], ["--day=40", "--waterquality=matala"]]:
		_check("valikko jää näkyviin: %s" % " ".join(args), not TestFlags.skips_menu(PackedStringArray(args)))
	for args in [["--day=40", "--luretest"], ["--boatshots=x"], ["--scratchtest=x"], ["--skipmenu"], ["--day=40", "--skipmenu"]]:
		_check("valikko ohitetaan: %s" % " ".join(args), TestFlags.skips_menu(PackedStringArray(args)))
	_check("--skipmenu ei lataa testiä", TestFlags.find(PackedStringArray(["--day=40", "--skipmenu"])) == "")
	_check("valikkotesti ei ohita valikkoa: --menutest=x",
		not TestFlags.skips_menu(PackedStringArray(["--menutest=x"])) and TestFlags.find_menu(PackedStringArray(["--menutest=x"])) == "res://tests/menu_test.gd")
	_check("--scratchtest voittaa muut testiliput",
		TestFlags.find(PackedStringArray(["--luretest", "--boatshots=x", "--scratchtest=/tmp/koe.gd"])) == "/tmp/koe.gd")
	_check("pelitesti voittaa kuvaskriptin, taulukon järjestys ratkaisee",
		TestFlags.find(PackedStringArray(["--boatshots=x", "--boattest", "--luretest"])) == "res://tests/lure_test.gd")
	_check("--seasonshot= ja toinen kuvalippu: vain season_shot",
		TestFlags.find(PackedStringArray(["--boatshots=x", "--seasonshot=y"])) == "res://tests/season_shot.gd")
	_check("tuntematon testilippu: --luretst",
		TestFlags.unknown_test_flag(PackedStringArray(["--day=180", "--luretst"])) == "VIRHE tuntematon testilippu --luretst")
	_check("valikkotesti ilman kansiota: vihje --menutest=KANSIO",
		TestFlags.unknown_test_flag(PackedStringArray(["--menutest"])).ends_with("--menutest vaatii kansion: --menutest=KANSIO"))
	_check("tuntematon paljas lippu: --lurtest ja --skipmenyy",
		TestFlags.unknown_test_flag(PackedStringArray(["--lurtest"])) == "VIRHE tuntematon testilippu --lurtest"
		and TestFlags.unknown_test_flag(PackedStringArray(["--day=40", "--skipmenyy"])) == "VIRHE tuntematon testilippu --skipmenyy")
	for args in [["--day=180", "--perftest-lines", "--luretest"], ["--mouse", "--short", "--flicker"], ["--jitter-still", "--watershots-timing"], ["--anchortest-shots=x", "--anchortest"], ["--shopbgtest"],
			["--menutest=x"], ["--short", "--bookshots=x", "--audio-log", "--seed=5", "--skipmenu"]]:
		_check("tunnetut liput kelpaavat: %s" % " ".join(args), TestFlags.unknown_test_flag(PackedStringArray(args)) == "")
	_check("taulukoissa 45 peli-, 15 kuva- ja 6 valikkolippua",
		TestFlags.GAME.size() == 45 and TestFlags.SHOTS.size() == 15 and TestFlags.MENU.size() == 6)
	var missing: Array[String] = []
	for table in [TestFlags.GAME, TestFlags.SHOTS, TestFlags.MENU]:
		for flag in table:
			if not ResourceLoader.exists(TestFlags.TEST_DIR + table[flag] + ".gd"):
				missing.append(flag)
	_check("jokaisen lipun skripti on olemassa (puuttuu: %s)" % ", ".join(missing), missing.is_empty())


const CHILD_TIMEOUT_MS := 40000 # alaprosessin aikaraja, ettei ajo jää roikkumaan


## Käynnistää pelin alaprosessina tällä projektilla; tuloste putkeen, ettei se
## sekoitu tämän testin riveihin.
func _start_child(user_args: Array) -> Dictionary:
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--"]
	args.append_array(user_args)
	var child := OS.execute_with_pipe(OS.get_executable_path(), args, false)
	child["out"] = ""
	child["code"] = -1
	child["timed_out"] = false
	return child


func _drain(child: Dictionary) -> void:
	for key in ["stdio", "stderr"]:
		var pipe: FileAccess = child.get(key)
		if pipe != null:
			child["out"] += pipe.get_buffer(65536).get_string_from_utf8()


## Odottaa alaprosessit (enintään CHILD_TIMEOUT_MS), lopettaa jumiin jääneet
func _wait_children(children: Array) -> void:
	var deadline := Time.get_ticks_msec() + CHILD_TIMEOUT_MS
	while true:
		var running := false
		for c in children:
			if c.is_empty():
				continue
			_drain(c)
			if OS.is_process_running(c["pid"]):
				running = true
		if not running or Time.get_ticks_msec() > deadline:
			break
		await get_tree().create_timer(0.1, true, false, true).timeout
	for c in children:
		if c.is_empty():
			continue
		if OS.is_process_running(c["pid"]):
			c["timed_out"] = true
			OS.kill(c["pid"])
		else:
			c["code"] = OS.get_process_exit_code(c["pid"])
		_drain(c)


## main.gd:n kytkennät oikealla kutsupolulla: tuntematon testilippu lopettaa
## heti koodilla 1, ja valikkotesti voittaa pelitestin (PÄÄTÖS 13).
func _subprocess_checks() -> void:
	var unknown := _start_child(["--day=180", "--luretst"])
	var menu_first := _start_child(["--day=180", "--luretest", "--shopbgtest"])
	_check("alaprosessit käynnistyivät", not unknown.is_empty() and not menu_first.is_empty())
	await _wait_children([unknown, menu_first])
	if unknown.is_empty() or menu_first.is_empty():
		return
	_check("alaprosessi -- --luretst: koodi %d (odotus 1), aikakatkaisu %s, rivi \"tuntematon testilippu --luretst\"" % [unknown["code"], unknown["timed_out"]],
		unknown["code"] == 1 and "VIRHE tuntematon testilippu --luretst" in unknown["out"])
	_check("alaprosessi -- --luretest --shopbgtest: valikkotesti ajettiin (aikakatkaisu %s)" % menu_first["timed_out"],
		not menu_first["timed_out"] and "kuvatiedosto on olemassa" in menu_first["out"])

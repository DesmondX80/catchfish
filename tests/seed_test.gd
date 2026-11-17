extends Node
## Siemenen testi: godot --headless --fixed-fps 30 -- --day=180 --seed=171 --seedtest
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

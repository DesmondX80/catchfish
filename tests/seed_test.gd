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

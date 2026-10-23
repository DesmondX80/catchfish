extends Node
## Kalakannan testi: godot --headless -- --speciestest
## Kokeilee uistimia ja pilkkiä tuhansissa satunnaisissa kohdissa järveä kesällä
## ja talvella eri kellonaikoina ja tulostaa, mitkä lajit iskevät. Tarkistaa,
## että hauki ja ahven ovat uistinkalat, särkikalat ja kiiski syövät pilkkiä,
## made on talven ja pimeän kala ja lahna on harvinainen saalis.

const SAMPLES := 6000

var main: Node
var _log: Array[String] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	main = get_parent()
	_rng.seed = 5
	var pop: FishPopulation = main.population
	print("Kaloja: ", pop.count_by_species())
	var summer_spoon := _trial(false, "lusikka", 0.85, 0.0, 10.0, "kesä, lusikka, klo 10")
	var summer_jig := _trial(false, "jigi", 0.4, 0.3, 10.0, "kesä, jigi, klo 10")
	var summer_night := _trial(false, "pilkki", 0.15, 0.3, 23.0, "kesä, toukka, klo 23")
	var summer_float := _trial(false, "koho", 0.0, 0.0, 9.0, "kesä, koho-onki + mato, klo 9")
	var summer_bottom := _trial(false, "pohja", 0.0, 0.0, 21.0, "kesä, pohjaonki + mato, klo 21")
	var winter_day := _trial(true, "pilkki", 0.15, 0.3, 12.0, "talvi, pilkki + toukka, klo 12")
	var winter_night := _trial(true, "pilkki", 0.15, 0.3, 21.0, "talvi, pilkki + toukka, klo 21")

	_check("kesällä lusikkaan iskevät hauki ja ahven (%.0f %%)" % _share(summer_spoon, ["hauki", "ahven"]), _share(summer_spoon, ["hauki", "ahven"]) > 85.0)
	_check("talven pilkillä saa särkeä ja kiiskeä (%d + %d)" % [winter_day.get("sarki", 0), winter_day.get("kiiski", 0)], winter_day.get("sarki", 0) > 0 and winter_day.get("kiiski", 0) > 0)
	_check("made syö talvella pimeällä (yöllä %d, päivällä %d)" % [winter_night.get("made", 0), winter_day.get("made", 0)], winter_night.get("made", 0) > winter_day.get("made", 0))
	_check("made on talven kala (talviyö %d, kesäyö %d)" % [winter_night.get("made", 0), summer_night.get("made", 0)], winter_night.get("made", 0) > summer_night.get("made", 0) * 2)
	_check("lahna on harvinainen saalis (talvipilkillä %.0f %%)" % _share(winter_day, ["lahna"]), _share(winter_day, ["lahna"]) < 15.0)
	_check("kesällä koho-ongella saa särkikaloja (särki + lahna %.0f %%)" % _share(summer_float, ["sarki", "lahna"]), _share(summer_float, ["sarki", "lahna"]) > 25.0)
	_check("hauki ei juuri syö matoa (%.0f %%)" % _share(summer_float, ["hauki"]), _share(summer_float, ["hauki"]) < 10.0)
	_check("pohjaongella saa kiiskeä ja lahnaa (%d + %d)" % [summer_bottom.get("kiiski", 0), summer_bottom.get("lahna", 0)], summer_bottom.get("kiiski", 0) > 0 and summer_bottom.get("lahna", 0) > 0)
	_check("jokainen laji on saatavissa jollakin tavalla", Species.DATA.keys().all(func(sp): return [summer_spoon, summer_jig, summer_night, winter_day, winter_night].any(func(r): return r.get(sp, 0) > 0)))
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _share(result: Dictionary, species: Array) -> float:
	var total := 0
	var n := 0
	for sp in result:
		total += result[sp]
		if sp in species:
			n += result[sp]
	return 100.0 * n / maxf(1.0, total)


## Satunnaiset kohdat järvellä: uistin kalojen syvyysvyöhykkeellä (talvella pohjan
## tuntumassa). Palauttaa iskut lajeittain.
func _trial(winter: bool, lure_id: String, speed: float, twitch: float, hour: float, title: String) -> Dictionary:
	var pop: FishPopulation = main.population
	var lake: LakeData = main.lake
	pop.winter = winter
	pop.update_traits()
	for f in pop.fish:
		f["depth"] = pop._preferred_depth(f["sp"], f["pos"])
		f["hunger"] = 0.7
		f["wary"] = 0.0
	var lure: Dictionary = Lures.all().filter(func(l): return l["id"] == lure_id)[0]
	var hits := {}
	var size := lake.world_size()
	var tries := 0
	while tries < SAMPLES:
		var p := Vector2(lake.origin_x + _rng.randf() * size.x, lake.origin_z + _rng.randf() * size.y)
		if not lake.is_water(p.x, p.y) or lake.depth_at(p.x, p.y) < 0.6:
			continue
		tries += 1
		var bottom := lake.depth_at(p.x, p.y)
		var depth := bottom - 0.3 if winter else _rng.randf_range(0.4, bottom - 0.1)
		if lure_id == "pohja":
			depth = maxf(0.3, bottom - 0.5) # pohjaongen mato puolen metrin korkeudella
		var idx := pop.check_lure(p, depth, speed, twitch, lure, hour, 3.0, 5.0, 0.3)
		if idx >= 0:
			var sp: String = pop.fish[idx]["sp"]
			hits[sp] = hits.get(sp, 0) + 1
	var parts := []
	for sp in Species.DATA:
		parts.append("%s %d" % [Species.DATA[sp]["name"], hits.get(sp, 0)])
	print("%-32s %s" % [title, ", ".join(parts)])
	return hits

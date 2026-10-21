extends Node
## Kalojen vuodenaikakäytöksen testi: godot --headless -- --day=180 --seasonfishtest
## Kalakanta luodaan eri vuodenpäiville: keväällä hauki kutee matalissa
## kaislikkolahdissa ja syö vähän, kudun jälkeen paljon, kesähelteellä kalat
## ovat syvemmällä ja syksyllä syönti vilkastuu.

const REEDS_SAMPLE := 400 # hauista kaislikkohaku (hidas)

var main: Node
var _log: Array[String] = []


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _ready() -> void:
	main = get_parent()
	var spring := _stats(125) # hauen kutu
	var early := _stats(175) # alkukesä
	var heat := _stats(210) # helle
	for d in [125, 175, 210]:
		var st: Dictionary = {125: spring, 175: early, 210: heat}[d]
		print("päivä %d: hauki %.1f m (kaislikossa %.0f %%), ahven %.1f m, lahna %.1f m" % [d, st["hauki"][0], st["hauki"][1] * 100.0, st["ahven"][0], st["lahna"][0]])
	_check("kutuaikaan hauet ovat matalassa (%.1f m, alkukesällä %.1f m)" % [spring["hauki"][0], early["hauki"][0]], spring["hauki"][0] < 1.3 and spring["hauki"][0] < early["hauki"][0] - 0.3)
	_check("kutevat hauet ovat kaislikoissa (%.0f %%, alkukesällä %.0f %%)" % [spring["hauki"][1] * 100.0, early["hauki"][1] * 100.0], spring["hauki"][1] > early["hauki"][1] + 0.1)
	_check("helteellä ahvenet ovat syvemmällä (%.1f m, alkukesällä %.1f m)" % [heat["ahven"][0], early["ahven"][0]], heat["ahven"][0] > early["ahven"][0] + 0.4)
	_check("lahnat kutevat kesäkuussa matalassa (%.1f m, helteellä %.1f m)" % [early["lahna"][0], heat["lahna"][0]], early["lahna"][0] < 1.6 and heat["lahna"][0] > early["lahna"][0] + 0.8)
	var a := func(sp: String, day: int) -> float: return Species.traits(sp, day, false)["activity"]
	_check("kutuaikaan hauki syö vähän, kudun jälkeen paljon (%.2f / %.2f)" % [a.call("hauki", 125), a.call("hauki", 150)], a.call("hauki", 125) < 0.6 and a.call("hauki", 150) > 1.2)
	_check("syksyllä syönti vilkastuu (hauki %.2f, ahven %.2f; kesällä 1.0)" % [a.call("hauki", 270), a.call("ahven", 270)], a.call("hauki", 270) > 1.2 and a.call("ahven", 270) > 1.2 and a.call("hauki", 175) == 1.0)
	_check("talvella ennallaan (made %.2f)" % Species.traits("made", 40, true)["activity"], Species.traits("made", 40, true)["activity"] == Species.DATA["made"]["season"][1])
	_check("vihjeet: kutu, helle ja syksy", Species.season_hint(125).contains("kutevat") and Species.season_hint(210).contains("syvempään") and Species.season_hint(270).contains("Syksy"))
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)


## Kalakanta päivälle: laji -> [keskisyvyys, osuus kaislikon lähellä]
func _stats(day: int) -> Dictionary:
	var pop := FishPopulation.new()
	pop.day = day
	pop.setup(main.lake)
	var lake: LakeData = main.lake
	var result := {}
	for sp in ["hauki", "ahven", "lahna"]:
		# Keskisyvyys koko kannasta (parvet vaihtelevat), kaislikko hauista otoksena
		var depth := 0.0
		var reedy := 0
		var n := 0
		for f in pop.fish:
			if f["sp"] != sp:
				continue
			n += 1
			depth += f["depth"]
			if n <= REEDS_SAMPLE and lake.reeds_near(f["pos"].x, f["pos"].y, 25.0) > 0.04:
				reedy += 1
		result[sp] = [depth / maxi(n, 1), float(reedy) / mini(maxi(n, 1), REEDS_SAMPLE)]
	pop.free()
	return result

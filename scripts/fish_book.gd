extends Node
## Kalakirja: jokaisesta lajista saaliiden määrä, oma ennätys ja ensimmäinen saalis.
## Laji "avautuu" kirjaan, kun sen saa ensimmäisen kerran. Mukana ovat sekä
## kertakalastuksen että uramoodin saaliit. Tallennetaan: user://kalakirja.json
## (ensimmäisellä kerralla kirja täytetään saaliskirjan vanhoista saaliista).

const PATH := "user://kalakirja.json"
## Tallennusmuodon versio. Versiossa 2 (0.46.0) vanha kirja tyhjennettiin
## kertaalleen yhdessä ennätyslistan kanssa (ks. CatchLog.SAVE_VERSION).
const SAVE_VERSION := 2

## Lajin sivun tekstit: tieteellinen nimi ja kuvaus
const TEXTS := {
	"hauki": ["Esox lucius", "Väijyvä petokala, joka seisoo kaislikon reunassa ja syöksyy saaliinsa kimppuun salamannopeasti. Hauki kutee heti jäiden lähdettyä matalissa, tulvivissa lahdissa. Suuri kita ja terävät hampaat – haavi ja pihdit kannattaa pitää lähellä."],
	"ahven": ["Perca fluviatilis", "Suomen yleisin kala ja kansalliskala. Raidallinen, punaeväinen parvikala syö päivällä ja iskee innokkaasti pieniin vieheisiin, kesällä myös matoon. Syksyllä isot ahvenet kerääntyvät syvänteiden reunoille."],
	"sarki": ["Rutilus rutilus", "Hopeakylkinen, punasilmäinen parvikala, joka viihtyy rantojen ja kasvillisuuden tuntumassa. Särki syö pohjaeläimiä, kasveja ja hyönteisiä, joten sen saa parhaiten mato-ongella tai talvella pilkkiin pujotetulla toukalla."],
	"kiiski": ["Gymnocephalus cernua", "Pieni, limainen ja piikikäs ahvenen sukulainen, joka elää pohjan tuntumassa. Kiiski on ahne syöjä ja tarttuu usein pohjaongen tai pilkin syöttiin. Kiiskikeitto on vanha herkku."],
	"lahna": ["Abramis brama", "Korkea ja kyljiltään litteä särkikala, joka penkoo pohjamutaa ruokaa etsien. Lahnaparvet liikkuvat hitaasti ja varovasti, joten iso lahna on harvinainen ja arvostettu saalis pohjaongella."],
	"made": ["Lota lota", "Turskan sukuinen, pimeää ja kylmää vettä rakastava pohjakala. Made syö öisin ja innostuu talvella, jolloin se myös kutee jään alla. Kesällä se lepää syvänteissä eikä juuri syö."],
}

## laji -> {count, best: saalis, first: ensimmäisen saaliin päiväys}
var species: Dictionary = {}
var persist := true


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			persist = false # testiajot eivät koske pelaajan kalakirjaan
	if persist and FileAccess.file_exists(PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if is_current_save(data):
			species = data["species"]
			return
	rebuild(CatchLog.entries if persist else [])
	_save()


## Onko tallennus nykyistä muotoa (vanha muoto tyhjennetään)
static func is_current_save(data) -> bool:
	return data is Dictionary and int(data.get("version", 0)) >= SAVE_VERSION and data.get("species") is Dictionary


## Kirja alusta annetuista saaliista (vanhat saaliskirjan saaliit)
func rebuild(entries: Array) -> void:
	species = {}
	for e in entries:
		_record(e)


## Lisää saaliin kirjaan. Palauttaa true, jos laji avautui nyt ensimmäisen kerran.
func add(entry: Dictionary) -> bool:
	var first := not unlocked(entry["species"])
	_record(entry)
	_save()
	return first


func _record(entry: Dictionary) -> void:
	var sp: String = entry["species"]
	if not Species.DATA.has(sp):
		return # vanhojen tallennusten lajit (kuha, taimen) eivät ole kirjassa
	var page: Dictionary = species.get(sp, {"count": 0, "best": {}, "first": entry.get("date", "")})
	page["count"] = int(page["count"]) + 1
	if page["best"].is_empty() or entry["weight"] > page["best"]["weight"]:
		page["best"] = entry.duplicate()
	species[sp] = page


func unlocked(sp: String) -> bool:
	return species.has(sp)


func count(sp: String) -> int:
	return int(species.get(sp, {}).get("count", 0))


func best(sp: String) -> Dictionary:
	return species.get(sp, {}).get("best", {})


func first_date(sp: String) -> String:
	return species.get(sp, {}).get("first", "")


func unlocked_count() -> int:
	return Species.DATA.keys().filter(unlocked).size()


func _save() -> void:
	if not persist:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version": SAVE_VERSION, "species": species}, "  "))

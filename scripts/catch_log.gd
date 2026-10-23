extends Node
## Kertakalastuksen saaliit ja ennätykset (painavimmat kalat), tallennetaan pelaajan
## koneelle. Uramoodin saaliit eivät tule tähän (ne ovat saavissa ja säilössä).

const SAVE_PATH := "user://saaliskirja.json"
## Tallennusmuodon versio. Versiossa 2 (0.46.0) vanhat ennätykset tyhjennettiin
## kertaalleen, koska kalalajit ovat muuttuneet projektin alusta.
const SAVE_VERSION := 2

var entries: Array = []
## Automaattitestit kalastavat oikeaa peliä, mutta niiden saaliita ei tallenneta
var persist := true


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			persist = false # testiajot eivät koske pelaajan saaliskirjaan
	if FileAccess.file_exists(SAVE_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		entries = parse_save(data)
		if not data is Dictionary or not data.has("version"):
			_save() # vanha tallennus tyhjennetään kerran


## Tallennuksen saaliit; vanhan muodon (pelkkä taulukko) saaliit jätetään pois
static func parse_save(data) -> Array:
	if data is Dictionary and int(data.get("version", 0)) >= SAVE_VERSION and data.get("entries") is Array:
		return data["entries"]
	return []


## Lisää saaliin. Palauttaa true, jos se on lajin uusi ennätys.
func add(entry: Dictionary) -> bool:
	var best := personal_best(entry["species"])
	entries.append(entry)
	_save()
	return best.is_empty() or entry["weight"] > best["weight"]


func personal_best(species: String) -> Dictionary:
	var best := {}
	for e in entries:
		if e["species"] == species and (best.is_empty() or e["weight"] > best["weight"]):
			best = e
	return best


## Koko pelin painavimmat kalat (kaikki lajit)
func top(n: int) -> Array:
	var sorted := entries.duplicate()
	sorted.sort_custom(func(a, b): return a["weight"] > b["weight"])
	return sorted.slice(0, n)


func count(species: String) -> int:
	var n := 0
	for e in entries:
		if e["species"] == species:
			n += 1
	return n


func _save() -> void:
	if not persist:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version": SAVE_VERSION, "entries": entries}, "  "))

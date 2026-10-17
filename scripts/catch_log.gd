extends Node
## Saaliskirja: kaikki saaliit ja lajikohtaiset ennätykset, tallennetaan pelaajan koneelle.

const SAVE_PATH := "user://saaliskirja.json"

var entries: Array = []
## Automaattitestit kalastavat oikeaa peliä, mutta niiden saaliita ei tallenneta
var persist := true


func _ready() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if data is Array:
			entries = data


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
		f.store_string(JSON.stringify(entries, "  "))

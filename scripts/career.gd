extends Node
## Uramoodi: päivät, kello, rahat, kalasäilö ja uistinvarasto.
## Ura alkaa maanantaina 1.6. aamulla. Päivä vaihtuu, kun kello ohittaa puolenyön
## (kalareissulla tai nukkuessa), ja vuodenaika etenee päivien mukana.
## Tallennetaan: user://ura.json

const PATH := "user://ura.json"
const START_DAY_OF_YEAR := 152 # 1.6.
const START_MONEY := 20.0
const START_LURES := {"lusikka": 2, "jigi": 2, "pilkki": 2}
const WEEKDAYS := ["maanantai", "tiistai", "keskiviikko", "torstai", "perjantai", "lauantai", "sunnuntai"]

## Tuottajahinnat €/kg (Luonnonvarakeskus, kaupallinen kalastus merialueella):
## ahven ja kuha 2025, hauki 2023 (uusin löydetty), taimen = perattu lohi 2025
## (Luke ei tilastoi taimenen hintaa erikseen).
const PRICES := {"ahven": 2.22, "hauki": 2.44, "kuha": 6.19, "taimen": 10.57}

var active := false # ura käynnissä (pelissä kalareissu on uran reissu)
var day := 1
var minutes := 7.0 * 60.0 # kotikello
var money := START_MONEY
var storage: Array = [] # säilössä olevat kalat: {species, name, weight, length, day}
var lures: Dictionary = {} # uistimen id -> kappalemäärä
var trip_start := 0.0
var persist := true


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			persist = false # testiajot eivät koske pelaajan uraan
	load_game()


func has_save() -> bool:
	return persist and FileAccess.file_exists(PATH)


func new_career() -> void:
	day = 1
	minutes = 7.0 * 60.0
	money = START_MONEY
	storage = []
	lures = START_LURES.duplicate()
	save_game()


func load_game() -> void:
	if not has_save():
		new_career()
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not data is Dictionary:
		new_career()
		return
	day = int(data.get("day", 1))
	minutes = float(data.get("minutes", 420.0))
	money = float(data.get("money", START_MONEY))
	storage = data.get("storage", [])
	lures = {}
	for id in data.get("lures", {}):
		lures[id] = int(data["lures"][id])


func save_game() -> void:
	if not persist:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"day": day, "minutes": minutes, "money": money, "storage": storage, "lures": lures}, "  "))


## Kello etenee; puolenyön jälkeen vaihtuu seuraava päivä
func advance(by_minutes: float) -> int:
	var days_before := day
	minutes += by_minutes
	while minutes >= 24.0 * 60.0:
		minutes -= 24.0 * 60.0
		day += 1
	return day - days_before


func sleep(hours: float) -> int:
	var passed := advance(hours * 60.0)
	save_game()
	return passed


func weekday() -> String:
	return WEEKDAYS[(day - 1) % 7]


func day_of_year() -> int:
	return (START_DAY_OF_YEAR - 1 + day - 1) % 365 + 1


func date_text() -> String:
	var lengths := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	var d := day_of_year()
	var month := 0
	while d > lengths[month]:
		d -= lengths[month]
		month += 1
	return "%d.%d." % [d, month + 1]


func clock_text() -> String:
	var m := int(minutes) % (24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]


## Päivän kilohinta: tuottajahinta ± enintään 15 % päivittäistä vaihtelua
func price(species: String) -> float:
	var wobble := sin(day * 1.7 + species.hash() % 100) * 0.1 + sin(day * 0.43 + species.length()) * 0.05
	return snappedf(PRICES.get(species, 1.0) * (1.0 + wobble), 0.01)


func storage_kg(species := "") -> float:
	var kg := 0.0
	for f in storage:
		if species == "" or f["species"] == species:
			kg += f["weight"]
	return kg


func storage_count(species := "") -> int:
	var n := 0
	for f in storage:
		if species == "" or f["species"] == species:
			n += 1
	return n


## Myy säilöstä lajin kaikki kalat (tyhjä = kaikki lajit); palauttaa saadun summan
func sell(species := "") -> float:
	var earned := 0.0
	var kept: Array = []
	for f in storage:
		if species == "" or f["species"] == species:
			earned += f["weight"] * price(f["species"])
		else:
			kept.append(f)
	storage = kept
	money = snappedf(money + earned, 0.01)
	save_game()
	return snappedf(earned, 0.01)


func buy(lure: Dictionary) -> bool:
	if money + 0.001 < lure["price"]:
		return false
	money = snappedf(money - lure["price"], 0.01)
	lures[lure["id"]] = int(lures.get(lure["id"], 0)) + 1
	save_game()
	return true


## Kalareissun loppu: saalis säilöön ja kotikello reissun mukaan
func end_trip(catch: Array, trip_minutes: float) -> void:
	for e in catch:
		storage.append({"species": e["species"], "name": e["name"], "weight": e["weight"], "length": e["length"], "day": day})
	advance(trip_minutes)
	save_game()

extends Node
## Uramoodi: päivät, kello, rahat, kalasäilö ja uistinvarasto.
## Ura alkaa maanantaina 1.6. aamulla. Päivä vaihtuu, kun kello ohittaa puolenyön
## (kalareissulla tai nukkuessa), ja vuodenaika etenee päivien mukana.
## Järveen lasketut verkot jäävät paikoilleen reissujen yli.
## Virvelikalastus ja verkot vaativat kalastonhoitomaksun, toinen vapa lisäksi
## tekoaltaan luvan. Vapautetut kalat antavat mainetta, joka nostaa myyntihintoja.
## Tallennetaan: user://ura.json

const PATH := "user://ura.json"
const START_DAY_OF_YEAR := 152 # 1.6.
const START_MONEY := 50.0
const START_LURES := {"lusikka": 2, "jigi": 2, "pilkki": 2}
const WEEKDAYS := ["maanantai", "tiistai", "keskiviikko", "torstai", "perjantai", "lauantai", "sunnuntai"]

## Tuottajahinnat €/kg: Luonnonvarakeskus, kaupallinen kalastus sisävesillä 2024
## (saaliin nimellisarvo / saalis lajeittain). Kiiski = "muut kalat".
## Kuha ja taimen: vanhojen tallennusten säilössä voi vielä olla niitä
## (merialueen hinnat 2025, taimen = perattu lohi).
## Kalastonhoitomaksut (eraluvat.fi, 2026): vuosimaksu kalenterivuoden loppuun,
## viikkomaksu 7 vrk, vuorokausimaksu ostopäivän loppuun
const FEES := [
	{"id": "vuosi", "name": "Vuosimaksu (31.12. asti)", "price": 47.0},
	{"id": "viikko", "name": "Viikkomaksu (7 vrk)", "price": 16.0},
	{"id": "vrk", "name": "Vuorokausimaksu (tämä päivä)", "price": 6.0},
]
## Tekoaltaan lupa toiselle vavalle, kalenterivuoden loppuun
const ROD_PERMIT_PRICE := 10.0
## Ison kalan raja (kg): lajin painojakauman 95. persentiili pyöristettynä;
## vapautettu iso kala antaa lisämainetta
const BIG_FISH := {"hauki": 5.0, "lahna": 2.5, "made": 1.7, "ahven": 0.4, "sarki": 0.3, "kiiski": 0.06}
const BIG_FISH_FAME := 5
const MAX_PRICE_BONUS := 25 # % (250 mainetta)

const PRICES := {"ahven": 2.52, "hauki": 2.74, "made": 5.28, "sarki": 0.95, "lahna": 1.23, "kiiski": 0.82, "kuha": 6.19, "taimen": 10.57}

var active := false # ura käynnissä (pelissä kalareissu on uran reissu)
var day := 1
var minutes := 7.0 * 60.0 # kotikello
var money := START_MONEY
## Kalastonhoitomaksun ja toisen vavan luvan viimeinen voimassaolopäivä uran
## päivänä (0 = ei maksettu)
var fee_until := 0
var rod_permit_until := 0
var fame := 0 # maine vapautetuista kaloista
var storage: Array = [] # säilössä olevat kalat: {species, name, weight, length, day}
var lures: Dictionary = {} # uistimen id -> kappalemäärä (myös verkot, Nets.LIST)
## Järveen jääneet verkot (Nets-muoto); ne odottavat nostoa seuraavalla reissulla
var nets: Array = []
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
	fee_until = 0 # ura alkaa ilman maksua: pelaaja maksaa sen itse liikkeessä
	rod_permit_until = 0
	fame = 0
	storage = []
	lures = START_LURES.duplicate()
	nets = []
	save_game()


func load_game() -> void:
	if not has_save():
		new_career()
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not data is Dictionary:
		new_career()
		return
	from_dict(data)


## Tallennuksen tiedot; vanhoista tallennuksista puuttuvat kentät saavat oletusarvon
func from_dict(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	minutes = float(data.get("minutes", 420.0))
	money = float(data.get("money", START_MONEY))
	fee_until = int(data.get("fee_until", 0))
	rod_permit_until = int(data.get("rod_permit_until", 0))
	fame = int(data.get("fame", 0))
	storage = data.get("storage", [])
	lures = {}
	for id in data.get("lures", {}):
		lures[id] = int(data["lures"][id])
	nets = data.get("nets", [])


func save_game() -> void:
	if not persist:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict(), "  "))


func to_dict() -> Dictionary:
	return {"day": day, "minutes": minutes, "money": money, "fee_until": fee_until, "rod_permit_until": rod_permit_until, "fame": fame, "storage": storage, "lures": lures, "nets": nets}


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


## Uran kello absoluuttisina minuutteina (päivä * 1440 + minuutit); reissulla
## kello on sky.minutes, joka alkaa uran kellosta (Career.trip_start)
func abs_minutes(clock_minutes: float) -> float:
	return day * 1440.0 + clock_minutes


## Vuodenpäivä absoluuttisten minuuttien hetkellä
func day_of_year_at(abs_min: float) -> int:
	var d := int(abs_min / 1440.0)
	return (START_DAY_OF_YEAR - 1 + d - 1) % 365 + 1


func weekday() -> String:
	return WEEKDAYS[(day - 1) % 7]


## Vuodenpäivä uran päivänä (oletus: tämä päivä)
func day_of_year(at_day := -1) -> int:
	return (START_DAY_OF_YEAR - 1 + (day if at_day < 0 else at_day) - 1) % 365 + 1


## Päivämäärä "1.6." uran päivänä (oletus: tämä päivä)
func date_text(at_day := -1) -> String:
	var lengths := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	var d := day_of_year(at_day)
	var month := 0
	while d > lengths[month]:
		d -= lengths[month]
		month += 1
	return "%d.%d." % [d, month + 1]


func clock_text() -> String:
	var m := int(minutes) % (24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]


## Päivän kilohinta: tuottajahinta ± enintään 15 % päivittäistä vaihtelua
## ja maineen hintalisä
func price(species: String) -> float:
	var wobble := sin(day * 1.7 + species.hash() % 100) * 0.1 + sin(day * 0.43 + species.length()) * 0.05
	return snappedf(PRICES.get(species, 1.0) * (1.0 + wobble) * (1.0 + price_bonus()), 0.01)


## Maineen hintalisä: +1 % jokaista täyttä 10 mainetta kohden, enintään +25 %
func price_bonus_percent() -> int:
	return mini(floori(fame / 10.0), MAX_PRICE_BONUS)


func price_bonus() -> float:
	return price_bonus_percent() / 100.0


## Vapautetun kalan maine: 1 piste alkavaa kiloa kohden (alle 50 g kala ei
## anna mitään) ja lisäksi 5, jos kala on vähintään lajinsa ison kalan rajan painoinen
static func release_fame(species: String, weight: float) -> int:
	if weight < 0.05 - 0.0001:
		return 0
	var points := ceili(weight - 0.0001)
	if weight >= BIG_FISH.get(species, INF) - 0.0001:
		points += BIG_FISH_FAME
	return points


func add_fame(points: int) -> void:
	fame += points
	save_game()


# --- Kalastonhoitomaksu ja toisen vavan lupa ----------------------------------

## Kuluvan kalenterivuoden viimeinen päivä (31.12.) uran päivänä
func year_end_day() -> int:
	return day + 365 - day_of_year()


func fee_valid() -> bool:
	return fee_until >= day


func fee(kind: String) -> Dictionary:
	for f in FEES:
		if f["id"] == kind:
			return f
	return {}


## Maksun viimeinen voimassaolopäivä, jos sen ostaa tänään
func fee_end(kind: String) -> int:
	match kind:
		"vuosi":
			return year_end_day()
		"viikko":
			return day + 6
	return day


## Voiko maksun maksaa: rahat riittävät ja maksu pidentää voimassaoloa
func can_pay_fee(kind: String) -> bool:
	return money + 0.001 >= fee(kind)["price"] and fee_end(kind) > maxi(fee_until, day - 1)


## Päällekkäinen maksu ei summaa päiviä: voimassa on myöhempi päättymispäivä
func pay_fee(kind: String) -> bool:
	if not can_pay_fee(kind):
		return false
	money = snappedf(money - fee(kind)["price"], 0.01)
	fee_until = maxi(fee_until, fee_end(kind))
	save_game()
	return true


func fee_until_text() -> String:
	return "voimassa %s asti" % date_text(fee_until) if fee_valid() else "ei maksettu"


func rod_permit_valid() -> bool:
	return rod_permit_until >= day


func can_pay_rod_permit() -> bool:
	return money + 0.001 >= ROD_PERMIT_PRICE and not rod_permit_valid()


func pay_rod_permit() -> bool:
	if not can_pay_rod_permit():
		return false
	money = snappedf(money - ROD_PERMIT_PRICE, 0.01)
	rod_permit_until = year_end_day()
	save_game()
	return true


func rod_permit_text() -> String:
	return "voimassa %s asti" % date_text(rod_permit_until) if rod_permit_valid() else "ei lupaa"


## Toinen vapa vaatii sekä luvan että kalastonhoitomaksun
func second_rod_allowed() -> bool:
	return rod_permit_valid() and fee_valid()


## Myytävät lajit: [id, nimi] – järven lajit ja säilössä olevat vanhat lajit
func sale_species() -> Array:
	var list := []
	for sp in Species.DATA:
		list.append([sp, Species.DATA[sp]["name"]])
	for f in storage:
		if not Species.DATA.has(f["species"]) and not list.any(func(x): return x[0] == f["species"]):
			list.append([f["species"], f["name"]])
	return list


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

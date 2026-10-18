extends Node
## Pelaajan asetukset, tallennetaan koneelle (user://asetukset.cfg).

const PATH := "user://asetukset.cfg"

## Valittavat vuodenajat: [nimi, vuoden päivä]
const SEASONS := [
	["Kevät (toukokuu)", 145],
	["Kesä (kesäkuu)", 165],
	["Ruska-aika (syyskuu)", 258],
	["Myöhäissyksy (lokakuu)", 291],
	["Talvi – pilkkiminen jäältä", 40],
]
## Valittavat kellonajat: [nimi, tunti]
const TIMES := [
	["Aamu 5.30", 5.5],
	["Aamupäivä 9.00", 9.0],
	["Keskipäivä 12.00", 12.0],
	["Iltapäivä 16.00", 16.0],
	["Ilta 20.00", 20.0],
	["Yö 23.30", 23.5],
]

## Todellinen kellonaika ja sää (Saloinen, Raahe)
var real_world := false
## Itse valittu vuodenaika ja kellonaika (kun todellinen aika ei ole käytössä)
var season_index := 1
var time_index := 0
## Testiajot eivät tallenna asetuksia pelaajan koneelle
var persist := true


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		real_world = cfg.get_value("peli", "todellinen_aika_ja_saa", false)
		season_index = clampi(cfg.get_value("peli", "vuodenaika", 1), 0, SEASONS.size() - 1)
		time_index = clampi(cfg.get_value("peli", "kellonaika", 0), 0, TIMES.size() - 1)
	# Testiajot eivät käytä pelaajan asetuksia
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			real_world = false
			season_index = 1
			time_index = 0
			persist = false


func season_day() -> int:
	return SEASONS[season_index][1]


func start_hour() -> float:
	return TIMES[time_index][1]


func save() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("peli", "todellinen_aika_ja_saa", real_world)
	cfg.set_value("peli", "vuodenaika", season_index)
	cfg.set_value("peli", "kellonaika", time_index)
	cfg.save(PATH)

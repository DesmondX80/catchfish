extends Node
## Pelaajan asetukset, tallennetaan koneelle (user://asetukset.cfg).
## Äänenvoimakkuudet säädetään omilla mikseriväylillä (Taustaäänet, Efektit,
## Puhe), jotka luodaan tässä ja ohjataan Master-väylään.

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
## Hiiren herkkyys kameran käännössä (kerroin) ja käänteinen pystyohjaus
const SENSITIVITY_MIN := 0.25
const SENSITIVITY_MAX := 3.0
var mouse_sensitivity := 1.0
var invert_y := false
## Äänenvoimakkuudet 0–1 väylittäin: [väylä, nimi valikossa, asetuksen avain]
const BUSES := [
	["Master", "Kaikki äänet", "kaikki"],
	["Taustaäänet", "Taustaäänet (tuuli, aallot, linnut)", "taustaaanet"],
	["Efektit", "Efektit (vene, kalastus)", "efektit"],
	["Puhe", "Kalastajan puhe", "puhe"],
]
var volumes := {"Master": 1.0, "Taustaäänet": 1.0, "Efektit": 1.0, "Puhe": 1.0}
## Testiajot eivät tallenna asetuksia pelaajan koneelle
var persist := true


func _ready() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b[0]) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b[0])
			AudioServer.set_bus_send(i, "Master")
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		real_world = cfg.get_value("peli", "todellinen_aika_ja_saa", false)
		season_index = clampi(cfg.get_value("peli", "vuodenaika", 1), 0, SEASONS.size() - 1)
		time_index = clampi(cfg.get_value("peli", "kellonaika", 0), 0, TIMES.size() - 1)
		mouse_sensitivity = clampf(cfg.get_value("ohjaus", "hiiren_herkkyys", 1.0), SENSITIVITY_MIN, SENSITIVITY_MAX)
		invert_y = cfg.get_value("ohjaus", "kaanteinen_pystyohjaus", false)
		for b in BUSES:
			volumes[b[0]] = clampf(cfg.get_value("aanet", b[2], 1.0), 0.0, 1.0)
	# Testiajot eivät käytä pelaajan asetuksia
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			real_world = false
			season_index = 1
			time_index = 0
			mouse_sensitivity = 1.0
			invert_y = false
			for b in BUSES:
				volumes[b[0]] = 1.0
			persist = false
	for bus in volumes:
		set_volume(bus, volumes[bus])


func season_day() -> int:
	return SEASONS[season_index][1]


func start_hour() -> float:
	return TIMES[time_index][1]


## Kameran käännön kertoimet hiiren liikkeelle (x, y)
func mouse_look_scale() -> Vector2:
	return Vector2(1.0, -1.0 if invert_y else 1.0) * mouse_sensitivity


## Väylän äänenvoimakkuus 0–1 (nollassa väylä mykistetään)
func set_volume(bus: String, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	var i := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(volumes[bus], 0.0001)))
	# Master-väylän mykistää myös M-näppäin, joten sitä ei kosketa
	if bus != "Master":
		AudioServer.set_bus_mute(i, volumes[bus] <= 0.0)


func save() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("peli", "todellinen_aika_ja_saa", real_world)
	cfg.set_value("peli", "vuodenaika", season_index)
	cfg.set_value("peli", "kellonaika", time_index)
	cfg.set_value("ohjaus", "hiiren_herkkyys", mouse_sensitivity)
	cfg.set_value("ohjaus", "kaanteinen_pystyohjaus", invert_y)
	for b in BUSES:
		cfg.set_value("aanet", b[2], volumes[b[0]])
	cfg.save(PATH)

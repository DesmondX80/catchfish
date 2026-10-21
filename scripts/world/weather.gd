class_name Weather
extends Node
## Sää: tuuli, pilvisyys ja sade.
## Tuuli muuttuu hitaasti satunnaisesti ja puuskittain. Se ajelehdittaa venettä,
## vaikuttaa heittoon ja aallokkoon sekä kalojen syöntihaluun.
## Säätila vaihtuu pelin kellon mukaan (selkeä, puolipilvinen, pilvinen, sade,
## rankkasade). Pilvisyys kasvaa vähitellen, ja sade alkaa vasta lähes täysin
## pilvisellä taivaalla. Sateella tuuli voimistuu.

enum Kind { CLEAR, PARTLY, CLOUDY, RAIN, HEAVY_RAIN }

## Säätilat: [pilvisyys min, max, sade min, max]
const KINDS := {
	Kind.CLEAR: [0.0, 0.15, 0.0, 0.0],
	Kind.PARTLY: [0.35, 0.55, 0.0, 0.0],
	Kind.CLOUDY: [0.75, 0.9, 0.0, 0.0],
	Kind.RAIN: [0.92, 1.0, 0.2, 0.5],
	Kind.HEAVY_RAIN: [1.0, 1.0, 0.75, 1.0],
}
## Todennäköisyydet seuraavalle säätilalle (yleensä naapuritila)
const NEXT := {
	Kind.CLEAR: [[Kind.CLEAR, 0.4], [Kind.PARTLY, 0.6]],
	Kind.PARTLY: [[Kind.CLEAR, 0.35], [Kind.PARTLY, 0.25], [Kind.CLOUDY, 0.4]],
	Kind.CLOUDY: [[Kind.PARTLY, 0.4], [Kind.CLOUDY, 0.2], [Kind.RAIN, 0.4]],
	Kind.RAIN: [[Kind.CLOUDY, 0.45], [Kind.RAIN, 0.25], [Kind.HEAVY_RAIN, 0.3]],
	Kind.HEAVY_RAIN: [[Kind.RAIN, 0.8], [Kind.HEAVY_RAIN, 0.2]],
}

var wind_direction := 0.6 # radiaaneina: suunta, johon tuuli puhaltaa (0 = pohjoiseen)
var wind_base := 3.0 # m/s
var gust := 0.0
var cloud_cover := 0.2 # 0 selkeä .. 1 täysin pilvessä
var rain := 0.0 # sateen voimakkuus 0 .. 1
var kind := Kind.CLEAR
var sky: SkyTime # pelin kello: sää muuttuu peliajassa
var snow := false # sataa lunta (todellinen sää)
var temperature := NAN # °C, vain todellisessa säässä
## Todellinen sää: säätila ei vaihdu itsestään, vaan apply_real() asettaa sen
var real_mode := false
var real_source := ""
var real_time := ""
var _gust_peak := 0.0

var _rng := RandomNumberGenerator.new()
var _gust_timer := 0.0
var _gust_target := 0.0 # puuskan huippu, jota kohti tuuli voimistuu
var _wind_target := 3.0
var _cover_target := 0.2
var _rain_target := 0.0
var _change_in := 40.0 # peliminuuttia seuraavaan säätilan vaihtoon


func _ready() -> void:
	_rng.randomize()
	wind_direction = _rng.randf() * TAU
	wind_base = _rng.randf_range(1.0, 5.0)
	_wind_target = wind_base
	# Aamu alkaa useimmiten selkeänä tai puolipilvisenä
	set_kind(Kind.CLEAR if _rng.randf() < 0.55 else (Kind.PARTLY if _rng.randf() < 0.75 else Kind.CLOUDY), true)


## Vaihtaa säätilan (instant = heti, muuten vähitellen)
func set_kind(new_kind: int, instant := false) -> void:
	kind = new_kind
	var k: Array = KINDS[kind]
	_cover_target = _rng.randf_range(k[0], k[1])
	_rain_target = _rng.randf_range(k[2], k[3])
	_change_in = _rng.randf_range(30.0, 90.0)
	if instant:
		cloud_cover = _cover_target
		rain = _rain_target


func _process(delta: float) -> void:
	var game_minutes := delta * (sky.time_scale() if sky else 1.0) / 60.0
	if real_mode:
		game_minutes = maxf(game_minutes, delta / 6.0) # havainnot tulevat näkyviin muutamassa sekunnissa
	else:
		_change_in -= game_minutes
		if _change_in <= 0.0:
			set_kind(_pick_next())

	# Pilvet tulevat noin puolessa tunnissa; sade alkaa vasta pilvisellä taivaalla
	cloud_cover = move_toward(cloud_cover, _cover_target, game_minutes / 30.0)
	var rain_goal := _rain_target if cloud_cover > 0.85 or real_mode else 0.0
	rain = move_toward(rain, rain_goal, game_minutes / 8.0)

	# Tuuli: hidas satunnaiskävely, sateella voimakkaampi; todellisessa säässä havaittu
	if real_mode:
		wind_base = move_toward(wind_base, _wind_target, delta * 0.3)
	else:
		_wind_target = clampf(_wind_target + _rng.randfn(0.0, 0.05) * delta * 4.0, 0.5, 8.0)
		wind_base = move_toward(wind_base, clampf(_wind_target + rain * 3.0, 0.0, 11.0), delta * 0.05)
	wind_direction = wrapf(wind_direction + _rng.randfn(0.0, 0.02) * delta * 4.0, 0.0, TAU)
	_gust_timer -= delta
	if _gust_timer <= 0.0:
		_gust_timer = _rng.randf_range(3.0, 12.0)
		var peak := maxf(_gust_peak - wind_base, 0.3) if real_mode else wind_base * (0.5 + rain * 0.3)
		_gust_target = _rng.randf_range(0.0, peak)
	# Puuska voimistuu parissa sekunnissa (ei hyppäystä) ja laantuu hitaasti
	if _gust_target > gust:
		gust = move_toward(gust, _gust_target, delta * 0.8)
		if gust >= _gust_target:
			_gust_target = 0.0
	else:
		gust = move_toward(gust, 0.0, delta * 0.3)


## Todellinen sää (RealWeather): pilvisyys, sade ja tuuli havainnoista
func apply_real(data: Dictionary, instant := false) -> void:
	real_mode = true
	real_source = data["source"]
	real_time = data["time"]
	temperature = data["temperature"]
	snow = data["snow"]
	_cover_target = data["cloud"]
	_rain_target = data["precipitation"]
	_wind_target = data["wind_speed"]
	_gust_peak = data["wind_gust"]
	# Havaittu suunta on se, MISTÄ tuulee; pelissä suunta, JOHON tuulee
	var to := deg_to_rad(data["wind_from_deg"] + 180.0)
	wind_direction = to if instant else lerp_angle(wind_direction, to, 1.0)
	if instant:
		cloud_cover = _cover_target
		rain = _rain_target
		wind_base = _wind_target
	# Sade alkaa todellisessa säässä heti eikä odota täyttä pilvipeitettä
	if _rain_target > 0.0:
		_cover_target = maxf(_cover_target, 0.9)


func _pick_next() -> int:
	var r := _rng.randf()
	for option in NEXT[kind]:
		r -= option[1]
		if r <= 0.0:
			return option[0]
	return kind


func speed() -> float:
	return wind_base + gust


## Tuulen nopeusvektori maailman XZ-tasossa (m/s)
func vector() -> Vector2:
	return Vector2(sin(wind_direction), -cos(wind_direction)) * speed()


## Ilmansuunta, josta tuuli puhaltaa, esim. "lounaasta"
func from_text() -> String:
	var names := ["pohjoisesta", "koillisesta", "idästä", "kaakosta", "etelästä", "lounaasta", "lännestä", "luoteesta"]
	var from := wrapf(wind_direction + PI, 0.0, TAU)
	return names[int(round(from / (TAU / 8.0))) % 8]


## Säätila sanoin, esim. "Pilvistä, heikkoa sadetta"
func description() -> String:
	var sky_text := "Selkeää"
	if cloud_cover > 0.85:
		sky_text = "Pilvistä"
	elif cloud_cover > 0.6:
		sky_text = "Enimmäkseen pilvistä"
	elif cloud_cover > 0.3:
		sky_text = "Puolipilvistä"
	elif cloud_cover > 0.12:
		sky_text = "Melkein selkeää"
	var what := "lumisadetta" if snow else "sadetta"
	if rain > 0.7:
		return sky_text + (", runsasta lumisadetta" if snow else ", rankkasadetta")
	if rain > 0.35:
		return sky_text + ", " + what
	if rain > 0.03:
		return sky_text + ", heikkoa " + what
	return sky_text

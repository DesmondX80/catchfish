class_name Weather
extends Node
## Tuuli muuttuu hitaasti satunnaisesti ja puuskittain. Tuuli ajelehdittaa venettä,
## vaikuttaa heittoon ja aallokkoon sekä kalojen syöntihaluun.

var wind_direction := 0.6 # radiaaneina: suunta, johon tuuli puhaltaa (0 = pohjoiseen)
var wind_base := 3.0 # m/s
var gust := 0.0
var _rng := RandomNumberGenerator.new()
var _gust_timer := 0.0


func _ready() -> void:
	_rng.randomize()
	wind_direction = _rng.randf() * TAU
	wind_base = _rng.randf_range(1.0, 5.0)


func _process(delta: float) -> void:
	wind_direction = wrapf(wind_direction + _rng.randfn(0.0, 0.02) * delta * 4.0, 0.0, TAU)
	wind_base = clampf(wind_base + _rng.randfn(0.0, 0.05) * delta * 4.0, 0.0, 9.0)
	_gust_timer -= delta
	if _gust_timer <= 0.0:
		_gust_timer = _rng.randf_range(3.0, 12.0)
		gust = _rng.randf_range(0.0, wind_base * 0.5)
	gust = move_toward(gust, 0.0, delta * 0.3)


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

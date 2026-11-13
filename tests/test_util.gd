class_name TestUtil
## Testien yhteiset apufunktiot.


## Tyyni, pysäytetty sää ja aallokko sen mukaiseksi: sää ei muutu kesken testin.
## Kutsu testin _ready()ssä heti main = get_parent():n jälkeen, ellei testi testaa säätä.
static func calm_weather(main: Node, wind := 0.0, direction := 0.6) -> void:
	var w: Weather = main.weather
	w.set_process(false)
	w.real_mode = false
	w.wind_base = wind
	w._wind_target = wind
	w.gust = 0.0
	w._gust_target = 0.0
	w._gust_timer = INF
	w.wind_direction = direction
	w.kind = Weather.Kind.CLEAR
	w.cloud_cover = 0.1
	w._cover_target = 0.1
	w.rain = 0.0
	w._rain_target = 0.0
	w.pressure = 1013.0
	w._pressure_target = 1013.0
	w.pressure_trend = 0.0
	w._change_in = INF
	Waves.reset(wind, direction)

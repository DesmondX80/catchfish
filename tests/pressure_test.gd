extends Node
## Ilmanpaineen testi: godot --headless -- --day=180 --pressuretest
## Simuloidussa säässä paine seuraa säätilaa: sään huonontuessa paine laskee ja
## kalat syövät kiivaammin, sään selkeytyessä paine nousee ja syönti heikkenee,
## tasaisessa korkeapaineessa syönti on laiskaa. Todellisen sään vastauksista
## luetaan paine ja sen muutos kolmessa tunnissa.

var main: Node
var _log: Array[String] = []


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _ready() -> void:
	main = get_parent()
	var w := Weather.new()
	add_child(w) # _ready arpoo alkusään
	w.set_process(false)
	w.set_kind(Weather.Kind.CLEAR, true)
	w.pressure = 1025.0
	_check("tasainen korkeapaine: syönti laiskaa (%s, kerroin %.2f)" % [w.pressure_text(), w.feeding_factor()], w.feeding_factor() < 0.85)
	# Sää huononee: tunnin ajan peliminuutteja
	w.set_kind(Weather.Kind.RAIN)
	_advance(w, 60)
	_check("sään huonontuessa paine laskee ja kalat syövät kiivaasti (%s, %.1f hPa/3 h, kerroin %.2f)" % [w.pressure_text(), w.pressure_trend, w.feeding_factor()],
		w.pressure_trend < -1.5 and w.feeding_factor() > 1.1 and w.pressure_text().contains("laskee"))
	# Sadetta muutama tunti, sitten selkenee (paine on silloin selvästi alempana)
	_advance(w, 180)
	w.set_kind(Weather.Kind.CLEAR)
	_advance(w, 60)
	_check("sään selkeytyessä paine nousee ja syönti heikkenee (%s, kerroin %.2f)" % [w.pressure_text(), w.feeding_factor()], w.pressure_trend > 1.5 and w.feeding_factor() < 1.0)
	w.queue_free()
	_check_bites()
	_check_parsing()
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)


func _advance(w: Weather, minutes: int) -> void:
	w.sky = null # yksi _process-sekunti = yksi peliminuutti, kun delta = 60
	for i in minutes:
		w._process(60.0)


## Sama uistin samoissa kohdissa: laskevassa paineessa iskuja tulee enemmän
func _check_bites() -> void:
	var pop: FishPopulation = main.population
	var lure: Dictionary = Lures.LIST[0] # lusikka
	var counts := []
	for factor in [1.5, 0.75]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var n := 0
		for f in pop.fish:
			f["wary"] = 0.0
			f["hunger"] = 1.0
		for i in 4000:
			var f: Dictionary = pop.fish[rng.randi() % pop.fish.size()]
			if pop.check_lure(f["pos"], f["depth"], 0.8, 0.0, lure, 10.0, 3.0, 0.5, 0.3, factor) >= 0:
				n += 1
		counts.append(n)
	_check("laskevassa paineessa iskuja enemmän kuin korkeapaineessa (%d / %d)" % counts, counts[0] > counts[1] * 1.3)


func _check_parsing() -> void:
	var xml := ""
	for row in [["06:00", "p_sea", "1015.0"], ["07:30", "p_sea", "1012.0"], ["09:00", "t2m", "6.7"], ["09:00", "ws_10min", "2.5"],
			["09:00", "wd_10min", "25.0"], ["09:00", "p_sea", "1009.0"]]:
		xml += "<BsWfs:Time>2026-10-18T%s:00Z</BsWfs:Time>\n<BsWfs:ParameterName>%s</BsWfs:ParameterName>\n<BsWfs:ParameterValue>%s</BsWfs:ParameterValue>\n" % row
	var d := RealWeather.parse_fmi(xml)
	_check("FMI: ilmanpaine 1009 hPa, laskenut 6 hPa kolmessa tunnissa (%.1f, %.1f)" % [d.get("pressure", 0.0), d.get("pressure_trend", 0.0)],
		is_equal_approx(d.get("pressure", 0.0), 1009.0) and is_equal_approx(d.get("pressure_trend", 0.0), -6.0))
	var om := RealWeather.parse_open_meteo('{"current":{"time":"2026-10-18T11:45","temperature_2m":2.9,"precipitation":0.0,"snowfall":0.0,"cloud_cover":15,"wind_speed_10m":1.7,"wind_direction_10m":24,"wind_gusts_10m":4.2,"weather_code":0,"pressure_msl":1003.2},"hourly":{"pressure_msl":[1006.0,1005.0,1004.0,1003.2]}}')
	_check("Open-Meteo: ilmanpaine ja muutos (%.1f, %.1f)" % [om.get("pressure", 0.0), om.get("pressure_trend", 0.0)], is_equal_approx(om.get("pressure", 0.0), 1003.2) and absf(om.get("pressure_trend", 0.0) + 2.8) < 0.01)
	var w := Weather.new()
	w.apply_real({"source": "x", "time": "", "temperature": 1.0, "wind_speed": 3.0, "wind_gust": 5.0, "wind_from_deg": 0.0, "cloud": 0.2, "precipitation": 0.0, "snow": false, "pressure": 1009.0, "pressure_trend": -6.0}, true)
	_check("todellinen sää: paine käyttöön (kerroin %.2f)" % w.feeding_factor(), w.pressure == 1009.0 and w.feeding_factor() > 1.4)
	w.free()

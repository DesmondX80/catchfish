extends Node
## Aaltojen ja tuulen äänten testi: godot --headless --fixed-fps 30 -- --day=180 --wavesoundtest
## Tyynellä kuuluu liplatus, tuulen voimistuessa aallokon loiske voimistuu ja
## liplatus hiljenee. Heikko tuuli kuuluu, kun ei ole tyyntä, ja vaihtuu kovalla
## tuulella kovan tuulen ääneksi. Talvella (--day=40) tuuliäänet ovat talven omat.

var main: Node
var _log: Array[String] = []
var _step := 0
var _t := 0.0
var _levels := {}


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _ready() -> void:
	main = get_parent()


func _process(delta: float) -> void:
	_t += delta
	var audio: GameAudio = main.audio
	main.boat.velocity = Vector2.ZERO
	if _t < 0.3:
		return
	if main.boat.on_ice:
		_check("talvi: talven tuuliäänet", audio._wind_light.stream == audio._streams["wind_light_winter_loop"] and audio._wind_strong.stream == audio._streams["wind_strong_winter_loop"])
		_finish()
		return
	var strength: float = [0.0, 0.5, 1.0][_step]
	main.weather.wind_base = strength * 8.0 # aallokko seuraa tuulta (main.gd)
	main._wave_strength = strength
	if _t > 0.6:
		_levels[strength] = [audio._lap.volume_db, audio._waves.volume_db, audio._wind_light.volume_db, audio._wind_strong.volume_db, main.weather.speed()]
		_step += 1
		_t = 0.0
		if _step == 3:
			for k in _levels:
				print("aallokko %.1f: liplatus %.1f dB, aallot %.1f dB, tuuli %.1f m/s: heikko %.1f dB, kova %.1f dB" % [k, _levels[k][0], _levels[k][1], _levels[k][4], _levels[k][2], _levels[k][3]])
			_check("tyynellä liplatus kuuluu, aallokko ei", _levels[0.0][0] > -20.0 and _levels[0.0][1] < -60.0)
			_check("tuulen voimistuessa aallot voimistuvat", _levels[1.0][1] > _levels[0.5][1] and _levels[0.5][1] > _levels[0.0][1])
			_check("kovalla tuulella aallot peittävät liplatuksen", _levels[1.0][1] > _levels[1.0][0] + 6.0)
			_check("tyynellä tuuli on hiljaisempi kuin heikossa tuulessa", maxf(_levels[0.0][2], _levels[0.0][3]) < _levels[0.5][2] - 6.0)
			_check("heikko tuuli kuuluu, kova ei vielä", _levels[0.5][2] > -20.0 and _levels[0.5][3] < _levels[0.5][2] - 6.0)
			_check("kovalla tuulella kovan tuulen ääni", _levels[1.0][3] > -10.0 and _levels[1.0][2] < -40.0)
			_finish()


func _finish() -> void:
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

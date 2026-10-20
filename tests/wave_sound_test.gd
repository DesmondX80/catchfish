extends Node
## Aaltojen äänten testi: godot --headless --fixed-fps 30 -- --day=180 --wavesoundtest
## Tyynellä kuuluu liplatus, tuulen voimistuessa aallokon loiske voimistuu ja
## liplatus hiljenee. Jäällä vesi ei kuulu.

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
	var strength: float = [0.0, 0.5, 1.0][_step]
	main.weather.wind_base = strength * 8.0 # aallokko seuraa tuulta (main.gd)
	main._wave_strength = strength
	if _t > 0.6:
		_levels[strength] = [audio._lap.volume_db, audio._waves.volume_db]
		_step += 1
		_t = 0.0
		if _step == 3:
			for k in _levels:
				print("aallokko %.1f: liplatus %.1f dB, aallot %.1f dB" % [k, _levels[k][0], _levels[k][1]])
			_check("tyynellä liplatus kuuluu, aallokko ei", _levels[0.0][0] > -20.0 and _levels[0.0][1] < -60.0)
			_check("tuulen voimistuessa aallot voimistuvat", _levels[1.0][1] > _levels[0.5][1] and _levels[0.5][1] > _levels[0.0][1])
			_check("kovalla tuulella aallot peittävät liplatuksen", _levels[1.0][1] > _levels[1.0][0] + 6.0)
			for l in _log:
				print(l)
			get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

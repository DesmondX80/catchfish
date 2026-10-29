extends Node
## Äänilokin testi: godot --headless --fixed-fps 30 -- --day=180 --audio-log --audiologtest
## --audio-log kirjaa soitetut kertaäänet (pelin kello HH:MM:SS, nimi, etäisyys
## veneestä), soittamatta jääneet merkinnällä OHITETTU, repliikit, ennätyksen
## kilahduksen sekä silmukoiden käynnistyksen ja pysäytyksen.

var main: Node
var _log: Array[String] = []
var _step := 0
var _t := 0.0


func _ready() -> void:
	main = get_parent()
	main.weather.rain = 0.0
	main.birds.auto_spawn = false # taivaan linnut eivät sotke lokia
	main.audio._bird_timer = 9999.0 # eivät myöskään metsän pikkulinnut


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _next() -> void:
	_step += 1
	_t = 0.0


func _last() -> String:
	var lines: Array[String] = main.audio.log_lines
	return lines[-1] if not lines.is_empty() else ""


func _clock() -> String:
	var s := int(main.sky.minutes * 60.0) % (24 * 3600)
	return "%02d:%02d:%02d" % [s / 3600, s / 60 % 60, s % 60]


func _process(delta: float) -> void:
	_t += delta
	var audio: GameAudio = main.audio
	var at: Vector3 = main.boat.global_position
	match _step:
		0:
			if _t > 3.0: # alun repliikki ("No niin, kalaan.") on jo sanottu
				_check("lippu luettu", audio.log_enabled)
				audio.play_at("lure_splash", at + Vector3(10, 0, 0))
				var re := RegEx.create_from_string("^\\[ääni\\] \\d\\d:\\d\\d:\\d\\d lure_splash 10\\.0 m$")
				_check("kertaääni: \"%s\"" % _last(), re.search(_last()) != null)
				_check("kellonaika on pelin kello (%s)" % _clock(), _last().contains(" %s " % _clock()))
				audio.play_at("oar_stroke", at)
				_check("muunnelma ilman numeroa: \"%s\"" % _last(), _last().ends_with(" oar_stroke 0.0 m"))
				audio.play_at("ei_ole", at + Vector3(0, 0, 3))
				_check("tuntematon ääni: \"%s\"" % _last(), _last().ends_with(" ei_ole 3.0 m OHITETTU"))
				main.voice.say("lost", true)
				_check("repliikki: \"%s\"" % _last(), _last().contains(" voice:lost ") and _last().ends_with(" m"))
				var entry := Fishing.catch_entry("ahven", 0.3, "testi", main.sky.clock_text(), "")
				main.fishing.caught.emit(entry, true)
				_check("ennätyksen kilahdus: \"%s\"" % _last(), _last().ends_with(" record_chime -"))
				main.boat.motor_running = true
				_next()
		1:
			if _t > 0.2:
				_check("moottori käynnistyy: \"%s\"" % _last(), _last().ends_with(" loop_start motor_loop"))
				main.boat.motor_running = false
				_next()
		2:
			if _t > 0.2:
				_check("moottori sammuu: \"%s\"" % _last(), _last().ends_with(" loop_stop motor_loop"))
				audio.log_enabled = false
				var count := audio.log_lines.size()
				audio.play_at("lure_splash", at)
				_check("kirjaus pois: ei riviä", audio.log_lines.size() == count)
				for l in _log:
					print(l)
				get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

extends Node
## Kalastajan puheen testi: godot --headless --fixed-fps 30 -- --day=180 --voicetest
## Repliikit latautuvat, tapahtumasta kuuluu repliikki ja tekstitys, kalastaja
## pitää taukoa repliikkien välillä eikä toista samaa heti. Hiljainen jakso ja
## sateen alkaminen saavat oman repliikkinsä.

var main: Node
var _log: Array[String] = []
var _step := 0
var _t := 0.0


func _ready() -> void:
	main = get_parent()
	main.hud.set_paused_view(false)
	main.weather.rain = 0.0


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _next() -> void:
	_step += 1
	_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	var v: AnglerVoice = main.voice
	match _step:
		0:
			var missing := AnglerVoice.LINES.keys().filter(func(k): return v._streams[k] == null or v._streams[k].get_length() < 0.4)
			_check("kaikki %d repliikkiä latautuivat" % AnglerVoice.LINES.size(), missing.is_empty())
			_next()
		1:
			if _t > 3.5:
				_check("alussa: \"%s\"" % main.hud._speech.text, v.last_line == "start" and main.hud._speech.text.contains("kalaan"))
				_next()
		2:
			if _t > AnglerVoice.MIN_GAP:
				main.fishing.voice.emit("lost")
				_check("kala irtosi: repliikki kuuluu ja näkyy (%s)" % main.hud._speech.text, v.last_line == "lost" and v._player.playing)
				_check("heti perään ei puhuta uudelleen", not v.say("snap"))
				_next()
		3:
			if _t > AnglerVoice.MIN_GAP + 0.5:
				_check("samaa repliikkiä ei toisteta heti", not v.say("lost"))
				# Pitkä hiljainen jakso kalastaessa
				main.fishing._lure_vel = Vector3(0, 6, 0) # uistin lennossa hetken
				main.fishing.state = Fishing.State.FLYING
				v._quiet = AnglerVoice.QUIET_TIME
				_next()
		4:
			if _t > 0.2:
				_check("pitkään ilman tärppiä: \"%s\"" % main.hud._speech.text, v.last_line.begins_with("quiet"))
				_next()
		5:
			if _t > AnglerVoice.MIN_GAP + 0.5:
				main.weather.rain = 0.6
				_next()
		6:
			if _t > 0.2:
				_check("sade alkaa: \"%s\"" % main.hud._speech.text, v.last_line == "rain")
				# Lajin tunnistus huudetaan heti, vaikka edellisestä repliikistä on hetki
				main.fishing.voice.emit("fish_hauki")
				_check("lajin tunnistus huudetaan heti: \"%s\"" % main.hud._speech.text, v.last_line == "fish_hauki" and main.hud._speech.text.contains("Hauki!"))
				for l in _log:
					print(l)
				get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

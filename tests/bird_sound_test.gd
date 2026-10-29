extends Node
## Lintuäänten testi: godot --headless --fixed-fps 30 -- --day=180 --birdsoundtest
## Kuikka on poistettu eikä sitä soiteta millään kellonajalla. Pikkulintujen
## (peippo, talitiainen) laulujen väli arvotaan aina 8–15 s, myös aamulla, ja ne
## laulavat vain, kun valoisuus on yli 0,45 (CATCHFISH-88).
## Vuorokausi käydään läpi puolen tunnin askelin, kullakin kellonajalla 120 s
## simuloitua aikaa kutsumalla GameAudio._birds() suoraan.

const STEP := 0.5 # s
const SLOT_SECONDS := 120.0

var main: Node
var _log: Array[String] = []
var _done := false
var _new_players: Array[AudioStreamPlayer3D] = []


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _ready() -> void:
	main = get_parent()


func _process(_delta: float) -> void:
	if _done:
		return
	_done = true
	var audio: GameAudio = main.audio
	var sky: SkyTime = main.sky
	main.birds.auto_spawn = false # taivaan linnut eivät sotke tulosta
	sky.real_time = false
	sky.set_process(false)
	audio.set_process(false)
	main.boat.velocity = Vector2.ZERO

	_check("kuikka poissa: ONE_SHOTS, äänet, laskuri ja tiedosto",
		not GameAudio.ONE_SHOTS.has("bird_loon") and not audio._streams.has("bird_loon")
		and not ("_loon_timer" in audio) and not FileAccess.file_exists("res://assets/sounds/bird_loon.wav"))

	audio.child_entered_tree.connect(func(n: Node):
		if n is AudioStreamPlayer3D:
			_new_players.append(n))

	var paths: Array[String] = []
	var intervals_dawn: Array[float] = []
	var intervals_day: Array[float] = []
	var song_times: Array[float] = []
	var dark_songs := 0
	var noon_songs := 0
	var dark_slots := 0
	var t := 0.0
	for slot in 48:
		var hour := slot * 0.5
		sky.minutes = hour * 60.0
		var light := sky.daylight() > 0.45
		if not light:
			dark_slots += 1
		var sim := 0.0
		while sim < SLOT_SECONDS:
			var before := audio._bird_timer
			audio._birds(STEP)
			sim += STEP
			t += STEP
			if audio._bird_timer > before:
				if hour >= 3.0 and hour <= 8.0:
					intervals_dawn.append(audio._bird_timer)
				else:
					intervals_day.append(audio._bird_timer)
			for p in _new_players:
				var path: String = p.stream.resource_path if p.stream else ""
				paths.append(path)
				if path.contains("bird_chaffinch") or path.contains("bird_great_tit"):
					song_times.append(t)
					if not light:
						dark_songs += 1
					if hour == 12.0:
						noon_songs += 1
				audio.remove_child(p)
				p.free()
			_new_players.clear()

	var loons := paths.filter(func(p: String): return p.contains("loon"))
	print("soittoja %d, pikkulintujen lauluja %d, pimeitä puolituntisia %d" % [paths.size(), song_times.size(), dark_slots])
	_check("kuikkaa ei soiteta vuorokauden aikana (%d soittoa)" % paths.size(), loons.is_empty())

	var all := intervals_dawn + intervals_day
	var lo := 999.0
	var hi := 0.0
	for v in all:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	print("välejä aamulla %d, muulloin %d, pienin %.2f s, suurin %.2f s" % [intervals_dawn.size(), intervals_day.size(), lo, hi])
	_check("välit 8–15 s (aamu ja päivä)", not intervals_dawn.is_empty() and not intervals_day.is_empty()
		and all.all(func(v: float): return v >= 8.0 and v <= 15.0))
	var min_gap := INF
	for i in range(1, song_times.size()):
		min_gap = minf(min_gap, song_times[i] - song_times[i - 1])
	print("pienin väli kahden laulun välillä %.2f s" % min_gap)
	_check("kahden laulun väli vähintään 8 s", song_times.size() >= 2 and min_gap >= 8.0 - 0.001)

	_check("pikkulinnut vain valoisalla (pimeällä %d laulua, klo 12 %d laulua)" % [dark_songs, noon_songs],
		dark_songs == 0 and noon_songs >= 1)

	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

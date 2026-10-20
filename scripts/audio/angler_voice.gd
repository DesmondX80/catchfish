class_name AnglerVoice
extends Node
## Kalastajan puhe: lyhyitä repliikkejä pelin tapahtumiin ("No nyt tärppäs!").
## Äänet tehdään työkalulla tools/make_voice.py (samat tunnisteet), ja
## repliikki näkyy myös tekstityksenä. Kalastaja ei puhu taukoamatta: repliikkien
## välillä on tauko, eikä samaa repliikkiä toisteta heti.

const DIR := "res://assets/sounds/voice/"
## Repliikit: tunniste -> teksti (sama kuin tools/make_voice.py)
const LINES := {
	"start": "No niin, kalaan.",
	"bite_1": "No nyt tärppäs!",
	"bite_2": "Nyt nykäsi!",
	"hooked": "Kala kiinni!",
	"lost": "Ei perhana, se pääsi irti!",
	"snap": "Voi hemmetti, siima poikki!",
	"snag": "Ei kai taas pohjassa...",
	"shore": "Ei sinne pitänyt heittää.",
	"quiet_1": "Ei perhana tule mitään.",
	"quiet_2": "Onkohan tässä järvessä kaloja ollenkaan?",
	"big": "Onpa järkäle!",
	"small": "Pikkuinen, mutta kala kuitenkin.",
	"landed": "Siinä se on!",
	"rain": "Alkaa sataa. Pitäisköhän lähteä kotiin?",
	"hole": "Reikä valmis. Nyt pilkille.",
	"fish_hauki": "Hauki!",
	"fish_ahven": "Ahven!",
	"fish_sarki": "Särki!",
	"fish_kiiski": "Kiiski!",
	"fish_lahna": "Lahna!",
	"fish_made": "Made!",
}
## Tapahtuma -> [repliikit, todennäköisyys]
const EVENTS := {
	"start": [["start"], 1.0],
	"bite": [["bite_1", "bite_2"], 0.7],
	"hooked": [["hooked"], 0.4],
	"lost": [["lost"], 1.0],
	"snap": [["snap"], 1.0],
	"snag": [["snag"], 0.7],
	"shore": [["shore"], 0.7],
	"quiet": [["quiet_1", "quiet_2"], 1.0],
	"big": [["big"], 1.0],
	"small": [["small"], 1.0],
	"landed": [["landed"], 0.8],
	"rain": [["rain"], 1.0],
	"hole": [["hole"], 0.8],
}
## Lajin tunnistus huudetaan aina: se ohittaa tauon ja toistonestot
const URGENT_PREFIX := "fish_"
const MIN_GAP := 6.0 # s repliikkien välillä
const REPEAT_GAP := 60.0 # s ennen kuin sama repliikki toistuu
const QUIET_TIME := 240.0 # s kalastusta ilman tärppiä -> "Ei perhana tule mitään"

var boat: Boat
var fishing: Fishing
var weather: Weather
var hud: Hud
var last_line := ""
var _player: AudioStreamPlayer3D
var _streams := {}
var _since_line := 99.0
var _last_said := {} # repliikki -> aika
var _time := 0.0
var _quiet := 0.0
var _raining := false
var _rng := RandomNumberGenerator.new()


func setup(boat_node: Boat, fishing_node: Fishing, weather_node: Weather, hud_node: Hud) -> void:
	boat = boat_node
	fishing = fishing_node
	weather = weather_node
	hud = hud_node
	_rng.randomize()
	for key in LINES:
		_streams[key] = load(DIR + key + ".wav")
	_player = AudioStreamPlayer3D.new()
	_player.unit_size = 6.0
	_player.volume_db = -2.0
	boat.angler.add_child(_player)
	_player.position = Vector3(0, 0.9, 0) # pään korkeudella
	fishing.voice.connect(func(event): say(event, event.begins_with(URGENT_PREFIX)))
	_raining = weather.rain > 0.3
	get_tree().create_timer(2.5).timeout.connect(func(): say("start"))


## Sanoo tapahtumaan sopivan repliikin, jos edellisestä on kulunut tarpeeksi aikaa
func say(event: String, urgent := false) -> bool:
	if event == "bite":
		_quiet = 0.0
	var key := ""
	if urgent:
		if not LINES.has(event):
			return false
		key = event # keskeyttää mahdollisen edellisen repliikin
	else:
		if not EVENTS.has(event) or _since_line < MIN_GAP:
			return false
		var options: Array = EVENTS[event][0].filter(func(k): return _time - _last_said.get(k, -999.0) > REPEAT_GAP)
		if options.is_empty() or _rng.randf() > EVENTS[event][1]:
			return false
		key = options[_rng.randi() % options.size()]
	_player.stream = _streams[key]
	_player.play()
	hud.show_speech(LINES[key])
	last_line = key
	_last_said[key] = _time
	_since_line = 0.0
	return true


func _process(delta: float) -> void:
	_time += delta
	_since_line += delta
	# Pitkä hiljainen jakso kalastaessa
	if fishing.state in [Fishing.State.RETRIEVING, Fishing.State.FLYING] or fishing.hands_free():
		_quiet += delta
		if _quiet > QUIET_TIME and say("quiet"):
			_quiet = 0.0
	# Sade alkaa
	var raining := weather.rain > 0.3
	if raining and not _raining:
		say("rain")
	_raining = raining

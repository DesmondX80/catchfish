class_name GameAudio
extends Node
## Pelin äänet: taustaäänet (tuuli, laineet, linnut), veneen ja kalastuksen
## jatkuvat äänet (moottori, kela, jarru) sekä kertaäänet 3D-ääninä oikeassa
## paikassa. Äänet syntetisoidaan työkalulla tools/make_sounds.py; moottorin, aaltojen
## ja tuulen äänet tehdään nauhoituksista (tools/make_recorded_sounds.py).

const DIR := "res://assets/sounds/"
const LOOPS := ["wind_light_loop", "wind_strong_loop", "wind_light_winter_loop", "wind_strong_winter_loop", "water_lap_loop", "water_waves_loop", "motor_loop", "reel_loop", "drag_loop", "rain_loop"]
const MAX_ONE_SHOTS := 24

## Kertaäänet: [voimakkuus dB, unit_size (m), sävelkorkeuden satunnaisuus]
const ONE_SHOTS := {
	"motor_start": [-7.0, 18.0, 0.03],
	"motor_stop": [-9.0, 18.0, 0.03],
	"oar_catch": [-8.0, 6.0, 0.12],
	"oar_drip": [-14.0, 4.0, 0.15],
	"boat_bump": [0.0, 10.0, 0.08],
	"anchor_drop": [-3.0, 8.0, 0.05],
	"anchor_up": [-6.0, 6.0, 0.05],
	"cast_swish": [-6.0, 5.0, 0.1],
	"lure_splash": [-4.0, 12.0, 0.15],
	"bite_tick": [-8.0, 3.0, 0.05],
	"fish_splash": [0.0, 14.0, 0.15],
	"line_snap": [-2.0, 5.0, 0.05],
	"net_landing": [-2.0, 8.0, 0.08],
	"ice_drill": [-4.0, 8.0, 0.04],
	"snow_step": [-14.0, 4.0, 0.15],
	"bird_chaffinch": [-6.0, 30.0, 0.06],
	"bird_great_tit": [-6.0, 30.0, 0.06],
	"bird_loon": [-2.0, 160.0, 0.04],
}

var boat: Boat
var fishing: Fishing
var weather: Weather
var sky: SkyTime
var lake: LakeData

var _streams := {}
var _wind_light: AudioStreamPlayer # heikko tuuli
var _wind_strong: AudioStreamPlayer # kova tuuli
var _winter := false # talven tuuliäänet käytössä
var _rain: AudioStreamPlayer
var _lap: AudioStreamPlayer3D # tyyni liplatus
var _waves: AudioStreamPlayer3D # tuulinen aallokko
var _motor: AudioStreamPlayer3D
var _reel: AudioStreamPlayer3D
var _drag: AudioStreamPlayer3D
var _chime: AudioStreamPlayer
var _bird_timer := 4.0
var _loon_timer := 20.0
var _rng := RandomNumberGenerator.new()


func setup(boat_node: Boat, fishing_node: Fishing, weather_node: Weather, sky_time: SkyTime, lake_data: LakeData) -> void:
	boat = boat_node
	fishing = fishing_node
	weather = weather_node
	sky = sky_time
	lake = lake_data
	_rng.randomize()
	# Rajoitin päämikserissä estää säröytymisen, kun moni ääni soi yhtä aikaa
	# (vain kerran: peli voidaan käynnistää uudelleen kotoa)
	var has_limiter := false
	for i in AudioServer.get_bus_effect_count(0):
		has_limiter = has_limiter or AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter
	if not has_limiter:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(0, limiter)
	for name in LOOPS + ONE_SHOTS.keys() + ["record_chime"]:
		var stream: AudioStreamWAV = load(DIR + name + ".wav")
		if name in LOOPS:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
		_streams[name] = stream

	_wind_light = AudioStreamPlayer.new()
	_wind_light.stream = _streams["wind_light_loop"]
	add_child(_wind_light)
	_wind_light.play()
	_wind_strong = AudioStreamPlayer.new()
	_wind_strong.stream = _streams["wind_strong_loop"]
	add_child(_wind_strong)
	_wind_strong.play()

	_rain = AudioStreamPlayer.new()
	_rain.stream = _streams["rain_loop"]
	_rain.volume_db = -80.0
	add_child(_rain)

	_lap = _attached_loop("water_lap_loop", 6.0)
	_lap.play()
	_waves = _attached_loop("water_waves_loop", 8.0)
	_waves.play()
	_motor = _attached_loop("motor_loop", 20.0)
	_reel = _attached_loop("reel_loop", 3.0)
	_drag = _attached_loop("drag_loop", 4.0)

	_chime = AudioStreamPlayer.new()
	_chime.stream = _streams["record_chime"]
	_chime.volume_db = -6.0
	add_child(_chime)

	boat.sound_event.connect(play_at)
	fishing.sound_event.connect(play_at)
	fishing.caught.connect(func(_entry, record): if record: _chime.play())


## Veneen mukana kulkeva silmukka
func _attached_loop(name: String, unit_size: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[name]
	p.unit_size = unit_size
	p.volume_db = -80.0
	boat.add_child(p)
	return p


## Kertaääni maailman pisteessä
func play_at(sound: String, at: Vector3) -> void:
	if not _streams.has(sound) or get_child_count() > MAX_ONE_SHOTS + 3:
		return
	var cfg: Array = ONE_SHOTS.get(sound, [0.0, 10.0, 0.05])
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[sound]
	p.volume_db = cfg[0]
	p.unit_size = cfg[1]
	p.max_distance = cfg[1] * 40.0
	p.pitch_scale = 1.0 + _rng.randf_range(-cfg[2], cfg[2])
	add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()


func _process(delta: float) -> void:
	if boat == null:
		return
	# Tuuli: tyynellä hiljaista, heikossa tuulessa heikon tuulen ääni, joka
	# vaihtuu 4–8 m/s tuulessa kovan tuulen ääneksi. Vaihto seuraa tuulen
	# perusvoimakkuutta, jottei puuska tuo kovan tuulen kahinaa esiin; puuskat
	# kuuluvat voimistuvana äänenä.
	# Talvella (järvi jäässä) omat talvituulen äänet.
	if boat.on_ice != _winter:
		_winter = boat.on_ice
		_wind_light.stream = _streams["wind_light_winter_loop" if _winter else "wind_light_loop"]
		_wind_strong.stream = _streams["wind_strong_winter_loop" if _winter else "wind_strong_loop"]
		_wind_light.play()
		_wind_strong.play()
	var wind := weather.speed()
	var level := clampf(0.08 + wind / 10.0, 0.0, 1.1)
	var strong := smoothstep(4.0, 8.0, weather.wind_base)
	var light := level * smoothstep(0.3, 1.5, wind) * (1.0 - strong)
	_wind_light.volume_db = linear_to_db(maxf(light, 0.0001)) - 4.0
	_wind_strong.volume_db = linear_to_db(maxf(level * strong, 0.0001)) - 4.0
	_wind_strong.pitch_scale = 0.95 + clampf((wind - 6.0) / 40.0, 0.0, 0.1)

	# Sade: voimakkuuden mukaan
	if weather.rain > 0.02:
		if not _rain.playing:
			_rain.play()
		_rain.volume_db = linear_to_db(clampf(weather.rain, 0.05, 1.0)) - 3.0
	elif _rain.playing:
		_rain.stop()

	# Vesi veneen kyljessä: tyynellä pientä liplatusta, tuulen voimistuessa
	# aallot loiskivat ja pärskyvät. Liikkuva vene voimistaa molempia.
	var speed := boat.velocity.length()
	var s := Waves.strength
	var lap := clampf(0.35 + speed * 0.08, 0.0, 0.8) * (1.0 - 0.75 * s)
	var waves := clampf(s * 1.15 - 0.1, 0.0, 1.0) * (1.0 + speed * 0.05)
	if boat.on_ice:
		lap = 0.0
		waves = 0.0
	_lap.volume_db = linear_to_db(maxf(lap, 0.0001)) - 6.0
	_waves.volume_db = linear_to_db(maxf(waves, 0.0001)) - 4.0

	# Moottori: kierrokset kaasun mukaan (nauhoitus on täydeltä kaasulta, sytytystaajuus
	# noin 49 Hz; tyhjäkäynnillä noin 30 Hz), käynnistyksen jälkeen pehmeä aloitus
	if boat.motor_running:
		if not _motor.playing:
			_motor.volume_db = -30.0
			_motor.play()
		var rpm := absf(boat.throttle)
		_motor.pitch_scale = lerpf(_motor.pitch_scale, 0.6 + rpm * 0.4, minf(1.0, delta * 3.0))
		_motor.volume_db = move_toward(_motor.volume_db, -12.0 + rpm * 5.0, delta * 40.0)
	elif _motor.playing:
		_motor.stop()

	# Kela ja jarru
	_set_loop(_reel, fishing.is_reeling(), -10.0, fishing.reel_speed() / Fishing.REEL_SPEED)
	_set_loop(_drag, fishing.drag_screaming(), -4.0, 1.0 + clampf(fishing.tension / 6.0, 0.0, 0.5))

	_birds(delta)


func _set_loop(player: AudioStreamPlayer3D, on: bool, volume_db: float, pitch: float) -> void:
	if on:
		player.pitch_scale = clampf(pitch, 0.3, 3.0)
		player.volume_db = volume_db
		if not player.playing:
			player.play()
	elif player.playing:
		player.stop()


## Pikkulinnut laulavat metsänreunassa päivällä, aamulla tiheämmin.
## Kuikka huutaa järvellä illalla ja yöllä.
func _birds(delta: float) -> void:
	var hour := sky.hour()
	_bird_timer -= delta
	if _bird_timer <= 0.0:
		var dawn := hour >= 3.0 and hour <= 8.0
		_bird_timer = _rng.randf_range(3.0, 8.0) if dawn else _rng.randf_range(6.0, 18.0)
		if sky.daylight() > 0.45:
			var spot := _shore_spot()
			if spot != Vector3.INF:
				play_at("bird_chaffinch" if _rng.randf() < 0.6 else "bird_great_tit", spot)
	_loon_timer -= delta
	if _loon_timer <= 0.0:
		_loon_timer = _rng.randf_range(35.0, 90.0)
		if hour >= 20.5 or hour <= 4.0:
			for attempt in 20:
				var p := boat.pos + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(150.0, 700.0)
				if lake.is_water(p.x, p.y):
					play_at("bird_loon", Vector3(p.x, 0.3, p.y))
					break


## Satunnainen kohta metsänreunassa 40–250 m päässä veneestä
func _shore_spot() -> Vector3:
	var dir := Vector2.from_angle(_rng.randf() * TAU)
	for d in range(40, 250, 8):
		var p := boat.pos + dir * d
		if not lake.is_water(p.x, p.y):
			return Vector3(p.x, lake.height_at(p.x, p.y) + 6.0, p.y)
	return Vector3.INF

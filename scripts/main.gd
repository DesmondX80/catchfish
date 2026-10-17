extends Node3D
## Kokoaa pelin: järvi, ympäristö, vene, kamera, kalat, virveli ja käyttöliittymä.

const LAKE_DIR := "res://assets/lake"

var lake: LakeData
var world: LakeWorld
var sky: SkyTime
var weather: Weather
var boat: Boat
var camera_rig: CameraRig
var population: FishPopulation
var fishing: Fishing
var fish_visuals: FishVisuals
var hud: Hud
var audio: GameAudio
var load_ms := 0


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	lake = LakeData.load_from(LAKE_DIR)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_res := Sky.new()
	sky_res.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky_res
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.0006
	env.fog_aerial_perspective = 0.4
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)

	weather = Weather.new()
	add_child(weather)
	sky = SkyTime.new()
	add_child(sky)
	sky.setup(sun, env)

	world = LakeWorld.new()
	add_child(world)
	world.build(lake)

	boat = Boat.new()
	add_child(boat)
	boat.setup(lake, weather)

	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.setup(boat, lake)

	population = FishPopulation.new()
	add_child(population)
	population.setup(lake)

	fishing = Fishing.new()
	add_child(fishing)
	fishing.setup(boat, camera_rig, lake, population, weather, sky)

	fish_visuals = FishVisuals.new()
	add_child(fish_visuals)
	fish_visuals.setup(population, boat, fishing, lake)

	hud = Hud.new()
	add_child(hud)
	hud.setup(boat, fishing, weather, sky, lake, population)
	hud.show_message("Tervetuloa: %s" % lake.name)

	audio = GameAudio.new()
	add_child(audio)
	audio.setup(boat, fishing, weather, sky, lake)

	load_ms = Time.get_ticks_msec() - t0

	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--"):
			CatchLog.persist = false # testiajo: ei kirjoiteta pelaajan saaliskirjaan
	if "--autotest" in args:
		add_child(load("res://tests/autotest.gd").new())
	elif "--flicker" in args:
		add_child(load("res://tests/flicker.gd").new())
	elif "--inputtest" in args:
		add_child(load("res://tests/input_test.gd").new())
	elif "--perftest" in args:
		add_child(load("res://tests/perf.gd").new())
	else:
		for arg in args:
			if arg.begins_with("--screenshots="):
				add_child(load("res://tests/screenshots.gd").new())
			elif arg.begins_with("--audio-preview="):
				add_child(load("res://tests/audio_preview.gd").new())


func _input(event: InputEvent) -> void:
	# Ensimmäinen klikkaus vain kaappaa hiiren, ei heitä
	if event is InputEventMouseButton and event.pressed and not GameInput.active():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		hud.set_paused_view(false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.set_paused_view(true)
	elif event.is_action_pressed("mute"):
		var bus := AudioServer.get_bus_index("Master")
		AudioServer.set_bus_mute(bus, not AudioServer.is_bus_mute(bus))
		hud.show_message("Äänet pois" if AudioServer.is_bus_mute(bus) else "Äänet päällä")
	elif event.is_action_pressed("time_speed"):
		sky.cycle_time_scale()
		hud.show_message("Ajan nopeus x%d" % int(sky.time_scale()))


var _wave_strength := -1.0


func _process(delta: float) -> void:
	# Aallokko seuraa tuulen perusvoimakkuutta hitaasti (ei puuskia). Aaltojen
	# suunta asetetaan kerran: suunnan muuttaminen kesken siirtäisi aaltoja
	# kaukana veneestä holtittomasti.
	var target := clampf(weather.wind_base / 8.0, 0.0, 1.0)
	if _wave_strength < 0.0:
		_wave_strength = target
		Waves.angle = weather.wind_direction
	_wave_strength = move_toward(_wave_strength, target, delta * 0.02)
	Waves.strength = _wave_strength
	Waves.time = fmod(Waves.time + delta, 3600.0)
	Waves.apply(world.water_material)
	Waves.apply(boat.wake.material)
	boat.wake.material.set_shader_parameter("light", sky.daylight())
	world.water_material.set_shader_parameter("sky_color", sky.sky_material.sky_horizon_color)

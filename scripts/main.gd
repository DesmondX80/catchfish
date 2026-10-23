class_name Main
extends Node3D
## Aloitusvalikko ja pelin kokoaminen: järvi, ympäristö, vene, kamera, kalat,
## virveli ja käyttöliittymä rakennetaan, kun aloituspaikka on valittu.

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
## "Mene kotiin": pää-scene ladataan uudelleen ja se aukeaa alkuvalikkoon
static var return_to_menu := false
## Uramoodin reissulta kotiin: valikko aukeaa uran kotinäkymään
static var return_to_career := false

var menu: StartMenu
var pause_menu: PauseMenu
var running := false # peli käynnissä (valikko ohitettu)
var load_ms := 0


func _ready() -> void:
	lake = LakeData.load_from(LAKE_DIR)
	if return_to_menu:
		return_to_menu = false
		_show_menu()
		if return_to_career:
			return_to_career = false
			menu.open_career()
		return
	var args := OS.get_cmdline_user_args()
	for arg in args:
		var menu_tests := {"--menutest=": "menu_test", "--settingstest=": "settings_test", "--timepicktest=": "time_pick_test", "--careertest=": "career_test", "--tvtest=": "tv_test"}
		for prefix in menu_tests:
			if arg.begins_with(prefix):
				CatchLog.persist = false
				_show_menu()
				add_child(load("res://tests/%s.gd" % menu_tests[prefix]).new())
				return
		if arg.begins_with("--"):
			CatchLog.persist = false # testiajo: ei kirjoiteta pelaajan saaliskirjaan
			_start_game(0) # testit ohittavat valikon
			return
	_show_menu()


func _show_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu = StartMenu.new()
	add_child(menu)
	menu.setup(lake)
	menu.start_selected.connect(_on_start_selected)


func _on_start_selected(index: int) -> void:
	menu.show_loading(lake.starts[index]["name"])
	# Annetaan latausviestin piirtyä ennen raskasta järven rakentamista
	await get_tree().process_frame
	await get_tree().process_frame
	var career := menu.career_mode
	menu.queue_free()
	menu = null
	_start_game(index, career)


## Kalareissun saalis saavissa (uramoodissa viedään kotiin säilöön)
var trip_catch: Array = []
var tub: CatchTub
var voice: AnglerVoice
var birds: Birds
var tackle_box: TackleBox


func _start_game(start_index: int, career := false) -> void:
	Career.active = career
	var t0 := Time.get_ticks_msec()
	lake.select_start(start_index)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_res := Sky.new()
	var sky_shader := ShaderMaterial.new()
	sky_shader.shader = load("res://shaders/sky.gdshader")
	sky_res.sky_material = sky_shader
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
	sun.directional_shadow_max_distance = 60.0 # lähempänä tarkemmat varjot
	sun.shadow_blur = 1.5
	add_child(sun)

	weather = Weather.new()
	add_child(weather)
	sky = SkyTime.new()
	add_child(sky)
	sky.setup(sun, env, weather)
	weather.sky = sky
	if career:
		# Uran kello ja päivä: vuodenaika etenee päivien mukana
		sky.day_of_year = Career.day_of_year()
		sky.minutes = Career.minutes
		Career.trip_start = Career.minutes
	elif Settings.real_world:
		_use_real_world()
	else:
		# Itse valittu vuodenaika ja kellonaika (aloituspaikan valinnassa)
		sky.day_of_year = Settings.season_day()
		sky.minutes = Settings.start_hour() * 60.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--day="):
			sky.day_of_year = int(arg.split("=")[1]) # testi: vuodenaika päivän mukaan
	var season := current_season()

	world = LakeWorld.new()
	add_child(world)
	world.build(lake, season)

	boat = Boat.new()
	add_child(boat)
	boat.setup(lake, weather)

	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.setup(boat, lake)

	var rain := Rain.new()
	add_child(rain)
	rain.setup(weather, camera_rig.camera)

	population = FishPopulation.new()
	add_child(population)
	population.winter = season.frozen()
	population.day = sky.day_of_year
	population.setup(lake)

	fishing = Fishing.new()
	add_child(fishing)
	fishing.setup(boat, camera_rig, lake, population, weather, sky)
	boat.angler.setup(boat, fishing)
	fishing.caught.connect(func(entry, _record): trip_catch.append(entry))

	tub = CatchTub.new()
	add_child(tub)
	tub.setup(boat, fishing, trip_catch)
	camera_rig.tub = tub
	tackle_box = TackleBox.new()
	add_child(tackle_box)
	tackle_box.setup(boat, fishing)
	camera_rig.box = tackle_box
	tackle_box.opened.connect(func(): hud.set_paused_view(false))

	fish_visuals = FishVisuals.new()
	add_child(fish_visuals)
	fish_visuals.setup(fishing)

	# Talvi: järvi jäässä, kävellään ja pilkitään
	if season.frozen():
		boat.set_on_ice(true)
		fishing.set_on_ice(true)
		fish_visuals.visible = false # kalat eivät näy jään läpi
		if not weather.real_mode:
			weather.snow = true

	hud = Hud.new()
	add_child(hud)
	hud.setup(boat, fishing, weather, sky, lake, population)
	hud.show_message("Tervetuloa: %s – %s" % [lake.name, lake.starts[start_index]["name"]])
	if boat.on_ice:
		hud.show_message("Järvi on jäässä – pilkille! Kairaa reikä pitämällä vasenta hiirtä pohjassa")
	else:
		var welcome := "Tervetuloa: %s – %s" % [lake.name, lake.starts[start_index]["name"]]
		if season.name != "kesä":
			welcome += " (%s)" % season.name
		# Vuodenajan vihje: kutu, helle tai syysyönti
		var hint := Species.season_hint(sky.day_of_year)
		hud.show_message(welcome + ("\n" + hint if hint != "" else ""))

	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.setup(hud.help_text(false))
	pause_menu.resumed.connect(func(): hud.set_paused_view(false))
	if career:
		fishing.limited = true
		fishing.inventory = Career.lures # sama sanakirja: menetetyt uistimet vähenevät urasta
		fishing.lure_index = 0
		pause_menu.going_home.connect(func():
			Career.end_trip(trip_catch, sky.minutes - Career.trip_start)
			Main.return_to_career = true)

	audio = GameAudio.new()
	add_child(audio)
	audio.setup(boat, fishing, weather, sky, lake)
	voice = AnglerVoice.new()
	add_child(voice)
	voice.setup(boat, fishing, weather, hud)
	birds = Birds.new()
	add_child(birds)
	birds.setup(boat, camera_rig.camera, sky, weather, lake, season.frozen())
	birds.sound_event.connect(audio.play_at)
	birds.eagle_seen.connect(func(): voice.say("eagle", true))

	load_ms = Time.get_ticks_msec() - t0
	running = true

	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		add_child(load("res://tests/autotest.gd").new())
	elif "--flicker" in args:
		add_child(load("res://tests/flicker.gd").new())
	elif "--icetest" in args:
		add_child(load("res://tests/ice_test.gd").new())
	elif "--pausetest" in args:
		add_child(load("res://tests/pause_test.gd").new())
	elif "--inputtest" in args:
		add_child(load("res://tests/input_test.gd").new())
	elif "--perftest" in args:
		add_child(load("res://tests/perf.gd").new())
	elif "--luretest" in args:
		add_child(load("res://tests/lure_test.gd").new())
	elif "--trolltest" in args:
		add_child(load("res://tests/troll_test.gd").new())
	elif "--speciestest" in args:
		add_child(load("res://tests/species_test.gd").new())
	elif "--tubtest" in args:
		add_child(load("res://tests/tub_test.gd").new())
	elif "--casttest" in args:
		add_child(load("res://tests/cast_test.gd").new())
	elif "--voicetest" in args:
		add_child(load("res://tests/voice_test.gd").new())
	elif "--wavesoundtest" in args:
		add_child(load("res://tests/wave_sound_test.gd").new())
	elif "--baittest" in args:
		add_child(load("res://tests/bait_test.gd").new())
	elif "--docktest" in args:
		add_child(load("res://tests/dock_test.gd").new())
	elif "--anglertest" in args:
		add_child(load("res://tests/angler_test.gd").new())
	elif "--piketest" in args:
		add_child(load("res://tests/pike_follow_test.gd").new())
	elif "--sonartest" in args:
		add_child(load("res://tests/sonar_test.gd").new())
	elif "--boattest" in args:
		add_child(load("res://tests/boat_test.gd").new())
	elif "--overlaptest" in args:
		add_child(load("res://tests/overlap_test.gd").new())
	elif "--synctest" in args:
		add_child(load("res://tests/sync_test.gd").new())
	elif "--proptest" in args:
		add_child(load("res://tests/prop_test.gd").new())
	elif "--seasonfishtest" in args:
		add_child(load("res://tests/season_fish_test.gd").new())
	elif "--pressuretest" in args:
		add_child(load("res://tests/pressure_test.gd").new())
	elif "--anchortest" in args:
		add_child(load("res://tests/anchor_test.gd").new())
	elif "--headwindtest" in args:
		add_child(load("res://tests/headwind_test.gd").new())
	elif "--paddletest" in args:
		add_child(load("res://tests/paddle_test.gd").new())
	elif "--tackletest" in args:
		add_child(load("res://tests/tackle_test.gd").new())
	elif "--birdtest" in args:
		add_child(load("res://tests/bird_test.gd").new())
	elif "--fpvtest" in args:
		add_child(load("res://tests/fpv_test.gd").new())
	elif "--booktest" in args:
		add_child(load("res://tests/book_test.gd").new())
	else:
		for arg in args:
			if arg.begins_with("--seasonshot="):
				add_child(load("res://tests/season_shot.gd").new())
			if arg.begins_with("--screenshots="):
				add_child(load("res://tests/screenshots.gd").new())
			elif arg.begins_with("--anglershots="):
				add_child(load("res://tests/angler_shots.gd").new())
			elif arg.begins_with("--boatshots="):
				add_child(load("res://tests/boat_shots.gd").new())
			elif arg.begins_with("--fpvshots="):
				add_child(load("res://tests/fpv_shots.gd").new())
			elif arg.begins_with("--foamshots="):
				add_child(load("res://tests/foam_shots.gd").new())
			elif arg.begins_with("--shadowshots="):
				add_child(load("res://tests/shadow_shots.gd").new())
			elif arg.begins_with("--jittershots="):
				add_child(load("res://tests/jitter_shots.gd").new())
			elif arg.begins_with("--audio-preview="):
				add_child(load("res://tests/audio_preview.gd").new())


func _input(event: InputEvent) -> void:
	if not running:
		return # valikossa hiiri on vapaana
	if tackle_box.is_open:
		return # kalapakki käsittelee hiiren ja näppäimet itse
	# Ensimmäinen klikkaus vain kaappaa hiiren, ei heitä
	if event is InputEventMouseButton and event.pressed and not GameInput.active():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		hud.set_paused_view(false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		hud.set_paused_view(false)
		pause_menu.open()
	elif event.is_action_pressed("mute"):
		var bus := AudioServer.get_bus_index("Master")
		AudioServer.set_bus_mute(bus, not AudioServer.is_bus_mute(bus))
		hud.show_message("Äänet pois" if AudioServer.is_bus_mute(bus) else "Äänet päällä")
	elif event.is_action_pressed("camera_view"):
		camera_rig.toggle_first_person()
		hud.show_message("FPV-kamera" if camera_rig.first_person else "Kamera veneen takana")
	elif event.is_action_pressed("time_speed"):
		if sky.real_time:
			hud.show_message("Todellinen aika käytössä – ajan nopeutta ei voi muuttaa")
		else:
			sky.cycle_time_scale()
			hud.show_message("Ajan nopeus x%d" % int(sky.time_scale()))


## Vuodenaika: todellisessa ajassa päivämäärän mukaan, muuten kesäkuun puoliväli
func current_season() -> Season:
	return Season.from_day(sky.day_of_year)


## Todellinen kellonaika ja sää Saloisissa: kello tietokoneelta, sää havainnoista
## 10 minuutin välein. Ensimmäinen havainto asetetaan heti, myöhemmät vähitellen.
func _use_real_world() -> void:
	sky.real_time = true
	sky.sync_to_system_clock()
	var real := RealWeather.new()
	add_child(real)
	var first := [true]
	real.updated.connect(func(data):
		weather.apply_real(data, first[0])
		if first[0]:
			first[0] = false
			_wave_strength = -1.0 # aallokko heti tuulen mukaiseksi
			if hud:
				hud.show_message("Sää: %s (%s klo %s)" % [RealWeather.summary(data), data["source"], data["time"]]))
	real.failed.connect(func(msg):
		if hud:
			hud.show_message(msg + " – käytetään simuloitua säätä"))
	real.fetch()
	var timer := Timer.new()
	timer.wait_time = 600.0
	timer.autostart = true
	timer.timeout.connect(real.fetch)
	add_child(timer)


var _wave_strength := -1.0


func _process(delta: float) -> void:
	if not running:
		return
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
	# Veneen sisällä ei piirretä vettä eikä vanaa (jäällä ei venettä)
	world.water_material.set_shader_parameter("ice", 1.0 if boat.on_ice else 0.0)
	for mat in [world.water_material, boat.wake.material]:
		mat.set_shader_parameter("boat_pos", Vector2(1e6, 1e6) if boat.on_ice else boat.pos)
		mat.set_shader_parameter("boat_yaw", boat.yaw)
	boat.wake.material.set_shader_parameter("light", sky.daylight())
	world.water_material.set_shader_parameter("sky_color", sky.horizon_color)
	world.water_material.set_shader_parameter("rain", weather.rain)

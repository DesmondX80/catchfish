extends Node
## Lintujen testi: godot --headless --fixed-fps 30 -- --day=180 --birdtest
## Tarkistaa, että jokainen laji lentää nopeudellaan ja korkeudellaan, siivet
## liikkuvat, linnut ääntelevät lähellä ja katoavat kaukana, muuttolinnut ovat
## talvella poissa ja kalastaja huudahtaa nähdessään kotkan (vain kerran).
## Pelkät lähikuvat lajeista: godot --fixed-fps 30 -- --day=180 --birdtest --birdshots=KANSIO

var main: Node
var birds: Birds
var _log: Array[String] = []
var _dir := ""
var _sounds: Array = []


func _ready() -> void:
	main = get_parent()
	birds = main.birds
	birds.auto_spawn = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--birdshots="):
			_dir = arg.split("=")[1]
	birds.sound_event.connect(func(sound, at): _sounds.append([sound, at]))
	await _wait(1.0)
	_clear()
	if _dir != "": # kuvat ikkunassa ovat hitaita: vain kuvat
		await _shots()
		get_tree().quit()
		return
	_season_checks()
	await _flight_checks()
	await _eagle_checks()
	await _despawn_checks()
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _wait(seconds: float) -> void:
	for i in int(seconds * 30.0):
		await get_tree().process_frame


func _clear() -> void:
	for f in birds.flocks.duplicate():
		birds._remove(f)


func _season_checks() -> void:
	birds.winter = true
	var gone := ["sorsa", "hanhi", "lokki"].all(func(sp): return birds.species_weight(sp) == 0.0)
	var stay := ["varis", "korppi", "kotka"].all(func(sp): return birds.species_weight(sp) > 0.0)
	_check("talvella muuttolinnut poissa, varis, korppi ja kotka jäävät", gone and stay)
	var picks := {}
	for i in 300:
		picks[birds._pick_species()] = true
	_check("talvella arvotaan vain paikkalintuja: %s" % ", ".join(picks.keys()), not picks.has("sorsa") and not picks.has("hanhi") and not picks.has("lokki"))
	birds.winter = false
	birds.day = 120
	var spring := birds.species_weight("hanhi")
	birds.day = 180
	_check("hanhia enemmän muuttoaikaan (kevät %.1f, kesä %.1f)" % [spring, birds.species_weight("hanhi")], spring > birds.species_weight("hanhi"))
	_check("kotka harvinaisin", Birds.SPECIES.keys().all(func(sp): return sp == "kotka" or birds.species_weight(sp) > birds.species_weight("kotka")))


## Jokainen laji lentää veneen yli: nopeus, korkeus, siivet ja ääni
func _flight_checks() -> void:
	var boat_pos: Vector2 = main.boat.pos
	for sp in Birds.SPECIES:
		var d: Dictionary = Birds.SPECIES[sp]
		_sounds.clear()
		var start := Vector3(boat_pos.x - 60.0, 30.0, boat_pos.y)
		var f := birds.spawn(sp, false, start, Vector2.RIGHT)
		var n: int = f["birds"].size()
		var node: MeshInstance3D = f["birds"][0]["node"]
		var flaps := []
		for i in 60:
			await get_tree().process_frame
			flaps.append(node.get_instance_shader_parameter("flap"))
		var moved: float = f["pos"].x - start.x
		var expect: float = d["speed"] * 2.0
		_check("%s: parvi %d (%d–%d), lentää %.0f m / 2 s (odotus %.0f)" % [d["name"], n, d["flock"][0], d["flock"][1], moved, expect],
			n >= d["flock"][0] and n <= d["flock"][1] and absf(moved - expect) < expect * 0.1)
		var spread: float = flaps.max() - flaps.min()
		_check("%s: siivet liikkuvat (%.2f rad)" % [d["name"], spread], spread > 0.02)
		_check("%s: malli suunnattu lentosuuntaan" % d["name"], (-node.global_basis.z).normalized().dot(Vector3.RIGHT) > 0.95)
		f["call_timer"] = 0.0
		await get_tree().process_frame
		_check("%s: ääntelee lähellä (%s)" % [d["name"], _sounds.map(func(s): return s[0])], _sounds.any(func(s): return s[0] == "bird_" + sp))
		_check("%s: ääni on ladattu" % d["name"], main.audio._streams.has("bird_" + sp))
		_clear()
	# Satunnainen parvi syntyy kauas ja korkealle lajin korkeusvälille
	for sp in Birds.SPECIES:
		var f := birds.spawn(sp)
		var d: Dictionary = Birds.SPECIES[sp]
		var dist := Vector2(f["pos"].x - boat_pos.x, f["pos"].z - boat_pos.y).length()
		var alt: float = f["pos"].y
		_check("%s: alkaa %.0f m päästä %.0f m korkeudelta" % [d["name"], dist, alt], dist > 350.0 and alt >= d["altitude"][0] and alt <= d["altitude"][1])
	_clear()
	var c := birds.spawn("lokki", true)
	var r0 := Vector2(c["pos"].x, c["pos"].z).distance_to(c["center"])
	await _wait(2.0)
	var r1 := Vector2(c["pos"].x, c["pos"].z).distance_to(c["center"])
	_check("lokki kaartelee ympyrää (säde %.0f m -> %.0f m)" % [r0, r1], absf(r0 - r1) < 1.0)
	_clear()


## Kotka kameran edessä: kalastaja huudahtaa kerran
func _eagle_checks() -> void:
	var cam: Camera3D = main.camera_rig.camera
	var ahead := cam.global_position - cam.global_basis.z * 120.0
	ahead.y = maxf(ahead.y, 40.0)
	var behind := cam.global_position + cam.global_basis.z * 150.0
	behind.y = 60.0
	main.voice.last_line = ""
	var f := birds.spawn("kotka", false, behind, Vector2(-cam.global_basis.z.x, -cam.global_basis.z.z).normalized().rotated(PI))
	await _wait(1.0)
	_check("kameran takana oleva kotka ei saa huudahtamaan", main.voice.last_line != "eagle")
	_clear()
	birds.spawn("kotka", false, ahead, Vector2(cam.global_basis.x.x, cam.global_basis.x.z).normalized())
	await _wait(1.0)
	_check("kotka näkyvissä: \"%s\"" % main.voice.LINES.get(main.voice.last_line, ""), main.voice.last_line == "eagle")
	main.voice.last_line = ""
	await _wait(3.0)
	_check("samasta kotkasta huudahdetaan vain kerran", main.voice.last_line != "eagle")
	_clear()


func _despawn_checks() -> void:
	var boat_pos: Vector2 = main.boat.pos
	var f := birds.spawn("sorsa", false, Vector3(boat_pos.x + Birds.DESPAWN_DISTANCE - 5.0, 20.0, boat_pos.y), Vector2.RIGHT)
	f["age"] = 10.0
	var nodes: Array = f["birds"].map(func(b): return b["node"])
	await _wait(1.0)
	_check("kauas lentänyt parvi poistuu", birds.flocks.is_empty() and nodes.all(func(n): return not is_instance_valid(n) or n.is_queued_for_deletion()))
	birds.auto_spawn = true
	birds._spawn_timer = 0.0
	# Yö: juhannuksen aikaan Raahessa ei pimene, joten lokakuun yö
	var summer_day: int = main.sky.day_of_year
	main.sky.day_of_year = 300
	main.sky.minutes = 2.0 * 60.0
	for i in 20:
		birds._spawn_timer = 0.0
		await get_tree().process_frame
	_check("yöllä lintuja ei lennä (valoisuus %.2f)" % main.sky.daylight(), birds.flocks.is_empty())
	main.sky.day_of_year = summer_day
	birds.auto_spawn = false


## Lähikuvat: kukin laji kameran edessä räpyttelemässä
func _shots() -> void:
	main.sky.minutes = 12.0 * 60.0
	main.hud.visible = false
	var cam: Camera3D = main.camera_rig.camera
	main.camera_rig.set_process(false)
	for sp in Birds.SPECIES:
		_clear()
		var span: float = Birds.SPECIES[sp]["span"]
		var at := Vector3(main.boat.pos.x, 40.0, main.boat.pos.y)
		var f := birds.spawn(sp, false, at, Vector2.RIGHT)
		for b in f["birds"].slice(1):
			b["node"].queue_free()
		f["birds"] = f["birds"].slice(0, 1)
		cam.global_position = at + Vector3(span * 0.6, -span * 0.9, span * 1.6)
		for i in 12:
			await get_tree().process_frame
			cam.global_position = f["pos"] + Vector3(span * 0.6, -span * 0.9, span * 1.6)
			cam.look_at(f["pos"])
		get_viewport().get_texture().get_image().save_png(_dir.path_join("lintu_%s.png" % sp))
	_clear()

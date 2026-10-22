extends Node
## Vaahtopäiden kuvat ja tarkistus (vaatii ikkunan):
##   godot --fixed-fps 30 -- --day=180 --foamshots=/polku/kansioon
## Kuvat järvestä eri tuulilla. Tyynellä ja heikolla tuulella pinnassa ei ole
## vaahtoa, kovalla tuulella valkoisia pikseleitä on selvästi selällä, mutta
## ei rannan lähellä (vaahtopäät alkavat n. 200 m rannasta).

var _dir := ""
var _frame := 0
var _index := 0
var _white := {}
var _log: Array[String] = []
var main: Node
var _open := Vector2.ZERO # selkä: yli 350 m rannasta
var _near := Vector2.ZERO # alle 90 m rannasta
const SHOTS := [
	# nimi, aallokon voimakkuus (1 = 8 m/s), silmän korkeus, katseen etäisyys, rannassa
	["1-heikko", 0.3, 3.0, 14.0, false],
	["2-kohtalainen", 0.65, 3.0, 14.0, false],
	["3-kova", 1.0, 3.0, 14.0, false],
	["4-kova-kauas", 1.0, 2.0, 60.0, false],
	["5-kova-ylhaalta", 1.0, 12.0, 6.0, false],
	["6-kova-rannassa", 1.0, 3.0, 14.0, true],
]


func _ready() -> void:
	main = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--foamshots="):
			_dir = arg.split("=")[1]
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	main.hud.visible = false
	main.weather.set_kind(Weather.Kind.CLEAR, true)
	# Aallot kulkevat pohjoiseen, ja kamera katsoo niiden mukana poispäin
	# keskipäivän auringosta (ei häikäisyä). Kuvauspaikoista näkee pohjoiseen
	# vettä: selällä ainakin 100 m, rannassa 30 m.
	Waves.angle = 0.0
	seed(35) # samat paikat joka ajolla
	var lake: LakeData = main.lake
	var best_open := 0.0
	var best_near := 0.0
	for i in 20000:
		var p := Vector2(lake.origin_x, lake.origin_z) + Vector2(randf(), randf()) * lake.world_size()
		if not lake.is_water(p.x, p.y):
			continue
		var shore := lake.shore_distance(p.x, p.y)
		var open := 0.0
		while open < 100.0 and lake.depth_at(p.x, p.y - open) > 0.5:
			open += 5.0
		if shore > 350.0 and open > best_open:
			best_open = open
			_open = p
		if shore < 90.0 and lake.shore_distance(p.x, p.y - 30.0) < 90.0 and open > best_near:
			best_near = open
			_near = p
	print("selkä %.0f m rannasta, ranta %.0f m rannasta" % [lake.shore_distance(_open.x, _open.y), lake.shore_distance(_near.x, _near.y)])
	main.boat.pos = _open


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _process(_delta: float) -> void:
	if _index >= SHOTS.size():
		_check("heikolla tuulella ei vaahtoa", _white["1-heikko"] < 0.005)
		_check("kovalla tuulella vaahtopäitä", _white["3-kova"] > 0.004)
		_check("kova tuuli vaahtoaa enemmän kuin kohtalainen", _white["3-kova"] > _white["2-kohtalainen"])
		_check("rannan lähellä ei vaahtopäitä", _white["6-kova-rannassa"] < 0.005)
		for l in _log:
			print(l)
		get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)
		return
	_frame += 1
	main.sky.minutes = 12.0 * 60.0
	var shot: Array = SHOTS[_index]
	main.weather.wind_base = shot[1] * 8.0
	main._wave_strength = shot[1]
	var boat: Boat = main.boat
	boat.velocity = Vector2.ZERO
	# Katse tuulen alapuolelle, vene jää kuvan taakse
	Waves.angle = 0.0
	var from: Vector2 = _near if shot[4] else boat.pos
	var eye := Vector3(from.x, shot[2], from.y - 4.0)
	var at := Vector3(from.x, 0.0, from.y - 4.0 - shot[3])
	main.camera_rig.shot = Transform3D(Basis.looking_at(at - eye), eye)
	main.camera_rig.shot_view = true
	if _frame > 20:
		var img := get_viewport().get_texture().get_image()
		if _dir != "":
			img.save_png(_dir.path_join(shot[0] + ".png"))
		_white[shot[0]] = _white_fraction(img)
		print("kuva %s: vaahtoa %.2f %% kuvan alaosasta" % [shot[0], _white[shot[0]] * 100.0])
		_index += 1
		_frame = 0


## Valkoisten pikseleiden osuus kuvan alaosassa (vesi; taivas on yläosassa)
func _white_fraction(img: Image) -> float:
	var count := 0
	var total := 0
	for y in range(img.get_height() * 6 / 10, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			total += 1
			if c.v > 0.8 and c.s < 0.15:
				count += 1
	return float(count) / total

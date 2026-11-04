extends Node
## Lähiveden ja kaukaisen järviverkon sauman kuvat (CATCHFISH-120, vaatii ikkunan):
##   godot --fixed-fps 30 -- --day=180 --seamshots=/polku/kansioon [--waterquality=matala]
## (talvella --day=30: lumen peittämä jää)
## Kuvat selältä keskipäivällä: kamera 25 m korkeudella katsoo 100 m eteen ja
## 8 m korkeudella 40 m eteen 45° kulmassa, tuulella 0,5, 4 ja 8 m/s. Lopuksi
## kamera liikkuu 5 m/s, ja peräkkäiset ruudut tallennetaan (sauma ei saa
## välähtää ruudulta toiselle).
## Jokaisesta kuvasta tulostetaan mittari: saumaviivan pikseleiden kirkkautta
## verrataan viivan molemmin puolin oleviin pikseleihin, ja poikkeavien
## näytteiden osuus kerrotaan sekä saumalle että vertailuviivalle 100 m
## kohdalla (ei saumaa). Mittari on vain tulostus, ei läpäisyehto.

const PLACE := Vector2(-218.0, -1329.0) # selkä, vettä joka suuntaan yli 150 m
const SETTLE := 60 # ruutua ennen kuvaa (kameran siirtymä ja aallokko asettuvat)
const MOVE_SPEED := 5.0 # m/s: liikkuvan kameran nopeus
const MOVE_FRAMES := 4 # liikkuvasta kamerasta peräkkäisiä kuvia
const REF_RADIUS := 100.0 # vertailuviiva (m keskeltä)
const BAND := 1 # px: saumaviivan leveys molempiin suuntiin
const SIDE := 5 # px: vertailupikselit viivan molemmin puolin
const THRESHOLD := 0.03 # kirkkausero, jota suurempi on poikkeava
const SHOTS := [
	# nimi, tuuli (m/s), silmän korkeus, katseen etäisyys, suunta (°), liikkuuko
	["01-25m-100-tyyni", 0.5, 25.0, 100.0, 0.0, false],
	["02-8m-40-viisto-tyyni", 0.5, 8.0, 40.0, 45.0, false],
	["03-25m-100-4ms", 4.0, 25.0, 100.0, 0.0, false],
	["04-8m-40-viisto-4ms", 4.0, 8.0, 40.0, 45.0, false],
	["05-25m-100-8ms", 8.0, 25.0, 100.0, 0.0, false],
	["06-8m-40-viisto-8ms", 8.0, 8.0, 40.0, 45.0, false],
	["07-liikkuva-8m-tyyni", 0.5, 8.0, 40.0, 45.0, true],
]

var main: Node
var _dir := ""
var _frame := 0
var _index := 0


func _ready() -> void:
	main = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seamshots="):
			_dir = arg.split("=")[1]
	DirAccess.make_dir_recursive_absolute(_dir)
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	main.hud.visible = false
	main.weather.set_kind(Weather.Kind.CLEAR, true)
	main.boat.pos = PLACE + Vector2(5000.0, 0.0) # vene pois kuvasta
	print("veden laatu: %s, jäällä: %s" % [Settings.water_quality, main.boat.on_ice])


func _process(_delta: float) -> void:
	if _index >= SHOTS.size():
		get_tree().quit()
		return
	var shot: Array = SHOTS[_index]
	_frame += 1
	if _frame == 1:
		Waves.reset(shot[1], 0.0) # aallokko heti tuulen mukaiseksi
	_set_view(shot)
	var last := SETTLE + (MOVE_FRAMES - 1 if shot[5] else 0)
	if _frame < SETTLE:
		return
	var img := get_viewport().get_texture().get_image()
	var name: String = shot[0]
	if shot[5]:
		name += "-%d" % (_frame - SETTLE + 1)
	img.save_png(_dir.path_join(name + ".png"))
	var seam := _measure(img, _seam())
	var ref := _measure(img, REF_RADIUS)
	print("kuva %s: sauma %.1f m poikkeavia %.1f %% (%d näytettä), vertailu %.0f m %.1f %% (%d näytettä)" % [name, _seam(), seam.x * 100.0, seam.y, REF_RADIUS, ref.x * 100.0, ref.y])
	if _frame >= last:
		_index += 1
		_frame = 0


func _set_view(shot: Array) -> void:
	main.sky.minutes = 12.0 * 60.0
	var w: Weather = main.weather
	w.wind_base = shot[1]
	w._wind_target = shot[1]
	w.wind_direction = 0.0
	w.gust = 0.0
	w._gust_target = 0.0
	var yaw := deg_to_rad(shot[4])
	var fwd := Vector2(sin(yaw), -cos(yaw))
	var from := PLACE
	if shot[5]:
		# Liikkuva kamera: eteenpäin ja sivuun, jolloin lähivesi siirtyy askelin molemmilla akseleilla
		from += Vector2(1.0, -0.6).normalized() * MOVE_SPEED * _frame / 30.0
	var eye := Vector3(from.x, shot[2], from.y)
	var at2: Vector2 = from + fwd * float(shot[3])
	main.camera_rig.shot = Transform3D(Basis.looking_at(Vector3(at2.x, 0.0, at2.y) - eye), eye)
	main.camera_rig.shot_view = true


## Saumaraja: tästä etäisyydestä (max(|dx|, |dz|)) alkaen kaukainen järviverkko piirtää
func _seam() -> float:
	return Waves.near_seam()


## Neliön (lähiveden keskipiste, puolileveys r) reunaviivan poikkeavien näytteiden
## osuus (x) ja näytteiden määrä (y). Näyte on viivan pikseli, jonka kohdalla
## sekä viivan molemmilla puolilla on vettä; poikkeava, jos viivan kirkkaus
## eroaa sivupikseleiden keskiarvosta yli THRESHOLD.
func _measure(img: Image, r: float) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	var c: Vector2 = Waves.near_center
	var size := img.get_size()
	var seen := {}
	var bad := 0
	for side in 4:
		var axis := Vector2(1.0, 0.0) if side < 2 else Vector2(0.0, 1.0) # viivan suunta
		var normal := Vector2(axis.y, axis.x) * (1.0 if side % 2 == 0 else -1.0) # ulospäin
		var t := -r
		while t <= r:
			var p2 := c + normal * r + axis * t
			t += 0.25
			if not (main.lake.is_water(p2.x, p2.y) and main.lake.is_water(p2.x + normal.x * 4.0, p2.y + normal.y * 4.0) and main.lake.is_water(p2.x - normal.x * 4.0, p2.y - normal.y * 4.0)):
				continue
			var p := Vector3(p2.x, 0.0, p2.y)
			var q := p + Vector3(normal.x, 0.0, normal.y)
			if cam.is_position_behind(p) or cam.is_position_behind(q):
				continue
			var s := cam.unproject_position(p)
			var n := cam.unproject_position(q) - s
			if n.length() < 0.001:
				continue
			n = n.normalized()
			var px := Vector2i(s.round())
			if seen.has(px):
				continue
			var ok := true
			for k in [-SIDE, SIDE]:
				var e := Vector2i((s + n * k).round())
				if e.x < 0 or e.y < 0 or e.x >= size.x or e.y >= size.y:
					ok = false
			if not ok:
				continue
			seen[px] = true
			var ref := (img.get_pixelv(Vector2i((s - n * SIDE).round())).get_luminance() + img.get_pixelv(Vector2i((s + n * SIDE).round())).get_luminance()) * 0.5
			var dev := 0.0
			for k in range(-BAND, BAND + 1):
				dev = maxf(dev, absf(img.get_pixelv(Vector2i((s + n * k).round())).get_luminance() - ref))
			if dev > THRESHOLD:
				bad += 1
	return Vector2(float(bad) / maxf(seen.size(), 1.0), seen.size())

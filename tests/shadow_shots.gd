extends Node
## Veneen varjon kuvat ja tarkistus eri kellonaikoina (vaatii ikkunan):
##   godot --fixed-fps 30 -- --day=180 --shadowshots=/polku/kansioon
## Kamera katsoo venettä lähes suoraan ylhäältä, jottei runko peitä varjoa. Varjon pitää alkaa rungosta ja
## osoittaa poispäin auringosta – ei näkyä irrallisena läiskänä veneen vieressä.
## Aamulla ja illalla (aurinko matalalla) vesi heti rungon varjopuolella on
## selvästi (yli 12 %) tummempaa kuin aurinkoisella puolella, myös syvässä vedessä.

var _dir := ""
var _frame := 0
var _index := 0
var _log: Array[String] = []
var main: Node
const SHOTS := [
	# nimi, kellonaika (h), syvä vesi, tarkistetaanko varjo rungon vieressä
	["1-aamu-syva", 8.0, true, true],
	["2-keskipaiva-syva", 12.0, true, false],
	["3-ilta-syva", 19.0, true, true],
	["4-aamu-matala", 8.0, false, true],
	["5-keskipaiva-matala", 12.0, false, false],
	["6-ilta-matala", 19.0, false, true],
]


func _ready() -> void:
	main = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shadowshots="):
			_dir = arg.split("=")[1]
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	main.hud.visible = false
	main.weather.set_kind(Weather.Kind.CLEAR, true)
	main.weather.wind_base = 0.0


## Syvin tai matalin (vähintään 1,2 m) kohta aloituspaikan lähellä
func _spot(deep: bool) -> Vector2:
	var boat: Boat = main.boat
	var lake = main.lake
	var best := boat.pos
	var best_depth: float = lake.depth_at(best.x, best.y) if deep else 99.0
	seed(7)
	for i in 4000:
		var p := boat.pos + Vector2(randf_range(-400, 400), randf_range(-400, 400))
		var d: float = lake.depth_at(p.x, p.y)
		if deep and d > best_depth or not deep and d > 1.2 and d < best_depth:
			best = p
			best_depth = d
	return best


func _process(_delta: float) -> void:
	if _index >= SHOTS.size():
		for l in _log:
			print(l)
		get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)
		return
	_frame += 1
	var shot: Array = SHOTS[_index]
	var boat: Boat = main.boat
	if _frame == 1:
		boat.pos = _spot(shot[2])
		boat.velocity = Vector2.ZERO
	main.sky.minutes = shot[1] * 60.0
	var from: Vector3 = boat.global_position + Vector3(0.8, 10.0, 0.8)
	main.camera_rig.shot = Transform3D(Basis.looking_at(boat.global_position - from), from)
	main.camera_rig.shot_view = true
	if _frame > 40:
		var img := get_viewport().get_texture().get_image()
		if _dir != "":
			img.save_png(_dir.path_join(shot[0] + ".png"))
		if shot[3]:
			_check_shadow(shot[0], img)
		_index += 1
		_frame = 0


## Vertaa veden kirkkautta heti rungon ulkopuolella varjon suunnassa ja
## vastakkaisella puolella
func _check_shadow(name: String, img: Image) -> void:
	var boat: Boat = main.boat
	var light_dir: Vector3 = -main.sky.sun.global_basis.z
	var dir := Vector2(light_dir.x, light_dir.z).normalized()
	var hull := boat._outline(boat.pos, boat.yaw)
	var dark := _brightness(img, _just_outside(hull, boat.pos, dir))
	var lit := _brightness(img, _just_outside(hull, boat.pos, -dir))
	print("kuva %s: varjo %.3f, aurinkoinen puoli %.3f" % [name, dark, lit])
	_log.append("%s %s: varjo alkaa rungosta" % ["OK  " if dark < lit * 0.88 else "VIRHE", name])


## Ensimmäinen kohta 0,3 m rungon ulkopuolella suunnassa dir
func _just_outside(hull: PackedVector2Array, from: Vector2, dir: Vector2) -> Vector2:
	var p := from
	while Geometry2D.is_point_in_polygon(p, hull):
		p += dir * 0.05
	return p + dir * 0.3


## Keskimääräinen kirkkaus 9x9 pikselin alueelta vedenpinnan kohdasta p
func _brightness(img: Image, p: Vector2) -> float:
	var world := Vector3(p.x, main.boat.global_position.y, p.y)
	var px: Vector2 = get_viewport().get_camera_3d().unproject_position(world)
	var sum := 0.0
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var x := clampi(int(px.x) + dx, 0, img.get_width() - 1)
			var y := clampi(int(px.y) + dy, 0, img.get_height() - 1)
			sum += img.get_pixel(x, y).v
	return sum / 81.0

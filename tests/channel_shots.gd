extends Node
## Kodan ruopatun väylän kuvat designerin tarkistukseen (CATCHFISH-101, vaatii ikkunan):
##   godot --fixed-fps 30 -- --day=180 --channelshots=/polku/kansioon
## Keskipäivä, tyyni ja selkeä sää, jotta väylän tummempi pohja näkyy:
## 1) pelaajan vene laiturissa, kamera veneen takana väylää kohti, 2–5) väylän
## kaksi kapeaa kohtaa eteen ja taakse, 6) lampi, 7) väylän pää taaksepäin,
## 8) väylä ylhäältä laiturin edestä, 9) karttanäkymä, 10) kapea kohta ylhäältä,
## 13) vieras moottorivene kodan laiturissa kannen länsipuolella.

const SETTLE := 45 # ruutua ennen kuvaa
## nimi, keskilinjan kohta (x, z), katsotaanko väylän kulkusuuntaan (true) vai taaksepäin
const VIEWS := [
	["02-kapea1-eteen", Vector2(-1297.0, 887.0), true],
	["03-kapea1-taakse", Vector2(-1297.0, 887.0), false],
	["04-kapea2-eteen", Vector2(-1281.0, 839.0), true],
	["05-kapea2-taakse", Vector2(-1281.0, 839.0), false],
	["06-lampi-eteen", Vector2(-1212.0, 741.0), true],
	["07-vaylan-paa-taakse", Vector2(-1028.0, 708.0), false],
]
const EYE_HEIGHT := 4.0 # m
const LOOK_AHEAD := 35.0 # m

var main: Node
var boat: Boat
var _dir := ""
var _line := PackedVector2Array()


func _ready() -> void:
	main = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--channelshots="):
			_dir = arg.split("=")[1]
	DirAccess.make_dir_recursive_absolute(_dir)
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	main.birds.auto_spawn = false
	main.other_boats.auto_spawn = false
	main.weather.set_kind(Weather.Kind.CLEAR, true)
	main.weather.set_process(false)
	boat = main.boat
	for ch in main.lake.channels:
		if ch.get("dock", "") == "kota":
			for p in ch["points"]:
				_line.append(Vector2(p[0], p[1]))
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		main.sky.minutes = 12.0 * 60.0
		await get_tree().process_frame


func _save(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(_dir.path_join(name + ".png"))
	print("kuva ", name)


func _look(from: Vector3, at: Vector3) -> void:
	main.camera_rig.shot = Transform3D(Basis.looking_at(at - from), from)
	main.camera_rig.shot_view = true


## Keskilinjan suunta lähinnä pistettä p (laiturilta väylän päähän)
func _tangent(p: Vector2) -> Vector2:
	var best := INF
	var dir := Vector2.UP
	for i in _line.size() - 1:
		var d := Geometry2D.get_closest_point_to_segment(p, _line[i], _line[i + 1]).distance_to(p)
		if d < best:
			best = d
			dir = (_line[i + 1] - _line[i]).normalized()
	return dir


func _run() -> void:
	main.weather.wind_base = 0.0
	main.weather.gust = 0.0
	Waves.reset(0.0, main.weather.wind_direction)
	if _line.size() < 2:
		print("Kodan väylää ei löytynyt järviaineistosta")
		get_tree().quit(1)
		return
	main.hud.visible = false
	# 1) Pelaajan vene laiturissa: kamera veneen takana ja yläpuolella väylää kohti
	var s: Dictionary = main.lake.starts[0]
	var dock := Vector2(s["x"], s["z"])
	var ahead := _tangent(dock)
	var from := dock - ahead * 9.0
	_look(Vector3(from.x, 3.5, from.y), Vector3(dock.x + ahead.x * 30.0, 0.0, dock.y + ahead.y * 30.0))
	await _frames(SETTLE)
	_save("01-laituri-vaylaa-kohti")
	# Vene pois muista kuvista
	boat.pos = dock + Vector2(0.0, 5000.0)
	boat._apply_transform()
	for v in VIEWS:
		var p: Vector2 = v[1]
		var dir := _tangent(p) * (1.0 if v[2] else -1.0)
		var eye := p - dir * 8.0
		var at := p + dir * LOOK_AHEAD
		_look(Vector3(eye.x, EYE_HEIGHT, eye.y), Vector3(at.x, 0.0, at.y))
		await _frames(SETTLE)
		_save(v[0])
	# 8) Ylhäältä laiturin edestä ja 10) kapean kohdan yläpuolelta: väylän
	# reunat liukuvat lahden pohjaan
	for top in [["08-ylhaalta-laiturin-edesta", dock + ahead * 12.0], ["10-ylhaalta-kapea2", Vector2(-1281.0, 839.0)]]:
		var c: Vector2 = top[1]
		var d := _tangent(c)
		_look(Vector3(c.x - d.x * 4.0, 28.0, c.y - d.y * 4.0), Vector3(c.x + d.x * 6.0, 0.0, c.y + d.y * 6.0))
		await _frames(SETTLE)
		_save(top[0])
	# 13) Vieras moottorivene kodan laiturissa (kannen länsipuoli) ja pelaajan vene aloituspaikalla
	var ob: OtherBoats = main.other_boats
	boat.pos = dock
	boat.yaw = deg_to_rad(s["yaw_deg"])
	boat._apply_transform()
	boat.snap_pose()
	ob.set_process(false) # laiturissa oleva vene muuten katoaisi
	var guest := ob.spawn(OtherBoats.Kind.MOTOR, PackedVector2Array([ob.berth_of(0)]), -1, ob.lake_berth_yaw(0))
	guest.moor(0)
	var eye := dock + ahead * 16.0 + Vector2(ahead.y, -ahead.x) * 6.0
	_look(Vector3(eye.x, 6.0, eye.y), Vector3(dock.x - 2.0, 0.0, dock.y + 1.0))
	await _frames(SETTLE)
	_save("13-vieras-moottorivene-kodalla")
	ob.remove(guest)
	ob.set_process(true)
	# 9) Karttanäkymä
	main.camera_rig.shot_view = false
	boat.pos = dock
	boat.yaw = deg_to_rad(s["yaw_deg"])
	boat._apply_transform()
	main.hud.visible = true
	main.hud._map_panel.visible = true
	await _frames(SETTLE)
	_save("09-kartta")
	get_tree().quit()

extends Node
## Muiden veneiden kuvat designerin tarkistukseen (vaatii ikkunan):
##   godot --fixed-fps 30 -- --day=180 --otherboatshots=/polku/kansioon
## 1) moottorivene sivulta, 2) soutuvene airoineen, 3) ohiajo ja vanan V
## pelaajan veneestä, 4) pelaajan vene peräaallossa (normaali kamera ja FPV),
## 5) vieras vene ylhäältä aallokossa (ei vettä sisällä), 6) vene laiturilla.

var main: Node
var ob: OtherBoats
var boat: Boat
var _dir := ""
var _spot := Vector2.ZERO
var _heading := Vector2.UP


func _ready() -> void:
	main = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--otherboatshots="):
			_dir = arg.split("=")[1]
	DirAccess.make_dir_recursive_absolute(_dir)
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	main.birds.auto_spawn = false
	main.weather.set_kind(Weather.Kind.CLEAR, true)
	main.weather.set_process(false)
	ob = main.other_boats
	boat = main.boat
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wind(speed: float) -> void:
	main.weather.wind_base = speed
	main.weather.gust = 0.0
	Waves.reset(speed, main.weather.wind_direction)


func _save(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(_dir.path_join(name + ".png"))
	print("kuva ", name)


## Kamera maailman pisteestä toiseen
func _look(from: Vector3, at: Vector3) -> void:
	main.camera_rig.shot = Transform3D(Basis.looking_at(at - from), from)
	main.camera_rig.shot_view = true


func _place_player(at: Vector2, heading: Vector2) -> void:
	boat.pos = at
	boat.yaw = atan2(-heading.x, -heading.y)
	boat.velocity = Vector2.ZERO
	boat.yaw_rate = 0.0
	boat._apply_transform()
	boat.snap_pose()


func _clear() -> void:
	for b in ob.boats.duplicate():
		ob.remove(b)


func _run() -> void:
	main.sky.minutes = 12.0 * 60.0
	_wind(0.0)
	while not ob.grid_ready:
		await _frames(1)
	var t = load("res://tests/other_boats_test.gd").new()
	t.main = main
	t.ob = ob
	t.boat = boat
	t.lake = main.lake
	t._find_spot()
	_spot = t._spot
	_heading = t._dir
	t.free()
	var side := Vector2(-_heading.y, _heading.x)
	_place_player(_spot, _heading)

	# 1) Moottorivene sivulta: moottori käy tyhjäkäynnillä
	var at := _spot + side * 14.0
	var b := ob.spawn(OtherBoats.Kind.MOTOR, PackedVector2Array([at]), -1, atan2(-_heading.x, -_heading.y))
	b.motor_running = true
	await _frames(5)
	var p3 := Vector3(at.x, 0.0, at.y)
	var s3 := Vector3(side.x, 0.0, side.y)
	var h3 := Vector3(_heading.x, 0.0, _heading.y)
	_look(p3 + s3 * 6.5 + Vector3(0, 1.2, 0) - h3 * 0.5, p3 + Vector3(0, 0.3, 0))
	await _frames(45)
	_save("1-moottorivene-sivulta")
	_clear()

	# 2) Soutuvene airoineen
	b = ob.spawn(OtherBoats.Kind.ROW, PackedVector2Array([_spot + side * 14.0, _spot + side * 14.0 + _heading * 200.0]))
	b.hold_at_end = true
	await _frames(75)
	p3 = Vector3(b.pos.x, 0.0, b.pos.y)
	_look(p3 + s3 * 6.0 + Vector3(0, 1.6, 0) + h3 * 2.0, p3 + Vector3(0, 0.3, 0))
	await _frames(45)
	_save("2-soutuvene")
	_clear()

	# 3) Ohiajo 20 m:n päästä, vanan V pelaajan veneestä
	var pass_start := _spot + side * 20.0 - _heading * 45.0
	b = ob.spawn(OtherBoats.Kind.MOTOR, PackedVector2Array([pass_start, _spot + side * 20.0 + _heading * 200.0]))
	b.hold_at_end = true
	b.motor_running = true
	b.state = OtherBoat.State.TRAVEL
	b.velocity = _heading * OtherBoat.MOTOR_CRUISE
	b.throttle = OtherBoat.CRUISE_THROTTLE
	main.camera_rig.shot_view = false
	while (b.pos - _spot).dot(_heading) < 35.0:
		await _frames(1)
	var me := Vector3(_spot.x, 0.0, _spot.y)
	_look(me + Vector3(0, 4.5, 0) - s3 * 4.0 - h3 * 6.0, me + s3 * 20.0 + h3 * 18.0)
	await _frames(40)
	_save("3-ohiajo-vana")

	# 4) Pelaajan vene peräaallossa: suurin kallistus normaalilla kameralla ja FPV:llä
	main.camera_rig.shot_view = false
	var best := 0.0
	var waited := 0
	while waited < 900:
		await _frames(1)
		waited += 1
		var tilt := absf(boat.hull.rotation.z)
		if tilt > deg_to_rad(2.0) and tilt < best:
			break # kallistus kääntyi laskuun: kuva harjalla
		best = maxf(best, tilt)
	_save("4-peraaalto-kamera")
	var first_person: bool = main.camera_rig.first_person
	if not first_person:
		main.camera_rig.toggle_first_person()
	main.camera_rig.yaw = boat.yaw - PI / 2.0 # katse vanaa kohti
	best = 0.0
	waited = 0
	while waited < 300:
		await _frames(1)
		waited += 1
		var tilt := absf(boat.hull.rotation.z)
		if tilt > deg_to_rad(2.0) and tilt < best:
			break
		best = maxf(best, tilt)
	_save("4b-peraaalto-fpv")
	if not first_person:
		main.camera_rig.toggle_first_person()
	_clear()

	# 5) Vieras vene ylhäältä aallokossa: sisällä ei vettä
	_wind(7.0)
	at = _spot + side * 12.0
	b = ob.spawn(OtherBoats.Kind.ROW, PackedVector2Array([at]), -1, atan2(-_heading.x, -_heading.y))
	b.start_fishing(999.0)
	p3 = Vector3(at.x, 0.0, at.y)
	_look(p3 + Vector3(0.01, 6.5, 0.4), p3)
	await _frames(60)
	_save("5-sisapuoli-ylhaalta")
	_clear()
	_wind(0.0)

	# 6) Vene laiturilla (uimalaituri tai muu moottoriveneiden laituri)
	var docks := ob.usable_docks(OtherBoats.Kind.MOTOR)
	var d: int = docks[0] if not docks.is_empty() else 1
	var berth := ob.berth_of(d)
	b = ob.spawn(OtherBoats.Kind.MOTOR, PackedVector2Array([berth]), -1, ob.lake_berth_yaw(d))
	b.moor(d)
	var fwd := b.forward()
	var right := b.right()
	p3 = Vector3(berth.x, 0.0, berth.y)
	_look(p3 + Vector3(right.x, 0, right.y) * 7.0 + Vector3(fwd.x, 0, fwd.y) * 5.0 + Vector3(0, 2.5, 0), p3)
	await _frames(60)
	_save("6-laiturilla")
	_clear()
	get_tree().quit()

extends Node
## Veneen ja perämoottorin kuvat eri suunnista (vaatii ikkunan):
##   godot --fixed-fps 30 -- --day=180 --boatshots=/polku/kansioon
## Kamera asetetaan veneen koordinaatteihin (keula -Z, perä +Z, oikea +X).

var _dir := ""
var _frame := 0
var _index := 0
var main: Node
const SHOTS := [
	# nimi, silmä ja katsekohde rungon koordinaateissa
	["1-sivulta", Vector3(5.5, 0.9, 0.0), Vector3(0, 0.1, 0.0)],
	["2-keulasta", Vector3(3.2, 1.6, -4.2), Vector3(0, 0.1, 0.2)],
	["3-perasta", Vector3(-2.6, 1.5, 4.4), Vector3(0, 0.2, 0.4)],
	["4-ylhaalta", Vector3(0.01, 6.5, 0.4), Vector3(0, 0, 0.2)],
	["5-sisalta", Vector3(0.0, 1.9, -3.0), Vector3(0, 0.0, 0.6)],
	["6-moottori", Vector3(1.6, 0.9, 3.5), Vector3(0, 0.3, 2.3)],
	["7-moottori-sivu", Vector3(2.4, 0.6, 2.4), Vector3(0, 0.1, 2.4)],
	["8-keula-sisalta", Vector3(0.5, 1.4, 0.1), Vector3(0, 0.0, -1.5)],
	["9-ankkurin-lasku", Vector3(2.2, 1.2, -1.2), Vector3(0, 0.3, -1.2)],
]


func _ready() -> void:
	main = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--boatshots="):
			_dir = arg.split("=")[1]
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	main.weather.set_kind(Weather.Kind.CLEAR, true)
	var boat: Boat = main.boat
	# Syvään veteen, jotta ankkurin laskussa kestää
	var deepest := boat.pos
	for i in 4000:
		var p := boat.pos + Vector2(randf_range(-400, 400), randf_range(-400, 400))
		if main.lake.depth_at(p.x, p.y) > main.lake.depth_at(deepest.x, deepest.y):
			deepest = p
	boat.pos = deepest
	boat.velocity = Vector2.ZERO
	main.weather.wind_base = 0.0


func _process(_delta: float) -> void:
	if _index >= SHOTS.size():
		get_tree().quit()
		return
	_frame += 1
	main.sky.minutes = 12.0 * 60.0
	var shot: Array = SHOTS[_index]
	var boat: Boat = main.boat
	if _frame == 1 and shot[0] == "9-ankkurin-lasku":
		boat.toggle_anchor()
	var basis := boat.global_basis.orthonormalized()
	var from: Vector3 = boat.global_position + basis * shot[1]
	var at: Vector3 = boat.global_position + basis * shot[2]
	main.camera_rig.shot = Transform3D(Basis.looking_at(at - from), from)
	main.camera_rig.shot_view = true
	if _frame > 40:
		get_viewport().get_texture().get_image().save_png(_dir.path_join(shot[0] + ".png"))
		print("kuva ", shot[0])
		_index += 1
		_frame = 0

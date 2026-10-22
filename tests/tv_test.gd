extends Node
## Alkuvalikon taustan TV:n testi:
##   godot -- --tvtest=/polku/kuviin
## TV ja ruutu ovat pirtissä, ruutu näkyy kameralle valikkopaneelin oikealla
## puolella, ja ohjelman kuvat (vene, koho, hauki) tallennetaan kuviksi.

var _dir := ""
var _frame := 0
var _log: Array[String] = []
var main: Node
var cabin: CabinScene
## Ohjelman ajat, joista otetaan kuva: vene, tärppi, koho painuu, hauki hyppää
const SHOTS := {"tv1-vene": 2.0, "tv2-tarppi": 5.5, "tv3-koho": 11.2, "tv4-hauki": 18.7}


func _ready() -> void:
	main = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tvtest="):
			_dir = arg.split("=")[1]


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _shot(name: String) -> void:
	if _dir != "":
		get_viewport().get_texture().get_image().save_png(_dir.path_join(name + ".png"))


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == 10:
		cabin = main.menu.find_children("*", "CabinScene", true, false)[0]
		var screen := cabin.tv_screen
		_check("TV:n ruutu on pirtissä", screen != null and screen.is_inside_tree())
		var mat := screen.mesh.material as ShaderMaterial
		_check("ruudulla kalastusohjelman varjostin", mat != null and mat.shader.resource_path.ends_with("tv_fishing.gdshader"))
		var cam := get_viewport().get_camera_3d()
		var at := screen.global_position
		var px := cam.unproject_position(at)
		var view := get_viewport().get_visible_rect().size
		_check("ruutu kameran edessä", not cam.is_position_behind(at))
		_check("ruutu näkyy valikkopaneelin oikealla puolella (x=%d)" % int(px.x), px.x > main.menu._main.get_global_rect().end.x and px.x < view.x and px.y > 0.0 and px.y < view.y)
	# Ensin kuvat valikon kamerasta, sitten lähikuvat ruudusta
	var names := SHOTS.keys()
	var k := (_frame - 20) / 10
	if _frame >= 20 and k < names.size() * 2:
		var name: String = names[k % names.size()]
		if (_frame - 20) % 10 == 0:
			cabin._time = SHOTS[name]
			if k == names.size():
				main.menu._main.visible = false
				var cam := get_viewport().get_camera_3d()
				var screen := cabin.tv_screen
				cam.global_position = screen.global_position + screen.global_basis.z * 0.55
				cam.look_at(screen.global_position, Vector3.UP)
		elif (_frame - 20) % 10 == 5:
			_shot(name + ("-lahi" if k >= names.size() else ""))
	if _frame == 20 + names.size() * 20:
		var mat := cabin.tv_screen.mesh.material as ShaderMaterial
		_check("ohjelman kello etenee", mat.get_shader_parameter("time") > SHOTS[names[-1]])
		for l in _log:
			print(l)
		get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

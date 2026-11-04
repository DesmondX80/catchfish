extends Node
## Lähiveden sauman testi (CATCHFISH-120): godot --headless --fixed-fps 30 -- --day=180 --seamtest
## Lähiveden ja kaukaisen järviverkon sauma on lähiveden uloimman verkkorivin
## keskellä, ja rivi on kokonaan tasainen (aallot häipyvät ennen sitä), jolloin
## molemmat verkot katsovat saumassa samaa tasaista pintaa. Testi tarkistaa
## molemmilla veden laaduilla rivin leveyden verkosta, häivytyksen
## (Waves.near_fade) rivillä ja keskellä, saumarajan paikan, materiaaleihin
## asetetut parametrit ja että varjostin käyttää samoja kaavoja.
## Lähdetarkistus (Windows-korjaus): fragment() laskee pikselin derivaatat
## ennen ensimmäistä discardia, eikä discardin jälkeen (eikä varjostimen
## apufunktioissa) ole derivaattoja tai texture()-kutsuja, koska ne ovat
## discardin jälkeen määrittelemättömiä (NVIDIA antaa nollan). Saumatesti
## käyttää uloimmalla tasaisella rivillä näkösäteen ja y = 0 -tason leikkausta,
## sisempänä rest_posia.

var main: Node
var _log: Array[String] = []


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _ready() -> void:
	main = get_parent()
	GameInput.force_active = true
	var before: String = Settings.water_quality
	for quality in ["korkea", "matala"]:
		# Asetus suoraan ilman tallennusta; signaali rakentaa lähiveden uudelleen
		Settings.water_quality = quality
		Settings.water_quality_changed.emit()
		_quality_checks(quality)
	Settings.water_quality = before
	Settings.water_quality_changed.emit()
	_shader_checks()
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)


func _quality_checks(quality: String) -> void:
	var world: LakeWorld = main.world
	var r := LakeWorld.NEAR_RADIUS
	# Lähivesi muualle kuin origoon, ettei keskipiste ole nolla
	var cam: Vector2 = main.boat.pos + Vector2(37.7, -12.3)
	world.follow_camera(Vector3(cam.x, 3.0, cam.y))
	var c: Vector2 = Waves.near_center
	# Uloimman rivin leveys verkon verteksien x-koordinaateista
	var xs := {}
	for v in world.near_water.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		xs[snappedf(v.x, 0.0001)] = true
	var sorted: Array = xs.keys()
	sorted.sort()
	var edge: float = sorted[-1] - sorted[-2]
	var expected := Vector2(5.5, 7.0) if quality == "korkea" else Vector2(9.5, 11.5)
	_check("%s: uloin rivi %.2f m leveä, near_edge %.2f m (Waves %.2f m)" % [quality, edge, world.near_edge, Waves.near_edge],
		absf(edge - world.near_edge) < 0.001 and Waves.near_edge == world.near_edge and edge > expected.x and edge < expected.y)
	_check("%s: lähiveden reuna %.2f m keskeltä (säde %.0f m)" % [quality, sorted[-1], r], absf(sorted[-1] - r) < 0.001 and absf(sorted[0] + r) < 0.001)
	# Häivytys: uloimmalla rivillä 0, keskellä 1
	var worst := 0.0
	for v in world.near_water.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if maxf(absf(v.x), absf(v.z)) >= r - edge - 0.0001:
			worst = maxf(worst, Waves.near_fade(c + Vector2(v.x, v.z)))
	for i in 400:
		# Rivin sisäpisteet neljällä sivulla ja kulmissa
		var t := -r + 2.0 * r * i / 399.0
		var k := r - edge * (i % 7) / 6.0
		for p in [Vector2(t, k), Vector2(t, -k), Vector2(k, t), Vector2(-k, t)]:
			worst = maxf(worst, Waves.near_fade(c + p))
	_check("%s: häivytys uloimmalla rivillä enintään %.6f (pitää olla 0)" % [quality, worst], worst < 1e-6)
	var centre := 1.0
	for p in [Vector2.ZERO, Vector2(50.0, -30.0), Vector2(-90.0, 90.0), Vector2(Waves.FADE_START * r - 0.01, 0.0)]:
		centre = minf(centre, Waves.near_fade(c + p))
	_check("%s: häivytys keskellä ja %.0f m asti vähintään %.4f (pitää olla 1)" % [quality, Waves.FADE_START * r, centre], centre == 1.0)
	var inner := Waves.near_fade(c + Vector2(r - edge - 2.0, 0.0))
	_check("%s: häivytys 2 m ennen ulointa riviä %.4f (välillä 0..1)" % [quality, inner], inner > 0.0 and inner < 1.0)
	# Saumaraja tasaisen rivin keskellä
	var seam := Waves.near_seam()
	_check("%s: saumaraja %.2f m tasaisen rivin %.2f–%.0f m keskellä" % [quality, seam, r - edge, r], absf(seam - (r - 0.5 * edge)) < 0.0001 and seam > r - edge + 1.0 and seam < r - 1.0)
	# Molempiin materiaaleihin samat parametrit kuin aaltomallissa
	var ok := true
	for mat in world.water_materials():
		Waves.apply(mat)
		ok = ok and mat.get_shader_parameter("near_edge") == Waves.near_edge
		ok = ok and mat.get_shader_parameter("near_radius") == Waves.near_radius
		ok = ok and mat.get_shader_parameter("near_center") == Waves.near_center
	_check("%s: lähiveden ja järviverkon materiaaleissa near_center, near_radius ja near_edge (%.2f m) samat kuin Waves" % [quality, Waves.near_edge], ok)


## Varjostimen kaavat vastaavat GDScript-versiota
func _shader_checks() -> void:
	var inc := FileAccess.get_file_as_string("res://shaders/waves.gdshaderinc")
	var water := FileAccess.get_file_as_string("res://shaders/water.gdshader")
	_check("varjostimen near_fade häivyttää samaan kohtaan (near_radius - near_edge)",
		inc.contains("smoothstep(FADE_START * near_radius, near_radius - near_edge, max(d.x, d.y))"))
	_check("varjostimen saumaraja sama kuin Waves.near_seam (near_radius - 0.5 * near_edge)",
		inc.contains("return near_radius - 0.5 * near_edge;"))
	_check("lähivesi ja järviverkko hylkäävät pikselin samalla saumatestillä",
		water.contains("if ((max(nd.x, nd.y) < near_seam()) != is_near) {") and not water.contains("near_radius - 0.02"))
	_derivative_checks(water, inc)


## Derivaatat ennen discardia (CATCHFISH-120, Windows/NVIDIA)
func _derivative_checks(water: String, inc: String) -> void:
	var start := water.find("void fragment() {")
	var end := water.find("\n}\n", start)
	_check("varjostimessa on fragment()", start >= 0 and end > start)
	if start < 0 or end < start:
		return
	var frag := water.substr(start, end - start)
	var first_discard := frag.find("discard;")
	var dx := frag.find("dFdx(")
	var dy := frag.find("dFdy(")
	_check("fragment(): dFdx (%d) ja dFdy (%d) ennen ensimmäistä discardia (%d)" % [dx, dy, first_discard],
		first_discard > 0 and dx >= 0 and dy >= 0 and dx < first_discard and dy < first_discard)
	# Discardin jälkeen suoritettava koodi: fragment()in loppu ja apufunktiot
	# (muu water.gdshader ja waves.gdshaderinc)
	var after := frag.substr(first_discard) + water.substr(0, start) + water.substr(end) + inc
	var found: Array[String] = []
	for call in ["dFdx(", "dFdy(", "fwidth(", "texture("]:
		if after.contains(call):
			found.append(call)
	_check("ei derivaattoja eikä texture()-kutsuja discardin jälkeen tai apufunktioissa %s" % [found], found.is_empty())
	# Näkösäde vain uloimmalla tasaisella rivillä, sisempänä rest_pos (aallon
	# harjan säde leikkaa tason harjaa kauempana)
	var band := frag.find("if (max(nd.x, nd.y) >= near_radius - near_edge) {")
	var ray := frag.find("nd = abs(sp - near_center);")
	var seam := frag.find("if ((max(nd.x, nd.y) < near_seam()) != is_near) {")
	_check("saumatesti: rest_pos sisempänä, näkösäteen ja y = 0 -tason leikkaus vain uloimmalla tasaisella rivillä",
		frag.find("vec2 nd = abs(p - near_center);") < band and band >= 0 and band < frag.find("vec2 sp = ")
		and frag.find("vec2 sp = ") < ray and ray < seam
		and frag.contains("INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(sndc, -1.0, 1.0)")
		and frag.find("vec2 nd = abs(p - near_center);") >= 0)

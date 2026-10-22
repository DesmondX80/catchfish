class_name LureModels
## Uistinten ja onkien 3D-mallit oikeassa koossa (metreinä). Malli osoittaa
## -Z:aan (uistimen kärki, johon siima kiinnittyy, edessä) ja on pystyssä
## selkä ylöspäin. Samat mallit ovat kalapakissa ja vedessä.
##   lusikka     kupera hopealusikka, punainen täplä, kolmihaarakoukku
##   vaappu      pitkä kelluva vaappu 9 cm: hopeakylki, musta selkä, pieni kieli
##   syvavaappu  lyhyt paksu syvävaappu: iso kieli, punainen kärki ja tiikerikuvio
##   lippa       pieni kapea lippa, kirkas pinta
##   jigi        lyijypää ja keltainen kumikala
##   koho        punavalkoinen koho, siima ja koukussa mato
##   pohja       lyijypaino, koukku ja mato
##   pilkki      pystypilkki ja toukka
##   tasuri      tasapainopilkki: vihreä kala, koukut päissä

static var _meshes := {}
static var _mats := {}


static func mesh(id: String) -> Mesh:
	if not _meshes.has(id):
		_meshes[id] = _build(id)
	return _meshes[id]


## Mallin pituus (m), kalapakin lokeron kokoa varten
static func length(id: String) -> float:
	var aabb := mesh(id).get_aabb()
	return maxf(aabb.size.z, aabb.size.y)


static func _mat(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	match key:
		"metal":
			# täysin metallinen pinta näyttää tummalta tai katoaa taivaan heijastukseen
			m.metallic = 0.55
			m.roughness = 0.3
			m.cull_mode = BaseMaterial3D.CULL_DISABLED # lusikka ja lippa ovat ohuita levyjä
		"paint":
			m.metallic = 0.1
			m.roughness = 0.35
		"soft":
			m.roughness = 0.7
		"clear":
			m.roughness = 0.1
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


## Mallin rakentaja: kukin materiaali omana pintanaan
class Builder:
	var tools := {}

	func st(key: String) -> SurfaceTool:
		if not tools.has(key):
			var s := SurfaceTool.new()
			s.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = s
		return tools[key]

	func tri(key: String, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb := Color(0, 0, 0, 0), cc := Color(0, 0, 0, 0)) -> void:
		var s := st(key)
		var n := (b - a).cross(c - a).normalized()
		for v in [[a, ca], [b, cb if cb.a > 0.0 else ca], [c, cc if cc.a > 0.0 else ca]]:
			s.set_color(v[1])
			s.set_normal(n)
			s.add_vertex(v[0])

	## Pyörähdyskappale Z-akselin ympäri: profile = [[z, säde x, säde y], ...],
	## color(z, kulma) antaa värin (kulma 0 = selkä)
	func lathe(key: String, profile: Array, color: Callable, segments := 12, center := Vector3.ZERO) -> void:
		var s := st(key)
		for i in profile.size() - 1:
			for k in segments:
				var quad := []
				for v in [[i, k], [i, k + 1], [i + 1, k + 1], [i + 1, k]]:
					var p: Array = profile[v[0]]
					var a: float = TAU * v[1] / segments
					quad.append([center + Vector3(sin(a) * p[1], cos(a) * p[2], p[0]), Vector3(sin(a) / maxf(p[1], 0.0001), cos(a) / maxf(p[2], 0.0001), 0).normalized(), color.call(p[0], a)])
				for idx in [0, 1, 2, 0, 2, 3]:
					s.set_color(quad[idx][2])
					s.set_normal(quad[idx][1])
					s.add_vertex(quad[idx][0])

	## Ellipsoidi
	func blob(key: String, center: Vector3, radii: Vector3, col: Color, segments := 10) -> void:
		var prof := []
		for i in segments + 1:
			var t := float(i) / segments
			var r := sin(t * PI)
			prof.append([lerpf(-radii.z, radii.z, t), maxf(r * radii.x, 0.0001), maxf(r * radii.y, 0.0001)])
		lathe(key, prof, func(_z, _a): return col, segments, center)

	## Ohut lanka pisteestä toiseen (koukut, siima, rengas)
	func wire(key: String, a: Vector3, b: Vector3, col: Color, r := 0.0006) -> void:
		var d := (b - a).normalized()
		var side := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized() * r
		var up := d.cross(side).normalized() * r
		for o in [[side, up], [up, -side], [-side, -up], [-up, side]]:
			var o1: Vector3 = o[0]
			var o2: Vector3 = o[1]
			tri(key, a + o1, b + o1, b + o2, col)
			tri(key, a + o1, b + o2, a + o2, col)

	## Kolmihaarakoukku: varsi alaspäin pisteestä at, haarat kaartuvat ylös
	func treble(at: Vector3, size: float) -> void:
		var c := Color(0.25, 0.25, 0.27)
		var bottom := at + Vector3(0, -size, 0)
		wire("metal", at, bottom, c)
		for k in 3:
			var dir := Vector3(sin(TAU * k / 3.0), 0, cos(TAU * k / 3.0))
			var mid := bottom + dir * size * 0.35 + Vector3(0, -size * 0.1, 0)
			var tip := bottom + dir * size * 0.45 + Vector3(0, size * 0.35, 0)
			wire("metal", bottom, mid, c)
			wire("metal", mid, tip, c)

	## Yksihaarainen koukku (onget)
	func hook(at: Vector3, size: float) -> void:
		var c := Color(0.3, 0.3, 0.32)
		var bottom := at + Vector3(0, -size, 0)
		var turn := bottom + Vector3(0, -size * 0.15, size * 0.25)
		var tip := bottom + Vector3(0, size * 0.25, size * 0.45)
		wire("metal", at, bottom, c)
		wire("metal", bottom, turn, c)
		wire("metal", turn, tip, c)

	## Mato: mutkitteleva punaruskea putki pisteiden kautta
	func worm(points: Array, r: float) -> void:
		var col := Color(0.62, 0.28, 0.27)
		for i in points.size() - 1:
			var a: Vector3 = points[i]
			var b: Vector3 = points[i + 1]
			var d := (b - a).normalized()
			var side := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
			var up := d.cross(side).normalized()
			for k in 6:
				var a1 := TAU * k / 6.0
				var a2 := TAU * (k + 1) / 6.0
				var o1 := (side * cos(a1) + up * sin(a1)) * r
				var o2 := (side * cos(a2) + up * sin(a2)) * r
				var shade := col.darkened(0.15 * float(i % 2))
				tri("soft", a + o1, b + o1, b + o2, shade)
				tri("soft", a + o1, b + o2, a + o2, shade)

	func commit() -> ArrayMesh:
		var m := ArrayMesh.new()
		for key in tools:
			var s: SurfaceTool = tools[key]
			s.commit(m)
			m.surface_set_material(m.get_surface_count() - 1, LureModels._mat(key))
		return m


static func _build(id: String) -> Mesh:
	var b := Builder.new()
	var silver := Color(0.85, 0.86, 0.88)
	match id:
		"lusikka":
			# Kupera soikea lusikka 6 cm, kovera puoli alaspäin, punainen täplä
			var rows := 8
			var cols := 6
			var grid := []
			for i in rows + 1:
				var t := float(i) / rows
				var z := lerpf(-0.03, 0.03, t)
				var half := 0.013 * sin(clampf(t * 1.05, 0.0, 1.0) * PI * 0.92 + 0.15)
				var row := []
				for k in cols + 1:
					var u := lerpf(-1.0, 1.0, float(k) / cols)
					row.append(Vector3(u * half, 0.004 * (1.0 - u * u), z))
				grid.append(row)
			for i in rows:
				for k in cols:
					var spot := Color(0.85, 0.12, 0.1) if i >= 3 and i <= 5 and k >= 2 and k <= 3 else silver
					b.tri("metal", grid[i][k], grid[i + 1][k], grid[i + 1][k + 1], spot)
					b.tri("metal", grid[i][k], grid[i + 1][k + 1], grid[i][k + 1], spot)
			b.wire("metal", Vector3(0, 0.002, -0.03), Vector3(0, 0.002, -0.037), silver, 0.0012)
			b.treble(Vector3(0, 0.0, 0.033), 0.012)
		"vaappu":
			# Pitkä kelluva vaappu 9 cm: hoikka, musta selkä, hopeakylki, valkoinen vatsa
			var prof := [[-0.045, 0.0005, 0.0005], [-0.042, 0.004, 0.005], [-0.034, 0.006, 0.008], [-0.015, 0.0068, 0.0095], [0.01, 0.006, 0.0085], [0.03, 0.004, 0.0055], [0.042, 0.0015, 0.002], [0.045, 0.0005, 0.0005]]
			b.lathe("paint", prof, func(z, a):
				var c := cos(a)
				if c > 0.55:
					return Color(0.06, 0.07, 0.08)
				return silver if c > -0.6 else Color(0.95, 0.95, 0.93), 12)
			b.blob("paint", Vector3(0.0062, 0.002, -0.036), Vector3(0.0005, 0.0018, 0.0018), Color(0.95, 0.85, 0.2), 6)
			b.blob("paint", Vector3(-0.0062, 0.002, -0.036), Vector3(0.0005, 0.0018, 0.0018), Color(0.95, 0.85, 0.2), 6)
			# pieni läpinäkyvä kieli
			b.tri("clear", Vector3(-0.005, -0.004, -0.044), Vector3(0.005, -0.004, -0.044), Vector3(0.004, -0.008, -0.055), Color(0.9, 0.92, 0.95, 0.5))
			b.tri("clear", Vector3(-0.005, -0.004, -0.044), Vector3(0.004, -0.008, -0.055), Vector3(-0.004, -0.008, -0.055), Color(0.9, 0.92, 0.95, 0.5))
			b.treble(Vector3(0, -0.009, -0.012), 0.01)
			b.treble(Vector3(0, -0.004, 0.044), 0.01)
		"syvavaappu":
			# Lyhyt paksu syvävaappu 6 cm: punainen pää, keltavihreä tiikerikylki, iso kieli
			var prof := [[-0.03, 0.0005, 0.0005], [-0.027, 0.006, 0.007], [-0.018, 0.0095, 0.012], [0.0, 0.01, 0.013], [0.015, 0.008, 0.01], [0.026, 0.004, 0.005], [0.03, 0.0005, 0.0005]]
			b.lathe("paint", prof, func(z, a):
				if z < -0.02:
					return Color(0.85, 0.15, 0.1)
				var stripe := fmod(z * 260.0 + 10.0, 2.0) < 0.8
				if cos(a) > 0.3:
					return Color(0.15, 0.35, 0.12) if stripe else Color(0.4, 0.6, 0.15)
				return Color(0.95, 0.85, 0.25) if cos(a) > -0.5 else Color(0.95, 0.6, 0.3), 12)
			for s in [-1.0, 1.0]:
				b.blob("paint", Vector3(s * 0.0092, 0.003, -0.022), Vector3(0.0006, 0.0025, 0.0025), Color(0.05, 0.05, 0.05), 6)
			var lip := Color(0.9, 0.92, 0.95, 0.55)
			b.tri("clear", Vector3(-0.007, -0.006, -0.028), Vector3(0.007, -0.006, -0.028), Vector3(0.009, -0.016, -0.05), lip)
			b.tri("clear", Vector3(-0.007, -0.006, -0.028), Vector3(0.009, -0.016, -0.05), Vector3(-0.009, -0.016, -0.05), lip)
			b.treble(Vector3(0, -0.012, -0.004), 0.009)
			b.treble(Vector3(0, -0.004, 0.03), 0.009)
		"lippa":
			# Kapea lippa 4 cm: kirkas, toinen puoli kupariin
			for i in 6:
				var z0 := lerpf(-0.02, 0.02, i / 6.0)
				var z1 := lerpf(-0.02, 0.02, (i + 1) / 6.0)
				var w0 := 0.0055 * sin((i / 6.0) * PI * 0.85 + 0.25)
				var w1 := 0.0055 * sin(((i + 1) / 6.0) * PI * 0.85 + 0.25)
				var col := silver if i % 2 == 0 else Color(0.85, 0.55, 0.3)
				b.tri("metal", Vector3(-w0, 0, z0), Vector3(w0, 0, z0), Vector3(w1, 0, z1), col)
				b.tri("metal", Vector3(-w0, 0, z0), Vector3(w1, 0, z1), Vector3(-w1, 0, z1), col)
				b.tri("metal", Vector3(-w0, 0, z0), Vector3(0, 0.002, z0), Vector3(0, 0.002, z1), col)
			b.treble(Vector3(0, 0, 0.022), 0.008)
		"jigi":
			# Lyijypää (punainen) ja keltainen kumikala, jonka pyrstö on lapa
			b.blob("paint", Vector3(0, 0, -0.022), Vector3(0.0055, 0.006, 0.006), Color(0.8, 0.12, 0.1), 8)
			var prof := [[-0.017, 0.004, 0.005], [-0.005, 0.0055, 0.007], [0.012, 0.004, 0.005], [0.026, 0.0018, 0.0022], [0.03, 0.0015, 0.0015]]
			b.lathe("soft", prof, func(z, a): return Color(0.95, 0.85, 0.15) if cos(a) < 0.5 else Color(0.85, 0.7, 0.1), 10)
			var tail := Color(0.95, 0.8, 0.15)
			b.tri("soft", Vector3(0, 0.0015, 0.029), Vector3(0, -0.0015, 0.029), Vector3(0, 0.008, 0.038), tail)
			b.tri("soft", Vector3(0, -0.0015, 0.029), Vector3(0, -0.008, 0.038), Vector3(0, 0.008, 0.038), tail)
			b.blob("paint", Vector3(0.005, 0.0015, -0.024), Vector3(0.0008, 0.0016, 0.0016), Color.WHITE, 6)
			b.blob("paint", Vector3(-0.005, 0.0015, -0.024), Vector3(0.0008, 0.0016, 0.0016), Color.WHITE, 6)
			b.wire("metal", Vector3(0, 0.006, -0.008), Vector3(0, 0.009, -0.006), Color(0.3, 0.3, 0.32))
		"koho":
			# Punavalkoinen koho 5 cm, siimaa ja koukussa mato
			var prof := [[0.0, 0.0006, 0.0006], [0.006, 0.006, 0.006], [0.013, 0.009, 0.009], [0.022, 0.007, 0.007], [0.03, 0.0015, 0.0015]]
			b.lathe("paint", prof, func(z, _a): return Color(0.9, 0.15, 0.1) if z < 0.014 else Color(0.95, 0.95, 0.92), 12, Vector3(0, 0, -0.04))
			b.wire("paint", Vector3(0, 0, -0.045), Vector3(0, 0, -0.052), Color(0.9, 0.15, 0.1), 0.001) # antenni
			b.wire("clear", Vector3(0, 0, -0.01), Vector3(0, 0, 0.02), Color(0.9, 0.9, 0.85, 0.6), 0.0003)
			b.blob("metal", Vector3(0, 0, 0.005), Vector3(0.0015, 0.0015, 0.0015), Color(0.4, 0.4, 0.42), 6) # haulipaino
			b.hook(Vector3(0, 0.004, 0.024), 0.008)
			b.worm([Vector3(0, -0.002, 0.026), Vector3(0.004, -0.004, 0.03), Vector3(-0.002, -0.006, 0.036), Vector3(0.005, -0.004, 0.042), Vector3(0.001, -0.001, 0.048)], 0.0018)
		"pohja":
			# Pohjaonki: lyijypaino (oliivi), siima ja koukussa mato
			b.blob("metal", Vector3(0, 0, -0.03), Vector3(0.006, 0.006, 0.011), Color(0.45, 0.45, 0.48), 10)
			b.wire("clear", Vector3(0, 0, -0.019), Vector3(0, 0, 0.022), Color(0.9, 0.9, 0.85, 0.6), 0.0003)
			b.hook(Vector3(0, 0.004, 0.024), 0.008)
			b.worm([Vector3(0, -0.002, 0.026), Vector3(-0.004, -0.004, 0.031), Vector3(0.003, -0.006, 0.036), Vector3(-0.004, -0.004, 0.042), Vector3(0.0, -0.001, 0.047)], 0.0018)
		"pilkki":
			# Pystypilkki 4 cm (kärki alaspäin), koukussa toukka
			var prof := [[-0.02, 0.0008, 0.0008], [-0.016, 0.003, 0.0018], [0.0, 0.0045, 0.0025], [0.014, 0.0035, 0.002], [0.02, 0.0008, 0.0008]]
			b.lathe("metal", prof, func(z, a): return silver if sin(a) > 0.0 else Color(0.85, 0.7, 0.35), 10)
			b.hook(Vector3(0, -0.002, 0.021), 0.007)
			b.blob("soft", Vector3(0, -0.006, 0.026), Vector3(0.0018, 0.0018, 0.004), Color(0.92, 0.88, 0.75), 6)
		"tasuri":
			# Tasapainopilkki 7 cm: vihreä kala, punainen täplä, koukut päissä
			var prof := [[-0.035, 0.0008, 0.0008], [-0.03, 0.004, 0.006], [-0.015, 0.0055, 0.008], [0.01, 0.0045, 0.0065], [0.026, 0.0025, 0.0035], [0.03, 0.001, 0.001]]
			b.lathe("paint", prof, func(z, a):
				if absf(z + 0.012) < 0.004 and cos(a) < 0.0:
					return Color(0.9, 0.15, 0.1)
				return Color(0.15, 0.55, 0.2) if cos(a) > -0.3 else Color(0.85, 0.85, 0.8), 10)
			var fin := Color(0.2, 0.6, 0.25)
			b.tri("paint", Vector3(0, 0.0, 0.028), Vector3(0, 0.008, 0.04), Vector3(0, -0.008, 0.04), fin)
			b.hook(Vector3(0, -0.002, -0.035), 0.006)
			b.hook(Vector3(0, -0.002, 0.032), 0.006)
			b.treble(Vector3(0, -0.006, 0.0), 0.007)
			b.wire("metal", Vector3(0, 0.006, -0.008), Vector3(0, 0.011, -0.008), Color(0.3, 0.3, 0.32))
	return b.commit()

class_name FishModels
## Kalojen 3D-mallit lajeittain. Malli on metrin pituinen ja osoittaa -Z:aan
## (kuono edessä); kalan koko asetetaan skaalalla.

## Ruumiin muoto: [t (0 kuono .. 1 pyrstö), puolikorkeus, puolileveys] metrin mittaiselle kalalle
const PROFILES := {
	"hauki": [[0.0, 0.006, 0.012], [0.06, 0.022, 0.03], [0.14, 0.04, 0.045], [0.3, 0.06, 0.052], [0.55, 0.062, 0.05], [0.75, 0.05, 0.038], [0.9, 0.025, 0.016], [0.95, 0.03, 0.01]],
	"ahven": [[0.0, 0.01, 0.01], [0.08, 0.06, 0.04], [0.22, 0.12, 0.062], [0.4, 0.135, 0.06], [0.6, 0.1, 0.048], [0.8, 0.045, 0.024], [0.9, 0.035, 0.014], [0.95, 0.04, 0.01]],
	"sarki": [[0.0, 0.01, 0.01], [0.08, 0.055, 0.035], [0.22, 0.1, 0.045], [0.4, 0.115, 0.048], [0.6, 0.09, 0.04], [0.8, 0.04, 0.022], [0.9, 0.03, 0.012], [0.95, 0.035, 0.01]],
	"kiiski": [[0.0, 0.015, 0.015], [0.07, 0.08, 0.06], [0.2, 0.13, 0.075], [0.38, 0.125, 0.065], [0.6, 0.085, 0.045], [0.8, 0.04, 0.022], [0.9, 0.03, 0.013], [0.95, 0.034, 0.01]],
	"lahna": [[0.0, 0.01, 0.008], [0.08, 0.07, 0.028], [0.22, 0.15, 0.04], [0.4, 0.175, 0.042], [0.6, 0.13, 0.035], [0.8, 0.05, 0.018], [0.9, 0.03, 0.01], [0.95, 0.035, 0.008]],
	"made": [[0.0, 0.01, 0.02], [0.06, 0.03, 0.05], [0.15, 0.05, 0.06], [0.3, 0.055, 0.05], [0.55, 0.05, 0.04], [0.75, 0.04, 0.028], [0.9, 0.025, 0.015], [0.95, 0.02, 0.01]],
}

## Värit: selkä, kylki, vatsa, vatsa- ja peräevät, kuvio, kuviotyyppi (ks. fish.gdshader),
## selkä- ja rintaevät sekä pyrstö
const COLORS := {
	"hauki": [Color(0.16, 0.22, 0.1), Color(0.34, 0.42, 0.2), Color(0.85, 0.82, 0.68), Color(0.45, 0.38, 0.2), Color(0.78, 0.76, 0.5), 2, Color(0.3, 0.3, 0.16)],
	"ahven": [Color(0.16, 0.22, 0.1), Color(0.5, 0.55, 0.28), Color(0.88, 0.86, 0.75), Color(0.85, 0.35, 0.12), Color(0.08, 0.1, 0.05), 1, Color(0.32, 0.36, 0.26)],
	"sarki": [Color(0.14, 0.2, 0.22), Color(0.72, 0.75, 0.74), Color(0.92, 0.92, 0.88), Color(0.78, 0.3, 0.18), Color(0.1, 0.1, 0.1), 0, Color(0.3, 0.32, 0.3)],
	"kiiski": [Color(0.25, 0.24, 0.14), Color(0.55, 0.5, 0.3), Color(0.85, 0.82, 0.7), Color(0.5, 0.46, 0.3), Color(0.15, 0.13, 0.08), 3, Color(0.4, 0.38, 0.25)],
	"lahna": [Color(0.2, 0.2, 0.16), Color(0.58, 0.52, 0.36), Color(0.85, 0.82, 0.7), Color(0.25, 0.25, 0.22), Color(0.1, 0.1, 0.1), 0, Color(0.22, 0.22, 0.2)],
	"made": [Color(0.2, 0.18, 0.1), Color(0.45, 0.4, 0.22), Color(0.8, 0.78, 0.65), Color(0.35, 0.32, 0.18), Color(0.15, 0.12, 0.06), 3, Color(0.3, 0.27, 0.15)],
}

## Evät: [tyyppi, t-alku, t-loppu, korkeus] – tyyppi: dorsal (selkä), anal (peräevä),
## pectoral (rintaevät), adipose (rasvaevä)
const FINS := {
	"hauki": [["dorsal", 0.72, 0.86, 0.05], ["anal", 0.72, 0.86, 0.045], ["pectoral", 0.16, 0.24, 0.04], ["pelvic", 0.5, 0.57, 0.035]],
	"ahven": [["dorsal", 0.24, 0.5, 0.09], ["dorsal", 0.52, 0.72, 0.06], ["anal", 0.66, 0.78, 0.05], ["pectoral", 0.2, 0.28, 0.05], ["pelvic", 0.28, 0.36, 0.05]],
	"sarki": [["dorsal", 0.42, 0.56, 0.07], ["anal", 0.66, 0.76, 0.05], ["pectoral", 0.2, 0.27, 0.045], ["pelvic", 0.42, 0.49, 0.045]],
	"kiiski": [["dorsal", 0.22, 0.72, 0.08], ["anal", 0.64, 0.76, 0.04], ["pectoral", 0.18, 0.26, 0.045], ["pelvic", 0.26, 0.33, 0.04]],
	"lahna": [["dorsal", 0.4, 0.5, 0.08], ["anal", 0.55, 0.85, 0.05], ["pectoral", 0.2, 0.28, 0.045], ["pelvic", 0.4, 0.46, 0.04]],
	"made": [["dorsal", 0.3, 0.4, 0.03], ["dorsal", 0.42, 0.92, 0.04], ["anal", 0.5, 0.92, 0.035], ["pectoral", 0.14, 0.2, 0.04], ["pelvic", 0.1, 0.15, 0.03]],
}

## Pyrstön muoto: [korkeus, haarautuminen (0 = suora, 1 = syvä haara)]
const TAILS := {
	"hauki": [0.08, 0.15],
	"ahven": [0.09, 0.35],
	"sarki": [0.1, 0.45],
	"kiiski": [0.08, 0.2],
	"lahna": [0.13, 0.55],
	"made": [0.06, 0.0],
}

const RINGS := 26
const SEGMENTS := 16

static var _meshes := {}
static var _materials := {}


static func mesh(sp: String) -> Mesh:
	if not _meshes.has(sp):
		_meshes[sp] = _build(sp)
	return _meshes[sp]


static func material(sp: String) -> ShaderMaterial:
	if not _materials.has(sp):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/fish.gdshader")
		var c: Array = COLORS[sp]
		m.set_shader_parameter("fin_color", c[3])
		m.set_shader_parameter("pattern_color", c[4])
		m.set_shader_parameter("pattern", c[5])
		m.set_shader_parameter("dorsal_color", c[6])
		_materials[sp] = m
	return _materials[sp]


static func _profile(sp: String, t: float) -> Vector2:
	var p: Array = PROFILES[sp]
	for i in p.size() - 1:
		var a: Array = p[i]
		var b: Array = p[i + 1]
		if t >= a[0] and t <= b[0]:
			var u := smoothstep(0.0, 1.0, (t - a[0]) / (b[0] - a[0]))
			return Vector2(lerpf(a[1], b[1], u), lerpf(a[2], b[2], u))
	var last: Array = p[-1]
	return Vector2(last[1], last[2])


static func _build(sp: String) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c: Array = COLORS[sp]
	var body_end := 0.95
	# Ruumis: renkaat kuonosta pyrstönvarteen
	var rings := []
	for i in RINGS + 1:
		var t := body_end * i / RINGS
		var hw := _profile(sp, t)
		var ring := []
		for j in SEGMENTS:
			var a := TAU * j / SEGMENTS # 0 = selkä
			var y := cos(a) * hw.x
			var x := sin(a) * hw.y
			var belly := (1.0 - cos(a)) * 0.5 # 0 selkä .. 1 vatsa
			var col: Color = c[0].lerp(c[1], smoothstep(0.1, 0.45, belly)).lerp(c[2], smoothstep(0.6, 0.85, belly))
			if (sp == "hauki" or sp == "made") and t < 0.14:
				y *= 0.75 # litteä kuono
			ring.append([Vector3(x, y, t - 0.5), Vector2(t, float(j) / SEGMENTS), col, Vector3(sin(a), cos(a), 0.0)])
		rings.append(ring)
	for i in RINGS:
		for j in SEGMENTS:
			var j2 := (j + 1) % SEGMENTS
			var quad := [rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j]]
			for idx in [0, 1, 2, 0, 2, 3]:
				_vertex(st, quad[idx][0], quad[idx][1], quad[idx][2], quad[idx][3], 1.0)
	# Pyrstö
	var tail: Array = TAILS[sp]
	var root := body_end - 0.5
	var tip_z := root + 0.11
	var h: float = tail[0]
	var fork: float = tail[1]
	var tail_pts := [Vector3(0, 0.025, root), Vector3(0, h, tip_z), Vector3(0, 0, tip_z - fork * 0.08), Vector3(0, -h, tip_z), Vector3(0, -0.025, root)]
	for tri in [[0, 1, 2], [0, 2, 4], [4, 2, 3]]:
		for idx in tri:
			var p: Vector3 = tail_pts[idx]
			_vertex(st, p, Vector2((p.z + 0.5), 0.0), c[3], Vector3.RIGHT, 0.5) # pyrstö: selkäevän väri
	# Muut evät
	for fin in FINS[sp]:
		_fin(st, sp, fin, c[3])
	st.index()
	return st.commit()


static func _fin(st: SurfaceTool, sp: String, fin: Array, color: Color) -> void:
	var kind: String = fin[0]
	var t0: float = fin[1]
	var t1: float = fin[2]
	var height: float = fin[3]
	var z0 := t0 - 0.5
	var z1 := t1 - 0.5
	if kind == "pectoral" or kind == "pelvic":
		for s in [-1.0, 1.0]:
			var hw := _profile(sp, t0)
			var y := -hw.x * (0.3 if kind == "pectoral" else 0.8)
			var base_a := Vector3(s * hw.y * 0.9, y, z0)
			var base_b := Vector3(s * hw.y * 0.9, y, z0 + (z1 - z0) * 0.4)
			var tip := Vector3(s * (hw.y + height * 0.8), y - height * 0.4, z1)
			# Rintaevät selkäevän sävyisiä, vatsaevät lajin evävärillä (ahvenella oranssi)
			for p in [base_a, base_b, tip]:
				_vertex(st, p, Vector2(p.z + 0.5, 0.0), color, Vector3.UP, 0.5 if kind == "pectoral" else 0.0)
		return
	var top := kind in ["dorsal", "adipose"]
	var sign := 1.0 if top else -1.0
	var a := _profile(sp, t0)
	var b := _profile(sp, t1)
	var p0 := Vector3(0, sign * a.x * 0.95, z0)
	var p1 := Vector3(0, sign * b.x * 0.95, z1)
	var top0 := Vector3(0, sign * (a.x + height), z0 + (z1 - z0) * 0.2)
	var top1 := Vector3(0, sign * (b.x + height * 0.6), z1)
	for p in [p0, top0, top1, p0, top1, p1]:
		_vertex(st, p, Vector2(p.z + 0.5, 0.0), color, Vector3.RIGHT, 0.5 if top else 0.0)


static func _vertex(st: SurfaceTool, p: Vector3, uv: Vector2, color: Color, normal: Vector3, body: float) -> void:
	st.set_color(Color(color.r, color.g, color.b, body))
	st.set_uv(uv)
	st.set_normal(normal)
	st.add_vertex(p)

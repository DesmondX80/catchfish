extends Node
## Keula-aallon ja pehmeän peräaallon testi (CATCHFISH-134):
##   godot --headless --fixed-fps 30 -- --day=180 --waketest
## Erillinen Wake-solmu saa suoran ajon fysiikkaruuduittain (track + set_hull),
## ja testi tarkistaa vaahtonauhojen ja vesiharjanteen kärjet:
## 1) 7,8 m/s: viikset keulassa molemmin puolin, alfa 0,80–0,90 (PÄÄTÖS 8), ei rungon sisällä
## 2) 1,0 m/s: ei viiksiä; 1,5 m/s: alfa ≤ 0,05
## 3) peruutus 3,2 m/s: ei viiksiä eikä roisketta
## 4) roiske 7,8 m/s:ssa, ei 4,4 m/s:ssa
## 5) kulku-uoma alkaa peräpeilistä (≤ 0,1 m), alfa siellä ≤ 0,05, 1,5 m:ssä ≥ 90 % huipusta
## 6) kulku-uoman leveys perässä ≤ 1,1 m
## 7) kulku-uoman ja sivuaaltojen uloimmat kärjet |u| = 1
## 8) pysähdyksen jälkeen 1 s: ei viiksiä
## 9) harjanteen korkeus 7,8 m/s 0,09–0,11 m, 4,4 m/s 0,05–0,07 m; 1,0 m/s,
##    peruutus ja paikallaan ei kärkiä
## 10) harjanne ääriviivalla tai ulkopuolella (≥ −0,01 m) ja ≤ 0,65 m siitä
## 11) harjanteen ja viiksen reuna- ja päätykärjet alfa 0, harjan alfa 0,55–0,65;
##     peräpeiliin ylettyvä viiksi jatkuu sivuaaltoon ilman alfa-aukkoa (PÄÄTÖS 7)
## 12) viiksi harjanteen päällä
## 13) piilotettu vana (jäällä) piilottaa harjanteen ja roiskeen
## 14) pelin vene: Boat._simulate välittää Wakelle nopeuden eteenpäin (peruutus
##     negatiivinen, ei keula-aaltoa; eteenpäin keula-aalto syntyy)
## 15) vanan vanhin pää alkaa alfasta 0 (häivytys 1,2 m, PÄÄTÖS 10)
## 16) aukon (vene siirtyi yli 2,8 m näytteiden välillä) jälkeinen alku alfasta 0 (PÄÄTÖS 10)

const DT := 1.0 / 30.0
const START := Vector2(40.0, -25.0)
const YAW := 0.7 # vinossa, jotta paikalliset koordinaatit tulevat testatuiksi
const WAKE_LIFT := 0.025 # wake.gdshader
const RIDGE_LIFT := 0.004 # bow_ridge.gdshader

var _log: Array[String] = []
var _pos := START
var _fwd := Vector2(-sin(YAW), -cos(YAW))
var _right := Vector2(cos(YAW), -sin(YAW))
## Viimeisimmän ajon kärjet maailmassa: peräaalto ja viikset yhdessä, harjanne erikseen
var _g := {}


func _ready() -> void:
	TestUtil.calm_weather(get_parent()) # tyyni, pysäytetty sää: tulos ei riipu arvotusta säästä
	_run.call_deferred()


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _new_wake() -> Wake:
	var w := Wake.new()
	add_child(w)
	w.set_process(false)
	_pos = START
	return w


## Ajo nopeudella v (m/s, negatiivinen = peruutus) seconds sekuntia
func _drive(w: Wake, v: float, seconds: float) -> void:
	for i in roundi(seconds / DT):
		_pos += _fwd * v * DT
		w.track(_stern(), _right, absf(v))
		w.set_hull(_pos, _fwd, v)
		w._process(DT)
	_snap(w)


func _snap(w: Wake) -> void:
	var wh := w.whisker_world()
	_g = {"verts": w._verts + wh["verts"], "colors": w._colors + wh["colors"],
		"uvs": w._uvs + wh["uvs"], "uv2s": w._uv2s + wh["uv2s"], "ridge": w.ridge_world()}


func _stern() -> Vector2:
	return _pos - _fwd * Boat.LENGTH * 0.5


## Etäisyys rungon ääriviivasta (negatiivinen sisällä)
func _outline_dist(p: Vector2) -> float:
	var poly := Boat._outline(_pos, YAW)
	var d := INF
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		d = minf(d, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return -d if Geometry2D.is_point_in_polygon(p, poly) else d


func _local(p: Vector2) -> Vector2:
	var d := p - _pos
	return Vector2(d.dot(_right), -d.dot(_fwd))


## Nauhatyypin kärkien indeksit
func _of_type(w: Wake, type: float) -> Array[int]:
	var out: Array[int] = []
	for i in _g.verts.size():
		if _g.uv2s[i].x == type:
			out.append(i)
	return out


func _max_alpha(w: Wake, idx: Array[int]) -> float:
	var m := 0.0
	for i in idx:
		m = maxf(m, _g.colors[i].a)
	return m


func _xz(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _run() -> void:
	# --- Täysi kaasu 7,8 m/s ---
	var w := _new_wake()
	_drive(w, 7.8, 6.0)
	var wh := _of_type(w, Wake.TYPE_WHISKER)
	var left := 0
	var right := 0
	var inside := 0
	for i in wh:
		var p := _xz(_g.verts[i] as Vector3)
		var l := _local(p)
		var d := _outline_dist(p)
		if d < -0.001:
			inside += 1
		if l.y < 0.0 and d <= 0.5:
			if l.x > 0.0:
				right += 1
			else:
				left += 1
	var wa := _max_alpha(w, wh)
	_check("1) 7,8 m/s: viiksen kärkiä keulan etupuoliskolla vasemmalla %d, oikealla %d" % [left, right], left > 0 and right > 0)
	_check("1) 7,8 m/s: viiksen suurin alfa %.3f (0,80–0,90)" % wa, wa >= 0.80 and wa <= 0.90)
	_check("1) 7,8 m/s: viiksen kärkiä rungon sisällä %d (0)" % inside, inside == 0)
	_check("4) roiske emittoi 7,8 m/s:ssa", w.spray[0].emitting and w.spray[1].emitting)
	var drop_a: float = (w.spray[0].mesh.material as StandardMaterial3D).albedo_color.a
	_check("4) roiskeessa aina %d pisaraa/kylki, elinaika %.2f s, alfa %.2f (PÄÄTÖKSET 9–10: 40, 0,3, 0,55)" % [w.spray[0].amount, w.spray[0].lifetime, drop_a],
		w.spray[0].amount == 40 and w.spray[1].amount == 40 and is_equal_approx(w.spray[0].lifetime, 0.3) and absf(drop_a - 0.55) < 0.01)
	_check("4) roiske on keulaolkapäillä (%.2f m keskipisteestä)" % _xz(w.spray[0].global_position).distance_to(_pos),
		_local(_xz(w.spray[0].global_position)).y < -1.0 and _local(_xz(w.spray[1].global_position)).y < -1.0)

	# 5–7) Peräaalto
	var ch := _of_type(w, Wake.TYPE_CHANNEL)
	var stern := _stern()
	var min_d := INF
	var near_alpha := 0.0
	var near_half := 0.0
	var peak := _max_alpha(w, ch)
	var at15 := INF
	for i in ch:
		var d: float = _g.uvs[i].y
		min_d = minf(min_d, d)
		if d <= 0.1:
			near_alpha = maxf(near_alpha, _g.colors[i].a)
			near_half = maxf(near_half, _xz(_g.verts[i]).distance_to(stern))
		if d >= 1.4 and d <= 1.6:
			at15 = minf(at15, _g.colors[i].a)
	_check("5) kulku-uoma alkaa %.3f m:n päästä peräpeilistä (≤ 0,1)" % min_d, min_d <= 0.1)
	_check("5) kulku-uoman alfa perässä %.3f (≤ 0,05)" % near_alpha, near_alpha <= 0.05)
	_check("5) kulku-uoman alfa 1,5 m perässä %.3f, huippu %.3f (≥ 90 %%)" % [at15, peak], at15 != INF and at15 >= 0.9 * peak)
	_check("6) kulku-uoman leveys perässä %.2f m (≤ 1,1)" % (near_half * 2.0), near_half > 0.0 and near_half * 2.0 <= 1.1)
	var bad_u := 0
	for i in ch + _of_type(w, Wake.TYPE_KELVIN):
		if not is_equal_approx(absf(_g.uvs[i].x), 1.0):
			bad_u += 1
	_check("7) kulku-uoman ja sivuaaltojen kärjet reunoilla |u| = 1 (poikkeavia %d)" % bad_u, bad_u == 0)

	# 9–12) Harjanne täydessä vauhdissa
	_check_ridge(w, "7,8 m/s", 0.09, 0.11, true)
	_check_whisker_edges(w, "7,8 m/s", false)
	_check_on_ridge(w)
	# PÄÄTÖS 7: viiksi jatkuu peräpeilistä sivuaaltoon ilman aukkoa
	var end_s := 0.0
	for i in wh:
		end_s = maxf(end_s, _g.uv2s[i].y)
	var end_alpha := 0.0
	var end_pts: Array[Vector2] = []
	for i in wh:
		if _g.uv2s[i].y >= end_s - 0.001 and _g.colors[i].a > 0.0:
			end_alpha = maxf(end_alpha, _g.colors[i].a)
			end_pts.append(_xz(_g.verts[i]))
	var kel_alpha := 0.0
	var kel_gap := INF
	for i in _of_type(w, Wake.TYPE_KELVIN):
		if _g.uvs[i].y <= 0.1:
			kel_alpha = maxf(kel_alpha, _g.colors[i].a)
			for p in end_pts:
				kel_gap = minf(kel_gap, p.distance_to(_xz(_g.verts[i])))
	_check("11) viiksen loppu peräpeilissä (z %.2f), alfa %.2f, sivuaalto alkaa alfalla %.2f %.2f m:n päästä" % [
		_local(end_pts[0]).y if not end_pts.is_empty() else 0.0, end_alpha, kel_alpha, kel_gap],
		not end_pts.is_empty() and _local(end_pts[0]).y > 2.1 and end_alpha >= 0.5 and kel_alpha >= 0.5 and kel_gap <= 0.35)

	# 15) Vanan vanhin pää häivytetty 1,2 m:n matkalla (PÄÄTÖS 10): ensimmäisen
	# kohdan kärjet alfa 0, 1,2 m:n päässä siitä jo täysi
	var first_a := 0.0
	for i in 6:
		first_a = maxf(first_a, _g.colors[i].a)
	_check("15) vanan vanhimman pään alfa %.3f (0)" % first_a, first_a == 0.0)
	# 8) Pysähdys: 1 s paikallaan
	_drive(w, 0.0, 1.0)
	_check("8) pysähdyksen jälkeen viiksen kärkiä %d (0)" % _of_type(w, Wake.TYPE_WHISKER).size(), _of_type(w, Wake.TYPE_WHISKER).is_empty())
	_check("9) paikallaan harjanteen kärkiä %d (0)" % _g.ridge.size(), _g.ridge.is_empty())
	_check("4) paikallaan roiske ei emittoi", not w.spray[0].emitting and not w.spray[1].emitting)
	# 13) Jäällä vana piilossa: harjanne ja roiske samoin
	w.visible = false
	_check("13) piilotettu vana piilottaa harjanteen ja roiskeen", not w.ridge.is_visible_in_tree() and not w.spray[0].is_visible_in_tree() and not w.spray[1].is_visible_in_tree())
	w.queue_free()

	# 16) Aukko vanassa: vene siirtyy 10 m eteenpäin kesken ajon (esim. laiturisiirto)
	w = _new_wake()
	_drive(w, 7.8, 3.0)
	_pos += _fwd * 10.0
	var gap_start := _stern()
	_drive(w, 7.8, 3.0)
	var best := INF
	var gap_a := -1.0
	for i in _g.verts.size() - 1:
		if _g.uv2s[i].x == Wake.TYPE_CHANNEL and _g.uvs[i].x == -1.0 and i < w._verts.size():
			var m := (_xz(_g.verts[i]) + _xz(_g.verts[i + 1])) * 0.5
			if m.distance_to(gap_start) < best:
				best = m.distance_to(gap_start)
				gap_a = maxf(_g.colors[i].a, _g.colors[i + 1].a)
				for j in range(i + 2, i + 6):
					gap_a = maxf(gap_a, _g.colors[j].a)
	_check("16) aukon jälkeisen alun alfa %.3f %.2f m:n päässä aukosta (0)" % [gap_a, best], best < 0.3 and gap_a == 0.0)
	w.queue_free()

	# --- Vieraan moottoriveneen vauhti 4,4 m/s ---
	w = _new_wake()
	_drive(w, 4.4, 6.0)
	wa = _max_alpha(w, _of_type(w, Wake.TYPE_WHISKER))
	_check("4,4 m/s: viiksen alfa %.3f (heikompi, n. 0,51)" % wa, wa > 0.45 and wa < 0.58)
	_check("4) roiske ei emittoi 4,4 m/s:ssa", not w.spray[0].emitting and not w.spray[1].emitting)
	_check_ridge(w, "4,4 m/s", 0.05, 0.07, false)
	_check_whisker_edges(w, "4,4 m/s", true)
	_check_on_ridge(w)
	w.queue_free()

	# --- Soutu 1,5 m/s ja hidas 1,0 m/s ---
	w = _new_wake()
	_drive(w, 1.5, 4.0)
	wa = _max_alpha(w, _of_type(w, Wake.TYPE_WHISKER))
	_check("2) 1,5 m/s: viiksen alfa %.3f (≤ 0,05)" % wa, wa <= 0.05)
	w.queue_free()
	w = _new_wake()
	_drive(w, 1.0, 4.0)
	_check("2) 1,0 m/s: viiksen kärkiä %d (0)" % _of_type(w, Wake.TYPE_WHISKER).size(), _of_type(w, Wake.TYPE_WHISKER).is_empty())
	_check("9) 1,0 m/s: harjanteen kärkiä %d (0)" % _g.ridge.size(), _g.ridge.is_empty())
	w.queue_free()

	# --- Peruutus 3,2 m/s ---
	w = _new_wake()
	_drive(w, -3.2, 5.0)
	_check("3) peruutus: viiksen kärkiä %d (0)" % _of_type(w, Wake.TYPE_WHISKER).size(), _of_type(w, Wake.TYPE_WHISKER).is_empty())
	_check("3) peruutus: roiske ei emittoi", not w.spray[0].emitting and not w.spray[1].emitting)
	_check("9) peruutus: harjanteen kärkiä %d (0)" % _g.ridge.size(), _g.ridge.is_empty())
	w.queue_free()
	await _check_game_boat()
	_finish()


## 14) Pelin oikea vene: set_hull-kutsu boat.gd:ssä antaa nopeuden eteenpäin
func _check_game_boat() -> void:
	var boat: Boat = get_parent().boat
	if boat.on_ice:
		_check("14) pelin vene jäällä: vana piilossa", not boat.wake.is_visible_in_tree())
		return
	for dir in [-1.0, 1.0]:
		for i in 3:
			boat.velocity = boat.forward() * 3.2 * dir
			await get_tree().physics_frame
		var hs := boat.wake._hull_speed
		var fs := boat.velocity.dot(boat.forward())
		var k := boat.wake.bow_strength()
		if dir < 0.0:
			_check("14) pelin vene peruuttaa: Wake saa nopeuden eteenpäin %.2f (vene %.2f), k %.2f (0)" % [hs, fs, k],
				hs < 0.0 and absf(hs - fs) < 0.3 and k == 0.0)
		else:
			_check("14) pelin vene eteenpäin: Wake saa nopeuden %.2f (vene %.2f), k %.2f (> 0)" % [hs, fs, k],
				hs > 0.0 and absf(hs - fs) < 0.3 and k > 0.0)
	boat.velocity = Vector2.ZERO


## 9–11) Harjanteen korkeus, sijainti ja reunojen alfa
func _check_ridge(w: Wake, label: String, h_min: float, h_max: float, full: bool) -> void:
	var top := 0.0
	var dmin := INF
	var dmax := -INF
	var edge_bad := 0
	var crest := 0.0
	for i in _g.ridge.size():
		var v: Vector3 = _g.ridge[i]
		var a := w._ridge_colors[i].a
		var d := _outline_dist(_xz(v))
		top = maxf(top, v.y)
		dmin = minf(dmin, d)
		dmax = maxf(dmax, d)
		crest = maxf(crest, a)
		# Sisäreuna (ääriviivalla) ja kärjet, joiden korkeus on 0 (päät ja ulkoreuna)
		if (d < 0.01 or v.y <= 1e-6) and a > 1e-6:
			edge_bad += 1
	_check("9) %s: harjanteen korkeus %.3f m (%.2f–%.2f)" % [label, top, h_min, h_max], top >= h_min and top <= h_max)
	_check("10) %s: harjanne %.3f … %.3f m ääriviivasta (≥ −0,01, ≤ 0,65)" % [label, dmin, dmax], dmin >= -0.01 and dmax <= 0.65)
	_check("11) %s: harjanteen reuna- ja päätykärkiä alfa > 0: %d (0)" % [label, edge_bad], edge_bad == 0)
	if full:
		_check("11) %s: harjan alfa %.3f (0,55–0,65)" % [label, crest], crest >= 0.55 and crest <= 0.65)


## 11) Viiksen reuna- ja kärkikärjet alfa 0; free_end: vapaa loppupää myös
func _check_whisker_edges(w: Wake, label: String, free_end: bool) -> void:
	var wh := _of_type(w, Wake.TYPE_WHISKER)
	var end_s := 0.0
	for i in wh:
		end_s = maxf(end_s, _g.uv2s[i].y)
	var bad := 0
	for i in wh:
		var col: float = _g.uvs[i].y
		var s: float = _g.uv2s[i].y
		var edge := col == 0.0 or col == 1.0 or s == 0.0 or (free_end and s >= end_s - 0.001)
		if edge and _g.colors[i].a > 1e-6:
			bad += 1
	_check("11) %s: viiksen reuna- ja kärki%s kärkiä alfa > 0: %d (0)" % [label, "- ja loppupään" if free_end else "pään", bad], not wh.is_empty() and bad == 0)


## 12) Viiksen kärjet eivät jää harjanteen alle: harjanteen korkeus samassa
## kohdassa kolmion sisältä interpoloituna
func _check_on_ridge(w: Wake) -> void:
	var under := 0
	var tested := 0
	var rv: PackedVector3Array = _g.ridge
	for i in _of_type(w, Wake.TYPE_WHISKER):
		var v: Vector3 = _g.verts[i]
		var p := _xz(v)
		for t in range(0, rv.size(), 3):
			var a := _xz(rv[t])
			var b := _xz(rv[t + 1])
			var c := _xz(rv[t + 2])
			var den := (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
			if absf(den) < 1e-9:
				continue
			var l1 := ((b.y - c.y) * (p.x - c.x) + (c.x - b.x) * (p.y - c.y)) / den
			var l2 := ((c.y - a.y) * (p.x - c.x) + (a.x - c.x) * (p.y - c.y)) / den
			var l3 := 1.0 - l1 - l2
			if l1 < -1e-4 or l2 < -1e-4 or l3 < -1e-4:
				continue
			tested += 1
			var h := l1 * rv[t].y + l2 * rv[t + 1].y + l3 * rv[t + 2].y
			if v.y + WAKE_LIFT < h + RIDGE_LIFT - 1e-5:
				under += 1
			break
	_check("12) viiksen kärkiä harjanteen alla %d / %d (0)" % [under, tested], tested > 0 and under == 0)


func _finish() -> void:
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

class_name BoatAnchor
extends Node3D
## Veneen ankkuri ja ankkuriköysi. Ankkuri lasketaan keulasta: se vajoaa
## suoraan keulan alla (liikkuu veneen mukana) 1 m/s, ja vene on ankkurissa
## vasta, kun ankkuri on pohjassa. Köyttä on silloin syvyys + 0,5 m, eikä sitä
## tule lisää, vaikka veneellä yritettäisiin ajaa pois. Nostettaessa köyttä kelataan vuorokäsin, ja ankkuri nousee
## keulaan ja lasketaan veneen pohjalle. Köysi ei veny: jos vene ajautuu
## nostossa kauemmas kuin ulkona oleva köysi riittää, ankkuri laahautuu perässä.
## Keulan takana ankkuri kulkee rungon pohjan alla, ja vauhdissa köyttä kelataan
## vain sen verran, ettei ankkuri nouse runkoa vasten, ennen kuin vene hidastuu.
## Pohjassa olevan ankkurin köysi roikkuu löysänä kaarella ja kiristyy suoraksi,
## kun vene liikkuu ankkurista poispäin.
## Humusvedessä ankkuri ja köysi eivät näy pinnan alla.

signal reached_bottom(depth: float)
signal stowed

enum State { STOWED, LOWERING, DOWN, RAISING }

const SINK_SPEED := 1.0 # m/s: ankkuri lasketaan (köysi luistaa käsien läpi)
const RAISE_SPEED := 1.0 # m/s: köyttä kelataan vuorokäsin
const ROPE_SEGMENTS := 14
const BOW_CHOCK := Vector3(0.0, 0.64, -2.2) # köyden kulku keulapiikin yli (rungon koordinaateissa)
const HAND_POINT := Vector3(0.0, 0.5, -1.5) # kalastajan kädet köydellä
const STOW_POINT := Vector3(0.0, Boat.FOOT_STEP + 0.04, -1.62) # ankkuri keulan jalkatasolla, rengas perään päin
const STEM_KNEE := Vector3(0.0, 0.3, -2.22) # keulavanta taittuu viistoksi (rungon koordinaateissa, vannan ulkopuolella)
const STEM_WATER := Vector3(0.0, -0.05, -1.98) # keulavanta vesirajan alapuolella
const SLIDE_SPEED := 1.0 # m/s: tätä nopeammassa veneessä ankkuri ei nouse keulan takaa
const SLIDE_ROPE := 1.5 # m: köyttä ulkona liu'un ajan, ankkuri mahtuu rungon alle
const KEEL_CLEAR := -0.35 # keulan takana ankkurin renkaan yläraja (rungon koordinaateissa, köli -0,25)

var boat: Boat
var state := State.STOWED
var xz := Vector2.ZERO # ankkurin paikka vaakatasossa
var height := 0.0 # ankkurin korkeus (0 = vedenpinta)
var rope_out := 0.0 # nostossa ulkona oleva köysi (m)
var _anchor: Node3D
var _rope: Array[MeshInstance3D] = []
var _rope_material: StandardMaterial3D
var _time := 0.0


func setup(boat_node: Boat) -> void:
	boat = boat_node
	top_level = true
	_anchor = Node3D.new()
	add_child(_anchor)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.2, 0.21, 0.22)
	iron.metallic = 0.6
	iron.roughness = 0.5
	# Varsi, rengas ylhäällä ja kaksi lapaa alhaalla (pieni naaraankoukku)
	_part(_anchor, _cylinder(0.018, 0.4), Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0)), iron)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.025
	ring.outer_radius = 0.04
	_part(_anchor, ring, Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0.42, 0)), iron)
	for s in [-1.0, 1.0]:
		var fluke := BoxMesh.new()
		fluke.size = Vector3(0.2, 0.025, 0.07)
		_part(_anchor, fluke, Transform3D(Basis(Vector3.BACK, -0.75 * s), Vector3(0.07 * s, 0.05, 0)), iron)
	_rope_material = StandardMaterial3D.new()
	_rope_material.albedo_color = Color(0.36, 0.22, 0.1)
	_rope_material.roughness = 0.9
	for i in ROPE_SEGMENTS + 1:
		var seg := MeshInstance3D.new()
		seg.mesh = _cylinder(0.011, 1.0) # paksumpi kuin oikea köysi, jotta erottuu kauempaa
		seg.material_override = _rope_material
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(seg)
		_rope.append(seg)
	stow()


func _cylinder(radius: float, length: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = length
	c.radial_segments = 6
	c.rings = 1
	return c


func _part(parent: Node3D, mesh: Mesh, xf: Transform3D, material: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xf
	mi.material_override = material
	parent.add_child(mi)


## Ankkuri veneen pohjalle (uusi reissu)
func stow() -> void:
	state = State.STOWED
	_place()


func lower() -> void:
	if state == State.STOWED:
		# Ankkuri nostetaan keulan yli: alkaa keulasta hieman veneen edestä
		var chock := bow_chock()
		var out := boat.forward() * 0.25
		xz = Vector2(chock.x, chock.z) + out
		height = chock.y
	state = State.LOWERING


func raise() -> void:
	if state == State.DOWN:
		rope_out = boat.anchor_rope
		state = State.RAISING
	elif state == State.LOWERING:
		rope_out = bow_chock().distance_to(Vector3(xz.x, height, xz.y))
		state = State.RAISING


## Kalastaja käsittelee köyttä (laskee tai nostaa)
func handling() -> bool:
	return state == State.LOWERING or state == State.RAISING


func bow_chock() -> Vector3:
	return boat.hull.global_transform * BOW_CHOCK


## Ankkurin rengas, johon köysi on sidottu
func ring() -> Vector3:
	return _anchor.global_transform * Vector3(0, 0.42, 0)


## Kalastajan kädet köydellä: nostaessa vuorokäsin, laskiessa köysi luistaa käsien läpi
func hand_points() -> Array:
	var hp: Vector3 = boat.hull.global_transform * HAND_POINT
	var up := boat.hull.global_basis.y
	var side := boat.hull.global_basis.x
	var swing := sin(_time * 5.0) * 0.1 if state == State.RAISING else 0.0
	return [hp + side * 0.06 + up * swing, hp - side * 0.06 - up * swing + boat.hull.global_basis.z * 0.12]


## Ruudun tahdissa: telineessä oleva ankkuri ja köysi seuraavat ruudulla
## näkyvää runkoa (Boat._process)
func follow_boat() -> void:
	_place()


func update(dt: float) -> void:
	_time += dt
	var lake := boat.lake
	match state:
		State.LOWERING:
			# Köysi pystysuorassa keulan alla: ankkuri kulkee veneen mukana,
			# eikä köyttä juokse lisää veneen liikkuessa
			var chock := bow_chock()
			xz = Vector2(chock.x, chock.z) + boat.forward() * 0.25
			var bottom := -lake.depth_at(xz.x, xz.y)
			height -= SINK_SPEED * dt
			if height <= bottom + 0.05:
				height = bottom
				state = State.DOWN
				reached_bottom.emit(-bottom)
		State.RAISING:
			# Köyttä kelataan: ulkona oleva köysi lyhenee, ja se rajaa ankkurin paikan
			var sliding := boat.velocity.length() >= SLIDE_SPEED and _behind_bow()
			rope_out = maxf(rope_out - RAISE_SPEED * dt, SLIDE_ROPE if sliding else 0.0)
			if rope_out <= 0.02:
				stow()
				stowed.emit()
				return
			_haul(dt)
	_place()


## Ankkuri köyden varassa nostossa: pohjasta irti se roikkuu ja heilahtaa keulan
## alle, ja keulan ja renkaan väli on enintään ulkona olevan köyden mittainen
func _haul(dt: float) -> void:
	var chock := bow_chock()
	if height > -boat.lake.depth_at(xz.x, xz.y):
		xz = xz.move_toward(Vector2(chock.x, chock.z), RAISE_SPEED * dt)
		height = maxf(height - SINK_SPEED * dt, -boat.lake.depth_at(xz.x, xz.y))
	var from_chock := Vector3(xz.x, height, xz.y) - chock
	if from_chock.length() <= rope_out:
		_clear_keel()
		return
	# Köysi kireällä: ankkuri tulee köyden suuntaan välin verran
	var p := chock + from_chock.normalized() * rope_out
	xz = Vector2(p.x, p.z)
	height = maxf(p.y, -boat.lake.depth_at(xz.x, xz.y))
	_clear_keel()


## Keulan takana ankkuri pysyy rungon pohjan alla: köysi riittää silloin vain
## lyhyemmälle matkalle keulan taakse, ja lopuksi ankkuri nousee keulan edestä
func _clear_keel() -> void:
	if not _behind_bow():
		return
	var hull := boat.hull.global_transform
	var local := hull.affine_inverse() * Vector3(xz.x, height, xz.y)
	var limit := (hull * Vector3(local.x, KEEL_CLEAR, local.z)).y
	if height <= limit:
		return
	height = limit
	var chock := bow_chock()
	var drop := chock.y - limit
	var off := xz - Vector2(chock.x, chock.z)
	xz = Vector2(chock.x, chock.z) + off.limit_length(sqrt(maxf(0.0, rope_out * rope_out - drop * drop)))


func _behind_bow() -> bool:
	var chock := bow_chock()
	return (xz - Vector2(chock.x, chock.z)).dot(boat.forward()) < -0.05


func _place() -> void:
	if boat == null or boat.hull == null:
		return
	match state:
		State.STOWED:
			# Keulan jalkatasolla pitkittäin, lavat vaakatasossa
			_anchor.global_transform = boat.hull.global_transform * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), STOW_POINT)
			_anchor.visible = true
			for seg in _rope:
				seg.visible = false
			return
		State.DOWN:
			# Pohjassa kallellaan, lapa kiinni pohjassa
			_anchor.global_transform = Transform3D(Basis(Vector3.UP, boat.yaw) * Basis(Vector3.RIGHT, 1.1), Vector3(xz.x, height, xz.y))
		_:
			# Roikkuu köyden varassa pystyssä
			_anchor.global_transform = Transform3D(Basis.IDENTITY, Vector3(xz.x, height - 0.42, xz.y))
	_anchor.visible = ring().y > _water_level()
	_draw_rope()


## Vedenpinnan korkeus keulassa (aallokko mukana)
func _water_level() -> float:
	var a := bow_chock()
	return Waves.swell_height(Vector2(a.x, a.z))


## Köysi: keulasta ankkurin renkaaseen; ankkurin ollessa pohjassa tai nostossa
## löysä köysi roikkuu kaarella ja kiristyy suoraksi, kun köysi on täysin auki.
## Jos suora köysi kulkisi rungon läpi, se kiertää keulavantaa pitkin vesirajaan.
func _draw_rope() -> void:
	var a := bow_chock()
	var b := ring()
	var span := a.distance_to(b)
	var length := span
	if state == State.DOWN:
		length = boat.anchor_rope
	elif state == State.RAISING:
		length = rope_out
	var sag := sqrt(maxf(0.0, length * length - span * span)) * 0.5
	var points: Array[Vector3] = []
	if _through_hull(b):
		var hull := boat.hull.global_transform
		var stem := hull * STEM_WATER
		points.append(a)
		points.append(hull * STEM_KNEE)
		for i in ROPE_SEGMENTS - 1:
			points.append(stem.lerp(b, float(i) / (ROPE_SEGMENTS - 2)))
	else:
		for i in ROPE_SEGMENTS + 1:
			var t := float(i) / ROPE_SEGMENTS
			points.append(a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
	for i in points.size():
		# Löysä köysi lepää pohjalla
		points[i].y = maxf(points[i].y, boat.lake.height_at(points[i].x, points[i].z) + 0.02)
	# Kalastajan käsien kautta keulaan, kun köyttä käsitellään
	var water := _water_level()
	var hand := boat.hull.global_transform * HAND_POINT
	for i in ROPE_SEGMENTS + 1:
		var seg := _rope[i]
		var p0: Vector3
		var p1: Vector3
		if i < ROPE_SEGMENTS:
			p0 = points[i]
			p1 = points[i + 1]
		else:
			p0 = hand
			p1 = a
			seg.visible = handling()
			if not seg.visible:
				continue
		# Pinnan alla oleva osa ei näy: katkaistaan vedenpintaan
		if p0.y < water and p1.y < water:
			seg.visible = false
			continue
		if p1.y < water:
			p1 = p0.lerp(p1, (p0.y - water) / (p0.y - p1.y))
		elif p0.y < water:
			p0 = p1.lerp(p0, (p1.y - water) / (p1.y - p0.y))
		seg.visible = true
		_segment(seg, p0, p1)


## Kulkisiko suora köysi keulasta rungon sisältä keulavannan takaa: tutkitaan
## vannan taitteen korkeus ja vesiraja. Keulan alla riippuva köysi pysyy suorana.
func _through_hull(ring_point: Vector3) -> bool:
	var to := boat.hull.global_transform.affine_inverse() * ring_point
	if to.y >= STEM_WATER.y:
		return false
	for stem in [Vector3(0.0, STEM_KNEE.y, BOW_CHOCK.z + 0.05), STEM_WATER]:
		var at := BOW_CHOCK.lerp(to, (BOW_CHOCK.y - stem.y) / (BOW_CHOCK.y - to.y))
		if at.z > stem.z and absf(at.x) < boat._half_width_at(at.z, stem.y):
			return true
	return false


func _segment(seg: MeshInstance3D, p0: Vector3, p1: Vector3) -> void:
	var d := p1 - p0
	var length := d.length()
	if length < 0.001:
		seg.visible = false
		return
	var y := d / length
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	seg.global_transform = Transform3D(Basis(x, y * length, z), (p0 + p1) * 0.5)


## Onko köysi kireällä (ankkuri pohjassa, vene köyden ulottuman päässä)
func taut() -> bool:
	var bow := bow_chock()
	return state == State.DOWN and Vector2(bow.x - xz.x, bow.z - xz.y).length() >= boat.anchor_reach() - 0.05

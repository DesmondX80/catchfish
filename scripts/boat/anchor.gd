class_name BoatAnchor
extends Node3D
## Veneen ankkuri ja ankkuriköysi. Ankkuri lasketaan keulasta: se vajoaa
## pohjaan köyden juostessa perässä, ja vene on ankkurissa vasta, kun ankkuri
## on pohjassa. Nostettaessa köyttä kelataan vuorokäsin, ja ankkuri nousee
## keulaan ja lasketaan veneen pohjalle. Pohjassa olevan ankkurin köysi roikkuu
## löysänä kaarella ja kiristyy suoraksi, kun vene liikkuu ankkurista poispäin.

signal reached_bottom(depth: float)
signal stowed

enum State { STOWED, LOWERING, DOWN, RAISING }

const SINK_SPEED := 1.0 # m/s: ankkuri vajoaa
const RAISE_SPEED := 0.8 # m/s: köyttä kelataan vuorokäsin
const ROPE_SEGMENTS := 14
const BOW_CHOCK := Vector3(0.0, 0.5, -2.05) # köyden kulku keulan yli (rungon koordinaateissa)
const HAND_POINT := Vector3(0.0, 0.5, -1.5) # kalastajan kädet köydellä
const STOW_POINT := Vector3(0.0, -0.1, -1.55) # ankkuri veneen pohjalla keulassa

var boat: Boat
var state := State.STOWED
var xz := Vector2.ZERO # ankkurin paikka vaakatasossa
var height := 0.0 # ankkurin korkeus (0 = vedenpinta)
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
	_rope_material.albedo_color = Color(0.62, 0.52, 0.32)
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
	if state == State.LOWERING or state == State.DOWN:
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


func update(dt: float) -> void:
	_time += dt
	var lake := boat.lake
	match state:
		State.LOWERING:
			# Ilmassa nopeasti veteen, sitten vajoaa; köysi antaa perään
			var bottom := -lake.depth_at(xz.x, xz.y)
			height -= (3.0 if height > 0.0 else SINK_SPEED) * dt
			if height <= bottom + 0.05:
				height = bottom
				state = State.DOWN
				reached_bottom.emit(-bottom)
		State.RAISING:
			# Köyttä kelataan: ankkuri nousee kohti keulaa ja kulkee sen alle
			var chock := bow_chock()
			var below := Vector2(chock.x, chock.z)
			var dist := Vector2(xz - below).length()
			var to_go := dist + (chock.y - height)
			var step := minf(RAISE_SPEED * dt, to_go)
			if to_go <= 0.02:
				stow()
				stowed.emit()
				return
			# Vaakaliike ja nousu samassa suhteessa kuin köyttä jäljellä
			var k := step / maxf(to_go, 0.001)
			xz = xz.lerp(below, k)
			height = lerpf(height, chock.y, k)
	_place()


func _place() -> void:
	if boat == null or boat.hull == null:
		return
	match state:
		State.STOWED:
			# Veneen pohjalla kyljellään
			_anchor.global_transform = boat.hull.global_transform * Transform3D(Basis(Vector3.BACK, PI / 2.0), STOW_POINT)
			for seg in _rope:
				seg.visible = false
			return
		State.DOWN:
			# Pohjassa kallellaan, lapa kiinni pohjassa
			_anchor.global_transform = Transform3D(Basis(Vector3.UP, boat.yaw) * Basis(Vector3.RIGHT, 1.1), Vector3(xz.x, height, xz.y))
		_:
			# Roikkuu köyden varassa pystyssä
			_anchor.global_transform = Transform3D(Basis.IDENTITY, Vector3(xz.x, height - 0.42, xz.y))
	_draw_rope()


## Köysi: keulasta ankkurin renkaaseen; ankkurin ollessa pohjassa löysä köysi
## roikkuu kaarella ja kiristyy suoraksi, kun köysi on täysin auki
func _draw_rope() -> void:
	var a := bow_chock()
	var b := ring()
	var length := boat.anchor_rope if state == State.DOWN else a.distance_to(b)
	var span := a.distance_to(b)
	var sag := sqrt(maxf(0.0, length * length - span * span)) * 0.5 if state == State.DOWN else 0.0
	var points: Array[Vector3] = []
	for i in ROPE_SEGMENTS + 1:
		var t := float(i) / ROPE_SEGMENTS
		var p := a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
		# Löysä köysi lepää pohjalla
		var floor_y := boat.lake.height_at(p.x, p.z) + 0.02
		p.y = maxf(p.y, floor_y)
		points.append(p)
	# Kalastajan käsien kautta keulaan, kun köyttä käsitellään
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
		seg.visible = true
		_segment(seg, p0, p1)


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


## Onko köysi kireällä (ankkuri pohjassa, köysi täysin auki)
func taut() -> bool:
	return state == State.DOWN and bow_chock().distance_to(ring()) >= boat.anchor_rope - 0.05

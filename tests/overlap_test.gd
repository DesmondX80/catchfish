extends Node
## Päällekkäisten pintojen testi: godot --headless --fixed-fps 30 -- --day=180 --overlaptest
## (talvella --day=40: saavi, pakki ja kalastaja jäällä)
## Veneen, moottorin, saavin, pakin, vavan, telineiden ja lähellä olevan veden,
## jään, maaston ja laiturin verkoista etsitään
## kolmiot, jotka ovat samassa tasossa (alle 1 mm toisistaan) ja peittävät
## toisiaan eri verkoissa. Sellaiset pinnat välkkyvät (z-fighting), kun kamera
## tai vene liikkuu. Kahden kappaleen liitoskohta, joka jää umpinaisen
## laatikon tai sylinterin sisään tai veneen pohjan alle, ei näy eikä välky.

const PLANE_EPS := 0.001 # m
const MIN_WIDTH := 0.0005 # m: kapeampi yhteinen alue on vain reunojen kosketus
const NEAR_BOAT := 6.0 # m: tutkittava alue veneen ympärillä

var main: Node
var _frame := 0
var _solids: Array = [] # [rungosta kappaleeseen, koko, onko sylinteri]: umpinaiset laatikot ja sylinterit


func _ready() -> void:
	main = get_parent()
	GameInput.force_active = true


func _process(_delta: float) -> void:
	_frame += 1
	if _frame < 10:
		return
	var boat: Boat = main.boat
	var to_local := boat.hull.global_transform.affine_inverse()
	var near := AABB(boat.global_position - Vector3.ONE * NEAR_BOAT / 2.0, Vector3.ONE * NEAR_BOAT)
	var tris: Array = [] # [a, b, c, normaali, d, verkko, kaksipuolinen]
	var names: Array[String] = []
	for mi in _meshes(main):
		if not (mi.global_transform * mi.get_aabb()).intersects(near):
			continue
		if mi.mesh is ImmediateMesh or mi.skin != null or mi.get_parent() is Skeleton3D:
			continue # joka ruudulla piirrettävät ja animoidut verkot
		var xf := to_local * mi.global_transform
		var id := names.size()
		names.append(_name(mi))
		if mi.mesh is BoxMesh:
			_solids.append([xf.affine_inverse(), (mi.mesh as BoxMesh).size, false])
		elif mi.mesh is CylinderMesh and (mi.mesh as CylinderMesh).cap_top and (mi.mesh as CylinderMesh).cap_bottom:
			var cyl := mi.mesh as CylinderMesh
			_solids.append([xf.affine_inverse(), Vector3(minf(cyl.top_radius, cyl.bottom_radius), cyl.height, 0.0), true])
		for surf in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(surf)
			var two_sided := mat is BaseMaterial3D and (mat as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED
			var arrays := mi.mesh.surface_get_arrays(surf)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count := index.size() if not index.is_empty() else verts.size()
			for t in range(0, count - 2, 3):
				var a := xf * verts[index[t] if not index.is_empty() else t]
				var b := xf * verts[index[t + 1] if not index.is_empty() else t + 1]
				var c := xf * verts[index[t + 2] if not index.is_empty() else t + 2]
				if a.length() > NEAR_BOAT and b.length() > NEAR_BOAT and c.length() > NEAR_BOAT:
					continue # järven, maaston ja laiturin kaukaiset osat
				var n := (b - a).cross(c - a)
				if n.length() < 1e-7:
					continue
				n = n.normalized()
				tris.append([a, b, c, n, n.dot(a), id, two_sided])
	# Kolmiot ämpäreihin tason mukaan (suunta etumerkistä riippumatta)
	var buckets := {}
	for i in tris.size():
		var key := _plane_key(tris[i][3], tris[i][4])
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(i)
	var found := {}
	for key in buckets:
		var own: Array = buckets[key]
		var others: Array = []
		for dk in [-1, 0, 1]:
			var k2: Vector4i = key + Vector4i(0, 0, 0, dk)
			if buckets.has(k2):
				others.append_array(buckets[k2])
		for i in own:
			for j in others:
				if j <= i or tris[i][5] == tris[j][5]:
					continue
				if _fights(tris[i], tris[j]):
					var pair := "%s  ↔  %s" % [names[tris[i][5]], names[tris[j][5]]]
					if not found.has(pair):
						found[pair] = tris[i][0]
	print("Verkkoja %d, kolmioita %d" % [names.size(), tris.size()])
	for pair in found:
		print("VIRHE päällekkäiset pinnat: %s (rungon koordinaateissa %s)" % [pair, found[pair]])
	if found.is_empty():
		print("OK   veneen ympärillä ei ole päällekkäisiä samassa tasossa olevia pintoja")
	get_tree().quit(1 if not found.is_empty() else 0)


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in node.get_children():
		if c is MeshInstance3D and c.mesh != null and c.is_visible_in_tree():
			out.append(c)
		out.append_array(_meshes(c))
	return out


## Verkon kuvaus: sen omistava luokka (Boat, CatchTub, ...), verkon tyyppi ja koko
## sekä paikka rungon koordinaateissa
func _name(mi: MeshInstance3D) -> String:
	var owner_name := "?"
	var n: Node = mi.get_parent()
	while n != null and n != main:
		var script: Script = n.get_script()
		if script != null and script.get_global_name() != "":
			owner_name = script.get_global_name()
			break
		n = n.get_parent()
	var mesh := mi.mesh.get_class()
	if mi.mesh is BoxMesh:
		mesh = "laatikko %s" % (mi.mesh as BoxMesh).size
	elif mi.mesh is CylinderMesh:
		mesh = "sylinteri r=%.3f h=%.3f" % [(mi.mesh as CylinderMesh).bottom_radius, (mi.mesh as CylinderMesh).height]
	var at: Vector3 = main.boat.hull.global_transform.affine_inverse() * mi.global_position
	return "%s: %s @ (%.3f, %.3f, %.3f)" % [owner_name, mesh, at.x, at.y, at.z]


func _plane_key(n: Vector3, d: float) -> Vector4i:
	if n.x < -1e-4 or (absf(n.x) <= 1e-4 and (n.y < -1e-4 or (absf(n.y) <= 1e-4 and n.z < 0.0))):
		n = -n
		d = -d
	return Vector4i(roundi(n.x * 20.0), roundi(n.y * 20.0), roundi(n.z * 20.0), roundi(d / 0.004))


## Välkkyvätkö kolmiot keskenään: sama taso, päällekkäin, ja kumpikin näkyy
## samalta puolelta (etupuoli, tai takapuoli kaksipuolisella materiaalilla),
## eikä päällekkäinen kohta jää umpinaisen kappaleen sisään piiloon
func _fights(p: Array, q: Array) -> bool:
	var np: Vector3 = p[3]
	var nq: Vector3 = q[3]
	var dot := np.dot(nq)
	if absf(dot) < 0.9995:
		return false
	if absf(np.dot(q[0]) - p[4]) > PLANE_EPS or absf(np.dot(q[1]) - p[4]) > PLANE_EPS or absf(np.dot(q[2]) - p[4]) > PLANE_EPS:
		return false
	var sides: Array[Vector3] = []
	if dot > 0.0:
		sides.append(np)
		if p[6] and q[6]:
			sides.append(-np)
	else:
		if q[6]:
			sides.append(np)
		if p[6]:
			sides.append(nq)
	if sides.is_empty():
		return false
	# Tason kanta ja kolmiot kaksiulotteisina
	var u := np.cross(Vector3.UP if absf(np.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := np.cross(u)
	var a := PackedVector2Array([Vector2(u.dot(p[0]), v.dot(p[0])), Vector2(u.dot(p[1]), v.dot(p[1])), Vector2(u.dot(p[2]), v.dot(p[2]))])
	var b := PackedVector2Array([Vector2(u.dot(q[0]), v.dot(q[0])), Vector2(u.dot(q[1]), v.dot(q[1])), Vector2(u.dot(q[2]), v.dot(q[2]))])
	var shared := Geometry2D.intersect_polygons(a, b)
	if shared.is_empty():
		return false
	var poly: PackedVector2Array = shared[0]
	if 2.0 * _area(poly) / _perimeter(poly) < MIN_WIDTH:
		return false
	var c2 := Vector2.ZERO
	for pt in poly:
		c2 += pt
	c2 /= poly.size()
	var center: Vector3 = u * c2.x + v * c2.y + np * (p[4] as float)
	for side in sides:
		if not _hidden(center + side * 0.002):
			return true
	return false


func _perimeter(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i in poly.size():
		sum += poly[i].distance_to(poly[(i + 1) % poly.size()])
	return maxf(sum, 1e-9)


func _area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i in poly.size():
		sum += poly[i].cross(poly[(i + 1) % poly.size()])
	return absf(sum) * 0.5


## Onko piste (rungon koordinaateissa) umpinaisen kappaleen sisällä tai veneen
## pohjan alla rungon sisällä, jonne kamera ei näe
func _hidden(pt: Vector3) -> bool:
	var boat: Boat = main.boat
	if pt.y < Boat.FLOOR_Y and absf(pt.x) < boat._half_width_at(pt.z, Boat.FLOOR_Y) and pt.z > -2.2 and pt.z < 2.2:
		return true
	for solid in _solids:
		var local: Vector3 = solid[0] * pt
		var size: Vector3 = solid[1]
		if solid[2]: # sylinteri (Y-akseli), r = size.x
			if absf(local.y) < size.y / 2.0 and Vector2(local.x, local.z).length() < size.x:
				return true
		elif absf(local.x) < size.x / 2.0 and absf(local.y) < size.y / 2.0 and absf(local.z) < size.z / 2.0:
			return true
	return false

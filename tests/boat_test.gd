extends Node
## Veneen mallin testi: godot --headless --fixed-fps 30 -- --day=180 --boattest
## Törmäysääriviiva vastaa rungon laitaa, veneessä olevat esineet (saavi, pakki,
## ankkuri, istuimet, vavanpitimet) ovat rungon sisällä pohjan yläpuolella,
## potkuri pyörii vain moottorin käydessä kaasulla, ja kalastajan jalat pysyvät
## veneen sisällä kalastaessa, moottorilla ja ankkuria laskiessa.

var main: Node
var _log: Array[String] = []
var _frame := 0
var _spin := 0.0


func _ready() -> void:
	main = get_parent()
	GameInput.force_active = true
	main.hud.set_paused_view(false)


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


## Onko rungon koordinaattien piste rungon sisällä pohjan ja laidan välissä
func _inside(boat: Boat, p: Vector3) -> bool:
	var h := boat._hull_at(p.z)
	return p.y >= Boat.FLOOR_Y - 0.02 and p.y <= h.y + 0.05 and absf(p.x) < boat._half_width_at(p.z, clampf(p.y, Boat.FLOOR_Y, h.y))


## Esineen osat, jotka ovat rungon ulkopuolella (tyhjä, jos kaikki sisällä)
func _parts_outside(boat: Boat, node: Node3D) -> String:
	var out := []
	var to_hull := boat.hull.global_transform.affine_inverse()
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mi.get_aabb()
		for k in 8:
			var p: Vector3 = to_hull * (mi.global_transform * box.get_endpoint(k))
			if not _inside(boat, p):
				out.append("%.2f, %.2f, %.2f" % [p.x, p.y, p.z])
	return "; ".join(out.slice(0, 3))


## Jalkaterät (nilkka ja varpaat) veneen sisällä pohjan yläpuolella
func _check_feet(boat: Boat, when: String) -> void:
	var angler := boat.angler
	var to_hull := boat.hull.global_transform.affine_inverse()
	var bad := []
	for side in ["L", "R"]:
		var ankle := angler.posed_position("Foot." + side)
		var toe := ankle - angler.global_basis.z * 0.16
		for p in [ankle, toe, ankle + angler.global_basis.x * 0.05, ankle - angler.global_basis.x * 0.05]:
			var local: Vector3 = to_hull * p
			if not _inside(boat, local):
				bad.append("%s %.2f, %.2f, %.2f" % [side, local.x, local.y, local.z])
	_check("jalat veneen sisällä %s (asento %d) %s" % [when, angler.pose, ", ".join(bad)], bad.is_empty())


func _process(_delta: float) -> void:
	_frame += 1
	var boat: Boat = main.boat
	if _frame == 5:
		var worst := 0.0
		for o in Boat.OUTLINE:
			worst = maxf(worst, absf(absf(o.x) - boat._hull_at(o.y).x - 0.02))
		_check("törmäysääriviiva laidan ja reunalistan kohdalla (poikkeama %.2f m)" % worst, worst < 0.04)
		_check("saavi pohjalla rungon sisällä", _inside(boat, CatchTub.ON_BOAT * Vector3(0.26, 0.0, 0.19)) and _inside(boat, CatchTub.ON_BOAT * Vector3(-0.26, 0.0, 0.19)))
		_check("pakki pohjalla rungon sisällä", _inside(boat, TackleBox.ON_BOAT.origin + Vector3(-0.18, 0.0, 0.1)))
		_check("ankkuri pohjalla rungon sisällä (%s)" % _parts_outside(boat, boat.anchor._anchor), _parts_outside(boat, boat.anchor._anchor) == "")
		_check("ankkuriköysi kulkee keulapiikin yli", absf(BoatAnchor.BOW_CHOCK.y - boat._hull_at(BoatAnchor.BOW_CHOCK.z).y) < 0.03)
		for i in 2:
			var holder := main.fishing.holder_transform(i).origin as Vector3
			_check("vavanpidin %d laidalla" % (i + 1), absf(holder.x) < boat._hull_at(holder.z).x and holder.y > boat._hull_at(holder.z).y - 0.1)
		for seat in [Angler.SEATS[Angler.Pose.FISHING], Angler.SEATS[Angler.Pose.MOTOR], Angler.SEATS[Angler.Pose.ANCHOR]]:
			_check("istumapaikka %s rungon sisällä" % seat, _inside(boat, seat))
		var handle := boat.hull.global_transform.affine_inverse() * boat.tiller_handle()
		_check("ohjausaisan kahva laitojen välissä perätuhdon edessä", absf(handle.x) < boat._hull_at(handle.z).x and handle.z < 1.6)
		boat.motor_running = true
		boat.throttle = 0.0
		_spin = boat._prop.rotation.z
	if _frame == 30:
		_check("vapaalla potkuri ei pyöri", is_equal_approx(boat._prop.rotation.z, _spin))
		boat.throttle = 0.5
	if _frame == 60:
		_check("kaasulla potkuri pyörii", absf(boat._prop.rotation.z - _spin) > 1.0)
		boat.throttle = 0.0
	if _frame == 120:
		_check_feet(boat, "moottorilla")
		boat.motor_running = false
	if _frame == 200:
		_check_feet(boat, "kalastaessa")
		# Syvään veteen, jotta ankkurin laskussa kestää
		var deepest := boat.pos
		for i in 4000:
			var p := boat.pos + Vector2(randf_range(-400, 400), randf_range(-400, 400))
			if main.lake.depth_at(p.x, p.y) > main.lake.depth_at(deepest.x, deepest.y):
				deepest = p
		boat.pos = deepest
		boat.velocity = Vector2.ZERO
		boat.toggle_anchor()
	if _frame == 260:
		_check("ankkuria lasketaan (syvyys %.1f m)" % boat.depth_below(), boat.anchor.handling())
		_check_feet(boat, "ankkuria laskiessa")
		for l in _log:
			print(l)
		get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)

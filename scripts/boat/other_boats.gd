class_name OtherBoats
extends Node3D
## Muut kalastajat järvellä: silloin tällöin moottorivene ajaa laiturilta toiselle
## laiturille tai kalapaikalle, tai soutuvene soutaa laiturilta kalapaikalle,
## kalastaa ankkurissa ja palaa. Veneitä on vain avovesikaudella ja valoisaan
## aikaan, eikä kovalla tuulella tai rankkasateella lähdetä; hämärän tullen
## järvellä olevat veneet palaavat laiturille. Veneet ilmestyvät ja katoavat
## laitureilla, kun pelaaja on kaukana tai ei katso laituria kohti.
## Reitit haetaan järven karkeasta ruudukosta (AStarGrid2D), joka rakennetaan
## pelin alussa muutaman ruudun aikana. Moottoriveneiden peräaallot (wakes_at)
## keinuttavat pelaajan venettä (Boat._animate), mutta vesipinta ei nouse niiden
## kohdalla; aallon näkee vaahtovanasta.

signal sound_event(sound: String, at: Vector3)

enum Kind { MOTOR, ROW }

const MAX_BOATS := 2
const FIRST_SPAWN := Vector2(120.0, 360.0) # s pelin alusta (todellista aikaa, ei peliaikaa)
const SPAWN_GAP := Vector2(240.0, 720.0) # s edellisestä veneestä
const RETRY := 10.0 # s: ehdot eivät sallineet lähtöä, yritetään uudelleen
const MOTOR_SHARE := 0.6 # moottoriveneitä 60 %, soutuveneitä 40 %
const START_BOAT_CHANCE := 0.5 # pelin alussa yksi vene voi olla jo järvellä
const MIN_DAYLIGHT := 0.45 # sama raja kuin metsän pikkulinnuilla (GameAudio)
const MAX_WIND := 8.0 # m/s: kovemmalla tuulella ei lähdetä
const MAX_RAIN := 0.5 # rankkasade
const HIDDEN_DISTANCE := 250.0 # m: pelaaja näin kaukana laiturista
const CLEAR_DISTANCE := 40.0 # m: näkymättömissäkään vene ei ilmesty pelaajan viereen
const BERTH_CLEAR := 15.0 # m: laiturilla ei ole jo toista venettä
const BERTH_GAP := 0.7 # m: vieras vene laiturin vieressä näin irti kannesta (lähtiessä kääntyy irti)
## Reittiruudukko
const CELL := 8.0 # m (kaksi järviaineiston ruutua)
const SHORE_CLEARANCE := 15.0 # m rannasta ja saarista
const MOTOR_DEPTH := Boat.SHALLOW_WARNING # potkuri osuu pohjaan alle metrissä
const ROW_DEPTH := 2.0 * Boat.DRAFT
const APPROACH_DEPTH := 0.5 # m: laiturin lähivedessä tätä matalampaan ei mennä
const BERTH_DEPTH := Boat.DRAFT + 0.05 # m: laiturin vierestä lähtöpisteeseen
const LEAVE_DISTANCE := 5.0 # m suoraan eteenpäin laiturin vierestä ennen kääntymistä
const APPROACH_RADIUS := 120.0 # m laiturista: laiturin ja syvän veden väli ajetaan hitaasti
const APPROACH_WEIGHT := 4.0 # reittihaku välttää matalaa lähivettä ja kapeaa vettä
## Soutuvene pääsee kapeista salmista (esim. kodan lahdesta järvelle): vähintään
## ROW_DEPTH syvää vettä näin kaukana rannasta on kulkukelpoista, mutta reittihaku
## välttää sitä kuten laiturin lähivettä. Kalapaikat ovat SHORE_CLEARANCE päässä.
const NARROW_CLEARANCE := 6.0 # m rannasta
const DOCK_CLEARANCE := 5.0 # m: reitti ei kulje laiturin kannen vierestä (paitsi laituriin)
const NET_CLEARANCE := 10.0 # m verkkojen pyykeistä
const NET_LINE_CLEARANCE := 6.0 # m verkon linjasta: verkon yli ei ajeta
## Moottoriveneet käyttävät vain näitä laitureita: kodan laiturilta on noin 600 m
## matalaa vettä, joten sieltä kulkevat vain soutuveneet
const MOTOR_DOCKS := ["uimalaituri", "veneenlasku"]
const LOS_STEP := 2.0 # m: suoran reitinosan tarkistusväli
const LINE_SWAY := 1.5 # m: matalassa vedessä suoran sivuilla on myös vettä näin kauas
const LOS_MAX := 150.0 # m: suoristettu reitinosa enintään
const BUILD_BUDGET_USEC := 2000 # ruudukon rakennus enintään näin paljon ruutua kohden
## Reitit
const PASS_NEAR := Vector2(30.0, 80.0) # m: osa ohiajoista kulkee näin läheltä pelaajaa
const PASS_NEAR_SHARE := 0.5
const ROW_SPOT := Vector2(100.0, 400.0) # m laiturilta soutuveneen kalapaikalle
const ROW_ROUTE_MAX := 600.0 # m: soudettava matka kalapaikalle enintään
const FAR_SPOT := 400.0 # m: moottoriveneen kalapaikka järven toisella puolella
const SPOT_FROM_PLAYER := 60.0 # m: kalapaikka ei ole pelaajan vieressä
const FISH_TIME := Vector2(300.0, 900.0) # s ankkurissa
## Peräaalto: Kelvinin hajaantuvat aallot
const GRAVITY := 9.81
const WAKE_HEIGHT := 0.15 # m 20 m:n päässä matkanopeudella
const WAKE_REF := 20.0
const WAKE_CRESTS := 4.5 # aallonharjaa ryhmässä
const WAKE_FADE := 2.0 * Wake.LIFETIME # s: korkeus vaimenee ajan mukaan
const WAKE_MIN_SPEED := 1.5 # m/s: hitaampi vene ei tee keinuttavaa aaltoa
const WAKE_HISTORY := 90.0 # s
const KELVIN_DIVERGENT := 0.6155 # rad (35,3°): aaltojen kulkusuunta veneen kulkusuunnasta

var boat: Boat
var camera: Camera3D
var sky: SkyTime
var weather: Weather
var lake: LakeData
var nets: NetControl
var audio: GameAudio
var winter := false
## Testit: ei satunnaisia uusia veneitä
var auto_spawn := true
var boats: Array[OtherBoat] = []
## Reittiruudukko valmis (rakennetaan pelin alussa muutaman ruudun aikana)
var grid_ready := false

var _rng := RandomNumberGenerator.new()
var _timer := 0.0
var _start_checked := false
var _gcols := 0
var _grows := 0
var _row := 0
var _cls := {} # Kind -> PackedByteArray: 0 ei kuljeta, 1 syvä vesi, 2 laiturin lähivesi tai kapea vesi
var _astar := {} # Kind -> AStarGrid2D
var _deep := {} # Kind -> PackedInt32Array syvän veden ruuduista (kalapaikat)
var _usable := {} # Kind -> [laiturin indeksi], joilta pääsee syvään veteen
var _exits := {} # Kind -> {laituri: lähtöpiste}
var _wake_cache_frame := -1
var _wake_cache_p := Vector2.INF
var _wake_cache: Array = []
var _next_variant := 0
var _berths := {} # laiturin indeksi -> laituripaikka


func setup(boat_node: Boat, camera_node: Camera3D, sky_time: SkyTime, weather_node: Weather, lake_data: LakeData, net_control: NetControl, is_winter: bool) -> void:
	boat = boat_node
	camera = camera_node
	sky = sky_time
	weather = weather_node
	lake = lake_data
	nets = net_control
	winter = is_winter
	_rng.randomize()
	_next_variant = _rng.randi() % OtherBoat.COLORS.size()
	_timer = _rng.randf_range(FIRST_SPAWN.x, FIRST_SPAWN.y)
	_gcols = lake.cols / 2
	_grows = lake.rows / 2


## Saako järvelle lähteä: avovesikausi, valoisaa, ei kovaa tuulta eikä rankkasadetta
func can_launch() -> bool:
	return not winter and sky.daylight() > MIN_DAYLIGHT and weather.wind_base <= MAX_WIND and weather.rain <= MAX_RAIN


func player_pos() -> Vector2:
	return Vector2(1e6, 1e6) if boat.on_ice else boat.pos


func fishing_time() -> float:
	return _rng.randf_range(FISH_TIME.x, FISH_TIME.y)


func _process(delta: float) -> void:
	if winter:
		return
	if not grid_ready:
		_build_grid_step()
		return
	if auto_spawn:
		if not _start_checked:
			_start_checked = true
			if _rng.randf() < START_BOAT_CHANCE and can_launch():
				_spawn_on_lake()
		_timer -= delta
		if _timer <= 0.0:
			if boats.size() < MAX_BOATS and can_launch() and _launch():
				_timer = _rng.randf_range(SPAWN_GAP.x, SPAWN_GAP.y)
			else:
				_timer = RETRY
	var dusk := sky.daylight() <= MIN_DAYLIGHT
	for b in boats.duplicate():
		if dusk and not b.hold_at_end and (b.state == OtherBoat.State.FISHING or (b.dock < 0 and b.state != OtherBoat.State.ANCHORING)):
			send_home(b)
		if b.state == OtherBoat.State.DOCKED and b.dock >= 0 and dock_hidden(b.dock):
			remove(b)
		elif b._stuck > OtherBoat.STUCK_TIME and _hidden(b.pos, HIDDEN_DISTANCE):
			remove(b)


# --- Veneet -------------------------------------------------------------------

## Uusi vene reitin alkuun keula reitin suuntaan; reitti päättyy laiturille
## end_dock (>= 0) tai kalapaikalle (-1). Testit käyttävät suoraan.
func spawn(kind: int, route: PackedVector2Array, end_dock := -1, heading := NAN) -> OtherBoat:
	var b := OtherBoat.new()
	add_child(b)
	if is_nan(heading):
		var d := route[1] - route[0] if route.size() > 1 else Vector2.UP
		heading = atan2(-d.x, -d.y)
	b.setup(self, kind, route[0], heading, _next_variant)
	_next_variant = (_next_variant + 1) % OtherBoat.COLORS.size()
	b.sound_event.connect(func(sound, at): sound_event.emit(sound, at))
	boats.append(b)
	if route.size() > 1:
		b.set_route(route, end_dock)
	return b


func remove(b: OtherBoat) -> void:
	if b._motor_sound and audio:
		audio.drive_motor(b._motor_sound, false, 0.0, 0.0) # loop_stop lokiin
	boats.erase(b)
	b.queue_free()


## Satunnainen vene laiturilta, jonka luona pelaaja ei ole
func _launch() -> bool:
	var kind := Kind.MOTOR if _rng.randf() < MOTOR_SHARE else Kind.ROW
	var origins: Array = _usable[kind].filter(func(i): return dock_hidden(i) and _berth_free(i))
	if origins.is_empty():
		return false
	var from: int = origins[_rng.randi() % origins.size()]
	var berth := berth_of(from)
	var end_dock := -1
	var dest := Vector2.INF
	var via := Vector2.INF
	if kind == Kind.MOTOR:
		# Toiselle laiturille tai kalapaikalle järven toisella puolella; osa
		# ohiajoista kulkee pelaajan läheltä
		var others: Array = _usable[kind].filter(func(i): return i != from)
		if not others.is_empty() and _rng.randf() < 0.5:
			end_dock = others[_rng.randi() % others.size()]
		else:
			dest = _random_spot(kind, berth, FAR_SPOT, INF, _exits[kind][from])
		if _rng.randf() < PASS_NEAR_SHARE:
			via = _near_player_point(kind)
	else:
		var row := row_route(from)
		if row.is_empty():
			return false
		var rb := spawn(kind, row, -1, lake_berth_yaw(from))
		rb.home_dock = from
		return true
	if end_dock < 0 and dest == Vector2.INF:
		return false
	var route := dock_route(kind, from, end_dock, dest, via)
	if route.is_empty() and via != Vector2.INF:
		route = dock_route(kind, from, end_dock, dest)
	if route.is_empty():
		return false
	var b := spawn(kind, route, end_dock, lake_berth_yaw(from))
	b.home_dock = from
	return true


## Reitti laiturilta from laiturille to (>= 0) tai kalapaikalle spot, valinnaisesti
## välipisteen via kautta. Tyhjä, jos reittiä ei löydy.
func dock_route(kind: int, from: int, to: int, spot := Vector2.INF, via := Vector2.INF) -> PackedVector2Array:
	var start: Vector2 = _exits[kind][from]
	var dest: Vector2 = _exits[kind][to] if to >= 0 else spot
	var route := find_path(kind, start, dest) if via == Vector2.INF else _join(find_path(kind, start, via), find_path(kind, via, dest))
	if route.is_empty():
		return route
	var out := _berth_path(from)
	out.reverse()
	route = out + route
	if to >= 0:
		route.append_array(_berth_path(to))
	return route


## Soutuveneen reitti laiturilta from kalapaikalle ROW_SPOT-etäisyydelle. Soudettava
## matka enintään ROW_ROUTE_MAX: kodalta kalapaikalle, joka on linnuntietä lähellä,
## voi olla kapeiden salmien takia pitkä matka. Tyhjä, jos sopivaa ei löydy.
func row_route(from: int) -> PackedVector2Array:
	for i in 16:
		var spot := _random_spot(Kind.ROW, berth_of(from), ROW_SPOT.x, ROW_SPOT.y, _exits[Kind.ROW][from])
		if spot == Vector2.INF:
			continue
		var route := dock_route(Kind.ROW, from, -1, spot)
		if not route.is_empty() and route_length(route) <= ROW_ROUTE_MAX:
			return route
	return PackedVector2Array()


static func route_length(route: PackedVector2Array) -> float:
	var length := 0.0
	for i in route.size() - 1:
		length += route[i].distance_to(route[i + 1])
	return length


## Laiturit, joilta tämän tyyppinen vene pääsee syvään veteen
func usable_docks(kind: int) -> Array:
	return _usable[kind]


## Pelin alussa vene voi olla jo kalapaikalla kaukana pelaajasta, näkymättömissä
func _spawn_on_lake() -> void:
	var kind := Kind.MOTOR if _rng.randf() < MOTOR_SHARE else Kind.ROW
	if _usable[kind].is_empty():
		return
	for i in 40:
		var spot := _deep_cell(kind)
		var d := spot.distance_to(player_pos())
		if d < 300.0 or d > 900.0 or not _hidden(spot, 600.0) or not _clear_of_nets(spot, 30.0):
			continue
		var home := _nearest_dock(kind, spot)
		if not _connected(kind, spot, _exits[kind][home]):
			continue # erillinen lampare: sieltä ei pääsisi kotiin
		var b := spawn(kind, PackedVector2Array([spot]), -1, _rng.randf() * TAU)
		b.start_fishing(_rng.randf_range(120.0, FISH_TIME.y))
		b.home_dock = home
		return


## Kalastus loppui tai hämärtyy: reitti laiturille (soutuvene lähtölaiturilleen,
## moottorivene lähimmälle). exclude: laituri, jolle ei mennä (pelaaja on siellä).
func send_home(b: OtherBoat, exclude := -1) -> void:
	if b.home_retry > 0.0:
		return
	if b.home_dock >= 0 and b.home_dock != exclude and b.pos.distance_to(berth_of(b.home_dock)) < BERTH_CLEAR:
		b.moor(b.home_dock) # ei vielä lähtenyt laiturista
		return
	var docks: Array = _usable[b.kind].filter(func(i): return i != exclude)
	if docks.is_empty():
		b.home_retry = 10.0
		return
	var target: int = b.home_dock if b.kind == Kind.ROW and b.home_dock in docks else -1
	if target < 0:
		var best := INF
		for i in docks:
			var d := b.pos.distance_to(berth_of(i))
			if d < best:
				best = d
				target = i
	var route := find_path(b.kind, b.pos, _exits[b.kind][target])
	if route.is_empty():
		b.home_retry = 10.0 # yritetään hetken päästä uudelleen
		return
	route.append_array(_berth_path(target))
	b.set_route(route, target)


func _nearest_dock(kind: int, p: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in _usable[kind]:
		var d := p.distance_to(berth_of(i))
		if d < best_d:
			best_d = d
			best = i
	return best


## Esteet, joita vene väistää: [paikka, säde]
func obstacles_for(b: OtherBoat) -> Array:
	var list := []
	var r: float = OtherBoat.AVOID_RADIUS[b.kind]
	if not boat.on_ice:
		list.append([boat.pos, r])
	for o in boats:
		if o != b:
			list.append([o.pos, r])
	if nets:
		for net in nets.nets:
			for end in net.ends():
				list.append([end, NET_CLEARANCE])
	return list


# --- Laiturit ---------------------------------------------------------------------

## Laituripaikka: aloituspaikka laiturin vieressä, runko irti kannesta
## (kuten Boat.setup) ja vielä BERTH_GAP metriä kauempana
func berth_of(i: int) -> Vector2:
	if _berths.has(i):
		return _berths[i]
	var p := Vector2(lake.starts[i]["x"], lake.starts[i]["z"])
	var away := Vector2.ZERO
	for k in 10:
		var push: Vector2 = Boat.dock_push_at(lake, p, lake_berth_yaw(i))[0]
		if push == Vector2.ZERO:
			break
		away += push
		p += push * 1.05
	# Kansi on laiturin paikallisen x:n negatiivisella puolella (LakeData.dock_side_x)
	var dock_yaw := LakeData.dock_yaw(lake.starts[i])
	var side := Vector2(cos(dock_yaw), -sin(dock_yaw))
	p += (away.normalized() if away != Vector2.ZERO else side) * BERTH_GAP
	_berths[i] = p
	return p


## Vieras vene on laiturissa kannen suuntaisena, keula järvelle päin (pelaajan
## aloitussuunta voi poiketa siitä, esim. kodalla)
## Laiturilta lähtiessä ensin suoraan eteenpäin kannen pään ohi (kodalla kansi
## on veneen ja syvän veden välissä), sitten lähtöpisteeseen
func leave_of(i: int) -> Vector2:
	var berth := berth_of(i)
	var yaw := lake_berth_yaw(i)
	var p := berth + Vector2(-sin(yaw), -cos(yaw)) * LEAVE_DISTANCE
	if lake.depth_at(p.x, p.y) < BERTH_DEPTH or lake.near_dock(p, 0.9):
		return berth
	return p


## Laiturin vieren ja lähtöpisteen väliset reittipisteet tullessa: [lähtöpaikka, laituri]
func _berth_path(i: int) -> PackedVector2Array:
	var path := PackedVector2Array()
	if leave_of(i) != berth_of(i):
		path.append(leave_of(i))
	path.append(berth_of(i))
	return path


func lake_berth_yaw(i: int) -> float:
	return LakeData.dock_yaw(lake.starts[i])


## Laiturilla voi ilmestyä tai kadota vene: pelaaja on kaukana tai ei katso laituria kohti
func dock_hidden(i: int) -> bool:
	return _hidden(berth_of(i), HIDDEN_DISTANCE)


func _hidden(p: Vector2, far: float) -> bool:
	var d := p.distance_to(player_pos())
	if d > far:
		return true
	return d > CLEAR_DISTANCE and not camera.is_position_in_frustum(Vector3(p.x, 0.5, p.y))


## Onko piste laiturin vieressä (lähtö- tai tulopaikka)
func near_berth(p: Vector2, distance: float) -> bool:
	for i in lake.starts.size():
		if p.distance_to(berth_of(i)) < distance:
			return true
	return false


func _berth_free(i: int) -> bool:
	for b in boats:
		if b.pos.distance_to(berth_of(i)) < BERTH_CLEAR:
			return false
	return true


# --- Reittiruudukko ------------------------------------------------------------------

## Ruudukon rivejä ruutu kerrallaan: ruudun matalin kohta ja lähin ranta
## järviaineiston neljästä ruudusta. Luokat moottori- ja soutuveneelle.
func _build_grid_step() -> void:
	if _astar.is_empty():
		for kind in [Kind.MOTOR, Kind.ROW]:
			var g := AStarGrid2D.new()
			g.region = Rect2i(0, 0, _gcols, _grows)
			g.cell_size = Vector2(CELL, CELL)
			g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
			g.update()
			_astar[kind] = g
			var cls := PackedByteArray()
			cls.resize(_gcols * _grows)
			_cls[kind] = cls
			_deep[kind] = PackedInt32Array()
		return # ruudukon varaus vie oman ruutunsa
	var t0 := Time.get_ticks_usec()
	var berths := []
	for i in lake.starts.size():
		berths.append(berth_of(i))
	var lc := lake.cols
	while _row < _grows and Time.get_ticks_usec() - t0 < BUILD_BUDGET_USEC:
		var r := _row
		for c in _gcols:
			var depth := 99.0
			var shore := 9999.0
			var shore_max := 0.0 # kapea vesi: ruudun etäisin kohta rannasta
			for k in 4:
				var i := (r * 2 + (k >> 1)) * lc + c * 2 + (k & 1)
				depth = minf(depth, -lake.heights[i] if lake.water[i] == 1 else 0.0)
				shore = minf(shore, lake.shore.decode_u16(i * 2))
				shore_max = maxf(shore_max, lake.shore.decode_u16(i * 2))
			var center := lake.cell_center(c * 2, r * 2) + Vector2(lake.cell_size, lake.cell_size) * 0.5
			var approach := false
			for b in berths:
				approach = approach or center.distance_to(b) < APPROACH_RADIUS
			var deck := approach and lake.near_dock(center, DOCK_CLEARANCE + CELL * 0.5)
			var id := r * _gcols + c
			for kind in [Kind.MOTOR, Kind.ROW]:
				var min_depth := MOTOR_DEPTH if kind == Kind.MOTOR else ROW_DEPTH
				var cls := 0
				if deck:
					cls = 0
				elif depth >= min_depth and shore >= SHORE_CLEARANCE:
					cls = 1
				elif approach and depth >= APPROACH_DEPTH:
					cls = 2
				elif kind == Kind.ROW and depth >= ROW_DEPTH and shore_max >= NARROW_CLEARANCE:
					cls = 2 # kapea vesi
				_cls[kind][id] = cls
				var g: AStarGrid2D = _astar[kind]
				if cls == 0:
					g.set_point_solid(Vector2i(c, r))
				elif cls == 2:
					g.set_point_weight_scale(Vector2i(c, r), APPROACH_WEIGHT)
				else:
					_deep[kind].append(id)
		_row += 1
	if _row >= _grows:
		_finish_grid()


## Laitureiden lähtöpisteet: lähin kulkukelpoinen ruutu, jonne pääsee suoraan lähtöpaikasta (leave_of)
## laiturin vierestä kannen ohi ja josta pääsee syvään veteen. Laituri on
## käytössä vain, jos sellainen löytyy. Moottoriveneille vain MOTOR_DOCKS.
func _finish_grid() -> void:
	for kind in [Kind.MOTOR, Kind.ROW]:
		_usable[kind] = []
		_exits[kind] = {}
		for i in lake.starts.size():
			if kind == Kind.MOTOR and not lake.starts[i].get("id", "") in MOTOR_DOCKS:
				continue
			var exit := _dock_exit(kind, leave_of(i))
			if exit != Vector2.INF:
				_usable[kind].append(i)
				_exits[kind][i] = exit
	grid_ready = true


func _dock_exit(kind: int, berth: Vector2) -> Vector2:
	var c0 := cell_of(berth)
	var candidates := []
	for dr in range(-6, 7):
		for dc in range(-6, 7):
			var c := c0 + Vector2i(dc, dr)
			if _class(kind, c) != 0:
				candidates.append([cell_pos(c).distance_to(berth), c])
	candidates.sort_custom(func(a, b): return a[0] < b[0])
	for cand in candidates:
		var p := cell_pos(cand[1])
		var d: float = cand[0]
		var clear := true
		for s in int(d):
			var q := berth.lerp(p, s / d)
			if lake.depth_at(q.x, q.y) < BERTH_DEPTH or lake.near_dock(q, 0.9):
				clear = false
				break
		if clear and _reaches_deep(kind, cand[1]):
			return p
	return Vector2.INF


## Pääseekö ruudusta syvään veteen laiturin lähivettä pitkin
func _reaches_deep(kind: int, start: Vector2i) -> bool:
	var seen := {start: true}
	var queue := [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if _class(kind, c) == 1:
			return true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not seen.has(n) and _class(kind, n) != 0:
				seen[n] = true
				queue.append(n)
	return false


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - lake.origin_x) / CELL), floori((p.y - lake.origin_z) / CELL))


func cell_pos(c: Vector2i) -> Vector2:
	return Vector2(lake.origin_x + (c.x + 0.5) * CELL, lake.origin_z + (c.y + 0.5) * CELL)


func _class(kind: int, c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= _gcols or c.y >= _grows or not grid_ready and c.y >= _row:
		return 0
	return _cls[kind][c.y * _gcols + c.x]


## Kulkukelpoinen vesi (syvä, laiturin lähivesi tai soutuveneelle kapea vesi)
func navigable(kind: int, p: Vector2) -> bool:
	return _class(kind, cell_of(p)) != 0


## Laiturin ja syvän veden välinen matala lähivesi: ajetaan hitaasti
func in_approach(kind: int, p: Vector2) -> bool:
	return _class(kind, cell_of(p)) == 2


## Reitti pisteestä a pisteeseen b: A* ruudukossa verkkojen ympäri, suoristettuna.
## Palauttaa [a, ..., b] tai tyhjän, jos reittiä ei löydy.
func find_path(kind: int, a: Vector2, b: Vector2) -> PackedVector2Array:
	var ca := _nearest_open(kind, cell_of(a))
	var cb := _nearest_open(kind, cell_of(b))
	if ca.x < 0 or cb.x < 0:
		return PackedVector2Array()
	var g: AStarGrid2D = _astar[kind]
	var blocked := _block_nets(kind)
	var ids := g.get_id_path(ca, cb)
	for c in blocked:
		g.set_point_solid(c, false)
	if ids.is_empty():
		return PackedVector2Array()
	var pts := PackedVector2Array()
	for c in ids:
		pts.append(cell_pos(c))
	pts = _smooth(kind, pts)
	var route := PackedVector2Array([a])
	var first := 1 if pts.size() > 1 and _line_clear(kind, a, pts[1]) else 0
	var last := pts.size() - 2 if pts.size() > 1 and _line_clear(kind, pts[pts.size() - 2], b) else pts.size() - 1
	for i in range(first, last + 1):
		if pts[i].distance_to(route[route.size() - 1]) > 0.5:
			route.append(pts[i])
	if b.distance_to(route[route.size() - 1]) > 0.5:
		route.append(b)
	return route


## Onko pisteiden välillä kulkukelpoinen yhteys (haku alkaa a:sta: erillisestä
## lampareesta haku päättyy nopeasti)
func _connected(kind: int, a: Vector2, b: Vector2) -> bool:
	var ca := _nearest_open(kind, cell_of(a))
	var cb := _nearest_open(kind, cell_of(b))
	return ca.x >= 0 and cb.x >= 0 and not (_astar[kind] as AStarGrid2D).get_id_path(ca, cb).is_empty()


func _join(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	if a.is_empty() or b.is_empty():
		return PackedVector2Array()
	var joined := a.duplicate()
	joined.append_array(b.slice(1))
	return joined


func _nearest_open(kind: int, c: Vector2i) -> Vector2i:
	if _class(kind, c) != 0:
		return c
	for r in range(1, 5):
		for dr in range(-r, r + 1):
			for dc in range(-r, r + 1):
				var n := c + Vector2i(dc, dr)
				if maxi(absi(dr), absi(dc)) == r and _class(kind, n) != 0:
					return n
	return Vector2i(-1, -1)


## Verkkojen pyykit ja linjat estoon reittihaun ajaksi; palauttaa estetyt ruudut
func _block_nets(kind: int) -> Array[Vector2i]:
	var blocked: Array[Vector2i] = []
	if nets == null:
		return blocked
	var g: AStarGrid2D = _astar[kind]
	for net in nets.nets:
		var pts := net.points()
		for i in pts.size():
			var radius := NET_CLEARANCE if i == 0 or i == pts.size() - 1 else NET_LINE_CLEARANCE
			var c0 := cell_of(pts[i])
			var n := ceili((radius + CELL) / CELL)
			for dr in range(-n, n + 1):
				for dc in range(-n, n + 1):
					var c := c0 + Vector2i(dc, dr)
					if _class(kind, c) != 0 and not g.is_point_solid(c) and cell_pos(c).distance_to(pts[i]) < radius + CELL * 0.5:
						g.set_point_solid(c)
						blocked.append(c)
	return blocked


func _clear_of_nets(p: Vector2, clearance: float) -> bool:
	if nets == null:
		return true
	for net in nets.nets:
		for q in net.points():
			if q.distance_to(p) < clearance:
				return false
	return true


## Suoristus: ruutujen ketjusta jätetään pois välipisteet, joiden yli pääsee suoraan
func _smooth(kind: int, pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array([pts[0]])
	var i := 0
	while i < pts.size() - 1:
		var j := i + 1
		while j + 1 < pts.size() and pts[i].distance_to(pts[j + 1]) <= LOS_MAX and _line_clear(kind, pts[i], pts[j + 1]):
			j += 1
		out.append(pts[j])
		i = j
	return out


## Pääseekö suoraan: joka LOS_STEP metrin kohdalla kulkukelpoista vettä, eikä
## syvän veden osuudelta oikaista laiturin matalaan lähiveteen. Matalassa ja
## kapeassa vedessä (ruutu on karkea) myös todellinen syvyys suoralla ja
## LINE_SWAY metrin päässä sen sivuilla, koska vene heilahtaa hieman reitiltä.
func _line_clear(kind: int, p: Vector2, q: Vector2) -> bool:
	var shallow_ok := _class(kind, cell_of(p)) == 2 or _class(kind, cell_of(q)) == 2
	var n := ceili(p.distance_to(q) / LOS_STEP)
	var side := (q - p).normalized().orthogonal() * LINE_SWAY
	for s in range(n + 1):
		var a := p.lerp(q, float(s) / maxi(n, 1))
		var cls := _class(kind, cell_of(a))
		if cls == 0 or (cls == 2 and not shallow_ok):
			return false
		if cls == 2:
			for b in [a, a + side, a - side]:
				if lake.depth_at(b.x, b.y) < APPROACH_DEPTH:
					return false
	return true


func _deep_cell(kind: int) -> Vector2:
	var cells: PackedInt32Array = _deep[kind]
	var id := cells[_rng.randi() % cells.size()]
	return cell_pos(Vector2i(id % _gcols, id / _gcols))


## Satunnainen syvän veden kalapaikka etäisyydellä [near_min, near_max] pisteestä,
## jonne pääsee pisteestä reach (laiturin lähtöpiste): lähellä voi olla erillinen
## lampare, johon ei ole kulkukelpoista yhteyttä
func _random_spot(kind: int, from: Vector2, near_min: float, near_max: float, reach := Vector2.INF) -> Vector2:
	for i in 80:
		var p := _deep_cell(kind)
		if near_max < INF:
			p = from + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(near_min, near_max)
			if _class(kind, cell_of(p)) != 1:
				continue
		var d := p.distance_to(from)
		if d < near_min or d > near_max or p.distance_to(player_pos()) < SPOT_FROM_PLAYER or not _clear_of_nets(p, 30.0):
			continue
		if reach != Vector2.INF and not _connected(kind, p, reach):
			continue
		return p
	return Vector2.INF


## Ohiajon välipiste PASS_NEAR-etäisyydellä pelaajasta syvässä vedessä
func _near_player_point(kind: int) -> Vector2:
	if boat.on_ice:
		return Vector2.INF
	for i in 16:
		var p := boat.pos + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(PASS_NEAR.x, PASS_NEAR.y)
		if _class(kind, cell_of(p)) == 1:
			return p
	return Vector2.INF


# --- Peräaallot ----------------------------------------------------------------------

## Moottoriveneiden peräaallot kohdassa p (OtherBoat.wake_wave). Sama ruutu ja
## piste: laskettu tulos uudelleen (vene ja ääni kysyvät samaa).
func wakes_at(p: Vector2) -> Array:
	var frame := Engine.get_physics_frames()
	if frame == _wake_cache_frame and p == _wake_cache_p:
		return _wake_cache
	var list := []
	for b in boats:
		if b.kind == Kind.MOTOR:
			var w := b.wake_wave(p)
			if not w.is_empty():
				list.append(w)
	_wake_cache_frame = frame
	_wake_cache_p = p
	_wake_cache = list
	return list


## Peräaaltojen korkeus pisteessä p (lähellä kohtaa, jolle aallot haettiin)
static func wake_sum(wakes: Array, p: Vector2) -> float:
	var h := 0.0
	for w in wakes:
		var dir: Vector2 = w["dir"]
		h += w["amp"] * sin(w["omega"] * w["since"] - w["k"] * dir.dot(p - w["at"]))
	return h


## Peräaaltojen korkeus (verho) kohdassa p: aaltoääni voimistuu sen mukaan
func wake_amplitude(p: Vector2) -> float:
	var a := 0.0
	for w in wakes_at(p):
		a += absf(w["amp"])
	return a

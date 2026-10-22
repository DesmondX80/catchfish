class_name TackleBox
extends Node3D
## Kalapakki: muovinen kääntölokeropakki veneen pohjalla kalastajan edessä
## (keskituhdon ja etutuhdon välissä vasemmalla, saalis on oikealla). L avaa pakin: kansi nousee, lokerotasot kääntyvät sivuille ja kamera
## katsoo pakkia ylhäältä. Uistin tai onki valitaan klikkaamalla sen lokeroa;
## L, Esc tai oikea hiiri sulkee pakin. Talvella jäällä on pieni pilkkirasia.

signal opened
signal closed

## Kesän pakki: pohjan mitat (pituus, korkeus, leveys)
const SIZE := Vector3(0.36, 0.14, 0.2)
## Pakin -Z (kannen sarana) osoittaa keulaan, ja kalastaja katsoo pakkia perän puolelta
const ON_BOAT := Transform3D(Basis.IDENTITY, Vector3(-0.12, -0.13, -0.58))
## Talven pilkkirasia jäällä kalastajan vasemmalla puolella
const ICE_SIZE := Vector3(0.15, 0.035, 0.09)
const ON_ICE := Vector3(-0.6, 0.0, 0.4)
const PLASTIC := Color(0.2, 0.4, 0.27)
const TRAY := Color(0.7, 0.68, 0.6)
const HOVER := Color(0.98, 0.86, 0.35)
const OPEN_TIME := 0.5 # s

## Lokerot: tunniste, keskipiste ja koko (x, z) avatussa pakissa, taso (y)
## ja mallin asento. Vasen taso: lusikka, lippa, jigi; oikea: vaaput;
## pohjalla isot onget. Pilkkirasiassa kaksi lokeroa.
const SUMMER := [
	{"id": "lusikka", "tray": -1, "z": -0.066},
	{"id": "lippa", "tray": -1, "z": 0.0},
	{"id": "jigi", "tray": -1, "z": 0.066},
	{"id": "vaappu", "tray": 1, "z": -0.05},
	{"id": "syvavaappu", "tray": 1, "z": 0.05},
	{"id": "koho", "tray": 0, "z": -0.05},
	{"id": "pohja", "tray": 0, "z": 0.05},
]
const WINTER := [
	{"id": "pilkki", "x": -0.036},
	{"id": "tasuri", "x": 0.036},
]
## Lokerotason leveys (x) ja korkeus pohjan yläpuolella avattuna
const TRAY_W := 0.17
const TRAY_OUT := 0.2 # tason keskikohdan etäisyys pakin keskeltä avattuna

var boat: Boat
var fishing: Fishing
var is_open := false
var hovered := "" # hiiren alla olevan lokeron uistin
var compartments: Array = [] # {id, center: Vector3 (paikallinen), size: Vector2, floor: MeshInstance3D}
var _open_t := 0.0
var _winter := false
var _lid: Node3D
var _trays: Array[Node3D] = [] # [vasen, oikea]
var _lamp: OmniLight3D
var _layer: CanvasLayer
var _label: Label


func setup(boat_node: Boat, fishing_node: Fishing) -> void:
	boat = boat_node
	fishing = fishing_node
	top_level = true
	_build()


## Pakin paikka veneessä tai jäällä
func _placement() -> Transform3D:
	if boat.on_ice:
		return boat.global_transform * Transform3D(Basis.IDENTITY, ON_ICE)
	return boat.hull.global_transform * ON_BOAT


## Kameran paikka avattua pakkia katsottaessa: ylhäältä, hieman kalastajan puolelta.
## Lasketaan veneen tämänhetkisestä asennosta (ks. CatchTub.view_point).
func view_transform() -> Transform3D:
	var t := _placement()
	var height := 0.3 if _winter else 0.44
	var center := t * Vector3(0, (ICE_SIZE.y if _winter else SIZE.y) + 0.02, 0)
	var eye := center + Vector3.UP * height + t.basis.z.normalized() * height * 0.15
	return Transform3D(Basis.looking_at(center - eye, -t.basis.z.normalized()), eye)


func open() -> void:
	if is_open:
		return
	is_open = true
	hovered = ""
	_lamp.visible = true
	_layer.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_label()
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	hovered = ""
	_lamp.visible = false
	_layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


## Valitsee lokeron uistimen; onnistuessa pakki sulkeutuu
func choose(id: String) -> bool:
	var err := fishing.select_lure(id)
	if err != "":
		_label.text = err
		return false
	close()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		if event.is_action_pressed("lure_next") and GameInput.active() and fishing.held >= 0:
			if fishing.state == Fishing.State.READY:
				open()
			else:
				fishing.message.emit("Kelaa siima sisään ennen uistimen vaihtoa")
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("lure_next") or event.is_action_pressed("pause") or event.is_action_pressed("reel"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_hover(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hover(event.position)
		if hovered != "":
			choose(hovered)
		get_viewport().set_input_as_handled()


## Hiiren alla oleva lokero: lokeron kulmat projisoidaan ruudulle
func _hover(at: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	hovered = ""
	if _open_t < 0.9: # lokerot ovat vielä liikkeessä
		_update_label()
		return
	for c in compartments:
		var rect := Rect2()
		var first := true
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var size: Vector2 = c["size"]
			var holder: Node3D = c["holder"]
			var p: Vector3 = holder.global_transform * Vector3(corner.x * size.x / 2.0, 0, corner.y * size.y / 2.0)
			var s := cam.unproject_position(p)
			rect = Rect2(s, Vector2.ZERO) if first else rect.expand(s)
			first = false
		if rect.has_point(at):
			hovered = c["id"]
	_update_label()


func _update_label() -> void:
	for c in compartments:
		var mat: StandardMaterial3D = c["floor"].material_override
		mat.albedo_color = HOVER if c["id"] == hovered else TRAY
	var text := "Kalapakki – klikkaa uistinta, L tai Esc sulkee"
	if hovered != "":
		var l: Dictionary = Lures.all().filter(func(x): return x["id"] == hovered)[0]
		text = l["name"]
		if fishing.limited:
			text += "  (%d kpl)" % int(fishing.inventory.get(hovered, 0))
		if hovered == fishing.lure()["id"]:
			text += "  – vavassa nyt"
	_label.text = text


func _process(delta: float) -> void:
	if boat == null:
		return
	if boat.on_ice != _winter:
		_build()
	global_transform = _placement()
	_open_t = move_toward(_open_t, 1.0 if is_open else 0.0, delta / OPEN_TIME)
	var k := smoothstep(0.0, 1.0, _open_t)
	_lid.rotation.x = -k * (1.75 if not _winter else 1.9)
	if not _winter:
		# Lokerotasot nousevat ja kääntyvät sivuille (kääntövarret)
		for i in 2:
			var side := -1.0 if i == 0 else 1.0
			_trays[i].position = Vector3(side * lerpf(TRAY_W / 2.0 - 0.005, TRAY_OUT, k), SIZE.y - 0.03 + sin(k * PI) * 0.06 + k * 0.03, 0)


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, alpha := 1.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, alpha)
	mat.roughness = 0.55
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	m.mesh = b
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


## Avoin laatikko (pohja ja seinät), jonka yläreuna on y = size.y
func _tray_box(parent: Node3D, size: Vector3, color: Color, wall := 0.004, alpha := 1.0) -> void:
	_box(parent, Vector3(size.x, wall, size.z), Vector3(0, wall / 2.0, 0), color, alpha)
	for s in [-1.0, 1.0]:
		_box(parent, Vector3(wall, size.y, size.z), Vector3(s * (size.x - wall) / 2.0, size.y / 2.0, 0), color, alpha)
		_box(parent, Vector3(size.x, size.y, wall), Vector3(0, size.y / 2.0, s * (size.z - wall) / 2.0), color, alpha)


## Lokero: pohjalevy (korostuu hiiren alla) ja uistin kyljellään
func _compartment(parent: Node3D, id: String, center: Vector3, size: Vector2, tray: int) -> void:
	var holder := Node3D.new()
	holder.position = center
	parent.add_child(holder)
	var floor := _box(holder, Vector3(size.x - 0.006, 0.002, size.y - 0.006), Vector3(0, 0.001, 0), TRAY)
	var lure := MeshInstance3D.new()
	lure.mesh = LureModels.mesh(id)
	lure.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Uistin pituussuunnassa lokeroon; vaaput ja onget kyljellään, lusikat lappeellaan
	var basis := Basis(Vector3.UP, -PI / 2.0)
	if not id in ["lusikka", "lippa"]:
		basis = basis * Basis(Vector3.FORWARD, PI / 2.0)
	if id == "pilkki":
		basis = Basis(Vector3.UP, -PI / 2.0) * Basis(Vector3.FORWARD, PI / 2.0)
	var fit := minf(1.0, (size.x - 0.02) / LureModels.length(id))
	lure.transform = Transform3D(basis.scaled(Vector3.ONE * fit), Vector3(0, 0.012, 0))
	holder.add_child(lure)
	compartments.append({"id": id, "center": center, "size": size, "floor": floor, "tray": tray, "holder": holder})


func _build() -> void:
	for c in get_children():
		c.queue_free()
	compartments.clear()
	_trays.clear()
	_winter = boat.on_ice
	if _winter:
		_build_ice_box()
	else:
		_build_summer_box()
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0, 0.8, 0.2)
	_lamp.omni_range = 1.6
	_lamp.light_energy = 0.45
	_lamp.light_color = Color(1.0, 0.96, 0.88)
	_lamp.visible = is_open
	add_child(_lamp)
	_layer = CanvasLayer.new()
	_layer.layer = 5
	_layer.visible = is_open
	add_child(_layer)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.85))
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.06, 0.05, 0.75)
	bg.set_corner_radius_all(8)
	bg.set_content_margin_all(8)
	_label.add_theme_stylebox_override("normal", bg)
	_layer.add_child(_label)
	# Ruudun yläreunaan: alareunassa on HUD:n uistin- ja jarrutieto
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.offset_top = 24
	_label.offset_left = -360
	_label.offset_right = 360
	_update_label()


func _build_summer_box() -> void:
	# Pohja: avoin laatikko, jonka pohjalla on isojen onkien lokerot
	var base := Node3D.new()
	add_child(base)
	_tray_box(base, SIZE, PLASTIC, 0.006)
	_box(base, Vector3(0.004, 0.05, SIZE.z - 0.012), Vector3(-0.12, 0.025, 0), PLASTIC)
	_box(base, Vector3(0.004, 0.05, SIZE.z - 0.012), Vector3(0.12, 0.025, 0), PLASTIC)
	_box(base, Vector3(0.24, 0.04, 0.003), Vector3(0, 0.02, 0), TRAY)
	for c in SUMMER.filter(func(x): return x["tray"] == 0):
		_compartment(base, c["id"], Vector3(0, 0.006, c["z"]), Vector2(0.23, 0.095), 0)
	# Kahva ja lukot
	_box(base, Vector3(0.012, 0.03, 0.03), Vector3(0, SIZE.y - 0.02, SIZE.z / 2.0 + 0.004), Color(0.85, 0.75, 0.2))
	# Lokerotasot: kumpikin lepää kiinni ollessa pohjan päällä ja kääntyy sivulle
	for i in 2:
		var side := -1 if i == 0 else 1
		var tray := Node3D.new()
		add_child(tray)
		_tray_box(tray, Vector3(TRAY_W, 0.03, SIZE.z - 0.012), TRAY.darkened(0.08), 0.003)
		for c in SUMMER.filter(func(x): return x["tray"] == side):
			var n := SUMMER.filter(func(x): return x["tray"] == side).size()
			var depth := (SIZE.z - 0.012) / n
			_compartment(tray, c["id"], Vector3(0, 0.003, c["z"]), Vector2(TRAY_W - 0.006, depth), side)
		for k in SUMMER.filter(func(x): return x["tray"] == side).size() - 1:
			var n := SUMMER.filter(func(x): return x["tray"] == side).size()
			var z := -(SIZE.z - 0.012) / 2.0 + (SIZE.z - 0.012) / n * (k + 1)
			_box(tray, Vector3(TRAY_W, 0.022, 0.003), Vector3(0, 0.011, z), TRAY.darkened(0.08))
		# Kääntövarret pohjaan
		for s in [-1.0, 1.0]:
			_box(tray, Vector3(0.12, 0.006, 0.006), Vector3(-side * 0.06, -0.02, s * (SIZE.z / 2.0 + 0.003)), PLASTIC.darkened(0.2))
		_trays.append(tray)
	# Kansi saranoituna taakse (pakin -Z-reuna)
	_lid = Node3D.new()
	_lid.position = Vector3(0, SIZE.y, -SIZE.z / 2.0)
	add_child(_lid)
	_box(_lid, Vector3(SIZE.x, 0.012, SIZE.z), Vector3(0, 0.006, SIZE.z / 2.0), PLASTIC.lightened(0.05))
	_box(_lid, Vector3(0.14, 0.02, 0.025), Vector3(0, 0.022, SIZE.z / 2.0), Color(0.12, 0.12, 0.12)) # kahva


func _build_ice_box() -> void:
	var base := Node3D.new()
	add_child(base)
	_tray_box(base, ICE_SIZE, Color(0.25, 0.3, 0.55), 0.003)
	_box(base, Vector3(0.003, ICE_SIZE.y, ICE_SIZE.z), Vector3(0, ICE_SIZE.y / 2.0, 0), Color(0.25, 0.3, 0.55))
	for c in WINTER:
		_compartment(base, c["id"], Vector3(c["x"], 0.003, 0), Vector2(0.068, ICE_SIZE.z - 0.008), 1)
	_lid = Node3D.new()
	_lid.position = Vector3(0, ICE_SIZE.y, -ICE_SIZE.z / 2.0)
	add_child(_lid)
	_box(_lid, Vector3(ICE_SIZE.x, 0.003, ICE_SIZE.z), Vector3(0, 0.0015, ICE_SIZE.z / 2.0), Color(0.8, 0.88, 0.95), 0.35)

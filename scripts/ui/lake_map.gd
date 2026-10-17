class_name LakeMap
extends Control
## Järven kartta: aloituspaikkojen valinta valikossa ja veneen sijainti pelissä.
## Pohjoinen on ylhäällä. Karttakuva tehdään työkalulla tools/build_lake.py.

signal start_clicked(index: int)

var lake: LakeData
var texture: Texture2D
var select_mode := false # true = aloituspaikat ovat klikattavia
var boat: Boat # pelissä: veneen sijainti ja suunta
var hovered := -1
var _font: Font


func setup(lake_data: LakeData) -> void:
	lake = lake_data
	texture = load("res://assets/lake/map.png")
	_font = get_theme_default_font()
	mouse_filter = Control.MOUSE_FILTER_STOP if select_mode else Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _map_rect() -> Rect2:
	var tex_size := texture.get_size()
	var scale := minf(size.x / tex_size.x, size.y / tex_size.y)
	var draw_size := tex_size * scale
	return Rect2((size - draw_size) / 2.0, draw_size)


func world_to_map(p: Vector2) -> Vector2:
	var r := _map_rect()
	var world := lake.world_size()
	var uv := Vector2((p.x - lake.origin_x) / world.x, (p.y - lake.origin_z) / world.y)
	return r.position + uv * r.size


func _start_point(i: int) -> Vector2:
	var s: Dictionary = lake.starts[i]
	return world_to_map(Vector2(s["x"], s["z"]))


func _process(_delta: float) -> void:
	if boat != null and is_visible_in_tree():
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not select_mode or lake == null:
		return
	if event is InputEventMouseMotion:
		var nearest := -1
		var best := 22.0
		for i in lake.starts.size():
			var d := _start_point(i).distance_to(event.position)
			if d < best:
				best = d
				nearest = i
		if nearest != hovered:
			hovered = nearest
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and hovered >= 0:
		start_clicked.emit(hovered)


func _text(pos: Vector2, text: String, font_size: int, color := Color.WHITE) -> void:
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.75))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	if lake == null or texture == null:
		return
	var r := _map_rect()
	draw_texture_rect(texture, r, false)
	draw_rect(r, Color(0, 0, 0, 0.6), false, 2.0)
	var px_per_m := r.size.x / lake.world_size().x

	# Paikannimet
	for place in lake.places:
		var p := world_to_map(Vector2(place["x"], place["z"]))
		if r.has_point(p):
			_text(p - Vector2(_font.get_string_size(place["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x / 2.0, 0), place["name"], 12, Color(1, 1, 1, 0.85))

	# Aloituspaikat
	for i in lake.starts.size():
		var p := _start_point(i)
		var big := select_mode
		var radius := (13.0 if i == hovered else 10.0) if big else 6.0
		draw_circle(p, radius + 2.0, Color(0, 0, 0, 0.7))
		draw_circle(p, radius, Color(1.0, 0.8, 0.2) if i == hovered else Color(0.95, 0.55, 0.15))
		var num := str(i + 1)
		var fs := 15 if big else 10
		draw_string(_font, p + Vector2(-_font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / 2.0, fs * 0.36), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.BLACK)
		if big:
			_text(p + Vector2(radius + 6.0, 5.0), lake.starts[i]["name"], 15)

	# Vene: kolmio keula edellä
	if boat != null:
		var p := world_to_map(boat.pos)
		var fwd := boat.forward()
		var side := Vector2(-fwd.y, fwd.x)
		var tip := p + fwd * 13.0
		var pts := PackedVector2Array([tip, p - fwd * 7.0 + side * 7.0, p - fwd * 7.0 - side * 7.0])
		draw_colored_polygon(pts, Color(1, 0.25, 0.2))
		pts.append(tip)
		draw_polyline(pts, Color.WHITE, 2.0)

	# Pohjoisnuoli ja mittakaava
	var n := r.position + Vector2(r.size.x - 34.0, 40.0)
	draw_colored_polygon(PackedVector2Array([n + Vector2(0, -22), n + Vector2(9, 6), n + Vector2(-9, 6)]), Color.WHITE)
	_text(n + Vector2(-6, 26), "N", 16)
	var bar := 500.0 * px_per_m
	var b0 := r.position + Vector2(20.0, r.size.y - 24.0)
	draw_rect(Rect2(b0, Vector2(bar, 6.0)), Color.WHITE)
	draw_rect(Rect2(b0, Vector2(bar / 2.0, 6.0)), Color.BLACK)
	_text(b0 + Vector2(0, -6), "500 m", 13)

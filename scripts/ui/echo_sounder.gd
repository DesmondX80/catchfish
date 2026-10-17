class_name EchoSounder
extends Control
## Kaikuluotain: pohjaprofiili ja kalakaaret veneen alta, uusin tieto oikealla.

const SAMPLES := 160
const INTERVAL := 0.25

var boat: Boat
var population: FishPopulation
var range_m := 6.0
var _depths: Array[float] = []
var _fish: Array = [] # [[sample_index, depth, weight], ...]
var _timer := 0.0
var _sample := 0


func _ready() -> void:
	custom_minimum_size = Vector2(300, 170)
	for i in SAMPLES:
		_depths.append(0.0)


func _process(delta: float) -> void:
	if boat == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = INTERVAL
	_sample += 1
	var depth := boat.depth_below()
	_depths.pop_front()
	_depths.append(depth)
	for f in population.fish_under(boat.pos, depth):
		_fish.append([_sample, f[0], f[1]])
	while _fish.size() > 0 and _fish[0][0] < _sample - SAMPLES:
		_fish.pop_front()
	range_m = maxf(3.0, ceilf((_depths.max() + 1.0) / 2.0) * 2.0)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.02, 0.05, 0.12, 0.85))
	var w := size.x / SAMPLES
	var scale_y := (size.y - 18.0) / range_m
	# Pohja
	for i in SAMPLES:
		var y := 14.0 + _depths[i] * scale_y
		draw_rect(Rect2(i * w, y, w + 1.0, size.y - y), Color(0.75, 0.4, 0.1))
		draw_rect(Rect2(i * w, y, w + 1.0, 3.0), Color(1.0, 0.85, 0.3))
	# Kalat kaarina, isompi kala = isompi kaari
	for f in _fish:
		var x: float = (f[0] - (_sample - SAMPLES)) * w
		var y: float = 14.0 + f[1] * scale_y
		var s: float = clampf(3.0 + f[2] * 2.5, 3.0, 12.0)
		draw_arc(Vector2(x, y + s * 0.5), s, PI * 1.15, PI * 1.85, 8, Color(0.3, 1.0, 0.4), 2.0)
	# Syvyysasteikko
	var font := get_theme_default_font()
	for d in range(0, int(range_m) + 1, 2):
		var y := 14.0 + d * scale_y
		draw_line(Vector2(0, y), Vector2(6, y), Color(1, 1, 1, 0.5))
		draw_string(font, Vector2(8, y + 4), "%d m" % d, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
	draw_string(font, Vector2(size.x - 70, 12), "%.1f m" % _depths[-1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

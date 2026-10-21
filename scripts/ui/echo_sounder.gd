class_name EchoSounder
extends Control
## Kaikuluotain kuten oikeissa laitteissa: kuva piirtyy sarakkeittain, uusin
## oikealla. Kalan kaiku piirretään vinoetäisyydelle (keilan reunalla kala on
## kauempana kuin suoraan alla), joten veneen ajaessa kalan yli siitä piirtyy
## kaari. Pohjan laatu erottuu kaiusta: kova pohja antaa kirkkaan, terävän
## kaiun ja toisen heijastuksen kaksinkertaisessa syvyydessä, muta pehmeän ja
## himmeän kaiun, ja vesikasvillisuus näkyy pohjasta nousevina tupsuina.

const SAMPLES := 160
const INTERVAL := 0.25
const TOP := 14.0 # px: syvyysasteikon nolla
const BOTTOM_NAMES := ["kova", "muta", "kasvillisuus"]

var boat: Boat
var population: FishPopulation
var range_m := 6.0
## Sarakkeet: {depth, bottom, fish: [[vinoetäisyys, voimakkuus], ...], seed}
var _columns: Array[Dictionary] = []
var _timer := 0.0
var _sample := 0


func _ready() -> void:
	custom_minimum_size = Vector2(300, 170)
	for i in SAMPLES:
		_columns.append({"depth": 0.0, "bottom": LakeData.Bottom.MUD, "fish": [], "seed": i})


func _process(delta: float) -> void:
	if boat == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = INTERVAL
	_sample += 1
	var depth := boat.depth_below()
	var radius := 1.0 + depth * 0.35
	var echoes := []
	for f in population.fish_under(boat.pos, depth):
		var off: float = f[2] / radius # 0 = keilan keskellä, 1 = reunalla
		var slant := sqrt(f[0] * f[0] + f[2] * f[2])
		# Iso kala ja keilan keskellä oleva kala kaikuvat voimakkaimmin
		var strength := clampf(0.35 + f[1] * 0.35, 0.3, 1.0) * (1.0 - 0.6 * off * off)
		echoes.append([slant, strength])
	_columns.pop_front()
	_columns.append({
		"depth": depth,
		"bottom": boat.lake.bottom_at(boat.pos.x, boat.pos.y) if depth > 0.0 else LakeData.Bottom.HARD,
		"fish": echoes,
		"seed": _sample,
	})
	var deepest := 0.0
	for c in _columns:
		deepest = maxf(deepest, c["depth"])
	range_m = maxf(3.0, ceilf((deepest + 1.0) / 2.0) * 2.0)
	queue_redraw()


## Kaiun väri voimakkuuden mukaan: heikko sininen, vihreä, keltainen, voimakas punainen
static func echo_color(strength: float) -> Color:
	var s := clampf(strength, 0.0, 1.0)
	if s < 0.33:
		return Color(0.15, 0.35, 0.9).lerp(Color(0.2, 0.9, 0.35), s / 0.33)
	if s < 0.66:
		return Color(0.2, 0.9, 0.35).lerp(Color(1.0, 0.9, 0.2), (s - 0.33) / 0.33)
	return Color(1.0, 0.9, 0.2).lerp(Color(0.95, 0.2, 0.1), (s - 0.66) / 0.34)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.05, 0.12, 0.85))
	var w := size.x / SAMPLES
	var scale_y := (size.y - TOP - 4.0) / range_m
	for i in SAMPLES:
		_draw_column(_columns[i], i * w, w + 1.0, scale_y)
	# Syvyysasteikko
	var font := get_theme_default_font()
	for d in range(0, int(range_m) + 1, 2):
		var y := TOP + d * scale_y
		draw_line(Vector2(0, y), Vector2(6, y), Color(1, 1, 1, 0.5))
		draw_string(font, Vector2(8, y + 4), "%d m" % d, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
	var last: Dictionary = _columns[-1]
	draw_string(font, Vector2(size.x - 70, 12), "%.1f m" % last["depth"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	if last["depth"] > 0.0:
		draw_string(font, Vector2(size.x - 110, size.y - 6), "Pohja: " + BOTTOM_NAMES[last["bottom"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.75))


func _draw_column(c: Dictionary, x: float, w: float, scale_y: float) -> void:
	var depth: float = c["depth"]
	var seed: int = c["seed"]
	var bottom_y := TOP + depth * scale_y
	var floor_y := size.y
	# Pintahäiriö: pientä sinistä rakeisuutta aivan pinnassa
	if _rand(seed, 1) < 0.5:
		draw_rect(Rect2(x, TOP + _rand(seed, 2) * 0.3 * scale_y, w, 1.5), Color(0.2, 0.4, 0.9, 0.5))
	# Kalat
	for e in c["fish"]:
		var y: float = TOP + e[0] * scale_y
		if y < bottom_y - 2.0:
			var h: float = 2.0 + e[1] * 3.0
			draw_rect(Rect2(x, y - h * 0.5, w, h), echo_color(e[1]))
	if depth <= 0.0:
		return
	match c["bottom"]:
		LakeData.Bottom.HARD:
			# Kova pohja: kirkas punainen reuna, paksu voimakas kaiku ja toinen heijastus
			draw_rect(Rect2(x, bottom_y, w, floor_y - bottom_y), Color(0.45, 0.22, 0.08))
			var band := maxf(5.0, 0.35 * scale_y)
			draw_rect(Rect2(x, bottom_y + 2.0, w, band), echo_color(0.8))
			draw_rect(Rect2(x, bottom_y, w, 2.5), echo_color(1.0))
			var second := TOP + depth * 2.0 * scale_y
			if second < floor_y - 2.0:
				draw_rect(Rect2(x, second, w, 2.5), Color(echo_color(0.55), 0.7))
		LakeData.Bottom.MUD:
			# Muta: pehmeä, himmeämpi ja epäterävä kaiku, joka vaimenee syvemmälle
			draw_rect(Rect2(x, bottom_y, w, floor_y - bottom_y), Color(0.3, 0.17, 0.1))
			draw_rect(Rect2(x, bottom_y - 1.5, w, 2.0), Color(echo_color(0.35), 0.6))
			draw_rect(Rect2(x, bottom_y, w, maxf(4.0, 0.25 * scale_y)), echo_color(0.5))
		LakeData.Bottom.WEEDS:
			# Kasvillisuus: pohja kuin muta, ja sen päällä eri pituisia vihreitä tupsuja
			draw_rect(Rect2(x, bottom_y, w, floor_y - bottom_y), Color(0.32, 0.18, 0.1))
			draw_rect(Rect2(x, bottom_y, w, maxf(4.0, 0.25 * scale_y)), echo_color(0.55))
			if _rand(seed, 3) < 0.8:
				var tall := minf(depth * 0.6, 0.2 + _rand(seed, 4) * 0.9) * scale_y
				draw_rect(Rect2(x, bottom_y - tall, w, tall), Color(echo_color(0.3), 0.85))
				draw_rect(Rect2(x, bottom_y - tall, w, 2.0), echo_color(0.45))


## Sarakkeen pysyvä satunnaisluku 0..1 (kuva ei välky uudelleenpiirrossa)
static func _rand(seed: int, k: int) -> float:
	var h := sin(seed * 12.9898 + k * 78.233) * 43758.5453
	return h - floorf(h)

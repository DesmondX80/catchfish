extends Node
## Suorituskykytesti: mittaa latausajan ja ruudun keskimääräisen käsittelyajan.
##   godot --headless --fixed-fps 30 -- --perftest [--perftest-lines]
## --perftest-lines: molemmat vavat telineissä, siimat vedessä veneen perässä
## (siiman simulaation ja piirron kustannus, CATCHFISH-86)

var _frame := 0
var _t := 0
var _lines := false


func _ready() -> void:
	_lines = "--perftest-lines" in OS.get_cmdline_user_args()


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == 2 and _lines:
		_put_lines()
	if _frame == 30:
		_t = Time.get_ticks_usec()
	elif _frame == 630:
		print("Lataus %d ms, keskimäärin %.2f ms/ruutu (pelilogiikka, ei piirtoa)%s" % [get_parent().load_ms, (Time.get_ticks_usec() - _t) / 600000.0, " – kaksi siimaa vedessä" if _lines else ""])
		get_tree().quit()


## Kaksi uistinta veneen perään (vavat telineissä, kädet vapaina)
func _put_lines() -> void:
	var main := get_parent()
	var f: Fishing = main.fishing
	var boat: Boat = main.boat
	var lake: LakeData = main.lake
	# Suunta, jossa veneen perässä on vettä
	var back := -boat.forward()
	for k in 16:
		var d := back.rotated(TAU * k / 16.0)
		var p := boat.pos + d * 25.0
		if lake.is_water(p.x, p.y) and lake.is_water(boat.pos.x + d.x * 10.0, boat.pos.y + d.y * 10.0):
			back = d
			break
	for i in 2:
		f._swap_to(i)
		var at := boat.pos + back * (18.0 + 6.0 * i) + Vector2(-back.y, back.x) * (1.5 if i == 0 else -1.5)
		f.state = Fishing.State.RETRIEVING
		f.in_holder = true
		f.lure_pos = Vector3(at.x, -0.5, at.y)
		f._prev_lure = f.lure_pos
		f.line_out = f.rod_tip().distance_to(f.lure_pos) + 2.0 # löysää: osa lepää pinnalla
	f.held = -1
	f._swap_to(0)

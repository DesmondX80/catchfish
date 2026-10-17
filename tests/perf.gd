extends Node
## Suorituskykytesti: mittaa latausajan ja ruudun keskimääräisen käsittelyajan.
##   godot --headless --fixed-fps 30 -- --perftest

var _frame := 0
var _t := 0


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == 30:
		_t = Time.get_ticks_usec()
	elif _frame == 630:
		print("Lataus %d ms, keskimäärin %.2f ms/ruutu (pelilogiikka, ei piirtoa)" % [get_parent().load_ms, (Time.get_ticks_usec() - _t) / 600000.0])
		get_tree().quit()

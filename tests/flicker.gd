extends Node
## Mittaa veden välkkymistä: kahden peräkkäisen ruudun keskimääräinen
## pikseliero kuvan alaosassa (vesi), kun kamera on paikallaan.
##   godot --fixed-fps 30 --resolution 640x360 -- --flicker

var _frame := 0
var _prev: Image
var _diffs: Array[float] = []


func _ready() -> void:
	var main := get_parent()
	main.sky.minutes = 12.0 * 60.0
	main.camera_rig.pitch = 0.12
	main.camera_rig.distance = 6.0
	main.camera_rig.yaw = main.boat.yaw + 0.3


func _process(_delta: float) -> void:
	_frame += 1
	if _frame < 20:
		return
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if _prev != null:
		var total := 0.0
		var n := 0
		for y in range(img.get_height() / 2, img.get_height(), 3):
			for x in range(0, img.get_width(), 3):
				var a := img.get_pixel(x, y)
				var b := _prev.get_pixel(x, y)
				total += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
				n += 1
		_diffs.append(total / n * 255.0 / 3.0)
	_prev = img
	if _diffs.size() >= 10:
		var avg := 0.0
		for d in _diffs:
			avg += d
		print("Välkyntä: keskimäärin %.2f / 255 pikseliä kohden ruutujen välillä (max %.2f)" % [avg / _diffs.size(), _diffs.max()])
		get_tree().quit()

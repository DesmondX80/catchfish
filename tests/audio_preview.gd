extends Node
## Nauhoittaa pelin äänistä näytteen WAV-tiedostoksi:
##   godot -- --audio-preview=/polku/naute.wav
## Kohtaukset: moottorin käynnistys ja ajo, sammutus, soutu, heitto ja kelaus.

var _path := ""
var _record: AudioEffectRecord
var _t := 0.0
var _step := 0
var main: Node


func _ready() -> void:
	main = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--audio-preview="):
			_path = arg.split("=")[1]
	GameInput.force_active = true
	main.hud.set_paused_view(false)
	main.sky.minutes = 21.0 * 60.0 # ilta
	_record = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, _record)
	_record.set_recording_active(true)


func _press(action: String, pressed := true) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _tap(action: String) -> void:
	_press(action)
	_press(action, false)


func _process(delta: float) -> void:
	_t += delta
	var events := [
		[1.0, func(): _tap("motor_toggle")],
		[3.5, func(): _press("boat_forward")],
		[7.0, func(): _press("boat_forward", false)],
		[11.0, func(): _press("boat_back")],
		[13.5, func(): _press("boat_back", false); _tap("motor_toggle")],
		[16.0, func(): _press("boat_forward")],
		[24.0, func(): _press("boat_forward", false); _tap("anchor_toggle")],
		[26.0, func(): _press("cast")],
		[27.0, func(): _press("cast", false)],
		[30.0, func(): _press("reel")],
		[38.0, func(): _press("reel", false)],
		[40.0, func(): _finish()],
	]
	while _step < events.size() and _t >= events[_step][0]:
		events[_step][1].call()
		_step += 1


func _finish() -> void:
	_record.set_recording_active(false)
	var rec := _record.get_recording()
	if rec:
		rec.save_to_wav(_path)
		print("Nauhoitettu %.1f s -> %s" % [rec.get_length(), _path])
	else:
		print("Nauhoitus epäonnistui")
	get_tree().quit()

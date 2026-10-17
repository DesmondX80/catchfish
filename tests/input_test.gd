extends Node
## Regressiotesti oikeilla hiiren klikkauksilla (hiiri kaapattuna kuten pelissä):
## väsytetty kala haavitaan klikkauksella, seuraava klikkaus sulkee saalisikkunan
## ja sitä seuraava painallus aloittaa heiton.
##   godot -- --inputtest   (vaatii ikkunan, jotta hiiren voi kaapata)

var _frame := 0
var _step := 0
var _log: Array[String] = []
var main: Node


func _ready() -> void:
	main = get_parent()
	main.hud.set_paused_view(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _mouse(pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	# Kaapattu hiiri on ikkunan keskellä; koordinaatit ikkunan pikseleinä
	var center := Vector2(DisplayServer.window_get_size()) / 2.0
	Input.warp_mouse(center)
	ev.position = center
	ev.global_position = center
	Input.parse_input_event(ev)


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s (tila %d)" % ["OK  " if ok else "VIRHE", name, main.fishing.state])


func _process(_delta: float) -> void:
	_frame += 1
	var f: Fishing = main.fishing
	match _frame:
		10:
			_check("hiiri kaapattu", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
			# Väsytetty hauki veneen vieressä
			var idx := 0
			f._fish_index = idx
			f._fish = main.population.fish[idx]
			f._stamina = 0.1
			f.line_out = 2.0
			f._fish_pos = f.rod_tip() + Vector3(1.0, -1.5, 0.5)
			f._fish_pos.y = -0.3
			f.state = Fishing.State.FIGHT
		14:
			_check("haavintakehote näkyy", f.landing_ready())
			_mouse(true)
		15:
			_mouse(false)
		18:
			_check("kala haavissa ja saalisikkuna auki", f.state == Fishing.State.LANDED and main.hud._catch_panel.visible)
			_mouse(true)
		19:
			_mouse(false)
		22:
			_check("klikkaus sulki saalisikkunan, valmiina heittoon", f.state == Fishing.State.READY)
			_mouse(true)
		30:
			_check("painallus aloitti heiton latauksen", f.state == Fishing.State.CHARGING)
			_mouse(false)
		34:
			_check("heitto lähti", f.state == Fishing.State.FLYING or f.state == Fishing.State.RETRIEVING)
			var failed := _log.any(func(l): return l.begins_with("VIRHE"))
			for l in _log:
				print(l)
			get_tree().quit(1 if failed else 0)

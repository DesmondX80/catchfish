extends Node
## Näppäinasetukset. Määritellään koodissa fyysisinä näppäiminä, jotta
## WASD toimii samoin suomalaisella ja muilla näppäimistöasetteluilla.

const KEYS := {
	"boat_forward": [KEY_W, KEY_UP],
	"boat_back": [KEY_S, KEY_DOWN],
	"boat_left": [KEY_A, KEY_LEFT],
	"boat_right": [KEY_D, KEY_RIGHT],
	"motor_toggle": [KEY_Q],
	"anchor_toggle": [KEY_X],
	"lure_next": [KEY_L],
	"rod_holder": [KEY_R],
	"drag_up": [KEY_E],
	"drag_down": [KEY_C],
	"reel_fast": [KEY_SHIFT],
	"twitch": [KEY_SPACE],
	"time_speed": [KEY_T],
	"catch_log": [KEY_TAB],
	"help": [KEY_F1, KEY_H],
	"pause": [KEY_ESCAPE],
	"mute": [KEY_M],
	"map": [KEY_K],
}

const MOUSE := {
	"cast": MOUSE_BUTTON_LEFT,
	"reel": MOUSE_BUTTON_RIGHT,
}


## Automaattitestit ohjaavat peliä ilman kaapattua hiirtä
var force_active := false


## Onko pelin ohjaus käytössä (hiiri kaapattu peliin)
func active() -> bool:
	return force_active or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	for action in KEYS:
		_ensure_action(action)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action in MOUSE:
		_ensure_action(action)
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE[action]
		InputMap.action_add_event(action, ev)


func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

class_name AlleyCatControls
extends Controls
## The controls HUD for the Alley Cat demo: the [Controls] addon
## ([url]https://github.com/kirbycope/godot-controls[/url]) with Alley Cat's own actions on its slots.
##
## The slots are not set here. They are set in [code]scenes/alley_cat_controls.tscn[/code], an
## inherited scene, and picked from the list the game publishes in
## [code]resources/alley_cat_inputs.tres[/code], so which action sits on which button and what each
## one is called are inspector fields. Those actions are what [AlleyCat] reads, so the scene is the
## mapping rather than a picture of one.
##
## What is left here is the two things the addon leaves to the game: the keyboard key behind each
## action, so the HUD's keyboard art names the key the game itself answers to, and the words for the
## setup questions, which the same buttons answer differently.

## What each slot's action answers to besides the button it is drawn on. The addon registers these,
## so the HUD lights up for a key press as well as a pad press and its keyboard art tells the truth,
## and because the game reads these actions, binding something here really does bind it.
##
## Every button does exactly the one thing drawn on it. The d-pad is the skill menu, not a second way
## to walk: the game asks that menu in text and a pad has no letters, so those four need a home, and
## putting the directions on both clusters draws the player two identical d-pads and lies about one.
const BINDINGS: Dictionary = {
	"button_0": {"keys": [KEY_ALT]},
	"button_1": {"keys": [KEY_S]},
	"button_2": {"keys": [KEY_N]},
	"button_3": {"keys": [KEY_Y]},
	"button_4": {"keys": [KEY_ESCAPE]},
	"button_6": {"keys": [KEY_M]},
	"button_11": {"keys": [KEY_K]},
	"button_12": {"keys": [KEY_H]},
	"button_13": {"keys": [KEY_T]},
	"button_14": {"keys": [KEY_A]},
	"move_up": {"keys": [KEY_UP]},
	"move_down": {"keys": [KEY_DOWN]},
	"move_left": {"keys": [KEY_LEFT]},
	"move_right": {"keys": [KEY_RIGHT]},
}

## What the buttons mean while the game is still asking its setup questions. It asks them in text and
## a pad has no letters, so the face buttons and the shoulders answer them; [method Controls.set_labels]
## is what the addon offers for exactly this, and [method Controls.reset_labels] puts the scene's own
## words back when play starts.
const SETUP_LABELS: Dictionary = {
	"button_0": "Start",
	"button_1": "",
	"button_2": "No",
	"button_3": "Yes",
	"button_4": "",
	"button_6": "",
	"button_11": "Kitten",
	"button_12": "House Cat",
	"button_13": "Tomcat",
	"button_14": "Alley Cat",
	"left_joystick": "",
}

## The label on the HUD for each slot named in [constant SETUP_LABELS].
const LABEL_PROPERTIES: Dictionary = {
	"button_0": "joypad_button_0_label",
	"button_1": "joypad_button_1_label",
	"button_2": "joypad_button_2_label",
	"button_3": "joypad_button_3_label",
	"button_4": "joypad_button_4_label",
	"button_6": "joypad_button_6_label",
	"button_11": "joypad_button_11_label",
	"button_12": "joypad_button_12_label",
	"button_13": "joypad_button_13_label",
	"button_14": "joypad_button_14_label",
	"left_joystick": "left_joystick_label",
}

var _setting_up: bool = false ## Whether the setup words are the ones currently up.


func _ready() -> void:
	# The addon registers extra_actions before it fills in the gaps itself, and a subclass sets them
	# here rather than from a parent, because a child is ready before whatever owns it.
	for slot: String in BINDINGS:
		var action: StringName = get(&"action_" + slot)
		if action != &"":
			extra_actions[String(action)] = BINDINGS[slot]
	super()
	# Changing device redraws the HUD from the scene's own text, and so does a world prompt handing
	# its label back, so the setup words have to go on again afterwards or they are lost the moment
	# the player picks up a pad mid-question.
	contextual_labels_requested.connect(_apply_labels)
	input_type_changed.connect(func(_input_type: InputType) -> void: _apply_labels())


## Swaps between the setup words and the scene's own. The same buttons mean different things on the
## game's two screens, and the HUD has to say which.
func set_setting_up(value: bool) -> void:
	if _setting_up == value:
		return
	_setting_up = value
	_apply_labels()


## Puts the words for whichever screen the game is on back onto the buttons.
func _apply_labels() -> void:
	if not _setting_up:
		reset_labels()
		return
	var texts: Dictionary = {}
	for slot: String in SETUP_LABELS:
		texts[get(LABEL_PROPERTIES[slot])] = SETUP_LABELS[slot]
	set_labels(texts)

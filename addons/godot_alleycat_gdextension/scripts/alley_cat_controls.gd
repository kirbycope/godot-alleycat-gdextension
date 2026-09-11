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

## The key behind each slot's action. The addon registers these alongside the button the slot is drawn
## on, so the HUD lights up for a key press as well as a pad press, and its keyboard art tells the
## truth. The game reads these actions, so binding a key here really does bind it.
const KEYS: Dictionary = {
	"button_0": KEY_ALT,
	"button_1": KEY_S,
	"button_2": KEY_N,
	"button_3": KEY_Y,
	"button_4": KEY_ESCAPE,
	"button_6": KEY_M,
	"button_9": KEY_K,
	"button_10": KEY_H,
	"axis_4_plus": KEY_T,
	"axis_5_plus": KEY_A,
	"button_11": KEY_UP,
	"button_12": KEY_DOWN,
	"button_13": KEY_LEFT,
	"button_14": KEY_RIGHT,
	"move_up": KEY_UP,
	"move_down": KEY_DOWN,
	"move_left": KEY_LEFT,
	"move_right": KEY_RIGHT,
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
	"button_9": "Kitten",
	"button_10": "House Cat",
	"axis_4_plus": "Tomcat",
	"axis_5_plus": "Alley Cat",
	"button_11": "",
	"button_12": "",
	"button_13": "",
	"button_14": "",
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
	"button_9": "joypad_button_9_label",
	"button_10": "joypad_button_10_label",
	"axis_4_plus": "joypad_axis_4_plus_label",
	"axis_5_plus": "joypad_axis_5_plus_label",
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
	for slot: String in KEYS:
		var action: StringName = get(&"action_" + slot)
		if action != &"":
			extra_actions[String(action)] = {"keys": [KEYS[slot]]}
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

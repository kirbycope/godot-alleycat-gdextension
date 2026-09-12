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
	# Jump is the bottom face button and the space bar wherever Godot is concerned, and in Alley Cat
	# jumping is pushing up, so the slot is on alleycat_up and the key over it is Space.
	"button_0": {"keys": [KEY_SPACE]},
	"button_1": {"keys": [KEY_S]},
	"button_2": {"keys": [KEY_N]},
	"button_3": {"keys": [KEY_Y]},
	"button_4": {"keys": [KEY_ESCAPE]},
	"button_6": {"keys": [KEY_M]},
	# Rewind is the host's, not the game's, but it earns a place on the HUD because a player has no
	# other way to find out it exists.
	"axis_4_plus": {"keys": [KEY_BACKSPACE]},
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
	"button_0": "",
	"button_1": "",
	"button_2": "No",
	"button_3": "Yes",
	"button_4": "",
	"button_6": "",
	# Rewinding works on the setup screens as well as in play, so it keeps its name there. Anything
	# set_labels is not told about is cleared, which is how it lost it.
	"axis_4_plus": "Rewind",
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
	"axis_4_plus": "joypad_axis_4_plus_label",
	"button_11": "joypad_button_11_label",
	"button_12": "joypad_button_12_label",
	"button_13": "joypad_button_13_label",
	"button_14": "joypad_button_14_label",
	"left_joystick": "left_joystick_label",
}

## Which of the game's screens is up. The same buttons mean different things on each, and most of them
## mean nothing at all on two of the three.
enum Stage {
	PLAYING, ## The game is drawing and the player is moving the cat.
	ASKING_JOYSTICK, ## "Do you want to use a joystick (Y/N)?"
	ASKING_SKILL, ## "Please select your skill level", answered on the d-pad.
}

## What each screen actually uses, as the [Controls] nodes themselves. A node named here is shown on that
## screen and hidden on the others: the skill menu is asked once and never again, and the yes/no pair
## answers a question that is over before play starts, so leaving either up draws buttons that do nothing.
## Anything named on no screen - the face buttons, the stick - is left exactly as the addon has it.
##
## The d-pad is five nodes and not four: the cross behind the buttons is drawn by the HUD as well, and
## hiding the buttons without it leaves an empty cross on screen. Its keyboard faces go with them, because
## the skill menu is the same question whichever the player is holding.
const STAGE_NODES: Dictionary = {
	Stage.ASKING_JOYSTICK: ["joypad_button_2", "joypad_button_3"],
	Stage.ASKING_SKILL: [
		"dpad_base", "joypad_button_11", "joypad_button_12", "joypad_button_13", "joypad_button_14",
		"key_i", "key_j", "key_k", "key_l",
	],
	Stage.PLAYING: [],
}

## The d-pad nodes the addon only ever shows for a pad, and the keyboard faces it only ever shows for a
## keyboard. Naming a screen's nodes is not enough on its own: a screen can want the d-pad without wanting
## both of the HUD's drawings of it.
const JOYPAD_ONLY_NODES: PackedStringArray = [
	"dpad_base", "joypad_button_11", "joypad_button_12", "joypad_button_13", "joypad_button_14",
]
const KEYBOARD_ONLY_NODES: PackedStringArray = ["key_i", "key_j", "key_k", "key_l"]

var _stage: Stage = Stage.PLAYING ## Which screen the HUD is currently dressed for.


func _ready() -> void:
	# The addon registers extra_actions before it fills in the gaps itself, and a subclass sets them
	# here rather than from a parent, because a child is ready before whatever owns it.
	for slot: String in BINDINGS:
		var action: StringName = get(&"action_" + slot)
		if action == &"":
			continue
		# Two slots may be put on one action deliberately, so the keys gather rather than the later
		# slot replacing the earlier and leaving the first button answering to nothing.
		var key: String = String(action)
		extra_actions[key] = merge_bindings(extra_actions.get(key, {}), BINDINGS[slot])
	super()
	# Changing device redraws the HUD from the scene's own text, and so does a world prompt handing
	# its label back, so the setup words have to go on again afterwards or they are lost the moment
	# the player picks up a pad mid-question.
	contextual_labels_requested.connect(_apply_labels)
	input_type_changed.connect(func(_input_type: InputType) -> void:
		_apply_labels()
		_apply_visibility())
	_apply_visibility()


## Dresses the HUD for [param stage]: the words for that screen on the buttons, and only the buttons
## that screen uses on screen at all.
func set_stage(stage: Stage) -> void:
	if _stage == stage:
		return
	_stage = stage
	_apply_labels()
	_apply_visibility()


## Whether the HUD is dressed for one of the game's questions rather than for play.
func is_setting_up() -> bool:
	return _stage != Stage.PLAYING


## Swaps between the setup words and the scene's own. Kept for callers that only know the two states;
## a bare "setting up" cannot say which question, so it is read as the skill menu, the one that has
## buttons of its own.
func set_setting_up(value: bool) -> void:
	set_stage(Stage.ASKING_SKILL if value else Stage.PLAYING)


## Shows the buttons the screen in front of the player uses and hides the ones it does not. Called
## again after anything that redraws the HUD from the scene, for the same reason the labels are.
func _apply_visibility() -> void:
	var is_keyboard: bool = current_input_type == InputType.KEYBOARD_MOUSE
	for stage: Stage in STAGE_NODES:
		for node_name: String in STAGE_NODES[stage]:
			var node: CanvasItem = get(node_name) as CanvasItem
			if node == null:
				continue
			# The addon shows one of the two d-pads for the device in hand and hides the other, and that
			# still holds on the screen the d-pad belongs to: a pad player has no I/J/K/L to press.
			var wanted: bool = stage == _stage
			if KEYBOARD_ONLY_NODES.has(node_name):
				wanted = wanted and is_keyboard
			elif JOYPAD_ONLY_NODES.has(node_name):
				wanted = wanted and not is_keyboard
			node.visible = wanted


## Puts the words for whichever screen the game is on back onto the buttons.
func _apply_labels() -> void:
	if _stage == Stage.PLAYING:
		reset_labels()
		return
	var texts: Dictionary = {}
	for slot: String in SETUP_LABELS:
		texts[get(LABEL_PROPERTIES[slot])] = SETUP_LABELS[slot]
	set_labels(texts)

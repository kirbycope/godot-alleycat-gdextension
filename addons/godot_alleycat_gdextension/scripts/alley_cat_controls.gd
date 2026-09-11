class_name AlleyCatControls
extends Controls
## The controls HUD for the Alley Cat demo: the [Controls] addon
## ([url]https://github.com/kirbycope/godot-controls[/url]) with Alley Cat's own actions on its slots.
##
## Everything this adds is two things the addon leaves to the game. It gives each action the keyboard
## key the game already answers to, so the HUD's keyboard art names a key that really works. And it
## turns a tap on the on-screen pad back into the joypad event [AlleyCat] reads, because a
## [TouchScreenButton] sends an [InputEventAction] and the extension's mapping is in C++, over real
## joypad events.
##
## The slots themselves are not set here. They are set in
## [code]scenes/alley_cat_controls.tscn[/code], an inherited scene, so which action sits on which
## button and what each one is called are inspector fields rather than lines of code.

## The key behind each slot's action, so the HUD's keyboard art is the key the game actually takes.
## The extension reads the keyboard itself, through the game's own INT 9 handler, so these bindings
## are for the HUD's benefit rather than the game's.
const KEYS: Dictionary = {
	"button_0": KEY_ALT,
	"button_1": KEY_S,
	"button_2": KEY_T,
	"button_3": KEY_A,
	"button_4": KEY_ESCAPE,
	"button_6": KEY_M,
	"button_11": KEY_UP,
	"button_12": KEY_DOWN,
	"button_13": KEY_LEFT,
	"button_14": KEY_RIGHT,
	"move_up": KEY_UP,
	"move_down": KEY_DOWN,
	"move_left": KEY_LEFT,
	"move_right": KEY_RIGHT,
}

## The joypad event each slot's action stands for, so a tap on the on-screen pad reaches [AlleyCat].
## A slot missing from here is one the pad does not send: the share button is the addon's own
## screenshot and never the game's.
const JOYPAD: Dictionary = {
	"button_0": JOY_BUTTON_A,
	"button_1": JOY_BUTTON_B,
	"button_2": JOY_BUTTON_X,
	"button_3": JOY_BUTTON_Y,
	"button_4": JOY_BUTTON_BACK,
	"button_6": JOY_BUTTON_START,
	"button_11": JOY_BUTTON_DPAD_UP,
	"button_12": JOY_BUTTON_DPAD_DOWN,
	"button_13": JOY_BUTTON_DPAD_LEFT,
	"button_14": JOY_BUTTON_DPAD_RIGHT,
}

## The stick, which sends axis events rather than buttons: the slot, its axis and which way it pushes.
const STICK: Dictionary = {
	"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	"move_down": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
}

## What the buttons mean while the game is still asking its setup questions. It asks them in text and
## a pad has no letters, so the face buttons stand in for them; [method Controls.set_labels] is what
## the addon offers for exactly this, and [method Controls.reset_labels] puts the scene's own words
## back when play starts.
const SETUP_LABELS: Dictionary = {
	"button_0": "Yes / Kitten",
	"button_1": "No / House Cat",
	# X and Y are the skill menu's harder two and do nothing while playing, which is why the scene
	# leaves them wordless and only this names them.
	"button_2": "Tomcat",
	"button_3": "Alley Cat",
	"button_4": "",
	"button_6": "",
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
	"button_11": "joypad_button_11_label",
	"button_12": "joypad_button_12_label",
	"button_13": "joypad_button_13_label",
	"button_14": "joypad_button_14_label",
	"left_joystick": "left_joystick_label",
}

var _setting_up: bool = false ## Whether the setup words are the ones currently up.
var _sent: Dictionary[int, float] = {} ## The last value sent per axis, so the node hears only changes.


func _ready() -> void:
	# The addon registers extra_actions before it fills in the gaps itself, and a subclass sets them
	# here rather than from a parent, because a child is ready before whatever owns it.
	for slot: String in KEYS:
		var action: StringName = get(&"action_" + slot)
		if action != &"":
			extra_actions[String(action)] = {"keys": [KEYS[slot]]}
	super()
	# Only the on-screen pad needs watching, and only while it is on screen.
	set_process(visible and current_input_type == InputType.TOUCH)
	input_type_changed.connect(_on_input_type_changed)
	# Changing device redraws the HUD from the scene's own text, and so does a world prompt handing
	# its label back, so the setup words have to go on again afterwards or they are lost the moment
	# the player picks up a pad mid-question.
	contextual_labels_requested.connect(_apply_labels)


func _on_input_type_changed(_input_type: InputType) -> void:
	set_process(visible and current_input_type == InputType.TOUCH)
	_apply_labels()


## Swaps between the setup words and the scene's own. The same buttons mean different things on the
## game's two screens, and the card has to say which.
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


## A [TouchScreenButton] sends an [InputEventAction] and nothing else does, so a real key or pad
## reaches [AlleyCat] on its own and is never sent twice.
func _input(event: InputEvent) -> void:
	# The addon works out which device is in hand in its own _input, and everything it draws hangs
	# off that, so an override that forgets this leaves the HUD stuck on the art it started with.
	super(event)
	var action_event: InputEventAction = event as InputEventAction
	if action_event == null:
		return
	for slot: String in JOYPAD:
		if get(&"action_" + slot) != action_event.action:
			continue
		var button_event: InputEventJoypadButton = InputEventJoypadButton.new()
		button_event.button_index = JOYPAD[slot]
		button_event.pressed = action_event.pressed
		Input.parse_input_event(button_event)
		return


## The stick. Godot's [VirtualJoystick] presses its actions straight into the input state rather than
## sending an event, so it is the one thing here that has to be read rather than listened for.
func _process(_delta: float) -> void:
	for axis: int in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var value: float = axis_value(axis)
		if is_equal_approx(value, _sent.get(axis, 0.0)):
			continue
		_sent[axis] = value
		var motion_event: InputEventJoypadMotion = InputEventJoypadMotion.new()
		motion_event.axis = axis
		motion_event.axis_value = value
		Input.parse_input_event(motion_event)


## How far an axis is pushed, from both of its directions at once, so letting go of one while the
## other is held leaves the stick pushed the other way rather than centred.
func axis_value(axis: int) -> float:
	var value: float = 0.0
	for slot: String in STICK:
		if STICK[slot][0] != axis:
			continue
		var action: StringName = get(&"action_" + slot)
		if action != &"" and InputMap.has_action(action):
			value += STICK[slot][1] * Input.get_action_strength(action)
	return clampf(value, -1.0, 1.0)

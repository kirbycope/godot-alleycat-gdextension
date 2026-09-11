class_name AlleyCatVirtualPad
extends Node
## The on-screen pad for the Alley Cat screen, so the demo is playable with no keyboard. It fills itself with
## the controls addon's HUD ([url]https://github.com/kirbycope/godot-controls[/url]) when that addon is in the
## project, maps every slot it uses to an action of its own, and turns the taps back into the joypad events
## [AlleyCat] already understands: the node has a pad mapping in C++, so a virtual pad needs no new engine
## code.
##
## The addon is optional. Without it this node does nothing and the demo still runs, which is why the HUD is
## loaded here rather than instanced in [code]demo.tscn[/code].

signal device_changed(input_type: int) ## The device in hand changed; carries a [constant TOUCH]-style value.

const CONTROLS_SCENE: String = "res://addons/controls/controls.tscn" ## Optional: no pad without it.

## The addon's own InputType values, repeated here rather than named through the addon, which a project
## taking this extension alone will not have.
const KEYBOARD_MOUSE: int = 0
const TOUCH: int = 4

## The joypad axes this pad fills, so [method _process] asks about no others.
const AXES: Array[int] = [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]

## Each slot this pad uses, as the controls addon names it, with the action to put on it and the joypad event
## [AlleyCat] reads that action as. A slot missing from here is left blank, and the addon hides a blank slot.
## Alley Cat is a one-stick game with one button that matters, so most of a modern pad is left empty: the
## shoulders, the triggers and the right stick do nothing, and the share button is left to the addon, which
## puts its own screenshot on it.
const SLOTS: Dictionary = {
	"button_0": {"action": &"alleycat_jump", "button": JOY_BUTTON_A},
	"button_1": {"action": &"alleycat_sound", "button": JOY_BUTTON_B},
	"button_2": {"action": &"alleycat_tomcat", "button": JOY_BUTTON_X},
	"button_3": {"action": &"alleycat_alley_cat", "button": JOY_BUTTON_Y},
	"button_4": {"action": &"alleycat_pause", "button": JOY_BUTTON_BACK},
	"button_6": {"action": &"alleycat_menu", "button": JOY_BUTTON_START},
	"button_11": {"action": &"alleycat_dpad_up", "button": JOY_BUTTON_DPAD_UP},
	"button_12": {"action": &"alleycat_dpad_down", "button": JOY_BUTTON_DPAD_DOWN},
	"button_13": {"action": &"alleycat_dpad_left", "button": JOY_BUTTON_DPAD_LEFT},
	"button_14": {"action": &"alleycat_dpad_right", "button": JOY_BUTTON_DPAD_RIGHT},
	"move_up": {"action": &"alleycat_move_up", "axis": JOY_AXIS_LEFT_Y, "value": -1.0},
	"move_down": {"action": &"alleycat_move_down", "axis": JOY_AXIS_LEFT_Y, "value": 1.0},
	"move_left": {"action": &"alleycat_move_left", "axis": JOY_AXIS_LEFT_X, "value": -1.0},
	"move_right": {"action": &"alleycat_move_right", "axis": JOY_AXIS_LEFT_X, "value": 1.0},
}

## What each button does, by the slot it sits on. The face buttons read two ways, because the game asks its
## setup questions in text and a pad has no letters: while the questions are up they answer them, and once
## play starts the bottom button is the joystick button the game keeps talking about.
const LABELS: Dictionary = {
	"button_0": "Jump",
	"button_1": "Sound",
	"button_2": "",
	"button_3": "",
	"button_4": "Paws",
	"button_6": "Menu",
	# Not a slot this pad fills: the addon puts its own screenshot on the share button, and set_labels clears
	# every label it is not given, so the word has to be repeated here to survive.
	"button_15": "Screenshot",
	"button_11": "Up",
	"button_12": "Down",
	"button_13": "Left",
	"button_14": "Right",
	"left_joystick": "Move",
}

## The same slots while the game is still asking its setup questions.
const SETUP_LABELS: Dictionary = {
	"button_0": "Yes / Kitten",
	"button_1": "No / House Cat",
	"button_2": "Tomcat",
	"button_3": "Alley Cat",
	"button_4": "",
	"button_6": "",
	"button_15": "Screenshot",
	"button_11": "",
	"button_12": "",
	"button_13": "",
	"button_14": "",
	"left_joystick": "",
}

## The label property on the addon's HUD for each slot named above.
const LABEL_PROPERTIES: Dictionary = {
	"button_0": "joypad_button_0_label",
	"button_1": "joypad_button_1_label",
	"button_2": "joypad_button_2_label",
	"button_3": "joypad_button_3_label",
	"button_4": "joypad_button_4_label",
	"button_6": "joypad_button_6_label",
	"button_15": "joypad_button_15_label",
	"button_11": "joypad_button_11_label",
	"button_12": "joypad_button_12_label",
	"button_13": "joypad_button_13_label",
	"button_14": "joypad_button_14_label",
	"left_joystick": "left_joystick_label",
}

var controls: CanvasLayer ## The addon's HUD, null where the addon is not installed.

var _setting_up: bool = true ## Whether the game is still on its text questions, which changes the labels.
var _sent: Dictionary[int, float] = {} ## The last value handed to the node per axis, so it hears only changes.


func _ready() -> void:
	set_process(false)
	if not ResourceLoader.exists(CONTROLS_SCENE):
		return
	controls = (load(CONTROLS_SCENE) as PackedScene).instantiate() as CanvasLayer
	# Slot names are written before the HUD enters the tree: it registers the InputMap actions in its own
	# _ready, from whatever the exports say at that moment.
	for slot: String in SLOTS:
		controls.set(&"action_" + slot, SLOTS[slot]["action"])
	add_child(controls)
	_apply_labels()
	controls.connect(&"input_type_changed", _on_input_type_changed)
	# Swapping device redraws the HUD from the scene's own text, so the Alley Cat wording goes back on after.
	controls.connect(&"contextual_labels_requested", _apply_labels)
	# The HUD starts on touch and waits for an event to say otherwise, which on a desktop browser means it
	# flashes up before the first keypress. A machine with no touchscreen can say so straight away.
	if not DisplayServer.is_touchscreen_available():
		controls.set(&"current_input_type", KEYBOARD_MOUSE)
	else:
		_on_input_type_changed(TOUCH)


## The pad is for the one device with no buttons of its own. A keyboard or a real controller has them, and
## the card down each side of the monitor already names every one, so the two never share the screen.
func _on_input_type_changed(input_type: int) -> void:
	controls.visible = input_type == TOUCH
	set_process(controls.visible)
	_apply_labels()
	device_changed.emit(input_type)


## The device in hand, for a caller that missed [signal device_changed].
func current_input_type() -> int:
	return controls.get(&"current_input_type") if controls != null else KEYBOARD_MOUSE


## Tells the pad which set of labels applies. The game asks its questions in text and plays in pixels, so the
## same buttons mean different things on the two screens and the pad should say which.
func set_setting_up(value: bool) -> void:
	if _setting_up == value:
		return
	_setting_up = value
	_apply_labels()


## Names every button after what the game does with it. [code]set_labels[/code] clears the ones not named,
## which is how the slots this pad leaves blank stay wordless.
func _apply_labels() -> void:
	if controls == null:
		return
	var source: Dictionary = SETUP_LABELS if _setting_up else LABELS
	var texts: Dictionary = {}
	for slot: String in source:
		texts[controls.get(LABEL_PROPERTIES[slot])] = source[slot]
	controls.call(&"set_labels", texts)


## The buttons. A [TouchScreenButton] sends an [InputEventAction], and nothing else does: a real key or pad
## reaches [AlleyCat] on its own and must not be sent twice.
func _input(event: InputEvent) -> void:
	var action_event: InputEventAction = event as InputEventAction
	if action_event == null:
		return
	for slot: String in SLOTS:
		var slot_binding: Dictionary = SLOTS[slot]
		if not slot_binding.has("button") or slot_binding["action"] != action_event.action:
			continue
		var button_event: InputEventJoypadButton = InputEventJoypadButton.new()
		button_event.button_index = slot_binding["button"]
		button_event.pressed = action_event.pressed
		Input.parse_input_event(button_event)
		return


## The stick. Godot's [VirtualJoystick] presses its actions straight into the input state rather than sending
## an event, so this is the one thing here that has to be read rather than listened for. Reading only happens
## while the pad is on screen, which is only on touch.
func _process(_delta: float) -> void:
	for axis: int in AXES:
		var value: float = axis_value(axis)
		if is_equal_approx(value, _sent.get(axis, 0.0)):
			continue
		_sent[axis] = value
		var motion_event: InputEventJoypadMotion = InputEventJoypadMotion.new()
		motion_event.axis = axis
		motion_event.axis_value = value
		Input.parse_input_event(motion_event)


## How far an axis is pushed, from both of its directions at once, so letting go of one while the other is
## held leaves the stick pushed the other way rather than centred.
func axis_value(axis: int) -> float:
	var value: float = 0.0
	for slot: String in SLOTS:
		var slot_binding: Dictionary = SLOTS[slot]
		if slot_binding.get("axis", -1) == axis:
			value += slot_binding["value"] * Input.get_action_strength(slot_binding["action"])
	return clampf(value, -1.0, 1.0)

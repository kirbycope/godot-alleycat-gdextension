extends Control

## Demo for the AlleyCat node: shows the game filling the window, or an explanation of where to put
## CAT.EXE if it is not there. The game is not distributed with this addon.

const PAD_INSET_SIDE: float = 120.0 ## Room down each side for the on-screen pad's thumb clusters.
const PAD_INSET_BOTTOM: float = 140.0

## The bottom button, named for the device in hand. Indexed by the controls addon's InputType.
const ACT_BUTTON: Array[String] = ["Alt", "A", "B", "Cross", "the button"]
## The right-hand button, same order. Nintendo swaps the pair round and Sony has its own shapes.
const SECOND_BUTTON: Array[String] = ["", "B", "A", "Circle", ""]

@onready var game: AlleyCat = $Screen/Game
@onready var screen: AspectRatioContainer = $Screen
@onready var missing: Label = $Missing
@onready var hint: Label = $Hint
@onready var prompt: Label = $Prompt
@onready var pad: AlleyCatVirtualPad = $VirtualPad

var _input_type: int = AlleyCatVirtualPad.KEYBOARD_MOUSE
var _setting_up: bool = true


func _ready() -> void:
	game.loaded.connect(_on_loaded)
	game.load_failed.connect(_on_load_failed)
	pad.device_changed.connect(_on_device_changed)
	_on_device_changed(pad.current_input_type())
	# _ready on a child runs before its parent's, so an autostart failure was emitted before this
	# could connect. Ask directly rather than wait for a signal that has already been and gone.
	if game.is_loaded():
		_on_loaded()
	else:
		_on_load_failed("Copy your own CAT.EXE to %s" % game.exe_path)


func _on_loaded() -> void:
	missing.hide()
	_refresh_hint()


func _on_load_failed(reason: String) -> void:
	missing.text = "Alley Cat is not included with this addon.\n\n%s" % reason
	missing.show()
	hint.hide()
	prompt.hide()


## The pad is only for a touchscreen, which has no buttons to name, so the hint line and the pad
## never share the screen. The monitor pulls in to leave the thumb clusters clear.
func _on_device_changed(input_type: int) -> void:
	_input_type = input_type
	var touch: bool = input_type == AlleyCatVirtualPad.TOUCH
	screen.offset_left = PAD_INSET_SIDE if touch else 0.0
	screen.offset_right = -screen.offset_left
	screen.offset_bottom = -PAD_INSET_BOTTOM if touch else -32.0
	_refresh_hint()


func _process(_delta: float) -> void:
	if not game.is_loaded():
		return
	# The game asks its setup questions through BIOS teletype rather than drawing them, so they
	# arrive as text and not as pixels. Without this the player sees a black screen and no reason
	# for it: the joystick question and the skill menu are both invisible.
	# The text buffer keeps everything printed since the last mode set, so it is still full once
	# play starts. The game blanks the graphics screen to ask a question and paints it to play,
	# so use that rather than the text to decide when the overlay is wanted.
	var asking: bool = game.get_screen_painted() < 512
	prompt.text = game.get_text() if asking else ""
	prompt.visible = asking
	if asking != _setting_up:
		_setting_up = asking
		pad.set_setting_up(asking)
		_refresh_hint()


## The hint line says what the device in hand does, and the two screens want different words: the
## setup questions are answered with letters a pad does not have, so its buttons stand in for them.
func _refresh_hint() -> void:
	if missing.visible:
		return
	if _input_type == AlleyCatVirtualPad.TOUCH:
		hint.hide()
		return
	hint.show()
	var act: String = ACT_BUTTON[_input_type]
	if _input_type == AlleyCatVirtualPad.KEYBOARD_MOUSE:
		hint.text = ("Y or N, then K, H, T or A" if _setting_up
				else "Cursor keys move  ·  Alt acts  ·  Ctrl-S sound  ·  Ctrl-M menu  ·  Esc pauses")
		return
	var second: String = SECOND_BUTTON[_input_type]
	hint.text = ("%s is yes and Kitten  ·  %s is no and House Cat  ·  X and Y are the harder two"
			% [act, second] if _setting_up
			else "Stick or D-pad moves  ·  %s acts  ·  Start opens the menu  ·  Back pauses" % act)

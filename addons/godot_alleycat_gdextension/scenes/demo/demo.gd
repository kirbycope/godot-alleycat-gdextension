extends Control

## Demo for the AlleyCat node: the game filling the window with the controls card down each side, the
## on-screen pad for a player with no keyboard, or an explanation of where to put CAT.EXE if it is not
## there. The game is not distributed with this addon.

const CARD_INSET: float = 210.0 ## Room down each side of the monitor for the controls card.
## Room for the on-screen pad: the thumb clusters in the bottom corners and the face buttons down the
## right reach further in than the card does.
const PAD_INSET_SIDE: float = 190.0
const PAD_INSET_BOTTOM: float = 160.0
## The controls card's wording for each of the controls addon's InputType values, in its enum's order.
const CARD_INPUT_TYPES: Array[String] = ["keyboard", "xbox", "nintendo", "playstation", "touch"]

@onready var game: AlleyCat = $Screen/Game
@onready var screen: AspectRatioContainer = $Screen
@onready var missing: Label = $Missing
@onready var prompt: Label = $Prompt
@onready var overlay: AlleyCatControlsOverlay = $AlleyCatControlsOverlay
@onready var pad: AlleyCatVirtualPad = $VirtualPad

var _setting_up: bool = true ## Whether the game is on its text questions rather than playing.


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
	overlay.show()


func _on_load_failed(reason: String) -> void:
	missing.text = "Alley Cat is not included with this addon.\n\n%s" % reason
	missing.show()
	overlay.hide()
	prompt.hide()


## The card beside the monitor words itself for the device in hand. On a phone it steps aside for the
## pad, whose buttons say what they do themselves, and the monitor pulls in to leave the thumbs clear.
func _on_device_changed(input_type: int) -> void:
	overlay.input_type = CARD_INPUT_TYPES[input_type]
	var touch: bool = input_type == AlleyCatVirtualPad.TOUCH
	overlay.visible = not touch and not missing.visible
	screen.offset_left = PAD_INSET_SIDE if touch else CARD_INSET
	screen.offset_right = -screen.offset_left
	screen.offset_bottom = -PAD_INSET_BOTTOM if touch else 0.0


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
		# The same buttons mean different things on the two screens, so the card changes with them.
		_setting_up = asking
		overlay.setting_up = asking
		pad.set_setting_up(asking)

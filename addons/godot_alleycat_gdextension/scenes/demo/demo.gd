extends Control

## Demo for the AlleyCat node: the game filling the window with the controls card down each side, the
## on-screen pad for a player with no keyboard, or an explanation of what is missing.
##
## The game node is built here rather than placed in [code]demo.tscn[/code]. A scene that names a
## GDExtension type cannot be opened at all where the library is not built, which would turn "this
## platform has no build yet" into a broken scene; instantiating it by name degrades instead.

const CARD_INSET: float = 210.0 ## Room down each side of the monitor for the controls card.
## Room for the on-screen pad: the thumb clusters in the bottom corners and the face buttons down the
## right reach further in than the card does.
const PAD_INSET_SIDE: float = 190.0
const PAD_INSET_BOTTOM: float = 160.0
## The controls card's wording for each of the controls addon's InputType values, in its enum's order.
const CARD_INPUT_TYPES: Array[String] = ["keyboard", "xbox", "nintendo", "playstation", "touch"]
## How much of the framebuffer has to be painted before the game counts as playing rather than asking
## a question. It blanks the screen to ask and paints it to play.
const PAINTED: int = 512

@onready var screen: AspectRatioContainer = $Screen
@onready var missing: Label = $Missing
@onready var prompt: Label = $Prompt
@onready var overlay: AlleyCatControlsOverlay = $AlleyCatControlsOverlay
@onready var pad: AlleyCatVirtualPad = $VirtualPad

var game: TextureRect ## The AlleyCat node, null where the library is not built for this platform.

var _setting_up: bool = true ## Whether the game is on its text questions rather than playing.


func _ready() -> void:
	pad.device_changed.connect(_on_device_changed)
	_on_device_changed(pad.current_input_type())
	if not ClassDB.class_exists(&"AlleyCat"):
		_on_load_failed("The AlleyCat library is not built for this platform.")
		return
	game = ClassDB.instantiate(&"AlleyCat") as TextureRect
	game.name = "Game"
	game.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	game.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	game.connect(&"loaded", _on_loaded)
	game.connect(&"load_failed", _on_load_failed)
	screen.add_child(game)
	# The node loads on its own _ready, which has now been and gone, so ask rather than wait for a
	# signal that has already fired.
	if game.call(&"is_loaded"):
		_on_loaded()
	else:
		_on_load_failed("Copy your own CAT.EXE to %s" % game.get(&"exe_path"))


func _on_loaded() -> void:
	missing.hide()
	overlay.show()


func _on_load_failed(reason: String) -> void:
	missing.text = "Alley Cat could not start.\n\n%s" % reason
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
	if game == null:
		return
	# The game asks its setup questions through BIOS teletype rather than drawing them, so they
	# arrive as text and not as pixels. Without this the player sees a black screen and no reason
	# for it: the joystick question and the skill menu are both invisible.
	# The text buffer keeps everything printed since the last mode set, so it is still full once
	# play starts; what says which screen is up is whether the game has painted one.
	var asking: bool = game.call(&"get_screen_painted") < PAINTED
	prompt.text = game.call(&"get_text") if asking else ""
	prompt.visible = asking
	if asking != _setting_up:
		# The same buttons mean different things on the two screens, so the card changes with them.
		_setting_up = asking
		overlay.setting_up = asking
		pad.set_setting_up(asking)

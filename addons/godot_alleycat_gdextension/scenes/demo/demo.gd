extends Control

## Demo for the AlleyCat node: the game on screen with the controls HUD around it, or an explanation
## of what is missing.
##
## The HUD is the [Controls] addon, instanced in this scene as [code]Controls[/code]. Which action
## sits on which button, and what each one is called, are set in
## [code]scenes/alley_cat_controls.tscn[/code] and edited there rather than here.
##
## The game node is the one thing built in code. A scene that names a GDExtension type cannot be
## opened at all where the library is not built, which would turn "this platform has no build yet"
## into a broken scene; instantiating it by name degrades instead.

## How much of the framebuffer has to be painted before the game counts as playing rather than asking
## a question. It blanks the screen to ask and paints it to play.
const PAINTED: int = 512

@onready var screen: AspectRatioContainer = $Screen
@onready var missing: Label = $Missing
@onready var prompt: Label = $Prompt
@onready var controls: AlleyCatControls = $Controls

var game: TextureRect ## The AlleyCat node, null where the library is not built for this platform.

var _setting_up: bool = false ## Whether the game is on its text questions rather than playing.


func _ready() -> void:
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
	controls.show()


func _on_load_failed(reason: String) -> void:
	missing.text = "Alley Cat could not start.\n\n%s" % reason
	missing.show()
	controls.hide()
	prompt.hide()


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
		# The same buttons mean different things on the game's two screens, so the HUD says which.
		_setting_up = asking
		controls.set_setting_up(asking)

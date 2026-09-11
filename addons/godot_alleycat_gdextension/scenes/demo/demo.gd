extends Control

## Demo for the AlleyCat node: shows the game filling the window, or an explanation of where to put
## CAT.EXE if it is not there. The game is not distributed with this addon.

@onready var game: AlleyCat = $Screen/Game
@onready var missing: Label = $Missing
@onready var hint: Label = $Hint
@onready var prompt: Label = $Prompt


func _ready() -> void:
	game.loaded.connect(_on_loaded)
	game.load_failed.connect(_on_load_failed)
	# _ready on a child runs before its parent's, so an autostart failure was emitted before this
	# could connect. Ask directly rather than wait for a signal that has already been and gone.
	if game.is_loaded():
		_on_loaded()
	else:
		_on_load_failed("Copy your own CAT.EXE to %s" % game.exe_path)


func _on_loaded() -> void:
	missing.hide()
	hint.show()


func _on_load_failed(reason: String) -> void:
	missing.text = "Alley Cat is not included with this addon.\n\n%s" % reason
	missing.show()
	hint.hide()
	prompt.hide()


func _process(_delta: float) -> void:
	if not game.is_loaded():
		return
	# The game asks its setup questions through BIOS teletype rather than drawing them, so they
	# arrive as text and not as pixels. Without this the player sees a black screen and no reason
	# for it: the joystick question and the skill menu are both invisible.
	# The text buffer keeps everything printed since the last mode set, so it is still full once
	# play starts. The game blanks the graphics screen to ask a question and paints it to play,
	# so use that rather than the text to decide when the overlay is wanted.
	var asking := game.get_screen_painted() < 512
	prompt.text = game.get_text() if asking else ""
	prompt.visible = asking


func _input(event: InputEvent) -> void:
	# The game takes every other key itself; this is the one the host keeps.
	if event.is_action_pressed(&"ui_cancel") and not game.is_running():
		get_tree().quit()

extends Control

## Demo for the AlleyCat node: shows the game filling the window, or an explanation of where to put
## CAT.EXE if it is not there. The game is not distributed with this addon.

@onready var game: AlleyCat = $Screen/Game
@onready var missing: Label = $Missing
@onready var hint: Label = $Hint


func _ready() -> void:
	game.loaded.connect(_on_loaded)
	game.load_failed.connect(_on_load_failed)
	# _ready on the node has already run by the time this does, so a failure that happened during
	# its autostart was emitted before we connected. Ask directly rather than wait for a signal.
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


func _input(event: InputEvent) -> void:
	# The game takes every other key itself; this is the one the host keeps.
	if event.is_action_pressed(&"ui_cancel") and not game.is_running():
		get_tree().quit()

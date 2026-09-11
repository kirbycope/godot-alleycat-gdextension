class_name AlleyCatControlsOverlay
extends CanvasLayer
## Two plain-text columns of Alley Cat's controls, one down each side of the monitor, worded for the
## input device in use. Set [member input_type] from whatever detects the device and [member setting_up]
## from whether the game is still asking its questions; the text comes from [member controls].

@export var controls: AlleyCatControls ## The card to show; resources/controls.tres by default.
@export var input_type: String = "keyboard": ## "keyboard", "xbox", "nintendo", "playstation" or "touch".
	set(value):
		input_type = value
		if is_node_ready():
			refresh()

## Whether the game is on its setup questions rather than playing. The same buttons mean different
## things on the two screens, so the card has two sets of lines.
@export var setting_up: bool = true:
	set(value):
		setting_up = value
		if is_node_ready():
			refresh()

@onready var left: RichTextLabel = $Left
@onready var right: RichTextLabel = $Right


func _ready() -> void:
	refresh()


## Rewrites both columns for the current input type and screen.
func refresh() -> void:
	if controls == null:
		return
	if setting_up:
		left.text = column("SETUP", controls.setup)
		right.text = ""
	else:
		left.text = column("MOVEMENT", controls.movement)
		right.text = column("ACTIONS", controls.actions)


## A title then one entry per line that has text for this device: the input in white, what it does beneath.
func column(title: String, lines: Array[AlleyCatControl]) -> String:
	var text: String = "[color=white]%s[/color]\n" % title
	for line: AlleyCatControl in lines:
		var input: String = line.text_for(input_type)
		if input != "":
			text += "\n[color=white]%s[/color]\n  %s\n" % [input, line.label]
	return text

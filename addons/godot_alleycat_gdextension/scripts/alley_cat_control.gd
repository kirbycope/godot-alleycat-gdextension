class_name AlleyCatControl
extends Resource
## One line of the controls card: what the game calls an action and the plain-text input for it on each
## device. Leave a device's text empty to drop the line for that device.

@export var label: String = "" ## What it does: "Move", "Jump", "Sound".
@export var keyboard: String = "" ## Keyboard: "Cursor keys", "Alt".
@export var xbox: String = "" ## Xbox pad, also shown on touch: "A", "Left stick, D-pad".
@export var nintendo: String = "" ## Nintendo pad: "B".
@export var playstation: String = "" ## PlayStation pad: "Cross".


## The text for an input type: "keyboard", "xbox", "nintendo", "playstation" or "touch" (the Xbox text).
func text_for(input_type: String) -> String:
	match input_type:
		"xbox", "touch":
			return xbox
		"nintendo":
			return nintendo
		"playstation":
			return playstation
		_:
			return keyboard

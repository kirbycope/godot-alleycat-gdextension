@tool
class_name AlleyCatSounds
extends Resource
## Sound to put over Alley Cat's own, as a resource rather than as code.
##
## The game has one speaker and drives it from two places - a music player walking a note table, and
## the routines that make its effects - so [AlleyCat] can turn either down on its own. That is what
## makes a swap possible: silence the music, leave the effects, and play something of your own over
## the top. Nothing here is required, and a slot left empty leaves the game's own sound alone.
##
## Drop one of these on an [AlleyCatRemaster] node. Keeping it a resource rather than exports on the
## node means a set of sounds is a file: several can sit side by side in a project and be swapped
## whole, and one of them can be shipped without shipping a scene.

## Played in place of the game's own music. Setting this is what silences the speaker's music voice;
## clear it and the game's tune comes back.
@export var music: AudioStream

## How loud [member music] is played, independently of the game's own voices.
@export_range(0.0, 1.0, 0.01) var music_volume: float = 0.7

## Whether [member music] starts again when it ends. A short loop wants this; a long one rarely does.
@export var music_loops: bool = true

@export_group("Replacing single effects")
## Played when the cat jumps.
@export var jump: AudioStream
## Played when the cat is caught.
@export var caught: AudioStream
## Played when something is eaten.
@export var eat: AudioStream
## Played on entering a window.
@export var enter_window: AudioStream

## Whether the game's own effects are silenced when a replacement is given for them. Off by default,
## because the game's effects are tied to events this addon cannot yet see: until they can be told
## apart one by one, silencing them all to replace one of them loses the rest.
@export var replace_effects: bool = false


## The named effects this resource carries, as slot name to stream, skipping the empty ones. What a
## host wires each of them to is its own business; this only says which were filled in.
func effects() -> Dictionary:
	var filled: Dictionary = {}
	for slot: String in ["jump", "caught", "eat", "enter_window"]:
		var stream: AudioStream = get(slot) as AudioStream
		if stream != null:
			filled[slot] = stream
	return filled

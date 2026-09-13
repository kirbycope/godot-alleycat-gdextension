extends RefCounted
## Drives the running demo about and records every sprite the game draws while it does.
##
## Run it through the Godot MCP's run_script against the demo. It comes back as a catalogue in the same
## shape `tools/export_sprites.py` takes: {"source", "width", "height", "times", "masked"}.
##
## Why a sweep rather than a static read of CAT.EXE: only 22% of the game's code is reachable by following
## calls from the entry point, so a disassembly can only ever name the sprites that 22% draws. The rest is
## entered through computed jumps and looks like data to any static tool. The machine has no such problem -
## it runs the code - so the complete list of artwork is the list of everything the game was made to draw.
##
## That makes this the thing to grow rather than to run once: every state reached adds sprites nobody had
## seen, and `export_sprites.py` merges a sweep into what is already catalogued rather than replacing it.

## How long to hold a direction before trying the next thing, in frames of the host rather than of the game.
const HOLD: int = 45

## Actions to walk the cat about with. Up is also the jump, which is how the cat reaches the windows.
const WALK: Array[StringName] = [
	&"alleycat_left", &"alleycat_right", &"alleycat_up", &"alleycat_down",
]

## The four skills, so each one's own screens and its own creatures get drawn.
const SKILLS: Array[Key] = [KEY_K, KEY_H, KEY_T, KEY_A]


func execute(scene_tree: SceneTree) -> Variant:
	var demo: Node = scene_tree.current_scene
	var game: Object = demo.game
	if game == null:
		return {"error": "AlleyCat is not built for this platform"}
	game.set(&"reports_sprites", true)
	var seen: Dictionary = {}
	for skill: Key in SKILLS:
		await _start_a_game(scene_tree, demo, skill)
		await _play(scene_tree, game, seen, 40)
	var out: Array = []
	for key: String in seen:
		out.append(seen[key])
	return {"sprites": out, "distinct": out.size()}


## Menu, a skill, and into play. Ctrl-M is the game's own way back to the setup whatever it was doing.
func _start_a_game(scene_tree: SceneTree, demo: Node, skill: Key) -> void:
	await _tap(scene_tree, KEY_M)
	for i in 1200:
		await scene_tree.process_frame
		if demo._stage == AlleyCatControls.Stage.ASKING_SKILL:
			break
	await _tap(scene_tree, skill)
	for i in 1200:
		await scene_tree.process_frame
		if demo._stage == AlleyCatControls.Stage.PLAYING:
			break


## Walks the cat through every direction a number of times, recording what the game draws throughout. The
## report is read every frame because it is cleared on the game's own tick and a tick spans many frames.
func _play(scene_tree: SceneTree, game: Object, seen: Dictionary, rounds: int) -> void:
	for round: int in rounds:
		var action: StringName = WALK[round % WALK.size()]
		Input.action_press(action)
		for i in HOLD:
			await scene_tree.process_frame
			_record(game, seen)
		Input.action_release(action)
		# Standing still matters too: the game draws poses here that it draws nowhere else.
		for i in 10:
			await scene_tree.process_frame
			_record(game, seen)


func _record(game: Object, seen: Dictionary) -> void:
	for sprite: Dictionary in game.call(&"get_sprites"):
		var key: String = "%d_%d_%d" % [int(sprite["source"]), int(sprite["width"]), int(sprite["height"])]
		var entry: Dictionary = seen.get(key, {
			"source": int(sprite["source"]), "width": int(sprite["width"]),
			"height": int(sprite["height"]), "times": 0, "masked": 0,
		})
		entry["times"] = int(entry["times"]) + 1
		if bool(sprite["masked"]):
			entry["masked"] = int(entry["masked"]) + 1
		seen[key] = entry


func _tap(scene_tree: SceneTree, key: Key) -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = key
	down.keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	for i in 10:
		await scene_tree.process_frame
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = key
	up.keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	await scene_tree.process_frame

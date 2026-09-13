extends RefCounted
## Drives the running demo about and records every sprite the game draws while it does.
##
## Run it through the Godot MCP's run_script against the demo. It comes back as a catalogue in the same
## shape `tools/export_sprites.py` takes: {"source", "width", "height", "times", "masked", "kind", "buffer"}.
##
## Why a sweep rather than a static read of CAT.EXE: only 22% of the game's code is reachable by following
## calls from the entry point, so a disassembly can only ever name the sprites that 22% draws. The rest is
## entered through computed jumps and looks like data to any static tool. The machine has no such problem -
## it runs the code - so the complete list of artwork is the list of everything the game was made to draw.
##
## That makes this the thing to grow rather than to run once: every state reached adds sprites nobody had
## seen, and `export_sprites.py` merges a sweep into what is already catalogued rather than replacing it.
##
## Two things the report says that the catalogue needs. A sprite drawn as a column lifted out of a wider
## one - the game clipping at the screen edge - comes with a stride and is not its own artwork, so it is left
## out. And a source whose bytes are not what CAT.EXE holds at that address is somewhere the game writes:
## a buffer it saves the background in, not a picture, and it is marked so the exporter leaves it out too.

const EXE: String = "res://addons/godot_alleycat_gdextension/assets/CAT.EXE"
const LOAD_ADDRESS: int = 0x10000
const HEADER: int = 512

## How long to hold a direction before trying the next thing, in frames of the host rather than of the game.
const HOLD: int = 45

## Actions to walk the cat about with. Up is also the jump, which is how the cat reaches the windows.
const WALK: Array[StringName] = [
	&"alleycat_left", &"alleycat_right", &"alleycat_up", &"alleycat_down",
]

## Longer holds, so the cat is clipped at both edges and stands still long enough to blink and wag.
const EDGES: Array = [
	[&"alleycat_right", 360], [&"alleycat_left", 720], [&"", 240], [&"alleycat_right", 360], [&"", 120],
]

## The four skills, so each one's own screens and its own creatures get drawn.
const SKILLS: Array[Key] = [KEY_K, KEY_H, KEY_T, KEY_A]

var _exe: PackedByteArray


func execute(scene_tree: SceneTree) -> Variant:
	var demo: Node = scene_tree.current_scene
	var game: Object = demo.game
	if game == null:
		return {"error": "AlleyCat is not built for this platform"}
	_exe = FileAccess.get_file_as_bytes(EXE)
	game.set(&"reports_sprites", true)
	var seen: Dictionary = {}
	# Whatever is up before anything is pressed: the title screen, if the demo has just opened.
	for i: int in 240:
		await scene_tree.process_frame
		_record(game, seen)
	for skill: Key in SKILLS:
		await _start_a_game(scene_tree, demo, skill)
		await _play(scene_tree, game, seen, 40)
		for step: Array in EDGES:
			await _hold(scene_tree, game, seen, step[0], step[1])
	var out: Array = []
	for key: String in seen:
		out.append(seen[key])
	return {"sprites": out, "distinct": out.size()}


## Menu, a skill, and into play. Ctrl-M is the game's own way back to the setup whatever it was doing.
func _start_a_game(scene_tree: SceneTree, demo: Node, skill: Key) -> void:
	await _tap(scene_tree, KEY_M)
	for i: int in 1200:
		await scene_tree.process_frame
		if demo._stage == AlleyCatControls.Stage.ASKING_SKILL:
			break
	await _tap(scene_tree, skill)
	for i: int in 1200:
		await scene_tree.process_frame
		if demo._stage == AlleyCatControls.Stage.PLAYING:
			break


## Walks the cat through every direction a number of times, recording what the game draws throughout. The
## report is read every frame because it is cleared on the game's own tick and a tick spans many frames.
func _play(scene_tree: SceneTree, game: Object, seen: Dictionary, rounds: int) -> void:
	for round: int in rounds:
		await _hold(scene_tree, game, seen, WALK[round % WALK.size()], HOLD)
		# Standing still matters too: the game draws poses here that it draws nowhere else.
		await _hold(scene_tree, game, seen, &"", 10)


func _hold(scene_tree: SceneTree, game: Object, seen: Dictionary, action: StringName, frames: int) -> void:
	if not action.is_empty():
		Input.action_press(action)
	for i: int in frames:
		await scene_tree.process_frame
		_record(game, seen)
	if not action.is_empty():
		Input.action_release(action)


func _record(game: Object, seen: Dictionary) -> void:
	for sprite: Dictionary in game.call(&"get_sprites"):
		if int(sprite.get("stride", 0)) > 0:
			continue
		var source: int = int(sprite["source"])
		var w: int = int(sprite["width"])
		var h: int = int(sprite["height"])
		var key: String = "%d_%d_%d" % [source, w, h]
		var entry: Dictionary = seen.get(key, {
			"source": source, "width": w, "height": h, "times": 0, "masked": 0,
			"kind": str(sprite.get("kind", "masked" if bool(sprite["masked"]) else "plain")), "buffer": false,
		})
		entry["times"] = int(entry["times"]) + 1
		if bool(sprite["masked"]):
			entry["masked"] = int(entry["masked"]) + 1
		if not bool(entry["buffer"]) and not _matches_file(game, source, w / 4 * h):
			entry["buffer"] = true
		seen[key] = entry


## Whether the bytes the game is drawing from are the bytes CAT.EXE holds there. Where they are not, the
## game wrote them, and a place the game writes is a buffer rather than artwork.
func _matches_file(game: Object, source: int, length: int) -> bool:
	var at: int = source - LOAD_ADDRESS + HEADER
	if at < 0 or at + length > _exe.size():
		return false
	var live: PackedByteArray = game.call(&"peek", source, length)
	return _exe.slice(at, at + length) == live


func _tap(scene_tree: SceneTree, key: Key) -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = key
	down.keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	for i: int in 10:
		await scene_tree.process_frame
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = key
	up.keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	await scene_tree.process_frame

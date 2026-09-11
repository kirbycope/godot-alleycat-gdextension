extends GutTest

## Purpose: Checks the AlleyCat node boots CAT.EXE, renders frames, and that the controls actually
## reach the game. The mapping is in C++, so the only honest way to test it is to drive real input
## events and ask the node and the game what happened. Skipped on platforms without a built library.

const EXE: String = "res://addons/godot_alleycat_gdextension/assets/CAT.EXE"
## The game's own clock runs on instructions retired, so winding the multiplier up makes a test that
## has to sit through the attract screen take a second rather than ten.
const FAST: float = 20.0
## How much of the framebuffer has to be painted before the game counts as playing rather than
## asking a question. The node and the demo both use the same figure.
const PAINTED: int = 512

var game: TextureRect


func before_each() -> void:
	if not ClassDB.class_exists(&"AlleyCat"):
		return
	game = ClassDB.instantiate(&"AlleyCat") as TextureRect
	game.set(&"exe_path", EXE)
	game.set(&"speed", FAST)
	add_child_autofree(game)


## Presses a pad button and holds it long enough for the game to notice. The game samples its port
## every couple of BIOS ticks, and a press of a frame or two can fall entirely between two looks.
func _tap_pad(button: int, frames: int = 30) -> void:
	var down := InputEventJoypadButton.new()
	down.button_index = button
	down.pressed = true
	Input.parse_input_event(down)
	await wait_process_frames(frames)
	var up := InputEventJoypadButton.new()
	up.button_index = button
	up.pressed = false
	Input.parse_input_event(up)
	await wait_process_frames(10)


func _push_stick(axis: int, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = axis
	motion.axis_value = value
	Input.parse_input_event(motion)
	await wait_process_frames(4)


## Runs until the game asks its first question, or gives up. The attract screen plays first.
func _wait_for_the_question(frames: int = 4000) -> bool:
	for i in frames:
		await wait_process_frames(1)
		if game.call(&"get_screen_painted") < PAINTED and "joystick" in game.call(&"get_text"):
			return true
	return false


func test_the_game_boots_and_draws() -> void:
	if game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	assert_true(game.call(&"is_loaded"), "CAT.EXE ships with the addon, so it should load")
	assert_true(game.call(&"is_running"), "autostart runs it")
	await wait_process_frames(60)
	assert_true(game.call(&"is_ready"), "the game sets a graphics mode on its way in")
	assert_eq(game.texture.get_size(), Vector2(320, 200), "CGA mode 4 is 320x200")
	assert_gt(game.call(&"get_screen_painted"), PAINTED, "the attract screen should be drawn")


## The setup questions are printed through BIOS teletype rather than drawn, so a host that ignores
## the text rows shows a blank screen and the player assumes it has hung.
func test_the_setup_questions_arrive_as_text() -> void:
	if game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	assert_true(await _wait_for_the_question(), "the game should ask about a joystick")
	assert_lt(game.call(&"get_screen_painted"), PAINTED, "and blank the screen to ask it")


## The whole point of the game port: answering yes has to get somewhere. Before the port was
## emulated the game failed its own adapter check here and the answer did nothing.
func test_the_pad_answers_the_setup_and_starts_the_game() -> void:
	if game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	assert_true(await _wait_for_the_question(), "the game should ask about a joystick")

	await _tap_pad(JOY_BUTTON_A)
	assert_string_contains(game.call(&"get_text"), "skill level",
			"A answers yes, and the skill menu follows")

	await _tap_pad(JOY_BUTTON_A)
	assert_string_contains(game.call(&"get_text"), "joystick button to start",
			"A picks Kitten, and the game asks for the button")

	# The last thing the setup asks for is the joystick button, on a screen that is still text, so
	# this is the press that would have been swallowed if A only worked once play had started.
	await _tap_pad(JOY_BUTTON_A, 120)
	await wait_process_frames(60)
	assert_gt(game.call(&"get_screen_painted"), PAINTED, "the alley should be on screen")


func test_the_stick_and_the_dpad_reach_the_game_port() -> void:
	if game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	await wait_process_frames(10)
	assert_eq(game.call(&"get_joystick_state")["x"], 0, "nothing pushed, nothing sent")

	await _push_stick(JOY_AXIS_LEFT_X, 1.0)
	assert_eq(game.call(&"get_joystick_state")["x"], 1, "right")
	await _push_stick(JOY_AXIS_LEFT_X, -1.0)
	assert_eq(game.call(&"get_joystick_state")["x"], -1, "left")
	await _push_stick(JOY_AXIS_LEFT_X, 0.0)
	assert_eq(game.call(&"get_joystick_state")["x"], 0, "centred")

	await _push_stick(JOY_AXIS_LEFT_Y, -1.0)
	assert_eq(game.call(&"get_joystick_state")["y"], -1, "up the fence")
	await _push_stick(JOY_AXIS_LEFT_Y, 1.0)
	assert_eq(game.call(&"get_joystick_state")["y"], 1, "down")
	await _push_stick(JOY_AXIS_LEFT_Y, 0.0)

	var right := InputEventJoypadButton.new()
	right.button_index = JOY_BUTTON_DPAD_RIGHT
	right.pressed = true
	Input.parse_input_event(right)
	await wait_process_frames(4)
	assert_eq(game.call(&"get_joystick_state")["x"], 1, "the d-pad steers too")
	right.pressed = false
	Input.parse_input_event(right)
	await wait_process_frames(4)
	assert_eq(game.call(&"get_joystick_state")["x"], 0)


## A stick barely off centre is drift, not a direction. The game resolves three positions per axis
## and nothing finer, so anything short of the threshold has to read as centred.
func test_a_nudged_stick_is_not_a_direction() -> void:
	if game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	await _push_stick(JOY_AXIS_LEFT_X, 0.3)
	assert_eq(game.call(&"get_joystick_state")["x"], 0, "drift is not a push")
	await _push_stick(JOY_AXIS_LEFT_X, 0.9)
	assert_eq(game.call(&"get_joystick_state")["x"], 1, "a real push is")
	await _push_stick(JOY_AXIS_LEFT_X, 0.0)


## The arrow keys drive the port as well as the keyboard, so a player who answered yes to the
## joystick question and then reached for the keyboard is not stranded.
func test_the_arrow_keys_drive_the_port_too() -> void:
	if game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	await wait_process_frames(10)
	var left := InputEventKey.new()
	left.keycode = KEY_LEFT
	left.physical_keycode = KEY_LEFT
	left.pressed = true
	Input.parse_input_event(left)
	await wait_process_frames(4)
	assert_eq(game.call(&"get_joystick_state")["x"], -1, "Left is left on the port as well")
	left.pressed = false
	Input.parse_input_event(left)
	await wait_process_frames(4)
	assert_eq(game.call(&"get_joystick_state")["x"], 0)

	var alt := InputEventKey.new()
	alt.keycode = KEY_ALT
	alt.physical_keycode = KEY_ALT
	alt.pressed = true
	Input.parse_input_event(alt)
	await wait_process_frames(4)
	assert_true(game.call(&"get_joystick_state")["button_1"], "Alt is the joystick button too")
	alt.pressed = false
	Input.parse_input_event(alt)
	await wait_process_frames(4)
	assert_false(game.call(&"get_joystick_state")["button_1"])


## The pad must not be the only way in. A held d-pad wins over a stick a player is also touching.
func test_the_dpad_wins_over_the_stick() -> void:
	if game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	await _push_stick(JOY_AXIS_LEFT_X, -1.0)
	var right := InputEventJoypadButton.new()
	right.button_index = JOY_BUTTON_DPAD_RIGHT
	right.pressed = true
	Input.parse_input_event(right)
	await wait_process_frames(4)
	assert_eq(game.call(&"get_joystick_state")["x"], 1, "the d-pad is the deliberate one")
	right.pressed = false
	Input.parse_input_event(right)
	await _push_stick(JOY_AXIS_LEFT_X, 0.0)


## Turning the adapter off is how a host says "keyboard only". The game then refuses the joystick
## question rather than leaving the player with a dead stick.
func test_the_adapter_can_be_turned_off() -> void:
	if game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	assert_true(game.get(&"joystick"), "an adapter is reported by default")
	game.set(&"joystick", false)
	assert_false(game.get(&"joystick"))


func test_a_missing_exe_is_reported_rather_than_silent() -> void:
	if game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	var reasons: Array = []
	game.connect(&"load_failed", func(reason: String) -> void: reasons.append(reason))
	game.set(&"exe_path", "res://addons/godot_alleycat_gdextension/assets/NOPE.EXE")
	assert_false(game.call(&"load_game"), "a missing file is a failed load")
	assert_eq(reasons.size(), 1, "and it says so")
	assert_string_contains(reasons[0], "NOPE.EXE")

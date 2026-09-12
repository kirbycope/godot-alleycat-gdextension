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
var _bound: Array[String] = []


func before_each() -> void:
	if not ClassDB.class_exists(&"AlleyCat"):
		return
	_bind_inputs()
	game = ClassDB.instantiate(&"AlleyCat") as TextureRect
	game.set(&"exe_path", EXE)
	game.set(&"speed", FAST)
	add_child_autofree(game)


func after_each() -> void:
	_release_inputs()


## Binds every action the game listens for to a key of its own, the way a host without the controls
## addon has to. Nothing reaches the game until something does this, which is the contract.
func _bind_inputs() -> void:
	var key: int = KEY_F1
	for action: String in AlleyCat.get_expected_inputs():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
			_bound.append(action)
			key += 1


func _release_inputs() -> void:
	for action: String in _bound:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
	_bound.clear()


## Holds an action down for long enough that the game notices. It samples its port every couple of
## BIOS ticks, and a press of a frame or two can fall entirely between two looks.
func _hold(action: String, frames: int = 30) -> void:
	Input.action_press(action)
	await wait_process_frames(frames)
	Input.action_release(action)
	await wait_process_frames(10)


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


## The setup, start to finish, on the inputs a pad can reach. Each question has an action of its own
## now: the game asks them in text and nothing overloads one button into answering all three, which
## is what the published input list buys.
func test_the_setup_is_answerable_and_starts_the_game() -> void:
	if game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	assert_true(await _wait_for_the_question(), "the game should ask about a joystick")

	await _hold("alleycat_yes")
	assert_string_contains(game.call(&"get_text"), "skill level",
			"yes, and the skill menu follows")

	await _hold("alleycat_kitten")
	assert_string_contains(game.call(&"get_text"), "joystick button to start",
			"a skill, and the game asks for the button")

	# The last thing the setup asks for is the joystick button, and Alt is it.
	await _hold("alleycat_alt", 120)
	await wait_process_frames(60)
	assert_gt(game.call(&"get_screen_painted"), PAINTED, "the alley should be on screen")


func test_the_directions_reach_the_game_port() -> void:
	if game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	await wait_process_frames(10)
	assert_eq(game.call(&"get_joystick_state")["x"], 0, "nothing held, nothing sent")

	Input.action_press("alleycat_right")
	await wait_process_frames(4)
	assert_eq(game.call(&"get_joystick_state")["x"], 1, "right")
	Input.action_release("alleycat_right")
	Input.action_press("alleycat_left")
	await wait_process_frames(4)
	assert_eq(game.call(&"get_joystick_state")["x"], -1, "left")
	Input.action_release("alleycat_left")
	await wait_process_frames(4)
	assert_eq(game.call(&"get_joystick_state")["x"], 0, "centred")

	Input.action_press("alleycat_up")
	await wait_process_frames(4)
	assert_eq(game.call(&"get_joystick_state")["y"], -1, "up the fence")
	Input.action_release("alleycat_up")
	Input.action_press("alleycat_down")
	await wait_process_frames(4)
	assert_eq(game.call(&"get_joystick_state")["y"], 1, "down")
	Input.action_release("alleycat_down")


## Holding both ways at once is a centred stick, not a doubled one, which is what a player rolling a
## thumb across a d-pad does for a frame or two.
func test_opposite_directions_cancel() -> void:
	if game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	Input.action_press("alleycat_left")
	Input.action_press("alleycat_right")
	await wait_process_frames(4)
	assert_eq(game.call(&"get_joystick_state")["x"], 0, "left and right together is neither")
	Input.action_release("alleycat_left")
	await wait_process_frames(4)
	assert_eq(game.call(&"get_joystick_state")["x"], 1, "letting one go leaves the other")
	Input.action_release("alleycat_right")


## Alt is the game's action key and its joystick button at once, so the port has to see it too.
func test_the_action_key_is_the_joystick_button() -> void:
	if game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	await wait_process_frames(10)
	assert_false(game.call(&"get_joystick_state")["button_1"])
	Input.action_press("alleycat_alt")
	await wait_process_frames(4)
	assert_true(game.call(&"get_joystick_state")["button_1"], "Alt is the joystick button too")
	Input.action_release("alleycat_alt")
	await wait_process_frames(4)
	assert_false(game.call(&"get_joystick_state")["button_1"])


## The node reads the InputMap and nothing else, so the list it publishes is the whole contract. A
## host binds these or the game cannot be played, and the catalog the HUD picks from is a copy of it.
func test_the_published_input_list_is_the_whole_contract() -> void:
	var expected: PackedStringArray = AlleyCat.get_expected_inputs()
	assert_gt(expected.size(), 0, "the node says what it listens for")
	var catalog: ControlsInputCatalog = load(
			"res://addons/godot_alleycat_gdextension/resources/alley_cat_inputs.tres")
	var published: Array[StringName] = catalog.actions
	assert_eq(published.size(), expected.size(), "the catalog lists exactly what the node listens for")
	for action: String in expected:
		assert_true(published.has(StringName(action)), "%s is in the catalog" % action)


## Unbound is not the same as unused, and a player staring at a game that ignores them deserves a
## better answer than silence.
func test_an_unbound_input_is_reported() -> void:
	if game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	assert_eq(game.call(&"get_missing_inputs").size(), 0, "the suite binds them all")
	_release_inputs()
	var missing: PackedStringArray = game.call(&"get_missing_inputs")
	assert_eq(missing.size(), AlleyCat.get_expected_inputs().size(), "with none bound, all are missing")


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


## Rewinding is not the machine run backwards - nothing can do that - it is a whole earlier machine put
## back, so what it has to prove is that the picture afterwards is the one that was there before, byte
## for byte, and not merely something that looks earlier.
func test_rewinding_puts_the_exact_earlier_frame_back() -> void:
	if not ClassDB.class_exists(&"AlleyCat"):
		pass_test("AlleyCat is not built for this platform")
		return
	var game = ClassDB.instantiate(&"AlleyCat")
	add_child_autofree(game)
	if not game.has_method(&"get_rewind_available"):
		pass_test("this platform's library predates rewind")
		return
	if not game.call(&"is_loaded"):
		pass_test("CAT.EXE is not here to run")
		return

	game.set(&"speed", 20.0)
	for i in 120:
		await wait_process_frames(1)
	assert_gt(game.call(&"get_rewind_depth"), 0, "running fills the ring")

	var seen := {}
	for i in 60:
		await wait_process_frames(1)
		seen[game.call(&"get_instructions")] = hash(game.call(&"get_frame").get_data())

	game.set(&"rewinding", true)
	var checked := 0
	var identical := 0
	for i in 40:
		await wait_process_frames(1)
		var icount = game.call(&"get_instructions")
		if seen.has(icount):
			checked += 1
			if seen[icount] == hash(game.call(&"get_frame").get_data()):
				identical += 1
	game.set(&"rewinding", false)

	assert_gt(checked, 0, "the rewind should walk back through frames it has already shown")
	assert_eq(identical, checked, "and every one of them comes back exactly as it was")


## Turning rewind off frees the ring rather than merely stopping it being read, because the whole point
## of the setting is the megabyte a snapshot it costs.
func test_no_rewind_seconds_means_no_ring() -> void:
	if not ClassDB.class_exists(&"AlleyCat"):
		pass_test("AlleyCat is not built for this platform")
		return
	var game = ClassDB.instantiate(&"AlleyCat")
	add_child_autofree(game)
	if not game.has_method(&"get_rewind_available"):
		pass_test("this platform's library predates rewind")
		return

	game.set(&"rewind_seconds", 0.0)
	for i in 30:
		await wait_process_frames(1)
	assert_eq(game.call(&"get_rewind_depth"), 0, "nothing is kept")
	assert_eq(game.call(&"get_rewind_available"), 0.0)


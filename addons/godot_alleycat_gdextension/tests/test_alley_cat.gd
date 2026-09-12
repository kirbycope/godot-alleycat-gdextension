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



## An effect count, not a voice. The voice says who is sounding, which is a level, and a level that is
## already EFFECTS says nothing at all when the next effect begins: it used to be set on every frequency
## write and never cleared, so a host watching it for "something happened" saw exactly one event, at the
## beginning, and then silence for the rest of the game.
func test_a_sound_starting_is_countable_rather_than_a_level_that_never_falls() -> void:
	if game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	if not game.has_method(&"get_effect_starts"):
		fail_test("This library predates get_effect_starts; rebuild it")
		return
	var voices: Dictionary = {}
	var starts: Array[int] = []
	for i in 2000:
		await wait_process_frames(1)
		voices[int(game.call(&"get_voice"))] = true
		starts.append(int(game.call(&"get_effect_starts")))
	assert_gt(starts[-1], starts[0], "The attract screen makes sounds, so the count should have risen")
	assert_true(voices.has(0), "and the voice should fall back to none between them rather than latching")


## What tells a room from a sprite. Pixels cannot: Alley Cat's screens share a background colour, so two
## different places agree on most of their pixels, and a screen arrives over several frames rather than in
## one. The machine knows what it drew.
func test_the_game_says_how_much_of_the_screen_it_drew() -> void:
	if game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	if not game.has_method(&"get_video_writes"):
		fail_test("This library predates get_video_writes; rebuild it")
		return
	var biggest: int = 0
	var busiest_quiet_frame: int = 0
	var last: int = int(game.call(&"get_video_writes"))
	for i in 3000:
		await wait_process_frames(1)
		var now: int = int(game.call(&"get_video_writes"))
		var drawn: int = now - last
		last = now
		biggest = maxi(biggest, drawn)
		if drawn < 4000:
			busiest_quiet_frame = maxi(busiest_quiet_frame, drawn)
	assert_gt(biggest, 12000, "Changing screen draws the whole 16K CGA window at once")
	assert_lt(busiest_quiet_frame, 4000,
		"and a frame that only moves sprites costs far less, so the two are told apart by size alone")


## The machine's memory, which is where everything the game knows about itself lives. Alley Cat is one 1984
## assembly program whose variables sit at fixed addresses, so a host that can read them can follow the score
## and the lives rather than guessing at them from pixels.
func test_the_machine_s_memory_can_be_read() -> void:
	if game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	if not game.has_method(&"peek"):
		fail_test("This library predates peek; rebuild it")
		return
	var load: int = int(game.call(&"get_load_address"))
	assert_eq(load, 0x10000, "The image is loaded at segment 0x1000, as the header has it")
	# Wide enough to be past the zero fill the image starts with, which is 82 bytes of it.
	var bytes: PackedByteArray = game.call(&"peek", load, 4096)
	assert_eq(bytes.size(), 4096, "A read inside memory gives back what was asked for")
	var nonzero: int = 0
	for byte: int in bytes:
		if byte != 0:
			nonzero += 1
	assert_gt(nonzero, 1000, "and CAT.EXE's own code is there rather than a blank megabyte")

	assert_eq(int(game.call(&"peek_u8", load)), bytes[0], "A single byte agrees with the block read")
	# The 8086 stores a word low byte first, so a counter read as a word is the number the game means.
	assert_eq(int(game.call(&"peek_u16", load)), bytes[0] | (bytes[1] << 8))
	assert_eq((game.call(&"peek", 1 << 20, 16) as PackedByteArray).size(), 0, "Past the top there is nothing")
	assert_eq(int(game.call(&"peek_u8", 1 << 20)), -1, "and a byte there reports itself missing")


## How anything in the game gets found. A score, a life count or a sprite is a place in memory, and the way
## to that place is the routine that touches it: watch the few bytes of screen something is drawn in, let the
## game draw, and what comes back are offsets into CAT.EXE that a disassembly explains.
func test_watching_memory_reports_the_code_that_wrote_to_it() -> void:
	if game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	if not game.has_method(&"watch"):
		fail_test("This library predates watch; rebuild it")
		return
	# A band across the middle of the picture, which the game draws over constantly.
	var base: int = 0xB8000
	game.call(&"watch", base + 30 * 80, base + 45 * 80)
	await wait_process_frames(600)
	var writers: PackedInt32Array = game.call(&"get_watch_writers")
	assert_gt(int(game.call(&"get_watch_hits")), 0, "The game draws into the middle of the screen")
	assert_gt(writers.size(), 0, "so the code that drew there should be named")
	for writer: int in writers:
		assert_lt(writer, 55067, "Writers are offsets into CAT.EXE, which is 55,067 bytes long")

	# An empty range is the watch turned off, and it forgets what the last one found.
	game.call(&"watch", 0, 0)
	await wait_process_frames(60)
	assert_eq(int(game.call(&"get_watch_hits")), 0, "Nothing is watched, so nothing is counted")
	assert_eq((game.call(&"get_watch_writers") as PackedInt32Array).size(), 0)


## The other half of reading memory. Carrying a high score across runs means putting one back, and the game
## keeps it in memory like everything else, so a host has to be able to write there.
func test_memory_can_be_written_as_well_as_read() -> void:
	if game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	if not game.has_method(&"poke"):
		fail_test("This library predates poke; rebuild it")
		return
	# Somewhere harmless and far from the program: the top of the megabyte.
	var at: int = (1 << 20) - 32
	var written: PackedByteArray = PackedByteArray([4, 2, 0, 6, 9])
	assert_eq(int(game.call(&"poke", at, written)), 5, "Five bytes in")
	assert_eq(game.call(&"peek", at, 5), written, "and the same five back out")
	assert_eq(int(game.call(&"poke", 1 << 20, written)), 0, "Past the top nothing is written")


## Where the game reads its variables from. A disassembly gives a variable as a bare offset, and this is what
## that offset is counted from, so the two together make an address. Alley Cat's is not where the image was
## loaded, which is why an offset read straight off the disassembly finds rubbish.
func test_the_data_segment_is_reported_so_an_offset_becomes_an_address() -> void:
	if game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	if not game.has_method(&"get_data_address"):
		fail_test("This library predates get_data_address; rebuild it")
		return
	await wait_process_frames(120)
	var data: int = int(game.call(&"get_data_address"))
	assert_gt(data, 0, "The game sets a data segment on its way in")
	assert_eq(data % 16, 0, "A segment base is a paragraph, so it is a multiple of 16")
	assert_lt(data, 1 << 20, "and it points inside the megabyte")


## The score and the high score, found by reading the disassembly in alley-decomp rather than by scanning:
## sub_09922 hands the digit printer a pointer to 0x1f89 and sub_0992C one to 0x1f82, and the printer draws
## seven digits with a gap after the third, which is the "000-0000" the fence shows twice.
func test_the_score_and_high_score_are_seven_decimal_digits_where_the_disassembly_says() -> void:
	if game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	if not game.has_method(&"get_data_address"):
		fail_test("This library predates get_data_address; rebuild it")
		return
	assert_true(await _wait_for_the_question(), "the game should reach its setup")
	await wait_process_frames(120)
	var data: int = int(game.call(&"get_data_address"))
	for label: String in ["score", "high score"]:
		var at: int = data + (0x1f82 if label == "score" else 0x1f89)
		var digits: PackedByteArray = game.call(&"peek", at, 7)
		assert_eq(digits.size(), 7, "The %s is seven bytes" % label)
		for digit: int in digits:
			assert_lt(digit, 10, "and every one of them is a decimal digit, not a byte of a number")

	# Writing digits in and reading them back is what the restore at startup does.
	var wanted: PackedByteArray = PackedByteArray([0, 0, 4, 2, 0, 6, 9])
	game.call(&"poke", data + 0x1f89, wanted)
	assert_eq(game.call(&"peek", data + 0x1f89, 7), wanted, "A high score put in is a high score read back")

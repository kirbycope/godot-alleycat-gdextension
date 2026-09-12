extends GutTest

## Purpose: The demo scene puts the game on screen with the controls HUD around it, and says what is
## missing instead of failing where the library is not built. The HUD is the controls addon itself,
## instanced in the scene, so what is checked here is the wiring: the slots are mapped, the actions
## they name exist, and the HUD follows the game between its setup questions and play.

const DEMO_SCENE: PackedScene = preload("res://addons/godot_alleycat_gdextension/scenes/demo/demo.tscn")
const PAINTED: int = 512

var demo: Control


func before_each() -> void:
	demo = DEMO_SCENE.instantiate()
	add_child_autofree(demo)


## The demo has to open on a platform with no built library, which is why the game node is built in
## code rather than placed in the scene: a scene naming a GDExtension type cannot load without it.
func test_the_demo_opens_without_the_library_and_says_why() -> void:
	if ClassDB.class_exists(&"AlleyCat"):
		assert_not_null(demo.game, "with the library there is a game to show")
		pass_test("AlleyCat is built for this platform")
		return
	assert_null(demo.game)
	assert_true(demo.missing.visible, "the demo says what is missing rather than failing to open")
	assert_string_contains(demo.missing.text, "not built for this platform")
	assert_false(demo.controls.visible, "and the HUD is no use with nothing to control")


func test_the_game_fills_the_screen_and_the_hud_shows() -> void:
	if not ClassDB.class_exists(&"AlleyCat"):
		pass_test("AlleyCat is not built for this platform")
		return
	assert_not_null(demo.game)
	assert_eq(demo.game.get_parent(), demo.screen, "the game belongs in the aspect ratio container")
	assert_true(demo.game.call(&"is_loaded"), "CAT.EXE ships with the addon")
	assert_false(demo.missing.visible)
	assert_true(demo.controls.visible, "the HUD shows around the screen")


## The scene is the mapping now: the game reads these actions and nothing else reaches it. So a slot
## naming something outside the list the game published is a dead button, and this is what says so.
##
## Rewind is the exception and is deliberate. It is the host's, not the game's - Alley Cat has no idea
## it is happening - but it earns a slot because a player has no other way to find out it exists.
const HOST_ACTIONS: Array[String] = ["alleycat_rewind"]

func test_every_slot_names_an_input_the_game_listens_for() -> void:
	var expected: PackedStringArray = AlleyCat.get_expected_inputs()
	for slot: String in AlleyCatControls.BINDINGS:
		var action: StringName = demo.controls.get(&"action_" + slot)
		assert_ne(String(action), "", "%s should name an action" % slot)
		if HOST_ACTIONS.has(String(action)):
			continue
		assert_true(expected.has(String(action)), "%s names an input the game reads" % slot)


## The rewind button is on the HUD, and on the trigger, which is where it is bound.
func test_rewind_is_on_the_trigger() -> void:
	assert_eq(String(demo.controls.action_axis_4_plus), "alleycat_rewind")
	assert_eq(demo.controls.joypad_axis_4_plus_label.text, "Rewind", "and says so")
	assert_true(demo.controls.joypad_axis_4_plus.visible, "and is drawn, being a slot that is mapped")


## Every input the game listens for needs a button, or it cannot be reached with a pad at all. The
## setup answers are the ones that bite: the game will not go on until one of them is pressed.
func test_every_input_the_game_listens_for_has_a_button() -> void:
	var mapped: Array[String] = []
	for slot: String in AlleyCatControls.BINDINGS:
		mapped.append(String(demo.controls.get(&"action_" + slot)))
	for action: String in AlleyCat.get_expected_inputs():
		# Button 2 the game never reads, a restart is not something to leave on a pad, and Alt is the
		# demo's to press: the only screens that want it are waits, and it answers them itself.
		if action in ["alleycat_button_2", "alleycat_restart", "alleycat_alt"]:
			continue
		assert_true(mapped.has(action), "%s is on a button" % action)
	assert_true(InputMap.has_action(&"alleycat_alt"), "Alt is still bound, just not drawn")


## The addon registers any action a slot names that the project has not declared, so every one of
## them exists by the time the HUD is ready. A slot naming an action nothing registers is a dead
## button that still draws, and here it would also be an input the game never hears.
func test_the_addon_registered_every_action_the_slots_name() -> void:
	for slot: String in AlleyCatControls.BINDINGS:
		var action: StringName = demo.controls.get(&"action_" + slot)
		assert_true(InputMap.has_action(action), "%s is registered" % action)


## The catalog is what turns the slots into a picker, so without it they are free text again and the
## whole point of publishing the list is lost.
func test_the_hud_picks_from_the_list_the_game_published() -> void:
	assert_not_null(demo.controls.input_catalog, "the HUD was handed the game's list")
	for property: Dictionary in demo.controls.get_property_list():
		if String(property["name"]).begins_with("action_"):
			assert_eq(property["hint"], PROPERTY_HINT_ENUM, "%s is a picker" % property["name"])
			break


## A blank slot is a button the game does not use, and the addon hides it. Alley Cat is a one-stick
## game with nothing on the shoulders, the triggers or the right stick.
func test_the_buttons_the_game_does_not_use_are_left_blank() -> void:
	for slot: String in ["button_7", "button_8", "button_9", "button_10",
			"axis_5_plus", "look_up", "look_down", "look_left", "look_right"]:
		assert_eq(String(demo.controls.get(&"action_" + slot)), "", "%s is not a button here" % slot)


## Jumping in Alley Cat is pushing up, and jumping in Godot is the bottom face button and the space bar,
## so the one has to be wired to the other: the button says Jump, sends alleycat_up, and reads Space.
func test_jump_is_the_face_button_the_space_bar_and_up() -> void:
	assert_eq(String(demo.controls.action_button_0), "alleycat_up")
	assert_eq(demo.controls.joypad_button_0_label.text, "Jump")

	for event: InputEvent in [_key(KEY_SPACE), _pad_button(JOY_BUTTON_A), _key(KEY_UP)]:
		assert_true(InputMap.action_has_event("alleycat_up", event), "alleycat_up answers to it")


func _key(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = keycode
	return event


func _pad_button(button: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	return event


func test_the_slots_are_labelled_with_what_the_game_does() -> void:
	assert_eq(demo.controls.joypad_button_0_label.text, "Jump")
	assert_eq(demo.controls.joypad_button_1_label.text, "Sound")
	assert_eq(demo.controls.joypad_button_4_label.text, "Paws")
	assert_eq(demo.controls.joypad_button_6_label.text, "Menu")
	assert_eq(demo.controls.left_joystick_label.text, "Move")


## The game asks its questions in text and a pad has no letters, so the face buttons stand in for
## them while it does, and the scene's own words come back when play starts.
func test_the_labels_swap_for_the_setup_questions_and_back() -> void:
	demo.controls.set_setting_up(true)
	assert_eq(demo.controls.joypad_button_3_label.text, "Yes")
	assert_eq(demo.controls.joypad_button_2_label.text, "No")
	assert_eq(demo.controls.joypad_button_11_label.text, "Kitten")
	assert_eq(demo.controls.joypad_button_14_label.text, "Alley Cat")

	demo.controls.set_setting_up(false)
	assert_eq(demo.controls.joypad_button_0_label.text, "Jump", "the scene's own words come back")
	assert_eq(demo.controls.joypad_button_1_label.text, "Sound")


## The game blanks the graphics screen to ask a question and paints it to play, and the HUD has to
## follow it, because the same buttons mean different things on the two screens.
func test_the_hud_follows_the_game_onto_its_setup_screen() -> void:
	if not ClassDB.class_exists(&"AlleyCat"):
		pass_test("AlleyCat is not built for this platform")
		return
	demo.game.set(&"speed", 20.0)
	var asked := false
	for i in 4000:
		await wait_process_frames(1)
		if demo.game.call(&"get_screen_painted") < PAINTED and "joystick" in demo.game.call(&"get_text"):
			asked = true
			break
	assert_true(asked, "the game should get as far as its first question")

	# It is asked, but it is not the player's to answer: the adapter is off, so the only answer the
	# game will take is no, and the demo gives it. What the player should end up looking at is the one
	# question that is a real choice.
	var reached_the_skill_menu := false
	for i in 4000:
		await wait_process_frames(1)
		if "skill level" in demo.game.call(&"get_text"):
			reached_the_skill_menu = true
			break
	await wait_process_frames(2)
	assert_true(reached_the_skill_menu, "the demo answers the joystick question for the player")
	assert_true(demo.prompt.visible, "the question is printed, not drawn, so the demo shows the text")
	assert_string_contains(demo.prompt.text, "skill level")
	assert_false(demo.prompt.text.contains("joystick"), "and only the question still being asked")
	assert_true(demo.controls.joypad_button_11.visible, "with the d-pad that answers it")


func test_a_missing_game_is_explained_rather_than_blank() -> void:
	demo._on_load_failed("Copy your own CAT.EXE to somewhere")
	assert_true(demo.missing.visible)
	assert_string_contains(demo.missing.text, "CAT.EXE")
	assert_false(demo.controls.visible, "the HUD is no use with nothing to control")
	assert_false(demo.prompt.visible)


## The paws menu is the host's, not the game's. Opening it stops the machine outright, which is a
## truer pause than Alley Cat's own: the game has no idea it happened and cannot have opinions about
## what the player may do next.
func test_the_paws_menu_stops_the_machine() -> void:
	if not ClassDB.class_exists(&"AlleyCat"):
		pass_test("AlleyCat is not built for this platform")
		return
	if not demo.game.call(&"is_loaded"):
		pass_test("CAT.EXE is not here to run")
		return
	demo.game.set(&"speed", 20.0)
	for i in 20:
		await wait_process_frames(1)

	demo.remaster.set_open(true)
	await wait_process_frames(2)
	var frozen_at = demo.game.call(&"get_instructions")
	for i in 20:
		await wait_process_frames(1)
	assert_eq(demo.game.call(&"get_instructions"), frozen_at, "nothing runs while the menu is up")

	demo.remaster.set_open(false)
	for i in 10:
		await wait_process_frames(1)
	assert_gt(demo.game.call(&"get_instructions"), frozen_at, "and it carries on afterwards")


## The menu is given the looks by the host rather than knowing any of its own, and stepping it moves
## the shader the screen is actually wearing.
func test_the_menu_steps_through_the_looks() -> void:
	assert_eq(demo.remaster.looks.size(), demo.LOOKS.size(), "the demo hands its own list over")

	demo.remaster.set_look(0)
	demo.remaster._on_next_look_pressed()
	assert_eq(demo.remaster.get_look(), 1)
	demo.remaster._on_previous_look_pressed()
	demo.remaster._on_previous_look_pressed()
	assert_eq(demo.remaster.get_look(), demo.LOOKS.size() - 1, "and it wraps at either end")


## The game drives one speaker from two places, so the two can be turned down separately. That is what
## makes a music swap possible at all: silence the tune, keep the effects.
func test_music_and_effects_turn_down_separately() -> void:
	if not ClassDB.class_exists(&"AlleyCat"):
		pass_test("AlleyCat is not built for this platform")
		return
	if not demo.game.has_method(&"get_voice"):
		pass_test("this platform's library predates the voice split")
		return

	demo.remaster._on_music_slider_value_changed(0.0)
	demo.remaster._on_effects_slider_value_changed(0.4)
	assert_eq(demo.game.get(&"music_volume"), 0.0, "the tune is silenced")
	assert_almost_eq(demo.game.get(&"effects_volume"), 0.4, 0.001, "and the effects are not")


## Giving the node a music stream is what silences the game's own tune; taking it away gives it back.
func test_a_replacement_tune_silences_the_game_s_own() -> void:
	if not ClassDB.class_exists(&"AlleyCat"):
		pass_test("AlleyCat is not built for this platform")
		return
	if not demo.game.has_method(&"get_voice"):
		pass_test("this platform's library predates the voice split")
		return

	var sounds = AlleyCatSounds.new()
	sounds.music = AudioStreamGenerator.new()
	demo.remaster.sounds = sounds
	assert_eq(demo.game.get(&"music_volume"), 0.0, "two tunes at once is nobody's idea of a remaster")

	demo.remaster.sounds = null
	assert_eq(demo.game.get(&"music_volume"), 1.0, "and the game's own comes back")



## The lives the cat has left, read out of the game rather than guessed at. sub_098E3 compares 0x1f80 with
## 0x1f81 and redraws the fence digit when they differ, so 0x1f80 is the count and 0x1f81 only a note of what
## has already been painted - which is why writing the count alone is enough to make the game repaint it.
func test_the_lives_are_read_from_the_game() -> void:
	if demo.game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	if not demo.game.has_method(&"peek_u8"):
		fail_test("This library predates peek_u8; rebuild it")
		return
	await wait_seconds(2.0)
	var data: int = int(demo.game.call(&"get_data_address"))
	demo.game.call(&"poke", data + AlleyCatRemaster.LIVES_AT, PackedByteArray([7]))
	# The reading has to settle before it is believed, so give it longer than the settle time.
	await wait_seconds(AlleyCatRemaster.LIVES_STEADY_TIME * 3.0)
	assert_eq(demo.remaster.get_lives(), 7, "What was written is what is read back")

	# A cat has nine lives at most, whatever the saying, and rubbish between screens must not read as a count.
	demo.game.call(&"poke", data + AlleyCatRemaster.LIVES_AT, PackedByteArray([200]))
	assert_eq(demo.remaster.get_lives(), -1, "A byte that is not a count reports itself as no answer")


## The count is polled, and polled every frame it does not hold still: the true value and zero come back
## alternately while a game is on. Measured in play it changed 122 times across three actual deaths, so a
## bare "it went down" test would have fired constantly. The reading has to settle before it is believed.
func test_a_flickering_reading_does_not_count_as_a_death() -> void:
	if demo.game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	if not demo.game.has_method(&"peek_u8"):
		fail_test("This library predates peek_u8; rebuild it")
		return
	await wait_seconds(2.0)
	var data: int = int(demo.game.call(&"get_data_address"))
	var at: int = data + AlleyCatRemaster.LIVES_AT
	demo.game.call(&"poke", at, PackedByteArray([5]))
	await wait_seconds(AlleyCatRemaster.LIVES_STEADY_TIME * 3.0)
	assert_eq(demo.remaster.get_lives(), 5, "Five to start from")
	demo.remaster._wipe = 0.0

	# Flick it away and back faster than the settle time, the way the live reading does.
	for i: int in 6:
		demo.game.call(&"poke", at, PackedByteArray([0]))
		await wait_process_frames(2)
		demo.game.call(&"poke", at, PackedByteArray([5]))
		await wait_process_frames(2)
	assert_eq(demo.remaster._wipe, 0.0, "None of that was a death, so nothing was wiped")

	# A drop that holds is one.
	demo.game.call(&"poke", at, PackedByteArray([4]))
	await wait_seconds(AlleyCatRemaster.LIVES_STEADY_TIME * 3.0)
	assert_gt(demo.remaster._wipe, 0.0, "A count that stays down is a life lost, and that is the wipe")

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
func test_every_slot_names_an_input_the_game_listens_for() -> void:
	var expected: PackedStringArray = AlleyCat.get_expected_inputs()
	for slot: String in AlleyCatControls.BINDINGS:
		var action: StringName = demo.controls.get(&"action_" + slot)
		assert_ne(String(action), "", "%s should name an action" % slot)
		assert_true(expected.has(String(action)), "%s names an input the game reads" % slot)


## Every input the game listens for needs a button, or it cannot be reached with a pad at all. The
## setup answers are the ones that bite: the game will not go on until one of them is pressed.
func test_every_input_the_game_listens_for_has_a_button() -> void:
	var mapped: Array[String] = []
	for slot: String in AlleyCatControls.BINDINGS:
		mapped.append(String(demo.controls.get(&"action_" + slot)))
	for action: String in AlleyCat.get_expected_inputs():
		if action == "alleycat_button_2" or action == "alleycat_restart":
			continue # The game never reads button 2, and a restart is not something to leave on a pad.
		assert_true(mapped.has(action), "%s is on a button" % action)


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
	for slot: String in ["button_7", "button_8", "button_9", "button_10", "axis_4_plus",
			"axis_5_plus", "look_up", "look_down", "look_left", "look_right"]:
		assert_eq(String(demo.controls.get(&"action_" + slot)), "", "%s is not a button here" % slot)


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
	# The demo notices in its own _process, which runs after this test resumes on the same frame.
	await wait_process_frames(2)
	assert_true(demo.prompt.visible, "the question is printed, not drawn, so the demo shows the text")
	assert_string_contains(demo.prompt.text, "joystick")
	assert_eq(demo.controls.joypad_button_3_label.text, "Yes",
			"and the HUD says which button answers it")


func test_a_missing_game_is_explained_rather_than_blank() -> void:
	demo._on_load_failed("Copy your own CAT.EXE to somewhere")
	assert_true(demo.missing.visible)
	assert_string_contains(demo.missing.text, "CAT.EXE")
	assert_false(demo.controls.visible, "the HUD is no use with nothing to control")
	assert_false(demo.prompt.visible)

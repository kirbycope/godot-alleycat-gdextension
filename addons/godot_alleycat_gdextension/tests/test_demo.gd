extends GutTest

## Purpose: The demo scene puts the game on screen with the controls card down each side and the
## on-screen pad for a player with no keyboard, and says so instead of failing where the library is
## not built. What is checked here is the wiring between the three: which one is on screen for the
## device in hand, and that the card follows the game from its setup questions into play.

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
	assert_false(demo.overlay.visible, "and the card is no use with nothing to control")


func test_the_game_fills_the_screen_and_the_card_shows() -> void:
	if not ClassDB.class_exists(&"AlleyCat"):
		pass_test("AlleyCat is not built for this platform")
		return
	assert_not_null(demo.game)
	assert_eq(demo.game.get_parent(), demo.screen, "the game belongs in the aspect ratio container")
	assert_true(demo.game.call(&"is_loaded"), "CAT.EXE ships with the addon")
	assert_false(demo.missing.visible)
	assert_true(demo.overlay.visible, "the controls card shows beside the screen")


## On a phone the pad has the screen edges and the card would only be in its way, so they swap and
## the monitor pulls in to leave the thumb clusters clear.
func test_the_card_gives_way_to_the_pad_on_touch() -> void:
	if not ClassDB.class_exists(&"AlleyCat"):
		pass_test("AlleyCat is not built for this platform")
		return
	demo._on_device_changed(AlleyCatVirtualPad.TOUCH)
	assert_false(demo.overlay.visible, "the card steps aside")
	assert_eq(demo.screen.offset_left, demo.PAD_INSET_SIDE, "and the monitor pulls in for the pad")
	assert_eq(demo.screen.offset_bottom, -demo.PAD_INSET_BOTTOM)

	demo._on_device_changed(1) # MICROSOFT
	assert_true(demo.overlay.visible, "a pad in hand gets the card back")
	assert_eq(demo.overlay.input_type, "xbox", "worded for what is in it")
	assert_eq(demo.screen.offset_left, demo.CARD_INSET, "and the monitor goes back to full height")
	assert_eq(demo.screen.offset_bottom, 0.0)


func test_the_card_is_worded_for_every_device_the_addon_reports() -> void:
	if not ClassDB.class_exists(&"AlleyCat"):
		pass_test("AlleyCat is not built for this platform")
		return
	# The demo indexes its wording by the controls addon's InputType, so a value it has and the
	# demo does not would be an out-of-range crash on a device nobody here is holding.
	for input_type in range(demo.CARD_INPUT_TYPES.size()):
		demo._on_device_changed(input_type)
		assert_eq(demo.overlay.input_type, demo.CARD_INPUT_TYPES[input_type])


## The game blanks the graphics screen to ask a question and paints it to play. Both the card and
## the pad have to follow it, because the same buttons mean different things on the two screens.
func test_the_card_and_the_pad_follow_the_game_onto_its_setup_screen() -> void:
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
	assert_true(demo.overlay.setting_up, "and the card says which button answers it")
	assert_string_contains(demo.overlay.get_node("Left").text, "SETUP")


## The pad is a dependency of the demo, not of the extension, so a project that takes the extension
## alone must still run. This is the branch that makes that true, and it holds with or without a
## built library, so it is the one test here that never skips.
func test_the_pad_is_only_built_where_the_controls_addon_is_installed() -> void:
	if ResourceLoader.exists(AlleyCatVirtualPad.CONTROLS_SCENE):
		assert_not_null(demo.pad.controls, "with the addon installed the HUD is built")
		assert_eq(demo.pad.current_input_type(), demo.pad.controls.get(&"current_input_type"))
	else:
		assert_null(demo.pad.controls, "without it the demo still runs, just without a pad")
		assert_eq(demo.pad.current_input_type(), AlleyCatVirtualPad.KEYBOARD_MOUSE)


func test_a_missing_game_is_explained_rather_than_blank() -> void:
	demo._on_load_failed("Copy your own CAT.EXE to somewhere")
	assert_true(demo.missing.visible)
	assert_string_contains(demo.missing.text, "CAT.EXE")
	assert_false(demo.overlay.visible, "the card is no use with nothing to control")
	assert_false(demo.prompt.visible)

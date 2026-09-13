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
	assert_true(demo.prompt.visible, "the demo says what is missing rather than failing to open")
	assert_string_contains(demo.prompt.text, "not built for this platform")
	assert_false(demo.controls.visible, "and the HUD is no use with nothing to control")


func test_the_game_fills_the_screen_and_the_hud_shows() -> void:
	if not ClassDB.class_exists(&"AlleyCat"):
		pass_test("AlleyCat is not built for this platform")
		return
	assert_not_null(demo.game)
	assert_eq(demo.game.get_parent(), demo.screen, "the game belongs in the aspect ratio container")
	assert_true(demo.game.call(&"is_loaded"), "CAT.EXE ships with the addon")
	assert_false(demo._failed, "so there is nothing to explain")
	assert_true(demo.controls.visible, "the HUD shows around the screen")


## The scene is the mapping now: the game reads these actions and nothing else reaches it. So a slot
## naming something outside the list the game published is a dead button, and this is what says so.
##
## Rewind is the exception and is deliberate. It is the host's, not the game's - Alley Cat has no idea
## it is happening - but it earns a slot because a player has no other way to find out it exists.
const HOST_ACTIONS: Array[String] = ["alleycat_rewind", "alleycat_fullscreen"]

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
		# Button 2 the game never reads, a restart is not something to leave on a pad, and Alt and No are
		# the demo's to press: the only screens that want them are waits and a question about hardware,
		# and it answers both itself.
		if action in ["alleycat_button_2", "alleycat_restart", "alleycat_alt", "alleycat_no"]:
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
## game with nothing on the sticks' buttons, the left shoulder or the right stick; the triggers and the
## right shoulder carry the host's own controls.
func test_the_buttons_the_game_does_not_use_are_left_blank() -> void:
	for slot: String in ["button_1", "button_7", "button_8", "button_9",
			"look_up", "look_down", "look_left", "look_right"]:
		assert_eq(String(demo.controls.get(&"action_" + slot)), "", "%s is not a button here" % slot)


## Jumping in Alley Cat is pushing up, and jumping in Godot is the bottom face button and the space bar,
## so the one has to be wired to the other: the button says Jump, sends alleycat_up, and reads Space.
func test_jump_is_the_face_button_the_space_bar_and_up() -> void:
	assert_eq(String(demo.controls.action_button_0), "alleycat_up")
	assert_eq(demo.controls.joypad_button_0_label.text, "Jump")

	for event: InputEvent in [_key(KEY_SPACE), _pad_button(JOY_BUTTON_A), _key(KEY_UP)]:
		assert_true(InputMap.action_has_event("alleycat_up", event), "alleycat_up answers to it")


## Dropping off a fence in Alley Cat is pushing down, and the left face button is where it sits, so a thumb
## on a phone has Jump and Drop side by side instead of two more arrows to find.
func test_drop_is_the_left_face_button_and_down() -> void:
	assert_eq(String(demo.controls.action_button_2), "alleycat_down")
	assert_eq(demo.controls.joypad_button_2_label.text, "Drop")
	for event: InputEvent in [_pad_button(JOY_BUTTON_X), _key(KEY_DOWN)]:
		assert_true(InputMap.action_has_event("alleycat_down", event), "alleycat_down answers to it")


## The joystick question is the demo's to answer, so No is bound for it to press but sits on no button, and
## answering does not walk the cat down the alley.
func test_the_demo_answers_the_joystick_question_with_no_and_not_with_a_walk() -> void:
	assert_true(InputMap.has_action(&"alleycat_no"), "No is bound")
	demo._answer_the_joystick_question(true)
	assert_true(Input.is_action_pressed(&"alleycat_no"), "the demo holds No down")
	assert_false(Input.is_action_pressed(&"alleycat_down"), "and not Drop, which is on the button No used to be on")
	demo._answer_the_joystick_question(false)
	assert_false(Input.is_action_pressed(&"alleycat_no"), "and lets go when the question is gone")


## On a touchscreen the cat walks on Left and Right alone: Up is Jump and Down is Drop, both face buttons,
## and those two are drawn bigger than the rest because they are what the game is played with.
func test_on_a_touchscreen_jump_and_drop_are_big_and_the_arrows_are_left_and_right() -> void:
	demo.controls.current_input_type = Controls.InputType.TOUCH
	assert_false(demo.controls.key_w.visible, "no Up arrow")
	assert_false(demo.controls.key_s.visible, "no Down arrow")
	assert_true(demo.controls.key_a.visible, "Left stays")
	assert_true(demo.controls.key_d.visible, "and Right")
	assert_eq(demo.controls.joypad_button_0.scale, Vector2.ONE * AlleyCatControls.TOUCH_FACE_SCALE, "Jump is big")
	assert_eq(demo.controls.joypad_button_2.scale, Vector2.ONE * AlleyCatControls.TOUCH_FACE_SCALE, "and so is Drop")
	assert_eq(demo.controls.joypad_button_0.position, AlleyCatControls.TOUCH_JUMP_POSITION, "in the corner")
	demo.controls.current_input_type = Controls.InputType.KEYBOARD_MOUSE
	assert_true(demo.controls.key_w.visible, "a keyboard has all four arrows")
	assert_eq(demo.controls.joypad_button_0.scale, Vector2.ONE, "and the pad-sized buttons")
	assert_ne(demo.controls.joypad_button_0.position, AlleyCatControls.TOUCH_JUMP_POSITION, "back where the scene put it")


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
	assert_eq(demo.controls.joypad_button_4_label.text, "Paws")
	assert_eq(demo.controls.joypad_button_6_label.text, "Menu")
	assert_eq(demo.controls.left_joystick_label.text, "Move")
	# Sound is on the right trigger, across from rewind on the left, and not on a face button: the game
	# calls it Ctrl-S and the face button had S on it, but S is also the S of WASD and walks the cat down
	# the alley, so a player heading downwards was turning the sound on and off the whole way.
	assert_eq(demo.controls.joypad_axis_5_plus_label.text, "Sound")
	assert_eq(String(demo.controls.action_axis_5_plus), "alleycat_sound")
	assert_false(InputMap.action_get_events(&"alleycat_down").any(
			func(e: InputEvent) -> bool: return e.is_match(_key(KEY_V))),
			"and V, which moved there with it, is not a way of walking")


## The game asks its questions in text and a pad has no letters, so the face buttons stand in for
## them while it does, and the scene's own words come back when play starts.
func test_the_labels_swap_for_the_setup_questions_and_back() -> void:
	demo.controls.set_setting_up(true)
	assert_eq(demo.controls.joypad_button_3_label.text, "Yes")
	assert_eq(demo.controls.joypad_button_2_label.text, "", "Drop says nothing on a screen with nothing to drop from")
	assert_eq(demo.controls.joypad_button_11_label.text, "Kitten")
	assert_eq(demo.controls.joypad_button_14_label.text, "Alley Cat")

	demo.controls.set_setting_up(false)
	assert_eq(demo.controls.joypad_button_0_label.text, "Jump", "the scene's own words come back")
	assert_eq(demo.controls.joypad_axis_5_plus_label.text, "Sound")


## Ctrl-M brings the player back to the setup, and the one thing there worth putting to the player is the
## skill. The game then reprints its instructions and waits for any key, which is not a question and has no
## button on the HUD that says so; leaving the player to find it is the dead end that made the Menu button
## useless. The demo presses it, so picking a skill puts them straight back in the alley.
func test_picking_a_skill_from_the_menu_goes_straight_back_into_play() -> void:
	var menu: String = "Please select your skill level:
   (K)itten
   (H)ouse Cat
"
	var chosen: String = menu + "During play:
   Ctrl-M  returns you to this menu.
Press any key to start.
"

	assert_eq(demo._stage_for(menu), AlleyCatControls.Stage.ASKING_SKILL, "the skill menu is the player's")
	assert_eq(demo._stage_for(chosen), AlleyCatControls.Stage.READY_TO_START, "what follows it is not")
	assert_eq(demo._stage_for("Do you want to use a joystick (Y/N)?
"),
			AlleyCatControls.Stage.ASKING_JOYSTICK, "and neither is the question before it")

	# The demo holds the action key for exactly the screen that is only waiting to be told to go, and lets
	# go of it again, so the press does not carry into the game that follows.
	demo._press_on(true)
	assert_true(demo._pressing_on and Input.is_action_pressed(&"alleycat_alt"))
	demo._press_on(false)
	assert_false(demo._pressing_on or Input.is_action_pressed(&"alleycat_alt"))


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


## There is no second label for this and no "Alley Cat is not included" message: the game is committed in
## this repository and ships with the addon, so the only two ways it does not start are a platform the
## library has not been built for and a CAT.EXE that is not where the node was told to look. The reason goes
## on the same label the game's own text goes on, and nothing overwrites it afterwards.
func test_a_missing_game_is_explained_rather_than_blank() -> void:
	demo._on_load_failed("Copy your own CAT.EXE to somewhere")
	assert_true(demo.prompt.visible)
	assert_string_contains(demo.prompt.text, "CAT.EXE")
	assert_false(demo.controls.visible, "the HUD is no use with nothing to control")
	await wait_process_frames(10)
	assert_string_contains(demo.prompt.text, "CAT.EXE", "and the reason stays up rather than being painted over")
	demo._on_loaded()


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


## The artwork resource is the whole catalogue, not a hand-picked few: every sprite the game was seen to draw
## has a slot, carrying the game's own picture so it can be told apart from the others. An address is not a
## name, and nobody can draw a replacement for a sprite they cannot look at.
func test_every_sprite_has_a_slot_and_the_game_s_own_picture_in_it() -> void:
	if demo.game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	var artwork: AlleyCatArtwork = demo.art.artwork
	assert_not_null(artwork, "The demo ships a set of artwork")
	assert_gt(artwork.sprites.size(), 100, "which lists what the game draws and what it keeps in tables")
	# By address, not by entry: the game blits some artwork at more than one size, and each size is its own
	# entry while the replacement for it is the same picture.
	var overridden: Dictionary = {}
	var ever_drawn: int = 0
	for sprite: AlleyCatSprite in artwork.sprites:
		assert_not_null(sprite.original, "0x%05X should carry the game's own picture" % sprite.source)
		assert_false(sprite.label.is_empty(), "0x%05X should be named on its row" % sprite.source)
		if sprite.draws > 0:
			ever_drawn += 1
		if sprite.texture != null:
			overridden[sprite.source] = sprite.texture
	# Most of the catalogue was recorded from the game drawing it, and that count is what separates the
	# scenery from the rarities. Not all of it, though: artwork read out of a table is in the catalogue
	# whether the game ever drew it or not, which is the only way to get at the screens nobody has reached
	# and at the glyphs that never got printed.
	assert_gt(ever_drawn, 50, "Most of the catalogue is artwork the game was seen to draw")
	assert_lt(ever_drawn, artwork.sprites.size(), "and some of it was read out of the file instead")

	# One sprite is filled in, as a worked example. The rest are empty, so the game looks as it shipped
	# until someone puts a picture in a slot.
	# The example is several entries and not one: a replacement has to cover a whole animation, or it is
	# on screen only for the fraction of the time its one frame is up, which reads as a flicker rather
	# than as artwork. Which entries those are is a choice about the artwork and is not pinned here.
	assert_gt(overridden.size(), 1, "The example covers a whole animation rather than one frame of it")
	assert_lt(overridden.size(), artwork.sprites.size(), "and every other sprite is left as it shipped")
	for example: int in overridden:
		assert_eq(artwork.texture_for(example), overridden[example], "0x%05X is found by address" % example)
	assert_null(artwork.texture_for(0), "An address with no replacement gives nothing rather than erroring")


## Ctrl-S is the game's own sound switch, printed on its own menu and sent by the HUD's Sound button, and a
## replacement tune or meow playing through Godot is still the game making a noise as far as the player is
## concerned. So the replacement follows the switch: the tune pauses rather than stops, so turning the sound
## back on carries on from where it went quiet, and an effect asked for while the sound is off is not played.
##
## The switch is poked here rather than played for, because what the key does to that byte is the game's
## behaviour and was established separately: it is the only byte in sixteen kilobytes of the data segment
## that changes when Ctrl-S is pressed and changes back when it is pressed again.
func test_the_replacement_sound_follows_the_game_s_own_sound_switch() -> void:
	if demo.game == null or not demo.game.has_method(&"poke"):
		pass_test("AlleyCat is not built for this platform")
		return
	var r: AlleyCatRemaster = demo.remaster
	await wait_seconds(1.0)
	assert_true(r.is_sound_on(), "The game starts with its sound on")

	# Asked for after the machine has booted, not before: the data segment is nowhere until the program is
	# loaded, and an address taken early is an offset from zero, which is the interrupt table.
	var at: int = int(demo.game.call(&"get_data_address")) + AlleyCatRemaster.SOUND_AT
	assert_gt(at, 0, "and its data segment is somewhere real")
	# Stopped while the switch is poked, so the game cannot set it back between the poke and the read.
	demo.game.call(&"stop")
	await wait_process_frames(2)
	var loud: float = linear_to_db(maxf(r.sounds.music_volume, 0.0001))

	demo.game.call(&"poke", at, PackedByteArray([0]))
	await wait_process_frames(4)
	assert_false(r.is_sound_on(), "Turning the game's sound off")
	assert_lt(r._music_player.volume_db, -60.0, "takes the replacement tune down with it")
	r._effect_player.stream = null
	r._play_effect(r.sounds.caught)
	assert_null(r._effect_player.stream, "and nothing new is started over the quiet")

	demo.game.call(&"poke", at, PackedByteArray([0xFF]))
	await wait_process_frames(4)
	assert_true(r.is_sound_on(), "Turning it back on")
	assert_almost_eq(r._music_player.volume_db, loud, 0.01, "puts the tune back at the level it asked for")
	r._play_effect(r.sounds.caught)
	assert_eq(r._effect_player.stream, r.sounds.caught, "and effects are heard again")

	r._effect_player.stop()
	r._effect_player.stream = null
	demo.game.call(&"start")


## The override is what draws, and only where there is one. A set with one picture in it replaces one sprite.
func test_only_the_sprites_with_a_replacement_are_drawn_over() -> void:
	if demo.game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	var artwork: AlleyCatArtwork = demo.art.artwork
	var without: int = 0
	for sprite: AlleyCatSprite in artwork.sprites:
		if sprite.texture == null:
			without += 1
			assert_null(artwork.texture_for(sprite.source), "0x%05X is left as the game drew it" % sprite.source)
	assert_gt(without, artwork.sprites.size() * 3 / 4, "Most of them are the game's own")


## What is drawn is held until the game draws it somewhere else or repaints the screen, not timed out. The
## game only redraws what moved, so a cat standing still is absent from every report while plainly still on
## screen; dropping it then blinks the replacement off whenever the player stops, which is most of the time.
func test_a_replacement_is_held_while_the_game_leaves_the_sprite_alone() -> void:
	if demo.game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	var art: AlleyCatArt = demo.art
	await wait_seconds(2.0)
	# The machine is stopped so it draws nothing at all, which is the state this is about: a sprite the
	# game has stopped mentioning has not stopped being on the screen.
	demo.game.call(&"stop")
	await wait_process_frames(2)
	art._showing = [{"source": 0, "x": 10, "y": 10, "width": 8, "height": 8, "at": 0, "masked": false}]
	await wait_process_frames(240)
	assert_false(art._showing.is_empty(), "Still on screen, because the game never took it off")
	demo.game.call(&"start")


## The other half of that rule. A replacement is held while the game leaves the place alone, and dropped the
## moment the game paints over it - which is what happens when the cat turns round and walks off as a sprite
## there is no replacement for. Without this the old picture is left standing where the cat used to be.
func test_a_replacement_is_dropped_once_the_game_draws_over_it() -> void:
	var art: AlleyCatArt = demo.art
	var held: Dictionary = {"source": 0, "x": 100, "y": 100, "width": 24, "height": 11}
	assert_false(art._drawn_over(held, []), "nothing drawn there, so it is still true")
	assert_false(art._drawn_over(held, [{"source": 1, "x": 200, "y": 100, "width": 24, "height": 11}]),
			"and something drawn elsewhere leaves it alone")
	assert_true(art._drawn_over(held, [{"source": 1, "x": 110, "y": 104, "width": 24, "height": 11}]),
			"but the game painting that patch itself takes the place back")


## The paws menu's Art row. The replacements can be turned off while the game is running, which is what the
## row is for: a player who wants the 1984 picture back should not have to restart anything to see it.
func test_the_art_row_switches_the_replacements_while_the_game_runs() -> void:
	if demo.game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	var art: AlleyCatArt = demo.art
	var remaster: AlleyCatRemaster = demo.remaster
	assert_true(art.enabled, "the demo ships with the replacements on")
	assert_true(remaster.is_remastered_art(), "and the menu agrees with the node rather than guessing")
	assert_true(remaster._art_row.visible, "so the row is offered")
	assert_eq(remaster._art_name.text, "Remastered")

	remaster._on_next_art_pressed()
	assert_false(art.enabled, "the arrow turns the overlay off")
	assert_eq(remaster._art_name.text, "Original")
	# There are two answers, so either arrow lands on the other one.
	remaster._on_previous_art_pressed()
	assert_true(art.enabled)
	assert_eq(remaster._art_name.text, "Remastered")


## Turning it off has to give the game its own sprites back. They are hidden on their way to the
## framebuffer while a replacement is drawn over them, and leaving them hidden with nothing painted on top
## would put a cat-shaped hole in the alley rather than the cat the game shipped with.
func test_turning_the_art_off_stops_hiding_the_game_s_own_sprites() -> void:
	if demo.game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	var art: AlleyCatArt = demo.art
	art.enabled = true
	assert_false(art.replaced_sources().is_empty(), "the example cat is replaced, so it is hidden")
	art.enabled = false
	assert_true(art.replaced_sources().is_empty(), "and with the overlay off nothing is hidden at all")
	assert_true(art._showing.is_empty(), "nor is anything left painted over the top")
	art.enabled = true


## A host with no artwork node has nothing to switch, so the row is not there to be switched.
func test_the_art_row_is_hidden_where_there_is_no_artwork_to_switch() -> void:
	var scene: PackedScene = load("res://addons/godot_alleycat_gdextension/scenes/alley_cat_remaster.tscn")
	var remaster: AlleyCatRemaster = scene.instantiate()
	add_child_autofree(remaster)
	await wait_process_frames(1)
	assert_false(remaster.is_remastered_art(), "nothing to draw, so nothing is being drawn")
	assert_false(remaster._art_row.visible, "and the row is hidden rather than offered dead")
	remaster.set_remastered_art(true)
	assert_false(remaster.is_remastered_art(), "asking for it changes nothing and errors at nobody")


## Fullscreen is on the right shoulder and F, and grows the picture to fill the window without changing its
## shape: the game draws 320x200 and the screen is an aspect ratio container, so it fills the height and
## centres, or the width and centres, and never stretches.
func test_fullscreen_is_on_the_right_shoulder_and_keeps_the_picture_s_shape() -> void:
	assert_eq(String(demo.controls.action_button_10), "alleycat_fullscreen")
	assert_eq(demo.controls.joypad_button_10_label.text, "Fullscreen", "and says so")
	var seen: Dictionary = {"key": false, "pad": false}
	for event: InputEvent in InputMap.action_get_events(&"alleycat_fullscreen"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_F:
			seen["key"] = true
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_SHOULDER:
			seen["pad"] = true
	assert_true(seen["key"], "F on the keyboard")
	assert_true(seen["pad"], "the right shoulder on a pad")
	if demo.game == null:
		pass_test("AlleyCat is not built for this platform")
		return

	var before: Rect2 = demo.screen.get_rect()
	assert_false(demo.is_fullscreen(), "the demo opens inside the HUD's margins")
	demo.set_fullscreen(true)
	await wait_process_frames(2)
	assert_true(demo.is_fullscreen())
	assert_eq(demo.screen.get_rect(), demo.get_rect(), "the screen fills the whole window")
	var picture: Vector2 = demo.game.size
	assert_almost_eq(picture.x / picture.y, 4.0 / 3.0, 0.01, "and the game keeps its shape inside it")
	assert_gt(picture.y, before.size.y, "so it is bigger than it was")
	demo.set_fullscreen(false)
	await wait_process_frames(2)
	assert_eq(demo.screen.get_rect(), before, "and goes back exactly where it was")


## The game does not always draw a sprite from its first byte. It clips the cat at the screen edge by
## lifting a column out of the artwork, and has things rise out of their surroundings by drawing the lower
## rows only; either way the source lands inside a replaced sprite's bytes, and the offset says which part
## of the replacement to draw.
func test_a_draw_from_inside_a_sprite_draws_that_part_of_its_replacement() -> void:
	var artwork: AlleyCatArtwork = AlleyCatArtwork.new()
	var frame: AlleyCatSprite = AlleyCatSprite.new()
	frame.source = 0x10EE2
	frame.original = ImageTexture.create_from_image(Image.create(24, 11, false, Image.FORMAT_RGBA8))
	frame.texture = ImageTexture.create_from_image(Image.create(48, 22, false, Image.FORMAT_RGBA8))
	artwork.sprites.append(frame)
	assert_true(artwork.locate(0x10E00).is_empty(), "somewhere unreplaced is nobody's")
	assert_true(artwork.locate(0x10EE2 + 66).is_empty(), "and the byte after the last is the next sprite")
	var column: Dictionary = artwork.locate(0x10EE2 + 2)
	assert_eq(column.get("texture"), frame.texture, "one word into frame 3 is frame 3")
	assert_eq([int(column["column"]), int(column["row"])], [8, 0], "starting eight pixels in, on the first row")
	var lower: Dictionary = artwork.locate(0x10EE2 + 6 * 4)
	assert_eq([int(lower["column"]), int(lower["row"])], [0, 4], "four rows of six bytes in is the fifth row")
	assert_eq(artwork.length_of(0x10EE2), 66, "and the whole frame is sixty-six bytes")
	assert_eq(artwork.length_of(0x12345), 1, "an unknown one is only itself")

	var art: AlleyCatArt = demo.art
	var was: AlleyCatArtwork = art.artwork
	art.artwork = artwork
	assert_eq(art._replacement_for({"source": 0x10EE2 + 4, "stride": 24}), frame.texture,
			"so a clipped draw of frame 3 is one of ours")
	assert_null(art._replacement_for({"source": 0x10E00, "stride": 0}), "and something unreplaced is not")
	var region: Rect2 = art._region_of({"source": 0x10EE2 + 4, "stride": 24, "width": 8, "height": 11}, frame.texture)
	assert_eq(region, Rect2(32.0, 0.0, 16.0, 22.0), "the last eight of twenty-four pixels is the last third")
	region = art._region_of({"source": 0x10EE2 + 6 * 4, "stride": 0, "width": 24, "height": 7}, frame.texture)
	assert_eq(region, Rect2(0.0, 8.0, 48.0, 14.0), "the bottom seven of eleven rows is the bottom seven elevenths")
	assert_eq(art.replaced_lengths(), PackedInt32Array([66]), "and the game is told how much to hide")
	art.artwork = was


## The game draws some artwork a row taller each tick, and every one of those draws is the top so many
## rows of one picture. So a replacement is one picture too, and a draw shorter than the original is the
## top of the replacement, not the whole of it squashed.
func test_a_partly_drawn_sprite_draws_the_top_of_its_replacement() -> void:
	var artwork: AlleyCatArtwork = AlleyCatArtwork.new()
	var creature: AlleyCatSprite = AlleyCatSprite.new()
	creature.source = 0x11DF0
	creature.original = ImageTexture.create_from_image(Image.create(16, 13, false, Image.FORMAT_RGBA8))
	creature.texture = ImageTexture.create_from_image(Image.create(64, 52, false, Image.FORMAT_RGBA8))
	artwork.sprites.append(creature)
	assert_eq(int(artwork.locate(0x11DF0)["height"]), 13, "the original is thirteen rows")
	var art: AlleyCatArt = demo.art
	var was: AlleyCatArtwork = art.artwork
	art.artwork = artwork
	var whole: Rect2 = art._region_of({"source": 0x11DF0, "stride": 0, "width": 16, "height": 13}, creature.texture)
	assert_eq(whole, Rect2(0.0, 0.0, 64.0, 52.0), "all thirteen rows is all of the replacement")
	var top: Rect2 = art._region_of({"source": 0x11DF0, "stride": 0, "width": 16, "height": 4}, creature.texture)
	assert_eq(top, Rect2(0.0, 0.0, 64.0, 16.0), "four rows of thirteen is the top four thirteenths of it")
	art.artwork = was


## When the cat is quick the game draws a frame, wipes it, and draws the next one all in one tick, and the
## report holds all three. Only the frame nothing was drawn over afterwards is still on the screen; showing
## the wiped one as well paints two cats a step apart, which is what the title screen's walk looked like.
func test_a_frame_the_game_wiped_later_in_the_tick_is_not_shown() -> void:
	var artwork: AlleyCatArtwork = AlleyCatArtwork.new()
	for source: int in [0x10D56, 0x10DDA]:
		var frame: AlleyCatSprite = AlleyCatSprite.new()
		frame.source = source
		frame.texture = PlaceholderTexture2D.new()
		artwork.sprites.append(frame)
	var art: AlleyCatArt = demo.art
	var was: AlleyCatArtwork = art.artwork
	art.artwork = artwork
	var report: Array = [
		{"source": 0x10D56, "x": 16, "y": 96, "width": 24, "height": 11, "stride": 0},
		{"source": 0x106FA, "x": 16, "y": 96, "width": 24, "height": 11, "stride": 0},
		{"source": 0x10DDA, "x": 20, "y": 96, "width": 24, "height": 11, "stride": 0},
	]
	var standing: Array = art._still_standing(report)
	assert_eq(standing.size(), 1, "one cat, not two")
	assert_eq(int(standing[0]["source"]), 0x10DDA, "the one drawn last, after the wipe")
	# The same two frames drawn apart from each other both stand.
	report[1] = {"source": 0x106FA, "x": 200, "y": 96, "width": 24, "height": 11, "stride": 0}
	report[2] = {"source": 0x10DDA, "x": 120, "y": 96, "width": 24, "height": 11, "stride": 0}
	assert_eq(art._still_standing(report).size(), 2, "nothing drawn over either, so both are up")
	art.artwork = was


## The report says which routine drew each sprite and whether it was a clipped column, which is what the
## catalogue needs to know which colour is see-through and what the overlay needs to draw the right slice.
func test_the_report_says_how_each_sprite_was_drawn() -> void:
	if demo.game == null:
		pass_test("AlleyCat is not built for this platform")
		return
	demo.game.set(&"reports_sprites", true)
	var report: Array = []
	for i: int in 600:
		await wait_process_frames(1)
		report = demo.game.call(&"get_sprites")
		if not report.is_empty():
			break
	assert_false(report.is_empty(), "the title screen draws something within a few seconds")
	for sprite: Dictionary in report:
		assert_true(["plain", "masked", "keyed"].has(str(sprite.get("kind"))), "%X says how it was drawn" % int(sprite["source"]))
		assert_true(sprite.has("stride"), "and whether it was a column of something wider")

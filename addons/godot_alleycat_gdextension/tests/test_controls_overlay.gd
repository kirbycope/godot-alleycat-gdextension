extends GutTest
## Covers the controls card: the resource that holds it and the overlay that renders it. The card
## documents the mapping in alley_cat.cpp, so what is checked here is that every line actually
## reaches a player - a line with no text for a device is dropped silently, which is the behaviour
## that hides a control from whoever is holding that device.

const CARD: String = "res://addons/godot_alleycat_gdextension/resources/controls.tres"
const OVERLAY: String = "res://addons/godot_alleycat_gdextension/scenes/alley_cat_controls_overlay.tscn"
const DEVICES: Array[String] = ["keyboard", "xbox", "nintendo", "playstation", "touch"]

var card: AlleyCatControls


func before_each() -> void:
	card = load(CARD)


func test_the_card_loads_and_has_all_three_sets() -> void:
	assert_not_null(card)
	assert_gt(card.movement.size(), 0, "movement has lines")
	assert_gt(card.actions.size(), 0, "actions has lines")
	assert_gt(card.setup.size(), 0, "setup has lines")


func test_every_line_is_labelled() -> void:
	for line: AlleyCatControl in card.movement + card.actions + card.setup:
		assert_ne(line.label, "", "a line says what it does")


func test_every_line_has_a_keyboard_input() -> void:
	# The keyboard is the one device every machine has, so a line with no keyboard text is a
	# control nobody would ever be told about.
	for line: AlleyCatControl in card.movement + card.actions + card.setup:
		assert_ne(line.keyboard, "", "%s names a key" % line.label)


func test_touch_borrows_the_xbox_wording() -> void:
	for line: AlleyCatControl in card.movement + card.actions + card.setup:
		assert_eq(line.text_for("touch"), line.xbox, line.label)


func test_an_unknown_device_falls_back_to_the_keyboard() -> void:
	for line: AlleyCatControl in card.actions:
		assert_eq(line.text_for("steam deck"), line.keyboard, line.label)


func test_the_pad_can_do_everything_the_setup_asks() -> void:
	# Every setup question has to be answerable with a pad, because the game will not go on until
	# it is answered and a pad has no letters to type.
	for line: AlleyCatControl in card.setup:
		for device: String in DEVICES:
			assert_ne(line.text_for(device), "", "%s on %s" % [line.label, device])


func test_moving_the_cat_is_named_on_every_device() -> void:
	for line: AlleyCatControl in card.movement:
		for device: String in DEVICES:
			assert_ne(line.text_for(device), "", "%s on %s" % [line.label, device])


func test_restart_is_keyboard_only() -> void:
	# Nothing on the pad is mapped to Ctrl-R, on purpose: a restart is not something to hand to a
	# button that might be leaned on. The card must not claim otherwise.
	var restart: Array[AlleyCatControl] = card.actions.filter(
			func(line: AlleyCatControl) -> bool: return line.label == "Restart")
	assert_eq(restart.size(), 1)
	assert_eq(restart[0].text_for("xbox"), "")


func test_the_overlay_writes_both_columns_for_play() -> void:
	var overlay: AlleyCatControlsOverlay = (load(OVERLAY) as PackedScene).instantiate()
	add_child_autofree(overlay)
	overlay.setting_up = false
	overlay.input_type = "xbox"
	assert_string_contains(overlay.get_node("Left").text, "MOVEMENT")
	assert_string_contains(overlay.get_node("Right").text, "ACTIONS")
	assert_string_contains(overlay.get_node("Right").text, "Jump, act")


func test_the_overlay_replaces_both_columns_for_setup() -> void:
	var overlay: AlleyCatControlsOverlay = (load(OVERLAY) as PackedScene).instantiate()
	add_child_autofree(overlay)
	overlay.input_type = "xbox"
	overlay.setting_up = true
	assert_string_contains(overlay.get_node("Left").text, "SETUP")
	assert_eq(overlay.get_node("Right").text, "", "the right column steps aside")


func test_a_line_with_no_text_for_the_device_is_dropped() -> void:
	var overlay: AlleyCatControlsOverlay = (load(OVERLAY) as PackedScene).instantiate()
	add_child_autofree(overlay)
	overlay.setting_up = false
	overlay.input_type = "xbox"
	assert_false(overlay.get_node("Right").text.contains("Restart"),
			"the pad card leaves Restart out")
	overlay.input_type = "keyboard"
	assert_string_contains(overlay.get_node("Right").text, "Restart")

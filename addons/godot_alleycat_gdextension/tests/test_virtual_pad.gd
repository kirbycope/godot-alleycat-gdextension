extends GutTest
## Covers the on-screen pad's mapping tables. Every entry here is something the demo relies on and
## that nothing else would catch: a slot the addon does not have is silently ignored, a label with
## no matching slot never appears, and an action left off a slot leaves that button dead.

const PAD_SCRIPT: String = "res://addons/godot_alleycat_gdextension/scripts/alley_cat_virtual_pad.gd"

var pad: AlleyCatVirtualPad


func before_each() -> void:
	pad = AlleyCatVirtualPad.new()


func after_each() -> void:
	pad.free()


func test_every_slot_names_an_action() -> void:
	for slot: String in AlleyCatVirtualPad.SLOTS:
		var binding: Dictionary = AlleyCatVirtualPad.SLOTS[slot]
		assert_true(binding.has("action"), "%s has an action" % slot)
		assert_ne(String(binding["action"]), "", "%s's action is not blank" % slot)


func test_every_slot_is_a_button_or_an_axis() -> void:
	for slot: String in AlleyCatVirtualPad.SLOTS:
		var binding: Dictionary = AlleyCatVirtualPad.SLOTS[slot]
		assert_true(binding.has("button") or binding.has("axis"),
				"%s sends either a button or an axis" % slot)
		if binding.has("axis"):
			assert_true(binding.has("value"), "%s's axis says which way it pushes" % slot)


func test_actions_are_unique() -> void:
	var seen: Array[StringName] = []
	for slot: String in AlleyCatVirtualPad.SLOTS:
		var action: StringName = AlleyCatVirtualPad.SLOTS[slot]["action"]
		assert_false(seen.has(action), "%s's action is its own" % slot)
		seen.append(action)


func test_the_left_stick_is_filled_in_both_directions() -> void:
	# The addon hides a stick whose pair is blank, so a half-filled stick is an invisible one.
	for axis: int in AlleyCatVirtualPad.AXES:
		var pushes: Array[float] = []
		for slot: String in AlleyCatVirtualPad.SLOTS:
			var binding: Dictionary = AlleyCatVirtualPad.SLOTS[slot]
			if binding.get("axis", -1) == axis:
				pushes.append(binding["value"])
		assert_true(pushes.has(-1.0) and pushes.has(1.0), "axis %d pushes both ways" % axis)


func test_both_label_sets_cover_the_same_slots() -> void:
	# set_labels clears every label it is not given, so a slot named in one set and not the other
	# would lose its word the moment the game changed screen.
	assert_eq(AlleyCatVirtualPad.LABELS.keys(), AlleyCatVirtualPad.SETUP_LABELS.keys())


func test_every_label_has_a_property_to_write_it_to() -> void:
	for slot: String in AlleyCatVirtualPad.LABELS:
		assert_true(AlleyCatVirtualPad.LABEL_PROPERTIES.has(slot),
				"%s has a label property on the HUD" % slot)


func test_setup_labels_answer_the_games_questions() -> void:
	# The game asks in text and a pad has no letters, so the bottom two buttons have to stand in
	# for Y and N, and all four for the skill menu. This is the promise the node's C++ keeps.
	assert_string_contains(AlleyCatVirtualPad.SETUP_LABELS["button_0"], "Yes")
	assert_string_contains(AlleyCatVirtualPad.SETUP_LABELS["button_1"], "No")
	assert_string_contains(AlleyCatVirtualPad.SETUP_LABELS["button_0"], "Kitten")
	assert_string_contains(AlleyCatVirtualPad.SETUP_LABELS["button_3"], "Alley Cat")


func test_axis_value_is_zero_with_nothing_pressed() -> void:
	# The addon's HUD registers these actions in its own _ready; it is not in the tree here, so
	# they are registered by hand for the length of the test.
	for slot: String in AlleyCatVirtualPad.SLOTS:
		var action: StringName = AlleyCatVirtualPad.SLOTS[slot]["action"]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	for axis: int in AlleyCatVirtualPad.AXES:
		assert_eq(pad.axis_value(axis), 0.0)
	for slot: String in AlleyCatVirtualPad.SLOTS:
		var action: StringName = AlleyCatVirtualPad.SLOTS[slot]["action"]
		if InputMap.has_action(action):
			InputMap.erase_action(action)


func test_current_input_type_is_keyboard_without_the_addon() -> void:
	# A project that installs this extension without godot-controls still has to run.
	assert_eq(pad.current_input_type(), AlleyCatVirtualPad.KEYBOARD_MOUSE)

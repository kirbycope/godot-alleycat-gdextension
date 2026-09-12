extends Control

## Demo for the AlleyCat node: the game on screen with the controls HUD around it, or an explanation
## of what is missing.
##
## The HUD is the [Controls] addon, instanced in this scene as [code]Controls[/code]. Which action
## sits on which button, and what each one is called, are set in
## [code]scenes/alley_cat_controls.tscn[/code] and edited there rather than here.
##
## The game node is the one thing built in code. A scene that names a GDExtension type cannot be
## opened at all where the library is not built, which would turn "this platform has no build yet"
## into a broken scene; instantiating it by name degrades instead.

## How much of the framebuffer has to be painted before the game counts as playing rather than asking
## a question. It blanks the screen to ask and paints it to play.
const PAINTED: int = 512

## The looks F6 cycles through, in order, with what to call each on screen. The first is the game as
## it loads: CGA palette 1 at high intensity, which is what Alley Cat picks and never changes.
const LOOKS: Array[String] = [
	"CGA", "Amber CRT", "Green CRT", "Trinitron CRT",
	"Comic", "Cel", "Game Boy", "Paper",
	"VHS", "Pen and Ink", "Dither", "Negative",
	"Deep Fried", "Double Vision", "Nausea", "Holofoil",
	"Film", "Frost", "Squiggle", "Blueprint",
	"Championship",
]

const SCREEN_SHADER: Shader = preload("res://addons/godot_alleycat_gdextension/shaders/screen.gdshader")

@onready var screen: AspectRatioContainer = $Screen
@onready var missing: Label = $Missing
@onready var prompt: Label = $Prompt
@onready var look_name: Label = $LookName
@onready var remaster: AlleyCatRemaster = $Remaster
@onready var controls: AlleyCatControls = $Controls

var game: TextureRect ## The AlleyCat node, null where the library is not built for this platform.


var _stage: AlleyCatControls.Stage = AlleyCatControls.Stage.PLAYING ## Which screen the game is on.
var _look_shown_until: float = 0.0 ## When to take the name of the look back off the screen.
var _answering: bool = false ## Whether the demo is holding the answer to the joystick question down.
var _pressing_on: bool = false ## Whether the demo is holding the action key to get past a wait.
var _has_played: bool = false ## Whether the game has reached play once. Its menu means something else after that.
var _can_rewind: bool = false ## Whether the library on this platform has been built with rewind in it.


func _ready() -> void:
	if not ClassDB.class_exists(&"AlleyCat"):
		_on_load_failed("The AlleyCat library is not built for this platform.")
		return
	game = ClassDB.instantiate(&"AlleyCat") as TextureRect
	game.name = "Game"
	# Keyboard only. The node feeds the game scancodes and the game port alike, so a pad, the keyboard
	# and the on-screen stick all reach it either way; saying there is no adapter just spares the player
	# a question about hardware that Godot has already answered for them.
	game.set(&"joystick", false)
	# The binaries are committed per platform and are not all rebuilt at the same moment, so the demo
	# asks the library what it can do rather than assuming. A build without rewind simply has no
	# rewind, instead of erroring once a frame.
	_can_rewind = game.has_method(&"get_rewind_available")
	game.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	game.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	game.connect(&"loaded", _on_loaded)
	game.connect(&"load_failed", _on_load_failed)
	# The looks are one shader with a mode rather than one shader each, because they all start from
	# the same four colours and differ only in what they do with the index.
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SCREEN_SHADER
	game.material = material
	screen.add_child(game)

	# The menu is told what it is a menu for here rather than in the scene, because the game node is
	# built in code: a scene naming a GDExtension type cannot be opened where the library is missing.
	remaster.game = game.get_path()
	remaster.screen = game.get_path()
	remaster.looks = PackedStringArray(LOOKS)
	remaster.look_changed.connect(_on_look_changed)
	remaster.set_look(0)
	look_name.hide()

	# F6 is the host's key, not one of the game's, so it is registered here rather than sitting on a
	# slot of the HUD: nothing in Alley Cat answers to it.
	controls.register_actions({
		"alleycat_look": {"keys": [KEY_F6]},
		# Alt is off the HUD but not gone: a keyboard still has it, and the demo presses it where the
		# game is only waiting to be told to carry on.
		"alleycat_alt": {"keys": [KEY_ALT], "buttons": [JOY_BUTTON_LEFT_SHOULDER]},
		# Rewind is the host's, not the game's - Alley Cat has no idea it is happening - so it is
		# registered here beside F6 rather than sitting on a slot of the HUD.
		"alleycat_rewind": {"keys": [KEY_BACKSPACE], "axes": [[JOY_AXIS_TRIGGER_LEFT, 1.0]]},
	})
	# The node loads on its own _ready, which has now been and gone, so ask rather than wait for a
	# signal that has already fired.
	if game.call(&"is_loaded"):
		_on_loaded()
	else:
		_on_load_failed("Copy your own CAT.EXE to %s" % game.get(&"exe_path"))


func _on_loaded() -> void:
	missing.hide()
	controls.show()


func _on_load_failed(reason: String) -> void:
	missing.text = "Alley Cat could not start.\n\n%s" % reason
	missing.show()
	controls.hide()
	prompt.hide()


## F6 swaps the look. It says which one it landed on, because eight of them cycle past quickly and a
## palette on its own does not name itself.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"alleycat_look"):
		return
	if remaster.is_open():
		return
	remaster.set_look(remaster.get_look() + 1)
	get_viewport().set_input_as_handled()


## Names whichever look is on, wherever the change came from. The menu owns the index: keeping a
## second copy here is what left the two disagreeing about what was on the screen.
func _on_look_changed(index: int) -> void:
	look_name.text = LOOKS[index] if index < LOOKS.size() else "-"
	look_name.show()
	_look_shown_until = Time.get_ticks_msec() / 1000.0 + 2.0


func _process(_delta: float) -> void:
	if look_name.visible and Time.get_ticks_msec() / 1000.0 > _look_shown_until:
		look_name.hide()

	if game == null:
		return
	# The game asks its setup questions through BIOS teletype rather than drawing them, so they
	# arrive as text and not as pixels. Without this the player sees a black screen and no reason
	# for it: the joystick question and the skill menu are both invisible.
	# The text buffer keeps everything printed since the last mode set, so it is still full once
	# play starts; what says which screen is up is whether the game has painted one.
	if remaster.is_open():
		return

	# Rewind first: while it is happening the game is not running, so none of what follows applies.
	var rewinding: bool = _can_rewind and Input.is_action_pressed(&"alleycat_rewind")
	if _can_rewind and rewinding != game.get(&"rewinding"):
		game.set(&"rewinding", rewinding)
	if rewinding:
		look_name.text = "Rewind  %.1fs" % game.call(&"get_rewind_available")
		look_name.show()
		_look_shown_until = Time.get_ticks_msec() / 1000.0 + 0.5
		return

	var asking: bool = game.call(&"get_screen_painted") < PAINTED
	var text: String = game.call(&"get_text")
	if not asking:
		_has_played = true

	# Two of the game's screens are not questions, the first time through: the title, and the page of
	# instructions that ends in "press any key to start". Both only want the action key, so the demo
	# presses it and the player never sees either.
	#
	# Only the first time, though. Ctrl-M reprints that same page to bring the player back to the
	# menu, and skipping it then is how the game ends up sitting at a menu nobody can see: the whole
	# point of going there is to read it and pick a skill again.
	var at_a_wait: bool = not asking or _start_prompt_at(text) > text.rfind("skill level")
	_press_on(at_a_wait and not _has_played and _stage == AlleyCatControls.Stage.PLAYING)
	var waiting_to_go_on: bool = at_a_wait and not _has_played

	var showing: bool = asking and not waiting_to_go_on
	prompt.text = _live_question(text) if showing else ""
	prompt.visible = showing

	# The same buttons mean different things on each of the game's screens, and most of them mean
	# nothing at all on two of the three, so the HUD is told which screen is up rather than just
	# whether one is.
	var stage: AlleyCatControls.Stage = _stage_for(text) if asking else AlleyCatControls.Stage.PLAYING
	if stage != _stage:
		_stage = stage
		controls.set_stage(stage)

	_answer_the_joystick_question(stage == AlleyCatControls.Stage.ASKING_JOYSTICK)



## Where in [param text] the game last asked to be told to carry on, or -1. It words that differently
## depending on how the joystick question went - "press the joystick button to start" when it thinks
## there is an adapter, "Press any key to start" when it does not - so both count, and missing the second
## is how the instructions page ends up in front of a player who should never have seen it.
func _start_prompt_at(text: String) -> int:
	return maxi(text.rfind("press the joystick button"), text.rfind("Press any key to start"))


## Just the question being asked. The buffer keeps everything printed since the last mode set, so the
## joystick question is still sitting above the skill menu long after it was answered - and answered by
## the demo at that, which makes showing it doubly beside the point.
func _live_question(text: String) -> String:
	var start: int = text.rfind("Please select")
	return text if start < 0 else text.substr(start)


## Which screen [param text] is showing. The game prints through BIOS teletype and the buffer keeps
## everything printed since the last mode set, so both questions are still in it once the second is up;
## the skill menu is always the later of the two, which is what makes it the answer when both are there.
func _stage_for(text: String) -> AlleyCatControls.Stage:
	# The skill menu is what the d-pad answers, so a page carrying it is the skill menu whatever else
	# was printed after. Ctrl-M puts the whole page up at once - the skill list and the instructions
	# together - and the player is there to pick a skill, not to read the last line of it.
	if text.contains("skill level") and not _has_played_past(text):
		return AlleyCatControls.Stage.ASKING_SKILL
	if text.rfind("(Y/N)") >= 0 and not text.contains("skill level"):
		return AlleyCatControls.Stage.ASKING_JOYSTICK
	return AlleyCatControls.Stage.PLAYING


## Whether the skill menu in [param text] is one the game has already been taken past, which is the
## case on the way into a first game and not when Ctrl-M has brought the player back to it.
func _has_played_past(text: String) -> bool:
	return not _has_played and _start_prompt_at(text) > text.rfind("skill level")


## Answers the joystick question for the player, holding the answer down for as long as the question is up.
## The game asks it even with the adapter turned off, and with the adapter off there is only one answer it
## will take, so putting it to the player is asking them to guess at hardware Godot has already dealt with:
## a pad, the keyboard and the on-screen stick all reach the game as keystrokes either way.
##
## Held rather than tapped for a set number of frames, because the game reads its inputs once per tick of
## its own clock and that is slower than a frame, so any count would be a guess.
func _answer_the_joystick_question(asking: bool) -> void:
	var action: StringName = controls.action_button_2
	if action.is_empty() or not InputMap.has_action(action):
		return
	if asking and not _answering:
		Input.action_press(action)
		_answering = true
	elif not asking and _answering:
		Input.action_release(action)
		_answering = false


## Holds the action key while the game is only waiting to be told to carry on. Alley Cat pauses on its
## title and again after its instructions, and both want the same key; a player who has already chosen
## to run the thing has nothing to decide at either, so the demo decides for them.
func _press_on(waiting: bool) -> void:
	if not InputMap.has_action(&"alleycat_alt"):
		return
	if waiting and not _pressing_on:
		Input.action_press(&"alleycat_alt")
		_pressing_on = true
	elif not waiting and _pressing_on:
		Input.action_release(&"alleycat_alt")
		_pressing_on = false

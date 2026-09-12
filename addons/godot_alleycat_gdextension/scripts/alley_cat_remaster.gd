@tool
class_name AlleyCatRemaster
extends CanvasLayer
## The remaster layer: a paws menu, and somewhere to drop sound that plays over the game's own.
##
## Alley Cat's own pause is [code]Esc[/code], which it calls paws mode. This takes that key before
## the game sees it and puts its own menu up instead, because a host that owns the key does not have
## to guess at the game's state: it stops running the machine, which is a true pause rather than the
## game's idea of one, and the same trick rewinding already uses.
##
## Everything it changes belongs to the host - which shader is on the screen, how loud each of the
## game's two voices is, how much rewind to keep - so none of it disturbs the machine, and a
## snapshot taken before the menu is still good after it.

signal closed ## The menu has been dismissed and the game is running again.
signal look_changed(index: int) ## A different look is on the screen, whoever asked for it.

@onready var _panel: Control = $Dim
@onready var _look_name: Label = %LookName
@onready var _music_slider: HSlider = %MusicSlider
@onready var _effects_slider: HSlider = %EffectsSlider
@onready var _rewind_slider: HSlider = %RewindSlider
@onready var _rewind_value: Label = %RewindValue
@onready var _difficulty_name: Label = %DifficultyName

## The [AlleyCat] node this is the menu for. Resolved when it is set rather than only in
## [method Node._ready], because a child is ready before whatever owns it: a host that builds the
## game node in code cannot have handed the path over yet by the time this node is ready.
@export var game: NodePath:
	set(value):
		game = value
		_resolve()

## The [TextureRect] the look shader is on. Defaults to [member game].
@export var screen: NodePath:
	set(value):
		screen = value
		_resolve()

## Sound to play over the game's own. Leave it empty and the game sounds exactly as it shipped.
@export var sounds: AlleyCatSounds:
	set(value):
		sounds = value
		if is_node_ready():
			_apply_sounds()

## The looks the menu offers, in order. The host sets these; the menu only presents them.
@export var looks: PackedStringArray = []

## The action that opens and closes the menu. Alley Cat's own pause key, taken before it gets there.
@export var pause_action: StringName = &"alleycat_esc"

## The skill levels the game offers, and the action that picks each. There is no memory address for
## this - or none found yet - so the only way to change it is the way a player would: Ctrl-M, which the
## game itself says "returns you to this menu", then the letter, then a key to start. That is also why
## changing it starts a new game: going back to the menu is what the game does, not what this adds.
const DIFFICULTIES: Array[String] = ["Kitten", "House Cat", "Tomcat", "Alley Cat"]
const DIFFICULTY_ACTIONS: Array[StringName] = [
	&"alleycat_kitten", &"alleycat_house_cat", &"alleycat_tomcat", &"alleycat_alley_cat",
]

## How long to hold each key of that sequence, and how long to let the game chew on it. The game reads
## its inputs once per tick of its own clock, which is slower than a frame, so a press has to outlast
## one of them.
const KEY_FRAMES: int = 10
const SETTLE_FRAMES: int = 90

var _difficulty: int = 3 ## Which of [constant DIFFICULTIES] is selected. The demo starts on Alley Cat.
var _changing_difficulty: bool = false

## How coarsely the screen is watched for movement. Every fourth pixel each way is 80x50 samples a
## frame, which is enough to find where the action is and cheap enough not to be felt.
const WATCH_STEP: int = 4

## How much of the screen has to change at once to count as the game announcing something rather than
## the cat walking. Losing a life redraws far more than any amount of running about does.
const UPHEAVAL: float = 0.22

var _open: bool = false
var _previous_frame: PackedByteArray = PackedByteArray()
var _focus_a: Vector2 = Vector2(0.5, 0.5)
var _focus_b: Vector2 = Vector2(0.5, 0.5)
var _focus_amount: float = 0.0
var _stage_hue: float = 0.0
var _wipe: float = 0.0
var _was_effects: bool = false

var _look: int = 0
var _game: Node = null
var _screen: CanvasItem = null
var _music_player: AudioStreamPlayer = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_resolve()
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "RemasterMusic"
	add_child(_music_player)
	_music_player.finished.connect(_on_music_finished)

	_music_slider.value = get_music_volume()
	_effects_slider.value = get_effects_volume()
	if is_instance_valid(_game) and _game.has_method(&"get_rewind_seconds"):
		_rewind_slider.value = _game.get(&"rewind_seconds")
	_refresh()
	_apply_sounds()
	_panel.hide()


## The pause key is taken here rather than left to the game. Polled rather than listened for, for the
## same reason the library polls: the HUD's own pause button is a TouchScreenButton, and those press
## their action straight into the input state without ever sending an event, so a handler would be
## deaf to the one control most likely to be used on a touchscreen. Polling catches the key, the pad
## and the on-screen button through one path.
##
## Opening stops the machine on the same frame, and a stopped machine reads no input, so the game
## never gets to act on the key either.
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if pause_action.is_empty() or not InputMap.has_action(pause_action):
		return
	if Input.is_action_just_pressed(pause_action):
		set_open(not _open)
	if not _open:
		_watch_the_game()


## Puts what the menu says back in step with what is actually set.
func _refresh() -> void:
	_look_name.text = looks[_look] if _look < looks.size() else "-"
	_difficulty_name.text = DIFFICULTIES[_difficulty]
	_rewind_value.text = "%.0f s" % _rewind_slider.value


## Finds the game and the screen from the paths given, as far as they can be found right now.
func _resolve() -> void:
	if not is_inside_tree():
		return
	_game = get_node_or_null(game)
	_screen = get_node_or_null(screen) as CanvasItem
	if _screen == null:
		_screen = _game as CanvasItem


## Whether the menu is up. While it is, the game is not running.
func is_open() -> bool:
	return _open


## Opens or closes the menu. Closing puts the game back exactly where it was: nothing here touched
## the machine, so there is nothing to put right.
func set_open(value: bool) -> void:
	if _open == value:
		return
	_open = value
	if is_instance_valid(_game):
		# Not running the machine is the pause. The game has no idea it happened, which is the point:
		# its own paws mode would have opinions about what the player may do next.
		if _open:
			_game.call(&"stop")
		else:
			_game.call(&"start")
	_panel.visible = _open
	if not _open:
		closed.emit()


## Which look is showing, as an index into [member looks].
func get_look() -> int:
	return _look


## Puts look [param index] on the screen, wrapping at either end.
func set_look(index: int) -> void:
	if looks.is_empty():
		return
	_look = posmod(index, looks.size())
	if is_instance_valid(_screen) and _screen.material is ShaderMaterial:
		(_screen.material as ShaderMaterial).set_shader_parameter("mode", _look)
	if is_node_ready():
		_refresh()
	look_changed.emit(_look)


## The game's own music, 0 to 1. Silencing it leaves the effects untouched.
func set_music_volume(value: float) -> void:
	if is_instance_valid(_game) and _game.has_method(&"set_music_volume"):
		_game.set(&"music_volume", value)


func get_music_volume() -> float:
	if is_instance_valid(_game) and _game.has_method(&"get_music_volume"):
		return _game.get(&"music_volume")
	return 1.0


## The game's own effects, 0 to 1.
func set_effects_volume(value: float) -> void:
	if is_instance_valid(_game) and _game.has_method(&"set_effects_volume"):
		_game.set(&"effects_volume", value)


func get_effects_volume() -> float:
	if is_instance_valid(_game) and _game.has_method(&"get_effects_volume"):
		return _game.get(&"effects_volume")
	return 1.0


## Puts the replacement sound in place. Giving a music stream silences the game's own music voice,
## because two tunes at once is nobody's idea of a remaster; taking it away gives the tune back.
func _apply_sounds() -> void:
	if not is_instance_valid(_music_player):
		return
	var stream: AudioStream = sounds.music if sounds != null else null
	_music_player.stream = stream
	if stream != null:
		_music_player.volume_db = linear_to_db(maxf(sounds.music_volume, 0.0001))
		_music_player.play()
		set_music_volume(0.0)
	else:
		_music_player.stop()
		set_music_volume(1.0)


func _on_music_finished() -> void:
	if sounds != null and sounds.music_loops and _music_player.stream != null:
		_music_player.play()


func _on_previous_look_pressed() -> void:
	set_look(_look - 1)
	_refresh()


func _on_next_look_pressed() -> void:
	set_look(_look + 1)
	_refresh()


func _on_music_slider_value_changed(value: float) -> void:
	set_music_volume(value)


func _on_effects_slider_value_changed(value: float) -> void:
	set_effects_volume(value)


## Rewind is bought with memory - a megabyte a snapshot, 18.2 of them a second - so the menu says how
## many seconds it is keeping rather than leaving it a bare number.
func _on_rewind_slider_value_changed(value: float) -> void:
	if is_instance_valid(_game) and _game.has_method(&"set_rewind_seconds"):
		_game.set(&"rewind_seconds", value)
	_refresh()


func _on_resume_pressed() -> void:
	set_open(false)


## Which skill level the menu is showing.
func get_difficulty() -> int:
	return _difficulty


## Takes the game back to its own menu, picks [param index] there, and starts it again. The game has
## no way to change skill in play, so this is a new game: the menu says so rather than pretending
## otherwise.
func set_difficulty(index: int) -> void:
	if _changing_difficulty or DIFFICULTY_ACTIONS.is_empty():
		return
	_difficulty = posmod(index, DIFFICULTIES.size())
	_refresh()
	_run_difficulty_change()


func _run_difficulty_change() -> void:
	if not is_instance_valid(_game):
		return
	_changing_difficulty = true
	# The sequence needs the machine running, so the menu gets out of the way for it.
	var was_open: bool = _open
	set_open(false)
	await _hold(&"alleycat_menu")
	await _hold(DIFFICULTY_ACTIONS[_difficulty])
	await _hold(&"alleycat_alt")
	_changing_difficulty = false
	if was_open:
		set_open(true)


## Holds one action long enough for the game to read it, then lets the game get on with what it did.
func _hold(action: StringName) -> void:
	if not InputMap.has_action(action):
		return
	Input.action_press(action)
	for i: int in KEY_FRAMES:
		await get_tree().process_frame
	Input.action_release(action)
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame


func _on_previous_difficulty_pressed() -> void:
	set_difficulty(_difficulty - 1)


func _on_next_difficulty_pressed() -> void:
	set_difficulty(_difficulty + 1)


## Watches the screen so the Championship look can answer to the game rather than to a clock. None of
## this is something a shader can do for itself: it is handed one frame with no memory of the last, so
## movement, upheaval and "something just happened" all have to be worked out here.
func _watch_the_game() -> void:
	if not is_instance_valid(_screen) or not (_screen.material is ShaderMaterial):
		return
	var material: ShaderMaterial = _screen.material as ShaderMaterial

	if _wipe > 0.0:
		_wipe = minf(_wipe + get_process_delta_time() * 1.6, 1.0)
		if _wipe >= 1.0:
			_wipe = 0.0

	# An effect firing is the game saying something happened, and it is the only such signal that
	# needs no new instrumentation: the library already reports which voice is sounding.
	if is_instance_valid(_game) and _game.has_method(&"get_voice"):
		var effects_now: bool = int(_game.call(&"get_voice")) == 2
		if effects_now and not _was_effects:
			_stage_hue = fposmod(_stage_hue + 0.13, 1.0)
		_was_effects = effects_now

	_follow_the_movement()

	material.set_shader_parameter("stage_hue", _stage_hue)
	material.set_shader_parameter("focus_a", _focus_a)
	material.set_shader_parameter("focus_b", _focus_b)
	material.set_shader_parameter("focus_amount", _focus_amount)
	material.set_shader_parameter("wipe", _wipe)


## Finds where the picture is changing and leans the focus points towards it. Two points rather than
## one because the cat is rarely the only thing worth looking at, and eased rather than snapped
## because a light that jumps reads as a fault.
func _follow_the_movement() -> void:
	if not is_instance_valid(_game) or not _game.has_method(&"get_frame"):
		return
	var image: Image = _game.call(&"get_frame") as Image
	if image == null:
		return
	var width: int = image.get_width()
	var height: int = image.get_height()
	var pixels: PackedByteArray = image.get_data()
	if pixels.is_empty():
		return
	if _previous_frame.size() != pixels.size():
		_previous_frame = pixels
		return

	# Two sums, split down the middle, so two points come out of one pass rather than two.
	var left: Vector2 = Vector2.ZERO
	var right: Vector2 = Vector2.ZERO
	var left_count: int = 0
	var right_count: int = 0
	var looked_at: int = 0
	for y: int in range(0, height, WATCH_STEP):
		for x: int in range(0, width, WATCH_STEP):
			var at: int = (y * width + x) * 4
			looked_at += 1
			if pixels[at] == _previous_frame[at] and pixels[at + 1] == _previous_frame[at + 1]:
				continue
			if x * 2 < width:
				left += Vector2(float(x) / float(width), float(y) / float(height))
				left_count += 1
			else:
				right += Vector2(float(x) / float(width), float(y) / float(height))
				right_count += 1
	_previous_frame = pixels

	var changed: int = left_count + right_count
	var upheaval: float = float(changed) / maxf(float(looked_at), 1.0)
	# Everything moving at once is not movement to follow, it is the game redrawing: a life lost, a
	# level starting. That is the wipe, and following it would only drag the light to the middle.
	if upheaval > UPHEAVAL:
		if _wipe <= 0.0:
			_wipe = 0.001
			_stage_hue = fposmod(_stage_hue + 0.37, 1.0)
		_focus_amount = lerpf(_focus_amount, 0.0, 0.25)
		return

	var ease: float = 0.18
	if left_count > 0:
		_focus_a = _focus_a.lerp(left / float(left_count), ease)
	if right_count > 0:
		_focus_b = _focus_b.lerp(right / float(right_count), ease)
	_focus_amount = lerpf(_focus_amount, 1.0 if changed > 0 else 0.0, ease)

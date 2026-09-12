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

## How much of the picture has to change between two frames before it stops being movement worth following
## and becomes the screen being rewritten. The light is let go of rather than dragged into the middle; what
## the upheaval actually means is [constant REDRAW_BYTES]' question, not this one's.
const UPHEAVAL: float = 0.22

## How many bytes of screen the game has to draw in one frame for the picture to be a different picture
## rather than the same one with the cat moved along it. Measured against the running game: the cat, the
## mice and the dog together cost about 120 bytes in a busy frame, and every screen change measured cost
## the whole 16K CGA window at once.
const REDRAW_BYTES: int = 4000

## ...and the whole window, which is what going through a window, losing a life and starting a level all
## cost. Below this the game has redrawn a part of the screen; at it, the screen is simply somewhere else.
const FULL_REDRAW_BYTES: int = 12000

## How far the stage colour moves for one sound the game makes, and how close together two of those are
## allowed to be. Small and spaced, because Alley Cat is never quiet: measured in play it starts about three
## and a half sounds a second, and a jump per sound turns the screen into a strobe. This is the ambient half
## of the effect - the colour drifting with how busy the alley is - while what a player reads as "something
## happened to me" is losing a life, and that redraws the screen and takes the jump below.
const EFFECT_HUE_STEP: float = 0.04
const EFFECT_HUE_GAP: float = 0.2

## How far it moves when the game draws a different picture: a room entered or left, a life lost, a level
## begun. Far enough to be unmistakably a new place rather than the drift.
const REDRAW_HUE_STEP: float = 0.29

## Where the game keeps its high score, as an offset from the address its data is counted from, and how many
## digits it is. Found by reading the disassembly in alley-decomp rather than by scanning memory: sub_09922
## hands sub_09969 a pointer to 0x1f89 and a screen position, and sub_09969 draws seven digits with a gap
## after the third, which is the "000-0000" on the fence. One decimal digit a byte, most significant first.
const HIGH_SCORE_AT: int = 0x1f89
const SCORE_AT: int = 0x1f82
const SCORE_DIGITS: int = 7

## Where the game keeps the lives it has left, from the same reading: sub_098E3 compares 0x1f80 against
## 0x1f81, and when they differ it draws the new digit and remembers it. 0x1f81 is only a note of what is
## already on the fence, which is why setting 0x1f80 is enough to make the game repaint it.
const LIVES_AT: int = 0x1f80

## How long the lives count has to read the same before it is believed. Polled every frame it does not: the
## true count and zero come back alternately while a game is on, and the game's own code writes only 3, 9 and
## a decrement, so the zero is something this has not explained rather than something the game means. Waiting
## for the reading to settle steps over it. In seconds rather than frames, because the demo runs at about 480
## of them a second and a frame count would mean something different on every machine.
const LIVES_STEADY_TIME: float = 0.2

## Where the high score is kept between runs. The game has no idea any of this is happening: it is read out
## of its memory while it plays and put back the next time it starts.
const HIGH_SCORE_FILE: String = "user://alley_cat_high_score.txt"

var _open: bool = false
var _previous_frame: PackedByteArray = PackedByteArray()
var _focus_a: Vector2 = Vector2(0.5, 0.5)
var _focus_b: Vector2 = Vector2(0.5, 0.5)
var _focus_amount: float = 0.0
var _stage_hue: float = 0.0
var _wipe: float = 0.0
var _effect_starts: int = -1 ## The game's count of sounds begun, to notice it going up. -1 until first read.
var _video_writes: int = -1 ## Bytes the game has drawn, to notice how much it drew this frame. -1 until first read.
var _since_effect: float = 0.0 ## Seconds since the colour last moved for a sound, so a burst of them is one move.

var _look: int = 0
var _game: Node = null
var _screen: CanvasItem = null
var _music_player: AudioStreamPlayer = null
var _effect_player: AudioStreamPlayer = null
var _lives: int = -1 ## The last count believed. -1 until one has settled.
var _lives_candidate: int = -1 ## The count being read now, which is not believed until it holds.
var _lives_steady: float = 0.0 ## How long it has held.
var _saved_high: PackedByteArray = PackedByteArray() ## The best score seen, as the game's own digits.
var _restored: bool = false ## Whether the saved high score has been put into the machine yet.


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_resolve()
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "RemasterMusic"
	add_child(_music_player)
	_music_player.finished.connect(_on_music_finished)
	# Kept apart from the music so one can be replaced without cutting the other off mid-note.
	_effect_player = AudioStreamPlayer.new()
	_effect_player.name = "RemasterEffects"
	add_child(_effect_player)

	_music_slider.value = get_music_volume()
	_effects_slider.value = get_effects_volume()
	if is_instance_valid(_game) and _game.has_method(&"get_rewind_seconds"):
		_rewind_slider.value = _game.get(&"rewind_seconds")
	_refresh()
	_apply_sounds()
	_panel.hide()
	_saved_high = _read_saved_high_score()


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
		_keep_the_high_score()


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

	# A sound starting is the game saying something happened - the cat caught, something eaten, a jump
	# landed - and it needs no new instrumentation beyond a count of them. It has to be a count and not
	# the voice that is sounding: the voice is a level, and a level that is already EFFECTS says nothing
	# when the next effect begins.
	if is_instance_valid(_game) and _game.has_method(&"get_effect_starts"):
		var starts: int = int(_game.call(&"get_effect_starts"))
		_since_effect += get_process_delta_time()
		if _effect_starts >= 0 and starts != _effect_starts and _since_effect >= EFFECT_HUE_GAP:
			_stage_hue = fposmod(_stage_hue + EFFECT_HUE_STEP, 1.0)
			_since_effect = 0.0
		_effect_starts = starts

	# How much of the screen the game just drew is the one reliable way to know it is showing somewhere
	# else. Pixels cannot answer it: Alley Cat's screens share a background colour, so two different places
	# agree on most of their pixels, and a room arrives over several frames rather than in one.
	if is_instance_valid(_game) and _game.has_method(&"get_video_writes"):
		var writes: int = int(_game.call(&"get_video_writes"))
		if _video_writes >= 0:
			var drawn: int = writes - _video_writes
			if drawn > REDRAW_BYTES:
				_stage_hue = fposmod(_stage_hue + REDRAW_HUE_STEP, 1.0)
				_focus_amount = 0.0
		_video_writes = writes

	# Losing a life is the game's own count going down, which it will say if asked. This used to be guessed
	# at from how much of the screen was redrawn, and the guess could not tell a death from a new level,
	# because both replace the picture. The wipe belongs to the death.
	_watch_the_lives()

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

	# Two sums, split down the middle, so two points come out of one pass rather than two, and a count of
	# ink per block in the same pass, which is what says whether this is a different place altogether.
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
	# Everything moving at once is not movement to follow, so the light is let go of rather than dragged
	# into the middle. What that upheaval means - a new room, a lost life - is not a question for pixels;
	# the game says how much it drew, and _watch_the_game reads that.
	if float(changed) / maxf(float(looked_at), 1.0) > UPHEAVAL:
		_focus_amount = lerpf(_focus_amount, 0.0, 0.25)
		return

	var ease: float = 0.18
	if left_count > 0:
		_focus_a = _focus_a.lerp(left / float(left_count), ease)
	if right_count > 0:
		_focus_b = _focus_b.lerp(right / float(right_count), ease)
	_focus_amount = lerpf(_focus_amount, 1.0 if changed > 0 else 0.0, ease)




## Carries the high score across runs, which the game cannot do for itself: it was written for a machine
## that was switched off at the wall, and it keeps its best score in memory like everything else.
##
## The saved score is put in once, as soon as the machine is up. After that this only ever reads: whenever
## the game's own high score is better than what is on disk, the file is rewritten. Nothing here writes to
## the game except that one restore, so a game in progress is never reached into.
func _keep_the_high_score() -> void:
	if not is_instance_valid(_game) or not _game.has_method(&"peek"):
		return
	if not bool(_game.call(&"is_ready")):
		return
	var at: int = int(_game.call(&"get_data_address")) + HIGH_SCORE_AT
	if not _restored:
		_restored = true
		if _saved_high.size() == SCORE_DIGITS:
			_game.call(&"poke", at, _saved_high)
			return
	var live: PackedByteArray = _game.call(&"peek", at, SCORE_DIGITS)
	if live.size() != SCORE_DIGITS or not _is_digits(live):
		return
	if _compare_scores(live, _saved_high) > 0:
		_saved_high = live
		_write_saved_high_score(live)


## The game's high score as a number, for a host that wants to show it somewhere of its own.
func get_high_score() -> int:
	if not is_instance_valid(_game) or not _game.has_method(&"peek"):
		return 0
	var at: int = int(_game.call(&"get_data_address")) + HIGH_SCORE_AT
	return _digits_to_number(_game.call(&"peek", at, SCORE_DIGITS))


## The score of the game being played, the same way.
func get_score() -> int:
	if not is_instance_valid(_game) or not _game.has_method(&"peek"):
		return 0
	var at: int = int(_game.call(&"get_data_address")) + SCORE_AT
	return _digits_to_number(_game.call(&"peek", at, SCORE_DIGITS))


## Whether every byte is a decimal digit. Memory read at the wrong moment - before the game has set itself
## up, say - is not, and a run of rubbish must never be saved over a real score.
func _is_digits(digits: PackedByteArray) -> bool:
	if digits.is_empty():
		return false
	for digit: int in digits:
		if digit > 9:
			return false
	return true


func _digits_to_number(digits: PackedByteArray) -> int:
	if not _is_digits(digits):
		return 0
	var total: int = 0
	for digit: int in digits:
		total = total * 10 + digit
	return total


## Which of two scores is the better, most significant digit first, without turning either into a number.
func _compare_scores(a: PackedByteArray, b: PackedByteArray) -> int:
	if b.size() != a.size():
		return 1
	for i: int in a.size():
		if a[i] != b[i]:
			return 1 if a[i] > b[i] else -1
	return 0


func _read_saved_high_score() -> PackedByteArray:
	if not FileAccess.file_exists(HIGH_SCORE_FILE):
		return PackedByteArray()
	var file: FileAccess = FileAccess.open(HIGH_SCORE_FILE, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var text: String = file.get_line().strip_edges()
	file.close()
	# Stored as the digits themselves so the file can be read, and edited, by a person.
	if text.length() != SCORE_DIGITS or not text.is_valid_int():
		return PackedByteArray()
	var digits: PackedByteArray = PackedByteArray()
	for i: int in text.length():
		digits.append(text.unicode_at(i) - 48)
	return digits if _is_digits(digits) else PackedByteArray()


func _write_saved_high_score(digits: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(HIGH_SCORE_FILE, FileAccess.WRITE)
	if file == null:
		return
	var text: String = ""
	for digit: int in digits:
		text += str(digit)
	file.store_line(text)
	file.close()


## Sweeps the wipe down the screen when a life is lost. The game keeps the count itself, so this is the one
## thing here that is not inferred: entering a room and losing a life both replace the picture, and only the
## count tells them apart.
func _watch_the_lives() -> void:
	var now: int = get_lives()
	if now < 0:
		return
	if now != _lives_candidate:
		_lives_candidate = now
		_lives_steady = 0.0
		return
	_lives_steady += get_process_delta_time()
	if _lives_steady < LIVES_STEADY_TIME:
		return
	if _lives >= 0 and now < _lives:
		if _wipe <= 0.0:
			_wipe = 0.001
			_stage_hue = fposmod(_stage_hue + REDRAW_HUE_STEP, 1.0)
		# The cat being caught is the one event the game names plainly enough to put a sound on: its own
		# count of lives went down. No guessing at which beep meant what.
		_play_effect(sounds.caught if sounds != null else null)
	_lives = now


## How many lives the cat has left, or -1 where the library cannot say. Read out of the game rather than
## counted here, so it is right across a rewind as well: rewinding puts the machine back, count and all.
func get_lives() -> int:
	if not is_instance_valid(_game) or not _game.has_method(&"peek_u8"):
		return -1
	if not bool(_game.call(&"is_ready")):
		return -1
	var value: int = int(_game.call(&"peek_u8", int(_game.call(&"get_data_address")) + LIVES_AT))
	# Between screens the game leaves rubbish here; a cat never has more than nine lives, whatever the saying.
	return value if value >= 0 and value <= 9 else -1


## Plays one of the replacement sounds, if there is one for what just happened. The game's own sound is left
## alone: it is a 1984 PC speaker and silencing it to layer over it is the host's choice, not this one's.
func _play_effect(stream: AudioStream) -> void:
	if stream == null or not is_instance_valid(_effect_player):
		return
	_effect_player.stream = stream
	_effect_player.volume_db = linear_to_db(maxf(get_effects_volume(), 0.0001))
	_effect_player.play()

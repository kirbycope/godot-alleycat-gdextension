@tool
class_name AlleyCatArt
extends Control
## Draws its own artwork over the game's, sprite for sprite.
##
## The game says what it drew and where - see [method AlleyCat.get_sprites] - so this listens to that rather
## than trying to recognise anything in the picture. Each frame it asks what was drawn, and for anything it
## has a replacement for, paints over the top in the same place and at the same size.
##
## What that buys is resolution. The game's own sprite is eight pixels by five and is scaled up to whatever
## the window is, so it arrives as blocks; the replacement is drawn at the screen's resolution instead. It
## does not change where anything is or how big it is, so the game plays exactly as it did.
##
## Anything with no replacement is left alone, so a set of artwork can be finished one sprite at a time.

## The [AlleyCat] node to draw over.
@export var game: NodePath:
	set(value):
		game = value
		_resolve()

## The replacements. Without one this node does nothing at all.
@export var artwork: AlleyCatArtwork

## The picture the game draws, which everything is positioned in.
const GAME_SIZE: Vector2 = Vector2(320.0, 200.0)

var _game: Node = null

## How much of the screen the game has to draw at once for what is up to be thrown away: the whole 16K CGA
## window, near enough. Anything less is the same picture with things moving on it, and what was drawn on it
## is still there. A lower bar than this throws the replacement away whenever several sprites move at once,
## which is often, and the replacement blinks.
const REDRAW_BYTES: int = 12000

## The replacements that are up. Held until the game draws one of them somewhere else, or repaints the
## screen - which is how long they are really there for.
##
## They cannot be dropped just because the game stopped mentioning them. It only redraws what moved, so a cat
## standing still is absent from every report while being plainly on screen; timing them out blinks the
## replacement off whenever the player stops, which is most of the time.
var _showing: Array = []
var _video_writes: int = -1


func _ready() -> void:
	# Drawn over the game rather than under it. The game node is added to the scene at runtime, so it would
	# otherwise be the later sibling and paint over this.
	z_index = 1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Engine.is_editor_hint():
		return
	_resolve()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or artwork == null:
		return
	if not is_instance_valid(_game) or not _game.has_method(&"get_sprites"):
		return
	# A screen the game has just repainted has none of what was on the old one still on it.
	if _game.has_method(&"get_video_writes"):
		var writes: int = int(_game.call(&"get_video_writes"))
		if _video_writes >= 0 and writes - _video_writes > REDRAW_BYTES and not _showing.is_empty():
			_showing = []
			queue_redraw()
		_video_writes = writes

	var mine: Array = []
	for sprite: Dictionary in _game.call(&"get_sprites"):
		if artwork.texture_for(int(sprite["source"])) != null:
			mine.append(sprite)
	# A report with one of ours in it replaces what is up, wholesale. The game draws one frame of an
	# animation at a time, so keeping the old one alongside would paint two cats a step apart.
	if not mine.is_empty():
		_showing = mine
		queue_redraw()


func _draw() -> void:
	if artwork == null or not is_instance_valid(_game) or not _game.has_method(&"get_sprites"):
		return
	var picture: Rect2 = picture_rect()
	if picture.size.x <= 0.0:
		return
	var scale: Vector2 = picture.size / GAME_SIZE
	for sprite: Dictionary in _showing:
		var texture: Texture2D = artwork.texture_for(int(sprite["source"]))
		if texture == null:
			continue
		var at: Vector2 = picture.position + Vector2(float(sprite["x"]), float(sprite["y"])) * scale
		var wide: Vector2 = Vector2(float(sprite["width"]), float(sprite["height"])) * scale
		draw_texture_rect(texture, Rect2(at, wide), false)


## Finds the game, and asks it to report what it draws. Asked for here rather than in [method _ready],
## because a child is ready before whatever owns it: the demo builds the game node in code and hands over the
## path afterwards, so at _ready there is nothing yet to ask.
func _resolve() -> void:
	if not is_inside_tree() or Engine.is_editor_hint():
		return
	_game = get_node_or_null(game)
	if is_instance_valid(_game) and _game.has_method(&"get_sprites"):
		# Reporting costs nothing until someone asks for it, so it is asked for rather than left on.
		_game.set(&"reports_sprites", true)


## Where the game's picture actually is inside this rect. The game is drawn centred and letterboxed, keeping
## its 320x200 shape whatever the window does, so the sprites have to be placed against the picture rather
## than against the whole box - otherwise everything lands stretched and too low.
func picture_rect() -> Rect2:
	if size.x <= 0.0 or size.y <= 0.0:
		return Rect2()
	var wanted: float = GAME_SIZE.x / GAME_SIZE.y
	var drawn: Vector2 = size
	if size.x / size.y > wanted:
		drawn = Vector2(size.y * wanted, size.y)
	else:
		drawn = Vector2(size.x, size.x / wanted)
	return Rect2((size - drawn) * 0.5, drawn)

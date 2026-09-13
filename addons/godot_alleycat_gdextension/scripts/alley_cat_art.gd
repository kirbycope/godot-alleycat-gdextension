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
@export var artwork: AlleyCatArtwork:
	set(value):
		artwork = value
		_tell_the_game_what_is_replaced()

## Whether the replacements are drawn. Turn it off and the game is exactly as it shipped: its own sprites
## stop being hidden and nothing is painted over them. This is what the paws menu's Art row switches, and
## it can be switched at any moment, mid-jump included.
##
## A switch of its own rather than clearing [member artwork], because the set has to still be there to come
## back to, and because reloading a catalogue of a hundred textures to turn the overlay on is absurd.
##
## Nothing in the machine changes either way. The game has been drawing its own sprites all along - hiding
## one only throws away the bytes on their way to the framebuffer - so there is no state to put back and no
## moment when switching is unsafe.
@export var enabled: bool = true:
	set(value):
		if enabled == value:
			return
		enabled = value
		# Whatever is up belongs to the old answer, and the game has been redrawing underneath it the whole
		# time, so dropping it uncovers a picture that is already right.
		_showing = []
		_tell_the_game_what_is_replaced()
		queue_redraw()

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

## The report grows as a game tick runs and starts again from nothing on the next one, and a tick is spread
## over dozens of host frames. So a half-built report is half the picture: at the start of a tick the only
## thing in it is the game rubbing out where the sprite was, and reading that on its own says the sprite has
## gone when it is about to be drawn again a few hundred instructions later. Deciding to *show* something
## can be done the moment it is reported, but deciding to take something away waits for the whole tick.
var _tick: Array = [] ## The report as it stood when the last tick ended.
var _reported: int = 0 ## How much of this tick's report has arrived, to notice the next one starting.
var _drawn_this_tick: bool = false ## Whether any of ours has been reported since the last tick ended.


func _ready() -> void:
	# Drawn over the game rather than under it. The game node is added to the scene at runtime, so it would
	# otherwise be the later sibling and paint over this.
	z_index = 1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Engine.is_editor_hint():
		return
	_resolve()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or artwork == null or not enabled:
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

	var report: Array = _game.call(&"get_sprites")
	if report.size() < _reported:
		_end_of_tick()
	_reported = report.size()
	_tick = report

	var mine: Array = []
	for sprite: Dictionary in report:
		if _replacement_for(sprite) != null:
			mine.append(sprite)
	# A report with one of ours in it replaces what is up, wholesale. The game draws one frame of an
	# animation at a time, so keeping the old one alongside would paint two cats a step apart.
	if not mine.is_empty():
		_showing = mine
		_drawn_this_tick = true
		queue_redraw()


## A whole game tick has gone by. If none of ours was drawn in it, anything the game drew over one of them
## has taken that place back: the cat has stopped and the game is drawing the standing pose there, or it has
## turned into something there is no replacement for. Held replacements are still kept while the game draws
## nothing at all where they are, which is what a sprite nobody has disturbed looks like from the report.
func _end_of_tick() -> void:
	if _drawn_this_tick:
		_drawn_this_tick = false
		return
	var kept: Array = []
	for held: Dictionary in _showing:
		if not _drawn_over(held, _tick):
			kept.append(held)
	if kept.size() != _showing.size():
		_showing = kept
		queue_redraw()


## Whether the game drew anything over [param held] in [param report], in the game's own 320x200 pixels.
## The report says what was blitted and where, so an overlap is the game painting that patch of screen
## itself - which is exactly when a replacement hung over it has stopped being true.
func _drawn_over(held: Dictionary, report: Array) -> bool:
	var box: Rect2 = _rect_of(held)
	for sprite: Dictionary in report:
		if box.intersects(_rect_of(sprite)):
			return true
	return false


## One entry of a sprite report as a rectangle in the game's own pixels.
func _rect_of(sprite: Dictionary) -> Rect2:
	return Rect2(float(sprite["x"]), float(sprite["y"]), float(sprite["width"]), float(sprite["height"]))


func _draw() -> void:
	if artwork == null or not enabled or not is_instance_valid(_game) or not _game.has_method(&"get_sprites"):
		return
	var picture: Rect2 = picture_rect()
	if picture.size.x <= 0.0:
		return
	var scale: Vector2 = picture.size / GAME_SIZE
	for sprite: Dictionary in _showing:
		var texture: Texture2D = _replacement_for(sprite)
		if texture == null:
			continue
		var at: Vector2 = picture.position + Vector2(float(sprite["x"]), float(sprite["y"])) * scale
		var wide: Vector2 = Vector2(float(sprite["width"]), float(sprite["height"])) * scale
		draw_texture_rect_region(texture, Rect2(at, wide), _region_of(sprite, texture))


## The part of [param texture] that stands for the part of the original the game drew, in the texture's
## own pixels. The whole of it, usually. A column of it where the game clipped the sprite at the screen
## edge, which the report says with a stride; the top of it where the game drew the original only so many
## rows tall, which is how the thing in the bin comes up. The replacement's width stands for the sprite's
## full width and its height for the full height, whatever resolution it was drawn at.
func _region_of(sprite: Dictionary, texture: Texture2D) -> Rect2:
	var region: Rect2 = Rect2(0.0, 0.0, float(texture.get_width()), float(texture.get_height()))
	var stride: int = int(sprite.get("stride", 0))
	if stride > 0:
		var slice: Dictionary = artwork.slice_for(int(sprite["source"]), stride)
		var across: float = texture.get_width() / float(slice["width"])
		region.position.x = float(slice["column"]) * across
		region.size.x = float(sprite["width"]) * across
	var full: int = artwork.height_for(int(sprite["source"]))
	if full > int(sprite["height"]):
		region.size.y = texture.get_height() * float(sprite["height"]) / float(full)
	return region


## The replacement for what one entry of the report says was drawn: the sprite's own, or, where the game
## drew a column lifted out of a wider sprite, that sprite's. Null where there is none.
func _replacement_for(sprite: Dictionary) -> Texture2D:
	var stride: int = int(sprite.get("stride", 0))
	if stride == 0:
		return artwork.texture_for(int(sprite["source"]))
	var slice: Dictionary = artwork.slice_for(int(sprite["source"]), stride)
	return slice.get("texture", null)


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
		_tell_the_game_what_is_replaced()


## Names the artwork the game should stop drawing, because this node is putting its own picture in the same
## place. Without it the game's own sprite is still on the screen underneath, showing through every gap in
## the replacement - and a replacement is a shape on transparency, so there are a lot of gaps. Painting over
## it here instead would mean guessing at what is behind the sprite, which is the alley rather than any one
## colour.
##
## By address, not by entry: the game blits some artwork at more than one size and each size is its own
## entry, while a replacement for it is the same picture and the same address.
func _tell_the_game_what_is_replaced() -> void:
	if not is_instance_valid(_game) or not _game.has_method(&"set_hidden_sprites"):
		return
	_game.call(&"set_hidden_sprites", replaced_sources())


## The addresses the game should stop drawing: every sprite with a replacement, once each. Empty while
## [member enabled] is off, which is the whole of turning the overlay off as far as the machine is
## concerned - the game goes back to drawing its own.
func replaced_sources() -> PackedInt32Array:
	var sources: PackedInt32Array = PackedInt32Array()
	if artwork == null or not enabled:
		return sources
	for sprite: AlleyCatSprite in artwork.sprites:
		if sprite.texture != null and not sources.has(sprite.source):
			sources.append(sprite.source)
	return sources


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

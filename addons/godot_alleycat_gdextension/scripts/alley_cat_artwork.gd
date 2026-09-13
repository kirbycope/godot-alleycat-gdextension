@tool
class_name AlleyCatArtwork
extends Resource
## Replacement artwork for the game's sprites, as a resource rather than as code, so a set of it is a file:
## several can sit side by side in a project and be swapped whole.
##
## Drop one on an [AlleyCatArt] node. Anything the game draws that is not named here is left exactly as it
## was, so a half-finished set is perfectly usable - one sprite can be replaced and the rest left alone.

@export var sprites: Array[AlleyCatSprite] = []

var _by_source: Dictionary = {}


## The replacement for the artwork at [param source], or null where there is none.
func texture_for(source: int) -> Texture2D:
	if _by_source.size() != sprites.size():
		_rebuild()
	return _by_source.get(source, null)


## How many rows the game's own artwork at [param source] has, or 0 where it is not catalogued. The game
## draws some artwork a row taller each tick - the thing coming up out of a bin - and each of those draws
## is the top so many rows of the same picture, so a draw shorter than this is the top of the replacement,
## not the whole of it squashed.
func height_for(source: int) -> int:
	for sprite: AlleyCatSprite in sprites:
		if sprite != null and sprite.source == source and sprite.original != null:
			return sprite.original.get_height()
	return 0


## The replacement for a column the game lifted out of a wider sprite, which is how it clips the cat and the
## dog at the edge of the screen. [method AlleyCat.get_sprites] reports such a draw with the address the
## column starts at and the sprite's full width in pixels as [code]stride[/code]; the column starts somewhere
## in that sprite's first row, so the sprite is whichever replaced one lies within a row's bytes before it.
##
## Returns the texture, the column's offset into it in the game's own pixels, and the sprite's full width,
## or an empty dictionary where nothing replaced contains the column.
func slice_for(source: int, stride: int) -> Dictionary:
	if stride <= 0:
		return {}
	for sprite: AlleyCatSprite in sprites:
		if sprite == null or sprite.texture == null:
			continue
		if source >= sprite.source and source < sprite.source + stride / 4:
			return {"texture": sprite.texture, "column": (source - sprite.source) * 4, "width": stride}
	return {}


func _rebuild() -> void:
	_by_source.clear()
	for sprite: AlleyCatSprite in sprites:
		if sprite != null and sprite.texture != null:
			_by_source[sprite.source] = sprite.texture

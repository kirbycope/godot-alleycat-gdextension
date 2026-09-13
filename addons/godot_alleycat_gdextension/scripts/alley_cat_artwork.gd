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


## Where [param source] falls inside a replaced sprite, or an empty dictionary where it falls in none.
##
## The game does not always draw a sprite from its first byte. It clips the cat at the screen edge by lifting
## a column out of the artwork, which starts a word or two into the first row; and it has things rise out of
## and sink into their surroundings by drawing the lower rows only, which starts a row or more down. Either
## way the source is inside the sprite's bytes, and the offset says which row and column: a row is width/4
## bytes. [member AlleyCatSprite.original] is what says how big the sprite is.
##
## Returns the texture, the column and row the draw starts at in the game's own pixels, and the sprite's
## full width and height, all in the game's pixels; the texture's own size stands for the full sprite.
func locate(source: int) -> Dictionary:
	for sprite: AlleyCatSprite in sprites:
		if sprite == null or sprite.texture == null:
			continue
		if sprite.original == null:
			if sprite.source == source:
				return {"texture": sprite.texture, "column": 0, "row": 0, "width": 0, "height": 0}
			continue
		var per_row: int = sprite.original.get_width() / 4
		var span: int = per_row * sprite.original.get_height()
		if source >= sprite.source and source < sprite.source + span:
			var offset: int = source - sprite.source
			return {"texture": sprite.texture, "column": (offset % per_row) * 4, "row": offset / per_row,
					"width": sprite.original.get_width(), "height": sprite.original.get_height()}
	return {}


## How many bytes of artwork the sprite at [param source] owns - width/4 times height - or 1 where its
## size is not known. What [method AlleyCat.set_hidden_sprites] needs alongside the address.
func length_of(source: int) -> int:
	for sprite: AlleyCatSprite in sprites:
		if sprite != null and sprite.source == source and sprite.original != null:
			return sprite.original.get_width() / 4 * sprite.original.get_height()
	return 1


func _rebuild() -> void:
	_by_source.clear()
	for sprite: AlleyCatSprite in sprites:
		if sprite != null and sprite.texture != null:
			_by_source[sprite.source] = sprite.texture

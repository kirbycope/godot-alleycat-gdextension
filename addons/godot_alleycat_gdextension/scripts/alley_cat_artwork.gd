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


func _rebuild() -> void:
	_by_source.clear()
	for sprite: AlleyCatSprite in sprites:
		if sprite != null and sprite.texture != null:
			_by_source[sprite.source] = sprite.texture

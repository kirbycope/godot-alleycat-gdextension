@tool
class_name AlleyCatSprite
extends Resource
## One piece of the game's artwork, and the picture to put in its place.
##
## The game draws every sprite by copying artwork from a fixed address, so that address is the sprite's name:
## the mice are all one piece of artwork drawn in four places, and replacing it replaces all of them at once.
## [method AlleyCat.get_sprites] reports the address of everything drawn, which is how one is found.

## The address the game copies this sprite's artwork from, as [method AlleyCat.get_sprites] reports it. It is
## a physical address rather than an offset, and it does not move between runs.
@export var source: int = 0

## The picture to draw instead. It is drawn in the same place and at the same size as the game's own, so it
## should have the same shape; what it gains is being drawn at the screen's resolution rather than at the
## 320x200 the game had.
@export var texture: Texture2D

## What this is, for whoever reads the resource later. The game has no names for its own artwork.
@export var note: String = ""

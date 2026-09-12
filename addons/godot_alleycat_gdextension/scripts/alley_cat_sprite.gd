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

## The game's own artwork for this sprite, exported out of CAT.EXE by [code]tools/export_sprites.py[/code].
## Nothing draws it - the game draws its own - but it is what says which sprite this entry is, since the
## game has no names for its artwork and an address on its own tells you nothing. Look at it in the
## inspector, draw something the same shape, and drop that into [member texture].
@export var original: Texture2D

## How many times this was drawn while the catalogue was recorded, and how often through the masking
## blitter. A sprite drawn thousands of times is scenery or the cat; one drawn twice is a rarity. Where
## [member masked_draws] is most of [member draws], the artwork is a mask - a solid shape ANDed into the
## background to punch a hole - rather than a picture, and replacing it paints over that hole.
@export var draws: int = 0
@export var masked_draws: int = 0

## What this is, for whoever reads the resource later. The game has no names for its own artwork.
@export var note: String = ""

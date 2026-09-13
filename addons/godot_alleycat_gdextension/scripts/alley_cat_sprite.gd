@tool
class_name AlleyCatSprite
extends Resource
## One piece of the game's artwork, and the picture to put in its place.
##
## The game draws every sprite by copying artwork from a fixed address, so that address is the sprite's name:
## the mice are all one piece of artwork drawn in four places, and replacing it replaces all of them at once.
## [method AlleyCat.get_sprites] reports the address of everything drawn, which is how one is found.

## What this sprite is, once somebody has worked it out - "Cat walk left 1 of 6" and so on. It is also what
## the inspector calls this entry in the list, so naming one is how a catalogue of a hundred addresses turns into
## something that can be read down rather than clicked through. Until it is named it says the address, the
## size and how often the game drew it, which is enough to find it on the contact sheets.
##
## Writing it through [member Resource.resource_name] is what puts it on the row: an array of resources is
## labelled by that, and nothing else in a resource shows without opening it.
@export var label: String = "":
	set(value):
		label = value
		resource_name = value

## What this sprite belongs to - "Cat", "Dog", "Mouse", "Broom". Most of the game's artwork comes in
## families: a thing that walks is six frames each way, and a thing that is drawn at three sizes is three
## entries, so the useful unit when replacing artwork is the family rather than the sprite. The browser
## filters the sheet by this, which is how twelve cat frames are found among a hundred sprites.
@export var group: String = ""

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

## The facts about this sprite, written by [code]tools/build_artwork_resource.py[/code] rather than by hand:
## its size and how often the game was seen to draw it. [member label] is the one to write in.
@export var note: String = ""

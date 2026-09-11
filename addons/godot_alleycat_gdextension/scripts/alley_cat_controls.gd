class_name AlleyCatControls
extends Resource
## The controls card for the Alley Cat screen: a movement column and an actions column of
## [AlleyCatControl] lines, plus the separate set for the setup questions the game asks before play.
## The default card is resources/controls.tres; it documents the mapping in alley_cat.cpp and does not
## change it.

@export var movement: Array[AlleyCatControl] = [] ## Shown on the left of the monitor while playing.
@export var actions: Array[AlleyCatControl] = [] ## Shown on the right of the monitor while playing.
## Shown on the left while the game is still asking its questions. The game prints those as text and a
## pad has no letters, so its buttons stand in for them and the card has to say which.
@export var setup: Array[AlleyCatControl] = []

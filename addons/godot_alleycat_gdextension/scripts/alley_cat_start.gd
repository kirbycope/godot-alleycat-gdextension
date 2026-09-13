@tool
class_name AlleyCatStart
extends Resource
## How the game should be when the player arrives: what it says on the fence, how many lives, which skill,
## whether the sound is on, and what the high score to beat is.
##
## A set rather than a row of fields on the node, the same as [AlleyCatSounds] and [AlleyCatArtwork], so a
## project can keep more than one and swap between them - an arcade cabinet's settings and a living room's,
## or a birthday one - and so the demo can ship an example without that example being the only way.
##
## Everything here is done to the machine's own memory once the program is loaded, so it is all there in a
## plain play session with no overlay and all of it is in a screenshot. Nothing is faked on top.
##
## Each setting has a "leave it alone" value and that is the default, so a fresh resource changes nothing.

## Which skill to begin on, or to leave the player to pick. The game has no memory location for this - it is
## asked on its own menu - so it is chosen by taking the game there and answering, the same as a player.
enum Skill {
	AS_THE_GAME_ASKS, ## Leave it: the player picks on the game's own menu.
	KITTEN,
	HOUSE_CAT,
	TOMCAT,
	ALLEY_CAT,
}

## Whether to start quiet. The game's own Ctrl-S switch is what is set, so the HUD's Sound button and the
## replacement sound both agree with it from the first frame.
enum Sound {
	AS_THE_GAME_LEAVES_IT, ## Alley Cat starts with its sound on.
	ON,
	OFF,
}

## Alley Cat has one fence and paints it twice: the routine at 0x09C30 draws the attract screen it opens on
## and the routine at 0x09C60 draws the alley you play in, and both read their graffiti from the same list.
##
## It does not have to stay one list. Each of those routines loads the address as its own immediate, so they
## are given a list each and can say different things - which is what these two groups are. Leave them the
## same and the fence behaves exactly as it always has.
##
## The words on the title screen itself - IBM PRESENTS, the Alley Cat logo, By Bill Williams, the copyright
## line - are not text at all. They are drawn artwork, changed by replacing sprites in the Alley Cat Artwork
## panel rather than by typing here; they are the ones grouped "Title" in the catalogue.
##
## Everything in both groups obeys the same rules:
## [br]- [b]A to Z[/b] and [b]0 to 9[/b], case ignored; an [b]apostrophe[/b], a [b]hyphen[/b] and [b]spaces[/b].
## [br]- Nothing else. There are no glyphs for a full stop, comma, question mark or exclamation mark.
## [br]- Only twelve letters are the game's own - A C E H I K L M S T U V. The rest are drawn by the addon and
##   written into the machine, so they are as real as the originals once it is running.
## [br]- A message is up to [b]34 letters[/b]; spaces are free and do not count. That is the screen's limit,
##   not the machine's: 320 pixels across at eight apart.
## [br]- A tag keeps the path the game's own letters take - HI' climbs, LOVE and THEM run downhill, MOUSIES
##   arcs - so a shorter word uses the first few places and a longer one carries on the same way. Empty one
##   and that tag comes off the fence.
## [br]- Anything refused is not written, and says why in the output.
@export_group("Fence: the title screen", "title_")

## An extra line, on top of the tags. Empty and only the tags are drawn.
@export_multiline var title_message: String = ""

## Where the message's first letter goes, in the game's own pixels - 320 across, 200 down, 0,0 top left. The
## fence is about y=110 to y=165, the two scores are painted across the top of it, and the bins are drawn in
## front of everything below about y=140.
@export var title_message_at: Vector2i = Vector2i(24, 112)

## How far apart the message's letters are. The glyphs are eight wide, so eight has them touching.
@export_range(6, 16) var title_message_spacing: int = 8

## The game's own tags, as they are, so they can be changed rather than only added to.
@export var title_hi: String = "HI'"
@export var title_cat: String = "CAT"
@export var title_love: String = "LOVE"
@export var title_them: String = "THEM"
@export var title_mousies: String = "MOUSIES"

@export_group("Fence: the alley", "alley_")

## An extra line, on top of the tags. Empty and only the tags are drawn.
@export_multiline var alley_message: String = ""

## Where the message's first letter goes. See [member title_message_at].
@export var alley_message_at: Vector2i = Vector2i(24, 112)

## How far apart the message's letters are.
@export_range(6, 16) var alley_message_spacing: int = 8

## The game's own tags, as they are.
@export var alley_hi: String = "HI'"
@export var alley_cat: String = "CAT"
@export var alley_love: String = "LOVE"
@export var alley_them: String = "THEM"
@export var alley_mousies: String = "MOUSIES"

@export_group("The game")

## How many lives to start each game with, 1 to 9, or [b]0 to leave the game's own three[/b].
##
## Applied at the start of every game rather than once, because the game writes its own three whenever one
## begins - off its menu, after a death, after Ctrl-R - so a count set before that would simply be
## overwritten. The number on the fence is the game's own and follows along.
@export_range(0, 9) var lives: int = 0

## Which skill to begin on, or [b]AS THE GAME ASKS[/b] to leave the player to pick it on the game's own
## menu. Picking one here is done by taking the game to that menu and answering it, because the skill is
## not a value in memory anywhere - it is a question the game asks.
@export var skill: Skill = Skill.AS_THE_GAME_ASKS

## Whether to start quiet, or [b]AS THE GAME LEAVES IT[/b], which is with the sound on.
##
## This is the game's own Ctrl-S switch, so the HUD's Sound button agrees with it from the first frame, and
## so does any replacement music or effect - a tune coming out of Godot is still the game making a noise.
@export var sound: Sound = Sound.AS_THE_GAME_LEAVES_IT

## A high score to put up as the one to beat. [b]Digits only[/b], up to seven of them - "42069" and
## "0042069" are the same score. Shorter is padded on the left, because the game reads a score most
## significant digit first.
##
## [b]Empty is the ordinary behaviour[/b]: the best score saved from an earlier run is used, and the game
## goes on saving new ones over it. Setting a score here puts that up instead, every time the game starts.
##
## Anything that is not a number is ignored and the saved score used, rather than writing rubbish into the
## seven bytes the game keeps its score in.
@export var high_score: String = ""

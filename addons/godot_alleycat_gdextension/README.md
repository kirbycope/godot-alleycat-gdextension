![Preview](./assets/godot-alleycat-gdextension.png)

# godot-alleycat-gdextension

Alley Cat (1984) running inside Godot 4.8 as a GDExtension, built on
[PureAlleyCat](https://github.com/kirbycope/PureAlleyCat). Open the project and press Play.

The `AlleyCat` node is a `TextureRect` that runs the game and shows its 320x200 screen as its own
texture, so it drops into any scene, scales, and can live inside a `SubViewport` like any other
control.

```gdscript
@onready var game: AlleyCat = $Screen/Game

func _ready() -> void:
    game.loaded.connect(func(): print("running"))
    game.load_failed.connect(func(reason): push_warning(reason))
```

## The game

`addons/godot_alleycat_gdextension/assets/CAT.EXE` is the whole of Alley Cat: 55 KB holding the code
*and* all 29 KB of the artwork, so it is the only asset the addon needs. It is committed here, which
is why the demo and the web export both just run.

Alley Cat was written by Bill Williams and published by Synapse Software and IBM in 1984. It is
long out of print and circulates freely as abandonware, but it has never been placed in the public
domain and the copyright has not lapsed. Point `exe_path` somewhere else if you would rather supply
your own copy; the node reports a missing file on screen rather than failing silently.

## The node

| Property | |
| --- | --- |
| `exe_path` | where to find `CAT.EXE` |
| `autostart` | load and run on `_ready` |
| `speed` | multiplier on the game clock, 0.1 to 4.0 |
| `joystick` | tell the game a game adapter is fitted, so its joystick question can be answered yes |

| Method | |
| --- | --- |
| `load_game()` | read `exe_path` and reset; emits `loaded` or `load_failed(reason)` |
| `start()`, `stop()` | run or pause |
| `is_running()`, `is_loaded()`, `is_ready()` | state; `is_ready` is true once a video mode is set |
| `get_frame()` | the current frame as an `Image` |
| `get_joystick_state()` | what the pad is telling the game port: `x`, `y`, `button_1`, `button_2` |
| `get_instructions()`, `get_status()`, `get_machine_state()` | diagnostics |
| `get_text()` | the BIOS text screen, which is where the game's setup and menu pages live |

The interpreter under it is `thirdparty/PureAlleyCat.h`, an 8086 that implements only what this one
program asks for. The BIOS video services it answers are set mode (`AH=00`), set cursor (`AH=02`),
teletype (`AH=0E`) and **scroll window (`AH=06` and `AH=07`)**. That last pair is the one worth naming: a
DOS program clears its screen by scrolling a window by zero lines, and ignoring it leaves the previous page
sitting in the text buffer underneath. Alley Cat's own Ctrl-M menu is shorter than the page it replaces, so
whatever the reprint failed to overwrite stayed on screen and the two pages came back spliced into one
unreadable one.

## What the game answers to

Cursor keys move, Alt acts, Ctrl-S toggles sound, Ctrl-R restarts, Ctrl-M returns to the menu and Esc
pauses. Those are the game's own, printed on its own setup screen, and the node feeds them as
scancodes through the INT 9 handler the game installs for itself.

A joystick works too, and the game's own question about it has a real answer. Alley Cat asks "Do you
want to use a joystick (Y/N)?", checks the BIOS equipment list for a game adapter, and then times the
one-shots on port 0x201 the way an IBM PC game port behaves. PureAlleyCat emulates all of that, and
the node drives the port from the same four directions and from Alt, which is the game's action key
and its joystick button at once. The game reads the port or the keyboard depending on how its
question was answered, never both, so feeding both costs nothing and works either way round.

Set `joystick` to `false` to have the game report no adapter at all, which is the keyboard-only
machine.

The setup questions are the ones to plan for. The game asks them in text and will not go on until
they are answered, so Y, N and the four skill letters each need something to press them; on a pad
that means six buttons, not one button that guesses.

## Input is InputMap actions, and nothing else

The node reads the InputMap. It listens for the actions below and has no opinion about which key or
button fires them; nothing else reaches the game.

| Action | What the game gets |
| --- | --- |
| `alleycat_up` `alleycat_down` `alleycat_left` `alleycat_right` | the arrow keys, and the game port's two axes |
| `alleycat_alt` | Alt, the action key, and the game port's button |
| `alleycat_button_2` | the port's second button, which the game never reads |
| `alleycat_esc` | Esc, paws mode |
| `alleycat_sound` `alleycat_restart` `alleycat_menu` | Ctrl-S, Ctrl-R and Ctrl-M |
| `alleycat_yes` `alleycat_no` | Y and N, the joystick question |
| `alleycat_kitten` `alleycat_house_cat` `alleycat_tomcat` `alleycat_alley_cat` | K, H, T and A, the skill menu |

`AlleyCat.get_expected_inputs()` returns that list at runtime and
`get_missing_inputs()` returns the ones nothing has registered, so a host can say what is unbound
rather than leaving the player with a game that ignores them.

Four more actions in the demo are the host's, not the game's - Alley Cat has no idea any of them happened:
`alleycat_look` (F6) cycles the looks, `alleycat_rewind` (Backspace, the left trigger) winds time back,
`alleycat_fullscreen` (F, the right shoulder) grows the picture to fill the window, and `alleycat_esc` opens
the paws menu in place of the game's own paws mode. Fullscreen keeps the game's shape: the screen is an
`AspectRatioContainer`, so the 320x200 picture fills the height or the width, whichever runs out first, and
the HUD draws over it the way it already does on a phone.

**Nothing is bound for you.** A project registers these actions itself, or installs the controls
addon and lets it do it. That is the whole contract: bind `alleycat_up` to whatever you like and the
cat walks.

```gdscript
InputMap.add_action("alleycat_up")
var event := InputEventKey.new()
event.physical_keycode = KEY_W
InputMap.action_add_event("alleycat_up", event)
```

## The HUD

The demo's on-screen controls are [godot-controls](https://github.com/kirbycope/godot-controls)
itself, instanced in `demo.tscn` as `Controls`, and because the game reads actions the HUD **is** the
mapping rather than a picture of one. Change a slot and you change what the button does.

Open [alley_cat_controls.tscn](./scenes/alley_cat_controls.tscn), which inherits the addon's
`controls.tscn`, and every slot is an inspector field. Its `input_catalog` is
[alley_cat_inputs.tres](./resources/alley_cat_inputs.tres), a copy of the list above, so each
`action_*` is a dropdown of the actions the game actually reads and a slot cannot name something
that will never arrive. A slot left blank is a button this game does not use, and the addon hides it.

[alley_cat_controls.gd](./scripts/alley_cat_controls.gd) subclasses the addon's `Controls` and adds
two things: the keyboard key behind each action, so the HUD's keyboard art names the key the game
answers to and lights up when it is pressed, and the words for the setup questions, which the same
buttons answer differently. `set_setting_up` swaps them with the addon's own `set_labels` and
`reset_labels`.

Every button on the HUD does exactly the one thing drawn on it, which took some deciding. The stick
and the arrow keys move the cat. The d-pad and the K, H, T and A keys are the skill menu, because the
game asks that in text and a pad has no letters, so those four answers need a home and the d-pad is
the only cluster free to be one - it deliberately does not double as a second way to walk, or the
player is shown two identical d-pads and one of them is lying. The face buttons are Alt, Sound, No
and Yes; Esc and Ctrl-M sit above. The shoulders, the triggers and the right stick are blank, and the
addon hides a blank slot.

The keyboard art names Alley Cat's own keys throughout rather than the addon's defaults, one
`keyboard_mouse_*` texture per slot set in the inherited scene, so a key drawn on the HUD is a key
the game answers to.

On a touchscreen the movement control is the four arrow buttons, not the virtual stick: the scene sets the
addon's `touch_movement` to `BUTTONS`. Alley Cat reads four directions and nothing in between, so an
analogue stick works against the player - a finger a fraction off the axis is a direction the game has no
way to express, and it reads as the control being finicky. The buttons are the movement slots, which already
carry the arrow art this scene gives them for its keyboard players.

### The HUD follows the game's screens

Alley Cat asks its setup in text rather than drawing it, and the same buttons answer different things on
each page, so `set_stage` dresses the HUD for whichever page is up and `Stage` names them:

| Stage | The page | What the HUD shows |
| --- | --- | --- |
| `ASKING_JOYSTICK` | "Do you want to use a joystick (Y/N)?" | Yes and No |
| `ASKING_SKILL` | "Please select your skill level" | the d-pad, labelled Kitten, House Cat, Tomcat, Alley Cat |
| `READY_TO_START` | the instructions, ending "Press any key to start." | one button, labelled Start |
| `PLAYING` | the alley | the scene's own words |

`READY_TO_START` exists because of the Menu button. Ctrl-M brings the player back to the setup, and once a
skill has been picked there the game reprints its instructions and waits to be told to go. That is a third
page and not the skill menu again: the d-pad has stopped answering anything, so a player left to find the
key themselves is reading "Press any key to start" with a HUD still offering four skills, which is how the
Menu button ended up being a way in and not a way out.

The demo presses that key for them. Of the three setup screens only the skill menu is a real choice - the
joystick question is about hardware Godot has already dealt with, and this page is not a question at all -
so `_answer_the_joystick_question` takes the first and `_press_on` takes the third, and pressing Menu then
a skill puts the player straight back in the alley. The page is on screen for about one frame, which is why
`READY_TO_START` still has a Start label: if the press ever fails to land, the HUD names the button that
works rather than showing a dead end.

## Tests

```bash
godot --headless --audio-driver Dummy --path . -s addons/gut/gut_cmdln.gd -gdir=res://addons/godot_alleycat_gdextension/tests -gexit
```

Two suites, and both drive the real thing rather than asserting against a table.
`test_alley_cat.gd` sends actual joypad and key events and asks the node and the game what happened;
the pad answering the setup questions and starting play is one test end to end. `test_demo.gd`
opens the demo scene and checks the wiring: every slot mapped, every action it names registered,
the labels the scene carries, and the HUD following the game between its setup screen and play.

`get_joystick_state()` is what makes the mapping assertable without reading pixels, which is the
only other way to tell a stick pushed left from one that went nowhere.

One machine exists per process, so only one `AlleyCat` node can run at a time. That is a property
of the library, not of the node.

## Building

The built libraries in `addons/godot_alleycat_gdextension/bin/` are committed, so installing the
addon needs no toolchain. To rebuild:

```bash
git clone https://github.com/godotengine/godot-cpp.git      # not vendored
godot --headless --dump-extension-api                        # see below
scons platform=windows target=template_debug custom_api_file=extension_api.json
scons platform=windows target=template_release custom_api_file=extension_api.json
scons platform=macos   target=template_debug custom_api_file=extension_api.json
scons platform=macos   target=template_release custom_api_file=extension_api.json
scons platform=web threads=no target=template_release custom_api_file=extension_api.json
```

The macOS builds are universal binaries and must be made on a Mac, against an API dumped from that
machine's own Godot. The web build needs the Emscripten SDK on `PATH`, and `threads=no` because the
export preset sets `variant/thread_support=false`; a library built with threads will not load into a
single-threaded export, and vice versa.

`custom_api_file` is needed because godot-cpp's master ships `extension_api` files only up to 4.7,
and this targets 4.8. Dump the API from the engine build you actually run and the bindings match
it; without that the extension loads against the wrong ABI.

## The web demo

`.github/workflows/pages.yml` exports the demo and hands it to Pages on every push to `main`. To
build it here instead:

```bash
godot --headless --path . --import      # a few times; the controls addon brings hundreds of SVGs
godot --headless --path . --export-release "Web" build/index.html
python -m http.server --directory build
```

The export is single-threaded, so a plain static server is enough; no cross-origin isolation headers
are needed.

`CAT.EXE` is committed, so CI exports a playable build with no extra setup. The export preset names
it in `include_filter` explicitly, because Godot has no importer for a DOS executable and would
otherwise leave it out of the pack. A GitHub Pages site is public even when the repository is
private, so the deployed demo is a public copy of the game.

## Layout

| Path | |
| --- | --- |
| `src/alley_cat.{h,cpp}` | the node |
| `src/alley_cat_impl.c` | the one unit that defines `ALLEYCAT_IMPLEMENTATION` |
| `src/register_types.{h,cpp}` | GDExtension entry point |
| `addons/.../thirdparty/PureAlleyCat.h` | the library, vendored |
| `addons/.../scenes/demo/` | the demo scene |
| `addons/.../scenes/alley_cat_controls.tscn` | the HUD mapping, inherited from godot-controls |
| `addons/.../scripts/alley_cat_controls.gd` | the `Controls` subclass behind it |
| `addons/.../tests/` | GUT tests |
| `tools/addons.json` | what `pull_addons.py` fetches into `addons/` |

## Looks

`F6` cycles twenty-one ways of showing the same four colours. They are one shader with a mode rather than
twenty shaders, because all of them start from the CGA palette index rather than the RGB it arrives
as - which is what makes a recolour exact instead of a hue rotation guessing at what was meant.

| | | | |
| --- | --- | --- | --- |
| CGA | Amber CRT | Green CRT | Trinitron CRT |
| Comic | Cel | Game Boy | Paper |
| VHS | Pen and Ink | Dither | Negative |
| Deep Fried | Double Vision | Nausea | Holofoil |
| Film | Frost | Squiggle | Blueprint |
| Championship | | | |

`Left Trigger` (or `Backspace`) rewinds while held. Snapshots are whole copies of the machine taken
at the game's own 18.2 Hz, kept in a ring sized by the node's `rewind_seconds`; set it to zero to
turn rewind off and free the memory, which is what a web export wants.

Four of the looks are reimplementations of techniques published on
[godotshaders.com](https://godotshaders.com), all of them CC0, and none of the original code is
copied here - the source is 320x200 in four colours and wanted its own treatment:

| Look | After | Licence |
| --- | --- | --- |
| VHS | [VHS Tape Effect](https://godotshaders.com/shader/vhs-tape-effect/) by blblblblb | CC0 |
| Pen and Ink | [Simplified Hand-drawn Hatch Lines](https://godotshaders.com/shader/simplified-hand-drawn-hatch-lines/) by misha.cilantro | CC0 |
| Holofoil | [MemeHoloFoil](https://godotshaders.com/shader/memeholofoil-parody-holographic-card-foil/) | CC0 |
| Dither | [Classic dithering shader](https://godotshaders.com/shader/classic-dithering-shader/) | CC0 |

`Championship` is the odd one out: it is not after a shader but after a game. Pac-Man Championship
Edition redrew a 1980 maze as tubes of light on black, and Alley Cat suits the same treatment because
its artwork is black line work - outlines, the writing on the fence, the sprites - over two flat
fills. So the ink lights up, the fills go almost out, and the light spills, which is the half of that
look people leave out.

It also answers to the game rather than to a clock, which needs three things the shader cannot know,
because a shader is handed one frame with no memory of the last.

A lit region follows whatever is moving. The host samples every fourth pixel each way, diffs against
the previous frame and splits what changed into two centroids, so the light finds the cat and
whatever is chasing it without being told which is which.

The stage colour drifts with how busy the alley is. `get_effect_starts()` counts the sounds the game
has begun that were not the music, and each one nudges the hue a little. It has to be a count: the
voice that is sounding is a level, and a level that is already EFFECTS says nothing when the next
effect starts. That is why the colour used to change once and then never again.

And the colour jumps, with a wipe down the screen, whenever the game draws a different picture -
through a window into a room, back out into the alley, a life lost, a level begun.
`get_video_writes()` counts bytes drawn into the CGA window, and the size alone tells those apart:
measured in play, moving the cat and the mice costs about 120 bytes in a busy frame, while every
screen change costs the whole 16K at once. Pixels cannot answer this. Alley Cat's screens share a
background colour, so two completely different places agree on most of their pixels, and a new screen
arrives over several frames rather than in one, so a frame-to-frame difference never spikes either.

## Reading the machine

Alley Cat is one hand-written 1984 assembly program, so its variables sit at fixed addresses and what it
knows about itself is in memory at a place that does not move between runs. `peek(at, length)`, `peek_u8`
and `peek_u16` read it, and `get_load_address()` says where the image was put, so an offset into `CAT.EXE`
becomes an address here.

Finding *which* address is the harder half, and a plain differential scan is not enough on its own: taking a
snapshot before and after a life is lost turns up hundreds of bytes that happened to fall by one, almost all
of them animation timers. What works is asking the game where its code is.

`watch(from, to)` remembers the routines that write into a range of memory, and `get_watch_writers()` gives
them back as offsets into `CAT.EXE`, which line up with a disassembly of the file. Point it at the few bytes
of screen something is drawn in, let the game draw, and the drawing code names itself. Pointed at the band
the score is drawn across while a game starts, it comes back with five addresses inside 200 bytes of each
other; pointed at the middle of the picture while the cat walks, it comes back with three of the same ones.
Those are the game's sprite blitters:

| Routine | What it does |
| --- | --- |
| `sub_09FCD` | `rep movsw` straight into the screen: the plain copy. The scenery, the title, the font, and every saved background going back |
| `sub_09F65` | reads the background first, saves it at `[bp]`, then ANDs the sprite into it. White leaves the background alone and black is ink: the cat, the mice on the lines |
| `sub_09EFC` | saves the background the same way, then lays the sprite over it with black as the key, working the mask out from the pixels as it goes. The dog, the thing that comes up out of the bins, the three sprites in the table at `0x1F5F` |
| `sub_09FA0` | never touches the screen. Lifts a column out of a wider sprite into the scratch buffer at `DS:000E`, walking its source by `AL` words a row; a blit *from* the buffer is what reaches the screen. That is how the game clips the cat and the dog at the edge |
| `sub_09FFA` | the other way round: screen into a buffer, the background saved before a plain copy goes over it |

The first reading of this file hooked three of them and missed `sub_09EFC` altogether, so nothing it drew was
ever reported and the dog was in the catalogue only as its own background. It also took `sub_09FA0`'s copies
for sprites and reported them at a place on the screen they never went - `x=56, y=0`, the buffer's offset read
as a screen offset - which is what the rows named `0x10FA8 8x11` and the like were. `get_sprites()` now says
which routine drew each sprite as `kind` ("plain", "masked" or "keyed"), and reports a blit from the scratch
buffer as the sprite it was lifted out of, with `stride` giving that sprite's full width so a host can tell
which column it is looking at. Every one of the 90 distinct draws seen in a game, compared pixel for pixel
against the bytes at the address it reports, matches; the only two that do not are backgrounds the game
drew over in the same tick.

They write the CGA window the way the hardware wants it - 80 bytes a row, even rows at `0xB8000` and odd
rows `0x2000` further on, `xor di, 0x2000` to change bank - which is why the picture cannot simply be
scaled: the artwork is 2 bits a pixel, interleaved by parity.

That is the hook hi-res art needs. It is also how the score was found.

`get_watch_callers()` answers the other half of the question. Every sprite in the game goes through those
same few blitters, so the writer says *how* something was drawn and only the caller says *what*: Alley Cat's
blitters are reached by a near call and push nothing, so the return address is still on top of the stack
when the store happens, and one word at `SS:SP` is the caller. Watching the score's band while a game starts
named `sub_09969`, and the disassembly explains it at once - it reads a digit through `BX`, shifts it by four
to index a glyph table at `0x2720`, blits it, and does that seven times with an extra column skipped after
the third. That is `000-0000`. Its two callers hand it the two numbers:

| | Offset | Drawn at |
| --- | --- | --- |
| Lives | `0x1f80` | screen `0x1260` |
| Lives last drawn | `0x1f81` | - |
| Score | `0x1f82` | screen `0x143c` |
| High score | `0x1f89` | screen `0x12ca` |

The lives came from the same reading. `sub_098E3` compares `0x1f80` against `0x1f81` and only draws when
they differ, so the first is the count and the second is a note of what is already on the fence - which is
why writing the count alone makes the game repaint it. `sub_098C0` confirms the two scores independently:
it walks the seven digits at `0x1f82` against those at `0x1f89` and copies one over the other when the game
has been won well enough.

Seven bytes each, one decimal digit per byte, most significant first - which is why a scan for a number
never found them, and why `sub_09936` adds to the score with `aaa`, the 8086's decimal adjust.

Those offsets are counted from `get_data_address()`, not from `get_load_address()`. Alley Cat's data segment
is a page above where the image was loaded, so an offset taken straight off the disassembly and added to the
load address reads rubbish. `peek` and `poke` work in physical addresses, and the sum of the two is one.

### When the game stops answering

`get_machine_state()` reports the three things about the machine that are not in its memory: `image_offset`,
where the instruction pointer is as an offset into `CAT.EXE`, so it lines up with a disassembly;
`interrupts_enabled`, because a queued key is only handed to the game's own INT 9 handler while they are on;
and `keys_queued`, how many are still waiting behind it.

It is for telling apart the two things that look identical from outside - a game spinning in a loop that is
ignoring input, and one that is simply waiting at a prompt. A frozen `image_offset` across two reads with
`keys_queued` at zero says the keys are arriving and the program is not acting on them, which points at the
prompt rather than at the input path.

## Watching the game draw

Hi-res artwork over a 1984 game needs to know what was drawn and where, and the game will say so. Set
`reports_sprites` and `get_sprites()` gives back everything drawn in the last frame, in the order it was
drawn:

| | |
| --- | --- |
| `source` | the address the artwork was copied from, which `peek` can read |
| `x`, `y` | where it went, in the 320x200 picture |
| `width`, `height` | how big, in pixels |
| `masked` | whether it was ANDed over the background or painted straight on |

It costs nothing while it is off, and very little while it is on: the check is on the call instruction, which
is rare next to the millions of ordinary instructions a second the interpreter runs.

`at` is also there, as the raw offset into the CGA window, but `x` and `y` are what a host wants. That window
is not a bitmap: rows alternate between two banks `0x2000` apart and each byte is four pixels, because that
is what the hardware wanted rather than anything anyone would choose.

Measured in play, a busy frame draws four sprites, all from one address, which is the mice running along the
ground - one piece of artwork used four times, which is exactly what a host replacing it needs to know. The
attract screen draws one, the cat walking the fence.

The report is cleared at the start of every frame, so a quiet frame says nothing and a host should read it
every frame rather than whenever it happens to look.

## The rooms

Alley Cat is one alley and seven other screens, and the game gets from the one to the others through the
only computed jump in the program: at image offset `0x746E` it reads a word at `DS:0004`, clamps it to 0-7,
and jumps through a table of eight at `CS:0250` (image `0x7480`). Each target is a small loop that sets the
word back to itself and calls that screen's routines until one of a handful of flags says it is over.

| `DS:0004` | Screen |
| --- | --- |
| 0 | the alley - though the alley's own loop lives elsewhere and only ever *sets* this to 0 |
| 1 | a room with a fishbowl on a table, and a broom |
| 2 | inside the fishbowl: the cat swimming among the fish. Room 1 leads here |
| 3 | the bookcase with the plants on top, and the spider |
| 4 | the cheese, and the mice in it |
| 5 | the birdcage on the table |
| 6 | the sleeping dogs and their bowls |
| 7 | the hearts: the finale |

How the game picks one is at `0x7415`: when the cat has gone through a window (`DS:0551` non-zero) it rolls a
die, and either takes `[0x421 + (skill & 3) * 4 + (roll & 3)]` - a three-by-four table, one row per skill -
or one of the five at `0x42D` (`1 3 4 5 6`), refusing anything that matches the last two rooms it remembers
at `0x41D` and `0x41F`. `DS:0418` set means the finale instead. `DS:0552` is "this room is over" and
`DS:0551`, `0553`, `041B` and `041C` are the other ways out; every room loop tests them.

`tools/sweep.gd` uses all of that rather than trying to jump the cat onto a bin, up a clothesline and
through an open window with scripted keys: it writes the room it wants into both tables, forgets the last
two, and holds `0x551` up until the alley loop takes it. That is how every room's artwork got into the
catalogue, and it is repeatable: a sprite nobody has seen is one more room, or one more thing to do in it.

## Putting your own artwork in

`AlleyCatArt` draws replacement pictures over the game's own sprites, sprite for sprite. It listens to
`get_sprites()` rather than trying to recognise anything in the picture: each frame it asks what was drawn
and, for anything it has a replacement for, paints over the top in the same place and at the same size.

The artwork is a resource - `AlleyCatArtwork`, a list of `AlleyCatSprite`, each pairing a source address
with a texture - so a set is a file that can be swapped whole, and anything not named in it is left exactly
as the game drew it. A set can be finished one sprite at a time.

`enabled` turns the whole overlay on and off, at any moment, mid-jump included. Nothing in the machine
moves either way: the game draws its own artwork all along, and the only difference is whether those bytes
reach the framebuffer and whether this node paints over the top of them. That is what the paws menu's
**Art** row switches, and it is why it needs no restart. Set it to `false` in the inspector to ship with
the 1984 picture and offer the remaster from the menu.

`resources/artwork.tres` has a slot for **every** sprite the game draws - 194 of them across the alley and
all seven rooms, counting the fourteen letters the addon draws for it - and each one carries the game's own picture in `original`. That is what makes the thing usable: an address is not a
name, and nobody can draw a replacement for a sprite they cannot look at. Open the resource, scroll to a
sprite, see what it is, drop a texture into its `texture` and that sprite is replaced and nothing else.

Every slot ships empty except the worked example, which is the player's cat. It takes **twelve** slots, and
that is the first thing to know before replacing anything:

| | Frames |
| --- | --- |
| Walking left | `0x10E5E` `0x10EA0` `0x10EE2` `0x10F24` `0x10F66` `0x10FA8` |
| Walking right | `0x10CD2` `0x10D14` `0x10D56` `0x10D98` `0x10DDA` `0x10E1C` |
| Standing still | the mask at `0x106FA`, not covered - see below |

A sprite that animates is several pieces of artwork, and a thing that faces both ways is two animations.
Covering one frame puts the replacement on screen only for the sixth of the time that frame is up, which
reads as a flicker; covering one direction puts it there only while the player walks that way. Both were
tried and both look broken. Note also that the art is drawn facing one way and mirrored for the other, and
that getting the mirror backwards makes the cat moonwalk.

Standing still is deliberately left as the game drew it. When the cat stops, the game stops drawing a walk
frame and draws the mask at `0x106FA` in its place - a plain black box it shares with other things on the
screen - so a replacement hung on that address would follow those about as well. Finding these twelve is
five minutes of work with the report: hold left in a real game and list what `get_sprites()` names, hold
right and list that, and the two sets are the two directions.

### Which sprite is which

An address is not a name, so there is a contact sheet, and it is a live one.

**The Alley Cat Artwork panel.** `plugin.cfg` registers an editor plugin that puts the catalogue in the
bottom panel as a sheet: every sprite at once, blown up on a mid grey so the black ones can be seen, the
name under each, and the ones that already have a replacement named in green. Click a sprite and its details
are on the right - the game's own picture beside the replacement, the name to type in, and a resource slot
to drag a texture onto from the FileSystem dock. Both are written straight into the `.tres`.

That panel exists because the inspector cannot do this job. An `AlleyCatArtwork` is a hundred sprites in a
flat array, and the inspector draws an array of resources as a hundred rows with a name on each: finding one
means opening a row, looking at the picture inside, and closing it again. The filter box takes a name or an
address, and "Replaced only" says how much of a set is finished.

**Zoom.** The sprites are eight to forty pixels wide, so how big they need to be drawn to read depends on
the screen: a cell of 104 pixels is comfortable on a desktop monitor and a thumbnail on a small high-density
one. The slider in the bar, the `-` and `+` beside it, or Ctrl and the wheel over the sheet zoom the sheet
and the two previews together, from half size to four times, and the editor remembers it per project.

**Groups.** Most of the game's artwork comes in families - a thing that walks is six frames each way, and a
thing drawn at three sizes is three entries - so the useful unit when replacing artwork is the family rather
than the sprite. Each sprite has a `group`, typed into the details panel or chosen from the dropdown beside
it, and the dropdown in the bar narrows the sheet to one. A group exists because a sprite says it is in one;
there is nothing to declare. "Ungrouped" is the list still to be worked through, which is the one to sort
from. The cat's twelve frames ship in a group called Cat.

**Still pictures.** `assets/artwork/sprite_sheet_1.png`, `_2` and `_3` are the same thing as flat images,
rebuilt from `assets/artwork/original/` by `tools/sprite_sheet.py`. They are worth keeping for reading away
from the editor, and for pasting into a conversation about which sprite is which.

Naming beats guessing: three separate guesses at which sprite was the player's cat were all wrong before the
sheets existed. Names typed into the panel live in `artwork.tres`, and `build_artwork_resource.py` rewrites
that file from nothing rather than reading the old one, so a name that has to survive a rebuild goes in the
`KNOWN` dictionary at the top of the script - which is where the cat's twelve frames are. Every other row has a name too, from `GUESSES` beside it: the best reading of a sweep that recorded which
room each sprite was drawn in and where, the room's routine in the disassembly, and the picture itself. The
game has no names for its artwork, so those are guesses, and the ones that are only a guess say so with a
question mark - "Cat Swim Sink?", "Bird Flying?". A name typed into the panel wins over either dictionary.

**Blanks are left out.** An address the game blits from that decodes to a rectangle of one flat colour is
not a picture - a run of identical bytes used to clear a strip - and the builder drops it. So are the
buffers and the clipped columns, at the exporter, so what is left is entries of real artwork and nothing else.

Two things the catalogue records are worth reading before drawing anything. `draws` says how often the
sprite was drawn, which separates the cat and the scenery from the rarities. And the note says which of the
game's routines draws it, because that is what says which colour is see-through: an *ANDed* sprite (the cat,
the mice) leaves the background wherever it is white, a *keyed* one (the dog) wherever it is black, and a
*plain* one nowhere. The exported picture carries that as alpha, so what the catalogue shows is what the
screen shows, and a replacement drawn on transparency lands the same way.

**Quick sprites.** A tick of the game is not always one frame of everything. When the cat is quick - the walk
along the fence on the title screen - the game draws a frame, wipes it with the saved background and draws
the next one four pixels on, all inside one tick, and the report holds all three. Only what nothing was drawn
over afterwards is still on the screen, so the overlay leaves out any entry the game drew over later in the
same report; taking them all painted two cats a step apart, and the wiped one trailed until the next tick.

**Parts of a sprite.** The game does not always draw a sprite from its first byte. It clips the cat and the
dog at the side of the screen by lifting a column out of the artwork into a scratch buffer and drawing that,
and it has things rise out of and sink into their surroundings by drawing the lower rows only, the source
walking down the artwork a row at a time. `get_sprites()` reports the first as the sprite it came from plus
a `stride`; the second simply reports the address it started at. Either way `AlleyCatArtwork.locate()` says
where that address falls inside a replaced sprite - which row, which column - and `AlleyCatArt` draws that
part of the replacement, so a replacement cat walks off the edge and a replacement mouse climbs out of the
cheese the way the game's own do, and nothing has to be drawn for the partial cases. Rows for them do not
exist in the catalogue, and should not: an entry that starts inside another's artwork and ends inside it too
is a part, not a sprite, and the exporter leaves them out along with the buffers the game saves backgrounds
in. The game is told the size of each replaced sprite as well as its address, so the partial draws are
hidden along with the whole.

Rebuilding the catalogue, when a new screen turns up sprites nobody has seen:

```bash
# run tools/sweep.gd against the demo (the Godot MCP's run_script), save what it returns, then
python tools/export_sprites.py <catalogue.json>      # CAT.EXE -> assets/artwork/original/*.png
python tools/build_artwork_resource.py               # -> resources/artwork.tres
```

`export_sprites.py` reads the artwork straight out of `CAT.EXE`: the image was loaded at `0x10000` and the
file has a 512 byte header, so a sprite's bytes are at `(source - 0x10000) + 512`. CGA mode 4 packs four
pixels to a byte, two bits each, and which of the four is see-through is not in the bytes at all - it is
which routine drew the sprite, so the sweep records that and the exporter writes white transparent for an
ANDed sprite, black for a keyed one, and nothing for a plain copy. It also throws away what is not artwork:
the buffers the game saves backgrounds in (what the file holds at those offsets is nothing), anything the
sweep saw change while the game ran (the same thing found the other way round), and the clipped columns.
Files for anything no longer catalogued are removed, so a mistaken export cannot linger.

What it buys is resolution, not position: the replacement is drawn where the original was and at the same
size, so the game plays exactly as it did. The game's own sprite is eight pixels by five, or thirty-two by
fifteen, scaled up to whatever the window is; the replacement is drawn at the screen's resolution instead.

Two things worth knowing if you write something else against `get_sprites()`.

The report is cleared on the game's own tick, about eighteen times a second, not on the host's frame. A tick
is tens of thousands of instructions and the host asks for a few hundred at a time, so one tick's drawing is
spread across dozens of frames - clearing per frame hands back a fragment of a tick.

And the report is what the game *just drew*, which is not what is on the screen. It only redraws what moved,
so a cat standing still is absent from every report while plainly still there. Whatever you draw from it has
to be held rather than timed out, or it blinks off whenever the player stops moving. Measured at 60 frames a
second, holding it properly is the difference between the replacement being on screen 9% of the time and
88%.

Held, but not held forever. A replacement is dropped as soon as the game draws anything *over* it, which is
the other half of the same rule: the cat turns round and walks off as a sprite there is no replacement for,
and without that check the old picture is left standing where the cat used to be. Overlap is the test,
because the report gives the rectangle the game blitted into and the game repainting that patch is exactly
what makes a replacement over it untrue.

## Keeping a high score

The remaster node carries the high score across runs, which the game cannot do for itself: it was written
for a machine that was switched off at the wall. The saved digits are put into memory once, as soon as the
machine is up, and from then on it only reads - whenever the game's own high score beats what is on disk,
`user://alley_cat_high_score.txt` is rewritten. The file is the seven digits as text, so it can be read and
edited by a person. `get_score()` and `get_high_score()` give either as an ordinary number.

Nothing else writes to the game. A run in progress is never reached into.

## Losing a life

The wipe down the screen belongs to a death, and now says so. It used to be inferred from how much of the
screen was redrawn, which could not tell a life lost from a level begun because both replace the picture.
The game keeps the count itself, so it is read instead.

One honest wart. Polled every frame, `0x1f80` does not hold still: the true count and zero come back
alternately, 122 times across three real deaths in one measured game. The game's own code writes only a 3, a
9 and a decrement, so the zero is not something it means, and it is not the data segment moving either -
that was checked and it does not. It is unexplained. Rather than build on a reading that is not understood,
the count has to hold steady for `LIVES_STEADY_TIME` before it is believed, which steps over the flicker
completely: the same measured game reported 9, 3, 2, 1, 9 and fired exactly three wipes for three deaths.

## The remaster layer

`scenes/alley_cat_remaster.tscn` is one node to drop into a scene. Point its `game` at the [AlleyCat]
node, hand it a list of `looks`, and it takes `Esc` - Alley Cat's own paws key - before the game sees
it and puts its own menu up instead.

The menu offers the look, the replacement artwork, the skill, the two volumes and how much rewind to
keep. The **Art** row appears only where the node's `art` has been pointed at an `AlleyCatArt`; a project
with no replacements gets no row rather than a dead one. It reads `Remastered` or `Original`, either arrow
lands on the other, and `is_remastered_art()` / `set_remastered_art()` are the same switch from code.

It does not try to detect the game's paws mode, and does not need to. A host that owns the key can
simply stop running the machine, which is a truer pause than the game's own: Alley Cat has no idea it
happened, so it has no opinions about what the player may do next. Rewind already works the same way.
Everything the menu changes - the look, the two volumes, how much rewind to keep - belongs to the
host, so a snapshot taken before the menu is still good after it.

The key is polled rather than listened for, because the HUD's own pause button is a
`TouchScreenButton` and those press their action straight into the input state without ever sending
an event. Polling catches the key, the pad and the on-screen button through one path - the same
reason the library polls its own inputs.

### Sound

The game drives one speaker from two places: a music player walking a note table, and the routines
that make its effects. Because there is only one speaker they interrupt each other rather than
mixing, so the node reports which of them last programmed the timer and scales that one on the way
out. `music_volume` and `effects_volume` are therefore real and separate, and silencing the tune
leaves the effects alone - which is what makes a swap possible.

Nothing here reads the waveform. A square wave carries no sign of what asked for it; only an
interpreter can know, and this one tags the write by the address that made it.

`resources/sounds.tres` is an **example** `AlleyCatSounds` with every slot empty, which is exactly how
the game sounds as it shipped. Copy it into your own project - examples in the addon never point at a
project's files - fill in `music` to replace the tune, and the named effect slots as they become
attributable. Giving it a `music` stream silences the game's own tune; clearing it gives it back.

Replacement sound obeys the game's own Sound switch. Ctrl-S is Alley Cat's, printed on its own menu and
sent by the HUD's Sound button, and a player who presses it wants quiet - a tune and a meow coming out of
Godot instead of the PC speaker are still the game making a noise as far as they are concerned. So the
remaster reads the switch out of the machine at `SOUND_AT`, `0x0000` from `get_data_address()`, and follows
it: the tune is turned down rather than stopped, so it keeps its place and turning the sound back on does
not restart the piece, and an effect asked for while the sound is off is simply not started. An effect part
way through is cut, because there is nothing to keep its place for.

It is read rather than counted. Watching for presses of the Sound action would work until the first restart,
rewind or trip through the game's own menu, none of which this layer is told about; the byte is right across
all three because it is the game's own.

Finding it was a differential scan, which is the technique that failed on the score and works here because
the value is a switch rather than a number: snapshot sixteen kilobytes of the data segment, press Ctrl-S,
snapshot, press it again, snapshot, and keep only the bytes that changed and then came home. Exactly one
does. Non-zero is on, and the confirmation is that the speaker goes quiet with it - five effects over ten
seconds of play with it on, none over the same play with it off.

## Licence

The code here is MIT and is original work: the node, the HUD mapping and the build. `assets/CAT.EXE` is not covered by it and is not ours to license - see **The game** above.

| Asset | What it is | From | Licence |
| --- | --- | --- | --- |
| `assets/artwork/cat_walk_*.png`, `assets/artwork/mouse.png` | sample replacement sprites, drawn for this addon | original work | MIT, with the rest of the code |
| `assets/artwork/added/*.png`, `assets/artwork/extra_font.png` | the fourteen letters Alley Cat does not carry, drawn for this addon by `tools/make_font.py` | original work | MIT, with the rest of the code |
| `assets/artwork/original/*.png`, `assets/artwork/sprite_sheet_*.png` | Alley Cat's own artwork, sliced out of `CAT.EXE` so each sprite can be looked at | the game | not ours to license - see **The game** |
| `assets/cat_meow.ogg` | the sound the cat makes on being caught | Gravity Sound, Animal SFX | see the pack's own terms |

See [PureAlleyCat](https://github.com/kirbycope/PureAlleyCat) for what the library is and how it was
verified, and `alley-decomp` for the reverse engineering that established the graphics format.

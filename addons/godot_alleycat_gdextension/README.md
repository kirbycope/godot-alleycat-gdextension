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
| `get_instructions()`, `get_status()` | diagnostics |

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

## The remaster layer

`scenes/alley_cat_remaster.tscn` is one node to drop into a scene. Point its `game` at the [AlleyCat]
node, hand it a list of `looks`, and it takes `Esc` - Alley Cat's own paws key - before the game sees
it and puts its own menu up instead.

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

## Licence

The code here is MIT and is original work: the node, the HUD mapping and the build. `assets/CAT.EXE` is not covered by it and is not ours to license - see **The game** above.

See [PureAlleyCat](https://github.com/kirbycope/PureAlleyCat) for what the library is and how it was
verified, and `alley-decomp` for the reverse engineering that established the graphics format.

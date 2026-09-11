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

The keyboard art names Alley Cat's own keys throughout, not the addon's defaults: Alt, S, N and Y on
the face buttons, K, H, T and A on the shoulders and triggers, Esc and M above, and the arrow keys on
both the stick and the d-pad. Every one of those is a `keyboard_mouse_*` texture set in the inherited
scene.

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

## Licence

The code here is MIT and is original work: the node, the HUD mapping and the build. `assets/CAT.EXE` is not covered by it and is not ours to license - see **The game** above.

See [PureAlleyCat](https://github.com/kirbycope/PureAlleyCat) for what the library is and how it was
verified, and `alley-decomp` for the reverse engineering that established the graphics format.

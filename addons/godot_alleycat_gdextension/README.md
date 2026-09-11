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

## Controls

Cursor keys move, Alt acts, Ctrl-S toggles sound, Ctrl-M returns to the menu, Esc pauses. They are
the game's own, not remapped here; the node feeds scancodes through the INT 9 handler the game
installs for itself.

A joypad works too, and the game's own question about it now has a real answer. Alley Cat asks
"Do you want to use a joystick (Y/N)?", checks the BIOS equipment list for a game adapter, and then
times the one-shots on port 0x201 the way an IBM PC game port behaves. PureAlleyCat emulates all of
that, and the node drives it from the left stick and the d-pad.

| Pad | While the questions are up | While playing |
| --- | --- | --- |
| Left stick, d-pad | | move the cat |
| A | yes, and Kitten | jump, and the joystick button the game asks you to press |
| B | no, and House Cat | sound on and off (Ctrl-S) |
| X | Tomcat | |
| Y | Alley Cat | |
| Back | | Esc, paws mode |
| Start | | Ctrl-M, back to the menu |

The game reads joystick button 1 and never button 2, so B is free and carries the sound toggle.

The face buttons read two ways because the game asks its setup questions as text and a pad has no
letters. Each one sends both of the letters it could mean at once; the game ignores whichever is
not an answer to the question in front of it, so nothing has to keep track of which screen is up.

The stick also goes out as arrow keys, and Alt counts as the joystick button, so the pad and the
keyboard both work whichever way the joystick question was answered. Set `joystick` to `false` to
have the game report no adapter at all, which is the keyboard-only machine.

## The HUD

The demo's on-screen controls are [godot-controls](https://github.com/kirbycope/godot-controls)
itself, instanced in `demo.tscn` as `Controls`. It draws every button in the art of whatever device
is being played on, keyboard included, and redraws when that changes.

**The mapping is a scene, not code.** Open
[alley_cat_controls.tscn](./scenes/alley_cat_controls.tscn), which
inherits the addon's `controls.tscn`, and every slot is an inspector field: which action sits on
each button, what its label says, and which key face the keyboard art shows. A slot left blank is a
button this game does not use, and the addon hides it, which is why the shoulders, the triggers and
the right stick are absent.

The script beside it,
[alley_cat_controls.gd](./scripts/alley_cat_controls.gd), subclasses
the addon's `Controls` and adds the two things the addon leaves to the game: the keyboard key behind
each action, and turning a tap on the on-screen pad back into the joypad event the extension reads,
since a `TouchScreenButton` sends an `InputEventAction` and the mapping is in C++.

The setup questions are the one thing the scene cannot say on its own, because the same buttons mean
something different there. `set_setting_up` swaps the words with the addon's own `set_labels`, and
`reset_labels` puts the scene's back, which is what those are for.

`addons/controls/` is fetched rather than committed, so a fresh clone needs:

```bash
python tools/pull_addons.py
```

Known gap: the addon exports the key face for each **face** button, so those show Alt, S, Esc and M
as they should, but the stick and d-pad are hard-wired to WASD and IJKL. Alley Cat moves on the
arrow keys, so that half of the keyboard art is wrong until the addon exports those textures too.

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

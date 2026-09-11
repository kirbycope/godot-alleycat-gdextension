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

## You supply the game

**Alley Cat is not distributed here.** It is still under copyright: written by Bill Williams,
published by Synapse Software / Atari. Copy your own `CAT.EXE` to:

```
addons/godot_alleycat_gdextension/assets/CAT.EXE
```

That single file holds the code *and* all 29 KB of the artwork, so it is the only asset needed.
Without it the demo says so on screen rather than failing silently, and `.gitignore` is set up to
stop a copy being committed by accident.

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
| A | yes, and Kitten | act, and the joystick button the game asks you to press |
| B | no, and House Cat | the second joystick button |
| X | Tomcat | |
| Y | Alley Cat | |
| Back | | Esc, paws mode |
| Start | | Ctrl-M, back to the menu |

The face buttons read two ways because the game asks its setup questions as text and a pad has no
letters. Each one sends both of the letters it could mean at once; the game ignores whichever is
not an answer to the question in front of it, so nothing has to keep track of which screen is up.

The stick also goes out as arrow keys, and Alt counts as the joystick button, so the pad and the
keyboard both work whichever way the joystick question was answered. Set `joystick` to `false` to
have the game report no adapter at all, which is the keyboard-only machine.

## The on-screen pad

On a touchscreen the demo fills itself with the HUD from
[godot-controls](https://github.com/kirbycope/godot-controls) and turns its taps back into joypad
events, so the same C++ mapping serves a phone with no keyboard. The addon is optional: without it
the demo still runs, just without the pad. `addons/controls/` is fetched rather than committed:

```bash
python tools/pull_addons.py
```

## Tests

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://addons/godot_alleycat_gdextension/tests -gexit
```

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
```

`custom_api_file` is needed because godot-cpp's master ships `extension_api` files only up to 4.7,
and this targets 4.8. Dump the API from the engine build you actually run and the bindings match
it; without that the extension loads against the wrong ABI.

For the web export, `scons platform=web threads=no target=template_release` with the Emscripten SDK
on `PATH`.

## Layout

| Path | |
| --- | --- |
| `src/alley_cat.{h,cpp}` | the node |
| `src/alley_cat_impl.c` | the one unit that defines `ALLEYCAT_IMPLEMENTATION` |
| `src/register_types.{h,cpp}` | GDExtension entry point |
| `addons/.../thirdparty/PureAlleyCat.h` | the library, vendored |
| `addons/.../scenes/demo/` | the demo scene |
| `addons/.../scripts/alley_cat_virtual_pad.gd` | the touchscreen pad, built on godot-controls |
| `addons/.../tests/` | GUT tests |
| `tools/addons.json` | what `pull_addons.py` fetches into `addons/` |

## Licence

MIT, and the code here is original work. It contains no part of Alley Cat; see
[PureAlleyCat](https://github.com/kirbycope/PureAlleyCat) for what the library is and how it was
verified, and `alley-decomp` for the reverse engineering that established the graphics format.

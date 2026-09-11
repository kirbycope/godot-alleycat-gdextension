#!/usr/bin/env python
# Builds the PureAlleyCat GDExtension. From this folder:
#   scons platform=windows target=template_debug
#   scons platform=windows target=template_release
#   scons platform=web threads=no target=template_release   (needs the Emscripten SDK on PATH)
#
# godot-cpp master ships extension_api files only up to 4.7, so against a 4.8 build pass the API
# dumped from the engine you actually run:
#   godot --headless --dump-extension-api
#   scons platform=windows target=template_debug custom_api_file=extension_api.json
import os

env = SConscript("godot-cpp/SConstruct")

env.Append(CPPPATH=["src/", "addons/godot_alleycat_gdextension/thirdparty/"])
# The library is C (alley_cat_impl.c holds the interpreter); the node is C++.
sources = Glob("src/*.cpp") + Glob("src/*.c")

if env["platform"] == "macos":
    library = env.SharedLibrary(
        "addons/godot_alleycat_gdextension/bin/liballey_cat.{}.{}.framework/liballey_cat.{}.{}".format(
            env["platform"], env["target"], env["platform"], env["target"]
        ),
        source=sources,
    )
else:
    library = env.SharedLibrary(
        "addons/godot_alleycat_gdextension/bin/liballey_cat{}{}".format(env["suffix"], env["SHLIBSUFFIX"]),
        source=sources,
    )

Default(library)

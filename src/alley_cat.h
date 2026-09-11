#pragma once

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/input_event.hpp>
#include <godot_cpp/classes/texture_rect.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

namespace godot {

// Runs Alley Cat (PureAlleyCat) in-process and shows its 320x200 frame as this TextureRect's
// texture. Feed it input events, the way a SubViewport's push_input reaches _input.
//
// The game is not distributed with this addon: point exe_path at your own copy of CAT.EXE. The
// file holds both the code and all of the artwork, so it is the only asset needed.
//
// PureAlleyCat keeps one machine per process, so only one AlleyCat node can run at a time.
class AlleyCat : public TextureRect {
	GDCLASS(AlleyCat, TextureRect)

	static const int FRAME_WIDTH = 320;
	static const int FRAME_HEIGHT = 200;
	// The game's own clock is the BIOS tick, and the library counts instructions rather than
	// seconds so that runs are reproducible. This is the conversion back to wall time.
	static const int INSTRUCTIONS_PER_TICK = 6000;
	static constexpr double TICKS_PER_SECOND = 18.2;

	String exe_path = "res://addons/godot_alleycat_gdextension/assets/CAT.EXE";
	bool autostart = true;
	double speed = 1.0;

	bool loaded = false;
	bool running = false;
	double pending_instructions = 0.0;

	PackedByteArray pixels; // RGBA8, FRAME_WIDTH * FRAME_HEIGHT * 4
	Ref<Image> image;
	Ref<ImageTexture> texture;

	void present_frame();
	void handle_key(const Ref<InputEvent> &event);

protected:
	static void _bind_methods();

public:
	AlleyCat();

	void _ready() override;
	void _process(double delta) override;
	void _input(const Ref<InputEvent> &event) override;

	// Reads exe_path and resets the machine. Emits loaded or load_failed.
	bool load_game();
	void start();
	void stop();
	bool is_running() const;
	bool is_loaded() const;
	// Non-zero once the game has set a graphics mode, so a host can hold off drawing until then.
	bool is_ready() const;
	Ref<Image> get_frame() const;
	int64_t get_instructions() const;
	String get_status() const;

	void set_exe_path(const String &path);
	String get_exe_path() const;
	void set_autostart(bool value);
	bool get_autostart() const;
	void set_speed(double value);
	double get_speed() const;
};

} // namespace godot

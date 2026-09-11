#pragma once

#include <godot_cpp/classes/audio_stream_generator_playback.hpp>
#include <godot_cpp/classes/audio_stream_player.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/texture_rect.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

namespace godot {

// Runs Alley Cat (PureAlleyCat) in-process and shows its 320x200 frame as this TextureRect's
// texture.
//
// Input is InputMap actions and nothing else: the node listens for the actions in
// get_expected_inputs() and has no opinion about which key or button fires them. A project binds
// them itself, or lets the controls addon do it; a project that binds none of them has a game that
// cannot be played, which is why get_missing_inputs() exists to say so.
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
	// Whether to tell the game there is a game adapter, which is what its own check looks for
	// before it will read the port at all. Turning it off is how a host says "keyboard only":
	// the game then refuses the joystick question and there is nothing to explain.
	bool joystick = true;
	// How far a stick has to be pushed to count. The game resolves three positions out of an
	// axis, so anything past this is simply "that way".
	static constexpr float STICK_THRESHOLD = 0.5f;
	// The PC speaker had no volume control, and a bare square wave at full scale is
	// unpleasant, so the host picks an amplitude.
	double volume = 0.12;

	bool loaded = false;
	bool running = false;
	double pending_instructions = 0.0;

	// Must match alleycat_audio_rate(), or every tone comes out at the wrong pitch.
	static const int MIX_RATE = 22050;
	AudioStreamPlayer *speaker = nullptr;
	Ref<AudioStreamGeneratorPlayback> playback;
	double phase = 0.0; // carried between frames so the square wave stays continuous

	PackedByteArray pixels; // RGBA8, FRAME_WIDTH * FRAME_HEIGHT * 4
	Ref<Image> image;
	Ref<ImageTexture> texture;

	enum { AXIS_NONE = 0, AXIS_X = 1, AXIS_Y = 2 };

	// One thing the game answers to: the action a host binds to it, the scancodes it sends, and
	// what it does to the emulated game port. See INPUTS in the .cpp for the table itself.
	struct GameInput {
		const char *action;
		int scancodes[2]; // a chord sends both, in order; 0 ends the list
		int axis;
		int direction;
		int port_button;
	};
	static const GameInput INPUTS[];
	static const int INPUT_COUNT;

	// Which of them are held. The game port holds a position rather than reporting changes, so the
	// held set is what push_joystick adds up every frame.
	bool input_held[32] = {};
	bool pad_button_1 = false;
	bool pad_button_2 = false;
	// The last position handed to the port, kept so a host - and the tests - can see what the node
	// is sending without having to read it back out of the game's pixels.
	int sent_x = 0;
	int sent_y = 0;

	void present_frame();
	void mix_audio();
	void read_inputs();
	void set_input_held(int index, bool held);
	void push_joystick();

protected:
	static void _bind_methods();

public:
	AlleyCat();

	void _ready() override;
	void _process(double delta) override;

	// Reads exe_path and resets the machine. Emits loaded or load_failed.
	bool load_game();
	void start();
	void stop();
	bool is_running() const;
	bool is_loaded() const;
	// Non-zero once the game has set a graphics mode, so a host can hold off drawing until then.
	bool is_ready() const;
	Ref<Image> get_frame() const;
	// The BIOS text screen. The game prints its setup questions through teletype rather
	// than drawing them, so a host that ignores this shows the player a blank screen.
	String get_text() const;
	// Non-zero framebuffer bytes. The game blanks the screen to ask a question and paints
	// it while playing, so a host uses this to decide whether to overlay get_text().
	int get_screen_painted() const;
	// The tone the game has programmed, and whether the gate is open.
	int get_speaker_hz() const;
	bool is_speaker_on() const;
	// Samples generated but not yet drained. Should hover near zero; a climbing figure
	// means the host is not draining fast enough and audio will start dropping.
	int get_audio_available() const;
	// What the held inputs are telling the game port right now: "x" and "y" are -1, 0 or 1, and
	// "button_1" and "button_2" are pressed or not.
	Dictionary get_joystick_state() const;
	// Every action this node listens for. Nothing else reaches the game, so a host binds these and
	// an editor can offer them as a list to pick from.
	static PackedStringArray get_expected_inputs();

	void set_volume(double value);
	double get_volume() const;
	int64_t get_instructions() const;
	String get_status() const;

	void set_exe_path(const String &path);
	String get_exe_path() const;
	void set_autostart(bool value);
	bool get_autostart() const;
	void set_speed(double value);
	double get_speed() const;
	void set_joystick(bool value);
	bool get_joystick() const;
	// The expected inputs no one has registered, so a host can say what is unbound rather than
	// leaving the player with a game that does not answer.
	PackedStringArray get_missing_inputs() const;
};

} // namespace godot

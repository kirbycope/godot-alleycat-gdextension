#pragma once

#include <godot_cpp/classes/audio_stream_generator_playback.hpp>
#include <godot_cpp/classes/audio_stream_player.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/texture_rect.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/typed_array.hpp>
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

	bool tick_completed = true; // Whether the game finished a tick, so the sprite report starts afresh.
	bool reports_sprites = false; // Whether every sprite the game draws is reported; see set_reports_sprites.
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

	// Rewind. Snapshots are whole copies of the machine taken at the game's own tick rate, kept in a
	// ring; going back is loading one, which is why it is exact rather than approximate. A megabyte
	// a snapshot sounds heavy and is nothing next to what the machine running it has.
	double music_volume = 1.0;
	double effects_volume = 1.0;
	double rewind_seconds = 6.0;
	bool rewinding = false;
	PackedByteArray snapshots;        // capacity * snapshot_size, oldest to newest in ring order
	int64_t snapshot_size = 0;
	int snapshot_capacity = 0;
	int snapshot_count = 0;           // how many of them are filled
	int snapshot_next = 0;            // where the next one goes
	double instructions_since_snapshot = 0.0;

	void size_the_ring();
	void take_snapshot();
	bool step_back();

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
	String get_printed_text() const;
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

	// The game drives one speaker from two places - a music player walking a note table, and the
	// routines that make its effects - and because there is only one speaker they interrupt each
	// other rather than mixing. These scale whichever is sounding, so a host can silence the music
	// and put its own on while the effects carry on.
	void set_music_volume(double value);
	double get_music_volume() const;
	void set_effects_volume(double value);
	double get_effects_volume() const;

	// Which of the two is sounding right now: 0 none, 1 music, 2 effects.
	int get_voice() const;
	int get_effect_starts() const;
	int get_video_writes() const;
	PackedByteArray peek(int at, int length) const;
	int peek_u8(int at) const;
	int peek_u16(int at) const;
	int get_load_address() const;
	int get_data_address() const;
	Dictionary get_machine_state() const;
	void set_hidden_sprites(const PackedInt32Array &sources);
	int poke(int at, const PackedByteArray &bytes);
	void set_reports_sprites(bool value);
	bool get_reports_sprites() const;
	TypedArray<Dictionary> get_sprites() const;
	void watch(int from, int to);
	PackedInt32Array get_watch_writers() const;
	int get_watch_hits() const;
	PackedInt32Array get_watch_callers() const;

	// How many seconds of rewind to keep. Zero turns it off and frees the ring, which is what a web
	// export wants; the memory is one megabyte per snapshot at 18.2 of them a second.
	void set_rewind_seconds(double value);
	double get_rewind_seconds() const;

	// While this is on the machine runs backwards instead of forwards, one snapshot a frame, and
	// stops at the oldest one it still has.
	void set_rewinding(bool value);
	bool get_rewinding() const;

	// How much is actually stored, in snapshots and in seconds, so a host can show it.
	int get_rewind_depth() const;
	double get_rewind_available() const;
};

} // namespace godot

#include "alley_cat.h"

#include "PureAlleyCat.h"

#include <godot_cpp/classes/audio_stream_generator.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/classes/input_map.hpp>
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void AlleyCat::_bind_methods() {
	ClassDB::bind_method(D_METHOD("load_game"), &AlleyCat::load_game);
	ClassDB::bind_method(D_METHOD("start"), &AlleyCat::start);
	ClassDB::bind_method(D_METHOD("stop"), &AlleyCat::stop);
	ClassDB::bind_method(D_METHOD("is_running"), &AlleyCat::is_running);
	ClassDB::bind_method(D_METHOD("is_loaded"), &AlleyCat::is_loaded);
	ClassDB::bind_method(D_METHOD("is_ready"), &AlleyCat::is_ready);
	ClassDB::bind_method(D_METHOD("get_frame"), &AlleyCat::get_frame);
	ClassDB::bind_method(D_METHOD("get_text"), &AlleyCat::get_text);
	ClassDB::bind_method(D_METHOD("get_screen_painted"), &AlleyCat::get_screen_painted);
	ClassDB::bind_method(D_METHOD("get_speaker_hz"), &AlleyCat::get_speaker_hz);
	ClassDB::bind_method(D_METHOD("is_speaker_on"), &AlleyCat::is_speaker_on);
	ClassDB::bind_method(D_METHOD("get_audio_available"), &AlleyCat::get_audio_available);
	ClassDB::bind_method(D_METHOD("get_joystick_state"), &AlleyCat::get_joystick_state);
	ClassDB::bind_static_method("AlleyCat", D_METHOD("get_expected_inputs"), &AlleyCat::get_expected_inputs);
	ClassDB::bind_method(D_METHOD("get_missing_inputs"), &AlleyCat::get_missing_inputs);
	ClassDB::bind_method(D_METHOD("set_volume", "value"), &AlleyCat::set_volume);
	ClassDB::bind_method(D_METHOD("get_volume"), &AlleyCat::get_volume);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "volume", PROPERTY_HINT_RANGE, "0.0,1.0,0.01"),
			"set_volume", "get_volume");
	ClassDB::bind_method(D_METHOD("get_instructions"), &AlleyCat::get_instructions);
	ClassDB::bind_method(D_METHOD("get_status"), &AlleyCat::get_status);

	ClassDB::bind_method(D_METHOD("set_exe_path", "path"), &AlleyCat::set_exe_path);
	ClassDB::bind_method(D_METHOD("get_exe_path"), &AlleyCat::get_exe_path);
	ADD_PROPERTY(PropertyInfo(Variant::STRING, "exe_path", PROPERTY_HINT_FILE, "*.EXE,*.exe"),
			"set_exe_path", "get_exe_path");

	ClassDB::bind_method(D_METHOD("set_autostart", "value"), &AlleyCat::set_autostart);
	ClassDB::bind_method(D_METHOD("get_autostart"), &AlleyCat::get_autostart);
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "autostart"), "set_autostart", "get_autostart");

	ClassDB::bind_method(D_METHOD("set_speed", "value"), &AlleyCat::set_speed);
	ClassDB::bind_method(D_METHOD("get_speed"), &AlleyCat::get_speed);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "speed", PROPERTY_HINT_RANGE, "0.1,4.0,0.1"),
			"set_speed", "get_speed");

	ClassDB::bind_method(D_METHOD("set_joystick", "value"), &AlleyCat::set_joystick);
	ClassDB::bind_method(D_METHOD("get_joystick"), &AlleyCat::get_joystick);
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "joystick"), "set_joystick", "get_joystick");

	ADD_SIGNAL(MethodInfo("loaded"));
	ADD_SIGNAL(MethodInfo("load_failed", PropertyInfo(Variant::STRING, "reason")));
}

AlleyCat::AlleyCat() {
	pixels.resize(FRAME_WIDTH * FRAME_HEIGHT * 4);
}

void AlleyCat::_ready() {
	image = Image::create_empty(FRAME_WIDTH, FRAME_HEIGHT, false, Image::FORMAT_RGBA8);
	texture = ImageTexture::create_from_image(image);
	set_texture(texture);
	// The frame is 320x200 of chunky pixels; smoothing it looks wrong.
	set_texture_filter(CanvasItem::TEXTURE_FILTER_NEAREST);

	// The PC speaker is one square wave, so a generator the node fills itself is the whole of it.
	speaker = memnew(AudioStreamPlayer);
	add_child(speaker);
	Ref<AudioStreamGenerator> generator;
	generator.instantiate();
	generator->set_mix_rate(MIX_RATE);
	generator->set_buffer_length(0.08);
	speaker->set_stream(generator);
	speaker->play();
	playback = speaker->get_stream_playback();

	if (autostart && !Engine::get_singleton()->is_editor_hint()) {
		if (load_game()) {
			start();
		}
	}
	set_process(true);

}

bool AlleyCat::load_game() {
	loaded = false;
	running = false;

	if (exe_path.is_empty()) {
		emit_signal("load_failed", "No exe_path set.");
		return false;
	}
	if (!FileAccess::file_exists(exe_path)) {
		emit_signal("load_failed",
				vformat("%s not found. Alley Cat is not distributed with this addon; copy your "
						"own CAT.EXE there.", exe_path));
		return false;
	}

	// The game reads the BIOS equipment list once, during startup, and will not touch the game
	// port unless bit 12 is set there, so this has to be said before the machine is reset. It is
	// claimed whether or not a pad is plugged in at this moment, because a pad connected later
	// would otherwise find the answer already given, and because the keyboard drives the port
	// too.
	alleycat_joystick_present(joystick ? 1 : 0);

	PackedByteArray bytes = FileAccess::get_file_as_bytes(exe_path);
	if (bytes.size() < 32) {
		emit_signal("load_failed", vformat("%s is too small to be an executable.", exe_path));
		return false;
	}
	if (alleycat_init(bytes.ptr(), (int)bytes.size()) != 0) {
		emit_signal("load_failed", vformat("%s is not an MZ executable.", exe_path));
		return false;
	}

	loaded = true;
	pending_instructions = 0.0;
	emit_signal("loaded");
	return true;
}

void AlleyCat::start() {
	if (loaded) {
		running = true;
	}
}

void AlleyCat::stop() {
	running = false;
}

void AlleyCat::_process(double delta) {
	if (!running) {
		return;
	}
	// The game port holds a position rather than reporting changes, so what is held goes in before
	// the machine gets a chance to sample it.
	read_inputs();
	push_joystick();
	// Run the number of instructions that much wall time is worth, keeping the fraction so a
	// long frame does not quietly lose time.
	pending_instructions += delta * TICKS_PER_SECOND * INSTRUCTIONS_PER_TICK * speed;
	int budget = (int)pending_instructions;
	if (budget > 0) {
		pending_instructions -= budget;
		alleycat_run(budget);
	}
	present_frame();
	mix_audio();
}

// Drains the audio the library generated while it was running instructions. It is produced
// inside the instruction loop at AUDIO_RATE, so a tone lasting less than a frame is still in
// there; sampling the speaker once per frame from out here would miss most of them.
void AlleyCat::mix_audio() {
	if (playback.is_null()) {
		return;
	}
	int room = playback->get_frames_available();
	if (room <= 0) {
		return;
	}
	static int16_t samples[4096];
	int want = room < 4096 ? room : 4096;
	int got = alleycat_audio_read(samples, want);
	if (got <= 0) {
		return;
	}
	PackedVector2Array buffer;
	buffer.resize(got);
	Vector2 *out = buffer.ptrw();
	for (int i = 0; i < got; i++) {
		float sample = (float)(samples[i] / 32768.0 * volume);
		out[i] = Vector2(sample, sample);
	}
	playback->push_buffer(buffer);
}

void AlleyCat::present_frame() {
	const uint8_t *frame = alleycat_framebuffer();
	uint32_t palette[4];
	alleycat_palette(palette);

	uint8_t *out = pixels.ptrw();
	for (int i = 0; i < FRAME_WIDTH * FRAME_HEIGHT; i++) {
		uint32_t rgb = palette[frame[i] & 3];
		out[i * 4 + 0] = (uint8_t)((rgb >> 16) & 0xFF);
		out[i * 4 + 1] = (uint8_t)((rgb >> 8) & 0xFF);
		out[i * 4 + 2] = (uint8_t)(rgb & 0xFF);
		out[i * 4 + 3] = 255;
	}
	image->set_data(FRAME_WIDTH, FRAME_HEIGHT, false, Image::FORMAT_RGBA8, pixels);
	texture->update(image);
}

// What the game answers to, and nothing else reaches it. Each entry is one action a host binds
// however it likes; the scancodes are IBM PC set-1 make codes, which is what the game's own INT 9
// handler reads from port 0x60, and axis and button are the emulated game port.
//
// This table is the whole mapping. A host that wants a different button on a different thing rebinds
// the action - in the controls addon's inspector, or in its own project.godot - and nothing here
// changes. get_expected_inputs() hands the list out so an editor can offer it as a choice.
const AlleyCat::GameInput AlleyCat::INPUTS[] = {
	{ "alleycat_up", { 0x48, 0 }, AXIS_Y, -1, 0 },
	{ "alleycat_down", { 0x50, 0 }, AXIS_Y, 1, 0 },
	{ "alleycat_left", { 0x4B, 0 }, AXIS_X, -1, 0 },
	{ "alleycat_right", { 0x4D, 0 }, AXIS_X, 1, 0 },
	// Alt is the game's action key and the joystick button at once: the setup's last question asks
	// for the button, and the game reads one or the other depending on how the first was answered.
	{ "alleycat_alt", { ALLEYCAT_KEY_ALT, 0 }, AXIS_NONE, 0, 1 },
	{ "alleycat_button_2", { 0, 0 }, AXIS_NONE, 0, 2 },
	{ "alleycat_esc", { ALLEYCAT_KEY_ESC, 0 }, AXIS_NONE, 0, 0 },
	// The three chords the game prints on its own setup screen.
	{ "alleycat_sound", { ALLEYCAT_KEY_CTRL, ALLEYCAT_KEY_S }, AXIS_NONE, 0, 0 },
	{ "alleycat_restart", { ALLEYCAT_KEY_CTRL, 0x13 }, AXIS_NONE, 0, 0 },
	{ "alleycat_menu", { ALLEYCAT_KEY_CTRL, ALLEYCAT_KEY_M }, AXIS_NONE, 0, 0 },
	// The setup answers. The game asks them in text, so a pad needs a button on each or the player
	// is stuck at a question with nothing that answers it.
	{ "alleycat_yes", { ALLEYCAT_KEY_Y, 0 }, AXIS_NONE, 0, 0 },
	{ "alleycat_no", { ALLEYCAT_KEY_N, 0 }, AXIS_NONE, 0, 0 },
	{ "alleycat_kitten", { 0x25, 0 }, AXIS_NONE, 0, 0 },
	{ "alleycat_house_cat", { 0x23, 0 }, AXIS_NONE, 0, 0 },
	{ "alleycat_tomcat", { 0x14, 0 }, AXIS_NONE, 0, 0 },
	{ "alleycat_alley_cat", { 0x1E, 0 }, AXIS_NONE, 0, 0 },
};

const int AlleyCat::INPUT_COUNT = (int)(sizeof(AlleyCat::INPUTS) / sizeof(AlleyCat::INPUTS[0]));

PackedStringArray AlleyCat::get_expected_inputs() {
	PackedStringArray out;
	for (int i = 0; i < INPUT_COUNT; i++) {
		out.push_back(INPUTS[i].action);
	}
	return out;
}

// Reads every action the game answers to and holds the result. Polled rather than listened for,
// because Godot's VirtualJoystick presses its actions straight into the input state without ever
// sending an event, so a touch stick would be silent to _input. Polling catches the pad, the
// keyboard and the on-screen stick through one path, and the game port wants a level anyway.
void AlleyCat::read_inputs() {
	Input *input = Input::get_singleton();
	InputMap *map = InputMap::get_singleton();
	for (int i = 0; i < INPUT_COUNT; i++) {
		const StringName action(INPUTS[i].action);
		// A host that has not registered an action simply has that input unbound; asking the
		// InputMap about one it does not know is an error, not an answer.
		set_input_held(i, map->has_action(action) && input->is_action_pressed(action));
	}
}

// Presses or releases one of the game's inputs. A chord goes down in order and comes up in reverse,
// the way a hand does it, because the game reads make and break codes rather than a key state.
void AlleyCat::set_input_held(int index, bool held) {
	if (held == input_held[index]) {
		return;
	}
	input_held[index] = held;
	const int *codes = INPUTS[index].scancodes;
	if (held) {
		for (int i = 0; i < 2 && codes[i]; i++) {
			alleycat_key(codes[i], 1);
		}
	} else {
		for (int i = 1; i >= 0; i--) {
			if (codes[i]) {
				alleycat_key(codes[i], 0);
			}
		}
	}
}

// Hands the game port the position the held inputs add up to. The port holds a position rather than
// reporting changes, so the game samples it whenever it likes and this runs every frame.
void AlleyCat::push_joystick() {
	int x = 0;
	int y = 0;
	bool button_1 = false;
	bool button_2 = false;
	for (int i = 0; i < INPUT_COUNT; i++) {
		if (!input_held[i]) {
			continue;
		}
		if (INPUTS[i].axis == AXIS_X) {
			x += INPUTS[i].direction;
		} else if (INPUTS[i].axis == AXIS_Y) {
			y += INPUTS[i].direction;
		}
		if (INPUTS[i].port_button == 1) {
			button_1 = true;
		} else if (INPUTS[i].port_button == 2) {
			button_2 = true;
		}
	}
	// Holding both ways at once is a centred stick, not a doubled one.
	sent_x = x < 0 ? -1 : (x > 0 ? 1 : 0);
	sent_y = y < 0 ? -1 : (y > 0 ? 1 : 0);
	pad_button_1 = button_1;
	pad_button_2 = button_2;
	alleycat_joystick(sent_x, sent_y, button_1 ? 1 : 0, button_2 ? 1 : 0);
}


bool AlleyCat::is_running() const { return running; }
bool AlleyCat::is_loaded() const { return loaded; }
bool AlleyCat::is_ready() const { return loaded && alleycat_ready() != 0; }
Ref<Image> AlleyCat::get_frame() const { return image; }

String AlleyCat::get_text() const {
	String out;
	for (int row = 0; row < alleycat_text_rows(); row++) {
		String line = String(alleycat_text_row(row)).strip_edges(false, true);
		if (!line.is_empty()) {
			out += line + "\n";
		}
	}
	return out;
}
int AlleyCat::get_screen_painted() const { return alleycat_screen_painted(); }
int AlleyCat::get_speaker_hz() const { return alleycat_speaker_hz(); }
bool AlleyCat::is_speaker_on() const { return alleycat_speaker_on() != 0; }
int AlleyCat::get_audio_available() const { return alleycat_audio_available(); }
Dictionary AlleyCat::get_joystick_state() const {
	Dictionary state;
	state["x"] = sent_x;
	state["y"] = sent_y;
	state["button_1"] = pad_button_1;
	state["button_2"] = pad_button_2;
	return state;
}

PackedStringArray AlleyCat::get_missing_inputs() const {
	PackedStringArray missing;
	InputMap *map = InputMap::get_singleton();
	for (int i = 0; i < INPUT_COUNT; i++) {
		const StringName action(INPUTS[i].action);
		if (!map->has_action(action)) {
			missing.push_back(INPUTS[i].action);
		}
	}
	return missing;
}
void AlleyCat::set_volume(double value) { volume = value; }
double AlleyCat::get_volume() const { return volume; }
int64_t AlleyCat::get_instructions() const { return (int64_t)alleycat_instructions(); }
String AlleyCat::get_status() const { return String(alleycat_status()); }

void AlleyCat::set_exe_path(const String &path) { exe_path = path; }
String AlleyCat::get_exe_path() const { return exe_path; }
void AlleyCat::set_autostart(bool value) { autostart = value; }
bool AlleyCat::get_autostart() const { return autostart; }
void AlleyCat::set_speed(double value) { speed = value; }
double AlleyCat::get_speed() const { return speed; }
void AlleyCat::set_joystick(bool value) {
	joystick = value;
	alleycat_joystick_present(joystick ? 1 : 0);
}
bool AlleyCat::get_joystick() const { return joystick; }

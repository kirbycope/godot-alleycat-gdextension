#include "alley_cat.h"

#include "PureAlleyCat.h"

#include <godot_cpp/classes/audio_stream_generator.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/input_event_joypad_button.hpp>
#include <godot_cpp/classes/input_event_joypad_motion.hpp>
#include <godot_cpp/classes/input_event_key.hpp>
#include <godot_cpp/classes/viewport.hpp>
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
	set_process_input(true);
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
	// The game port holds a position rather than reporting changes, so the pad's current state
	// goes in before the machine gets a chance to sample it.
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

void AlleyCat::_input(const Ref<InputEvent> &event) {
	if (!running) {
		return;
	}
	handle_key(event);
	handle_joypad(event);
}

void AlleyCat::handle_key(const Ref<InputEvent> &event) {
	Ref<InputEventKey> key = event;
	if (key.is_null() || key->is_echo()) {
		return;
	}

	// Map the whole keyboard, not a chosen few. The setup asks for Y/N and then K, H, T or A for
	// the skill level, and a hand-picked list of "the keys the game uses" silently loses whichever
	// one was overlooked. These are IBM PC set-1 make codes, which is what the game's own INT 9
	// handler reads from port 0x60.
	static const struct { Key key; int code; } SCANCODES[] = {
		{ KEY_ESCAPE, 0x01 }, { KEY_1, 0x02 }, { KEY_2, 0x03 }, { KEY_3, 0x04 },
		{ KEY_4, 0x05 }, { KEY_5, 0x06 }, { KEY_6, 0x07 }, { KEY_7, 0x08 },
		{ KEY_8, 0x09 }, { KEY_9, 0x0A }, { KEY_0, 0x0B }, { KEY_MINUS, 0x0C },
		{ KEY_EQUAL, 0x0D }, { KEY_BACKSPACE, 0x0E }, { KEY_TAB, 0x0F },
		{ KEY_Q, 0x10 }, { KEY_W, 0x11 }, { KEY_E, 0x12 }, { KEY_R, 0x13 },
		{ KEY_T, 0x14 }, { KEY_Y, 0x15 }, { KEY_U, 0x16 }, { KEY_I, 0x17 },
		{ KEY_O, 0x18 }, { KEY_P, 0x19 }, { KEY_ENTER, 0x1C }, { KEY_CTRL, 0x1D },
		{ KEY_A, 0x1E }, { KEY_S, 0x1F }, { KEY_D, 0x20 }, { KEY_F, 0x21 },
		{ KEY_G, 0x22 }, { KEY_H, 0x23 }, { KEY_J, 0x24 }, { KEY_K, 0x25 },
		{ KEY_L, 0x26 }, { KEY_SHIFT, 0x2A }, { KEY_Z, 0x2C }, { KEY_X, 0x2D },
		{ KEY_C, 0x2E }, { KEY_V, 0x2F }, { KEY_B, 0x30 }, { KEY_N, 0x31 },
		{ KEY_M, 0x32 }, { KEY_COMMA, 0x33 }, { KEY_PERIOD, 0x34 }, { KEY_SLASH, 0x35 },
		{ KEY_ALT, 0x38 }, { KEY_SPACE, 0x39 },
		{ KEY_UP, 0x48 }, { KEY_LEFT, 0x4B }, { KEY_RIGHT, 0x4D }, { KEY_DOWN, 0x50 },
	};
	int scancode = 0;
	Key keycode = key->get_keycode();
	for (unsigned i = 0; i < sizeof(SCANCODES) / sizeof(SCANCODES[0]); i++) {
		if (SCANCODES[i].key == keycode) {
			scancode = SCANCODES[i].code;
			break;
		}
	}
	if (scancode == 0) {
		return;
	}
	const bool pressed = key->is_pressed();
	// The same keys drive the emulated game port, so answering yes to the joystick question and
	// then reaching for the keyboard works. push_joystick reads these.
	switch (scancode) {
		case ALLEYCAT_KEY_LEFT: key_x = pressed ? -1 : 0; break;
		case ALLEYCAT_KEY_RIGHT: key_x = pressed ? 1 : 0; break;
		case ALLEYCAT_KEY_UP: key_y = pressed ? -1 : 0; break;
		case ALLEYCAT_KEY_DOWN: key_y = pressed ? 1 : 0; break;
		case ALLEYCAT_KEY_ALT: key_action = pressed; break;
		default: break;
	}

	alleycat_key(scancode, pressed ? 1 : 0);
	get_viewport()->set_input_as_handled();
}

// A face button means different things on the two screens the game has. During setup it wants a
// letter, and a pad has none; while playing it wants the game port and Alt. Each setup button
// sends both of the letters it could mean at once - the joystick question answers to Y or N and
// the skill menu to K, H, T or A, and each ignores anything else - so no state has to be kept.
void AlleyCat::press_pad_button(int button, bool pressed) {
	const int down = pressed ? 1 : 0;
	// The game blanks the graphics screen to ask a question and paints it to play, which is the
	// same test the demo uses to decide whether to show the text rows over the top.
	const bool setting_up = alleycat_screen_painted() < 512;
	switch (button) {
		case JOY_BUTTON_A:
			if (setting_up) {
				alleycat_key(ALLEYCAT_KEY_Y, down);  // yes, a joystick
				alleycat_key(0x25, down);            // K: Kitten
			} else {
				pad_button_1 = pressed;
				alleycat_key(ALLEYCAT_KEY_ALT, down);
			}
			break;
		case JOY_BUTTON_B:
			if (setting_up) {
				alleycat_key(ALLEYCAT_KEY_N, down);  // no joystick
				alleycat_key(0x23, down);            // H: House Cat
			} else {
				pad_button_2 = pressed;
			}
			break;
		case JOY_BUTTON_X:
			if (setting_up) {
				alleycat_key(0x14, down);            // T: Tomcat
			}
			break;
		case JOY_BUTTON_Y:
			if (setting_up) {
				alleycat_key(0x1E, down);            // A: Alley Cat
			}
			break;
		case JOY_BUTTON_BACK:
			alleycat_key(ALLEYCAT_KEY_ESC, down);    // paws mode
			break;
		case JOY_BUTTON_START:                       // Ctrl-M: back to the menu
			alleycat_key(ALLEYCAT_KEY_CTRL, down);
			alleycat_key(ALLEYCAT_KEY_M, down);
			break;
		default:
			break;
	}
}

void AlleyCat::handle_joypad(const Ref<InputEvent> &event) {
	Ref<InputEventJoypadButton> button = event;
	if (button.is_valid()) {
		const bool pressed = button->is_pressed();
		switch (button->get_button_index()) {
			case JOY_BUTTON_DPAD_UP: dpad_y = pressed ? -1 : 0; break;
			case JOY_BUTTON_DPAD_DOWN: dpad_y = pressed ? 1 : 0; break;
			case JOY_BUTTON_DPAD_LEFT: dpad_x = pressed ? -1 : 0; break;
			case JOY_BUTTON_DPAD_RIGHT: dpad_x = pressed ? 1 : 0; break;
			default: press_pad_button(button->get_button_index(), pressed); break;
		}
		get_viewport()->set_input_as_handled();
		return;
	}

	Ref<InputEventJoypadMotion> motion = event;
	if (motion.is_valid()) {
		// Only the left stick steers. Alley Cat has one stick's worth of controls, and reading
		// the right one as well would fight it.
		switch (motion->get_axis()) {
			case JOY_AXIS_LEFT_X: stick_x = motion->get_axis_value(); break;
			case JOY_AXIS_LEFT_Y: stick_y = motion->get_axis_value(); break;
			default: break;
		}
	}
}

// Hands the pad's current state to the library. The stick goes to the emulated game port and to
// the arrow keys at the same time: the game reads one or the other depending on how the setup
// question was answered, and they are exclusive inside the game, so feeding both means the pad
// works either way round.
void AlleyCat::push_joystick() {
	// What the pad alone is saying: the d-pad wins over the stick, because a player using both
	// means the d-pad.
	const int pad_x = dpad_x != 0 ? dpad_x
			: (stick_x < -STICK_THRESHOLD ? -1 : (stick_x > STICK_THRESHOLD ? 1 : 0));
	const int pad_y = dpad_y != 0 ? dpad_y
			: (stick_y < -STICK_THRESHOLD ? -1 : (stick_y > STICK_THRESHOLD ? 1 : 0));

	// The port gets the pad, or the arrow keys when the pad is idle.
	alleycat_joystick(pad_x != 0 ? pad_x : key_x, pad_y != 0 ? pad_y : key_y,
			(pad_button_1 || key_action) ? 1 : 0, pad_button_2 ? 1 : 0);

	// And the pad's direction also goes out as arrow keys, for a player who answered no to the
	// joystick question. Only the pad's own direction: a real arrow key is already on its way
	// through handle_key, and sending it twice would leave the game holding a key that is up.
	if (pad_x != sent_key_x) {
		if (sent_key_x != 0) {
			alleycat_key(sent_key_x < 0 ? ALLEYCAT_KEY_LEFT : ALLEYCAT_KEY_RIGHT, 0);
		}
		if (pad_x != 0) {
			alleycat_key(pad_x < 0 ? ALLEYCAT_KEY_LEFT : ALLEYCAT_KEY_RIGHT, 1);
		}
		sent_key_x = pad_x;
	}
	if (pad_y != sent_key_y) {
		if (sent_key_y != 0) {
			alleycat_key(sent_key_y < 0 ? ALLEYCAT_KEY_UP : ALLEYCAT_KEY_DOWN, 0);
		}
		if (pad_y != 0) {
			alleycat_key(pad_y < 0 ? ALLEYCAT_KEY_UP : ALLEYCAT_KEY_DOWN, 1);
		}
		sent_key_y = pad_y;
	}
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

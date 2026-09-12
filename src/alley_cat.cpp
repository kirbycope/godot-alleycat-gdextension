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

	ClassDB::bind_method(D_METHOD("set_music_volume", "value"), &AlleyCat::set_music_volume);
	ClassDB::bind_method(D_METHOD("get_music_volume"), &AlleyCat::get_music_volume);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "music_volume", PROPERTY_HINT_RANGE, "0.0,1.0,0.01"),
			"set_music_volume", "get_music_volume");

	ClassDB::bind_method(D_METHOD("set_effects_volume", "value"), &AlleyCat::set_effects_volume);
	ClassDB::bind_method(D_METHOD("get_effects_volume"), &AlleyCat::get_effects_volume);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "effects_volume", PROPERTY_HINT_RANGE, "0.0,1.0,0.01"),
			"set_effects_volume", "get_effects_volume");

	ClassDB::bind_method(D_METHOD("get_voice"), &AlleyCat::get_voice);
	ClassDB::bind_method(D_METHOD("get_effect_starts"), &AlleyCat::get_effect_starts);
	ClassDB::bind_method(D_METHOD("get_video_writes"), &AlleyCat::get_video_writes);
	ClassDB::bind_method(D_METHOD("peek", "at", "length"), &AlleyCat::peek);
	ClassDB::bind_method(D_METHOD("peek_u8", "at"), &AlleyCat::peek_u8);
	ClassDB::bind_method(D_METHOD("peek_u16", "at"), &AlleyCat::peek_u16);
	ClassDB::bind_method(D_METHOD("get_load_address"), &AlleyCat::get_load_address);
	ClassDB::bind_method(D_METHOD("get_data_address"), &AlleyCat::get_data_address);
	ClassDB::bind_method(D_METHOD("get_machine_state"), &AlleyCat::get_machine_state);
	ClassDB::bind_method(D_METHOD("poke", "at", "bytes"), &AlleyCat::poke);
	ClassDB::bind_method(D_METHOD("set_reports_sprites", "value"), &AlleyCat::set_reports_sprites);
	ClassDB::bind_method(D_METHOD("get_reports_sprites"), &AlleyCat::get_reports_sprites);
	ClassDB::bind_method(D_METHOD("get_sprites"), &AlleyCat::get_sprites);
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "reports_sprites"), "set_reports_sprites", "get_reports_sprites");
	ClassDB::bind_method(D_METHOD("watch", "from", "to"), &AlleyCat::watch);
	ClassDB::bind_method(D_METHOD("get_watch_writers"), &AlleyCat::get_watch_writers);
	ClassDB::bind_method(D_METHOD("get_watch_hits"), &AlleyCat::get_watch_hits);
	ClassDB::bind_method(D_METHOD("get_watch_callers"), &AlleyCat::get_watch_callers);

	ClassDB::bind_method(D_METHOD("set_rewind_seconds", "value"), &AlleyCat::set_rewind_seconds);
	ClassDB::bind_method(D_METHOD("get_rewind_seconds"), &AlleyCat::get_rewind_seconds);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "rewind_seconds", PROPERTY_HINT_RANGE, "0.0,60.0,0.5"),
			"set_rewind_seconds", "get_rewind_seconds");

	ClassDB::bind_method(D_METHOD("set_rewinding", "value"), &AlleyCat::set_rewinding);
	ClassDB::bind_method(D_METHOD("get_rewinding"), &AlleyCat::get_rewinding);
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "rewinding"), "set_rewinding", "get_rewinding");

	ClassDB::bind_method(D_METHOD("get_rewind_depth"), &AlleyCat::get_rewind_depth);
	ClassDB::bind_method(D_METHOD("get_rewind_available"), &AlleyCat::get_rewind_available);

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
	// A fresh machine has no past, and the size of a snapshot is only known once the library is
	// built, so the ring is laid out here rather than in the constructor.
	size_the_ring();
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

	// Going back is not running the machine slowly in reverse - nothing can do that - it is putting
	// a whole earlier machine back. One snapshot a frame, which at 18.2 of them a second is about
	// three times real speed, and that is what a rewind should feel like.
	if (rewinding) {
		if (step_back()) {
			present_frame();
		}
		return;
	}

	// Run the number of instructions that much wall time is worth, keeping the fraction so a
	// long frame does not quietly lose time.
	pending_instructions += delta * TICKS_PER_SECOND * INSTRUCTIONS_PER_TICK * speed;
	int budget = (int)pending_instructions;
	if (budget > 0) {
		pending_instructions -= budget;
		// A fresh tick's worth of sprites, cleared on the game's own clock rather than the host's. A tick is
		// tens of thousands of instructions and the host asks for a few hundred at a time, so one tick's
		// drawing is spread across dozens of frames; clearing every frame would hand back a fragment of it
		// and leave anything drawing from the report flickering.
		if (reports_sprites && tick_completed) {
			alleycat_sprites_begin();
			tick_completed = false;
		}
		alleycat_run(budget);
		// Snapshot on the game's own clock rather than the host's, so how much history a second of
		// rewind buys does not depend on the frame rate of the machine it happens to run on.
		instructions_since_snapshot += budget;
		while (instructions_since_snapshot >= INSTRUCTIONS_PER_TICK) {
			instructions_since_snapshot -= INSTRUCTIONS_PER_TICK;
			tick_completed = true;
			take_snapshot();
		}
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

void AlleyCat::set_music_volume(double value) {
	music_volume = value < 0.0 ? 0.0 : value;
	alleycat_set_voice_volume(ALLEYCAT_VOICE_MUSIC, (float)music_volume);
}

double AlleyCat::get_music_volume() const { return music_volume; }

void AlleyCat::set_effects_volume(double value) {
	effects_volume = value < 0.0 ? 0.0 : value;
	alleycat_set_voice_volume(ALLEYCAT_VOICE_EFFECTS, (float)effects_volume);
}

double AlleyCat::get_effects_volume() const { return effects_volume; }

int AlleyCat::get_voice() const { return alleycat_voice(); }

// Sounds other than the music the game has begun since it booted. It only rises, so a host reads a change
// as "something just happened" without needing to know what happened.
int AlleyCat::get_effect_starts() const { return (int)alleycat_effect_starts(); }

// Bytes drawn into the CGA window since boot. The jump between two frames says how much of the screen the
// game just drew, which is how a whole new place is told from a sprite moving.
int AlleyCat::get_video_writes() const { return (int)alleycat_video_writes(); }

// The machine's memory. Alley Cat is one 1984 assembly program whose variables live at fixed addresses, so
// what it is thinking is in here, at a place that does not move between runs. Finding which place is a
// matter of watching what changes when something happens; these are the window to watch through.
PackedByteArray AlleyCat::peek(int at, int length) const {
	PackedByteArray out;
	if (at < 0 || length <= 0) {
		return out;
	}
	out.resize(length);
	int copied = alleycat_peek((unsigned int)at, out.ptrw(), (unsigned int)length);
	out.resize(copied < 0 ? 0 : copied);
	return out;
}

int AlleyCat::peek_u8(int at) const {
	unsigned char byte = 0;
	return alleycat_peek((unsigned int)at, &byte, 1) == 1 ? (int)byte : -1;
}

// Little-endian, the way the 8086 stores a word, so a counter reads as the number the game means.
int AlleyCat::peek_u16(int at) const {
	unsigned char bytes[2] = { 0, 0 };
	return alleycat_peek((unsigned int)at, bytes, 2) == 2 ? (int)(bytes[0] | (bytes[1] << 8)) : -1;
}

// Where the image was loaded, so an offset into CAT.EXE's own data becomes an address here.
int AlleyCat::get_load_address() const { return (int)(ALLEYCAT_LOAD_SEG << 4); }

// Where the machine is reading its variables from right now. A disassembly gives a variable as a bare offset
// like 0x1f82; this is what that offset is counted from, so the two together are an address peek can read.
int AlleyCat::get_data_address() const { return (int)alleycat_data_address(); }

// What the machine is doing, for working out why it has stopped answering. Memory alone cannot say: a game
// spinning with interrupts disabled and one running normally look identical from the outside, and a key is
// only handed to the game's INT 9 handler while interrupts are on.
Dictionary AlleyCat::get_machine_state() const {
	unsigned int at = 0;
	int interrupts = 0;
	int queued = 0;
	alleycat_where(&at, &interrupts, &queued);
	Dictionary out;
	out["image_offset"] = (int)at;
	out["interrupts_enabled"] = interrupts != 0;
	out["keys_queued"] = queued;
	return out;
}

// Writes into the machine's memory, and answers how many bytes went in. The other half of what carrying a
// high score across runs needs: one read out at the end of a game has to be put back at the start of the
// next. It writes where the game itself would, so it can corrupt the program as easily as set a score.
// Whether to report every sprite the game draws. Off by default and free when off: the check is on the call
// instruction, which is rare beside the millions of ordinary instructions a second the interpreter runs.
void AlleyCat::set_reports_sprites(bool value) {
	reports_sprites = value;
	alleycat_report_sprites(value ? 1 : 0);
}

bool AlleyCat::get_reports_sprites() const { return reports_sprites; }

// What the game drew this frame, in the order it drew it. Each entry says which artwork was copied, where it
// went, and how big it is - enough for a host to put its own picture in the same place instead.
//
// "at" is an offset into the CGA window, which is not a position: rows alternate between two banks 0x2000
// apart, and each byte is four pixels. The x and y here are worked back out of it, so a host does not have
// to know what a 1981 display adapter was thinking.
TypedArray<Dictionary> AlleyCat::get_sprites() const {
	TypedArray<Dictionary> out;
	int n = alleycat_sprite_count();
	for (int i = 0; i < n; i++) {
		unsigned int source = 0, at = 0, size = 0, kind = 0;
		if (!alleycat_sprite(i, &source, &at, &size, &kind)) {
			continue;
		}
		unsigned int bank = (at & 0x2000u) ? 1u : 0u;
		unsigned int offset = at & 0x1FFFu;
		Dictionary sprite;
		sprite["source"] = (int)source;
		sprite["at"] = (int)at;
		sprite["x"] = (int)((offset % 80u) * 4u);
		sprite["y"] = (int)((offset / 80u) * 2u + bank);
		// CL is how many words across, and a word is eight pixels; CH is how many rows down.
		sprite["width"] = (int)((size & 0xFFu) * 8u);
		sprite["height"] = (int)((size >> 8) & 0xFFu);
		sprite["masked"] = kind == ALLEYCAT_BLIT_MASKED;
		out.push_back(sprite);
	}
	return out;
}

int AlleyCat::poke(int at, const PackedByteArray &bytes) {
	if (at < 0 || bytes.is_empty()) {
		return 0;
	}
	return alleycat_poke((unsigned int)at, bytes.ptr(), (unsigned int)bytes.size());
}

// Watches a range of memory and remembers where the code that wrote to it was. This is how anything in the
// game gets found: a score, a life count or a sprite is a place in memory, and the way to that place is the
// routine that touches it. Point it at the few bytes of screen a number is drawn in, let the game draw, and
// what comes back are offsets into CAT.EXE that a disassembly explains.
void AlleyCat::watch(int from, int to) {
	alleycat_watch((unsigned int)(from < 0 ? 0 : from), (unsigned int)(to < 0 ? 0 : to));
}

PackedInt32Array AlleyCat::get_watch_writers() const {
	unsigned int found[ALLEYCAT_WATCH_MAX];
	int n = alleycat_watch_writers(found, ALLEYCAT_WATCH_MAX);
	PackedInt32Array out;
	out.resize(n);
	for (int i = 0; i < n; i++) {
		out.set(i, (int)found[i]);
	}
	return out;
}

int AlleyCat::get_watch_hits() const { return (int)alleycat_watch_hits(); }

// The routines that called the writers. Every sprite in the game goes through the same few blitters, so the
// writer says how something was drawn and only the caller says what.
PackedInt32Array AlleyCat::get_watch_callers() const {
	unsigned int found[ALLEYCAT_WATCH_MAX];
	int n = alleycat_watch_callers(found, ALLEYCAT_WATCH_MAX);
	PackedInt32Array out;
	out.resize(n);
	for (int i = 0; i < n; i++) {
		out.set(i, (int)found[i]);
	}
	return out;
}

// ---- rewind ---------------------------------------------------------------------------------

// Sizes the ring for the seconds asked for. Snapshots are taken at the game's tick rate, so the
// count is simply seconds times that. Resizing throws away what was stored: the alternative is
// shuffling a megabyte per entry to preserve history the player has not asked to keep.
void AlleyCat::size_the_ring() {
	snapshot_size = (int64_t)alleycat_state_size();
	snapshot_capacity = (int)(rewind_seconds * TICKS_PER_SECOND);
	if (snapshot_capacity < 1 || rewind_seconds <= 0.0) {
		snapshot_capacity = 0;
	}
	snapshots.resize(snapshot_capacity * snapshot_size);
	snapshot_count = 0;
	snapshot_next = 0;
	instructions_since_snapshot = 0.0;
}

void AlleyCat::take_snapshot() {
	if (snapshot_capacity == 0) {
		return;
	}
	alleycat_save_state(snapshots.ptrw() + (int64_t)snapshot_next * snapshot_size);
	snapshot_next = (snapshot_next + 1) % snapshot_capacity;
	if (snapshot_count < snapshot_capacity) {
		snapshot_count++;
	}
}

// Puts the most recent snapshot back and drops it, so holding the trigger walks backwards through
// them. Returns false once there is nothing older left, which is where a rewind stops.
bool AlleyCat::step_back() {
	if (snapshot_count == 0) {
		return false;
	}
	snapshot_next = (snapshot_next + snapshot_capacity - 1) % snapshot_capacity;
	snapshot_count--;
	alleycat_load_state(snapshots.ptr() + (int64_t)snapshot_next * snapshot_size);
	// The machine is now where it was, so the part-run instruction budget from the frame we are
	// leaving does not belong to it.
	pending_instructions = 0.0;
	instructions_since_snapshot = 0.0;
	return true;
}

void AlleyCat::set_rewind_seconds(double value) {
	rewind_seconds = value < 0.0 ? 0.0 : value;
	size_the_ring();
}

double AlleyCat::get_rewind_seconds() const { return rewind_seconds; }

void AlleyCat::set_rewinding(bool value) { rewinding = value; }
bool AlleyCat::get_rewinding() const { return rewinding; }

int AlleyCat::get_rewind_depth() const { return snapshot_count; }

double AlleyCat::get_rewind_available() const {
	return (double)snapshot_count / TICKS_PER_SECOND;
}

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

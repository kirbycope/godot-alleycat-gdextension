#include "alley_cat.h"

#include "PureAlleyCat.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/file_access.hpp>
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
	// Run the number of instructions that much wall time is worth, keeping the fraction so a
	// long frame does not quietly lose time.
	pending_instructions += delta * TICKS_PER_SECOND * INSTRUCTIONS_PER_TICK * speed;
	int budget = (int)pending_instructions;
	if (budget > 0) {
		pending_instructions -= budget;
		alleycat_run(budget);
	}
	present_frame();
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
	if (running) {
		handle_key(event);
	}
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
	Key pressed = key->get_keycode();
	for (unsigned i = 0; i < sizeof(SCANCODES) / sizeof(SCANCODES[0]); i++) {
		if (SCANCODES[i].key == pressed) {
			scancode = SCANCODES[i].code;
			break;
		}
	}
	if (scancode == 0) {
		return;
	}
	alleycat_key(scancode, key->is_pressed() ? 1 : 0);
	get_viewport()->set_input_as_handled();
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
int64_t AlleyCat::get_instructions() const { return (int64_t)alleycat_instructions(); }
String AlleyCat::get_status() const { return String(alleycat_status()); }

void AlleyCat::set_exe_path(const String &path) { exe_path = path; }
String AlleyCat::get_exe_path() const { return exe_path; }
void AlleyCat::set_autostart(bool value) { autostart = value; }
bool AlleyCat::get_autostart() const { return autostart; }
void AlleyCat::set_speed(double value) { speed = value; }
double AlleyCat::get_speed() const { return speed; }

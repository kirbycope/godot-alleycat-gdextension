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

	int scancode = 0;
	switch (key->get_keycode()) {
		case KEY_UP: scancode = ALLEYCAT_KEY_UP; break;
		case KEY_DOWN: scancode = ALLEYCAT_KEY_DOWN; break;
		case KEY_LEFT: scancode = ALLEYCAT_KEY_LEFT; break;
		case KEY_RIGHT: scancode = ALLEYCAT_KEY_RIGHT; break;
		case KEY_ALT: scancode = ALLEYCAT_KEY_ALT; break;
		case KEY_ESCAPE: scancode = ALLEYCAT_KEY_ESC; break;
		case KEY_CTRL: scancode = ALLEYCAT_KEY_CTRL; break;
		case KEY_S: scancode = ALLEYCAT_KEY_S; break;
		case KEY_M: scancode = ALLEYCAT_KEY_M; break;
		case KEY_Y: scancode = ALLEYCAT_KEY_Y; break;
		case KEY_N: scancode = ALLEYCAT_KEY_N; break;
		default: return;
	}
	alleycat_key(scancode, key->is_pressed() ? 1 : 0);
	get_viewport()->set_input_as_handled();
}

bool AlleyCat::is_running() const { return running; }
bool AlleyCat::is_loaded() const { return loaded; }
bool AlleyCat::is_ready() const { return loaded && alleycat_ready() != 0; }
Ref<Image> AlleyCat::get_frame() const { return image; }
int64_t AlleyCat::get_instructions() const { return (int64_t)alleycat_instructions(); }
String AlleyCat::get_status() const { return String(alleycat_status()); }

void AlleyCat::set_exe_path(const String &path) { exe_path = path; }
String AlleyCat::get_exe_path() const { return exe_path; }
void AlleyCat::set_autostart(bool value) { autostart = value; }
bool AlleyCat::get_autostart() const { return autostart; }
void AlleyCat::set_speed(double value) { speed = value; }
double AlleyCat::get_speed() const { return speed; }

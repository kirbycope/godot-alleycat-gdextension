/* PureAlleyCat - Alley Cat (1984) as an embeddable C library.
 *
 * Shaped after PureDOOM: the library is the engine, and you supply the original data. Here the
 * data file is the game's own CAT.EXE, which holds both the code and all 29 KB of artwork, so
 * nothing copyrighted ships with the library.
 *
 *     #include "purecat.h"
 *
 *     alleycat_init(exe_bytes, exe_size);
 *     while (running) {
 *         alleycat_key(ALLEYCAT_KEY_LEFT, held);
 *         alleycat_update();                        // one frame
 *         draw(alleycat_framebuffer());             // 320x200, one byte per pixel, values 0-3
 *     }
 *
 * No allocation, no file I/O, no dependency beyond <stdint.h> and <string.h>. One megabyte of
 * state lives in the library, so it is a big BSS object rather than a heap user.
 *
 * What it actually is: a small 8086 real-mode interpreter plus the handful of BIOS calls and
 * ports the game touches. A source port would be nicer, but the source was never released, and
 * Ghidra's decompilation of hand-written assembly loses the register-passing conventions the
 * program is built on. This runs the real thing, and it is exact.
 */
#ifndef ALLEYCAT_H
#define ALLEYCAT_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define ALLEYCAT_WIDTH  320
#define ALLEYCAT_HEIGHT 200

/* Scancodes the game reads. It installs its own INT 9 handler and reads port 0x60 directly, so
 * these are IBM PC set-1 make codes; alleycat_key feeds them through the same path. */
enum {
    ALLEYCAT_KEY_UP    = 0x48,
    ALLEYCAT_KEY_DOWN  = 0x50,
    ALLEYCAT_KEY_LEFT  = 0x4B,
    ALLEYCAT_KEY_RIGHT = 0x4D,
    ALLEYCAT_KEY_ALT   = 0x38,
    ALLEYCAT_KEY_ESC   = 0x01,
    ALLEYCAT_KEY_CTRL  = 0x1D,
    ALLEYCAT_KEY_S     = 0x1F,
    ALLEYCAT_KEY_M     = 0x32,
    ALLEYCAT_KEY_Y     = 0x15,
    ALLEYCAT_KEY_N     = 0x31,
};

/* Loads CAT.EXE and resets the machine. Returns 0 on success, non-zero if it is not an MZ image.
 * The bytes are copied in, so the caller may free them afterwards. */
int alleycat_init(const void *exe, int exe_size);

/* Runs approximately one 18.2 Hz tick worth of instructions. */
void alleycat_update(void);

/* Runs an explicit number of instructions; alleycat_update is a wrapper on this. */
void alleycat_run(int instructions);

/* 320x200, one byte per pixel, each 0-3 indexing the CGA palette. Decoded from the emulated
 * framebuffer, so it is valid after any alleycat_update. */
const uint8_t *alleycat_framebuffer(void);

/* The four RGB triples for the palette the game selected, as 0xRRGGBB. */
void alleycat_palette(uint32_t out[4]);

/* Press or release a key. `down` is non-zero for a press. */
void alleycat_key(int scancode, int down);

/* The game port. Alley Cat asks "joystick? (y/n)" at startup and, if answered yes, checks the
   BIOS equipment list for a game adapter before it will read the port at all, so a host says
   whether the machine it is running on has one. Call it before alleycat_init, which is what
   writes the equipment word; calling it later takes effect on the next init.

   alleycat_joystick then feeds the stick. x and y are -1, 0 or 1, because that is all the game
   resolves out of the analogue axes: -1 is left or up, 1 is right or down. Buttons are pressed
   when non-zero. It is a level, not an event, so a host sets it every frame and the library
   reports it whenever the game samples the port. */
void alleycat_joystick_present(int present);
void alleycat_joystick(int x, int y, int button1, int button2);

/* Non-zero once the program has set a graphics mode, i.e. it is past its startup checks. */
int alleycat_ready(void);

/* The BIOS text screen. The game prints its setup questions through teletype rather than drawing
   them, so a host must show these rows or the player sees nothing and assumes it has hung. */
const char *alleycat_text_row(int row);
int alleycat_text_rows(void);
/* Where the cursor is on that screen. The text screen is persistent and Alley Cat reprints its menu over
   whatever page is already on it, so the characters alone cannot say how far the program has got through
   printing the page in front of the player - everything below the cursor may be the tail of an older one. */
void alleycat_cursor(int *row, int *col);

/* How many of the 16384 framebuffer bytes are non-zero. The game blanks the graphics screen while
   it asks a setup question and paints it while playing, so this is how a host decides whether to
   show the text rows over the top or get out of the way. */
int alleycat_screen_painted(void);

/* The PC speaker. alleycat_speaker_hz is the tone the timer is programmed for, and
   alleycat_speaker_on reports whether the gate is open. A host polls both each frame and drives a
   square wave: the speaker had no volume control, so amplitude is the host's choice. */
int alleycat_speaker_on(void);
int alleycat_speaker_hz(void);

/* Drains generated audio: signed 16-bit mono at alleycat_audio_rate(). Returns how many samples
   were written, which may be fewer than asked for. Call it every frame; what is not drained is
   eventually dropped rather than allowed to drift further and further behind. */
int alleycat_audio_read(int16_t *out, int max_samples);
int alleycat_audio_rate(void);
int alleycat_audio_available(void);

/* Which of the game's two voices is sounding. Alley Cat drives one speaker from two places - a music
   player that walks a note table, and the routines that make its effects - and because there is only
   one speaker they interrupt each other rather than mixing. So the voice is whichever of them last
   programmed the timer, and the library reports it rather than guessing from the waveform, which
   cannot be done: a square wave carries no sign of what asked for it.

   alleycat_set_voice_volume scales one of them on the way out. Zero silences that voice and leaves
   the other alone, which is how a host swaps the music for its own. */
#define ALLEYCAT_VOICE_NONE    0
#define ALLEYCAT_VOICE_MUSIC   1
#define ALLEYCAT_VOICE_EFFECTS 2
int alleycat_voice(void);
/* Sounds other than the music the game has begun since it booted. Only ever rises, so a change is an event:
   this is "something just happened" without having to know what. */
unsigned int alleycat_effect_starts(void);
/* Bytes written into the CGA window since boot. The jump between two host frames says how much of the screen
   the game just drew, which is how a whole new place is told from a sprite moving. */
unsigned int alleycat_video_writes(void);

/* Reads the machine's memory. The game is one 1984 assembly program with its variables at fixed addresses,
   so what it is thinking - the score, the lives, which screen it is on - is in here at an address that does
   not move between runs. Finding which address is a matter of watching what changes when something happens,
   and this is the window to watch through. Reads outside the megabyte give nothing rather than reading off
   the end. LOAD_SEG is where the image was placed, so a physical address is (LOAD_SEG << 4) + offset. */
#define ALLEYCAT_LOAD_SEG 0x1000u
#define ALLEYCAT_MEM_SIZE (1u << 20)
int alleycat_peek(unsigned int at, unsigned char *into, unsigned int length);
/* Where the machine is reading its variables from right now, as a physical address: the data segment shifted
   into place. A disassembly gives a variable as a bare offset like 0x1f82, and this is what that offset is
   counted from, so the two together are an address alleycat_peek can read. */
unsigned int alleycat_data_address(void);
/* Writes into the machine's memory. The counterpart of alleycat_peek, and the other half of what a host
   needs to carry something across runs: a high score read out at the end of one game has to be put back at
   the start of the next, and the game keeps it in memory like everything else.

   This writes where the game itself would, so it can just as easily corrupt the program as set a score. It
   is deliberately not routed through the interpreter's own write path: a host poking memory is not the game
   drawing, so it does not count towards the video writes a host reads to notice screen changes. */
int alleycat_poke(unsigned int at, const unsigned char *from, unsigned int length);

/* Every sprite the game draws, as it draws it. Hi-res artwork over a 1984 game needs to know what was drawn
   and where, and the game will say so: every sprite in it goes through one of three blitters, so watching
   the calls to those is watching the game draw.

   Reporting is off by default and costs nothing when off - it is a comparison on the call instruction, which
   is rare next to the millions of ordinary instructions a second the interpreter runs.

   A report is the source the artwork was copied from, as an address alleycat_peek can read; where it went in
   the CGA window; and the size as the game gave it, CL words across by CH rows. A word is eight pixels at
   two bits each, and rows alternate banks, which is the shape the hardware wanted rather than anything a
   host would choose. */
#define ALLEYCAT_SPRITES_MAX 512
/* The blitters, as offsets into CAT.EXE. sub_09FCD copies straight into the screen, sub_09F65 saves the
   background and ANDs the sprite over it, sub_09FA0 walks its source by a stride for a taller strip. */
#define ALLEYCAT_BLIT_PLAIN   0x9FCDu
#define ALLEYCAT_BLIT_MASKED  0x9F65u
#define ALLEYCAT_BLIT_STRIDED 0x9FA0u
void alleycat_report_sprites(int on);
void alleycat_sprites_begin(void);
int alleycat_sprite_count(void);
int alleycat_sprite(int index, unsigned int *source, unsigned int *at, unsigned int *size, unsigned int *kind);

/* Watches a range of memory and remembers where the code that wrote to it was. This is how anything in the
   game is found: a score, a life count or a sprite is a place in memory, and the way to that place is the
   routine that touches it. Point the watch at the few bytes of screen a number is drawn in, let the game
   draw it, and the addresses that come back are the drawing code, which the disassembly then explains.

   Writers are kept as image offsets - the address the code sits at inside CAT.EXE - so they line up with a
   disassembly of the file rather than with wherever the image happened to be loaded. At most
   ALLEYCAT_WATCH_MAX distinct ones are kept, which is far more than any one routine needs. */
#define ALLEYCAT_WATCH_MAX 32
void alleycat_watch(unsigned int from, unsigned int to);
int alleycat_watch_writers(unsigned int *into, int max);
unsigned int alleycat_watch_hits(void);
/* The routines that called the writers. The writer is nearly always a shared blitter, so it is the caller
   that says what was being drawn. */
int alleycat_watch_callers(unsigned int *into, int max);
/* The artwork the host is replacing with its own. A blit from one of these addresses still runs in full -
   the game's own bookkeeping, its saved backgrounds and its erases are all untouched - but none of what it
   writes reaches the screen. That is what a replacement needs: artwork drawn over the game's own shows the
   game's version of the same thing through every gap in it, and the background the host wants behind its
   picture is the alley, not a flat colour it would have to guess at.

   Addresses are as alleycat_sprite reports them. Passing a count of zero turns hiding off. */
#define ALLEYCAT_HIDDEN_MAX 64
void alleycat_hide_sprites(const unsigned int *sources, int count);

void alleycat_set_voice_volume(int voice, float volume);

/* Where the machine is and whether it is in a state to take a key. A game that has stopped responding
   looks the same from memory as one that is running normally, so this reports the things that are not in
   memory: the instruction pointer as an image offset, so it lines up with a disassembly of CAT.EXE, whether
   interrupts are enabled - a key is only handed to the game's INT 9 handler while they are - and how many
   keys are waiting in the queue behind that. */
void alleycat_where(unsigned int *image_offset, int *interrupts_enabled, int *keys_queued);

/* Machine state, for rewinding. alleycat_state_size is how many bytes a snapshot takes and does not
   change while the program runs, so a host can size a ring once. Saving copies the whole machine -
   the megabyte of RAM, the registers, the video and text screens, the keyboard queue, the timers and
   the game port - and loading puts it all back, so a restore is indistinguishable from never having
   gone forward.

   Two things are deliberately left out. The parity table is a lookup built from nothing and is the
   same every time, and the audio ring is the host's queue rather than the machine's: rewinding the
   machine should not replay samples the host has already drained. Everything the speaker itself is
   doing - the timer divisor, the gate, the square wave phase - is in there. */
size_t alleycat_state_size(void);
void alleycat_save_state(void *dst);
void alleycat_load_state(const void *src);

/* Total instructions retired, and the last stop reason, for diagnostics. */
uint64_t alleycat_instructions(void);
const char *alleycat_status(void);

/* -1 if none; otherwise the opcode that stopped the run, and its CS:IP packed as 0xSSSSIIII. */
int alleycat_fault_opcode(void);
uint32_t alleycat_fault_address(void);

#ifdef __cplusplus
}
#endif

#endif /* ALLEYCAT_H */



/* ============================================================================
 *  Implementation.
 *
 *  Define ALLEYCAT_IMPLEMENTATION in exactly one translation unit before
 *  including this header and that unit gets the whole interpreter, the way
 *  PureDOOM's DOOM_IMPLEMENTATION works. Every other unit includes the header
 *  for the declarations alone.
 * ============================================================================ */
#ifdef ALLEYCAT_IMPLEMENTATION

#include <string.h>

/* ---- machine state ------------------------------------------------------------------------ */

#define MEM_SIZE   (1u << 20)
#define LOAD_SEG   0x1000u
#define PSP_SEG    (LOAD_SEG - 0x10u)
#define VIDEO_SEG  0xB800u
#define TICK_STEPS 6000            /* instructions per 18.2 Hz tick, as in the Python reference */

enum { rAX, rCX, rDX, rBX, rSP, rBP, rSI, rDI };
enum { sES, sCS, sSS, sDS };

enum {
    fCF = 0x0001, fPF = 0x0004, fAF = 0x0010, fZF = 0x0040,
    fSF = 0x0080, fTF = 0x0100, fIF = 0x0200, fDF = 0x0400, fOF = 0x0800
};

static uint8_t  MEM[MEM_SIZE];
static uint16_t R[8];
static uint16_t S[4];
static uint16_t IP;
static uint16_t FLAGS = 0x0002;
static uint64_t ICOUNT;
static int      VIDEO_MODE = -1;
static const char *STATUS = "not started";
static uint8_t  FRAME[ALLEYCAT_WIDTH * ALLEYCAT_HEIGHT];
/* The game prints its setup prompts through BIOS teletype rather than drawing them, so INT 10h
   has to keep a text screen or every question is invisible and it reads as a hang. */
#define TEXT_COLS 40
#define TEXT_ROWS 25
static char     TEXT[TEXT_ROWS][TEXT_COLS + 1];
static int      CUR_ROW, CUR_COL;
static uint8_t  SCANCODE;
static uint8_t  PORT61;
/* PC speaker. The game drives it the textbook way: a divisor into PIT channel 2 through port
   0x42, mode 3 (square wave) selected by 0xB6 on port 0x43, and the gate opened by setting the
   low two bits of port 0x61. Tone in hertz is PIT_HZ / divisor. */
#define PIT_HZ 1193182u
/* Audio is generated here rather than by the host, because the host only gets to look between
   frames. At 480 frames a second that is one glance every ~228 instructions, and a tone that
   starts and stops inside that window is simply never seen. Sampling inside the instruction loop
   catches every one. */
#define AUDIO_RATE 22050
#define INSTR_PER_SEC (TICK_STEPS * 182 / 10)
#define AUDIO_RING 16384
static int16_t  AUDIO[AUDIO_RING];
static int      AUDIO_W, AUDIO_R;
static uint32_t AUDIO_ACC;      /* instruction-to-sample fraction, scaled by AUDIO_RATE */
static uint32_t SQUARE_PHASE;   /* square wave phase, scaled by AUDIO_RATE */
static int      SQUARE_LEVEL;
/* Which routine last programmed the tone, and how loud each is wanted. The music player's writes to
   the timer are at these image offsets; everything else that makes a sound is an effect. Found by
   reading the disassembly in alley-decomp: the player at 00C5F5 walks a note table at 0x538C with a
   cursor at 0x5320 and looks each note's divisor up at 0x5324. */
#define MUSIC_OUT_LOW  0xC619u
#define MUSIC_OUT_HIGH 0xC61Du
static int   VOICE = ALLEYCAT_VOICE_NONE;        /* Who is sounding right now, NONE while the speaker is quiet. */
static int   VOICE_WRITER = ALLEYCAT_VOICE_NONE; /* Who last set a frequency; who VOICE becomes when the gate opens. */
static int   SPEAKER_WAS_ON = 0;
static unsigned int EFFECT_STARTS = 0;           /* Sounds the game has begun that were not the music. */
static float VOICE_VOLUME[3] = { 1.0f, 1.0f, 1.0f };
static uint16_t PIT2_DIVISOR = 0;

/* Follows the speaker gate after anything that could have moved it. The game silences a sound either by
   closing the gate at port 0x61 or by zeroing the divisor at 0x42, so both count as quiet.

   This is what makes "a sound just started" answerable. VOICE on its own is a level, not an event: it used
   to be set on every frequency write and never cleared, so after the first effect it simply stayed at
   EFFECTS for good and a host watching for the change saw exactly one, at the beginning. Now it falls back
   to NONE with the speaker, and every fresh effect is a rising edge that EFFECT_STARTS counts. */
static void note_speaker(void) {
    int on = (PORT61 & 0x03) == 0x03 && PIT2_DIVISOR > 0;
    if (on && !SPEAKER_WAS_ON && VOICE_WRITER == ALLEYCAT_VOICE_EFFECTS) {
        EFFECT_STARTS++;
    }
    VOICE = on ? VOICE_WRITER : ALLEYCAT_VOICE_NONE;
    SPEAKER_WAS_ON = on;
}

static int      PIT2_HIGH_BYTE_NEXT = 0;
/* PIT channel 0 is the game's stopwatch. It free-runs at PIT_HZ and counts down through 65536
   every BIOS tick, which is TICK_STEPS instructions here, and the game latches it with
   `out 0x43, 0` then reads the low byte and the high. It times the joystick's one-shots by
   subtracting two of those readings, so the count has to fall at roughly the right rate and in
   the right direction; a counter that merely changes is not enough. */
#define PIT0_PER_TICK 65536u
static uint16_t PIT0_LATCH;
static int      PIT0_HIGH_BYTE_NEXT;
static uint32_t RETRACE;
/* The game port. A PC joystick is two potentiometers and two buttons on port 0x201: writing to
   the port fires a one-shot per axis, bits 0-3 read high while each is still charging, and the
   host times how long that takes. Alley Cat only wants three positions out of each axis - the
   routine at 0x84D1 buckets the count at 1286 and 2586 - so the host hands over -1, 0 or 1 and
   the charge time is picked inside the matching bucket. Buttons are active low in bits 4 and 5.
   JOY_PRESENT survives a reset, because a host sets it once for the machine it is running on and
   alleycat_init is what writes it into the BIOS equipment word. */
static int      JOY_PRESENT;
static int      JOY_X, JOY_Y;
static int      JOY_BUTTON1, JOY_BUTTON2;
static uint64_t JOY_FIRED;
static int      JOY_TIMING;
static int      STOPPED;
static int      BAD_OP = -1;
static uint16_t BAD_CS, BAD_IP;

/* A tiny key queue: the game installs its own INT 9 handler, so a key is delivered by putting the
 * make/break code where port 0x60 will be read and raising interrupt 9. */
static uint8_t  KEYQ[32];
static int      KEYQ_HEAD, KEYQ_TAIL;

static uint8_t PARITY[256];
static int     PARITY_READY;

static void parity_init(void)
{
    for (int i = 0; i < 256; i++) {
        int bits = 0, v = i;
        while (v) { bits += v & 1; v >>= 1; }
        PARITY[i] = (uint8_t)((bits & 1) == 0);
    }
    PARITY_READY = 1;
}

/* ---- memory --------------------------------------------------------------------------------- */

static uint32_t phys(uint16_t seg, uint16_t off) { return (uint32_t)(((seg << 4) + off) & 0xFFFFF); }
static uint8_t  rd8(uint16_t seg, uint16_t off)  { return MEM[phys(seg, off)]; }

/* How much of the screen the game has drawn, counted in bytes written into the CGA window. This is the one
   honest way to tell "the picture is being replaced" from "a sprite moved": moving the cat writes a few
   hundred bytes, while going through a window and landing in a room writes the whole 16K.

   Pixels cannot answer it. Alley Cat's screens share a background colour, so two completely different places
   agree on most of their pixels, and a room arrives over several frames rather than in one, so a
   frame-to-frame difference never spikes either. The machine knows what it drew; the picture does not. */
static unsigned int VIDEO_WRITES = 0;

/* The watch: a range of memory, the code that has written into it, and how often. See alleycat_watch. */
static uint32_t WATCH_FROM = 0;
static uint32_t WATCH_TO = 0;
static uint32_t WATCH_WRITERS[ALLEYCAT_WATCH_MAX];
static uint32_t WATCH_CALLERS[ALLEYCAT_WATCH_MAX];
static int      WATCH_WRITER_COUNT = 0;
static int      WATCH_CALLER_COUNT = 0;
static unsigned int WATCH_HITS = 0;

/* Sprites drawn this frame. See alleycat_report_sprites. */
static int      SPRITES_REPORTED = 0;
static uint32_t SPRITE_SOURCE[ALLEYCAT_SPRITES_MAX];
static uint16_t SPRITE_AT[ALLEYCAT_SPRITES_MAX];
static uint16_t SPRITE_SIZE[ALLEYCAT_SPRITES_MAX];
static uint16_t SPRITE_KIND[ALLEYCAT_SPRITES_MAX];
static int      SPRITE_COUNT = 0;
static int      SPRITE_MISSED = 0;

/* The artwork a host is drawing over, and whether a blit of one of those is running right now. See
   alleycat_hide_sprites. HIDING_SP is the stack as it stood when that blit was called, which is how the end
   of it is recognised: the routine is reached by a near call, so the stack comes back above that on return. */
static uint32_t HIDDEN[ALLEYCAT_HIDDEN_MAX];
static int      HIDDEN_COUNT = 0;
static int      HIDING = 0;
static uint16_t HIDING_SP = 0;
#define IN_VIDEO(at) ((at) >= ((uint32_t)VIDEO_SEG << 4) && (at) < (((uint32_t)VIDEO_SEG << 4) + 0x4000u))

static void note_watch(uint32_t at);
static void note_caller(void);
static void note_sprite(void);

static void     wr8(uint16_t seg, uint16_t off, uint8_t v) {
    uint32_t at = phys(seg, off);
    if (IN_VIDEO(at)) {
        VIDEO_WRITES++;
        /* Counted and then dropped. The count is how a host tells a moved sprite from a repainted screen,
           and the game did draw; it is only the pixels that are not wanted, because the host is putting its
           own picture in the same place and the game's would show through the gaps in it. */
        if (HIDING) { return; }
    }
    if (WATCH_TO > WATCH_FROM && at >= WATCH_FROM && at < WATCH_TO) { note_watch(at); note_caller(); }
    MEM[at] = v;
}

static uint16_t rd16(uint16_t seg, uint16_t off)
{
    return (uint16_t)(MEM[phys(seg, off)] | (MEM[phys(seg, (uint16_t)(off + 1))] << 8));
}

static void wr16(uint16_t seg, uint16_t off, uint16_t v)
{
    wr8(seg, off, (uint8_t)v);
    wr8(seg, (uint16_t)(off + 1), (uint8_t)(v >> 8));
}

/* 8-bit register halves: index 0-3 are AL CL DL BL, 4-7 are AH CH DH BH. */
static uint8_t get8(int i)
{
    return (uint8_t)((i & 4) ? (R[i & 3] >> 8) : (R[i & 3] & 0xFF));
}

static void set8(int i, uint8_t v)
{
    int j = i & 3;
    if (i & 4) R[j] = (uint16_t)((R[j] & 0x00FF) | (v << 8));
    else       R[j] = (uint16_t)((R[j] & 0xFF00) | v);
}

/* ---- fetch ----------------------------------------------------------------------------------- */

/* Remembers where the code that just wrote to the watched range lives, as an offset into CAT.EXE so it
   lines up with a disassembly of the file. IP has already moved past the instruction by the time a write
   happens, so what comes back points just after the store rather than at it - near enough to find the
   routine, and the disassembly settles the rest. A writer already seen is not recorded twice: one routine
   filling a row of pixels would otherwise use the whole table on its own. */
static void note_watch(uint32_t at)
{
    uint32_t where = (((uint32_t)S[sCS] << 4) + IP) - ((uint32_t)LOAD_SEG << 4);
    int i;
    (void)at;
    WATCH_HITS++;
    for (i = 0; i < WATCH_WRITER_COUNT; i++) {
        if (WATCH_WRITERS[i] == where) {
            return;
        }
    }
    if (WATCH_WRITER_COUNT < ALLEYCAT_WATCH_MAX) {
        WATCH_WRITERS[WATCH_WRITER_COUNT++] = where;
    }
}

/* Who called the routine that just wrote. The writer is almost always a shared blitter - the same three
   routines draw every sprite in the game - so knowing the blitter says nothing about what was drawn. The
   caller does.

   Alley Cat's blitters are reached by a near call and push nothing, so the top of the stack is still the
   return address when the store happens. That makes the caller readable without tracing calls: one word at
   SS:SP, turned into an offset into CAT.EXE the same way. A blitter that pushed registers would need the
   stack walking properly, and none of these do. */
static void note_caller(void)
{
    uint16_t ret = rd16(S[sSS], R[rSP]);
    uint32_t where = (((uint32_t)S[sCS] << 4) + ret) - ((uint32_t)LOAD_SEG << 4);
    int i;
    for (i = 0; i < WATCH_CALLER_COUNT; i++) {
        if (WATCH_CALLERS[i] == where) {
            return;
        }
    }
    if (WATCH_CALLER_COUNT < ALLEYCAT_WATCH_MAX) {
        WATCH_CALLERS[WATCH_CALLER_COUNT++] = where;
    }
}

/* Called on every near call, which is where a blit begins. The registers are still the ones the caller set
   up - SI the artwork, DI the place on screen, CX the size - because nothing has run yet. */
static void note_sprite(void)
{
    uint32_t where, source;
    int i;
    if (!SPRITES_REPORTED && HIDDEN_COUNT == 0) {
        return;
    }
    where = (((uint32_t)S[sCS] << 4) + IP) - ((uint32_t)LOAD_SEG << 4);
    if (where != ALLEYCAT_BLIT_PLAIN && where != ALLEYCAT_BLIT_MASKED && where != ALLEYCAT_BLIT_STRIDED) {
        return;
    }
    /* The source as an address rather than an offset, so a host can read the artwork with alleycat_peek. */
    source = ((uint32_t)S[sDS] << 4) + R[rSI];
    if (!HIDING) {
        for (i = 0; i < HIDDEN_COUNT; i++) {
            if (HIDDEN[i] == source) {
                HIDING = 1;
                HIDING_SP = R[rSP];
                break;
            }
        }
    }
    if (!SPRITES_REPORTED) {
        return;
    }
    if (SPRITE_COUNT >= ALLEYCAT_SPRITES_MAX) {
        SPRITE_MISSED++;
        return;
    }
    SPRITE_SOURCE[SPRITE_COUNT] = source;
    SPRITE_AT[SPRITE_COUNT] = R[rDI];
    SPRITE_SIZE[SPRITE_COUNT] = R[rCX];
    SPRITE_KIND[SPRITE_COUNT] = (uint16_t)where;
    SPRITE_COUNT++;
}

static uint8_t fetch8(void)   { uint8_t v = rd8(S[sCS], IP); IP++; return v; }
static uint16_t fetch16(void) { uint16_t v = rd16(S[sCS], IP); IP = (uint16_t)(IP + 2); return v; }
static int8_t fetchs8(void)   { return (int8_t)fetch8(); }

/* ---- flags ------------------------------------------------------------------------------------ */

static void setf(uint16_t mask, int on) { FLAGS = (uint16_t)(on ? (FLAGS | mask) : (FLAGS & ~mask)); }
static int  getf(uint16_t mask) { return (FLAGS & mask) != 0; }

static void szp(uint32_t v, int w)
{
    setf(fZF, v == 0);
    setf(fSF, (v & (w ? 0x8000u : 0x80u)) != 0);
    setf(fPF, PARITY[v & 0xFF]);
}

static void logic_flags(uint32_t v, int w) { setf(fCF | fOF, 0); szp(v, w); }

static void add_flags(uint32_t a, uint32_t b, uint32_t r, int w, uint32_t carry)
{
    uint32_t mask = w ? 0xFFFFu : 0xFFu;
    uint32_t sign = w ? 0x8000u : 0x80u;
    setf(fCF, (a + b + carry) > mask);
    setf(fAF, ((a ^ b ^ r) & 0x10) != 0);
    setf(fOF, ((~(a ^ b) & (a ^ r)) & sign) != 0);
    szp(r & mask, w);
}

static void sub_flags(uint32_t a, uint32_t b, uint32_t r, int w, uint32_t borrow)
{
    uint32_t mask = w ? 0xFFFFu : 0xFFu;
    uint32_t sign = w ? 0x8000u : 0x80u;
    setf(fCF, (b + borrow) > a);
    setf(fAF, ((a ^ b ^ r) & 0x10) != 0);
    setf(fOF, (((a ^ b) & (a ^ r)) & sign) != 0);
    szp(r & mask, w);
}

/* ---- mod/rm -------------------------------------------------------------------------------------- */

typedef struct { int mod, reg, rm; uint16_t seg, off; } Modrm;

static Modrm decode_modrm(int seg_override)
{
    Modrm m;
    uint8_t byte = fetch8();
    int base_seg;
    int32_t base;

    m.mod = byte >> 6;
    m.reg = (byte >> 3) & 7;
    m.rm  = byte & 7;
    m.seg = 0;
    m.off = 0;
    if (m.mod == 3) return m;

    switch (m.rm) {
    case 0: base = R[rBX] + R[rSI]; base_seg = sDS; break;
    case 1: base = R[rBX] + R[rDI]; base_seg = sDS; break;
    case 2: base = R[rBP] + R[rSI]; base_seg = sSS; break;
    case 3: base = R[rBP] + R[rDI]; base_seg = sSS; break;
    case 4: base = R[rSI];          base_seg = sDS; break;
    case 5: base = R[rDI];          base_seg = sDS; break;
    case 6:
        if (m.mod == 0) { base = fetch16(); base_seg = sDS; }
        else            { base = R[rBP];    base_seg = sSS; }
        break;
    default: base = R[rBX]; base_seg = sDS; break;
    }
    if (m.mod == 1)      base += fetchs8();
    else if (m.mod == 2) base += (int16_t)fetch16();

    if (seg_override >= 0) base_seg = seg_override;
    m.seg = S[base_seg];
    m.off = (uint16_t)base;
    return m;
}

static uint16_t rm_read(int w, const Modrm *m)
{
    if (m->mod == 3) return w ? R[m->rm] : get8(m->rm);
    return w ? rd16(m->seg, m->off) : rd8(m->seg, m->off);
}

static void rm_write(int w, const Modrm *m, uint16_t v)
{
    if (m->mod == 3) { if (w) R[m->rm] = v; else set8(m->rm, (uint8_t)v); }
    else if (w)      wr16(m->seg, m->off, v);
    else             wr8(m->seg, m->off, (uint8_t)v);
}

/* ---- stack ------------------------------------------------------------------------------------------ */

static void push(uint16_t v) { R[rSP] = (uint16_t)(R[rSP] - 2); wr16(S[sSS], R[rSP], v); }
static uint16_t pop(void)    { uint16_t v = rd16(S[sSS], R[rSP]); R[rSP] = (uint16_t)(R[rSP] + 2); return v; }

/* ---- alu / shift -------------------------------------------------------------------------------------- */

/* Returns the result; *store is cleared for cmp, which writes nothing. */
static uint16_t alu(int op, uint32_t a, uint32_t b, int w, int *store)
{
    uint32_t mask = w ? 0xFFFFu : 0xFFu, r;
    uint32_t c;
    *store = 1;
    switch (op) {
    case 0: r = (a + b) & mask;  add_flags(a, b, r, w, 0); return (uint16_t)r;
    case 1: r = a | b;           logic_flags(r, w);        return (uint16_t)r;
    case 2: c = getf(fCF) ? 1u : 0u; r = (a + b + c) & mask; add_flags(a, b, r, w, c); return (uint16_t)r;
    case 3: c = getf(fCF) ? 1u : 0u; r = (a - b - c) & mask; sub_flags(a, b, r, w, c); return (uint16_t)r;
    case 4: r = a & b;           logic_flags(r, w);        return (uint16_t)r;
    case 5: r = (a - b) & mask;  sub_flags(a, b, r, w, 0); return (uint16_t)r;
    case 6: r = a ^ b;           logic_flags(r, w);        return (uint16_t)r;
    default:
        r = (a - b) & mask; sub_flags(a, b, r, w, 0); *store = 0; return (uint16_t)r;
    }
}

static uint16_t shift_op(int op, uint32_t v, int count, int w)
{
    uint32_t mask = w ? 0xFFFFu : 0xFFu;
    uint32_t sign = w ? 0x8000u : 0x80u;
    int c = 0, i;

    count &= 0x1F;
    if (count == 0) return (uint16_t)v;
    for (i = 0; i < count; i++) {
        switch (op) {
        case 0: c = (v & sign) != 0; v = ((v << 1) | (uint32_t)c) & mask; break;          /* rol */
        case 1: c = v & 1; v = ((v >> 1) | (c ? sign : 0)) & mask; break;                  /* ror */
        case 2: { int old = getf(fCF); c = (v & sign) != 0;
                  v = ((v << 1) | (uint32_t)old) & mask; break; }                          /* rcl */
        case 3: { int old = getf(fCF); c = v & 1;
                  v = ((v >> 1) | (old ? sign : 0)) & mask; break; }                       /* rcr */
        case 4: case 6: c = (v & sign) != 0; v = (v << 1) & mask; break;                   /* shl */
        case 5: c = v & 1; v = (v >> 1) & mask; break;                                     /* shr */
        default: c = v & 1; v = ((v >> 1) | (v & sign)) & mask; break;                     /* sar */
        }
        setf(fCF, c);
    }
    if (op == 4 || op == 5 || op == 6 || op == 7) szp(v, w);
    setf(fOF, count == 1 ? (((v ^ (v << 1)) & sign) != 0) : 0);
    return (uint16_t)v;
}

static int condition(int code)
{
    int o = getf(fOF), c = getf(fCF), z = getf(fZF), s = getf(fSF), p = getf(fPF);
    switch (code) {
    case 0:  return o;              case 1:  return !o;
    case 2:  return c;              case 3:  return !c;
    case 4:  return z;              case 5:  return !z;
    case 6:  return c || z;         case 7:  return !(c || z);
    case 8:  return s;              case 9:  return !s;
    case 10: return p;              case 11: return !p;
    case 12: return s != o;         case 13: return s == o;
    case 14: return z || (s != o);  default: return !z && (s == o);
    }
}

/* ---- the platform ------------------------------------------------------------------------------------- */

/* Where PIT channel 0 has counted down to, in its own 1.193182 MHz counts. */
static uint16_t pit0_now(void)
{
    return (uint16_t)(0u - (uint16_t)((ICOUNT * PIT0_PER_TICK / TICK_STEPS) & 0xFFFFu));
}

/* How long an axis holds its one-shot high, in PIT counts. Centre sits between the game's two
   thresholds; the ends sit clear of them, with room for the polling loop's own granularity of
   about 140 counts per pass. */
static uint32_t joy_charge(int axis)
{
    if (axis < 0) return 600u;
    if (axis > 0) return 3200u;
    return 1900u;
}

static uint8_t port_in(uint16_t port)
{
    switch (port) {
    case 0x3DA: RETRACE++; return (uint8_t)((RETRACE & 1) ? 0x09 : 0x00);
    case 0x60:  return SCANCODE;
    case 0x61:  return PORT61;
    case 0x40: {
        uint8_t v = PIT0_HIGH_BYTE_NEXT ? (uint8_t)(PIT0_LATCH >> 8) : (uint8_t)PIT0_LATCH;
        PIT0_HIGH_BYTE_NEXT = !PIT0_HIGH_BYTE_NEXT;
        /* Both halves of a latched reading have been handed over, so the next pair reads live
           again even if the caller forgets to latch. */
        if (!PIT0_HIGH_BYTE_NEXT) PIT0_LATCH = pit0_now();
        return v;
    }
    case 0x201: {
        uint8_t v = 0xF0;                       /* both axis pairs low, every button up */
        if (JOY_BUTTON1) v &= (uint8_t)~0x10;
        if (JOY_BUTTON2) v &= (uint8_t)~0x20;
        if (JOY_TIMING) {
            uint32_t counts = (uint32_t)((ICOUNT - JOY_FIRED) * PIT0_PER_TICK / TICK_STEPS);
            if (counts < joy_charge(JOY_X)) v |= 0x01;
            if (counts < joy_charge(JOY_Y)) v |= 0x02;
            if (!(v & 0x03)) JOY_TIMING = 0;
        }
        return v;
    }
    default:    return 0xFF;
    }
}

static void port_out(uint16_t port, uint8_t value)
{
    switch (port) {
    case 0x61:
        PORT61 = value;
        note_speaker();
        break;
    case 0x43:
        /* Only a channel 2 control word concerns the speaker. The game also latches channel 0
           constantly to read the clock, and that must not disturb the tone. */
        if ((value >> 6) == 2) {
            PIT2_HIGH_BYTE_NEXT = 0;
        } else if ((value >> 6) == 0) {
            PIT0_LATCH = pit0_now();
            PIT0_HIGH_BYTE_NEXT = 0;
        }
        break;
    case 0x42:
        /* Who is making this sound. IP has already moved past the OUT by the time this runs, and the
           instruction is two bytes, so the music player's own writes are known by where it returns
           to. Only an interpreter can answer this: a square wave carries no sign of what asked for it. */
        VOICE_WRITER = (IP == MUSIC_OUT_LOW + 2u || IP == MUSIC_OUT_HIGH + 2u)
                ? ALLEYCAT_VOICE_MUSIC : ALLEYCAT_VOICE_EFFECTS;
        /* Access mode lo/hi: the low byte arrives first, then the high. */
        if (PIT2_HIGH_BYTE_NEXT) {
            PIT2_DIVISOR = (uint16_t)((PIT2_DIVISOR & 0x00FF) | ((uint16_t)value << 8));
            PIT2_HIGH_BYTE_NEXT = 0;
        } else {
            PIT2_DIVISOR = (uint16_t)((PIT2_DIVISOR & 0xFF00) | value);
            PIT2_HIGH_BYTE_NEXT = 1;
        }
        note_speaker();
        break;
    case 0x201:
        /* Any write fires the axis one-shots; the value written is ignored by the hardware. */
        JOY_FIRED = ICOUNT;
        JOY_TIMING = 1;
        break;
    default:
        break;
    }
}

static void text_clear(void)
{
    int r, c;
    for (r = 0; r < TEXT_ROWS; r++) {
        for (c = 0; c < TEXT_COLS; c++) TEXT[r][c] = ' ';
        TEXT[r][TEXT_COLS] = 0;
    }
    CUR_ROW = CUR_COL = 0;
}

static void interrupt(int n);

/* Returns 1 if the host answered, 0 to fall through to the interrupt vector table. */
static int bios(int n)
{
    uint8_t ah = get8(4);
    if (n == 0x1A && ah == 0x00) {
        uint32_t ticks = (uint32_t)(ICOUNT / TICK_STEPS);
        R[rCX] = (uint16_t)(ticks >> 16);
        R[rDX] = (uint16_t)ticks;
        set8(rAX, 0);
        return 1;
    }
    if (n == 0x10) {
        switch (ah) {
        case 0x00:                      /* set mode */
            VIDEO_MODE = get8(rAX);
            text_clear();
            return 1;
        case 0x06:                      /* scroll window up */
        case 0x07: {                    /* scroll window down */
            /* The ordinary way a DOS program clears its screen: scroll a window by zero lines, which blanks
               it. Ignoring this is why the game's own menu came back with the last page still underneath it
               - Ctrl-M reprints a shorter page and everything it does not overwrite was still there, so the
               joystick question, the skill menu and the paws message were all on screen at once. */
            uint8_t lines = get8(rAX);
            int top = get8(5), left = get8(1), bottom = get8(6), right = get8(2);
            int r, c, n;
            if (top < 0) top = 0;
            if (left < 0) left = 0;
            if (bottom > TEXT_ROWS - 1) bottom = TEXT_ROWS - 1;
            if (right > TEXT_COLS - 1) right = TEXT_COLS - 1;
            if (top > bottom || left > right) {
                return 1;
            }
            if (lines == 0 || lines > (uint8_t)(bottom - top)) {
                for (r = top; r <= bottom; r++)
                    for (c = left; c <= right; c++) TEXT[r][c] = ' ';
                return 1;
            }
            for (n = 0; n < lines; n++) {
                if (ah == 0x06) {
                    for (r = top; r < bottom; r++)
                        for (c = left; c <= right; c++) TEXT[r][c] = TEXT[r + 1][c];
                    for (c = left; c <= right; c++) TEXT[bottom][c] = ' ';
                } else {
                    for (r = bottom; r > top; r--)
                        for (c = left; c <= right; c++) TEXT[r][c] = TEXT[r - 1][c];
                    for (c = left; c <= right; c++) TEXT[top][c] = ' ';
                }
            }
            return 1;
        }
        case 0x02:                      /* set cursor: DH row, DL column */
            CUR_ROW = get8(6);
            CUR_COL = get8(2);
            return 1;
        case 0x0E: {                    /* teletype: AL is the character */
            uint8_t ch = get8(rAX);
            if (ch == 13) {
                CUR_COL = 0;
            } else if (ch == 10) {
                CUR_ROW++;
            } else if (ch == 8) {
                if (CUR_COL > 0) CUR_COL--;
            } else {
                if (CUR_ROW < TEXT_ROWS && CUR_COL < TEXT_COLS)
                    TEXT[CUR_ROW][CUR_COL] = (ch >= 32 && ch < 127) ? (char)ch : '?';
                CUR_COL++;
            }
            if (CUR_COL >= TEXT_COLS) { CUR_COL = 0; CUR_ROW++; }
            if (CUR_ROW >= TEXT_ROWS) {
                int r, c;
                for (r = 0; r < TEXT_ROWS - 1; r++)
                    for (c = 0; c < TEXT_COLS; c++) TEXT[r][c] = TEXT[r + 1][c];
                for (c = 0; c < TEXT_COLS; c++) TEXT[TEXT_ROWS - 1][c] = ' ';
                CUR_ROW = TEXT_ROWS - 1;
            }
            return 1;
        }
        default:                        /* palette, cursor shape and the rest: accepted, ignored */
            return 1;
        }
    }
    /* Equipment list. Bit 12 is the game adapter, which is what the game's joystick check
       at 0xD215 looks at before it will time the port at all. */
    if (n == 0x11) { R[rAX] = (uint16_t)(0x0021 | (JOY_PRESENT ? 0x1000 : 0)); return 1; }
    if (n == 0x12) { R[rAX] = 640;    return 1; }
    if (n == 0x20) { STOPPED = 1; STATUS = "int 20h: program exit"; return 1; }
    if (n == 0x21 && ah == 0x4C) { STOPPED = 1; STATUS = "int 21h/4C: program exit"; return 1; }
    return 0;
}

static void interrupt(int n)
{
    uint16_t off, seg;
    if (bios(n)) return;
    off = rd16(0, (uint16_t)(n * 4));
    seg = rd16(0, (uint16_t)(n * 4 + 2));
    if (seg == 0 && off == 0) return;        /* nothing installed; ignore */
    push(FLAGS);
    push(S[sCS]);
    push(IP);
    setf(fIF, 0);
    S[sCS] = seg;
    IP = off;
}

/* ---- string operations ------------------------------------------------------------------------------------ */

static void string_op(int op, int seg_override, int rep)
{
    int w = op & 1;
    int16_t step = (int16_t)((w ? 2 : 1) * (getf(fDF) ? -1 : 1));
    uint16_t src_seg = S[seg_override >= 0 ? seg_override : sDS];

    if (rep && R[rCX] == 0) return;
    for (;;) {
        switch (op) {
        case 0xA4: case 0xA5: {
            uint16_t v = w ? rd16(src_seg, R[rSI]) : rd8(src_seg, R[rSI]);
            if (w) wr16(S[sES], R[rDI], v); else wr8(S[sES], R[rDI], (uint8_t)v);
            R[rSI] = (uint16_t)(R[rSI] + step);
            R[rDI] = (uint16_t)(R[rDI] + step);
            break;
        }
        case 0xA6: case 0xA7: {
            uint32_t a = w ? rd16(src_seg, R[rSI]) : rd8(src_seg, R[rSI]);
            uint32_t b = w ? rd16(S[sES], R[rDI]) : rd8(S[sES], R[rDI]);
            sub_flags(a, b, (a - b) & (w ? 0xFFFFu : 0xFFu), w, 0);
            R[rSI] = (uint16_t)(R[rSI] + step);
            R[rDI] = (uint16_t)(R[rDI] + step);
            break;
        }
        case 0xAA: case 0xAB:
            if (w) wr16(S[sES], R[rDI], R[rAX]); else wr8(S[sES], R[rDI], get8(rAX));
            R[rDI] = (uint16_t)(R[rDI] + step);
            break;
        case 0xAC: case 0xAD:
            if (w) R[rAX] = rd16(src_seg, R[rSI]); else set8(rAX, rd8(src_seg, R[rSI]));
            R[rSI] = (uint16_t)(R[rSI] + step);
            break;
        default: {
            uint32_t a = w ? R[rAX] : get8(rAX);
            uint32_t b = w ? rd16(S[sES], R[rDI]) : rd8(S[sES], R[rDI]);
            sub_flags(a, b, (a - b) & (w ? 0xFFFFu : 0xFFu), w, 0);
            R[rDI] = (uint16_t)(R[rDI] + step);
            break;
        }
        }
        if (!rep) return;
        R[rCX] = (uint16_t)(R[rCX] - 1);
        if (R[rCX] == 0) return;
        if (op == 0xA6 || op == 0xA7 || op == 0xAE || op == 0xAF) {
            /* repe (F3) runs while ZF, repne (F2) while not ZF */
            if ((rep == 0xF3) != getf(fZF)) return;
        }
    }
}

/* ---- execute ------------------------------------------------------------------------------------------------ */

static void execute(uint8_t op, int seg_override, int rep)
{
    Modrm m;

    if (op < 0x40 && (op & 7) < 6) {                 /* the eight ALU ops */
        int kind = op >> 3, form = op & 7, w = form & 1, store;
        uint16_t res;
        if (form < 4) {
            uint32_t a, b;
            m = decode_modrm(seg_override);
            a = rm_read(w, &m);
            b = w ? R[m.reg] : get8(m.reg);
            if (form & 2) {
                res = alu(kind, b, a, w, &store);
                if (store) { if (w) R[m.reg] = res; else set8(m.reg, (uint8_t)res); }
            } else {
                res = alu(kind, a, b, w, &store);
                if (store) rm_write(w, &m, res);
            }
        } else {
            uint32_t imm = w ? fetch16() : fetch8();
            uint32_t a = w ? R[rAX] : get8(rAX);
            res = alu(kind, a, imm, w, &store);
            if (store) { if (w) R[rAX] = res; else set8(rAX, (uint8_t)res); }
        }
        return;
    }

    switch (op) {
    case 0x06: case 0x0E: case 0x16: case 0x1E: push(S[(op >> 3) & 3]); return;
    case 0x07: case 0x17: case 0x1F: S[(op >> 3) & 3] = pop(); return;

    case 0x37: case 0x3F: {                          /* aaa / aas */
        uint8_t al = get8(rAX);
        if ((al & 0x0F) > 9 || getf(fAF)) {
            set8(rAX, (uint8_t)((al + (op == 0x37 ? 6 : -6)) & 0x0F));
            R[rAX] = (uint16_t)(R[rAX] + (op == 0x37 ? 0x100 : -0x100));
            setf(fAF | fCF, 1);
        } else {
            set8(rAX, (uint8_t)(al & 0x0F));
            setf(fAF | fCF, 0);
        }
        return;
    }
    case 0x27: case 0x2F: return;                    /* daa/das: unused by this program */

    case 0x40: case 0x41: case 0x42: case 0x43:
    case 0x44: case 0x45: case 0x46: case 0x47: {
        int i = op & 7, c = getf(fCF);
        uint32_t a = R[i], r = (a + 1) & 0xFFFF;
        add_flags(a, 1, r, 1, 0); setf(fCF, c); R[i] = (uint16_t)r; return;
    }
    case 0x48: case 0x49: case 0x4A: case 0x4B:
    case 0x4C: case 0x4D: case 0x4E: case 0x4F: {
        int i = op & 7, c = getf(fCF);
        uint32_t a = R[i], r = (a - 1) & 0xFFFF;
        sub_flags(a, 1, r, 1, 0); setf(fCF, c); R[i] = (uint16_t)r; return;
    }
    case 0x50: case 0x51: case 0x52: case 0x53:
    case 0x54: case 0x55: case 0x56: case 0x57: push(R[op & 7]); return;
    case 0x58: case 0x59: case 0x5A: case 0x5B:
    case 0x5C: case 0x5D: case 0x5E: case 0x5F: R[op & 7] = pop(); return;

    case 0x70: case 0x71: case 0x72: case 0x73:
    case 0x74: case 0x75: case 0x76: case 0x77:
    case 0x78: case 0x79: case 0x7A: case 0x7B:
    case 0x7C: case 0x7D: case 0x7E: case 0x7F: {
        int8_t d = fetchs8();
        if (condition(op & 0x0F)) IP = (uint16_t)(IP + d);
        return;
    }

    case 0x80: case 0x81: case 0x82: case 0x83: {
        int w = op & 1, store;
        uint32_t a, imm;
        uint16_t res;
        m = decode_modrm(seg_override);
        a = rm_read(w, &m);
        if (op == 0x81)      imm = fetch16();
        else if (op == 0x83) imm = (uint16_t)(int16_t)fetchs8();
        else                 imm = fetch8();
        res = alu(m.reg, a, imm, w, &store);
        if (store) rm_write(w, &m, res);
        return;
    }

    case 0x84: case 0x85: {
        int w = op & 1;
        uint32_t a, b;
        m = decode_modrm(seg_override);
        a = rm_read(w, &m);
        b = w ? R[m.reg] : get8(m.reg);
        logic_flags(a & b, w);
        return;
    }
    case 0x86: case 0x87: {
        int w = op & 1;
        uint16_t a, b;
        m = decode_modrm(seg_override);
        a = rm_read(w, &m);
        b = w ? R[m.reg] : get8(m.reg);
        rm_write(w, &m, b);
        if (w) R[m.reg] = a; else set8(m.reg, (uint8_t)a);
        return;
    }

    case 0x88: case 0x89: case 0x8A: case 0x8B: {
        int w = op & 1;
        m = decode_modrm(seg_override);
        if (op & 2) {
            uint16_t v = rm_read(w, &m);
            if (w) R[m.reg] = v; else set8(m.reg, (uint8_t)v);
        } else {
            rm_write(w, &m, (uint16_t)(w ? R[m.reg] : get8(m.reg)));
        }
        return;
    }
    case 0x8C: m = decode_modrm(seg_override); rm_write(1, &m, S[m.reg & 3]); return;
    case 0x8E: m = decode_modrm(seg_override); S[m.reg & 3] = rm_read(1, &m); return;
    case 0x8D: m = decode_modrm(seg_override); R[m.reg] = m.off; return;
    case 0x8F: m = decode_modrm(seg_override); rm_write(1, &m, pop()); return;

    case 0x90: return;
    case 0x91: case 0x92: case 0x93: case 0x94: case 0x95: case 0x96: case 0x97: {
        int i = op & 7; uint16_t t = R[rAX]; R[rAX] = R[i]; R[i] = t; return;
    }
    case 0x98: { uint8_t v = get8(rAX); R[rAX] = (uint16_t)((v & 0x80) ? (v | 0xFF00) : v); return; }
    case 0x99: R[rDX] = (uint16_t)((R[rAX] & 0x8000) ? 0xFFFF : 0); return;
    case 0x9A: { uint16_t off = fetch16(), seg = fetch16();
                 push(S[sCS]); push(IP); S[sCS] = seg; IP = off; return; }
    case 0x9C: push(FLAGS); return;
    case 0x9D: FLAGS = (uint16_t)(pop() | 0x0002); return;
    case 0x9E: FLAGS = (uint16_t)((FLAGS & 0xFF00) | (get8(4) & 0xD5) | 0x02); return;
    case 0x9F: set8(4, (uint8_t)(FLAGS & 0xFF)); return;

    case 0xA0: case 0xA1: case 0xA2: case 0xA3: {
        int w = op & 1;
        uint16_t off = fetch16();
        uint16_t sg = S[seg_override >= 0 ? seg_override : sDS];
        if (op & 2) { if (w) wr16(sg, off, R[rAX]); else wr8(sg, off, get8(rAX)); }
        else        { if (w) R[rAX] = rd16(sg, off); else set8(rAX, rd8(sg, off)); }
        return;
    }

    case 0xA4: case 0xA5: case 0xA6: case 0xA7:
    case 0xAA: case 0xAB: case 0xAC: case 0xAD: case 0xAE: case 0xAF:
        string_op(op, seg_override, rep); return;

    case 0xA8: case 0xA9: {
        int w = op & 1;
        uint32_t imm = w ? fetch16() : fetch8();
        uint32_t a = w ? R[rAX] : get8(rAX);
        logic_flags(a & imm, w); return;
    }

    case 0xB0: case 0xB1: case 0xB2: case 0xB3:
    case 0xB4: case 0xB5: case 0xB6: case 0xB7: set8(op & 7, fetch8()); return;
    case 0xB8: case 0xB9: case 0xBA: case 0xBB:
    case 0xBC: case 0xBD: case 0xBE: case 0xBF: R[op & 7] = fetch16(); return;

    case 0xC0: case 0xC1: case 0xD0: case 0xD1: case 0xD2: case 0xD3: {
        int w = op & 1, count;
        m = decode_modrm(seg_override);
        if (op == 0xC0 || op == 0xC1)      count = fetch8();
        else if (op == 0xD0 || op == 0xD1) count = 1;
        else                               count = get8(rCX);
        rm_write(w, &m, shift_op(m.reg, rm_read(w, &m), count, w));
        return;
    }

    case 0xC2: case 0xC3: {
        uint16_t n = (op == 0xC2) ? fetch16() : 0;
        IP = pop(); R[rSP] = (uint16_t)(R[rSP] + n); return;
    }
    case 0xCA: case 0xCB: {
        uint16_t n = (op == 0xCA) ? fetch16() : 0;
        IP = pop(); S[sCS] = pop(); R[rSP] = (uint16_t)(R[rSP] + n); return;
    }

    case 0xC4: case 0xC5:
        m = decode_modrm(seg_override);
        R[m.reg] = rd16(m.seg, m.off);
        S[op == 0xC4 ? sES : sDS] = rd16(m.seg, (uint16_t)(m.off + 2));
        return;

    case 0xC6: case 0xC7: {
        int w = op & 1;
        uint16_t imm;
        m = decode_modrm(seg_override);
        imm = (uint16_t)(w ? fetch16() : fetch8());
        rm_write(w, &m, imm); return;
    }

    case 0xCC: interrupt(3); return;
    case 0xCD: interrupt(fetch8()); return;
    case 0xCE: if (getf(fOF)) interrupt(4); return;
    case 0xCF: IP = pop(); S[sCS] = pop(); FLAGS = (uint16_t)(pop() | 0x0002); return;
    case 0xD4: case 0xD5: fetch8(); return;
    case 0xD7: set8(rAX, rd8(S[seg_override >= 0 ? seg_override : sDS],
                             (uint16_t)(R[rBX] + get8(rAX)))); return;

    case 0xE0: case 0xE1: case 0xE2: {
        int8_t d = fetchs8();
        int z;
        R[rCX] = (uint16_t)(R[rCX] - 1);
        z = getf(fZF);
        if (R[rCX] != 0 && (op == 0xE2 || (op == 0xE1 && z) || (op == 0xE0 && !z)))
            IP = (uint16_t)(IP + d);
        return;
    }
    case 0xE3: { int8_t d = fetchs8(); if (R[rCX] == 0) IP = (uint16_t)(IP + d); return; }

    case 0xE4: case 0xE5: case 0xEC: case 0xED: {
        int w = op & 1;
        uint16_t port = (op < 0xEC) ? fetch8() : R[rDX];
        uint8_t v = port_in(port);
        if (w) R[rAX] = (uint16_t)(v | (port_in((uint16_t)(port + 1)) << 8));
        else   set8(rAX, v);
        return;
    }
    case 0xE6: case 0xE7: case 0xEE: case 0xEF: {
        int w = op & 1;
        uint16_t port = (op < 0xEE) ? fetch8() : R[rDX];
        port_out(port, get8(rAX));
        if (w) port_out((uint16_t)(port + 1), (uint8_t)(R[rAX] >> 8));
        return;
    }

    case 0xE8: { int16_t d = (int16_t)fetch16(); push(IP); IP = (uint16_t)(IP + d); note_sprite(); return; }
    case 0xE9: { int16_t d = (int16_t)fetch16(); IP = (uint16_t)(IP + d); return; }
    case 0xEA: { uint16_t off = fetch16(), seg = fetch16(); S[sCS] = seg; IP = off; return; }
    case 0xEB: { int8_t d = fetchs8(); IP = (uint16_t)(IP + d); return; }

    case 0xF4: STOPPED = 1; STATUS = "hlt"; return;
    case 0xF5: setf(fCF, !getf(fCF)); return;
    case 0xF8: setf(fCF, 0); return;
    case 0xF9: setf(fCF, 1); return;
    case 0xFA: setf(fIF, 0); return;
    case 0xFB: setf(fIF, 1); return;
    case 0xFC: setf(fDF, 0); return;
    case 0xFD: setf(fDF, 1); return;

    case 0xF6: case 0xF7: {
        int w = op & 1;
        uint32_t a, mask = w ? 0xFFFFu : 0xFFu;
        m = decode_modrm(seg_override);
        a = rm_read(w, &m);
        switch (m.reg) {
        case 0: case 1: {
            uint32_t imm = w ? fetch16() : fetch8();
            logic_flags(a & imm, w); return;
        }
        case 2: rm_write(w, &m, (uint16_t)(~a & mask)); return;
        case 3: {
            uint32_t r = (uint32_t)(-(int32_t)a) & mask;
            sub_flags(0, a, r, w, 0); setf(fCF, a != 0);
            rm_write(w, &m, (uint16_t)r); return;
        }
        case 4: {
            uint32_t hi;
            if (w) { uint32_t p = (uint32_t)R[rAX] * a;
                     R[rAX] = (uint16_t)p; R[rDX] = (uint16_t)(p >> 16); hi = R[rDX]; }
            else   { uint32_t p = (uint32_t)get8(rAX) * a;
                     R[rAX] = (uint16_t)p; hi = (p >> 8) & 0xFF; }
            setf(fCF | fOF, hi != 0); return;
        }
        case 5: {
            int32_t sa = (int32_t)((a & (w ? 0x8000u : 0x80u)) ? (int32_t)a - (int32_t)(mask + 1) : (int32_t)a);
            if (w) { int32_t sb = (int16_t)R[rAX]; int32_t p = sa * sb;
                     R[rAX] = (uint16_t)p; R[rDX] = (uint16_t)(p >> 16);
                     setf(fCF | fOF, p != (int16_t)p); }
            else   { int32_t sb = (int8_t)get8(rAX); int32_t p = sa * sb;
                     R[rAX] = (uint16_t)p; setf(fCF | fOF, p != (int8_t)p); }
            return;
        }
        case 6: {
            if (a == 0) { interrupt(0); return; }
            if (w) { uint32_t n = ((uint32_t)R[rDX] << 16) | R[rAX];
                     uint32_t q = n / a, rem = n % a;
                     if (q > 0xFFFF) { interrupt(0); return; }
                     R[rAX] = (uint16_t)q; R[rDX] = (uint16_t)rem; }
            else   { uint32_t n = R[rAX], q = n / a, rem = n % a;
                     if (q > 0xFF) { interrupt(0); return; }
                     set8(rAX, (uint8_t)q); set8(4, (uint8_t)rem); }
            return;
        }
        default: {
            int32_t sa = (int32_t)((a & (w ? 0x8000u : 0x80u)) ? (int32_t)a - (int32_t)(mask + 1) : (int32_t)a);
            if (sa == 0) { interrupt(0); return; }
            if (w) { int32_t n = (int32_t)(((uint32_t)R[rDX] << 16) | R[rAX]);
                     int32_t q = n / sa, rem = n - q * sa;
                     R[rAX] = (uint16_t)q; R[rDX] = (uint16_t)rem; }
            else   { int32_t n = (int16_t)R[rAX];
                     int32_t q = n / sa, rem = n - q * sa;
                     set8(rAX, (uint8_t)q); set8(4, (uint8_t)rem); }
            return;
        }
        }
    }

    case 0xFE: case 0xFF: {
        int w = op & 1;
        uint32_t a;
        m = decode_modrm(seg_override);
        a = rm_read(w, &m);
        switch (m.reg) {
        case 0: { int c = getf(fCF); uint32_t r = (a + 1) & (w ? 0xFFFFu : 0xFFu);
                  add_flags(a, 1, r, w, 0); setf(fCF, c); rm_write(w, &m, (uint16_t)r); return; }
        case 1: { int c = getf(fCF); uint32_t r = (a - 1) & (w ? 0xFFFFu : 0xFFu);
                  sub_flags(a, 1, r, w, 0); setf(fCF, c); rm_write(w, &m, (uint16_t)r); return; }
        case 2: push(IP); IP = (uint16_t)a; return;
        case 3: push(S[sCS]); push(IP);
                IP = rd16(m.seg, m.off); S[sCS] = rd16(m.seg, (uint16_t)(m.off + 2)); return;
        case 4: IP = (uint16_t)a; return;
        case 5: IP = rd16(m.seg, m.off); S[sCS] = rd16(m.seg, (uint16_t)(m.off + 2)); return;
        default: push((uint16_t)a); return;
        }
    }

    default:
        STOPPED = 1;
        STATUS = "unimplemented opcode";
        BAD_OP = op;
        BAD_CS = S[sCS];
        BAD_IP = (uint16_t)(IP - 1);
        return;
    }
}

/* One audio sample at the current speaker state. Silence when the gate is shut, so the ring is
   always continuous and the host never has to guess at timing. */
static void audio_sample(void)
{
    int next = (AUDIO_W + 1) % AUDIO_RING;
    int16_t value = 0;
    if ((PORT61 & 0x03) == 0x03 && PIT2_DIVISOR > 0) {
        uint32_t hz = PIT_HZ / PIT2_DIVISOR;
        if (hz > 30 && hz < 12000) {
            /* Two transitions make a cycle, so advance at twice the frequency and flip. */
            SQUARE_PHASE += hz * 2u;
            while (SQUARE_PHASE >= AUDIO_RATE) {
                SQUARE_PHASE -= AUDIO_RATE;
                SQUARE_LEVEL = !SQUARE_LEVEL;
            }
            value = SQUARE_LEVEL ? 8000 : -8000;
            /* Turned down per voice rather than overall, so a host can silence the game's music and
               put its own on while the effects carry on as they were. */
            value = (int16_t)((float)value * VOICE_VOLUME[VOICE]);
        }
    }
    if (next != AUDIO_R) {      /* drop rather than overwrite if the host stopped draining */
        AUDIO[AUDIO_W] = value;
        AUDIO_W = next;
    }
}

static void step(void)
{
    int seg_override = -1, rep = 0;
    uint8_t op;
    /* The end of a hidden blit. It is reached by a near call, so the stack is back above where it stood when
       the call was made as soon as the routine has returned - and every instruction inside it, nested calls
       included, leaves the stack at or below that. */
    if (HIDING && R[rSP] > HIDING_SP) {
        HIDING = 0;
    }
    for (;;) {
        op = fetch8();
        if (op == 0x26) { seg_override = sES; continue; }
        if (op == 0x2E) { seg_override = sCS; continue; }
        if (op == 0x36) { seg_override = sSS; continue; }
        if (op == 0x3E) { seg_override = sDS; continue; }
        if (op == 0xF0) continue;
        if (op == 0xF2 || op == 0xF3) { rep = op; continue; }
        break;
    }
    ICOUNT++;
    execute(op, seg_override, rep);
    AUDIO_ACC += AUDIO_RATE;
    while (AUDIO_ACC >= INSTR_PER_SEC) {
        AUDIO_ACC -= INSTR_PER_SEC;
        audio_sample();
    }
}

/* ---- public API --------------------------------------------------------------------------------------------- */

int alleycat_init(const void *exe_bytes, int exe_size)
{
    const uint8_t *exe = (const uint8_t *)exe_bytes;
    uint16_t pages, relocations, header_pars, bytes_last, table;
    uint32_t header, size;
    uint16_t i;

    if (!PARITY_READY) parity_init();
    if (exe_size < 32 || exe[0] != 'M' || exe[1] != 'Z') return 1;

    memset(MEM, 0, sizeof MEM);
    memset(R, 0, sizeof R);
    memset(S, 0, sizeof S);
    FLAGS = 0x0002; IP = 0; ICOUNT = 0; VIDEO_MODE = -1; STOPPED = 0;
    SCANCODE = 0; PORT61 = 0; RETRACE = 0; KEYQ_HEAD = KEYQ_TAIL = 0;
    HIDING = 0; HIDING_SP = 0;
    VOICE = VOICE_WRITER = ALLEYCAT_VOICE_NONE; SPEAKER_WAS_ON = 0;
    PIT2_DIVISOR = 0; PIT2_HIGH_BYTE_NEXT = 0;
    PIT0_LATCH = 0; PIT0_HIGH_BYTE_NEXT = 0;
    JOY_X = JOY_Y = 0; JOY_BUTTON1 = JOY_BUTTON2 = 0; JOY_FIRED = 0; JOY_TIMING = 0;
    AUDIO_W = AUDIO_R = 0; AUDIO_ACC = 0; SQUARE_PHASE = 0; SQUARE_LEVEL = 0;
    STATUS = "running";
    text_clear();

#define U16(o) ((uint16_t)(exe[(o)] | (exe[(o) + 1] << 8)))
    bytes_last  = U16(2);
    pages       = U16(4);
    relocations = U16(6);
    header_pars = U16(8);
    table       = U16(24);
    header = (uint32_t)header_pars * 16;
    size = (uint32_t)(pages - 1) * 512 + (bytes_last ? bytes_last : 512) - header;
    if (header + size > (uint32_t)exe_size) size = (uint32_t)exe_size - header;

    memcpy(MEM + ((uint32_t)LOAD_SEG << 4), exe + header, size);

    for (i = 0; i < relocations; i++) {
        uint16_t off = U16(table + i * 4);
        uint16_t seg = U16(table + i * 4 + 2);
        uint32_t at = (((uint32_t)(LOAD_SEG + seg)) << 4) + off;
        uint16_t fixed = (uint16_t)((MEM[at] | (MEM[at + 1] << 8)) + LOAD_SEG);
        MEM[at] = (uint8_t)fixed;
        MEM[at + 1] = (uint8_t)(fixed >> 8);
    }

    S[sCS] = (uint16_t)(LOAD_SEG + U16(22));
    IP     = U16(20);
    S[sSS] = (uint16_t)(LOAD_SEG + U16(14));
    R[rSP] = U16(16);
    S[sDS] = S[sES] = PSP_SEG;
#undef U16

    /* A PSP whose first bytes are INT 20h, so a program that returns into it exits. */
    MEM[(uint32_t)PSP_SEG << 4] = 0xCD;
    MEM[((uint32_t)PSP_SEG << 4) + 1] = 0x20;
    /* BIOS data area: equipment word reports a CGA in 80x25, plus the game adapter when the
       host has said there is one. The game reads this once, at startup. */
    MEM[0x410] = 0x21;
    MEM[0x411] = (uint8_t)(JOY_PRESENT ? 0x10 : 0x00);
    return 0;
}

void alleycat_run(int instructions)
{
    int i;
    for (i = 0; i < instructions && !STOPPED; i++) {
        /* Deliver a queued key through the game's own INT 9 handler when it will accept one. */
        if (KEYQ_HEAD != KEYQ_TAIL && getf(fIF)) {
            SCANCODE = KEYQ[KEYQ_HEAD];
            KEYQ_HEAD = (KEYQ_HEAD + 1) % (int)sizeof KEYQ;
            interrupt(9);
        }
        step();
    }
}

void alleycat_update(void) { alleycat_run(TICK_STEPS); }

void alleycat_joystick_present(int present)
{
    JOY_PRESENT = present ? 1 : 0;
    /* Keep a running machine in step with the answer, even though the game only reads the
       equipment word once, so a host that plugs a pad in before the question is asked works. */
    MEM[0x411] = (uint8_t)(JOY_PRESENT ? 0x10 : 0x00);
}

void alleycat_joystick(int x, int y, int button1, int button2)
{
    JOY_X = x < 0 ? -1 : (x > 0 ? 1 : 0);
    JOY_Y = y < 0 ? -1 : (y > 0 ? 1 : 0);
    JOY_BUTTON1 = button1 ? 1 : 0;
    JOY_BUTTON2 = button2 ? 1 : 0;
}

void alleycat_key(int scancode, int down)
{
    int next = (KEYQ_TAIL + 1) % (int)sizeof KEYQ;
    if (next == KEYQ_HEAD) return;                      /* queue full: drop it */
    KEYQ[KEYQ_TAIL] = (uint8_t)(down ? (scancode & 0x7F) : (scancode | 0x80));
    KEYQ_TAIL = next;
}

const uint8_t *alleycat_framebuffer(void)
{
    int y, xb, pair;
    for (y = 0; y < ALLEYCAT_HEIGHT; y++) {
        /* CGA mode 4 interleave: even scanlines at +0x0000, odd at +0x2000, 80 bytes a row. */
        uint32_t row = ((uint32_t)VIDEO_SEG << 4) + ((y & 1) ? 0x2000u : 0u) + (uint32_t)(y >> 1) * 80u;
        for (xb = 0; xb < 80; xb++) {
            uint8_t byte = MEM[row + xb];
            for (pair = 0; pair < 4; pair++)
                FRAME[y * ALLEYCAT_WIDTH + xb * 4 + pair] = (uint8_t)((byte >> (6 - pair * 2)) & 3);
        }
    }
    return FRAME;
}

void alleycat_palette(uint32_t out[4])
{
    /* CGA palette 1, high intensity: black, light cyan, light magenta, white. Which palette the
     * hardware shows is set through port 0x3D9, which this game leaves at the default. */
    out[0] = 0x000000; out[1] = 0x55FFFF; out[2] = 0xFF55FF; out[3] = 0xFFFFFF;
}

/* One row of the BIOS text screen, 0 to 24, NUL terminated. The setup prompts arrive here and
   nowhere else, so a host that does not show this leaves the player looking at a blank screen. */
const char *alleycat_text_row(int row)
{
    if (row < 0 || row >= TEXT_ROWS) return "";
    TEXT[row][TEXT_COLS] = 0;
    return TEXT[row];
}

int alleycat_text_rows(void) { return TEXT_ROWS; }

void alleycat_cursor(int *row, int *col)
{
    if (row) *row = CUR_ROW;
    if (col) *col = CUR_COL;
}

int alleycat_screen_painted(void)
{
    int i, n = 0;
    uint32_t base = (uint32_t)VIDEO_SEG << 4;
    for (i = 0; i < 16384; i++) {
        if (MEM[base + i]) n++;
    }
    return n;
}

/* Both low bits of port 0x61: bit 0 gates the timer, bit 1 connects it to the cone. */
int alleycat_speaker_on(void) { return (PORT61 & 0x03) == 0x03 && PIT2_DIVISOR > 0; }

int alleycat_speaker_hz(void)
{
    if (PIT2_DIVISOR == 0) return 0;
    return (int)(PIT_HZ / PIT2_DIVISOR);
}

int alleycat_audio_rate(void) { return AUDIO_RATE; }

int alleycat_audio_available(void)
{
    return (AUDIO_W - AUDIO_R + AUDIO_RING) % AUDIO_RING;
}

int alleycat_audio_read(int16_t *out, int max_samples)
{
    int n = 0;
    while (n < max_samples && AUDIO_R != AUDIO_W) {
        out[n++] = AUDIO[AUDIO_R];
        AUDIO_R = (AUDIO_R + 1) % AUDIO_RING;
    }
    return n;
}

int alleycat_ready(void) { return VIDEO_MODE >= 0; }
int alleycat_voice(void) { return VOICE; }

/* How many sounds other than the music the game has begun since it booted. A host watches this for "something
   just happened" without knowing what: it only ever goes up, so a change is an event. Deliberately left out
   of the snapshot fields below, because an event count is the host's history rather than the machine's state
   and rewinding it would un-happen things the host has already reacted to. */
unsigned int alleycat_effect_starts(void) { return EFFECT_STARTS; }

/* Bytes the game has written into the CGA window since it booted. A host reads the jump between two of its
   own frames: a few hundred is the cat moving, the whole 16K is a different place. Left out of the snapshot
   for the same reason as the effect count - it is the host's reading of history, not the machine's state. */
unsigned int alleycat_video_writes(void) { return VIDEO_WRITES; }

unsigned int alleycat_data_address(void) { return (unsigned int)S[sDS] << 4; }

void alleycat_where(unsigned int *image_offset, int *interrupts_enabled, int *keys_queued)
{
    if (image_offset) {
        unsigned int at = phys(S[sCS], IP);
        *image_offset = at >= (ALLEYCAT_LOAD_SEG << 4) ? at - (ALLEYCAT_LOAD_SEG << 4) : at;
    }
    if (interrupts_enabled) *interrupts_enabled = getf(fIF) ? 1 : 0;
    if (keys_queued) {
        int n = KEYQ_TAIL - KEYQ_HEAD;
        *keys_queued = n < 0 ? n + (int)sizeof KEYQ : n;
    }
}

int alleycat_poke(unsigned int at, const unsigned char *from, unsigned int length)
{
    if (at >= MEM_SIZE || from == 0) {
        return 0;
    }
    if (length > MEM_SIZE - at) {
        length = MEM_SIZE - at;
    }
    memcpy(MEM + at, from, length);
    return (int)length;
}

/* Watches [from] up to but not including [to]. An empty range turns the watch off, and setting one clears
   what the last watch found, so each hunt starts from nothing. */
void alleycat_watch(unsigned int from, unsigned int to)
{
    WATCH_FROM = from;
    WATCH_TO = to;
    WATCH_WRITER_COUNT = 0;
    WATCH_CALLER_COUNT = 0;
    WATCH_HITS = 0;
}

/* Copies the distinct writers found so far into [into], newest last, and answers how many there were. */
int alleycat_watch_writers(unsigned int *into, int max)
{
    int n = WATCH_WRITER_COUNT < max ? WATCH_WRITER_COUNT : max;
    int i;
    for (i = 0; i < n; i++) {
        into[i] = WATCH_WRITERS[i];
    }
    return n;
}

unsigned int alleycat_watch_hits(void) { return WATCH_HITS; }

void alleycat_report_sprites(int on) { SPRITES_REPORTED = on; alleycat_sprites_begin(); }

/* Starts a fresh frame's worth. A host calls this before letting the machine run, so what it reads back
   afterwards is what was drawn in that frame and nothing older. */
void alleycat_sprites_begin(void) { SPRITE_COUNT = 0; SPRITE_MISSED = 0; }

void alleycat_hide_sprites(const unsigned int *sources, int count)
{
    int i;
    if (sources == 0 || count < 0) { count = 0; }
    if (count > ALLEYCAT_HIDDEN_MAX) { count = ALLEYCAT_HIDDEN_MAX; }
    for (i = 0; i < count; i++) {
        HIDDEN[i] = (uint32_t)sources[i];
    }
    HIDDEN_COUNT = count;
    /* Whatever was being hidden a moment ago may not be on the new list, and a blit already running would
       otherwise stay hidden to the end of itself. */
    HIDING = 0;
}

int alleycat_sprite_count(void) { return SPRITE_COUNT; }

int alleycat_sprite(int index, unsigned int *source, unsigned int *at, unsigned int *size, unsigned int *kind)
{
    if (index < 0 || index >= SPRITE_COUNT) {
        return 0;
    }
    if (source) { *source = SPRITE_SOURCE[index]; }
    if (at)     { *at = SPRITE_AT[index]; }
    if (size)   { *size = SPRITE_SIZE[index]; }
    if (kind)   { *kind = SPRITE_KIND[index]; }
    return 1;
}

/* The routines that called the writers, which is what says what was being drawn rather than how. */
int alleycat_watch_callers(unsigned int *into, int max)
{
    int n = WATCH_CALLER_COUNT < max ? WATCH_CALLER_COUNT : max;
    int i;
    for (i = 0; i < n; i++) {
        into[i] = WATCH_CALLERS[i];
    }
    return n;
}

/* Copies [length] bytes of the machine's memory from [at] into [into]. Answers how many bytes it actually
   copied, which is fewer than asked for at the very top of memory and zero for an address past it. */
int alleycat_peek(unsigned int at, unsigned char *into, unsigned int length)
{
    if (at >= MEM_SIZE || into == 0) {
        return 0;
    }
    if (length > MEM_SIZE - at) {
        length = MEM_SIZE - at;
    }
    memcpy(into, MEM + at, length);
    return (int)length;
}

void alleycat_set_voice_volume(int voice, float volume)
{
    if (voice < 0 || voice > 2) {
        return;
    }
    VOICE_VOLUME[voice] = volume < 0.0f ? 0.0f : volume;
}

/* ---- machine state, for rewinding ---------------------------------------------------------- */

/* Every piece of the machine, named once. Save and load both walk this list, so neither can drift
   out of step with the other and adding a register later means adding it here and nowhere else.

   PARITY is not here because it is a lookup table built from nothing, identical every run. The
   audio ring is not here because it belongs to the host, not the machine: rewinding should not
   push samples back at a host that has already played them. */
#define ALLEYCAT_STATE_FIELDS(X) 	X(MEM) X(R) X(S) X(IP) X(FLAGS) X(ICOUNT) 	X(VIDEO_MODE) X(STATUS) X(FRAME) 	X(TEXT) X(CUR_ROW) X(CUR_COL) 	X(SCANCODE) X(PORT61) X(KEYQ) X(KEYQ_HEAD) X(KEYQ_TAIL) 	X(AUDIO_ACC) X(SQUARE_PHASE) X(SQUARE_LEVEL) 	X(PIT2_DIVISOR) X(PIT2_HIGH_BYTE_NEXT) X(VOICE) X(VOICE_WRITER) X(SPEAKER_WAS_ON) 	X(PIT0_LATCH) X(PIT0_HIGH_BYTE_NEXT) X(RETRACE) 	X(JOY_PRESENT) X(JOY_X) X(JOY_Y) X(JOY_BUTTON1) X(JOY_BUTTON2) 	X(JOY_FIRED) X(JOY_TIMING) 	X(STOPPED) X(BAD_OP) X(BAD_CS) X(BAD_IP) 	X(HIDING) X(HIDING_SP)

size_t alleycat_state_size(void)
{
	size_t total = 0;
#define ALLEYCAT_STATE_ADD(field) total += sizeof(field);
	ALLEYCAT_STATE_FIELDS(ALLEYCAT_STATE_ADD)
#undef ALLEYCAT_STATE_ADD
	return total;
}

void alleycat_save_state(void *dst)
{
	unsigned char *at = (unsigned char *)dst;
#define ALLEYCAT_STATE_SAVE(field) memcpy(at, &(field), sizeof(field)); at += sizeof(field);
	ALLEYCAT_STATE_FIELDS(ALLEYCAT_STATE_SAVE)
#undef ALLEYCAT_STATE_SAVE
}

void alleycat_load_state(const void *src)
{
	const unsigned char *at = (const unsigned char *)src;
#define ALLEYCAT_STATE_LOAD(field) memcpy(&(field), at, sizeof(field)); at += sizeof(field);
	ALLEYCAT_STATE_FIELDS(ALLEYCAT_STATE_LOAD)
#undef ALLEYCAT_STATE_LOAD
}

uint64_t alleycat_instructions(void) { return ICOUNT; }
const char *alleycat_status(void) { return STATUS; }
int alleycat_fault_opcode(void) { return BAD_OP; }
uint32_t alleycat_fault_address(void) { return ((uint32_t)BAD_CS << 16) | BAD_IP; }

#endif /* ALLEYCAT_IMPLEMENTATION */

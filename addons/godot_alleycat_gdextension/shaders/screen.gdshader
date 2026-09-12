shader_type canvas_item;

// Looks for the Alley Cat screen, switched at runtime by AlleyCatScreen.
//
// The game hands over four colours and nothing else: CGA palette 1 at high intensity, which is what
// Alley Cat selects and then never changes. So every look here works from the palette *index* rather
// than from the RGB it arrives as. That is what makes a recolour exact - an amber monitor showing
// four tones, not a hue rotation guessing at what was meant - and it is what lets the drawn looks
// know which pixel is background and which is the cat.

// Black, light cyan, light magenta, white. 0x55 is 1/3 of full, which is where the 0.333s come from.
const vec3 CGA[4] = {
	vec3(0.0, 0.0, 0.0),
	vec3(0.333, 1.0, 1.0),
	vec3(1.0, 0.333, 1.0),
	vec3(1.0, 1.0, 1.0)
};

// How bright each of those four reads on a monitor that only has one colour. Cyan and magenta are
// both "mid" on real hardware but have to stay apart or the artwork turns to mush, so they are
// spread rather than measured.
const float TONE[4] = { 0.0, 0.72, 0.45, 1.0 };

uniform int mode : hint_range(0, 20) = 0;
uniform vec2 frame_size = vec2(320.0, 200.0);
uniform float scanline_depth : hint_range(0.0, 1.0) = 0.35;
// How many of the game's own pixels one halftone dot spans, for the comic look.
// Championship only. The host drives these: the hue is changed by what happens in the game rather
// than by a clock, the two focus points follow whatever is moving, and the wipe runs when the cat is
// lost. A shader cannot know any of that on its own - it sees one frame with no memory of the last.
uniform float stage_hue = 0.0;
uniform vec2 focus_a = vec2(0.5, 0.5);
uniform vec2 focus_b = vec2(0.5, 0.5);
uniform float focus_amount : hint_range(0.0, 1.0) = 0.0;
uniform float wipe : hint_range(0.0, 1.0) = 0.0;
uniform float fill_light : hint_range(0.0, 0.5) = 0.16;

uniform float halftone_cell : hint_range(1.5, 8.0) = 4.0;

// What the comic is printed on. Not pure white - paper never is, and a flat 1.0 next to the ink
// reads as a screen rather than a page.
const vec3 PAPER = vec3(0.94, 0.92, 0.86);

// Which of the four the pixel is. Nearest wins, so a filtered edge still lands on one of them.
int cga_index(vec3 colour) {
	int best = 0;
	float best_distance = 1e9;
	for (int i = 0; i < 4; i++) {
		float d = distance(colour, CGA[i]);
		if (d < best_distance) {
			best_distance = d;
			best = i;
		}
	}
	return best;
}

int index_at(sampler2D tex, vec2 uv) {
	return cga_index(texture(tex, uv).rgb);
}

// True where this pixel sits against a different colour, which is the outline the drawn looks use.
bool on_an_edge(sampler2D tex, vec2 uv, int here) {
	vec2 step_size = 1.0 / frame_size;
	return index_at(tex, uv + vec2(step_size.x, 0.0)) != here
		|| index_at(tex, uv - vec2(step_size.x, 0.0)) != here
		|| index_at(tex, uv + vec2(0.0, step_size.y)) != here
		|| index_at(tex, uv - vec2(0.0, step_size.y)) != here;
}

// Value noise, for grain and wobble. Cheap and good enough: none of this is trying to be film.
float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 within = fract(p);
	vec2 smoothed = within * within * (3.0 - 2.0 * within);
	return mix(
		mix(hash12(cell), hash12(cell + vec2(1.0, 0.0)), smoothed.x),
		mix(hash12(cell + vec2(0.0, 1.0)), hash12(cell + vec2(1.0, 1.0)), smoothed.x),
		smoothed.y);
}

// The 4x4 ordered pattern every 8-bit machine dithered with, as a 0..1 threshold.
float bayer(vec2 pixels) {
	int x = int(mod(pixels.x, 4.0));
	int y = int(mod(pixels.y, 4.0));
	int table[16] = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 };
	return float(table[y * 4 + x]) / 16.0;
}

// Darkens towards the corners, which is most of what sells a lens or a tube.
float vignette(vec2 uv, float strength) {
	vec2 from_centre = uv - 0.5;
	return 1.0 - strength * dot(from_centre, from_centre) * 2.0;
}

// Diagonal pen strokes, denser where more ink is wanted. After misha.cilantro's hand-drawn hatch
// lines on godotshaders.com (CC0), reduced to what a four-tone picture needs.
float hatch(vec2 uv, float ink, float spacing_px) {
	if (ink <= 0.02) {
		return 0.0;
	}
	vec2 pixels = uv * frame_size;
	float along = (pixels.x + pixels.y) * 0.70710678;
	float wobble = (value_noise(vec2(along * 0.15, floor(along / spacing_px))) - 0.5) * 1.6;
	float across = abs(mod(along + wobble, spacing_px) - spacing_px * 0.5);
	// A quarter of the gap at full ink, not half: at this resolution a stroke any heavier than that
	// closes up against its neighbour and the drawing turns into a solid field.
	return 1.0 - smoothstep(0.0, 0.9, across - ink * spacing_px * 0.26);
}

// Whether a white pixel sits against one of the two screened colours, which is where a printed page
// would want an outline. Black neighbours do not count: the drawn line is already there.
bool touches_a_screened_colour(sampler2D tex, vec2 uv) {
	vec2 step_size = 1.0 / frame_size;
	int neighbours[4] = {
		index_at(tex, uv + vec2(step_size.x, 0.0)),
		index_at(tex, uv - vec2(step_size.x, 0.0)),
		index_at(tex, uv + vec2(0.0, step_size.y)),
		index_at(tex, uv - vec2(0.0, step_size.y))
	};
	for (int i = 0; i < 4; i++) {
		if (neighbours[i] == 1 || neighbours[i] == 2) {
			return true;
		}
	}
	return false;
}

// A monitor with one phosphor colour: the four tones, tinted.
vec3 monochrome(int here, vec3 phosphor) {
	return phosphor * TONE[here];
}

// Scanlines and the slight swell of a lit phosphor, for the CRT looks.
vec3 crt(vec3 colour, vec2 uv) {
	float line = 0.5 + 0.5 * cos(uv.y * frame_size.y * 6.2831853);
	return colour * (1.0 - scanline_depth * line) + colour * colour * 0.15;
}

// A Trinitron had no shadow mask - it had vertical wires - so the grille darkens columns rather
// than dots, and each stripe favours one gun.
vec3 aperture_grille(vec3 colour, vec2 uv) {
	float column = fract(uv.x * frame_size.x);
	vec3 stripe = vec3(
		smoothstep(0.0, 0.5, 1.0 - abs(column - 0.166) * 4.0),
		smoothstep(0.0, 0.5, 1.0 - abs(column - 0.5) * 4.0),
		smoothstep(0.0, 0.5, 1.0 - abs(column - 0.833) * 4.0));
	return colour * (0.75 + 0.45 * stripe);
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	int here = cga_index(source.rgb);
	vec3 colour = CGA[here];

	if (mode == 1) {
		// Amber. The P3 phosphor every office terminal used, and the warmest of the monochromes.
		colour = monochrome(here, vec3(1.0, 0.62, 0.13));
		colour = crt(colour, UV);
	} else if (mode == 2) {
		// Green. P1, the one an IBM 5151 showed.
		colour = monochrome(here, vec3(0.25, 1.0, 0.32));
		colour = crt(colour, UV);
	} else if (mode == 3) {
		// Trinitron: the game's own colours behind a grille, which is what a good consumer set did
		// to CGA rather than changing it.
		colour = aperture_grille(colour, UV);
		colour = crt(colour, UV);
	} else if (mode == 4) {
		// Comic: printed rather than drawn. The line is the black the artist already put down, left
		// exactly as thin as they drew it - thickening it was the mistake the first attempt made -
		// and the flat colours are screened the way a press lays them, dots on a 45 degree grid with
		// the bigger dots where more ink is wanted. "Rasterized" in the printing sense of the word.
		if (here == 0) {
			colour = vec3(0.0);
		} else if (here == 3 && touches_a_screened_colour(TEXTURE, UV)) {
			// White objects - the socks and shirts on the line, the highlights on the bins - are
			// paper printed on paper, and would simply disappear. A printer gives them the line that
			// makes them a thing: ink where the white meets a screened colour, and nothing where it
			// already meets the drawn black, which is doing that job itself.
			colour = vec3(0.0);
		} else {
			vec2 pixels = UV * frame_size;
			vec2 turned = vec2(pixels.x + pixels.y, pixels.y - pixels.x) * 0.70710678;
			vec2 within_dot = fract(turned / halftone_cell) - 0.5;
			// How much ink this tone asks for, and the dot that carries it. The square root is what
			// keeps a half-tone looking half covered rather than a quarter: ink goes as area.
			float ink = 1.0 - TONE[here];
			float dot_radius = sqrt(ink) * 0.62;
			float covered = 1.0 - smoothstep(dot_radius - 0.07, dot_radius + 0.07, length(within_dot));
			colour = mix(PAPER, CGA[here] * 0.88, covered);
		}
	} else if (mode == 5) {
		// Cel: one hard step of shade inside each flat area, the way a cel is painted - a single
		// darker band, no gradient - placed where the area meets something darker above and left.
		vec2 step_size = 1.0 / frame_size;
		int above_left = index_at(TEXTURE, UV - step_size);
		if (here != 0 && TONE[above_left] < TONE[here]) {
			colour *= 0.55;
		}
	} else if (mode == 6) {
		// Game Boy. Four tones is four tones, and the DMG's are the most recognisable set of them.
		vec3 dmg[4] = {
			vec3(0.06, 0.22, 0.06), vec3(0.19, 0.38, 0.19),
			vec3(0.55, 0.67, 0.06), vec3(0.61, 0.74, 0.06)
		};
		colour = dmg[3 - here];
	} else if (mode == 7) {
		// Paper: black on white, the way the manual's screenshots were printed.
		colour = vec3(1.0 - TONE[here] * 0.92);
	} else if (mode == 8) {
		// VHS: the tape is not tracking. Lines shear, the colour lags the luma the way composite
		// always did, and there is grain over the lot. After blblblblb's VHS Tape Effect (CC0).
		float line_wobble = (value_noise(vec2(TIME * 8.0, UV.y * 90.0)) - 0.5) * 0.012;
		float bad_patch = step(0.982, value_noise(vec2(TIME * 1.5, floor(UV.y * 50.0))));
		vec2 torn = UV + vec2(line_wobble + bad_patch * 0.05, 0.0);
		// Chroma smears sideways because it was carried at a quarter of the bandwidth.
		vec3 luma = CGA[cga_index(texture(TEXTURE, torn).rgb)];
		vec3 chroma = CGA[cga_index(texture(TEXTURE, torn + vec2(0.006, 0.0)).rgb)];
		colour = vec3(chroma.r, luma.g, mix(luma.b, chroma.b, 0.6));
		colour += (value_noise(UV * frame_size * 2.0 + TIME * 60.0) - 0.5) * 0.16;
		colour *= vignette(UV, 0.55);
	} else if (mode == 9) {
		// Pen and ink: no colour at all, just how hard the nib was pressed.
		float ink = 1.0 - TONE[here];
		float stroke = hatch(UV, ink, 6.0);
		if (here == 0) {
			stroke = 1.0;
		}
		colour = mix(PAPER, vec3(0.07, 0.06, 0.09), stroke);
	} else if (mode == 10) {
		// Dither: the four tones pushed through the 4x4 pattern every 8-bit machine used, so a tone
		// becomes a mix of the two either side of it instead of a flat block.
		float level = TONE[here] * 3.0;
		float low = floor(level);
		float pick = step(bayer(UV * frame_size), level - low);
		int chosen = int(clamp(low + pick, 0.0, 3.0));
		colour = vec3(0.86, 0.88, 0.92) * (chosen == 0 ? 0.0 : TONE[chosen]);
	} else if (mode == 11) {
		// Negative: the photograph the screen never was.
		colour = vec3(1.0) - colour;
	} else if (mode == 12) {
		// Deep fried: saved, posted, saved again. Blocks of eight, colour pushed until it clips.
		vec2 block = floor(UV * frame_size / 8.0) * 8.0 / frame_size;
		vec3 blocky = CGA[index_at(TEXTURE, block + 4.0 / frame_size)];
		colour = clamp(mix(colour, blocky, 0.45) * 1.9 - 0.35, 0.0, 1.0);
		colour += (value_noise(UV * frame_size * 0.5) - 0.5) * 0.1;
	} else if (mode == 13) {
		// Double vision: the guns out of register, which is what a knocked monitor looked like.
		float split = 0.004 + 0.002 * sin(TIME * 1.7);
		colour = vec3(
			CGA[index_at(TEXTURE, UV - vec2(split, 0.0))].r,
			colour.g,
			CGA[index_at(TEXTURE, UV + vec2(split, 0.0))].b);
	} else if (mode == 14) {
		// Nausea: the room will not hold still.
		vec2 swim = UV + vec2(
			sin(UV.y * 9.0 + TIME * 1.3) * 0.006,
			cos(UV.x * 7.0 + TIME * 1.1) * 0.006);
		colour = CGA[index_at(TEXTURE, swim)];
	} else if (mode == 15) {
		// Holofoil: the picture printed on a foil card, catching the light as the card is turned.
		// After the MemeHoloFoil parody on godotshaders.com (CC0). The sheen rides on how light the
		// pixel already is, so it runs over the artwork instead of flooding it.
		float sweep = (UV.x * 1.4 + UV.y) * 2.6 + TIME * 0.35;
		vec3 rainbow = 0.5 + 0.5 * cos(6.2831853 * (sweep + vec3(0.0, 0.33, 0.67)));
		float sheen = pow(0.5 + 0.5 * sin(sweep * 6.2831853), 3.0);
		colour = clamp(colour * 0.8 + rainbow * sheen * (0.3 + TONE[here] * 0.8), 0.0, 1.0);
	} else if (mode == 16) {
		// Film: a print with grain in it, weaving very slightly in the gate.
		vec2 weave = UV + vec2(sin(TIME * 2.3) * 0.0008, cos(TIME * 1.7) * 0.0011);
		colour = CGA[index_at(TEXTURE, weave)];
		colour *= 0.92 + 0.16 * value_noise(UV * frame_size * 3.0 + TIME * 90.0);
		colour = mix(colour, vec3(dot(colour, vec3(0.299, 0.587, 0.114))), 0.25);
		colour *= vignette(UV, 0.7);
	} else if (mode == 17) {
		// Frost: seen through a window that has iced over.
		vec2 ice = UV + vec2(
			value_noise(UV * 22.0) - 0.5,
			value_noise(UV * 22.0 + 31.4) - 0.5) * 0.012;
		colour = CGA[index_at(TEXTURE, ice)];
		colour = mix(colour, vec3(0.78, 0.90, 1.0), 0.22);
	} else if (mode == 18) {
		// Squiggle: redrawn every frame by someone who cannot hold the pen still. The wobble is
		// stepped in time rather than smooth, or it reads as warping rather than as drawing.
		float tick = floor(TIME * 8.0);
		vec2 shaky = UV + vec2(
			value_noise(vec2(UV.y * 40.0, tick)) - 0.5,
			value_noise(vec2(UV.x * 40.0, tick + 9.0)) - 0.5) * 0.01;
		int shaken = index_at(TEXTURE, shaky);
		colour = mix(PAPER, vec3(0.1), 1.0 - TONE[shaken]);
	} else if (mode == 20) {
		// Championship: neon on black, after Pac-Man Championship Edition DX. Three things make that
		// look, and the first attempt here had only one of them.
		//
		// The maze is ONE colour at a time - a whole stage is blue, the next is magenta - rather than
		// a rainbow spread across the screen. The pellets are a warm colour against it, which is the
		// only contrast in the picture. And the glow is wide and soft rather than a tight edge: in
		// the real thing the lines bleed far enough to light the black around them.
		//
		// Alley Cat suits it because its artwork is black line work over two flat fills, so the ink
		// becomes the maze and the white things - laundry, what is in the bins - become the pellets.
		// The hue is the host's to change, and it changes on what happens rather than on a clock: the
		// real thing turns a whole stage a new colour when something in the game says so.
		vec3 maze = 0.5 + 0.5 * cos(6.2831853 * (stage_hue + vec3(0.0, 0.33, 0.67)));
		maze = mix(vec3(0.55), maze, 1.15);
		vec3 pellet = vec3(1.0, 0.82, 0.45);

		// Black only counts as line work where something else is near it. The game blanks the whole
		// screen to ask its questions, and without this that blank is one enormous lit field.
		vec2 near_step = 2.0 / frame_size;
		bool black_is_drawing = index_at(TEXTURE, UV + vec2(near_step.x, 0.0)) != 0
			|| index_at(TEXTURE, UV - vec2(near_step.x, 0.0)) != 0
			|| index_at(TEXTURE, UV + vec2(0.0, near_step.y)) != 0
			|| index_at(TEXTURE, UV - vec2(0.0, near_step.y)) != 0;
		bool is_maze = here == 0 && black_is_drawing;
		bool is_pellet = here == 3;

		// Three rings of it, falling off with distance. Wide and soft is the whole difference between
		// this and a picture with a bright outline drawn round it.
		vec3 spill = vec3(0.0);
		vec2 step_size = 1.0 / frame_size;
		for (int i = 0; i < 12; i++) {
			float angle = float(i) * 0.5235988;
			vec2 direction = vec2(cos(angle), sin(angle));
			for (int ring = 1; ring <= 3; ring++) {
				vec2 at = UV + direction * step_size * float(ring) * 2.2;
				int there = index_at(TEXTURE, at);
				float weight = 1.0 / float(ring * ring);
				if (there == 3) {
					spill += pellet * weight;
				} else if (there == 0) {
					spill += maze * weight * 0.8;
				}
			}
		}
		spill /= 12.0;

		vec3 lamp = is_pellet ? pellet : maze;
		float lit = (is_maze || is_pellet) ? 1.0 : 0.0;

		// The fence and the sky are the floor of the maze, not nothing. Left at almost black they
		// vanished and the picture lost its shape, so they are lifted and tinted towards the stage
		// colour, which is what the floor between the walls does in the real thing.
		vec3 floor_colour = mix(CGA[here], maze, 0.45) * fill_light;

		// Light follows what is moving, the way the real thing keeps a brighter region around the
		// player and the ghosts. The host works out where that is; a shader has one frame and no
		// memory of the last, so it cannot.
		float attention = max(
			1.0 - smoothstep(0.0, 0.28, distance(UV, focus_a)),
			1.0 - smoothstep(0.0, 0.22, distance(UV, focus_b)));
		attention *= focus_amount;

		colour = floor_colour + lamp * lit + spill * 0.85;
		colour += (lamp * lit + spill) * attention * 0.7;
		colour += maze * attention * 0.06;
		colour *= vignette(UV, 0.5);

		// Losing a cat wipes the screen, bright edge first. It is the one moment the game stops being
		// a picture and becomes an announcement.
		if (wipe > 0.0) {
			float edge = wipe * 1.25 - 0.125;
			float behind = smoothstep(edge + 0.02, edge - 0.02, UV.y);
			float at_the_edge = 1.0 - smoothstep(0.0, 0.05, abs(UV.y - edge));
			colour = mix(colour, colour * 0.08, behind);
			colour += (maze + pellet) * 0.5 * at_the_edge;
		}
		colour = clamp(colour, 0.0, 1.0);
	} else if (mode == 19) {
		// Blueprint: white on blue, with the grid the paper came ruled with.
		float ink = 1.0 - TONE[here];
		vec2 pixels = UV * frame_size;
		float grid = max(step(15.0, mod(pixels.x, 16.0)), step(15.0, mod(pixels.y, 16.0)));
		colour = vec3(0.04, 0.16, 0.42) + grid * 0.06;
		colour = mix(colour, vec3(0.85, 0.92, 1.0), ink);
	}

	COLOR = vec4(colour, source.a);
}

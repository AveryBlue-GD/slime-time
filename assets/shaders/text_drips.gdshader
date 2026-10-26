shader_type canvas_item;

// Gives every letter on screen its own goo drips. The pixel font (assets/fonts/pixel.fnt and its
// 2x copy pixel_big.fnt) has drips baked under each glyph, so repeated letters dripped the same
// way; this ignores the baked ones and grows new drips under the letter's bottom row, picked by
// a hash of the letter's place on screen (and its column within the letter) and `seed`. Text that
// stays put keeps its drips; the same letter somewhere else drips differently, and UIKit gives
// `seed` a new value every time a screen opens, so coming back to a screen drips anew.
// A letter whose bottom is a single pixel (4, 1, i, l, T, 7...) rarely drips: a drip there just
// looks like the stroke is too long.
// Anything drawn with another texture (button frames, icons) passes through untouched.

uniform float seed = 0.0;
// Economy.CLEAN_SMALL_TEXT: 8 px text grows no drips (they made C read as Ç); 16 px titles still do.
uniform bool clean_small = true;
// BUG2-05: 16 px text that must read clean (the tagline, ENTER THE HUB) grows no drips; the logo and the big headings keep them.
uniform bool clean_big = false;

varying vec2 world;
varying vec4 tint;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	tint = COLOR;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// The font's alpha at atlas pixel (x, y). (Macros, not functions: a function cannot be handed the built-in TEXTURE.)
#define INK(x, y) texture(TEXTURE, vec2((x), (y)) / atlas).a
// ITER-3 whitelist (UI-41..43): a drip may hang only where it cannot change a letter's reading.
//  STEM: a free-standing vertical stem whose foot has no ink beside it on the last two rows (H K M N R X legs: ink all the way up the column, so not A, whose extended leg read as A-ogonek, not
//        D B P U J Q G O S C, not the serif ends of I, not the points of V W Y, never a lone T / Y / F / P / 1 stem).
//  FLAT: the middle of a flat 5-wide bottom bar (E L Z): NOT USED (macro kept): it read as a cedilla (E -> Ę).
// Digits (main atlas columns 154..210) never drip. Round bottoms never drip. tests/test_title_drips.gd mirrors this.
#define STEM_COLUMN(x) (INK((x), (top + 0.5) * unit) > 0.5 && INK((x), (top + 6.5) * unit) > 0.5 && INK((x), (top + 5.5) * unit) > 0.5 && INK((x) - unit, (top + 6.5) * unit) < 0.5 && INK((x) + unit, (top + 6.5) * unit) < 0.5 && INK((x) - unit, (top + 5.5) * unit) < 0.5 && INK((x) + unit, (top + 5.5) * unit) < 0.5)
#define FLAT_COLUMN(x) (INK((x) - 2.0 * unit, (top + 6.5) * unit) > 0.5 && INK((x) - unit, (top + 6.5) * unit) > 0.5 && INK((x), (top + 6.5) * unit) > 0.5 && INK((x) + unit, (top + 6.5) * unit) > 0.5 && INK((x) + 2.0 * unit, (top + 6.5) * unit) > 0.5 && INK((x) - 3.0 * unit, (top + 6.5) * unit) < 0.5 && INK((x) + 3.0 * unit, (top + 6.5) * unit) < 0.5)
// An empty atlas column: the gap between two glyphs.
#define GLYPH_GAP(x) (INK((x), (top + 0.5) * unit) + INK((x), (top + 1.5) * unit) + INK((x), (top + 2.5) * unit) + INK((x), (top + 3.5) * unit) 	+ INK((x), (top + 4.5) * unit) + INK((x), (top + 5.5) * unit) + INK((x), (top + 6.5) * unit) < 0.5)

void fragment() {
	vec2 atlas = 1.0 / TEXTURE_PIXEL_SIZE;
	// The font atlases: one row of glyphs 9 px tall (7 px letters + 2 px of drips), or 18 at 2x.
	bool small_font = abs(atlas.y - 9.0) < 0.5 && atlas.x > 200.0;
	bool big_font = abs(atlas.y - 18.0) < 0.5 && atlas.x > 400.0;
	// The i18n page (pixel_ext.png, tools/make_font.py): 5 rows of accent room above the same 7 + 2,
	// 14 px tall (28 at 2x). Marks under the baseline (cedilla, ogonek, dot below) are drawn in the
	// body shade, brighter than the baked drips, so they are kept, and no drip grows under them.
	bool ext_small = abs(atlas.y - 14.0) < 0.5 && atlas.x > 200.0;
	bool ext_big = abs(atlas.y - 28.0) < 0.5 && atlas.x > 400.0;
	bool ext = ext_small || ext_big;
	big_font = big_font || ext_big;
	if (small_font || big_font || ext) {
		float unit = big_font ? 2.0 : 1.0;
		float top = ext ? 5.0 : 0.0;
		vec2 px = UV * atlas;
		float row = floor(px.y / unit) - top;
		bool mark = ext && row >= 7.0 && texture(TEXTURE, UV).a > 0.5 && texture(TEXTURE, UV).r > 0.75;
		if (row >= 7.0 && !mark) {
			// Where this glyph's atlas origin lands on screen: the same for every pixel of one
			// letter, different for each letter drawn. The shadow copy (dark, 1 px right on the
			// small font) uses the letter's own place, so its drips match.
			float origin = floor(world.x - px.x + 0.5);
			if (dot(tint.rgb, vec3(0.3, 0.59, 0.11)) < 0.25 && !big_font) {
				origin -= 1.0;
			}
			float column = floor(px.x / unit);
			float bottom = INK(px.x, (top + 6.5) * unit);
			// Whitelisted columns only (STEM_COLUMN / FLAT_COLUMN); about 1 drip per 2-3 letters, picked by the
			// letter's place on screen and `seed` (the text and its shadow agree), 1 or 2 font units long
			// (the atlas holds 2 drip rows). Body coloured with a lit bulb, like the logo's.
			bool others = false;
			bool stop_l = false;
			bool stop_r = false;
			for (int i = 1; i <= 5; i++) {
				float xl = px.x - float(i) * unit;
				float xr = px.x + float(i) * unit;
				if (GLYPH_GAP(xl)) {
					stop_l = true;
				}
				if (GLYPH_GAP(xr)) {
					stop_r = true;
				}
				if (!stop_l && INK(xl, (top + 6.5) * unit) > 0.5) {
					others = true;
				}
				if (!stop_r && INK(xr, (top + 6.5) * unit) > 0.5) {
					others = true;
				}
			}
			bool digit = !ext && column >= 154.0 && column < 211.0;
			bool can = !digit && (others && STEM_COLUMN(px.x));
			// No drip in a column that carries a mark under the baseline.
			if (ext) {
				vec4 under1 = texture(TEXTURE, vec2(px.x, (top + 7.5) * unit) / atlas);
				vec4 under2 = texture(TEXTURE, vec2(px.x, (top + 8.5) * unit) / atlas);
				if ((under1.a > 0.5 && under1.r > 0.75) || (under2.a > 0.5 && under2.r > 0.75)) {
					bottom = 0.0;
				}
			}
			float r = hash(vec2(column + fract(seed * 0.618) * 97.0, origin + seed));
			float drip_len = 0.0;
			if (can && bottom > 0.5 && r < 0.85) {
				drip_len = fract(r * 37.0) < 0.5 ? 1.0 : 2.0;
			}
			if (clean_small && !big_font) {
				drip_len = 0.0;
			}
			if (clean_big && big_font) {
				drip_len = 0.0;
			}
			if (bottom > 0.5 && row - 7.0 < drip_len) {
				// body shade, the last row of a drip lit (the logo's bulb)
				float shade = (row - 7.0 > drip_len - 1.5) ? 244.0 / 255.0 : 215.0 / 255.0;
				COLOR = vec4(vec3(shade) * tint.rgb, tint.a);
			} else {
				COLOR = vec4(0.0);
			}
		}
	}
}

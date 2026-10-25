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
			float bottom = texture(TEXTURE, vec2(px.x, ((top + 6.5) * unit)) / atlas).a;
			// A drip only where a stroke ends going down: the pixel above (row 5) is inked too. Under a curved
			// bottom arc (C S G J U O Q 0 3 5 6 8 9) that is false, so no drip turns them into Ç / Ş.
			float above = texture(TEXTURE, vec2(px.x, (top + 5.5) * unit) / atlas).a;
			if (above < 0.5) {
				bottom = 0.0;
			}
			// A lone bottom pixel: nothing beside it on the letter's bottom row.
			bool lone = texture(TEXTURE, vec2(px.x - unit, (top + 6.5) * unit) / atlas).a < 0.5
				&& texture(TEXTURE, vec2(px.x + unit, (top + 6.5) * unit) / atlas).a < 0.5;
			// No drip in a column that carries a mark under the baseline.
			if (ext) {
				vec4 under1 = texture(TEXTURE, vec2(px.x, (top + 7.5) * unit) / atlas);
				vec4 under2 = texture(TEXTURE, vec2(px.x, (top + 8.5) * unit) / atlas);
				if ((under1.a > 0.5 && under1.r > 0.75) || (under2.a > 0.5 && under2.r > 0.75)) {
					bottom = 0.0;
				}
			}
			float r = hash(vec2(column + fract(seed * 0.618) * 97.0, origin + seed));
			float drip_len = lone ? (r < 0.015 ? 2.0 : (r < 0.06 ? 1.0 : 0.0))
				: (r < 0.2 ? 2.0 : (r < 0.7 ? 1.0 : 0.0));
			if (clean_small && !big_font) {
				drip_len = 0.0;
			}
			if (clean_big && big_font) {
				drip_len = 0.0;
			}
			if (bottom > 0.5 && row - 7.0 < drip_len) {
				COLOR = vec4(vec3(160.0 / 255.0) * tint.rgb, tint.a);
			} else {
				COLOR = vec4(0.0);
			}
		}
	}
}

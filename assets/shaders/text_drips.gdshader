shader_type canvas_item;

// Gives every letter on screen its own goo drips. The pixel font (assets/fonts/pixel.fnt and its
// 2x copy pixel_big.fnt) has drips baked under each glyph, so repeated letters dripped the same
// way; this ignores the baked ones and grows new drips under the letter's bottom row, picked by
// a hash of the letter's place on screen (and its column within the letter). Text that stays put
// keeps its drips; the same letter somewhere else drips differently.
// Anything drawn with another texture (button frames, icons) passes through untouched.

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
	if (small_font || big_font) {
		float unit = big_font ? 2.0 : 1.0;
		vec2 px = UV * atlas;
		float row = floor(px.y / unit);
		if (row >= 7.0) {
			// Where this glyph's atlas origin lands on screen: the same for every pixel of one
			// letter, different for each letter drawn. The shadow copy (dark, 1 px right on the
			// small font) uses the letter's own place, so its drips match.
			float origin = floor(world.x - px.x + 0.5);
			if (dot(tint.rgb, vec3(0.3, 0.59, 0.11)) < 0.25 && !big_font) {
				origin -= 1.0;
			}
			float column = floor(px.x / unit);
			float bottom = texture(TEXTURE, vec2(px.x, (6.5 * unit)) / atlas).a;
			float r = hash(vec2(column, origin));
			float drip_len = r < 0.08 ? 2.0 : (r < 0.3 ? 1.0 : 0.0);
			if (bottom > 0.5 && row - 7.0 < drip_len) {
				COLOR = vec4(vec3(160.0 / 255.0) * tint.rgb, tint.a);
			} else {
				COLOR = vec4(0.0);
			}
		}
	}
}

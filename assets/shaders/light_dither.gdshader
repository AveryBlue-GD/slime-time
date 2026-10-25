shader_type canvas_item;
render_mode blend_add, unshaded;

// Every additive light sprite (the slime's lantern, chalice / coin / ticket glows, hub pools):
// the sprite's smooth radial falloff is cut into 4 steps whose edges are broken up by the same
// world-locked 4x4 Bayer matrix the fog uses (fog.gdshader), so one dithered light vocabulary
// runs through the game and the pattern stays put while the light moves. Tint and strength come
// from the sprite's modulate. No arrays, no texture filtering.

varying vec4 tint;
varying vec2 world_pos;

// The 4x4 Bayer matrix worked out (see fog.gdshader), not looked up.
float bayer4(vec2 pixel) {
	vec2 a = mod(pixel, 2.0);
	vec2 b = mod(floor(pixel / 2.0), 2.0);
	return 4.0 * mod(2.0 * a.x + 3.0 * a.y, 4.0) + mod(2.0 * b.x + 3.0 * b.y, 4.0);
}

void vertex() {
	tint = COLOR;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float a = texture(TEXTURE, UV).a;
	float thr = (bayer4(floor(world_pos)) + 0.5) / 16.0;
	float level = clamp(floor(a * 4.0 + thr) / 4.0, 0.0, 1.0);
	COLOR = vec4(tint.rgb, tint.a * level);
}

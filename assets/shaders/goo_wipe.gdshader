shader_type canvas_item;

// Screen transition: a sheet of goo in the skin's color slides down over the screen with drips
// hanging off its bottom edge, then keeps sliding down and off to reveal the next screen.
// Covered where top < y < bottom + drip(x). `bottom` and `top` run from 0 to about 1.3.
// The goo is textured (marbled shades, drip streaks and bubbles) and the texture slides along
// with the sheet, so it reads as one thick slab of slime.

uniform vec2 screen_size = vec2(320.0, 180.0);
uniform float bottom = 0.0;
uniform float top = 0.0;
// How far the sheet has slid (px), so its texture moves with it.
uniform float slide = 0.0;
uniform vec4 goo : source_color = vec4(0.94, 0.49, 0.18, 1.0);
uniform vec4 goo_dark : source_color = vec4(0.6, 0.25, 0.1, 1.0);
uniform vec4 goo_light : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform vec4 goo_deep : source_color = vec4(0.35, 0.14, 0.06, 1.0);
uniform vec4 goo_highlight : source_color = vec4(1.0, 0.93, 0.8, 1.0);

// The 4x4 Bayer dither matrix (0, 8, 2, 10 / 12, 4, 14, 6 / 3, 11, 1, 9 / 15, 7, 13, 5) worked
// out instead of looked up: arrays indexed at run time fail to compile on many Android GPUs.
float bayer4(vec2 pixel) {
	vec2 a = mod(pixel, 2.0);
	vec2 b = mod(floor(pixel / 2.0), 2.0);
	return 4.0 * mod(2.0 * a.x + 3.0 * a.y, 4.0) + mod(2.0 * b.x + 3.0 * b.y, 4.0);
}

float hash(float x) {
	return fract(sin(x * 91.17) * 43758.5453);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 pixel = floor(UV * screen_size);
	// Drips: each 4 px column hangs a different length below the edge (0-24 px).
	float column = floor(pixel.x / 4.0);
	float drip = floor(pow(hash(column), 2.0) * 24.0);
	float edge = floor(bottom * screen_size.y) + drip;
	float top_edge = floor(top * screen_size.y) - floor(hash(column + 37.0) * 6.0);
	if (pixel.y >= edge || pixel.y < top_edge) {
		discard;
	}
	// Texture coordinates that travel down with the sheet.
	vec2 sheet = vec2(pixel.x, pixel.y - floor(slide));
	float threshold = (bayer4(pixel) + 0.5) / 16.0;

	// Marbling: big, soft, downward-stretched swirls of lighter and darker goo; only the
	// borders between shades are dithered.
	float n = value_noise(sheet / vec2(22.0, 40.0)) * 0.75 + value_noise(sheet / vec2(9.0, 18.0)) * 0.25;
	vec3 rgb = goo.rgb;
	if (n + (threshold - 0.5) * 0.08 < 0.3) {
		rgb = mix(goo.rgb, goo_dark.rgb, 0.55);
	} else if (n + (threshold - 0.5) * 0.08 > 0.68) {
		rgb = mix(goo.rgb, goo_light.rgb, 0.6);
	}
	// Drip streaks: a few wide, faint darker runs.
	if (hash(floor(pixel.x / 6.0) + 11.0) > 0.85) {
		rgb = mix(rgb, goo_dark.rgb, 0.25);
	}

	// Bubbles: about one in four 32 px cells holds a round bubble with a dark rim and a glint.
	vec2 cell = floor(sheet / 32.0);
	if (hash2(cell) > 0.72) {
		vec2 center = cell * 32.0 + 8.0 + floor(vec2(hash2(cell + 3.1), hash2(cell + 7.7)) * 16.0);
		float radius = 3.0 + floor(hash2(cell + 1.3) * 3.0);
		float d = distance(sheet + 0.5, center + 0.5);
		if (d <= radius && d > radius - 1.2) {
			rgb = goo_dark.rgb;
		} else if (d <= radius - 1.2) {
			rgb = mix(goo.rgb, goo_light.rgb, 0.35);
			vec2 glint = center - floor(radius * 0.45);
			if (sheet == glint || sheet == glint + vec2(1.0, 0.0)) {
				rgb = goo_highlight.rgb;
			}
		}
	}

	// Bottom edge: deep rim along the bottom and drip tips, a glint above each drip.
	if (pixel.y >= edge - 1.0) {
		rgb = goo_deep.rgb;
	} else if (pixel.y >= edge - 3.0) {
		rgb = goo_dark.rgb;
	} else if (pixel.y >= edge - 6.0 && mod(pixel.x, 4.0) == 1.0) {
		rgb = goo_highlight.rgb;
	}
	COLOR = vec4(rgb, 1.0);
}

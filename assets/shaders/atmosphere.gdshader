shader_type canvas_item;

// Full-screen overlay: drifting mist (menus) and a dithered vignette that darkens the screen edges.
// Works in screen pixels of the 320x180 base resolution so the bands and dither stay crisp.

uniform vec2 screen_size = vec2(320.0, 180.0);
// 0 = vignette only (in game), 1 = full menu mist.
uniform float mist_strength = 1.0;
// How dark the corners get (0-1).
uniform float vignette_strength = 0.7;
uniform vec4 deep : source_color = vec4(0.078, 0.078, 0.133, 1.0);
uniform vec4 mist : source_color = vec4(0.247, 0.239, 0.341, 1.0);

const float BAYER[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 pixel = floor(UV * screen_size);
	int bx = int(mod(pixel.x, 4.0));
	int by = int(mod(pixel.y, 4.0));
	float threshold = (BAYER[by * 4 + bx] + 0.5) / 16.0;

	// Vignette: distance from the center (wider than tall), stepped into dithered bands.
	vec2 c = (UV - 0.5) * vec2(1.0, screen_size.y / screen_size.x) * 2.0;
	float v = smoothstep(0.45, 1.05, length(c)) * vignette_strength;
	v = floor(v * 6.0 + threshold) / 6.0;

	// Mist: two slow noise layers, banded.
	float n = value_noise(pixel / 34.0 + vec2(TIME * 0.10, TIME * 0.03)) * 0.6
		+ value_noise(pixel / 14.0 - vec2(TIME * 0.17, TIME * 0.05)) * 0.4;
	float band = floor(n * n * 5.0 + threshold * 0.5) / 4.0;
	float mist_alpha = clamp(band, 0.0, 1.0) * 0.45 * mist_strength;

	vec3 rgb = mix(mist.rgb, deep.rgb, v / max(v + mist_alpha, 0.001));
	COLOR = vec4(rgb, clamp(max(v, mist_alpha), 0.0, 1.0));
}

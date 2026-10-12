shader_type canvas_item;

// Palette swap: the slime sheet is drawn in six green goo shades (highlight, light, mid, dark,
// deep shadow, outline); each is replaced by the matching shade of the current skin. The dried
// crust of the dry-up frames (four stone greys) becomes a dull, darker version of the skin's own
// shades, so every slime dries up in its own color. Every other color (eyes, glints, ground
// shadow) is kept.
// With `rainbow` on, the goo instead shows rainbow bands (red, orange, yellow, green, blue,
// violet) that flow across the body from left to right with a slight ripple, like a wave.

uniform vec4 highlight = vec4(0.84, 0.98, 0.73, 1.0);
uniform vec4 light = vec4(0.58, 0.886, 0.439, 1.0);
uniform vec4 mid = vec4(0.22, 0.718, 0.392, 1.0);
uniform vec4 dark = vec4(0.145, 0.443, 0.475, 1.0);
uniform vec4 deep = vec4(0.086, 0.259, 0.322, 1.0);
uniform vec4 outline = vec4(0.047, 0.149, 0.188, 1.0);
uniform bool rainbow = false;
// Jelly test (0 = solid, 1 = see-through): the goo body lets the floor show through, while the
// outline, shine and eyes stay solid so the slime still reads clearly.
uniform float translucency = 0.0;
// Rainbow cycles per second passing any point, and how wide one full rainbow is (px).
uniform float rainbow_speed = 0.45;
uniform float rainbow_width = 16.0;

// No arrays here on purpose: constant and local arrays indexed at run time fail to compile on
// many Android GPUs in the browser (the slime, stations and hats just vanished), so every lookup
// is a plain chain of branches.

// The sheet's six goo shades ("H", "l", "m", "n", "D", "G" in the art script's palette).
const vec3 SRC_H = vec3(214.0, 250.0, 186.0) / 255.0;
const vec3 SRC_L = vec3(148.0, 226.0, 112.0) / 255.0;
const vec3 SRC_M = vec3(56.0, 183.0, 100.0) / 255.0;
const vec3 SRC_N = vec3(37.0, 113.0, 121.0) / 255.0;
const vec3 SRC_D = vec3(22.0, 66.0, 82.0) / 255.0;
const vec3 SRC_G = vec3(12.0, 38.0, 48.0) / 255.0;
// The dry-up crust's greys ("x", "w", "W", "z"), drying from the light, mid, dark and deep shades.
const vec3 CRUST_X = vec3(194.0, 210.0, 222.0) / 255.0;
const vec3 CRUST_W = vec3(148.0, 176.0, 194.0) / 255.0;
const vec3 CRUST_WW = vec3(86.0, 108.0, 134.0) / 255.0;
const vec3 CRUST_Z = vec3(62.0, 74.0, 96.0) / 255.0;
const float MATCH = 0.02;
const float HUE_STEPS = 12.0;

// Which goo shade (0 highlight ... 5 outline) a sheet color is, or -1.
int goo_shade(vec3 c) {
	if (distance(c, SRC_H) < MATCH) { return 0; }
	if (distance(c, SRC_L) < MATCH) { return 1; }
	if (distance(c, SRC_M) < MATCH) { return 2; }
	if (distance(c, SRC_N) < MATCH) { return 3; }
	if (distance(c, SRC_D) < MATCH) { return 4; }
	if (distance(c, SRC_G) < MATCH) { return 5; }
	return -1;
}

// The goo shade a crust grey dried from, or -1.
int crust_source(vec3 c) {
	if (distance(c, CRUST_X) < MATCH) { return 1; }
	if (distance(c, CRUST_W) < MATCH) { return 2; }
	if (distance(c, CRUST_WW) < MATCH) { return 3; }
	if (distance(c, CRUST_Z) < MATCH) { return 4; }
	return -1;
}

// The skin's color for a goo shade.
vec3 skin_shade(int s) {
	if (s == 0) { return highlight.rgb; }
	if (s == 1) { return light.rgb; }
	if (s == 2) { return mid.rgb; }
	if (s == 3) { return dark.rgb; }
	if (s == 4) { return deep.rgb; }
	return outline.rgb;
}

// Rainbow version of each shade: saturation, value.
vec2 rainbow_sv(int s) {
	if (s == 0) { return vec2(0.2, 1.0); }
	if (s == 1) { return vec2(0.45, 1.0); }
	if (s == 2) { return vec2(0.8, 0.95); }
	if (s == 3) { return vec2(0.85, 0.55); }
	if (s == 4) { return vec2(0.9, 0.36); }
	return vec2(0.9, 0.18);
}

// How see-through each goo shade gets at full translucency (highlight ... outline).
float jelly_alpha(int s) {
	if (s == 0) { return 0.9; }
	if (s == 1) { return 0.55; }
	if (s == 2) { return 0.42; }
	if (s == 3) { return 0.52; }
	if (s == 4) { return 0.68; }
	return 1.0;
}

// In fragment(), COLOR already includes the texture, so keep the plain tint (modulate) here.
varying vec4 tint;
// Pixel position within the sprite, so the rainbow moves with the slime.
varying vec2 local_pos;

void vertex() {
	tint = COLOR;
	local_pos = VERTEX;
}

vec3 hsv_to_rgb(float h, float s, float v) {
	vec3 p = abs(fract(vec3(h) + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return v * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), s);
}

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	vec3 rgb = texel.rgb;
	int shade = goo_shade(rgb);
	int crust_from = shade < 0 ? crust_source(rgb) : -1;
	// Dried crust: the goo shade it came from, then dulled and darkened below.
	int source = shade >= 0 ? shade : crust_from;
	if (source >= 0 && rainbow) {
		vec2 p = floor(local_pos);
		float wave = p.x + sin(p.y * 0.6 + TIME * 4.0) * 1.5;
		// Hue falls as time passes, so each color travels toward +x; banded for a pixel look.
		float hue = fract(floor((wave / rainbow_width - TIME * rainbow_speed) * HUE_STEPS) / HUE_STEPS);
		// Red -> violet is the first 5/6 of the hue circle; squeeze it so magenta is skipped.
		hue *= 0.83;
		vec2 sv = rainbow_sv(source);
		rgb = hsv_to_rgb(hue, sv.x, sv.y);
	} else if (source >= 0) {
		rgb = skin_shade(source);
	}
	if (crust_from >= 0) {
		float grey = dot(rgb, vec3(0.3, 0.59, 0.11));
		rgb = mix(vec3(grey), rgb, 0.55) * 0.8;
	}
	float alpha = texel.a;
	if (shade >= 0) {
		alpha *= mix(1.0, jelly_alpha(shade), translucency);
	}
	COLOR = vec4(rgb, alpha) * tint;
}

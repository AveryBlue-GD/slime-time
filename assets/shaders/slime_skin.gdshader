shader_type canvas_item;

// Palette swap: the slime sheet is drawn in six green goo shades (highlight, light, mid, dark,
// deep shadow, outline); each is replaced by the matching shade of the current skin. Every other
// color (eyes, glints, ground shadow, dried crust) is kept.
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

// The sheet's six goo shades ("H", "l", "m", "n", "D", "G" in the art script's palette).
const vec3 SOURCES[6] = {
	vec3(214.0, 250.0, 186.0) / 255.0, vec3(148.0, 226.0, 112.0) / 255.0, vec3(56.0, 183.0, 100.0) / 255.0,
	vec3(37.0, 113.0, 121.0) / 255.0, vec3(22.0, 66.0, 82.0) / 255.0, vec3(12.0, 38.0, 48.0) / 255.0
};
// Rainbow version of each shade: saturation, value.
const vec2 RAINBOW_SV[6] = {vec2(0.2, 1.0), vec2(0.45, 1.0), vec2(0.8, 0.95), vec2(0.85, 0.55), vec2(0.9, 0.36), vec2(0.9, 0.18)};
// How see-through each goo shade gets at full translucency (highlight ... outline).
const float JELLY_ALPHA[6] = {0.9, 0.55, 0.42, 0.52, 0.68, 1.0};
const float MATCH = 0.02;
const float HUE_STEPS = 12.0;

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
	int shade = -1;
	for (int i = 0; i < 6; i++) {
		if (distance(rgb, SOURCES[i]) < MATCH) {
			shade = i;
			break;
		}
	}
	if (shade >= 0 && rainbow) {
		vec2 p = floor(local_pos);
		float wave = p.x + sin(p.y * 0.6 + TIME * 4.0) * 1.5;
		// Hue falls as time passes, so each color travels toward +x; banded for a pixel look.
		float hue = fract(floor((wave / rainbow_width - TIME * rainbow_speed) * HUE_STEPS) / HUE_STEPS);
		// Red -> violet is the first 5/6 of the hue circle; squeeze it so magenta is skipped.
		hue *= 0.83;
		rgb = hsv_to_rgb(hue, RAINBOW_SV[shade].x, RAINBOW_SV[shade].y);
	} else if (shade >= 0) {
		vec4 swaps[6] = {highlight, light, mid, dark, deep, outline};
		rgb = swaps[shade].rgb;
	}
	float alpha = texel.a;
	if (shade >= 0) {
		alpha *= mix(1.0, JELLY_ALPHA[shade], translucency);
	}
	COLOR = vec4(rgb, alpha) * tint;
}

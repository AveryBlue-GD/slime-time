shader_type canvas_item;

// Palette swap: the slime sheet is drawn in three green goo shades; each is replaced by the
// matching shade of the current skin. Every other color (outline, eyes, dried crust) is kept.
// With `rainbow` on, the goo instead shows rainbow bands (red, orange, yellow, green, blue,
// violet) that flow across the body from left to right with a slight ripple, like a wave.

uniform vec4 light = vec4(0.58, 0.886, 0.439, 1.0);
uniform vec4 mid = vec4(0.22, 0.718, 0.392, 1.0);
uniform vec4 dark = vec4(0.145, 0.443, 0.475, 1.0);
uniform bool rainbow = false;
// Rainbow cycles per second passing any point, and how wide one full rainbow is (px).
uniform float rainbow_speed = 0.45;
uniform float rainbow_width = 16.0;

const vec3 SOURCE_LIGHT = vec3(148.0, 226.0, 112.0) / 255.0;
const vec3 SOURCE_MID = vec3(56.0, 183.0, 100.0) / 255.0;
const vec3 SOURCE_DARK = vec3(37.0, 113.0, 121.0) / 255.0;
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
	if (distance(rgb, SOURCE_LIGHT) < MATCH) {
		shade = 0;
	} else if (distance(rgb, SOURCE_MID) < MATCH) {
		shade = 1;
	} else if (distance(rgb, SOURCE_DARK) < MATCH) {
		shade = 2;
	}
	if (shade >= 0 && rainbow) {
		vec2 p = floor(local_pos);
		float wave = p.x + sin(p.y * 0.6 + TIME * 4.0) * 1.5;
		// Hue falls as time passes, so each color travels toward +x; banded for a pixel look.
		float hue = fract(floor((wave / rainbow_width - TIME * rainbow_speed) * HUE_STEPS) / HUE_STEPS);
		// Red -> violet is the first 5/6 of the hue circle; squeeze it so magenta is skipped.
		hue *= 0.83;
		rgb = shade == 0 ? hsv_to_rgb(hue, 0.45, 1.0) : (shade == 1 ? hsv_to_rgb(hue, 0.8, 0.95) : hsv_to_rgb(hue, 0.85, 0.55));
	} else if (shade == 0) {
		rgb = light.rgb;
	} else if (shade == 1) {
		rgb = mid.rgb;
	} else if (shade == 2) {
		rgb = dark.rgb;
	}
	COLOR = vec4(rgb, texel.a) * tint;
}

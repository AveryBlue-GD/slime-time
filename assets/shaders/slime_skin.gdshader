shader_type canvas_item;

// Palette swap: the slime sheet is drawn in three green goo shades; each is replaced by the
// matching shade of the current skin. Every other color (outline, eyes, dried crust) is kept.

uniform vec4 light = vec4(0.58, 0.886, 0.439, 1.0);
uniform vec4 mid = vec4(0.22, 0.718, 0.392, 1.0);
uniform vec4 dark = vec4(0.145, 0.443, 0.475, 1.0);

const vec3 SOURCE_LIGHT = vec3(148.0, 226.0, 112.0) / 255.0;
const vec3 SOURCE_MID = vec3(56.0, 183.0, 100.0) / 255.0;
const vec3 SOURCE_DARK = vec3(37.0, 113.0, 121.0) / 255.0;
const float MATCH = 0.02;

// In fragment(), COLOR already includes the texture, so keep the plain tint (modulate) here.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	vec3 rgb = texel.rgb;
	if (distance(rgb, SOURCE_LIGHT) < MATCH) {
		rgb = light.rgb;
	} else if (distance(rgb, SOURCE_MID) < MATCH) {
		rgb = mid.rgb;
	} else if (distance(rgb, SOURCE_DARK) < MATCH) {
		rgb = dark.rgb;
	}
	COLOR = vec4(rgb, texel.a) * tint;
}

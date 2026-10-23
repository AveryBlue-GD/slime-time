shader_type canvas_item;

// IMP2-01 launch card: the game's boot-colour fog with a dithered round hole that widens from the slime's light
// pocket until the title shows through. Ordered 4x4 dither (no arrays: arithmetic only, safe on every GPU).

uniform vec2 center = vec2(96.0, 146.0);
uniform float radius = 0.0;
uniform float soft = 16.0;
uniform vec4 fog : source_color = vec4(0.101961, 0.109804, 0.172549, 1.0);

float dither2(vec2 p) {
	return fract(p.x * 0.5 + p.y * p.y * 0.75);
}

float bayer4(vec2 px) {
	vec2 q = mod(px, 2.0);
	vec2 h = floor(mod(px, 4.0) * 0.5);
	return dither2(q) + 0.25 * dither2(h);
}

void fragment() {
	vec2 px = floor(UV * vec2(320.0, 180.0));
	float d = distance(px + 0.5, center);
	float edge = radius + (bayer4(px) - 0.5) * soft;
	COLOR = (radius > 0.0 && d < edge) ? vec4(0.0) : fog;
}

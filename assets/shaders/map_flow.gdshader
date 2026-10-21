shader_type canvas_item;

// A map drawn in a flowing paper part (PRISM, RAINBOW; Cosmetics.style_colors): MapView.mark_flow gave
// those pixels alpha 254 (a RAINBOW part also a rainbow laid across it); here their hue turns over
// time in steps, so a PRISM part turns through the colors as one and a RAINBOW part flows. Every other
// pixel is drawn as it is. (No run-time-indexed arrays: fine on every GPU.)

uniform float speed = 0.35;  // full turns of the color wheel per second, as the rainbow hat
const float HUE_STEPS = 12.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	float a = texture(TEXTURE, UV).a;
	if (a > 0.99 && a < 0.998) {
		vec3 hsv = rgb2hsv(COLOR.rgb);
		hsv.x = fract(hsv.x - floor(TIME * speed * HUE_STEPS) / HUE_STEPS);
		COLOR = vec4(hsv2rgb(hsv), COLOR.a / a);
	}
}

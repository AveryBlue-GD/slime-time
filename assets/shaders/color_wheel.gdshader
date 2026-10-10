shader_type canvas_item;

// Hue/saturation wheel in chunky steps: hue goes around, saturation grows outward.
// ColorWheel (scripts/ui/color_wheel.gd) uses the same math to turn clicks into colors.

uniform float value = 1.0;
const float HUE_STEPS = 24.0;
const float SAT_STEPS = 6.0;

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		COLOR = vec4(0.0);
	} else {
		float hue = floor(fract(atan(p.y, p.x) / 6.2831853) * HUE_STEPS) / HUE_STEPS;
		float sat = ceil(r * SAT_STEPS) / SAT_STEPS;
		COLOR = vec4(hsv_to_rgb(vec3(hue, sat, value)), 1.0);
	}
}

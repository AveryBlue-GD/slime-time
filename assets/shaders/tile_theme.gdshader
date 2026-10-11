shader_type canvas_item;

// Level theme: recolors the stone/floor tiles with a gradient map. Each pixel's brightness picks
// a color along dark -> mid -> light, so the art keeps all its shading in the theme's colors.
// Strongly colored details (moss, puddles) keep some of their own color (`keep_color`).

uniform vec4 dark : source_color = vec4(0.1, 0.1, 0.17, 1.0);
uniform vec4 mid : source_color = vec4(0.34, 0.42, 0.53, 1.0);
uniform vec4 light : source_color = vec4(0.76, 0.82, 0.87, 1.0);
// Brightness range of the source art that maps onto the ramp.
uniform float lum_low = 0.1;
uniform float lum_high = 0.8;
uniform float keep_color = 0.4;

void fragment() {
	vec4 c = COLOR;  // already includes the texture
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float t = clamp((l - lum_low) / (lum_high - lum_low), 0.0, 1.0);
	vec3 g = t < 0.5 ? mix(dark.rgb, mid.rgb, t * 2.0) : mix(mid.rgb, light.rgb, t * 2.0 - 1.0);
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	float keep = smoothstep(0.12, 0.35, sat) * keep_color;
	COLOR = vec4(mix(g, c.rgb, keep), c.a);
}

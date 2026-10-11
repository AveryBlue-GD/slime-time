shader_type canvas_item;

// Screen transition: a sheet of goo in the skin's color slides down over the screen with drips
// hanging off its bottom edge, then keeps sliding down and off to reveal the next screen.
// Covered where top < y < bottom + drip(x). `bottom` and `top` run from 0 to about 1.3.

uniform vec2 screen_size = vec2(320.0, 180.0);
uniform float bottom = 0.0;
uniform float top = 0.0;
uniform vec4 goo : source_color = vec4(0.94, 0.49, 0.18, 1.0);
uniform vec4 goo_dark : source_color = vec4(0.6, 0.25, 0.1, 1.0);
uniform vec4 goo_light : source_color = vec4(1.0, 0.8, 0.5, 1.0);

float hash(float x) {
	return fract(sin(x * 91.17) * 43758.5453);
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
	vec3 rgb = goo.rgb;
	if (pixel.y >= edge - 2.0) {
		rgb = goo_dark.rgb;  // dark rim along the bottom and drip tips
	} else if (pixel.y >= edge - 5.0 && mod(pixel.x, 4.0) == 1.0) {
		rgb = goo_light.rgb;  // a glint above each drip
	}
	COLOR = vec4(rgb, 1.0);
}

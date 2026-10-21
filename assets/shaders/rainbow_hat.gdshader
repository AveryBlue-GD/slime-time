shader_type canvas_item;

// The rainbow hat's flowing colors: every colorful pixel (the rainbow's bands, the twinkle's
// points) has its hue turned round over time, so the bands keep their order but flow along the
// arch. Whites (clouds), greys and the dark outline are left as drawn, and so are dyed clouds
// (hat_dyes.png marks them with alpha 254: tools/make_hats.py KEEP_ALPHA). Hues move in steps so
// the pixel art doesn't smear.

uniform float speed = 0.35;  // full turns of the color wheel per second
const float HUE_STEPS = 12.0;
// `gradient` (a hat in the RAINBOW dye, Hats.RAINBOW_GRADIENT): instead of turning every pixel the
// same, a rainbow lies across the hat (one full rainbow every `gradient_width` px, on a slant) and
// flows along it, like the rainbow jelly skin (slime_skin.gdshader), in HUE_STEPS bands.
uniform bool gradient = false;
uniform float gradient_width = 16.0;
uniform float gradient_speed = 0.45;

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
	vec3 hsv = rgb2hsv(COLOR.rgb);
	if (hsv.y > 0.4 && hsv.z > 0.3 && texture(TEXTURE, UV).a > 0.998) {
		if (gradient) {
			// The pixel's place in its 32 x 16 frame (the sheet's frames all start on whole multiples).
			vec2 p = mod(floor(UV / TEXTURE_PIXEL_SIZE), vec2(32.0, 16.0));
			float wave = p.x + p.y * 0.5;
			float hue = fract(floor((wave / gradient_width - TIME * gradient_speed) * HUE_STEPS) / HUE_STEPS);
			hsv.x = fract(hsv.x + hue * 0.83);  // (red to violet, skipping magenta, as the skin does)
		} else {
			hsv.x = fract(hsv.x - floor(TIME * speed * HUE_STEPS) / HUE_STEPS);
		}
		COLOR.rgb = hsv2rgb(hsv);
	}
}

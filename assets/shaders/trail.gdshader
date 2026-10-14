shader_type canvas_item;

// The goo trail: the trail image holds one 2 px cell per painted spot in the skin's goo colors
// (rainbow included). This adds the look of a raised blob lit from the top left: a dark rim on
// the lower/right edges, a bright bevel on the upper/left edges and rare twinkling specks. The
// cell colors are kept, so every skin (and the rainbow) is tinted by what is stored.
// Texture is sampled with nearest filtering; no arrays, 4 extra taps on painted cells only.
// `stars` adds the STARRY trail style's specks (a hash per screen pixel, no texture, no array).

uniform float animate = 1.0;      // 0 = no twinkle (Reduce Motion)
uniform float rim_dark = 0.55;    // brightness of the shaded edge
uniform float bevel_lift = 0.42;  // how far the lit edge moves toward white
uniform float stars = 0.0;        // 1 = the STARRY trail style: 1 px white specks (Cosmetics)

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	if (t.a < 0.01) { discard; }
	vec2 px = TEXTURE_PIXEL_SIZE;
	float up = step(0.01, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
	float lf = step(0.01, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
	float dn = step(0.01, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	float rt = step(0.01, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	vec3 c = t.rgb;
	float a = t.a;
	if (dn < 0.5 || rt < 0.5) {
		c *= rim_dark;
		a = min(1.0, a + 0.3);
	} else if (up < 0.5 || lf < 0.5) {
		c = mix(c, vec3(1.0), bevel_lift);
		a = min(1.0, a + 0.2);
	}
	vec2 cell = floor(UV / px);
	float g = hash(cell);
	if (g > 0.985) {
		float tw = animate > 0.5 ? 0.5 + 0.5 * sin(TIME * 3.0 + g * 80.0) : 0.5;
		c = mix(c, vec3(1.0), 0.35 + 0.4 * tw);
		a = min(1.0, a + 0.25);
	}
	if (stars > 0.5) {
		// STARRY: fixed 1 px specks (each 2 px cell holds 2x2 pixels), picked by a pixel hash.
		float s = hash(floor(UV / px * 2.0) + vec2(37.0, 11.0));
		if (s > 0.94) {
			c = mix(c, vec3(1.0), 0.85);
			a = max(a, 0.9);
		}
	}
	COLOR = vec4(c, a);
}

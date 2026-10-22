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
uniform float fx = 0.0;           // PREVIEW styles: 1 FROST twinkle, 2 TOXIC bubbles, 3 GHOST shimmer

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
	if (fx > 0.5) {
		float t = TIME * animate;
		if (fx < 1.5) {
			// FROST: bright (near-white) cells twinkle, each on its own beat.
			if (dot(c, vec3(1.0)) > 2.6) {
				float tw = 0.5 + 0.5 * sin(t * 4.0 + g * 60.0);
				c = mix(c * 0.85, vec3(1.0), tw);
			}
		} else if (fx < 2.5) {
			// TOXIC: a bubble per 4x4-cell block grows from its center and pops (a 1-cell ring), on its own clock.
			vec2 block = floor(cell / 4.0);
			float bh = hash(block + vec2(5.0, 9.0));
			if (bh > 0.45) {
				float life = fract(t * 0.35 + bh * 7.0);
				vec2 centre = block * 4.0 + vec2(1.0 + floor(bh * 2.0), 1.0 + floor(fract(bh * 13.0) * 2.0));
				float d = length(cell - centre);
				float r = life * 2.2;
				if (life < 0.85 && abs(d - r) < 0.55) {
					c = mix(c, vec3(0.92, 1.0, 0.6), 0.75);
					a = max(a, 0.85);
				} else if (life >= 0.85 && d < 1.6 && hash(cell + vec2(floor(t * 8.0))) > 0.6) {
					c = mix(c, vec3(1.0), 0.6); // the pop: a few specks
					a = max(a, 0.8);
				}
			}
		} else {
			// GHOST: a slow wave of alpha and brightness drifts across the trail.
			float w = 0.5 + 0.5 * sin(t * 1.6 + cell.x * 0.35 + cell.y * 0.22);
			c = mix(c, vec3(1.0), 0.25 * w);
			a *= 0.65 + 0.6 * w;
		}
	}
	COLOR = vec4(c, a);
}

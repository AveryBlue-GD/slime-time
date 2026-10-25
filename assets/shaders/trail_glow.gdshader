shader_type canvas_item;
render_mode blend_add, unshaded;

// The faint glow over the goo trail: an additive copy of the trail image (nearest filtering, no
// blur), plus a one-cell halo around it that is Bayer-checkered into every other pixel instead of
// smoothed (ENV-10). `cell_px` is the screen size of one trail cell. No arrays.

uniform float strength = 0.1;
uniform float cell_px = 2.0;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 t = texture(TEXTURE, UV);
	if (t.a > 0.01) {
		COLOR = vec4(t.rgb, t.a * strength);
	} else {
		vec4 u = texture(TEXTURE, UV + vec2(0.0, -px.y));
		vec4 d = texture(TEXTURE, UV + vec2(0.0, px.y));
		vec4 l = texture(TEXTURE, UV + vec2(-px.x, 0.0));
		vec4 r = texture(TEXTURE, UV + vec2(px.x, 0.0));
		vec4 n = u;
		if (d.a > n.a) { n = d; }
		if (l.a > n.a) { n = l; }
		if (r.a > n.a) { n = r; }
		vec2 p = floor(UV / px * cell_px);
		float checker = mod(p.x + p.y, 2.0);
		if (n.a > 0.01 && checker < 0.5) {
			COLOR = vec4(n.rgb, n.a * strength * 0.8);
		} else {
			discard;
		}
	}
}

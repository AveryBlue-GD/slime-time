shader_type canvas_item;

// Drifting fog over the maze. The texture is plain RGBA8 (phones can't all load float textures),
// one texel per fog cell, holding two 16-bit numbers counted in 1/TICKS second steps
// (packed by game.gd _fog_color):
//   r,g = when the cell was last lit by the slime
//   b,a = (when it was first revealed + 1) * 2 + 1 if it's a wall; 0 = never revealed
// Unexplored cells are fully covered by mist. A newly reached cell clears over `reveal_time`;
// once the slime moves away, lit cells fade back toward mist in steps. Walls use the same steps
// at the same moments, just `wall_shade` thicker. Fog edges are softened by blending
// neighboring cells and dithered so they stay pixel-crisp.

uniform float now;
uniform float wall_shade = 0.3;
uniform float reveal_time = 0.35;
// A cell lit `age` seconds ago is fogged to fade_alpha.x/.y/.z/.w for the first fade_after.x/.y/
// .z/.w it is younger than, or to fade_alpha_last past the last one. (Plain vec4s checked one by
// one, not arrays indexed in a loop: run-time-indexed arrays are a risk on Android WebGL.)
uniform vec4 fade_after = vec4(1.5, 3.5, 6.0, 9.0);
uniform vec4 fade_alpha = vec4(0.0, 0.3, 0.5, 0.65);
uniform float fade_alpha_last = 0.78;
// Hard mode: once a cell has fully dimmed it is covered again like unexplored ground.
uniform bool hard_mode = false;
// Hard mode: a cell lit this long ago is fog again (the last fade step; HEAT FOG BITES halves it).
uniform float refog_after = 9.0;

uniform vec2 map_size;
// World position of the texture's top-left corner (px), so the mist and dither line up between
// the maze's fog and the plain fog that carries on beyond it.
uniform vec2 origin = vec2(0.0);
// A world rect (x, y, w, h; px) left uncovered: the outer fog's hole where the maze's own fog is.
uniform vec4 hole = vec4(0.0);
// The outer fog: its texture is one unrevealed cell, so every tap of the soft edge reads 1.0 and
// the blend is exactly 1.0; skip the taps.
uniform bool solid = false;
uniform vec4 fog_deep = vec4(0.078, 0.078, 0.133, 1.0);
uniform vec4 fog_mist = vec4(0.247, 0.239, 0.341, 1.0);
// The slime's world position (px) and light: the mist is crushed toward black (only a faint tint
// is left in its highlights), already-lit cells dim a little with distance from the slime, and
// the screen edges fall off into a vignette. One vec2, no arrays.
uniform vec2 slime_px = vec2(0.0);
uniform vec2 view_center = vec2(0.0);
uniform float mist_gain = 0.45;
uniform float far_dim = 0.22;
uniform float deep_gain = 0.55;
uniform float vig_max = 0.35;
uniform float light_inner = 32.0;
uniform float light_outer = 115.0;

// LIGHT & LIFE (Economy.LIGHT_LIFE_TEST, BM-09). All of it is skipped while ll_on is false, so the
// old look is pixel-identical. Only plain uniforms and bayer4(): no run-time-indexed arrays.
uniform bool ll_on = false;
uniform sampler2D trail_tex : filter_nearest;
// The lit pocket's tint (theme + skin colour), its strength and radius (px) from the slime.
uniform vec3 ll_tint = vec3(1.0);
uniform float ll_strength = 0.16;
uniform float ll_radius = 44.0;
uniform vec3 ll_glint = vec3(1.0);
// The goal glow colour.
uniform vec3 goal_color = vec3(1.0, 0.82, 0.3);
// Win sunrise: seconds since the win (negative = off), a ring of light sweeping out from the slime.
uniform float sunrise = -1.0;
// false = Reduce Motion: no glint flicker, no sunrise ring.
uniform bool ll_motion = true;
// Light drawn over the slime would wash its skin: none within this radius (px) of the slime's centre.
const float LL_BODY = 10.0;


// The 4x4 Bayer dither matrix (0, 8, 2, 10 / 12, 4, 14, 6 / 3, 11, 1, 9 / 15, 7, 13, 5) worked
// out instead of looked up: arrays indexed at run time fail to compile on many Android GPUs.
float bayer4(vec2 pixel) {
	vec2 a = mod(pixel, 2.0);
	vec2 b = mod(floor(pixel / 2.0), 2.0);
	return 4.0 * mod(2.0 * a.x + 3.0 * a.y, 4.0) + mod(2.0 * b.x + 3.0 * b.y, 4.0);
}
const float DITHER_LEVELS = 8.0;
const float TICKS = 16.0;

// Fog amount for one cell's data (see the channel layout above).
float cell_alpha(vec4 texel) {
	vec4 bytes = floor(texel * 255.0 + 0.5);
	float packed = bytes.b * 256.0 + bytes.a;
	if (packed < 1.0) {
		return 1.0;
	}
	float wall = mod(packed, 2.0);
	float first_revealed = (floor(packed / 2.0) - 1.0) / TICKS;
	float age = now - (bytes.r * 256.0 + bytes.g) / TICKS;
	if (hard_mode && age >= refog_after) {
		return 1.0;
	}
	float alpha = fade_alpha_last;
	if (age < fade_after.x) {
		alpha = fade_alpha.x;
	} else if (age < fade_after.y) {
		alpha = fade_alpha.y;
	} else if (age < fade_after.z) {
		alpha = fade_alpha.z;
	} else if (age < fade_after.w) {
		alpha = fade_alpha.w;
	}
	if (wall > 0.5) {
		alpha += (1.0 - alpha) * wall_shade;
	}
	return max(alpha, 1.0 - clamp((now - first_revealed) / reveal_time, 0.0, 1.0));
}

// x = seconds since the cell was last lit (999 = never revealed), y = 1 for a wall cell.
vec2 cell_age_wall(vec4 texel) {
	vec4 bytes = floor(texel * 255.0 + 0.5);
	float packed = bytes.b * 256.0 + bytes.a;
	if (packed < 1.0) {
		return vec2(999.0, 0.0);
	}
	return vec2(now - (bytes.r * 256.0 + bytes.g) / TICKS, mod(packed, 2.0));
}

// How fresh floor trail sits in the cell next door (0..1): the rim light a wall gets from it.
float rim_from(vec4 fog_texel, vec4 trail_texel) {
	vec2 aw = cell_age_wall(fog_texel);
	if (aw.y > 0.5 || aw.x > 2.5) {
		return 0.0;
	}
	return step(0.01, trail_texel.a) * (1.0 - aw.x / 2.5);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 world_px = UV * map_size + origin;
	if (hole.z > 0.0 && world_px.x >= hole.x && world_px.y >= hole.y
			&& world_px.x < hole.x + hole.z && world_px.y < hole.y + hole.w) {
		discard;
	}
	float alpha = 1.0;
	if (!solid) {
		vec2 t = TEXTURE_PIXEL_SIZE;
		// Soft edge: weighted blend of this cell and its neighbors (13 taps, ~3 cells wide).
		alpha = cell_alpha(texture(TEXTURE, UV)) * 4.0;
		alpha += 2.0 * (cell_alpha(texture(TEXTURE, UV + vec2(t.x, 0.0))) + cell_alpha(texture(TEXTURE, UV - vec2(t.x, 0.0)))
			+ cell_alpha(texture(TEXTURE, UV + vec2(0.0, t.y))) + cell_alpha(texture(TEXTURE, UV - vec2(0.0, t.y))));
		alpha += cell_alpha(texture(TEXTURE, UV + t)) + cell_alpha(texture(TEXTURE, UV - t))
			+ cell_alpha(texture(TEXTURE, UV + vec2(t.x, -t.y))) + cell_alpha(texture(TEXTURE, UV + vec2(-t.x, t.y)));
		alpha += cell_alpha(texture(TEXTURE, UV + vec2(2.0 * t.x, 0.0))) + cell_alpha(texture(TEXTURE, UV - vec2(2.0 * t.x, 0.0)))
			+ cell_alpha(texture(TEXTURE, UV + vec2(0.0, 2.0 * t.y))) + cell_alpha(texture(TEXTURE, UV - vec2(0.0, 2.0 * t.y)));
		alpha /= 20.0;
	}

	// Dither in world pixels so the pattern stays put as the camera moves.
	vec2 pixel = floor(world_px);
	float threshold = (bayer4(pixel) + 0.5) / 16.0;
	alpha = clamp(floor(alpha * DITHER_LEVELS + threshold) / DITHER_LEVELS, 0.0, 1.0);

	// Light falloff: lit ground far from the slime dims toward the fog (never fully), and a
	// soft vignette darkens everything toward the edges of the view.
	float d = distance(world_px, slime_px);
	float falloff = smoothstep(light_inner, light_outer, d);
	alpha = max(alpha, far_dim * falloff * step(alpha, 0.999));
	float vd = length((world_px - view_center) / vec2(176.0, 100.0));
	float vig = smoothstep(0.55, 1.15, vd) * vig_max;
	alpha = max(alpha, vig * step(alpha, 0.999));

	// LIGHT & LIFE: light (rgb, a) added in the clear, plus rim light on walls and a sunrise ring in the fog.
	vec4 ll = vec4(0.0);
	float rim = 0.0;
	float sun = 0.0;
	if (ll_on && !solid) {
		float thr = (bayer4(pixel) + 0.5) / 16.0;
		vec2 aw = cell_age_wall(texture(TEXTURE, UV));
		if (alpha <= 0.0) {
			// Tinted pocket: a dithered falloff, small and faint.
			float t = clamp(1.0 - d / ll_radius, 0.0, 1.0);
			ll = vec4(ll_tint, floor(t * 4.0 + thr) / 4.0 * ll_strength);
			if (d < LL_BODY) {
				ll = vec4(0.0);
			}
			// Glints on fresh trail: single pixels that flicker and fade with the trail's age.
			if (ll_motion && aw.y < 0.5 && aw.x < 3.5 && texture(trail_tex, UV).a > 0.01) {
				if (d >= LL_BODY && hash(pixel + floor(now * 5.0)) > 0.965) {
					ll = vec4(ll_glint, 0.55 * (1.0 - aw.x / 3.5));
				}
			}
		} else if (aw.y > 0.5) {
			// Rim light: a wall cell beside fresh trail is lit by it.
			vec2 t2 = TEXTURE_PIXEL_SIZE;
			float r = max(max(rim_from(texture(TEXTURE, UV + vec2(t2.x, 0.0)), texture(trail_tex, UV + vec2(t2.x, 0.0))), rim_from(texture(TEXTURE, UV - vec2(t2.x, 0.0)), texture(trail_tex, UV - vec2(t2.x, 0.0)))),
				max(rim_from(texture(TEXTURE, UV + vec2(0.0, t2.y)), texture(trail_tex, UV + vec2(0.0, t2.y))), rim_from(texture(TEXTURE, UV - vec2(0.0, t2.y)), texture(trail_tex, UV - vec2(0.0, t2.y)))));
			rim = step(thr, r);
		}
		if (ll_motion && sunrise >= 0.0) {
			float band = 1.0 - abs(d - sunrise * 220.0) / 9.0;
			sun = step(thr, clamp(band, 0.0, 1.0) * clamp(1.5 - sunrise, 0.0, 1.0));
		}
	}
	if (alpha <= 0.0) {
		// Fully clear: blending leaves what is underneath whatever the color, so skip the mist.
		COLOR = vec4(0.0);
		if (ll.a > 0.0) {
			COLOR = ll;
		}
		if (sun > 0.0) {
			COLOR = vec4(goal_color, 0.5);
		}
	} else {
		// Drifting mist: two layers of noise moving at different speeds, banded for a pixel look.
		float n = value_noise(pixel / 30.0 + vec2(now * 0.12, now * 0.04)) * 0.65
			+ value_noise(pixel / 12.0 - vec2(now * 0.2, now * 0.07)) * 0.35;
		// A third, much larger and slower layer swells the mist in broad patches for depth.
		float swell = value_noise(pixel / 90.0 + vec2(now * 0.03, -now * 0.02));
		float band = floor(n * n * 5.0 * (0.7 + 0.6 * swell)) / 4.0;
		vec3 rgb = mix(fog_deep.rgb * deep_gain, fog_mist.rgb * mist_gain, clamp(band, 0.0, 1.0));
		rgb = mix(rgb, vec3(0.0), vig * step(0.999, alpha));
		if (ll_on && !solid) {
			alpha *= 1.0 - 0.7 * rim;  // (IMP3-07: strong enough to read at 1x)
			rgb = mix(rgb, ll_tint, 0.6 * rim);
			alpha *= 1.0 - 0.5 * sun;
			rgb = mix(rgb, goal_color, 0.5 * sun);
		}
		COLOR = vec4(rgb, alpha);
	}
}

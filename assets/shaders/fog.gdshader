shader_type canvas_item;

// Drifting fog over the maze. The texture has one texel per fog cell:
//   r = game time (seconds) the cell was last lit by the slime
//   g = -1 never revealed, 0 floor/goo, 1 wall
//   b = game time the cell was first revealed
// Unexplored cells are fully covered by mist. A newly reached cell clears over `reveal_time`;
// once the slime moves away, lit cells fade back toward mist in steps. Walls use the same steps
// at the same moments, just `wall_shade` thicker. Fog edges are softened by blending
// neighboring cells and dithered so they stay pixel-crisp. A glowing slime (custom skin, after
// beating the game) also lights rings of colored light around itself.

uniform float now;
uniform float wall_shade = 0.3;
uniform float reveal_time = 0.35;
// A cell lit `age` seconds ago is fogged to fade_alpha[i] for the first fade_after[i]
// it is younger than, or to fade_alpha[LAYERS - 1] past the last one.
const int LAYERS = 5;
uniform float fade_after[4];
uniform float fade_alpha[5];
// Hard mode: once a cell has fully dimmed it is covered again like unexplored ground.
uniform bool hard_mode = false;

uniform vec2 map_size;
uniform vec4 fog_deep = vec4(0.078, 0.078, 0.133, 1.0);
uniform vec4 fog_mist = vec4(0.247, 0.239, 0.341, 1.0);

uniform vec2 glow_pos;
uniform float glow_radius = 0.0;
uniform vec4 glow_color = vec4(1.0);

const float BAYER[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};
const float DITHER_LEVELS = 8.0;

// Fog amount for one cell's data (see the channel layout above).
float cell_alpha(vec3 cell) {
	if (cell.g < 0.0) {
		return 1.0;
	}
	float age = now - cell.r;
	if (hard_mode && age >= fade_after[LAYERS - 2]) {
		return 1.0;
	}
	float alpha = fade_alpha[LAYERS - 1];
	for (int i = 0; i < LAYERS - 1; i++) {
		if (age < fade_after[i]) {
			alpha = fade_alpha[i];
			break;
		}
	}
	if (cell.g > 0.5) {
		alpha += (1.0 - alpha) * wall_shade;
	}
	return max(alpha, 1.0 - clamp((now - cell.b) / reveal_time, 0.0, 1.0));
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
	vec2 t = TEXTURE_PIXEL_SIZE;
	// Soft edge: weighted blend of this cell and its neighbors (13 taps, ~3 cells wide).
	float alpha = cell_alpha(texture(TEXTURE, UV).rgb) * 4.0;
	alpha += 2.0 * (cell_alpha(texture(TEXTURE, UV + vec2(t.x, 0.0)).rgb) + cell_alpha(texture(TEXTURE, UV - vec2(t.x, 0.0)).rgb)
		+ cell_alpha(texture(TEXTURE, UV + vec2(0.0, t.y)).rgb) + cell_alpha(texture(TEXTURE, UV - vec2(0.0, t.y)).rgb));
	alpha += cell_alpha(texture(TEXTURE, UV + t).rgb) + cell_alpha(texture(TEXTURE, UV - t).rgb)
		+ cell_alpha(texture(TEXTURE, UV + vec2(t.x, -t.y)).rgb) + cell_alpha(texture(TEXTURE, UV + vec2(-t.x, t.y)).rgb);
	alpha += cell_alpha(texture(TEXTURE, UV + vec2(2.0 * t.x, 0.0)).rgb) + cell_alpha(texture(TEXTURE, UV - vec2(2.0 * t.x, 0.0)).rgb)
		+ cell_alpha(texture(TEXTURE, UV + vec2(0.0, 2.0 * t.y)).rgb) + cell_alpha(texture(TEXTURE, UV - vec2(0.0, 2.0 * t.y)).rgb);
	alpha /= 20.0;

	// Dither in world pixels so the pattern stays put as the camera moves.
	vec2 pixel = floor(UV * map_size);
	int bx = int(mod(pixel.x, 4.0));
	int by = int(mod(pixel.y, 4.0));
	float threshold = (BAYER[by * 4 + bx] + 0.5) / 16.0;
	alpha = clamp(floor(alpha * DITHER_LEVELS + threshold) / DITHER_LEVELS, 0.0, 1.0);

	// Drifting mist: two layers of noise moving at different speeds, banded for a pixel look.
	float n = value_noise(pixel / 30.0 + vec2(now * 0.12, now * 0.04)) * 0.65
		+ value_noise(pixel / 12.0 - vec2(now * 0.2, now * 0.07)) * 0.35;
	float band = floor(n * n * 5.0) / 4.0;
	vec3 rgb = mix(fog_deep.rgb, fog_mist.rgb, clamp(band, 0.0, 1.0));

	if (glow_radius > 0.0) {
		vec2 here = floor(UV * map_size / 2.0) * 2.0 + 1.0;
		float d = distance(here, glow_pos) / glow_radius;
		if (d < 1.0) {
			float ring = d < 0.4 ? 0.1 : (d < 0.7 ? 0.35 : 0.65);
			alpha = min(alpha, ring);
			// Tint: the mist takes on the slime's color, and lit ground gets a faint wash.
			rgb = mix(rgb, glow_color.rgb * 0.5, 0.6);
			alpha = max(alpha, 0.14 * (1.0 - d));
		}
	}
	COLOR = vec4(rgb, alpha);
}

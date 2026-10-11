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
// A cell lit `age` seconds ago is fogged to fade_alpha[i] for the first fade_after[i]
// it is younger than, or to fade_alpha[LAYERS - 1] past the last one.
const int LAYERS = 5;
uniform float fade_after[4];
uniform float fade_alpha[5];
// Hard mode: once a cell has fully dimmed it is covered again like unexplored ground.
uniform bool hard_mode = false;

uniform vec2 map_size;
// World position of the texture's top-left corner (px), so the mist and dither line up between
// the maze's fog and the plain fog that carries on beyond it.
uniform vec2 origin = vec2(0.0);
// A world rect (x, y, w, h; px) left uncovered: the outer fog's hole where the maze's own fog is.
uniform vec4 hole = vec4(0.0);
uniform vec4 fog_deep = vec4(0.078, 0.078, 0.133, 1.0);
uniform vec4 fog_mist = vec4(0.247, 0.239, 0.341, 1.0);


const float BAYER[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};
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
	if (wall > 0.5) {
		alpha += (1.0 - alpha) * wall_shade;
	}
	return max(alpha, 1.0 - clamp((now - first_revealed) / reveal_time, 0.0, 1.0));
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
	vec2 t = TEXTURE_PIXEL_SIZE;
	// Soft edge: weighted blend of this cell and its neighbors (13 taps, ~3 cells wide).
	float alpha = cell_alpha(texture(TEXTURE, UV)) * 4.0;
	alpha += 2.0 * (cell_alpha(texture(TEXTURE, UV + vec2(t.x, 0.0))) + cell_alpha(texture(TEXTURE, UV - vec2(t.x, 0.0)))
		+ cell_alpha(texture(TEXTURE, UV + vec2(0.0, t.y))) + cell_alpha(texture(TEXTURE, UV - vec2(0.0, t.y))));
	alpha += cell_alpha(texture(TEXTURE, UV + t)) + cell_alpha(texture(TEXTURE, UV - t))
		+ cell_alpha(texture(TEXTURE, UV + vec2(t.x, -t.y))) + cell_alpha(texture(TEXTURE, UV + vec2(-t.x, t.y)));
	alpha += cell_alpha(texture(TEXTURE, UV + vec2(2.0 * t.x, 0.0))) + cell_alpha(texture(TEXTURE, UV - vec2(2.0 * t.x, 0.0)))
		+ cell_alpha(texture(TEXTURE, UV + vec2(0.0, 2.0 * t.y))) + cell_alpha(texture(TEXTURE, UV - vec2(0.0, 2.0 * t.y)));
	alpha /= 20.0;

	// Dither in world pixels so the pattern stays put as the camera moves.
	vec2 pixel = floor(world_px);
	int bx = int(mod(pixel.x, 4.0));
	int by = int(mod(pixel.y, 4.0));
	float threshold = (BAYER[by * 4 + bx] + 0.5) / 16.0;
	alpha = clamp(floor(alpha * DITHER_LEVELS + threshold) / DITHER_LEVELS, 0.0, 1.0);

	// Drifting mist: two layers of noise moving at different speeds, banded for a pixel look.
	float n = value_noise(pixel / 30.0 + vec2(now * 0.12, now * 0.04)) * 0.65
		+ value_noise(pixel / 12.0 - vec2(now * 0.2, now * 0.07)) * 0.35;
	// A third, much larger and slower layer swells the mist in broad patches for depth.
	float swell = value_noise(pixel / 90.0 + vec2(now * 0.03, -now * 0.02));
	float band = floor(n * n * 5.0 * (0.7 + 0.6 * swell)) / 4.0;
	vec3 rgb = mix(fog_deep.rgb, fog_mist.rgb, clamp(band, 0.0, 1.0));

	COLOR = vec4(rgb, alpha);
}

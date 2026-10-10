shader_type canvas_item;

// Darkness over the maze. The texture has one texel per fog cell:
//   r = game time (seconds) the cell was last lit by the slime
//   g = -1 never revealed (black), 0 floor/goo, 1 wall
// Lit cells fade back toward darkness in steps the longer the slime stays away. Walls use the
// same steps at the same moments, just `wall_shade` darker, so floor and walls dim together.
// A glowing slime (custom skin, after beating the game) also lights rings of colored light
// around itself, even over unexplored ground; that light leaves no memory behind.

uniform float now;
uniform float wall_shade = 0.3;
// A cell lit `age` seconds ago is darkened to fade_alpha[i] for the first fade_after[i]
// it is younger than, or to fade_alpha[LAYERS - 1] past the last one.
const int LAYERS = 5;
uniform float fade_after[4];
uniform float fade_alpha[5];

uniform vec2 map_size;
uniform vec2 glow_pos;
uniform float glow_radius = 0.0;
uniform vec4 glow_color = vec4(1.0);

void fragment() {
	vec2 cell = texture(TEXTURE, UV).rg;
	float alpha = 1.0;
	if (cell.g >= 0.0) {
		float age = now - cell.r;
		alpha = fade_alpha[LAYERS - 1];
		for (int i = 0; i < LAYERS - 1; i++) {
			if (age < fade_after[i]) {
				alpha = fade_alpha[i];
				break;
			}
		}
		if (cell.g > 0.5) {
			alpha += (1.0 - alpha) * wall_shade;
		}
	}

	vec3 rgb = vec3(0.0);
	if (glow_radius > 0.0) {
		// Snap to the fog grid so the light rings stay pixel-crisp.
		vec2 here = floor(UV * map_size / 2.0) * 2.0 + 1.0;
		float d = distance(here, glow_pos) / glow_radius;
		if (d < 1.0) {
			float ring = d < 0.4 ? 0.1 : (d < 0.7 ? 0.35 : 0.65);
			alpha = min(alpha, ring);
			// Tint: the darkness takes on the slime's color, and lit ground gets a faint wash.
			rgb = glow_color.rgb * 0.35;
			alpha = max(alpha, 0.14 * (1.0 - d));
		}
	}
	COLOR = vec4(rgb, alpha);
}

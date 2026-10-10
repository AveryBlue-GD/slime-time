shader_type canvas_item;

// Darkness over the maze. The texture has one texel per fog cell:
//   r = game time (seconds) the cell was last lit by the slime
//   g = brightest the cell can be (0 for goo, WALL_FOG_ALPHA for walls), or -1 if never revealed
// Lit cells fade back toward darkness in steps the longer the slime stays away.

uniform float now;
// A cell lit `age` seconds ago is darkened to fade_alpha[i] for the first fade_after[i]
// it is younger than, or to fade_alpha[LAYERS - 1] past the last one.
const int LAYERS = 5;
uniform float fade_after[4];
uniform float fade_alpha[5];

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
		alpha = max(alpha, cell.g);
	}
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}

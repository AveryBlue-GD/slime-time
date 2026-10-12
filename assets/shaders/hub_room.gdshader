shader_type canvas_item;

// The hub room, drawn live so the whole building turns with `turn` (radians), not just the
// stations. It's a round room seen at a slant (an ellipse on screen, `radii`), shaped like a slime:
// - floor: jelly-cube tiles laid out on the room's own floor plan, so they swing round as it
//   turns, with variety per tile (lighter or darker cubes, cracked ones, bubbly ones, goo puddles),
//   a lit top edge and a glint;
// - rim: a thick band of glossy goo whose lumpy inner edge, speckles and the drips running off the
//   front all turn with the room, while its shading and the shine streak stay put (the light
//   doesn't move);
// - everything in the skin's six goo shades; with the rainbow skin (`rainbow`), each pixel keeps its
//   brightness but takes a hue from rainbow bands laid across the floor plan, flowing slowly and
//   turning with the room, like the rainbow slime.
// Drawn on a 320x180 rect; each screen pixel is worked out at its center so it stays crisp.

uniform vec2 center = vec2(160.0, 98.0);
uniform vec2 radii = vec2(154.0, 78.0);
uniform float turn = 0.0;
uniform float tile_size = 13.0;
uniform vec4 highlight : source_color = vec4(0.84, 0.98, 0.73, 1.0);
uniform vec4 light : source_color = vec4(0.58, 0.886, 0.439, 1.0);
uniform vec4 mid : source_color = vec4(0.22, 0.718, 0.392, 1.0);
uniform vec4 dark : source_color = vec4(0.145, 0.443, 0.475, 1.0);
uniform vec4 deep : source_color = vec4(0.086, 0.259, 0.322, 1.0);
uniform vec4 outline : source_color = vec4(0.047, 0.149, 0.188, 1.0);
uniform vec4 background : source_color = vec4(0.07, 0.06, 0.1, 1.0);
uniform bool rainbow = false;
// The fog the room floats in (the dungeon's, as in the mazes): drifting banded mist all round it.
uniform vec4 fog_deep : source_color = vec4(0.078, 0.078, 0.133, 1.0);
uniform vec4 fog_mist : source_color = vec4(0.247, 0.239, 0.341, 1.0);
uniform float rainbow_speed = 0.05;
const float HUE_STEPS = 12.0;

vec3 hsv_to_rgb(float h, float s, float v) {
	vec3 p = abs(fract(vec3(h) + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return v * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), s);
}

// The rainbow skin's version of a shaded color: same brightness, the band's hue (red to violet).
vec3 rainbow_of(vec3 col, vec2 plan) {
	float hue = fract(floor((plan.x * 0.6 + plan.y * 0.35 - TIME * rainbow_speed) * HUE_STEPS) / HUE_STEPS) * 0.83;
	float v = max(col.r, max(col.g, col.b));
	return hsv_to_rgb(hue, mix(0.9, 0.25, v * v), v);
}


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Where the rim starts (0..1 of the room's radius) at a given floor-plan angle: a lumpy goo bank.
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// The maze fog's mist (fog.gdshader): two drifting noise layers and a slow swell, banded.
vec3 mist(vec2 pixel) {
	float now = TIME;
	float n = value_noise(pixel / 30.0 + vec2(now * 0.12, now * 0.04)) * 0.65
		+ value_noise(pixel / 12.0 - vec2(now * 0.2, now * 0.07)) * 0.35;
	float swell = value_noise(pixel / 90.0 + vec2(now * 0.03, -now * 0.02));
	float band = floor(n * n * 5.0 * (0.7 + 0.6 * swell)) / 4.0;
	return mix(fog_deep.rgb * 0.35, fog_mist.rgb * 0.25, clamp(band, 0.0, 1.0));
}

float rim_inner(float plan_angle) {
	return 0.925 + 0.012 * sin(plan_angle * 9.0) + 0.007 * sin(plan_angle * 23.0 + 1.0);
}

vec3 floor_tile(vec2 plan) {
	vec2 t = plan * radii.x / tile_size;
	vec2 cell = floor(t);
	vec2 f = fract(t);
	float h = hash(cell);
	vec3 col = deep.rgb;
	if (h < 0.14) {
		col = mix(deep.rgb, dark.rgb, 0.55);        // a lighter cube
	} else if (h < 0.24) {
		col = mix(deep.rgb, outline.rgb, 0.5);      // a darker cube
	}
	if (f.x < 0.1 || f.y < 0.1) {
		return outline.rgb;                         // the gaps between cubes
	}
	if (f.y < 0.2) {
		col = mix(col, dark.rgb, 0.8);              // lit top edge
	}
	if (h >= 0.24 && h < 0.34 && length((f - vec2(0.55, 0.6)) * vec2(1.0, 1.3)) < 0.22) {
		col = mid.rgb;                              // a little goo puddle
		if (f.y < 0.5) col = light.rgb;
	} else if (h >= 0.34 && h < 0.44 && abs(f.x - f.y * 0.8 - 0.1) < 0.06) {
		col = outline.rgb;                          // a crack
	} else if (h >= 0.44 && h < 0.56) {
		vec2 b1 = f - vec2(0.35, 0.45);
		vec2 b2 = f - vec2(0.7, 0.7);
		if (length(b1) < 0.09 || length(b2) < 0.07) {
			col = light.rgb;                        // bubbles
		}
	}
	if (h > 0.78 && length(f - vec2(0.24, 0.3)) < 0.07) {
		col = mix(col, mid.rgb, 0.7);               // a glint on some cubes
	}
	return col;
}

void fragment() {
	vec2 px = floor(UV * vec2(320.0, 180.0)) + 0.5;
	vec2 q = (px - center) / radii;
	float d = length(q);
	float screen_angle = atan(q.y, q.x);
	float plan_angle = screen_angle - turn;
	vec2 plan = vec2(cos(-turn) * q.x - sin(-turn) * q.y, sin(-turn) * q.x + cos(-turn) * q.y);
	float inner = rim_inner(plan_angle);
	vec3 col = background.rgb;

	if (d <= inner) {
		col = floor_tile(plan);
		// The back rim's shadow across the floor.
		if (q.y < 0.0 && d > inner - 0.06 && mod(px.x + px.y, 2.0) > 0.5) {
			col = mix(col, outline.rgb, 0.7);
		}
	} else if (d <= 1.0) {
		float depth = (d - inner) / (1.0 - inner);
		float lit = -cos(screen_angle) * 0.55 - sin(screen_angle) * 0.85;   // facing up-left
		if (d > 0.985) {
			col = outline.rgb;
		} else if (depth < 0.18) {
			col = deep.rgb;
		} else if (lit > 0.55 && depth > 0.55) {
			col = light.rgb;
		} else if (lit > 0.1) {
			col = mid.rgb;
		} else {
			col = dark.rgb;
		}
		// Speckles in the goo that turn with the room.
		if (depth > 0.25 && d <= 0.985 && hash(vec2(floor(plan_angle * 40.0), floor(depth * 3.0))) > 0.9) {
			col = mix(col, highlight.rgb, 0.45);
		}
		// The shine: a bright streak on the back-left (fixed, like the light).
		float deg = mod(degrees(screen_angle) + 360.0, 360.0);
		if (deg > 200.0 && deg < 262.0 && d > 0.955 && d < 0.975) {
			col = highlight.rgb;
		}
	} else if (q.y > 0.0 && abs(q.x) < 0.98) {
		// Drips running off the front of the rim, at spots fixed to the room (they turn with it).
		float edge_y = center.y + radii.y * sqrt(1.0 - q.x * q.x);
		float front_angle = acos(clamp(q.x, -1.0, 1.0)) - turn;
		float id = floor(front_angle / (PI / 100.0));
		float h = hash(vec2(id, 7.0));
		float drip_length = 2.0 + floor(hash(vec2(id, 3.0)) * 8.0);
		float below = px.y - edge_y;
		if (h < 0.16 && below < drip_length) {
			col = below > drip_length - 1.0 ? outline.rgb : (below > drip_length - 2.0 ? mid.rgb : dark.rgb);
		}
	}
	if (rainbow && (d <= 1.0 || col != background.rgb)) {
		col = rainbow_of(col, plan);
	}
	if (d > 1.0 && col == background.rgb) {
		col = mist(floor(px));  // outside the room (and its drips): fog
	} else if (d <= 1.0) {
		// Darker floor, a bit more toward the rim, so the stations pop.
		// The floor itself is darker still, so the light pools under the stations can show.
		col *= (d <= inner ? 0.64 : 0.8) - 0.12 * smoothstep(0.5, 1.0, d);
	}
	COLOR = vec4(col, 1.0);
}

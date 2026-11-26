shader_type canvas_item;
// Kevencre : le monde est délavé (gris) sauf autour de Sépia et là où la couleur est revenue.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D paper : repeat_enable, filter_linear;
uniform vec2 view_size = vec2(1280.0, 720.0);
uniform float base_sat = 0.12;
uniform vec2 player_pos = vec2(-9999.0);
uniform float player_r = 150.0;
uniform vec3 circles[32];
uniform int count = 0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 px = SCREEN_UV * view_size;
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float wob = noise(px * 0.02) * 40.0 + noise(px * 0.07) * 14.0;
	float s = base_sat;
	if (player_r > 0.0) {
		float d = distance(px, player_pos) - wob * 0.6;
		s = max(s, 1.0 - smoothstep(player_r * 0.55, player_r, d));
	}
	for (int i = 0; i < 32; i++) {
		if (i >= count) break;
		vec3 ci = circles[i];
		float d = distance(px, ci.xy) - wob;
		s = max(s, 1.0 - smoothstep(ci.z * 0.82, ci.z, d));
	}
	float g = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 grey = vec3(g) * vec3(0.97, 0.98, 1.02) * 0.92 + 0.06;
	vec3 col = mix(grey, c, clamp(s, 0.0, 1.0));
	// bord délavé : un léger liseré plus sombre là où la couleur s'arrête
	float edge = s * (1.0 - s) * 4.0;
	col *= 1.0 - edge * 0.06;
	// grain du papier
	vec3 pp = texture(paper, px / 512.0).rgb;
	col *= mix(vec3(1.0), pp * 1.06, 0.55);
	// vignette douce
	vec2 uv = SCREEN_UV - 0.5;
	col *= 1.0 - dot(uv, uv) * 0.38;
	COLOR = vec4(col, 1.0);
}

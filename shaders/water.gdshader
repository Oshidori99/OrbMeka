shader_type spatial;
// 0.0.5.19 : eau des petits lacs : bleu-vert, un peu transparente, petites rides animées, reflets plus forts
// en regardant de côté. Eau calme pour l'instant (pas d'écoulement : eau réaliste plus tard, #124).
// 0.0.6 : vue de dessous (sous l’eau) : surface claire et mouvante, la lumière qui la traverse.
render_mode blend_mix, cull_disabled, depth_draw_opaque, specular_schlick_ggx;
uniform vec3 water_color : source_color = vec3(0.09, 0.30, 0.36);
uniform vec3 sky_tint : source_color = vec3(0.55, 0.75, 0.85);
// 0.0.6.17 : rendu Web : eau un peu moins claire (mesuré sur captures).
uniform float tone = 1.0;
// 0.0.5.36 : l'eau détaillée s'arrête où commence le terrain lointain (qui a sa propre eau) : pas de double couche.
uniform vec4 near_rect = vec4(-100000.0, -100000.0, 100000.0, 100000.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = world_position.xz;
	if (p.x < near_rect.x || p.y < near_rect.y || p.x > near_rect.z || p.y > near_rect.w) {
		discard;
	}
	float t = TIME;
	// Vaguelettes d’avant 0.0.6 (l’eau vue de dessus reste la même, demande de l’utilisateur).
	float wave_a = sin(p.x * 1.7 + t * 1.3) * cos(p.y * 1.3 - t * 0.9);
	float wave_b = sin((p.x + p.y) * 3.1 - t * 2.1);
	vec3 ripple = normalize(vec3(wave_a * 0.08 + wave_b * 0.04, 1.0, wave_b * 0.05 - wave_a * 0.06));
	// Dessus ou dessous selon la caméra (les triangles du lac ne sont pas tous tournés du même côté).
	if (CAMERA_POSITION_WORLD.y >= world_position.y) {
		NORMAL = normalize((VIEW_MATRIX * vec4(ripple, 0.0)).xyz);
		float side = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		ALBEDO = mix(water_color, sky_tint, side * 0.5) * tone;
		ALPHA = mix(0.72, 0.93, side);
		ROUGHNESS = 0.06;
		SPECULAR = 0.6;
	} else {
		// Vue de dessous : la surface laisse passer la lumière, plus claire.
		NORMAL = normalize((VIEW_MATRIX * vec4(-ripple, 0.0)).xyz);
		// Lumière propre (pas d’ombre par triangle) : reflets mouvants comme la lumière qui traverse les vagues.
		float light = smoothstep(0.25, 0.75, noise(p * 0.35 + t * 0.12)) * 0.6 + noise(p * 1.3 - t * 0.3) * 0.4;
		ALBEDO = vec3(0.0);
		EMISSION = mix(vec3(0.1, 0.3, 0.33), vec3(0.32, 0.55, 0.58), light);
		// Opaque : plusieurs morceaux d’eau se recouvrent, ils feraient des facettes plus claires.
		ALPHA = 1.0;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	}
}

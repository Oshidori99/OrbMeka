shader_type spatial;
// 0.0.5.19 : eau des petits lacs : bleu-vert, un peu transparente, petites rides animées, reflets plus forts
// en regardant de côté. Eau calme pour l'instant (pas d'écoulement : eau réaliste plus tard, #124).
render_mode blend_mix, cull_disabled, depth_draw_opaque, specular_schlick_ggx;
uniform vec3 water_color : source_color = vec3(0.09, 0.30, 0.36);
uniform vec3 sky_tint : source_color = vec3(0.55, 0.75, 0.85);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float t = TIME;
	float wave_a = sin(p.x * 1.7 + t * 1.3) * cos(p.y * 1.3 - t * 0.9);
	float wave_b = sin((p.x + p.y) * 3.1 - t * 2.1);
	vec3 ripple = normalize(vec3(wave_a * 0.08 + wave_b * 0.04, 1.0, wave_b * 0.05 - wave_a * 0.06));
	NORMAL = normalize((VIEW_MATRIX * vec4(ripple, 0.0)).xyz);
	float side = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(water_color, sky_tint, side * 0.5);
	ALPHA = mix(0.72, 0.93, side);
	ROUGHNESS = 0.06;
	SPECULAR = 0.6;
}

shader_type spatial;
// 0.0.6.7 (#124) : eau des rivières : même teinte que les lacs, mais des rides qui descendent le courant
// (UV.y : distance le long de la rivière, UV.x : d'une rive à l'autre), un peu d'écume sur les bords.
render_mode blend_mix, cull_disabled, depth_draw_opaque, specular_schlick_ggx;
uniform vec3 water_color : source_color = vec3(0.09, 0.30, 0.36);
uniform vec3 sky_tint : source_color = vec3(0.55, 0.75, 0.85);
uniform float speed = 1.4;

void fragment() {
	float along = UV.y - TIME * speed;
	float across = UV.x * 2.0 - 1.0;
	float wave_a = sin(along * 3.1 + across * 2.0) * 0.5;
	float wave_b = sin(along * 7.3 - across * 4.1 + sin(along * 1.7) * 2.0) * 0.25;
	vec3 ripple = normalize(vec3(across * 0.05 + wave_b * 0.06, 1.0, wave_a * 0.1 + wave_b * 0.05));
	NORMAL = normalize((VIEW_MATRIX * vec4(ripple, 0.0)).xyz);
	float side = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float foam = smoothstep(0.75, 1.0, abs(across)) * (0.5 + 0.5 * sin(along * 5.0 + across * 3.0));
	ALBEDO = mix(mix(water_color, sky_tint, side * 0.5), vec3(0.85, 0.9, 0.92), foam * 0.35);
	ALPHA = mix(0.75, 0.93, side);
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
}

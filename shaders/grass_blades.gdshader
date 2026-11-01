shader_type spatial;
// 0.0.5.4 : brins d'herbe fins (0.0.5.7 : 24 à 56 cm), base sombre et pointe claire, balancés par un vent léger.
// UV.y : 0 à la base, 1 à la pointe. Couleur propre à chaque brin selon sa position dans le monde.
render_mode cull_disabled, diffuse_burley, specular_disabled;
uniform float wind_strength = 0.06;
varying float blade_shade;
varying float blade_zone;
float zone_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float zone_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(zone_hash(i), zone_hash(i+vec2(1,0)), f.x), mix(zone_hash(i+vec2(0,1)), zone_hash(i+vec2(1,1)), f.x), f.y);
}
// 0.0.5.30 : grandes zones d'herbe plus claires et plus sombres (même formule dans les 3 shaders du sol).
float zone_shade(vec2 xz) {
	float n = zone_noise(xz / 26.0) * 0.6 + zone_noise(xz / 61.0 + 9.0) * 0.4;
	return mix(0.72, 1.3, smoothstep(0.25, 0.75, n));
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float bend = UV.y * UV.y;
	float gust = sin(TIME * 1.7 + world.x * 0.9 + world.z * 0.6) * 0.6 + sin(TIME * 3.1 + world.x * 2.3) * 0.4;
	VERTEX.x += gust * wind_strength * bend;
	VERTEX.z += gust * wind_strength * 0.6 * bend;
	blade_shade = hash2(floor(world.xz * 40.0));
	blade_zone = zone_shade(world.xz);
	// Lumière douce : normales tournées vers le haut, comme une pelouse vue de loin.
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.75));
}

void fragment() {
	vec3 base = vec3(0.07, 0.13, 0.03);
	vec3 tip = mix(vec3(0.24, 0.40, 0.08), vec3(0.36, 0.46, 0.12), blade_shade);
	vec3 color = mix(base, tip, smoothstep(0.0, 1.0, UV.y));
	// Quelques brins plus secs, jaunis.
	color = mix(color, vec3(0.42, 0.38, 0.17), step(0.93, blade_shade) * UV.y * 0.7);
	ALBEDO = color * COLOR.rgb * blade_zone;
	ROUGHNESS = 0.9;
	BACKLIGHT = vec3(0.12, 0.18, 0.04) * UV.y;
}

shader_type spatial;
// 0.0.5.30 : terrain lointain : couleurs des sommets, et les mêmes zones d'herbe que le terrain détaillé.
render_mode diffuse_burley, specular_disabled;
varying vec3 world_position;
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
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	bool grass = COLOR.g > COLOR.r * 1.2 && COLOR.g > COLOR.b * 1.2;
	ALBEDO = grass ? COLOR.rgb * zone_shade(world_position.xz) : COLOR.rgb;
	ROUGHNESS = 1.0;
}

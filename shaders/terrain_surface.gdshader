shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform bool ground_surface = false;
uniform bool dirt_surface = false;
// 0.0.5.5 : plage de sable peinte sur le sol plat (centre X, Z et rayon en mètres ; rayon 0 = aucune).
uniform vec2 sand_center = vec2(0.0);
uniform float sand_radius = 0.0;
varying vec3 world_position;
varying vec3 world_normal;
varying vec4 tint;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),
		mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),
		mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),
		mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float fbm(vec3 p) {
	return noise3(p)*0.57 + noise3(p*2.03+11.7)*0.28 + noise3(p*4.17+31.2)*0.15;
}
void vertex() {
	world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
	tint = COLOR;
}
void fragment() {
	vec3 p = world_position;
	vec3 n = normalize(world_normal);
	bool earth = ground_surface || dirt_surface || (tint.r > tint.g*1.3 && tint.g > tint.b*1.2 && tint.r < 0.65);
	vec3 albedo = tint.rgb;
	float height = 0.0;
	if (earth) {
		float patches = fbm(p*0.31);
		float clods = fbm(p*7.0);
		float grains = noise3(p*110.0);
		float crumbs = smoothstep(0.71,0.91,noise3(p*34.0));
		vec3 soil = mix(vec3(0.095,0.058,0.031),vec3(0.28,0.174,0.087),clods);
		soil *= 0.77 + patches*0.47;
		soil += vec3(0.16,0.125,0.08)*crumbs*0.28;
		float fibers = (noise3(p*vec3(60.0,30.0,25.0))+noise3(p*vec3(23.0,30.0,65.0)))*0.5;
		vec3 grass = mix(vec3(0.075,0.125,0.028),vec3(0.27,0.33,0.09),patches);
		grass = mix(grass,vec3(0.37,0.32,0.14),smoothstep(0.63,0.81,fbm(p*1.8))*0.42);
		grass *= 0.72 + fibers*0.48 + grains*0.12;
		float top = smoothstep(0.64,0.94,n.y);
		float lip = 1.0-smoothstep(0.035,0.14,1.0-fract(p.y+0.002)+(noise3(p*13.0)-0.5)*0.055);
		float cover = max(top,lip*0.62);
		// 0.0.5.7 : sol plat plus clair (il paraissait noir sur le Web), proche de la couleur des brins.
		// 0.0.5.9 : terre posée (bleu du sommet à 0) : nue, sans herbe.
		if (ground_surface) { cover = top * tint.b; grass = mix(grass * 1.25, vec3(0.16,0.27,0.06), 0.35); }
		albedo = mix(soil,grass,cover);
		float detail_fade = 1.0-smoothstep(8.0,35.0,length(VERTEX));
		height = mix(clods*0.004+grains*0.0006,fibers*0.0015,cover)*detail_fade;
	}
	// 0.0.5.5 : sable réaliste (couleur du bloc #d8c291) : grains fins, teintes chaudes variées,
	// rides de vent sur le dessus, quelques grains plus sombres et quelques reflets.
	bool sand = !earth && tint.r > 0.6 && tint.g > 0.5 && tint.b < tint.g;
	// Sol plat : sable à l'intérieur d'un bord irrégulier, fondu sur 30 cm avec l'herbe.
	float beach = 0.0;
	// 0.0.5.9 : sable posé sur le terrain lisse (alpha du sommet à 0).
	if (ground_surface) {
		beach = smoothstep(0.35, 0.65, 1.0 - tint.a);
	}
	if (ground_surface && sand_radius > 0.0) {
		float edge = length(p.xz - sand_center) + (fbm(vec3(p.x, 0.0, p.z) * 0.9) - 0.5) * 1.4;
		beach = max(beach, 1.0 - smoothstep(sand_radius - 0.3, sand_radius, edge));
	}
	vec3 grass_albedo = albedo;
	float grass_height = height;
	if (sand || beach > 0.0) {
		float patches = fbm(p*0.6);
		float grains = noise3(p*180.0);
		float coarse = noise3(p*45.0);
		float warp = fbm(p*1.3)*2.2;
		float ripple = sin((p.x*0.8 + p.z*0.45)*38.0 + warp*6.0)*0.5+0.5;
		float top = smoothstep(0.6,0.95,n.y);
		vec3 light_sand = vec3(0.56,0.41,0.21);
		vec3 dark_sand = vec3(0.37,0.26,0.13);
		albedo = mix(dark_sand,light_sand,patches*0.6+grains*0.25+coarse*0.15);
		albedo *= 0.88 + ripple*0.2*top;
		albedo = mix(albedo,vec3(0.16,0.12,0.08),smoothstep(0.86,0.97,noise3(p*95.0))*0.6);
		float sides = 1.0-top;
		albedo *= 1.0 - sides*0.06*(1.0-fract(p.y));
		float detail_fade = 1.0-smoothstep(6.0,30.0,length(VERTEX));
		height = (ripple*0.012*top + grains*0.0015 + coarse*0.002)*detail_fade;
		if (!sand) {
			albedo = mix(grass_albedo, albedo, beach);
			height = mix(grass_height, height, beach);
			sand = beach > 0.5;
		}
	}
	ALBEDO = albedo;
	ROUGHNESS = earth ? 0.96 : (sand ? 0.93 : 0.86);
	SPECULAR = earth ? 0.12 : (sand ? 0.18 + step(0.985,noise3(p*240.0))*0.6 : 0.25);
	vec3 r1 = cross(dFdy(world_position),n);
	vec3 r2 = cross(n,dFdx(world_position));
	float determinant = dot(dFdx(world_position),r1);
	vec3 gradient = (r1*dFdx(height)+r2*dFdy(height))*sign(determinant)/max(abs(determinant),0.000001);
	gradient = clamp(gradient,vec3(-0.35),vec3(0.35));
	NORMAL = normalize((VIEW_MATRIX*vec4(normalize(n-gradient),0.0)).xyz);
}

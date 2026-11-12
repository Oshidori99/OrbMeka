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
// 0.0.6.4 : calcaire, charbon, silex (CUSTOM0 du terrain) ; rock_kind pour les rochers et cailloux : 1 calcaire, 2 silex.
varying vec3 ore_share;
// 0.0.6.15 : litière d'aiguilles de pin (CUSTOM0.a).
varying float litter_share;
uniform int rock_kind = 0;
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
	ore_share = CUSTOM0.rgb;
	litter_share = CUSTOM0.a;
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
		// 0.0.5.12 : pas d'herbe sur la pierre (vert du sommet à 0).
		if (ground_surface) { cover = top * tint.b * tint.g; grass = mix(grass * 1.25, vec3(0.16,0.27,0.06), 0.35) * zone_shade(p.xz); }
		albedo = mix(soil,grass,cover);
		float detail_fade = 1.0-smoothstep(8.0,35.0,length(VERTEX));
		height = mix(clods*0.004+grains*0.0006,fibers*0.0015,cover)*detail_fade;
		// 0.0.5.12 : pierre sous les 4 m de terre : roche grise, veines sombres, grain fin.
		if (ground_surface && tint.g < 0.99) {
			float stone = smoothstep(0.3, 0.7, 1.0 - tint.g);
			float veins = smoothstep(0.55, 0.8, fbm(p*vec3(2.5,6.0,2.5)));
			vec3 rock = mix(vec3(0.17,0.165,0.16), vec3(0.36,0.345,0.32), fbm(p*1.4));
			rock = mix(rock, vec3(0.11,0.105,0.10), veins*0.55);
			rock *= 0.88 + noise3(p*40.0)*0.24;
			// 0.0.5.18 : Roche-mère (rouge du sommet à 0) : presque noire, teintée de rouge, veines plus rouges.
			// 0.0.5.26 : pierre sombre (rouge à moitié) : la même pierre, un peu noircie.
			rock *= 1.0 - 0.42 * smoothstep(0.15, 0.4, 1.0 - tint.r);
			// 0.0.5.27 : Roche-mère (rouge à 0) : aucune couleur principale, toute la surface en taches irrégulières
			// et franches, de toutes tailles : noir, gris foncé, gris clair, un peu de bleu et de rouge (motif à nous).
			float mother_rock = smoothstep(0.6, 0.85, 1.0 - tint.r);
			vec3 warped = p + (vec3(noise3(p*11.0), noise3(p*11.0 + 17.0), noise3(p*11.0 + 41.0)) - 0.5) * 0.3
				+ (vec3(noise3(p*29.0 + 5.0), noise3(p*29.0 + 23.0), noise3(p*29.0 + 57.0)) - 0.5) * 0.09;
			// Deux tailles de taches, couleur tirée au hasard pour chacune : gris clair, gris foncé, noir, bleu, rouge.
			vec3 fine_cell = floor(warped * 20.0);
			vec3 chosen_cell = floor(warped * 8.0);
			if (hash3(fine_cell) > 0.45) { chosen_cell = fine_cell + 7.0; }
			float pick = hash3(chosen_cell);
			vec3 deep = vec3(0.012);
			if (pick > 0.86) { deep = vec3(0.17,0.025,0.022); }
			else if (pick > 0.72) { deep = vec3(0.025,0.055,0.2); }
			else if (pick > 0.48) { deep = vec3(0.3,0.3,0.31); }
			else if (pick > 0.24) { deep = vec3(0.1,0.1,0.11); }
			rock = mix(rock, deep, mother_rock);
			albedo = mix(albedo, rock, stone);
			height = mix(height, (fbm(p*9.0)*0.01 + grains*0.001)*detail_fade, stone);
		}
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
		// 0.0.5.10 : la terre posée (bleu à 0) reste de la terre, même sur la plage.
		beach = max(beach, (1.0 - smoothstep(sand_radius - 0.3, sand_radius, edge)) * tint.b);
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
	// 0.0.5.20 : argile (UV.x) et boue (UV.y) du terrain lisse ; 0.0.5.21 : argile grise (comme en vrai), grain fin, lits clairs ;
	// 0.0.5.22 : boue plus liquide : mate et gorgée d'eau, avec de petites flaques (eau en surface, seules un peu
	// brillantes), coulures lisses ; plus du tout « vernie ».
	float clay = clamp(UV.x, 0.0, 1.0);
	float mud = clamp(UV.y, 0.0, 1.0);
	float puddle = 0.0;
	float clay_wet = 0.0;
	if (clay + mud > 0.01) {
		// 0.0.5.22 : argile plus vraie : lisse et un peu humide (grain presque invisible), fines craquelures sombres.
		vec3 clay_color = mix(vec3(0.19,0.19,0.18), vec3(0.28,0.275,0.26), fbm(p*1.1)) * (0.97 + noise3(p*55.0)*0.04);
		float cracks = (1.0 - smoothstep(0.0, 0.035, abs(noise3(p*vec3(2.6,1.0,2.6)) - 0.5))) * smoothstep(0.6,0.9,n.y);
		clay_color = mix(clay_color, vec3(0.1,0.1,0.095), cracks * 0.6);
		clay_color = mix(clay_color, vec3(0.31,0.3,0.285), smoothstep(0.6,0.7,noise3(p*vec3(3.0,14.0,3.0)))*0.2);
		clay_wet = clay;
		vec3 mud_color = mix(vec3(0.075,0.052,0.035), vec3(0.15,0.105,0.065), fbm(p*2.3));
		mud_color *= 0.85 + smoothstep(0.55,0.8,fbm(p*0.9))*0.25;
		puddle = mud * smoothstep(0.6,0.7,fbm(p*0.55 + 7.0)) * smoothstep(0.75,0.95,n.y);
		mud_color = mix(mud_color, vec3(0.05,0.045,0.04), puddle * 0.8);
		albedo = mix(albedo, clay_color, clay);
		albedo = mix(albedo, mud_color, mud);
		// Coulures lisses (boue molle), plates dans les flaques.
		height = mix(height, fbm(p*vec3(1.5,4.0,1.5))*0.012, mud) * (1.0 - puddle);
		height = mix(height, fbm(p*0.8)*0.006, clay);
	}
	// 0.0.6 : neige (UV2.x) : blanche un peu bleutée dans les creux, congères douces, quelques paillettes ;
	// gravier (UV2.y) : petits cailloux arrondis de teintes variées, joints sombres entre eux.
	float snow = clamp(UV2.x, 0.0, 1.0);
	float gravel = clamp(UV2.y, 0.0, 1.0);
	float sparkle = 0.0;
	float gravel_fade = 1.0-smoothstep(8.0,30.0,length(VERTEX));
	// Cailloux dessinés seulement de près (calcul plus lourd) ; au loin, une teinte unie.
	if (gravel > 0.01 && gravel_fade <= 0.0) {
		albedo = mix(albedo, vec3(0.29,0.27,0.24), gravel);
	}
	if (gravel > 0.01 && gravel_fade > 0.0) {
		// Cailloux d'environ 6 à 12 cm, centres décalés au hasard, taille de chacun au hasard : bombés, joints sombres irréguliers.
		vec3 q = p * 11.0 + (vec3(noise3(p * 3.0), noise3(p * 3.0 + 9.0), noise3(p * 3.0 + 21.0)) - 0.5) * 0.6;
		vec3 cell = floor(q);
		float best = 9.0;
		vec3 pick = cell;
		for (int i = -1; i <= 1; i++) {
			for (int j = -1; j <= 1; j++) {
				for (int k = -1; k <= 1; k++) {
					vec3 c = cell + vec3(float(i), float(j), float(k));
					vec3 centre = c + vec3(hash3(c), hash3(c + 13.1), hash3(c + 27.7));
					float size = 0.45 + hash3(c + 41.3) * 0.4;
					float d = length(q - centre) / size;
					if (d < best) { best = d; pick = c; }
				}
			}
		}
		float dome = sqrt(clamp(1.0 - best * best, 0.0, 1.0));
		float tone = hash3(pick);
		vec3 pebble = mix(vec3(0.2,0.195,0.185), vec3(0.5,0.48,0.44), tone);
		pebble = mix(pebble, vec3(0.4,0.31,0.22), step(0.78, hash3(pick + 5.0)) * 0.8);
		pebble = mix(pebble, vec3(0.58,0.56,0.52), step(0.93, hash3(pick + 8.0)) * 0.7);
		pebble *= 0.7 + dome * 0.38 + (noise3(p * 140.0) - 0.5) * 0.08;
		// Entre les cailloux : grains plus fins et terre sombre.
		vec3 grit = mix(vec3(0.07,0.06,0.05), vec3(0.24,0.22,0.19), noise3(p * 70.0));
		vec3 gravel_color = mix(grit, pebble, smoothstep(0.0, 0.25, dome));
		albedo = mix(albedo, mix(vec3(0.29,0.27,0.24), gravel_color, gravel_fade), gravel);
		height = mix(height, dome * 0.01 * gravel_fade, gravel);
	}
	if (snow > 0.01) {
		float drifts = fbm(p * vec3(0.7, 0.3, 0.7));
		vec3 snow_color = mix(vec3(0.74,0.79,0.88), vec3(0.95,0.96,0.98), smoothstep(0.25, 0.75, drifts));
		snow_color *= 0.96 + noise3(p * 60.0) * 0.05;
		// Moins de neige sur les pentes raides : la roche dessous se devine.
		float steep = 1.0 - smoothstep(0.35, 0.7, n.y);
		float hold = snow * (1.0 - steep * 0.7);
		sparkle = step(0.992, noise3(p * 260.0)) * hold;
		albedo = mix(albedo, snow_color, hold);
		// Relief léger, effacé au loin (pas de motif régulier vu de loin).
		height = mix(height, drifts * 0.004 * (1.0 - smoothstep(10.0, 40.0, length(VERTEX))), hold);
		snow = hold;
	}
	vec3 ore = clamp(ore_share, 0.0, 1.0);
	if (rock_kind == 1) { ore.x = 1.0; }
	if (rock_kind == 2) { ore.z = 1.0; }
	float coal_glint = 0.0;
	float flint_gloss = 0.0;
	if (ore.x > 0.01) {
		// Calcaire : gris très clair à beige, mat, un peu granuleux, petits trous plus sombres.
		vec3 lime = mix(vec3(0.62, 0.57, 0.46), vec3(0.82, 0.77, 0.64), fbm(p * 1.7));
		lime *= 0.9 + noise3(p * 90.0) * 0.14;
		lime = mix(lime, vec3(0.45, 0.43, 0.39), smoothstep(0.82, 0.95, noise3(p * 26.0)) * 0.5);
		albedo = mix(albedo, lime, ore.x);
		height = mix(height, noise3(p * 60.0) * 0.004, ore.x);
	}
	if (ore.y > 0.01) {
		// Charbon : noir mat en couches, quelques éclats légèrement brillants.
		float layers = smoothstep(0.35, 0.65, sin(p.y * 26.0 + fbm(p * 2.0) * 5.0) * 0.5 + 0.5);
		vec3 coal = mix(vec3(0.022, 0.022, 0.026), vec3(0.06, 0.06, 0.066), layers);
		coal_glint = step(0.9, noise3(p * 70.0)) * ore.y;
		albedo = mix(albedo, coal, ore.y);
		height = mix(height, layers * 0.004, ore.y);
	}
	if (ore.z > 0.01) {
		// Silex : gris foncé à noir, lisse et un peu brillant ; croûte blanche crayeuse autour (bord du rognon,
		// taches sur les cailloux).
		vec3 core = mix(vec3(0.05, 0.05, 0.06), vec3(0.17, 0.17, 0.19), fbm(p * 3.5));
		float crust = rock_kind == 2 ? smoothstep(0.45, 0.6, fbm(p * 16.0)) : 1.0 - smoothstep(0.55, 0.85, ore.z);
		vec3 chalk = mix(vec3(0.74, 0.73, 0.68), vec3(0.86, 0.85, 0.8), noise3(p * 40.0));
		albedo = mix(albedo, mix(core, chalk, crust), ore.z);
		flint_gloss = ore.z * (1.0 - crust);
		height = mix(height, crust * noise3(p * 50.0) * 0.004, ore.z);
	}
	// 0.0.6.15 : litière d'aiguilles sous les pins : brun-orangé, fines aiguilles couchées en tous sens, taches plus sombres.
	float litter = clamp(litter_share, 0.0, 1.0);
	if (litter > 0.01) {
		float streak_a = smoothstep(0.55, 0.9, noise3(vec3(p.x * 40.0 + p.z * 8.0, p.y, p.z * 6.0)));
		float streak_b = smoothstep(0.6, 0.92, noise3(vec3(p.x * 7.0, p.y, p.z * 38.0 - p.x * 9.0)));
		vec3 needles = mix(vec3(0.30, 0.19, 0.10), vec3(0.50, 0.33, 0.17), max(streak_a, streak_b));
		needles = mix(needles, vec3(0.20, 0.14, 0.09), smoothstep(0.62, 0.85, fbm(p * 0.9)) * 0.6);
		albedo = mix(albedo, needles, litter);
		height = mix(height, max(streak_a, streak_b) * 0.003, litter);
	}
	ALBEDO = albedo;
	ROUGHNESS = mix(mix(mix(mix(mix(mix(mix(mix(mix(earth ? 0.96 : (sand ? 0.93 : 0.86), 0.62, clay_wet), 0.72, mud), 0.12, puddle), 0.55, snow), 0.9, gravel), 0.92, ore.x), 0.8 - coal_glint * 0.45, ore.y), 0.6, flint_gloss), 0.95, ore.z - flint_gloss);
	SPECULAR = mix(mix(mix(mix(mix(mix(mix(earth ? 0.12 : (sand ? 0.18 + step(0.985,noise3(p*240.0))*0.6 : 0.25), 0.22, mud), 0.5, puddle), 0.35 + sparkle * 0.6, snow), 0.2, gravel), 0.15, ore.x), 0.25 + coal_glint * 0.55, ore.y), 0.25, flint_gloss);
	vec3 r1 = cross(dFdy(world_position),n);
	vec3 r2 = cross(n,dFdx(world_position));
	float determinant = dot(dFdx(world_position),r1);
	vec3 gradient = (r1*dFdx(height)+r2*dFdy(height))*sign(determinant)/max(abs(determinant),0.000001);
	gradient = clamp(gradient,vec3(-0.35),vec3(0.35));
	NORMAL = normalize((VIEW_MATRIX*vec4(normalize(n-gradient),0.0)).xyz);
}

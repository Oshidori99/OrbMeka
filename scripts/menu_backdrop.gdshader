shader_type canvas_item;
// Voile des menus : assombrit et floute ce qui est derrière (monde en pause ou fond 3D de l'accueil).
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur = 0.0;
uniform vec4 tint : source_color = vec4(0.07, 0.04, 0.13, 0.2);
uniform float vignette = 0.35;

void fragment() {
	vec3 scene = textureLod(screen_texture, SCREEN_UV, blur).rgb;
	float edge = smoothstep(0.35, 0.95, distance(SCREEN_UV, vec2(0.5)));
	float amount = clamp(tint.a + edge * vignette, 0.0, 1.0);
	COLOR = vec4(mix(scene, tint.rgb, amount), 1.0);
}

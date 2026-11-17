shader_type canvas_item;
// 0.0.7.23 : voile des menus sans flou (accueil) : la même image que menu_backdrop.gdshader avec blur = 0, mais posé par
// transparence, sans recopier l'écran à chaque image (sur le Web, cette copie coûtait cher).
uniform float blur = 0.0;
uniform vec4 tint : source_color = vec4(0.07, 0.04, 0.13, 0.2);
uniform float vignette = 0.35;

void fragment() {
	float edge = smoothstep(0.35, 0.95, distance(SCREEN_UV, vec2(0.5)));
	COLOR = vec4(tint.rgb, clamp(tint.a + edge * vignette, 0.0, 1.0));
}

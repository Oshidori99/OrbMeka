shader_type canvas_item;
// 0.0.7.24 : pause : l'image du jeu photographiée une fois (frozen), floutée et voilée comme menu_backdrop.gdshader ;
// la 3D n'est plus dessinée pendant la pause (sur le Web, le flou de l'écran vivant coûtait 24 ms par image).
// 0.0.7.25 : image déjà floutée une fois (réduite puis lue en douceur, app.gd _freeze_world) : plus de flou à chaque image.
uniform sampler2D frozen : filter_linear;
uniform float blur = 0.0;
uniform vec4 tint : source_color = vec4(0.07, 0.04, 0.13, 0.2);
uniform float vignette = 0.35;

void fragment() {
	vec3 scene = texture(frozen, SCREEN_UV).rgb;
	float edge = smoothstep(0.35, 0.95, distance(SCREEN_UV, vec2(0.5)));
	float amount = clamp(tint.a + edge * vignette, 0.0, 1.0);
	COLOR = vec4(mix(scene, tint.rgb, amount), 1.0);
}

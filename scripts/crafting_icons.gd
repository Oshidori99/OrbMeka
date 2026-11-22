extends Button
# 0.0.8.8 (demande de l'utilisateur) : les actions de la fabrication en images (au lieu du texte ; le nom au survol et
# sous la rangée). Dessinées en code, dans le style du menu des actions (B + T) : on reconnaît ce qu'on fait.
# Tresser : trois brins qui s'enroulent ; Tailler : un caillou frappe un silex, des éclats sautent ; Fendre : un éclat
# enfoncé dans le bout d'une branche fendue ; Assembler : une tête de pierre qui glisse dans la fente ; Ficeler : le haut
# d'un manche entouré de tours de ficelle, la tête au-dessus.
var action := ""

func _init(kind: String, side: float) -> void:
	action = kind
	custom_minimum_size = Vector2(side, side)
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE

func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	var c := box.get_center()
	var s := minf(size.x, size.y) * 0.8
	var a := 0.45 if disabled else 1.0
	var wood := Color(0.55, 0.36, 0.2, a)
	var bark := Color(0.42, 0.28, 0.16, a)
	var flint := Color(0.22, 0.22, 0.26, a)
	var stone := Color(0.62, 0.6, 0.56, a)
	var cord := Color(0.82, 0.74, 0.5, a)
	var green := Color(0.42, 0.6, 0.3, a)
	var white := Color(1, 1, 1, a)
	match action:
		"tresser":
			for strand in range(3):
				var points := PackedVector2Array()
				for step in range(21):
					var t := step / 20.0
					var x := lerpf(-0.42, 0.42, t)
					points.append(c + Vector2(x, sin(t * TAU * 2.0 + strand * TAU / 3.0) * 0.09 * (1.0 - t * 0.6)) * s)
				draw_polyline(points, [green, cord, Color(0.55, 0.65, 0.35, a)][strand], 0.045 * s, true)
		"tailler":
			# Le silex (à droite) et le caillou qui le frappe (à gauche), des éclats qui sautent.
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.02, 0.32) * s, c + Vector2(0.4, 0.3) * s, c + Vector2(0.42, -0.02) * s, c + Vector2(0.18, -0.12) * s, c + Vector2(0.0, 0.06) * s]), flint)
			draw_line(c + Vector2(0.06, 0.2) * s, c + Vector2(0.3, 0.02) * s, Color(0.45, 0.45, 0.5, a), 0.02 * s)
			draw_circle(c + Vector2(-0.26, -0.18) * s, 0.15 * s, stone)
			for chip in [Vector2(-0.02, -0.18), Vector2(0.06, -0.3), Vector2(-0.1, -0.36)]:
				draw_rect(Rect2(c + chip * s, Vector2(0.05, 0.05) * s), flint)
			draw_line(c + Vector2(-0.14, -0.08) * s, c + Vector2(-0.02, 0.0) * s, white, 0.03 * s)
		"fendre":
			# Une branche couchée, son bout fendu en V, l'éclat enfoncé dedans.
			draw_line(c + Vector2(-0.42, 0.2) * s, c + Vector2(0.18, -0.04) * s, bark, 0.16 * s)
			draw_line(c + Vector2(0.18, -0.04) * s, c + Vector2(0.4, -0.2) * s, wood, 0.07 * s)
			draw_line(c + Vector2(0.18, -0.04) * s, c + Vector2(0.42, 0.06) * s, wood, 0.07 * s)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.3, -0.34) * s, c + Vector2(0.4, -0.3) * s, c + Vector2(0.24, -0.02) * s]), flint)
		"assembler":
			# Un manche fendu debout, une tête de pierre au-dessus, une flèche vers la fente.
			draw_line(c + Vector2(0.0, 0.42) * s, c + Vector2(0.0, -0.02) * s, bark, 0.12 * s)
			draw_line(c + Vector2(0.0, -0.02) * s, c + Vector2(-0.05, -0.1) * s, wood, 0.05 * s)
			draw_line(c + Vector2(0.0, -0.02) * s, c + Vector2(0.05, -0.1) * s, wood, 0.05 * s)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.34, -0.3) * s, c + Vector2(0.36, -0.34) * s, c + Vector2(0.3, -0.24) * s, c + Vector2(-0.3, -0.2) * s]), flint)
			draw_line(c + Vector2(0.3, 0.0) * s, c + Vector2(0.12, -0.12) * s, white, 0.03 * s)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.1, -0.16) * s, c + Vector2(0.18, -0.08) * s, c + Vector2(0.08, -0.06) * s]), white)
		"ficeler":
			# Le haut du manche, la tête en travers, et des tours de ficelle autour.
			draw_line(c + Vector2(0.0, 0.42) * s, c + Vector2(0.0, -0.18) * s, bark, 0.12 * s)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.36, -0.3) * s, c + Vector2(0.38, -0.34) * s, c + Vector2(0.32, -0.18) * s, c + Vector2(-0.3, -0.16) * s]), flint)
			for turn in range(4):
				var y := -0.08 + turn * 0.07
				draw_line(c + Vector2(-0.09, y) * s, c + Vector2(0.09, y - 0.03) * s, cord, 0.035 * s)

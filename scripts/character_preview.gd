extends Control
# Aperçu simple d'un personnage (0.0.3.16), dessiné en code, sans image externe.
# Style propre à OrbMeka : tête ronde (une « orbe »), corps aux angles arrondis.
# Couleurs volontairement éloignées des personnages d'autres jeux de blocs.

const CHARACTERS := {
	"boy": {"name": "Garçon", "age": "≈ 14 ans", "height": 0.86, "skin": Color("#e8b98f"), "hair": Color("#3b2a1e"), "long_hair": false, "top": Color("#e0644b"), "bottom": Color("#4a4f5c"), "dress": false},
	"girl": {"name": "Fille", "age": "≈ 14 ans", "height": 0.84, "skin": Color("#c98e63"), "hair": Color("#1e1a1a"), "long_hair": true, "top": Color("#9b6fd1"), "bottom": Color("#2f3e57"), "dress": false},
	"man": {"name": "Homme", "age": "adulte", "height": 1.0, "skin": Color("#8d5a3b"), "hair": Color("#151212"), "long_hair": false, "top": Color("#d9a441"), "bottom": Color("#3a3a3a"), "dress": false},
	"woman": {"name": "Femme", "age": "adulte", "height": 0.97, "skin": Color("#f1c9a5"), "hair": Color("#a8572c"), "long_hair": true, "top": Color("#3f9e8a"), "bottom": Color("#5b3a63"), "dress": true},
}

var character := "boy":
	set(value):
		character = value
		queue_redraw()

func _rounded(rect: Rect2, color: Color, radius: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	draw_style_box(box, rect)

func _draw() -> void:
	var data: Dictionary = CHARACTERS[character]
	# Hauteur relative : les enfants sont un peu plus petits ; pieds en bas de la zone.
	var unit: float = size.y * 0.9 * data.height
	var center_x := size.x * 0.5
	var feet := size.y * 0.97
	var head_radius := unit * 0.13
	var head_y := feet - unit + head_radius
	var body_top := head_y + head_radius * 1.05
	var body_height := unit * 0.36
	var body_width := unit * 0.32
	var legs_top := body_top + body_height
	# Cheveux longs derrière la tête et les épaules.
	if data.long_hair:
		_rounded(Rect2(center_x - head_radius * 1.1, head_y - head_radius * 0.2, head_radius * 2.2, head_radius * 2.6), data.hair, head_radius)
	# Bras.
	_rounded(Rect2(center_x - body_width * 0.5 - unit * 0.07, body_top + unit * 0.02, unit * 0.07, body_height * 0.85), data.skin, unit * 0.03)
	_rounded(Rect2(center_x + body_width * 0.5, body_top + unit * 0.02, unit * 0.07, body_height * 0.85), data.skin, unit * 0.03)
	# Jambes (ou robe).
	if data.dress:
		_rounded(Rect2(center_x - body_width * 0.62, legs_top - unit * 0.02, body_width * 1.24, unit * 0.22), data.bottom, unit * 0.04)
		_rounded(Rect2(center_x - body_width * 0.3, legs_top + unit * 0.2, unit * 0.07, feet - legs_top - unit * 0.2), data.skin, unit * 0.03)
		_rounded(Rect2(center_x + body_width * 0.3 - unit * 0.07, legs_top + unit * 0.2, unit * 0.07, feet - legs_top - unit * 0.2), data.skin, unit * 0.03)
	else:
		_rounded(Rect2(center_x - body_width * 0.45, legs_top, body_width * 0.42, feet - legs_top), data.bottom, unit * 0.03)
		_rounded(Rect2(center_x + body_width * 0.03, legs_top, body_width * 0.42, feet - legs_top), data.bottom, unit * 0.03)
	# Corps.
	_rounded(Rect2(center_x - body_width * 0.5, body_top, body_width, body_height), data.top, unit * 0.06)
	# Tête ronde, cheveux courts sur le dessus, yeux.
	draw_circle(Vector2(center_x, head_y), head_radius, data.skin)
	if not data.long_hair:
		draw_arc(Vector2(center_x, head_y), head_radius * 0.92, PI * 1.08, PI * 1.92, 16, data.hair, head_radius * 0.45)
	else:
		draw_arc(Vector2(center_x, head_y), head_radius * 0.95, PI * 1.02, PI * 1.98, 16, data.hair, head_radius * 0.35)
	var eye := head_radius * 0.13
	draw_circle(Vector2(center_x - head_radius * 0.35, head_y + head_radius * 0.05), eye, Color("#1d1430"))
	draw_circle(Vector2(center_x + head_radius * 0.35, head_y + head_radius * 0.05), eye, Color("#1d1430"))
	draw_arc(Vector2(center_x, head_y + head_radius * 0.3), head_radius * 0.3, PI * 0.2, PI * 0.8, 10, Color("#7a3b2e"), maxf(1.0, head_radius * 0.08))

extends Control
# Aperçu simple d'un personnage (0.0.3.16), dessiné en code, sans image externe.
# Style propre à OrbMeka : tête ronde (une « orbe »), corps aux angles arrondis.
# Couleurs volontairement éloignées des personnages d'autres jeux de blocs.

const CHARACTERS := {
	"boy": {"name": "Garçon", "age": "≈ 14 ans", "height": 0.86, "skin": Color("#e8b98f"), "hair": Color("#3b2a1e"), "long_hair": false, "top": Color("#e0644b"), "bottom": Color("#4a4f5c"), "dress": false},
	"girl": {"name": "Fille", "age": "≈ 14 ans", "height": 0.84, "skin": Color("#c98e63"), "hair": Color("#1e1a1a"), "long_hair": true, "top": Color("#9b6fd1"), "bottom": Color("#2f3e57"), "dress": false},
	"man": {"name": "Homme", "age": "adulte", "height": 1.0, "skin": Color("#8d5a3b"), "hair": Color("#151212"), "long_hair": false, "top": Color("#d9a441"), "bottom": Color("#3a3a3a"), "dress": false},
	"woman": {"name": "Femme", "age": "adulte", "height": 0.97, "skin": Color("#f1c9a5"), "hair": Color("#a8572c"), "long_hair": true, "top": Color("#3f9e8a"), "bottom": Color("#5b3a63"), "dress": true},
	# 0.0.3.19 : chat original façon peluche (création OrbMeka, ne copie aucune peluche existante) :
	# grosse tête ronde, petit corps assis, joues roses, foulard violet de l'Orbe.
	"cat": {"name": "Chat", "age": "peluche", "height": 0.62, "fur": Color("#f3d9b1"), "belly": Color("#fbeedb"), "stripes": Color("#d9a46a"), "pink": Color("#f4a6b8"), "eyes": Color("#2b1d2e"), "scarf": Color("#9b6fd1"), "plush": true},
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

func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(32):
		var angle := TAU * index / 32.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

# Chat peluche (0.0.3.19), assis, vu de face ; tout est proportionnel à « u ».
func _draw_cat(data: Dictionary) -> void:
	var u: float = minf(size.x * 1.25, size.y) * 0.95 * data.height / 0.62
	var cx := size.x * 0.5
	var ground := size.y * 0.97
	var outline := Color(data.stripes, 0.9)
	# Queue : grosse courbe douce qui remonte sur la droite, bout plus foncé.
	var tail := PackedVector2Array()
	for index in range(14):
		var t := index / 13.0
		tail.append(Vector2(cx + u * (0.2 + 0.2 * sin(t * PI * 0.75)), ground - u * (0.04 + 0.28 * t)))
	draw_polyline(tail, data.fur, u * 0.09, true)
	_ellipse(tail[tail.size() - 1], Vector2(u * 0.046, u * 0.046), data.stripes)
	# Corps assis, ventre plus clair, pattes avant avec coussinets roses.
	var body_center := Vector2(cx, ground - u * 0.17)
	_ellipse(body_center, Vector2(u * 0.24, u * 0.19), data.fur)
	_ellipse(body_center + Vector2(0, u * 0.03), Vector2(u * 0.14, u * 0.13), data.belly)
	for side in [-1.0, 1.0]:
		var paw := Vector2(cx + side * u * 0.1, ground - u * 0.04)
		_ellipse(paw, Vector2(u * 0.075, u * 0.05), data.fur)
		_ellipse(paw + Vector2(0, u * 0.01), Vector2(u * 0.025, u * 0.018), data.pink)
	# Foulard violet, la touche OrbMeka.
	_rounded(Rect2(cx - u * 0.2, ground - u * 0.36, u * 0.4, u * 0.07), data.scarf, u * 0.035)
	_ellipse(Vector2(cx + u * 0.12, ground - u * 0.29), Vector2(u * 0.045, u * 0.06), data.scarf)
	# Oreilles : triangles doux, posés sur la tête, intérieur rose bien visible.
	var head := Vector2(cx, ground - u * 0.58)
	var head_radius := u * 0.27
	var ears: Array = []
	for side in [-1.0, 1.0]:
		var tip := head + Vector2(side * head_radius * 0.78, -head_radius * 1.12)
		var outer := head + Vector2(side * head_radius * 1.0, -head_radius * 0.35)
		var inner_base := head + Vector2(side * head_radius * 0.3, -head_radius * 0.85)
		ears.append([inner_base, tip, outer])
		draw_colored_polygon(PackedVector2Array([inner_base, tip, outer]), data.fur)
	# Tête ronde (l'orbe), un peu plus large que haute, trois rayures douces sur le front.
	_ellipse(head, Vector2(head_radius * 1.08, head_radius), data.fur)
	for ear in ears:
		var centre: Vector2 = (ear[0] + ear[1] + ear[2]) / 3.0
		draw_colored_polygon(PackedVector2Array([ear[0].lerp(centre, 0.45), ear[1].lerp(centre, 0.3), ear[2].lerp(centre, 0.45)]), data.pink)
	for offset in [-0.22, 0.0, 0.22]:
		_rounded(Rect2(head.x + head_radius * offset - head_radius * 0.05, head.y - head_radius * 0.95, head_radius * 0.1, head_radius * 0.3), data.stripes, head_radius * 0.05)
	# Grands yeux brillants, deux reflets chacun.
	for side in [-1.0, 1.0]:
		var eye := head + Vector2(side * head_radius * 0.42, head_radius * 0.05)
		_ellipse(eye, Vector2(head_radius * 0.17, head_radius * 0.22), data.eyes)
		draw_circle(eye + Vector2(-head_radius * 0.05, -head_radius * 0.08), head_radius * 0.065, Color.WHITE)
		draw_circle(eye + Vector2(head_radius * 0.06, head_radius * 0.07), head_radius * 0.03, Color(1, 1, 1, 0.85))
		# Joues roses et moustaches.
		_ellipse(head + Vector2(side * head_radius * 0.66, head_radius * 0.38), Vector2(head_radius * 0.15, head_radius * 0.09), Color(data.pink, 0.75))
		for whisker in [-0.06, 0.06]:
			var start := head + Vector2(side * head_radius * 0.8, head_radius * (0.3 + whisker))
			draw_line(start, start + Vector2(side * head_radius * 0.38, head_radius * whisker * 2.0), outline, maxf(1.0, head_radius * 0.025), true)
	# Petit nez rose et bouche en « w ».
	var nose := head + Vector2(0, head_radius * 0.28)
	draw_colored_polygon(PackedVector2Array([nose + Vector2(-head_radius * 0.07, -head_radius * 0.04), nose + Vector2(head_radius * 0.07, -head_radius * 0.04), nose + Vector2(0, head_radius * 0.05)]), data.pink)
	var width := maxf(1.0, head_radius * 0.035)
	draw_arc(nose + Vector2(-head_radius * 0.06, head_radius * 0.07), head_radius * 0.06, 0.0, PI, 10, data.eyes, width, true)
	draw_arc(nose + Vector2(head_radius * 0.06, head_radius * 0.07), head_radius * 0.06, 0.0, PI, 10, data.eyes, width, true)

func _draw() -> void:
	var data: Dictionary = CHARACTERS[character]
	if data.get("plush", false):
		_draw_cat(data)
		return
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

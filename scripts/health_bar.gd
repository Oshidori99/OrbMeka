extends Control
# 0.0.8 (#171, demande de l'utilisateur) : barre de vie en bas à gauche, en Survie seulement. Contour blanc fin ; dedans,
# une barre rouge en dégradé : rouge vif à gauche, de plus en plus clair et transparent vers la droite ; le nombre de
# points (100 quand la vie est pleine, sans « % ») écrit en blanc au milieu. La barre raccourcit vers la gauche quand la
# vie baisse ; elle clignote un court instant à chaque dégât.
const WIDTH := 220.0
const HEIGHT := 18.0
const BORDER := 1.5
const LEFT_RED := Color(0.86, 0.06, 0.06, 0.95)
const RIGHT_RED := Color(1.0, 0.55, 0.55, 0.45)
const BLINK_SECONDS := 0.6

var text_scale := 1.0
var value := 100:
	set(new_value):
		if new_value == value:
			return
		value = new_value
		queue_redraw()
var maximum := 100
var blink := 0.0

func _ready() -> void:
	name = "HealthBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	place()

# En bas à gauche, un peu au-dessus du bord.
func place() -> void:
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	var w := roundf(WIDTH * text_scale)
	var h := roundf(HEIGHT * text_scale)
	offset_left = 18.0
	offset_right = 18.0 + w
	offset_bottom = -18.0
	offset_top = -18.0 - h
	custom_minimum_size = Vector2(w, h)
	queue_redraw()

func hurt() -> void:
	blink = BLINK_SECONDS

func _process(delta: float) -> void:
	if blink > 0.0:
		blink = maxf(0.0, blink - delta)
		# Clignote 3 fois.
		modulate.a = 0.35 if int(blink / (BLINK_SECONDS / 6.0)) % 2 == 1 else 1.0
		if blink == 0.0:
			modulate.a = 1.0

func fill_ratio() -> float:
	return clampf(float(value) / float(maxi(1, maximum)), 0.0, 1.0)

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	# Fond très léger pour la partie vide.
	draw_rect(rect, Color(0, 0, 0, 0.25))
	var inner := rect.grow(-BORDER - 1.0)
	var filled := inner.size.x * fill_ratio()
	if filled > 0.5:
		# Dégradé : les couleurs suivent toute la largeur, la barre en montre seulement sa partie pleine.
		var right := LEFT_RED.lerp(RIGHT_RED, fill_ratio())
		var points := PackedVector2Array([inner.position, inner.position + Vector2(filled, 0), inner.position + Vector2(filled, inner.size.y), inner.position + Vector2(0, inner.size.y)])
		draw_polygon(points, PackedColorArray([LEFT_RED, right, right, LEFT_RED]))
	draw_rect(rect, Color(1, 1, 1, 0.95), false, BORDER)
	var font := get_theme_default_font()
	var font_size := roundi(13 * text_scale)
	var text := str(value)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var at := Vector2((size.x - text_size.x) * 0.5, (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0, 0, 0, 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

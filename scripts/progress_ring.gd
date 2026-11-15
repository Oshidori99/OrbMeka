extends Control
# 0.0.7.8 (demande de l'utilisateur) : anneau de chargement autour de la croix de visée, pour tout ce qui prend du temps
# (abattre ou couper un arbre, récupérer une poignée avec R + I). Sans pourcentage écrit : un cercle blanc grisâtre,
# un peu transparent, qui se remplit en blanc dans le sens des aiguilles d'une montre ; plein : c'est fait.
const RADIUS := 17.0
const WIDTH := 3.5

var progress := 0.0:
	set(value):
		var clamped := clampf(value, 0.0, 1.0)
		if is_equal_approx(clamped, progress):
			return
		progress = clamped
		visible = progress > 0.0
		queue_redraw()

func _ready() -> void:
	name = "ProgressRing"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Centré sur l'écran (sous un CanvasLayer : ancres au milieu, décalages de part et d'autre).
	var half := RADIUS + WIDTH
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -half
	offset_right = half
	offset_top = -half
	offset_bottom = half
	custom_minimum_size = Vector2.ONE * (RADIUS + WIDTH) * 2.0
	visible = false

func _draw() -> void:
	var center := size * 0.5
	draw_arc(center, RADIUS, 0.0, TAU, 48, Color(0.85, 0.85, 0.85, 0.35), WIDTH, true)
	if progress > 0.0:
		draw_arc(center, RADIUS, -PI * 0.5, -PI * 0.5 + TAU * progress, maxi(4, roundi(48 * progress)), Color(1, 1, 1, 0.95), WIDTH, true)

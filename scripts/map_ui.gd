extends Control
# 0.0.8.28 (#154, demandes de l'utilisateur) : la mini-carte, en haut à droite de l'écran (à la place des rappels F1 à F3 ;
# l'heure et les coordonnées dessous) : la carte (world_map.gd) autour du joueur, sa flèche au centre ; nord en haut (ou
# la carte qui tourne avec le regard : Paramètres → Vidéo → Carte). Redessinée REDRAW_EVERY s au plus (léger).
const REDRAW_EVERY := 0.1
const SIZES := {"small": 120.0, "medium": 170.0, "large": 230.0}
const ARROW := Color(1.0, 0.85, 0.2)

var map
var player: Node3D
var zoom := 2.0
var north_fixed := true
var _wait := 0.0

func setup(world_map, who: Node3D) -> void:
	map = world_map
	player = who
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_options(size_name: String, zoom_name: String, north: String) -> void:
	var side: float = SIZES.get(size_name, SIZES.medium)
	custom_minimum_size = Vector2(side, side)
	size = Vector2(side, side)
	offset_left = -18.0 - side
	offset_right = -18.0
	offset_top = 18.0
	offset_bottom = 18.0 + side
	zoom = 1.0 if zoom_name == "1" else (4.0 if zoom_name == "4" else 2.0)
	north_fixed = north != "turning"
	queue_redraw()

func _process(delta: float) -> void:
	_wait -= delta
	if _wait <= 0.0 and visible:
		_wait = REDRAW_EVERY
		queue_redraw()

static func draw_arrow(canvas: CanvasItem, at: Vector2, direction: Vector2, length: float) -> void:
	var forward := direction.normalized()
	var side := Vector2(-forward.y, forward.x)
	var points := PackedVector2Array([at + forward * length, at - forward * length * 0.6 + side * length * 0.55, at - forward * length * 0.25, at - forward * length * 0.6 - side * length * 0.55])
	canvas.draw_colored_polygon(points, ARROW)
	canvas.draw_polyline(points + PackedVector2Array([points[0]]), Color(0, 0, 0, 0.8), 1.5)

func _draw() -> void:
	var side := size.x
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.08, 0.1, 0.85))
	if map == null or not is_instance_valid(player):
		return
	var center := size * 0.5
	var at: Vector2 = map.pixel_of(player.global_position)
	var yaw: float = player.rotation.y
	# Ce que la mini-carte montre (pixels de la carte) : son côté divisé par le zoom.
	var shown := side / zoom
	if north_fixed:
		draw_texture_rect_region(map.seen_texture, Rect2(Vector2.ZERO, size), Rect2(at - Vector2(shown, shown) * 0.5, Vector2(shown, shown)))
		draw_arrow(self, center, Vector2(-sin(yaw), -cos(yaw)), side * 0.07)
	else:
		# La carte tourne : le regard toujours vers le haut.
		var reach := shown * 1.5
		draw_set_transform(center, yaw, Vector2.ONE)
		draw_texture_rect_region(map.seen_texture, Rect2(-Vector2(reach, reach) * zoom * 0.5, Vector2(reach, reach) * zoom), Rect2(at - Vector2(reach, reach) * 0.5, Vector2(reach, reach)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arrow(self, center, Vector2(0, -1), side * 0.07)
	# 0.0.8.35 (#252) : les points de repère ; trop loin, au bord, dans leur direction.
	for point: Dictionary in map.waypoints:
		var offset: Vector2 = (map.pixel_of(Vector3(point.x, 0.0, point.z)) - at) * zoom
		if not north_fixed:
			offset = offset.rotated(yaw)
		var edge := side * 0.5 - 7.0
		var far := maxf(absf(offset.x), absf(offset.y)) > edge
		if far:
			offset *= edge / maxf(absf(offset.x), absf(offset.y))
		map.draw_waypoint(self, center + offset, point, 3.5 if far else 5.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.9), false, 2.0)
	# Le nord.
	var north := Vector2(center.x, 12.0) if north_fixed else center + Vector2(0, -1).rotated(yaw) * (side * 0.5 - 12.0)
	draw_string(ThemeDB.fallback_font, north + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.9))

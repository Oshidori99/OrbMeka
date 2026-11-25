extends Control
# 0.0.8.28 (#154, demandes de l'utilisateur) : la grande carte (O + M) : tout ce qu'on a exploré (les zones chargées au
# fil de la partie), la flèche du joueur ; « Tout voir » montre une fois tout le monde (dessiné en arrière-plan, sa part
# affichée) ; recliquer revient à ce qui est exploré. O + M ou Échap pour fermer. Les points de repère viendront plus
# tard (issue #252).
const MapUI = preload("res://scripts/map_ui.gd")
signal closed

var map
var player: Node3D
var show_all := false
var all_button: Button
var status: Label
var _wait := 0.0

func setup(world_map, who: Node3D, text_scale: float) -> void:
	map = world_map
	player = who
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_top = 12
	bar.offset_left = 18
	bar.offset_right = -18
	bar.add_theme_constant_override("separation", 12)
	add_child(bar)
	var title := Label.new()
	title.text = "Carte"
	title.add_theme_font_size_override("font_size", roundi(22 * text_scale))
	bar.add_child(title)
	all_button = Button.new()
	all_button.focus_mode = Control.FOCUS_NONE
	all_button.pressed.connect(toggle_all)
	bar.add_child(all_button)
	status = Label.new()
	status.add_theme_font_size_override("font_size", roundi(15 * text_scale))
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(status)
	var close := Button.new()
	close.text = "Fermer (O + M)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): closed.emit())
	bar.add_child(close)
	_refresh_texts()

func toggle_all() -> void:
	show_all = not show_all
	if show_all:
		map.want_all()
	_refresh_texts()
	queue_redraw()

func _refresh_texts() -> void:
	all_button.text = "Seulement l'exploré" if show_all else "Tout voir"
	if show_all and map.busy():
		status.text = "Dessin de tout le monde : %d %%" % roundi(map.progress() * 100.0)
	elif show_all:
		status.text = "Tout le monde."
	else:
		status.text = "Ce que vous avez exploré."

func _process(delta: float) -> void:
	if not visible:
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = 0.2
		_refresh_texts()
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		closed.emit()
		accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.05, 0.92))
	if map == null:
		return
	var top := 64.0
	var room := Vector2(size.x - 36.0, size.y - top - 18.0)
	var side := minf(room.x, room.y)
	var origin := Vector2((size.x - side) * 0.5, top)
	var texture: Texture2D = map.full_texture if show_all else map.seen_texture
	draw_texture_rect(texture, Rect2(origin, Vector2(side, side)), false)
	draw_rect(Rect2(origin, Vector2(side, side)), Color(0.6, 0.6, 0.6, 0.6), false, 1.5)
	if is_instance_valid(player):
		var scale := side / float(map.pixels)
		var at: Vector2 = origin + map.pixel_of(player.global_position) * scale
		var yaw: float = player.rotation.y
		MapUI.draw_arrow(self, at, Vector2(-sin(yaw), -cos(yaw)), 9.0)
	draw_string(ThemeDB.fallback_font, origin + Vector2(side * 0.5 - 5.0, 16.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.9))

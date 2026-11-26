extends Control
# 0.0.8.28 (#154, demandes de l'utilisateur) : la grande carte (O + M) : tout ce qu'on a exploré (les zones chargées au
# fil de la partie), la flèche du joueur ; « Tout voir » montre une fois tout le monde (dessiné en arrière-plan, sa part
# affichée) ; recliquer revient à ce qui est exploré. O + M ou Échap pour fermer.
# 0.0.8.35 (#252) : points de repère : « Ajouter un repère » (là où l'on est), son nom à écrire dans la case à côté ;
# un clic sur un repère le choisit (pour le renommer), « Supprimer » l'enlève. Nom et distance écrits sur la carte.
const MapUI = preload("res://scripts/map_ui.gd")
signal closed
signal waypoints_changed

var map
var player: Node3D
var show_all := false
var all_button: Button
var status: Label
var _wait := 0.0
var add_button: Button
var name_edit: LineEdit
var remove_button: Button
var color_buttons: Array = []
var chosen := -1
var text_scale := 1.0

func setup(world_map, who: Node3D, scale_of_text: float) -> void:
	map = world_map
	player = who
	text_scale = scale_of_text
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
	# 0.0.8.39 (demande de l'utilisateur) : en bas à droite, un « + » pour ajouter un repère, à sa droite son nom, ses
	# couleurs et « Supprimer ».
	var tools := HBoxContainer.new()
	tools.name = "Reperes"
	tools.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	tools.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tools.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tools.offset_right = -18
	tools.offset_bottom = -12
	tools.add_theme_constant_override("separation", 8)
	add_child(tools)
	add_button = Button.new()
	add_button.text = "+"
	add_button.tooltip_text = "Ajouter un repère là où vous êtes"
	add_button.custom_minimum_size = Vector2(36.0, 32.0) * text_scale
	add_button.add_theme_font_size_override("font_size", roundi(22 * text_scale))
	add_button.focus_mode = Control.FOCUS_NONE
	add_button.pressed.connect(add_here)
	tools.add_child(add_button)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Nom du repère"
	name_edit.max_length = map.MAX_NAME
	name_edit.custom_minimum_size = Vector2(180.0 * text_scale, 0.0)
	name_edit.text_changed.connect(func(text: String) -> void:
		if chosen >= 0:
			map.rename_waypoint(chosen, text)
			waypoints_changed.emit()
			queue_redraw())
	name_edit.text_submitted.connect(func(_text: String) -> void: name_edit.release_focus())
	tools.add_child(name_edit)
	for index in range(map.WAYPOINT_COLORS.size()):
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(26.0, 26.0) * text_scale
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.tooltip_text = "Couleur du repère"
		for state in ["normal", "hover", "pressed", "disabled"]:
			var box := StyleBoxFlat.new()
			box.bg_color = map.WAYPOINT_COLORS[index] if state != "disabled" else map.WAYPOINT_COLORS[index].darkened(0.6)
			box.set_corner_radius_all(13)
			box.set_border_width_all(2 if state == "hover" else 1)
			box.border_color = Color.WHITE if state == "hover" else Color(0, 0, 0, 0.8)
			swatch.add_theme_stylebox_override(state, box)
		swatch.pressed.connect(set_color.bind(index))
		tools.add_child(swatch)
		color_buttons.append(swatch)
	remove_button = Button.new()
	remove_button.text = "Supprimer"
	remove_button.focus_mode = Control.FOCUS_NONE
	remove_button.pressed.connect(remove_chosen)
	tools.add_child(remove_button)
	_choose(-1)
	var close := Button.new()
	close.text = "Fermer (O + M)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): closed.emit())
	bar.add_child(close)
	_refresh_texts()

# Un repère là où est le joueur, choisi tout de suite (son nom à écrire).
func add_here() -> void:
	if not is_instance_valid(player):
		return
	var point: Dictionary = map.add_waypoint(player.global_position)
	if point.is_empty():
		return
	waypoints_changed.emit()
	_choose(map.waypoints.size() - 1)
	name_edit.grab_focus()
	name_edit.select_all()

# 0.0.8.39 (demande de l'utilisateur) : la couleur du repère choisi.
func set_color(index: int) -> void:
	if chosen < 0:
		return
	map.waypoints[chosen].couleur = index
	waypoints_changed.emit()
	queue_redraw()

func remove_chosen() -> void:
	if chosen < 0:
		return
	map.remove_waypoint(chosen)
	waypoints_changed.emit()
	_choose(-1)

func _choose(index: int) -> void:
	chosen = index if index >= 0 and index < map.waypoints.size() else -1
	name_edit.editable = chosen >= 0
	name_edit.text = map.waypoints[chosen].nom if chosen >= 0 else ""
	remove_button.disabled = chosen < 0
	for swatch: Button in color_buttons:
		swatch.disabled = chosen < 0
	queue_redraw()

# Place de la carte dans la fenêtre : coin et côté (pixels).
func _frame() -> Array:
	var top := 64.0
	var room := Vector2(size.x - 36.0, size.y - top - 64.0)
	var side := minf(room.x, room.y)
	return [Vector2((size.x - side) * 0.5, top), side]

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
	# Un clic sur un repère le choisit.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and map != null:
		var frame := _frame()
		var scale: float = frame[1] / float(map.pixels)
		var best := -1
		for index in range(map.waypoints.size()):
			var point: Dictionary = map.waypoints[index]
			var at: Vector2 = frame[0] + map.pixel_of(Vector3(point.x, 0.0, point.z)) * scale
			if at.distance_to(event.position) < 14.0:
				best = index
		_choose(best)
		if best < 0:
			name_edit.release_focus()
		accept_event()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		closed.emit()
		accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.05, 0.92))
	if map == null:
		return
	var top := 64.0
	var room := Vector2(size.x - 36.0, size.y - top - 64.0)
	var side := minf(room.x, room.y)
	var origin := Vector2((size.x - side) * 0.5, top)
	var texture: Texture2D = map.full_texture if show_all else map.seen_texture
	draw_texture_rect(texture, Rect2(origin, Vector2(side, side)), false)
	draw_rect(Rect2(origin, Vector2(side, side)), Color(0.6, 0.6, 0.6, 0.6), false, 1.5)
	var map_scale := side / float(map.pixels)
	for index in range(map.waypoints.size()):
		var point: Dictionary = map.waypoints[index]
		var spot: Vector2 = origin + map.pixel_of(Vector3(point.x, 0.0, point.z)) * map_scale
		map.draw_waypoint(self, spot, point, 7.0 if index == chosen else 4.5)
		var label: String = point.nom
		if is_instance_valid(player):
			label += " · %d m" % roundi(Vector2(point.x - player.global_position.x, point.z - player.global_position.z).length())
		draw_string(ThemeDB.fallback_font, spot + Vector2(11.0, 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(14 * text_scale), Color.WHITE)
	if is_instance_valid(player):
		var scale := side / float(map.pixels)
		var at: Vector2 = origin + map.pixel_of(player.global_position) * scale
		var yaw: float = player.rotation.y
		MapUI.draw_arrow(self, at, Vector2(-sin(yaw), -cos(yaw)), 9.0)
	draw_string(ThemeDB.fallback_font, origin + Vector2(side * 0.5 - 5.0, 16.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.9))

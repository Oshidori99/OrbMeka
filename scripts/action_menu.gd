extends Control
# 0.0.7.17 (demande de l'utilisateur) : menu des actions, ouvert avec B + T. Deux lignes de cases en bas de l'écran,
# au-dessus de la barre d'objets : en haut, ce que fait le clic gauche (Creuser / Casser, Casser / Récupérer des
# objets, Récupérer des matériaux) ; en bas, le clic droit (Poser, Aplanir, Lisser). Chaque case : une petite image
# et un petit texte dessous (cases juste assez larges pour tout le texte). 0.0.8.14 (#247, demande de l'utilisateur) :
# les images sont faites dans Blender à partir des modèles du jeu (menu_images.gd), avec la main du personnage ; un peu
# plus grandes (54 points, avant 46 : dessins plus simples).
# La molette choisit dans la ligne active (aussitôt pris en compte) ; T (ou B + T) passe à l'autre ligne ; un clic,
# Échap ou Entrée ferme le menu (Échap n'ouvre pas la pause), ou un moment sans rien toucher (IDLE_SECONDS).

signal chosen(row: int, index: int)

const ROWS := [
	# 0.0.8.9 (demande de l'utilisateur) : « Casser / Arracher » : arrache les mauvaises herbes, qui restent au sol.
	["Creuser / Casser", "Casser / Récupérer des objets", "Récupérer des matériaux", "Casser / Arracher"],
	["Poser", "Aplanir", "Lisser", "Manger"],
]
const ROW_NAMES := ["Clic gauche", "Clic droit"]
const IDLE_SECONDS := 2.5
const ICON := 54.0
const MenuImages = preload("res://scripts/menu_images.gd")
const GAP := 10.0

var selected := [0, 0]
var row := 0
var idle := 0.0
var text_scale := 1.0
var bottom_margin := 90.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Images réduites proprement (mipmaps), à toutes les tailles du texte.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	visible = false

func is_open() -> bool:
	return visible

func open(left_mode: int, brush: int) -> void:
	selected = [left_mode, brush]
	row = 0
	idle = 0.0
	visible = true
	queue_redraw()

func close() -> void:
	visible = false

func switch_row() -> void:
	row = 1 - row
	idle = 0.0
	queue_redraw()

func move(step: int) -> void:
	selected[row] = wrapi(selected[row] + step, 0, ROWS[row].size())
	idle = 0.0
	chosen.emit(row, selected[row])
	queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	idle += delta
	if idle >= IDLE_SECONDS:
		close()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			move(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			move(1)
		else:
			close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
			close()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_T or event.keycode == KEY_T:
			switch_row()
			get_viewport().set_input_as_handled()
	elif event is InputEventAction and event.pressed and event.action == "brush_next":
		switch_row()
		get_viewport().set_input_as_handled()

# 0.0.8.9 (demandes de l'utilisateur) : toutes les cases du menu ont la même largeur ; un nom long va sur deux lignes.
const TILE_WIDTH := 112.0

func _tile_width(_label: String) -> float:
	return TILE_WIDTH * text_scale

# Le nom en une ou deux lignes (coupé à l'espace le plus proche du milieu).
func _label_lines(label: String) -> Array:
	var font := get_theme_default_font()
	var size := roundi(12 * text_scale)
	if font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= (TILE_WIDTH - 6.0) * text_scale:
		return [label]
	var best := -1
	for index in range(label.length()):
		if label[index] == " " and (best < 0 or absi(index - label.length() / 2) < absi(best - label.length() / 2)):
			best = index
	if best < 0:
		return [label]
	return [label.left(best).strip_edges(), label.substr(best + 1).strip_edges()]

# Cases d'une ligne : [rectangle de la case, texte], centrées en bas.
func tiles(row_index: int) -> Array:
	var widths: Array = ROWS[row_index].map(func(label): return _tile_width(label))
	var total := 0.0
	for width in widths:
		total += width
	total += GAP * text_scale * (widths.size() - 1)
	var tile_height := ICON * text_scale + 34.0 * text_scale
	var screen := get_viewport_rect().size
	var bottom := screen.y - bottom_margin - (1 - row_index) * (tile_height + 14.0 * text_scale)
	var x := (screen.x - total) * 0.5
	var made := []
	for index in range(widths.size()):
		made.append([Rect2(x, bottom - tile_height, widths[index], tile_height), ROWS[row_index][index]])
		x += widths[index] + GAP * text_scale
	return made

func _draw() -> void:
	var font := get_theme_default_font()
	var font_size := roundi(12 * text_scale)
	for row_index in range(2):
		var active := row_index == row
		var row_tiles := tiles(row_index)
		var first: Rect2 = row_tiles[0][0]
		draw_string(font, Vector2(first.position.x - 8.0 * text_scale - font.get_string_size(ROW_NAMES[row_index], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, first.position.y + 18.0 * text_scale), ROW_NAMES[row_index], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.95 if active else 0.55))
		for index in range(row_tiles.size()):
			var rect: Rect2 = row_tiles[index][0]
			var picked: bool = selected[row_index] == index
			# 0.0.8.9 (demande de l'utilisateur) : bleu-violet, un peu futuriste (avant presque noir).
			draw_rect(rect, Color(0.17, 0.14, 0.32, 0.82 if active else 0.55))
			if picked:
				draw_rect(rect, Color("#f2c94c") if active else Color(0.95, 0.8, 0.3, 0.6), false, 3.0 * text_scale)
			var icon := Rect2(rect.position.x + (rect.size.x - ICON * text_scale) * 0.5, rect.position.y + 2.0 * text_scale, ICON * text_scale, ICON * text_scale)
			_icon(row_index, index, icon, 1.0 if active else 0.6)
			var lines := _label_lines(row_tiles[index][1])
			for line in range(lines.size()):
				var width := font.get_string_size(lines[line], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				var baseline := rect.end.y - 5.0 * text_scale - (lines.size() - 1 - line) * (font_size + 2.0)
				draw_string(font, Vector2(rect.position.x + (rect.size.x - width) * 0.5, baseline), lines[line], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 1.0 if active else 0.6))

# Image d'une case (menu_images.gd), plus pâle sur la ligne qui n'est pas active.
func _icon(row_index: int, index: int, box: Rect2, alpha: float) -> void:
	var picture := MenuImages.action(row_index, index)
	if picture != null:
		draw_texture_rect(picture, box, false, Color(1.0, 1.0, 1.0, alpha))

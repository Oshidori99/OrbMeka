extends Control
# 0.0.7.17 (demande de l'utilisateur) : menu des actions, ouvert avec B + T. Deux lignes de cases en bas de l'écran,
# au-dessus de la barre d'objets : en haut, ce que fait le clic gauche (Creuser / Casser, Casser / Récupérer des
# objets, Récupérer des matériaux) ; en bas, le clic droit (Poser, Aplanir, Lisser). Chaque case : une petite image
# dessinée ici et un petit texte dessous (cases juste assez larges pour tout le texte).
# La molette choisit dans la ligne active (aussitôt pris en compte) ; T (ou B + T) passe à l'autre ligne ; un clic,
# Échap ou Entrée ferme le menu (Échap n'ouvre pas la pause), ou un moment sans rien toucher (IDLE_SECONDS).

signal chosen(row: int, index: int)

const ROWS := [
	["Creuser / Casser", "Casser / Récupérer des objets", "Récupérer des matériaux"],
	["Poser", "Aplanir", "Lisser"],
]
const ROW_NAMES := ["Clic gauche", "Clic droit"]
const IDLE_SECONDS := 2.5
const ICON := 46.0
const GAP := 10.0

var selected := [0, 0]
var row := 0
var idle := 0.0
var text_scale := 1.0
var bottom_margin := 90.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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

# Largeur d'une case : l'image, ou le texte s'il est plus large.
func _tile_width(label: String) -> float:
	var font := get_theme_default_font()
	var size := roundi(12 * text_scale)
	return maxf(ICON * text_scale, font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 10.0 * text_scale)

# Cases d'une ligne : [rectangle de la case, texte], centrées en bas.
func tiles(row_index: int) -> Array:
	var widths: Array = ROWS[row_index].map(func(label): return _tile_width(label))
	var total := 0.0
	for width in widths:
		total += width
	total += GAP * text_scale * (widths.size() - 1)
	var tile_height := ICON * text_scale + 20.0 * text_scale
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
			draw_rect(rect, Color(0.08, 0.09, 0.1, 0.78 if active else 0.5))
			if picked:
				draw_rect(rect, Color("#f2c94c") if active else Color(0.95, 0.8, 0.3, 0.6), false, 3.0 * text_scale)
			var icon := Rect2(rect.position.x + (rect.size.x - ICON * text_scale) * 0.5, rect.position.y + 2.0 * text_scale, ICON * text_scale, ICON * text_scale)
			_icon(row_index, index, icon, 1.0 if active else 0.6)
			var label: String = row_tiles[index][1]
			var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(font, Vector2(rect.position.x + (rect.size.x - width) * 0.5, rect.end.y - 5.0 * text_scale), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 1.0 if active else 0.6))

# Petites images simples (formes de base, couleurs du jeu).
func _icon(row_index: int, index: int, box: Rect2, alpha: float) -> void:
	var c := box.get_center()
	var s := box.size.x
	var wood := Color(0.55, 0.36, 0.2, alpha)
	var earth := Color(0.48, 0.33, 0.2, alpha)
	var light := Color(0.85, 0.7, 0.48, alpha)
	var metal := Color(0.7, 0.72, 0.75, alpha)
	var leaf := Color(0.35, 0.6, 0.25, alpha)
	var white := Color(1, 1, 1, alpha)
	match [row_index, index]:
		[0, 0]:
			# Creuser / Casser : une pelle plantée dans un tas de terre.
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.42, 0.4) * s, c + Vector2(0.42, 0.4) * s, c + Vector2(0.0, 0.08) * s]), earth)
			draw_line(c + Vector2(0.28, -0.4) * s, c + Vector2(0.02, 0.12) * s, wood, 0.07 * s)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.06, 0.06) * s, c + Vector2(0.1, 0.14) * s, c + Vector2(-0.02, 0.36) * s, c + Vector2(-0.16, 0.26) * s]), metal)
		[0, 1]:
			# Casser / Récupérer des objets : un bâton cassé en deux et une flèche vers le haut.
			draw_line(c + Vector2(-0.42, 0.28) * s, c + Vector2(-0.06, 0.12) * s, wood, 0.11 * s)
			draw_line(c + Vector2(0.06, 0.06) * s, c + Vector2(0.42, -0.1) * s, wood, 0.11 * s)
			draw_circle(c + Vector2(-0.06, 0.12) * s, 0.05 * s, light)
			draw_line(c + Vector2(0.0, -0.06) * s, c + Vector2(0.0, -0.42) * s, white, 0.05 * s)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.12, -0.3) * s, c + Vector2(0.12, -0.3) * s, c + Vector2(0.0, -0.46) * s]), white)
		[0, 2]:
			# Récupérer des matériaux : une poignée de terre au-dessus d'un tas.
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.44, 0.4) * s, c + Vector2(0.44, 0.4) * s, c + Vector2(0.18, 0.12) * s, c + Vector2(-0.2, 0.14) * s]), earth)
			draw_circle(c + Vector2(0.0, -0.16) * s, 0.15 * s, Color(earth.r * 1.15, earth.g * 1.15, earth.b * 1.15, alpha))
			draw_line(c + Vector2(0.0, 0.06) * s, c + Vector2(0.0, -0.02) * s, white, 0.04 * s)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.3, -0.06) * s, c + Vector2(-0.18, -0.06) * s, c + Vector2(-0.24, -0.16) * s]), white)
		[1, 0]:
			# Poser : un bloc de terre (cube vu de biais).
			var top := PackedVector2Array([c + Vector2(0.0, -0.36) * s, c + Vector2(0.34, -0.18) * s, c + Vector2(0.0, 0.0) * s, c + Vector2(-0.34, -0.18) * s])
			draw_colored_polygon(top, leaf)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.34, -0.18) * s, c, c + Vector2(0.0, 0.4) * s, c + Vector2(-0.34, 0.22) * s]), earth)
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(0.34, -0.18) * s, c + Vector2(0.34, 0.22) * s, c + Vector2(0.0, 0.4) * s]), Color(earth.r * 0.8, earth.g * 0.8, earth.b * 0.8, alpha))
		[1, 1]:
			# Aplanir : une bosse coupée à plat.
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.44, 0.36) * s, c + Vector2(-0.24, 0.0) * s, c + Vector2(0.24, 0.0) * s, c + Vector2(0.44, 0.36) * s]), earth)
			draw_line(c + Vector2(-0.4, 0.0) * s, c + Vector2(0.4, 0.0) * s, light, 0.05 * s)
			draw_line(c + Vector2(-0.24, -0.2) * s, c + Vector2(0.24, -0.2) * s, Color(white.r, white.g, white.b, alpha * 0.5), 0.03 * s)
		[1, 2]:
			# Lisser : un sol en vague douce.
			var wave := PackedVector2Array()
			for step in range(13):
				var x := -0.44 + step * 0.88 / 12.0
				wave.append(c + Vector2(x, 0.08 + sin(x * 7.0) * 0.08) * s)
			var ground := wave.duplicate()
			ground.append(c + Vector2(0.44, 0.4) * s)
			ground.append(c + Vector2(-0.44, 0.4) * s)
			draw_colored_polygon(ground, earth)
			draw_polyline(wave, light, 0.05 * s)

extends RefCounted
# Thème commun des menus, ambiance « Orbe violet » (0.0.2.12) : violet profond et chaleureux,
# accents sable doré (couleur du bloc Sable) et turquoise doux ; coins peu arrondis, esprit « blocs ».
# Variations de Label : OrbTitle (titres de page), OrbSection (sous-titres), OrbNote (textes discrets).

const PANEL := Color(0.13, 0.08, 0.21, 0.9)
const BUTTON := Color("#3a2858")
const BUTTON_HOVER := Color("#503a78")
const BUTTON_PRESSED := Color("#2a1c42")
const FIELD := Color("#1d1430")
const ACCENT := Color("#f0cf7f")
const ACCENT_SOFT := Color(0.94, 0.81, 0.5, 0.35)
const ACCENT_FAINT := Color(0.94, 0.81, 0.5, 0.2)
const TURQUOISE := Color("#7fd6c8")
const TEXT := Color("#efe8f7")
const TEXT_DIM := Color("#b3a6c9")
const ERROR := Color("#ffb7a8")

static func _box(color: Color, radius: int, border: Color = Color.TRANSPARENT, border_width: int = 0, margin: Vector2 = Vector2(14, 8)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.border_color = border
	box.set_border_width_all(border_width)
	box.content_margin_left = margin.x
	box.content_margin_right = margin.x
	box.content_margin_top = margin.y
	box.content_margin_bottom = margin.y
	return box

static func panel_style() -> StyleBoxFlat:
	var box := _box(PANEL, 8, ACCENT_SOFT, 2, Vector2(30, 28))
	box.shadow_color = Color(0.05, 0.02, 0.1, 0.45)
	box.shadow_size = 14
	return box

static func _button_box(color: Color, border: Color, border_width: int) -> StyleBoxFlat:
	# Bord inférieur plus épais : effet de pavé posé, comme un bloc.
	var box := _box(color, 6, border, border_width)
	box.border_width_bottom = border_width + 3
	return box

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	# Boutons : pavés violets, contour sable au survol et au focus clavier.
	theme.set_stylebox("normal", "Button", _button_box(BUTTON, Color("#251838"), 1))
	theme.set_stylebox("hover", "Button", _button_box(BUTTON_HOVER, ACCENT, 1))
	theme.set_stylebox("pressed", "Button", _box(BUTTON_PRESSED, 6, ACCENT, 1))
	theme.set_stylebox("hover_pressed", "Button", _box(BUTTON_PRESSED, 6, ACCENT, 1))
	theme.set_stylebox("disabled", "Button", _box(Color(BUTTON, 0.45), 6))
	var focus := _box(Color.TRANSPARENT, 8, ACCENT, 2)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", ACCENT)
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_color("font_hover_pressed_color", "Button", ACCENT)
	theme.set_color("font_disabled_color", "Button", Color(TEXT_DIM, 0.5))
	theme.set_font_size("font_size", "Button", 20)
	# Textes.
	theme.set_color("font_color", "Label", TEXT)
	theme.set_type_variation("OrbTitle", "Label")
	theme.set_font_size("font_size", "OrbTitle", 34)
	theme.set_color("font_color", "OrbTitle", ACCENT)
	theme.set_color("font_outline_color", "OrbTitle", Color("#2a1440"))
	theme.set_constant("outline_size", "OrbTitle", 6)
	theme.set_type_variation("OrbSection", "Label")
	theme.set_font_size("font_size", "OrbSection", 22)
	theme.set_color("font_color", "OrbSection", TURQUOISE)
	theme.set_type_variation("OrbNote", "Label")
	theme.set_font_size("font_size", "OrbNote", 16)
	theme.set_color("font_color", "OrbNote", TEXT_DIM)
	# Champs de saisie et liste des mondes.
	for state in ["normal", "read_only"]:
		theme.set_stylebox(state, "LineEdit", _box(FIELD, 6, ACCENT_FAINT, 1))
	theme.set_stylebox("focus", "LineEdit", _box(Color.TRANSPARENT, 6, ACCENT, 2))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", Color(TEXT_DIM, 0.7))
	theme.set_color("caret_color", "LineEdit", ACCENT)
	theme.set_color("selection_color", "LineEdit", Color(ACCENT, 0.3))
	theme.set_stylebox("panel", "ItemList", _box(FIELD, 6, ACCENT_FAINT, 1, Vector2(8, 8)))
	theme.set_stylebox("focus", "ItemList", _box(Color.TRANSPARENT, 6, ACCENT, 2))
	theme.set_stylebox("selected", "ItemList", _box(BUTTON_HOVER, 4))
	theme.set_stylebox("selected_focus", "ItemList", _box(BUTTON_HOVER, 4, ACCENT, 1))
	theme.set_stylebox("hovered", "ItemList", _box(Color(BUTTON_HOVER, 0.5), 4))
	theme.set_stylebox("cursor", "ItemList", _box(Color.TRANSPARENT, 4))
	theme.set_stylebox("cursor_unfocused", "ItemList", _box(Color.TRANSPARENT, 4))
	theme.set_color("font_color", "ItemList", TEXT)
	theme.set_color("font_selected_color", "ItemList", Color.WHITE)
	theme.set_color("font_hovered_color", "ItemList", Color.WHITE)
	theme.set_constant("v_separation", "ItemList", 8)
	# Barres de défilement fines.
	theme.set_stylebox("scroll", "VScrollBar", _box(Color(FIELD, 0.6), 3, Color.TRANSPARENT, 0, Vector2(3, 3)))
	theme.set_stylebox("grabber", "VScrollBar", _box(Color(ACCENT, 0.5), 3))
	theme.set_stylebox("grabber_highlight", "VScrollBar", _box(ACCENT, 3))
	theme.set_stylebox("grabber_pressed", "VScrollBar", _box(ACCENT, 3))
	theme.set_stylebox("focus", "ScrollContainer", _box(Color.TRANSPARENT, 6, ACCENT_SOFT, 1))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_stylebox("panel", "TooltipPanel", _box(FIELD, 4, ACCENT_SOFT, 1))
	return theme

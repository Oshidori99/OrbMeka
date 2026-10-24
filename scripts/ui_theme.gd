extends RefCounted
# Thème commun des menus, ambiance « Orbe violet » (0.0.2.12) : violet profond et chaleureux,
# accents sable doré (couleur du bloc Sable) et turquoise doux ; coins peu arrondis, esprit « blocs ».
# Textes des menus : RichTextLabel sélectionnables (copie possible), variations OrbTitle
# (titres de page), OrbSection (sous-titres), OrbNote (textes discrets).
# text_scale : réglage Vidéo → Taille du texte (1.0 = tailles d'origine).
# mode : réglage Vidéo → Thème (« dark », « default », « light ») ; « default » = couleurs d'origine.
# Profondeur (0.0.3.5) : sous le titre, le contenu est dans un encadré creusé (OrbInset),
# et les blocs de réglages dans un second encadré plus profond (OrbInsetDeep).

# Couleurs du thème par défaut (gardées en constantes pour les autres scripts).
const PANEL := Color(0.13, 0.08, 0.21, 0.62)
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
const RESET := Color("#f0a640")
const RESET_HOVER := Color("#ffc25e")
const RESET_PRESSED := Color("#d88a2a")
const LAUNCH := Color("#2f9e58")
const LAUNCH_HOVER := Color("#3bbd6b")
const LAUNCH_PRESSED := Color("#237a43")
# Écran du launcher (0.0.4.1) : gris neutre et opaque, pour sortir de l'ambiance du jeu.
const LAUNCHER_SCREEN := Color("#16181d")
const LAUNCHER_PANEL := Color("#22252c")
# 0.0.4.17 : dans un navigateur, pas de polices du système pour compléter celle de Godot : les symboles
# (↻ ▾ ← ⌫ ▼ ✕ ⚙ ✏ ➕…) et emojis (🗑 📋) viennent de DejaVu Sans et Noto Emoji (licences dans
# assets/fonts/ et LICENCES.txt). Sur Windows, rien ne change (le système complète déjà).
const WEB_FALLBACK_FONTS := ["res://assets/fonts/DejaVuSans.ttf", "res://assets/fonts/NotoEmoji.ttf"]

static func use_web_fonts(force := false) -> void:
	if not (force or OS.has_feature("web")):
		return
	var base: Font = ThemeDB.fallback_font
	var fallbacks: Array[Font] = []
	for path in WEB_FALLBACK_FONTS:
		fallbacks.append(load(path))
	base.fallbacks = fallbacks
const MODES := ["dark", "default", "light"]
# Facteur des marges intérieures pendant la construction du thème (Taille des zones et boutons).
static var spacing := 1.0

static func palette(mode: String = "default") -> Dictionary:
	var colors := {
		"panel": PANEL, "button": BUTTON, "button_hover": BUTTON_HOVER, "button_pressed": BUTTON_PRESSED,
		"button_edge": Color("#251838"), "field": FIELD, "accent": ACCENT, "section": TURQUOISE,
		"text": TEXT, "text_strong": Color.WHITE, "text_dim": TEXT_DIM, "error": ERROR,
		"shadow": Color(0.05, 0.02, 0.1, 0.6), "title_outline": Color("#2a1440"),
		"inset": Color(0.04, 0.02, 0.08, 0.3), "inset_edge": Color(0.02, 0.01, 0.05, 0.55),
		"panel_shadow": Color(0.05, 0.02, 0.1, 0.45),
	}
	if mode == "dark":
		colors.merge({
			"panel": Color(0.05, 0.035, 0.08, 0.88), "button": Color("#261a3a"), "button_hover": Color("#3a2b56"),
			"button_pressed": Color("#191126"), "button_edge": Color("#0e0916"), "field": Color("#110b1b"),
			"section": Color("#6cc4b6"), "text": Color("#e4ddee"), "text_dim": Color("#9a8fae"),
			"inset": Color(0.0, 0.0, 0.0, 0.35), "inset_edge": Color(0.0, 0.0, 0.0, 0.6),
		}, true)
	elif mode == "light":
		colors.merge({
			"panel": Color(0.96, 0.94, 0.99, 0.92), "button": Color("#ddd0f0"), "button_hover": Color("#cdb9ec"),
			"button_pressed": Color("#bba5e0"), "button_edge": Color("#9c86c4"), "field": Color("#ffffff"),
			"accent": Color("#8a5a00"), "section": Color("#1d7468"), "text": Color("#241638"),
			"text_strong": Color("#100820"), "text_dim": Color("#5e5175"), "error": Color("#b3261e"),
			"shadow": Color(1, 1, 1, 0.0), "title_outline": Color("#fff6e0"),
			"inset": Color(0.4, 0.3, 0.6, 0.1), "inset_edge": Color(0.3, 0.2, 0.5, 0.3),
			"panel_shadow": Color(0.2, 0.1, 0.3, 0.25),
		}, true)
	return colors

static func _box(color: Color, radius: int, border: Color = Color.TRANSPARENT, border_width: int = 0, margin: Vector2 = Vector2(14, 8)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.border_color = border
	box.set_border_width_all(border_width)
	box.content_margin_left = margin.x * spacing
	box.content_margin_right = margin.x * spacing
	box.content_margin_top = margin.y * spacing
	box.content_margin_bottom = margin.y * spacing
	return box

static func scaled(size: int, text_scale: float) -> int:
	return maxi(5, roundi(size * text_scale))

static func panel_style(mode: String = "default") -> StyleBoxFlat:
	var colors := palette(mode)
	var box := _box(colors.panel, 8, Color(colors.accent, 0.35), 2, Vector2(26, 22))
	box.shadow_color = colors.panel_shadow
	box.shadow_size = 14
	return box

static func inset_style(colors: Dictionary, margin: Vector2) -> StyleBoxFlat:
	# Encadré creusé : fond plus sombre, bord haut épais (ombre intérieure), bord bas fin.
	var box := _box(colors.inset, 6, colors.inset_edge, 1, margin)
	box.border_width_top = 3
	return box

static func _button_box(color: Color, border: Color, border_width: int) -> StyleBoxFlat:
	# Bord inférieur plus épais : effet de pavé posé, comme un bloc.
	var box := _box(color, 6, border, border_width)
	box.border_width_bottom = border_width + 3
	return box

static func _tab_box(color: Color, mark: Color) -> StyleBoxFlat:
	# Barre verticale à gauche : repère de la section ouverte.
	var box := _box(color, 0, mark, 0, Vector2(14, 10))
	box.border_width_left = 4
	return box

static func build(text_scale: float = 1.0, mode: String = "default", depth: bool = true, element_scale: float = 1.0) -> Theme:
	# Taille des zones et boutons (0.0.3.10) : marges intérieures des cadres, boutons et champs.
	spacing = element_scale
	var c := palette(mode)
	var theme := Theme.new()
	theme.default_font_size = scaled(18, text_scale)
	theme.set_stylebox("panel", "PanelContainer", panel_style(mode))
	theme.set_type_variation("OrbInset", "PanelContainer")
	# Profondeur désactivée (Vidéo → Profondeur des menus : Non) : encadrés invisibles et sans marge.
	theme.set_stylebox("panel", "OrbInset", inset_style(c, Vector2(14, 12)) if depth else StyleBoxEmpty.new())
	theme.set_type_variation("OrbInsetDeep", "PanelContainer")
	theme.set_stylebox("panel", "OrbInsetDeep", inset_style(c, Vector2(12, 8)) if depth else StyleBoxEmpty.new())
	# Boutons : pavés violets, contour sable au survol et au focus clavier.
	theme.set_stylebox("normal", "Button", _button_box(c.button, c.button_edge, 1))
	theme.set_stylebox("hover", "Button", _button_box(c.button_hover, c.accent, 1))
	theme.set_stylebox("pressed", "Button", _box(c.button_pressed, 6, c.accent, 1))
	theme.set_stylebox("hover_pressed", "Button", _box(c.button_pressed, 6, c.accent, 1))
	theme.set_stylebox("disabled", "Button", _box(Color(c.button, 0.45), 6))
	var focus := _box(Color.TRANSPARENT, 8, c.accent, 2)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", c.text)
	theme.set_color("font_hover_color", "Button", c.text_strong)
	theme.set_color("font_pressed_color", "Button", c.accent)
	theme.set_color("font_focus_color", "Button", c.text_strong)
	theme.set_color("font_hover_pressed_color", "Button", c.accent)
	theme.set_color("font_disabled_color", "Button", Color(c.text_dim, 0.5))
	theme.set_font_size("font_size", "Button", scaled(20, text_scale))
	# Onglets du menu latéral (OrbTab) : rectangles à angles droits, section active surlignée de sable.
	theme.set_type_variation("OrbTab", "Button")
	theme.set_stylebox("normal", "OrbTab", _tab_box(Color(c.button, 0.7), Color.TRANSPARENT))
	theme.set_stylebox("hover", "OrbTab", _tab_box(c.button_hover, Color(c.accent, 0.35)))
	theme.set_stylebox("pressed", "OrbTab", _tab_box(c.button_hover, c.accent))
	theme.set_stylebox("hover_pressed", "OrbTab", _tab_box(c.button_hover, c.accent))
	theme.set_color("font_pressed_color", "OrbTab", c.accent)
	theme.set_color("font_hover_pressed_color", "OrbTab", c.accent)
	theme.set_font_size("font_size", "OrbTab", scaled(18, text_scale))
	theme.set_constant("h_separation", "OrbTab", 8)
	# ↻ d'une catégorie d'attributs (OrbCategoryReset) : pavé orangé, bien visible, dans tous les thèmes.
	theme.set_type_variation("OrbCategoryReset", "Button")
	theme.set_stylebox("normal", "OrbCategoryReset", _button_box(RESET, Color("#8a4a12"), 1))
	theme.set_stylebox("hover", "OrbCategoryReset", _button_box(RESET_HOVER, Color.WHITE, 1))
	theme.set_stylebox("pressed", "OrbCategoryReset", _box(RESET_PRESSED, 6, Color.WHITE, 1))
	theme.set_stylebox("hover_pressed", "OrbCategoryReset", _box(RESET_PRESSED, 6, Color.WHITE, 1))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(state, "OrbCategoryReset", Color("#2a1440"))
	theme.set_font_size("font_size", "OrbCategoryReset", scaled(22, text_scale))
	# Jouer et ▼ du launcher (OrbLaunch, 0.0.4.1) : gros boutons verts, dans tous les thèmes.
	theme.set_type_variation("OrbLaunch", "Button")
	theme.set_stylebox("normal", "OrbLaunch", _button_box(LAUNCH, Color("#145c32"), 1))
	theme.set_stylebox("hover", "OrbLaunch", _button_box(LAUNCH_HOVER, Color.WHITE, 1))
	theme.set_stylebox("pressed", "OrbLaunch", _box(LAUNCH_PRESSED, 6, Color.WHITE, 1))
	theme.set_stylebox("hover_pressed", "OrbLaunch", _box(LAUNCH_PRESSED, 6, Color.WHITE, 1))
	theme.set_stylebox("disabled", "OrbLaunch", _box(Color(LAUNCH, 0.4), 6))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(state, "OrbLaunch", Color.WHITE)
	theme.set_font_size("font_size", "OrbLaunch", scaled(26, text_scale))
	# Autres boutons du launcher (OrbLauncherButton) : gris sobres, hors de l'ambiance du jeu.
	theme.set_type_variation("OrbLauncherButton", "Button")
	theme.set_stylebox("normal", "OrbLauncherButton", _button_box(Color("#353943"), Color("#1c1e23"), 1))
	theme.set_stylebox("hover", "OrbLauncherButton", _button_box(Color("#454a56"), Color("#9aa0ad"), 1))
	theme.set_stylebox("pressed", "OrbLauncherButton", _box(Color("#2a2d35"), 6, Color("#9aa0ad"), 1))
	theme.set_stylebox("disabled", "OrbLauncherButton", _box(Color("#353943", 0.45), 6))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(state, "OrbLauncherButton", Color("#e6e8ec"))
	# Textes.
	theme.set_color("font_color", "Label", c.text)
	# Ombre légère : texte lisible sur le panneau transparent.
	theme.set_color("font_shadow_color", "Label", c.shadow)
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_font_size("font_size", "Label", scaled(18, text_scale))
	# Textes sélectionnables des menus : mêmes couleurs et ombre que les Label.
	theme.set_color("default_color", "RichTextLabel", c.text)
	theme.set_color("font_shadow_color", "RichTextLabel", c.shadow)
	theme.set_constant("shadow_offset_x", "RichTextLabel", 1)
	theme.set_constant("shadow_offset_y", "RichTextLabel", 1)
	theme.set_color("selection_color", "RichTextLabel", Color(c.accent, 0.35))
	theme.set_font_size("normal_font_size", "RichTextLabel", scaled(18, text_scale))
	theme.set_stylebox("focus", "RichTextLabel", StyleBoxEmpty.new())
	theme.set_type_variation("OrbTitle", "RichTextLabel")
	theme.set_font_size("normal_font_size", "OrbTitle", scaled(34, text_scale))
	theme.set_color("default_color", "OrbTitle", c.accent)
	theme.set_color("font_outline_color", "OrbTitle", c.title_outline)
	theme.set_constant("outline_size", "OrbTitle", 6)
	theme.set_type_variation("OrbSection", "RichTextLabel")
	theme.set_font_size("normal_font_size", "OrbSection", scaled(22, text_scale))
	theme.set_color("default_color", "OrbSection", c.section)
	# 0.0.4.16 : trait fin et discret entre deux lignes des menus ; sous-titres (ex. Voler → Rapide).
	theme.set_type_variation("OrbRowLine", "HSeparator")
	var row_line := StyleBoxLine.new()
	row_line.color = Color(0.55, 0.55, 0.58, 0.28)
	row_line.thickness = 1
	theme.set_stylebox("separator", "OrbRowLine", row_line)
	theme.set_constant("separation", "OrbRowLine", 1)
	theme.set_type_variation("OrbSubsection", "RichTextLabel")
	theme.set_font_size("normal_font_size", "OrbSubsection", scaled(18, text_scale))
	theme.set_color("default_color", "OrbSubsection", c.section)
	# 0.0.4.14 : petits boutons Tout réduire / Tout développer / ouverture, en haut de Paramètres.
	theme.set_type_variation("OrbFold", "Button")
	theme.set_font_size("font_size", "OrbFold", scaled(14, text_scale))
	theme.set_type_variation("OrbNote", "RichTextLabel")
	theme.set_font_size("normal_font_size", "OrbNote", scaled(16, text_scale))
	theme.set_color("default_color", "OrbNote", c.text_dim)
	# Champs de saisie et liste des mondes.
	for state in ["normal", "read_only"]:
		theme.set_stylebox(state, "LineEdit", _box(c.field, 6, Color(c.accent, 0.2), 1))
	theme.set_stylebox("focus", "LineEdit", _box(Color.TRANSPARENT, 6, c.accent, 2))
	theme.set_color("font_color", "LineEdit", c.text)
	theme.set_color("font_placeholder_color", "LineEdit", Color(c.text_dim, 0.7))
	theme.set_color("caret_color", "LineEdit", c.accent)
	theme.set_color("selection_color", "LineEdit", Color(c.accent, 0.3))
	theme.set_stylebox("panel", "ItemList", _box(c.field, 6, Color(c.accent, 0.2), 1, Vector2(8, 8)))
	theme.set_stylebox("focus", "ItemList", _box(Color.TRANSPARENT, 6, c.accent, 2))
	theme.set_stylebox("selected", "ItemList", _box(c.button_hover, 4))
	theme.set_stylebox("selected_focus", "ItemList", _box(c.button_hover, 4, c.accent, 1))
	theme.set_stylebox("hovered", "ItemList", _box(Color(c.button_hover, 0.5), 4))
	theme.set_stylebox("cursor", "ItemList", _box(Color.TRANSPARENT, 4))
	theme.set_stylebox("cursor_unfocused", "ItemList", _box(Color.TRANSPARENT, 4))
	theme.set_color("font_color", "ItemList", c.text)
	theme.set_color("font_selected_color", "ItemList", c.text_strong)
	theme.set_color("font_hovered_color", "ItemList", c.text_strong)
	theme.set_constant("v_separation", "ItemList", 8)
	# Barres de réglage (0.0.3.7) : rail creusé, partie remplie couleur sable.
	theme.set_stylebox("slider", "HSlider", _box(c.field, 3, Color(c.accent, 0.3), 1, Vector2(0, 3)))
	theme.set_stylebox("grabber_area", "HSlider", _box(Color(c.accent, 0.7), 3, Color.TRANSPARENT, 0, Vector2(0, 3)))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box(c.accent, 3, Color.TRANSPARENT, 0, Vector2(0, 3)))
	theme.set_stylebox("focus", "HSlider", _box(Color.TRANSPARENT, 4, c.accent, 1))
	theme.set_stylebox("focus", "CheckButton", _box(Color.TRANSPARENT, 6, c.accent, 1))
	# Barres de défilement fines.
	theme.set_stylebox("scroll", "VScrollBar", _box(Color(c.field, 0.6), 3, Color.TRANSPARENT, 0, Vector2(3, 3)))
	theme.set_stylebox("grabber", "VScrollBar", _box(Color(c.accent, 0.5), 3))
	theme.set_stylebox("grabber_highlight", "VScrollBar", _box(c.accent, 3))
	theme.set_stylebox("grabber_pressed", "VScrollBar", _box(c.accent, 3))
	theme.set_stylebox("focus", "ScrollContainer", _box(Color.TRANSPARENT, 6, Color(c.accent, 0.35), 1))
	theme.set_color("font_color", "TooltipLabel", c.text)
	theme.set_stylebox("panel", "TooltipPanel", _box(c.field, 4, Color(c.accent, 0.35), 1))
	return theme

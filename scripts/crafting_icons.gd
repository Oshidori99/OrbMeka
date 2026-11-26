extends Button
# 0.0.8.8 (demande de l'utilisateur) : les actions de la fabrication en images (au lieu du texte ; le nom au survol et
# sous la rangée) : on reconnaît ce qu'on fait.
# 0.0.8.14 (#247, demande de l'utilisateur) : images faites dans Blender à partir des modèles du jeu (menu_images.gd),
# dans le style du menu des actions (B + T). Tresser : trois fibres de lin tressées en ficelle ; Tailler : la main frappe
# un silex avec un caillou, des éclats sautent ; Fendre : un éclat enfoncé dans le bout fendu d'une branche ;
# Assembler : la tête taillée qui descend dans la fente du manche ; Ficeler : la tête tenue par les tours de ficelle.
const MenuImages = preload("res://scripts/menu_images.gd")

var action := ""
const STAND_IN := {"detresser": "tresser", "defaire": "assembler", "relier": "ficeler", "ecorcer": "fendre"}

func _init(kind: String, side: float) -> void:
	action = kind
	custom_minimum_size = Vector2(side, side)
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	# Image réduite proprement (mipmaps), à toutes les tailles du texte.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _draw() -> void:
	# 0.0.8.40 : les nouvelles actions reprennent pour l'instant une image proche (leurs images Blender viendront plus tard).
	var picture := MenuImages.texture(STAND_IN.get(action, action))
	if picture == null:
		return
	var side := minf(size.x, size.y) * 0.9
	var box := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	draw_texture_rect(picture, box, false, Color(1.0, 1.0, 1.0, 0.45 if disabled else 1.0))

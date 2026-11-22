extends CanvasLayer
# 0.0.8.14 (rapport d'optimisation, choix de l'utilisateur) : sur un PC trop lent pour sa qualité d'affichage, une seule fois,
# un message propose la qualité Performance. Le jeu mesure ses images par seconde en jouant (après WARMUP_SECONDS, le temps
# que le monde se construise autour), par tranches de MEASURE_SECONDS ; sous LOW_FPS (ou sous 85 % de la limite d'images
# choisie, si elle est plus basse), le jeu se met en pause et propose : « Passer en Performance » (comme la choisir dans
# Paramètres → Vidéo → Qualité d'affichage) ou garder la qualité actuelle. Jamais en Performance, jamais deux fois
# (menus.json : « qualite_conseillee »). Mesuré sur une Radeon 610M (PC bon marché) : Équilibré 11 à 19 images par seconde,
# Performance environ 40.
const WARMUP_SECONDS := 10.0
const MEASURE_SECONDS := 20.0
const LOW_FPS := 30.0

const UserSettings = preload("res://scripts/user_settings.gd")

var app: Node
var panel: PanelContainer
var message: Label
var keep_button: Button
var shown := false
var _played := 0.0
var _frames := 0
var _time := 0.0

func _ready() -> void:
	name = "QualiteConseillee"
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = PanelContainer.new()
	panel.theme = app.menu_root.theme if app != null and app.get("menu_root") != null else null
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.1, 0.25, 0.94)
	style.border_color = Color(0.62, 0.55, 1.0, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(560, 0)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Le jeu est lent sur cet ordinateur"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	column.add_child(title)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size = Vector2(516, 0)
	column.add_child(message)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	keep_button = Button.new()
	keep_button.pressed.connect(func(): choose(false))
	buttons.add_child(keep_button)
	var faster := Button.new()
	faster.text = "Passer en Performance"
	faster.pressed.connect(func(): choose(true))
	buttons.add_child(faster)

# Seuil : 30 images par seconde, ou 85 % de la limite choisie si elle est plus basse.
func threshold() -> float:
	return minf(LOW_FPS, float(app.settings.values.get("max_fps", 60.0)) * 0.85)

func _watching() -> bool:
	# Jamais sans fenêtre (tests : une machine de test lente ne doit pas se mettre en pause toute seule ; ils appellent decide).
	if DisplayServer.get_name() == "headless":
		return false
	if shown or app == null or app.settings.quality_hint_done or app.settings.values.get("quality", "") == "performance":
		return false
	var world: Variant = app.get("active_world")
	if app.page != "playing" or not is_instance_valid(world) or get_tree().paused:
		return false
	return not world.inventory_open and not world.crafting_open and not world.notebook_open and not world.death_open and not world.behind_loading

func _process(delta: float) -> void:
	if not _watching():
		return
	_played += delta
	if _played < WARMUP_SECONDS:
		return
	_frames += 1
	_time += delta
	if _time >= MEASURE_SECONDS:
		decide(_frames / _time)
		_frames = 0
		_time = 0.0

# Images par seconde d'une tranche de jeu : sous le seuil, le message (vrai s'il est montré).
func decide(fps: float) -> bool:
	if shown or fps >= threshold() or app.settings.quality_hint_done or app.settings.values.get("quality", "") == "performance":
		return false
	shown = true
	app.settings.set_quality_hint_done()
	var current: String = UserSettings.CHOICES.quality.options.get(app.settings.values.get("quality", "balanced"), "actuelle")
	message.text = "Il tourne à environ %d images par seconde en qualité %s. La qualité Performance le rend bien plus fluide (moins de distance d'affichage, d'herbe et d'ombres, sol simplifié). On peut la changer à tout moment : Paramètres → Vidéo → Qualité d'affichage." % [roundi(fps), current]
	keep_button.text = "Garder %s" % current
	# Pause pendant le message, souris libre (sur le Web, sans ouvrir aussi le menu de pause).
	app.was_captured = false
	get_tree().paused = true
	if is_instance_valid(app.active_world):
		app.active_world.player.release_controls()
	visible = true
	return true

func choose(performance: bool) -> void:
	visible = false
	if performance:
		app._choose("quality", "performance")
	get_tree().paused = false
	if is_instance_valid(app.active_world) and app.page == "playing":
		app.active_world.player.resume_controls()

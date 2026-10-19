extends Control

const Catalog = preload("res://scripts/world_catalog.gd")
const WorldScene = preload("res://scenes/world.tscn")
const WorldRules = preload("res://scripts/world.gd")
const UserSettings = preload("res://scripts/user_settings.gd")
const Terrain = preload("res://scripts/terrain_generator.gd")

var settings: RefCounted
var setting_fields: Dictionary = {}
var setting_resets: Dictionary = {}
var settings_message: Label
var settings_apply_button: Button
var catalog: RefCounted
var page := "home"
var active_world: Node3D
var current_world_id := ""
var menu_root: Control
var pages: Dictionary = {}
var world_list: ItemList
var open_button: Button
var list_message: Label
var name_field: LineEdit
var seed_field: LineEdit
var world_options_title: Label
var duplicate_button: Button
var world_settings_button: Button
var world_settings_text: Label
var world_settings_back_button: Button
var form_error: Label
var return_button: Button
var play_button: Button
var settings_button: Button
var information_button: Button
var history_button: Button
var history_back_button: Button
var history_text: Label
var history_scroll: ScrollContainer
var settings_back_button: Button
var information_back_button: Button
var generation_info: Label
var create_button: Button
var new_world_button: Button
var rename_button: Button
var delete_button: Button
var rename_field: LineEdit
var rename_error: Label
var delete_message: Label
var cancel_delete_button: Button
var pending_world_id := ""
var resume_button: Button
var how_button: Button
var help_back_button: Button
var help_text: Label
var home_version: Label
var pause_version: Label
var info_button: Button
var info_back_button: Button
var info_text: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if catalog == null:
		catalog = Catalog.new()
	if settings == null:
		settings = UserSettings.new()
	_build_interface()
	show_page("home")

func _button(text: String, parent: Node, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 46
	button.add_theme_font_size_override("font_size", 20)
	parent.add_child(button)
	button.pressed.connect(action)
	return button

func _explanation(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)

func _add_setting_row(parent: Node, key: String) -> void:
	var spec: Dictionary = UserSettings.SPECS[key]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var label := Label.new()
	label.text = "%s (%s)
Défaut : %s · %s à %s" % [spec.label, spec.unit, UserSettings.number_text(spec.default), UserSettings.number_text(spec.min), UserSettings.number_text(spec.max)]
	label.add_theme_font_size_override("font_size", 15)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var field := LineEdit.new()
	field.custom_minimum_size = Vector2(85,46)
	field.max_length = 24
	field.placeholder_text = UserSettings.number_text(spec.default)
	field.tooltip_text = "%s — %s à %s %s" % [spec.label, UserSettings.number_text(spec.min), UserSettings.number_text(spec.max), spec.unit]
	row.add_child(field)
	field.text_submitted.connect(func(_text: String): apply_user_settings())
	setting_fields[key] = field
	var reset := _button("↻", row, func(): reset_setting(key))
	reset.custom_minimum_size.x = 42
	reset.tooltip_text = "Rétablir le défaut de ce champ : " + UserSettings.number_text(spec.default)
	setting_resets[key] = reset

func _fill_settings() -> void:
	for key in setting_fields:
		setting_fields[key].text = UserSettings.number_text(settings.values[key])
	settings_message.text = settings.load_notice

func reset_setting(key: String) -> void:
	setting_fields[key].text = UserSettings.number_text(UserSettings.SPECS[key].default)
	settings_message.text = "Défaut rétabli pour ce champ. Appliquer pour enregistrer."

func apply_user_settings() -> void:
	var texts := {}
	for key in setting_fields:
		texts[key] = setting_fields[key].text
	if not settings.apply_texts(texts):
		settings_message.text = settings.last_error
		return
	_fill_settings()
	settings_message.text = "Paramètres enregistrés."

func _page(parent: Node, heading: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	parent.add_child(box)
	var title := Label.new()
	title.text = heading
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)
	return box

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	menu_root = Control.new()
	layer.add_child(menu_root)
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("#142735")
	menu_root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	menu_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 560
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#243e4d")
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var stack := VBoxContainer.new()
	panel.add_child(stack)
	var home := _page(stack, "OrbMeka™")
	pages.home = home
	var version := Label.new()
	version.text = "v" + str(ProjectSettings.get_setting("application/config/version", "0.0.2.10"))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home.add_child(version)
	home_version = version
	play_button = _button("Jouer", home, func(): show_page("worlds"))
	settings_button = _button("Paramètres", home, func(): show_page("settings"))
	information_button = _button("Informations", home, func(): show_page("information"))
	history_button = _button("Historique des versions", home, open_history)
	var history_page := _page(stack, "Historique des versions")
	pages.history = history_page
	history_scroll = ScrollContainer.new()
	history_scroll.custom_minimum_size = Vector2(0, 350)
	history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	history_scroll.focus_mode = Control.FOCUS_ALL
	history_page.add_child(history_scroll)
	history_text = Label.new()
	history_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	history_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_text.add_theme_font_size_override("font_size", 17)
	history_scroll.add_child(history_text)
	history_back_button = _button("Retour", history_page, func(): show_page("home"))
	var settings_page := _page(stack, "Attributs")
	settings_page.add_theme_constant_override("separation", 10)
	pages.settings = settings_page
	var settings_scroll := ScrollContainer.new()
	settings_scroll.custom_minimum_size = Vector2(0, 320)
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_scroll.focus_mode = Control.FOCUS_ALL
	settings_scroll.follow_focus = true
	settings_page.add_child(settings_scroll)
	var attributes := VBoxContainer.new()
	attributes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attributes.add_theme_constant_override("separation", 10)
	settings_scroll.add_child(attributes)
	_explanation(attributes, "Saut")
	attributes.get_child(-1).add_theme_font_size_override("font_size", 22)
	_explanation(attributes, "Hauteur : sommet visé (1 m = 1 bloc).
Vitesse : départ plus vif ou plus doux ; hauteur conservée.
Gravité de descente : retombée plus ou moins rapide.")
	for key in ["jump_height", "jump_speed", "fall_gravity"]:
		_add_setting_row(attributes, key)
	_explanation(attributes, "Blocs")
	attributes.get_child(-1).add_theme_font_size_override("font_size", 22)
	_explanation(attributes, "Temps entre deux actions au maintien du clic.
Première action immédiate ; un délai plus court accélère la répétition.")
	for key in ["place_ms", "break_ms"]:
		_add_setting_row(attributes, key)
	_explanation(attributes, "↻ : défaut de ce champ. Champ vide : défaut.
Appliquer enregistre pour tous les mondes. Retour annule les modifications.")
	settings_message = Label.new()
	settings_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_page.add_child(settings_message)
	settings_apply_button = _button("Appliquer", settings_page, apply_user_settings)
	settings_back_button = _button("Retour", settings_page, func(): show_page("home"))
	var information_page := _page(stack, "Génération des mondes")
	pages.information = information_page
	generation_info = Label.new()
	generation_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var span := Terrain.MAX_CELL - Terrain.MIN_CELL + 1
	generation_info.text = "Base plate : largeur %d × longueur %d blocs
Zone de génération : largeur %d × longueur %d blocs
Construction : hauteur maximale %d blocs au-dessus du sol plat, collines comprises.
Collines : 3 ou 4, hauteur maximale %d blocs

Graine choisie à la création, ou aléatoire si le champ est vide.
Nom et graine conservés ; constructions non sauvegardées.
Réouvrir un monde régénère son terrain initial.
F1 : revenir à la liste des mondes depuis la partie." % [int(WorldRules.BASE_SIZE.x), int(WorldRules.BASE_SIZE.z), span, span, WorldRules.MAX_BUILD_HEIGHT, Terrain.MAX_HEIGHT]
	information_page.add_child(generation_info)
	information_back_button = _button("Retour", information_page, func(): show_page("home"))
	var list_page := _page(stack, "Mes mondes")
	pages.worlds = list_page
	list_page.add_theme_constant_override("separation", 10)
	world_list = ItemList.new()
	world_list.custom_minimum_size = Vector2(0, 144)
	world_list.add_theme_font_size_override("font_size", 21)
	list_page.add_child(world_list)
	world_list.item_selected.connect(func(_index: int): _update_world_actions())
	world_list.item_activated.connect(func(_index: int): open_selected_world())
	list_message = Label.new()
	list_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_page.add_child(list_message)
	var actions_row := HBoxContainer.new()
	actions_row.add_theme_constant_override("separation", 10)
	list_page.add_child(actions_row)
	open_button = _button("Ouvrir", actions_row, open_selected_world)
	rename_button = _button("Renommer", actions_row, request_rename)
	delete_button = _button("Supprimer", actions_row, request_delete)
	for button in [open_button, rename_button, delete_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var extra_actions := HBoxContainer.new()
	extra_actions.add_theme_constant_override("separation", 10)
	list_page.add_child(extra_actions)
	duplicate_button = _button("Dupliquer", extra_actions, duplicate_selected_world)
	world_settings_button = _button("Paramètres du monde", extra_actions, open_world_settings)
	for button in [duplicate_button, world_settings_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_world_button = _button("Créer un monde", list_page, func(): show_page("create"))
	_button("Retour", list_page, func(): show_page("home"))
	var form := _page(stack, "Créer un monde")
	pages.create = form
	var name_label := Label.new()
	name_label.text = "Nom du monde"
	form.add_child(name_label)
	_explanation(form, "Un nom de 1 à %d caractères suffit.
Graine facultative : vide pour un terrain aléatoire.
Nom et graine conservés ; constructions non sauvegardées." % Catalog.MAX_NAME_LENGTH)
	name_field = LineEdit.new()
	name_field.placeholder_text = "Mon monde"
	name_field.max_length = Catalog.MAX_NAME_LENGTH
	name_field.custom_minimum_size.y = 46
	name_field.add_theme_font_size_override("font_size", 22)
	form.add_child(name_field)
	name_field.text_submitted.connect(func(_text: String): create_named_world())
	var seed_label := Label.new()
	seed_label.text = "Graine de génération (facultatif)"
	form.add_child(seed_label)
	seed_field = LineEdit.new()
	seed_field.placeholder_text = "Vide : aléatoire · Entier de 0 à 4294967295"
	seed_field.max_length = 32
	seed_field.custom_minimum_size.y = 46
	seed_field.add_theme_font_size_override("font_size", 18)
	form.add_child(seed_field)
	seed_field.text_submitted.connect(func(_text: String): create_named_world())
	world_options_title = Label.new()
	world_options_title.text = "Options du monde"
	world_options_title.add_theme_font_size_override("font_size", 22)
	form.add_child(world_options_title)
	form_error = Label.new()
	form_error.add_theme_color_override("font_color", Color("#ffcfb4"))
	form_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(form_error)
	create_button = _button("Créer", form, create_named_world)
	_button("Retour", form, func(): show_page("worlds"))
	var world_settings_page := _page(stack, "Paramètres du monde")
	pages.world_settings = world_settings_page
	world_settings_text = Label.new()
	world_settings_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	world_settings_page.add_child(world_settings_text)
	world_settings_back_button = _button("Retour", world_settings_page, cancel_world_action)
	var rename_page := _page(stack, "Renommer le monde")
	pages.rename = rename_page
	_explanation(rename_page, "Seul le nom change (1 à %d caractères).
La graine et le terrain initial sont conservés." % Catalog.MAX_NAME_LENGTH)
	rename_field = LineEdit.new()
	rename_field.max_length = Catalog.MAX_NAME_LENGTH
	rename_field.custom_minimum_size.y = 46
	rename_page.add_child(rename_field)
	rename_field.text_submitted.connect(func(_text: String): confirm_rename())
	rename_error = Label.new()
	rename_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rename_page.add_child(rename_error)
	_button("Renommer", rename_page, confirm_rename)
	_button("Annuler", rename_page, cancel_world_action)
	var delete_page := _page(stack, "Supprimer ce monde ?")
	pages.delete = delete_page
	delete_message = Label.new()
	delete_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	delete_page.add_child(delete_message)
	_button("Confirmer la suppression", delete_page, confirm_delete)
	cancel_delete_button = _button("Annuler", delete_page, cancel_world_action)
	var pause_page := _page(stack, "Pause")
	pages.pause = pause_page
	pause_version = Label.new()
	pause_version.text = version.text
	pause_version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_page.add_child(pause_version)
	resume_button = _button("Reprendre", pause_page, resume_game)
	how_button = _button("Comment jouer", pause_page, open_help)
	info_button = _button("Informations du monde", pause_page, open_world_info)
	_button("Retour aux mondes", pause_page, return_to_worlds)
	var help_page := _page(stack, "Comment jouer")
	pages.help = help_page
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 350)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	help_page.add_child(scroll)
	help_text = Label.new()
	help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help_text.add_theme_font_size_override("font_size", 17)
	scroll.add_child(help_text)
	help_back_button = _button("Retour à la pause", help_page, func(): show_page("pause"))
	var info_page := _page(stack, "Informations du monde")
	pages.world_info = info_page
	info_text = Label.new()
	info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_page.add_child(info_text)
	info_back_button = _button("Retour à la pause", info_page, func(): show_page("pause"))
	return_button = _button("Retour aux mondes (F1)", layer, return_to_worlds)
	return_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	return_button.offset_left = -280
	return_button.offset_right = -18
	return_button.offset_top = 18
	return_button.offset_bottom = 64
	var shortcut_hints := Label.new()
	shortcut_hints.name = "ShortcutHints"
	shortcut_hints.text = "F2 : Comment jouer
F3 : Informations du monde"
	shortcut_hints.position = Vector2(0, 50)
	shortcut_hints.add_theme_font_size_override("font_size", 15)
	shortcut_hints.add_theme_color_override("font_shadow_color", Color.BLACK)
	shortcut_hints.add_theme_constant_override("shadow_outline_size", 3)
	shortcut_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return_button.add_child(shortcut_hints)
	return_button.visible = false

func show_page(next_page: String) -> void:
	page = next_page
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_root.visible = true
	return_button.visible = false
	for key in pages:
		pages[key].visible = key == page
	if page == "worlds":
		refresh_world_list()
		if world_list.item_count > 0:
			world_list.grab_focus()
		else:
			# Open is disabled on an empty list; focus the next actionable button.
			new_world_button.grab_focus()
	elif page == "history":
		history_back_button.grab_focus()
	elif page == "settings":
		_fill_settings()
		setting_fields.jump_height.grab_focus()
	elif page == "information":
		information_back_button.grab_focus()
	elif page == "create":
		name_field.clear()
		seed_field.clear()
		form_error.text = ""
		create_button.disabled = not catalog.load_error.is_empty()
		name_field.grab_focus()
	elif page == "world_settings":
		world_settings_back_button.grab_focus()
	elif page == "rename":
		rename_field.grab_focus()
	elif page == "pause":
		resume_button.grab_focus()
	elif page == "world_info":
		info_back_button.grab_focus()
	elif page == "help":
		help_back_button.grab_focus()
	elif page == "delete":
		cancel_delete_button.grab_focus()
	else:
		play_button.grab_focus()

func refresh_world_list(preferred_id: String = "") -> void:
	world_list.clear()
	for item in catalog.worlds:
		world_list.add_item(item.name)
		world_list.set_item_metadata(world_list.item_count - 1, item.id)
	open_button.disabled = true
	if not catalog.load_error.is_empty():
		list_message.text = catalog.load_error
	elif world_list.item_count == 0:
		list_message.text = "Aucun monde. Créez votre premier monde."
	else:
		list_message.text = "Choisissez un monde à ouvrir."
		world_list.select(0)
		open_button.disabled = false
		for index in range(world_list.item_count):
			if world_list.get_item_metadata(index) == preferred_id:
				world_list.select(index)
	_update_world_actions()

func _selected_world_id() -> String:
	var selection := world_list.get_selected_items()
	return "" if selection.is_empty() else str(world_list.get_item_metadata(selection[0]))

func _update_world_actions() -> void:
	var available: bool = not _selected_world_id().is_empty() and catalog.load_error.is_empty()
	open_button.disabled = not available
	rename_button.disabled = not available
	delete_button.disabled = not available
	duplicate_button.disabled = not available
	world_settings_button.disabled = not available

func duplicate_selected_world() -> void:
	var item: Dictionary = catalog.duplicate_world(_selected_world_id())
	if item.is_empty():
		list_message.text = catalog.last_error
		return
	refresh_world_list(item.id)
	list_message.text = "Copie créée : %s" % item.name
	world_list.grab_focus()

func open_world_settings() -> void:
	var item: Dictionary = catalog.find_world(_selected_world_id())
	if item.is_empty():
		return
	pending_world_id = item.id
	world_settings_text.text = "Monde : %s
Aucun paramètre disponible pour le moment." % item.name
	show_page("world_settings")

func request_rename() -> void:
	var item: Dictionary = catalog.find_world(_selected_world_id())
	if item.is_empty():
		return
	pending_world_id = item.id
	show_page("rename")
	rename_field.text = item.name
	rename_field.select_all()
	rename_error.text = ""

func confirm_rename() -> void:
	if not catalog.rename_world(pending_world_id, rename_field.text):
		rename_error.text = catalog.last_error
		return
	cancel_world_action()

func request_delete() -> void:
	var item: Dictionary = catalog.find_world(_selected_world_id())
	if item.is_empty():
		return
	pending_world_id = item.id
	delete_message.text = "Supprimer le monde « %s » ?
Son nom et sa graine seront retirés de la liste." % item.name
	show_page("delete")

func confirm_delete() -> void:
	if not catalog.delete_world(pending_world_id):
		delete_message.text = catalog.last_error
		return
	cancel_world_action()

func cancel_world_action() -> void:
	var previous_id := pending_world_id
	pending_world_id = ""
	show_page("worlds")
	refresh_world_list(previous_id)

func create_named_world() -> void:
	var item: Dictionary = catalog.create_world(name_field.text, seed_field.text)
	if item.is_empty():
		form_error.text = catalog.last_error
		if catalog.last_error.begins_with("La graine"):
			seed_field.grab_focus()
		else:
			name_field.grab_focus()
		return
	open_world(item.id)

func open_selected_world() -> void:
	var selection := world_list.get_selected_items()
	if not selection.is_empty():
		open_world(str(world_list.get_item_metadata(selection[0])))

func open_world(id: String) -> void:
	var item: Dictionary = catalog.find_world(id)
	if item.is_empty() or is_instance_valid(active_world):
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	menu_root.hide()
	page = "playing"
	current_world_id = id
	active_world = WorldScene.instantiate()
	active_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	active_world.terrain_seed = item.seed
	active_world.world_name = item.name
	add_child(active_world)
	return_button.show()
	active_world.player.apply_settings(settings.values)
	# Opening from a menu is an explicit request to play immediately.
	active_world.player.resume_controls()

func return_to_worlds() -> void:
	get_tree().paused = false
	if is_instance_valid(active_world):
		active_world.player.release_controls()
		remove_child(active_world)
		active_world.queue_free()
		active_world = null
	current_world_id = ""
	show_page("worlds")

func pause_game() -> void:
	if page != "playing" or not is_instance_valid(active_world):
		return
	active_world.player.release_controls()
	get_tree().paused = true
	show_page("pause")

func open_history() -> void:
	if is_instance_valid(active_world):
		return
	var file := FileAccess.open("res://HISTORIQUE.txt", FileAccess.READ)
	history_text.text = file.get_as_text() if file != null else "L'historique des versions est indisponible."
	history_scroll.scroll_vertical = 0
	show_page("history")

func open_help() -> void:
	if page != "pause" or not is_instance_valid(active_world):
		return
	help_text.text = WorldRules.get_help_text() + "

Bloc choisi : %s · %d blocs présents." % [WorldRules.BLOCK_NAMES[active_world.player.selected_type], active_world.blocks.size()]
	show_page("help")

func open_world_info() -> void:
	if page != "pause" or not is_instance_valid(active_world):
		return
	info_text.text = active_world.get_world_info_text()
	show_page("world_info")

func resume_game() -> void:
	if page != "pause" or not is_instance_valid(active_world):
		return
	active_world.player.release_controls()
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	menu_root.hide()
	page = "playing"
	get_tree().paused = false
	return_button.show()
	active_world.player.resume_controls()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if page in ["playing", "pause", "help", "world_info"] and event is InputEventKey and event.keycode == KEY_F1:
		return_to_worlds()
		get_viewport().set_input_as_handled()
	elif is_instance_valid(active_world) and page in ["playing", "pause", "help", "world_info"] and event is InputEventKey and event.keycode in [KEY_F2, KEY_F3]:
		if page == "playing":
			pause_game()
		else:
			show_page("pause")
		if event.keycode == KEY_F2:
			open_help()
		else:
			open_world_info()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if page == "playing":
			pause_game()
		elif page in ["help", "world_info"]:
			show_page("pause")
		elif page == "pause":
			resume_game()
		elif page in ["rename", "delete", "world_settings"]:
			cancel_world_action()
		elif page in ["settings", "information", "history"]:
			show_page("home")
		elif page == "create":
			show_page("worlds")
		elif page == "worlds":
			show_page("home")
		get_viewport().set_input_as_handled()
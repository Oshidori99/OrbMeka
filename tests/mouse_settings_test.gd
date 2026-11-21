extends SceneTree
# 0.0.7.35 (demande de l'utilisateur) : Souris tout en haut de Paramètres → Contrôles : sensibilité (avant dans Paramètres
# généraux) et vitesse de défilement de la molette (menus, listes, inventaire ; 100 % : celle de Godot).
const Settings = preload("res://scripts/user_settings.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/mouse-settings-test-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	root.add_child(app)
	current_scene = app
	app.show_page("settings")
	await process_frame
	# Souris dans Contrôles, avant les touches ; plus dans Paramètres généraux.
	var controls: Node = app.settings_sections.controls
	var general: Node = app.settings_sections.general
	var sensitivity: Control = app.setting_fields.mouse_sensitivity
	var scroll_field: Control = app.setting_fields.scroll_speed
	var first_group: Control = app.control_group_labels[app.Controls.GROUPS.keys()[0]]
	check(controls.is_ancestor_of(sensitivity) and controls.is_ancestor_of(scroll_field) and not general.is_ancestor_of(sensitivity), "Souris (sensitivity, scroll speed) in Contrôles, no longer in Paramètres généraux")
	check(_order(controls, sensitivity) < _order(controls, first_group), "Souris at the top of Contrôles, before the keys")
	check(Settings.SPECS.scroll_speed.default == 100.0 and Settings.SPECS.scroll_speed.min == 25.0 and Settings.SPECS.scroll_speed.max == 300.0 and Settings.menu_of("scroll_speed") == "general", "scroll speed: 100 % by default, 25 to 300 %, saved with the general settings")
	# La molette fait défiler l'Historique des versions : deux fois plus loin à 200 %.
	app.open_history()
	await process_frame
	await process_frame
	var scroll: ScrollContainer = app.history_scroll
	var bar := scroll.get_v_scroll_bar()
	check(bar.max_value - bar.page > 100.0, "a long page to scroll (history)")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	event.factor = 1.0
	bar.value = 0.0
	app._scroll_by(scroll, event)
	var normal := bar.value
	settings.values.scroll_speed = 200.0
	bar.value = 0.0
	app._scroll_by(scroll, event)
	var fast := bar.value
	settings.values.scroll_speed = 50.0
	bar.value = 0.0
	app._scroll_by(scroll, event)
	var slow := bar.value
	check(is_equal_approx(normal, bar.page / 8.0) and is_equal_approx(fast, 2.0 * normal) and is_equal_approx(slow, normal / 2.0), "one wheel notch: 1/8 of the page at 100 %% (%.0f px), twice at 200 %%, half at 50 %%" % normal)
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	bar.value = 0.0
	check(not app._scroll_by(scroll, event), "at the top, scrolling up is left to the area around")
	print("RESULT: %d mouse settings checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

# Ordre d'affichage d'un nœud dans la section (parcours en profondeur).
static func _order(root_node: Node, target: Node) -> int:
	var index := 0
	var stack: Array = [root_node]
	while not stack.is_empty():
		var node: Node = stack.pop_front()
		if node == target:
			return index
		index += 1
		var children: Array = node.get_children()
		for i in range(children.size() - 1, -1, -1):
			stack.push_front(children[i])
	return 1 << 30

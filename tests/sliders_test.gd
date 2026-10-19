extends SceneTree
# 0.0.3.7 : une barre par réglage chiffré (liée au champ), interrupteur on/off pour Oui / Non.
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
	var fixture := "res://.godot/sliders-test-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	root.add_child(app)
	current_scene = app
	app.show_page("settings")
	await process_frame
	check(app.setting_sliders.size() == Settings.SPECS.size(), "one slider per numeric setting")
	var bounds_ok := true
	var placed_ok := true
	for key in Settings.SPECS:
		var slider: HSlider = app.setting_sliders[key]
		bounds_ok = bounds_ok and slider.min_value == Settings.SPECS[key].min and slider.max_value == Settings.SPECS[key].max and is_equal_approx(slider.value, snappedf(settings.values[key], slider.step))
		placed_ok = placed_ok and slider.get_parent() == app.setting_fields[key].get_parent() and slider.get_index() < app.setting_fields[key].get_index()
	check(bounds_ok, "slider ranges match setting bounds and show saved values")
	check(placed_ok, "each slider sits just before its field")
	check(app.setting_sliders.place_ms.step == 10 and app.setting_sliders.jump_height.step == 0.1 and app.setting_sliders.fov.step == 1 and app.setting_sliders.walk_forward.step == 0.1, "slider steps suit each range")
	# Barre → champ, champ → barre.
	app.setting_sliders.fov.value = 90
	check(app.setting_fields.fov.text == Settings.number_text(90), "moving the slider fills the field")
	app.setting_fields.walk_forward.text = "8,5"
	app.setting_fields.walk_forward.text_changed.emit("8,5")
	check(is_equal_approx(app.setting_sliders.walk_forward.value, 8.5), "typing moves the slider")
	app.setting_fields.walk_forward.text = "abc"
	app.setting_fields.walk_forward.text_changed.emit("abc")
	check(is_equal_approx(app.setting_sliders.walk_forward.value, 8.5), "invalid typing leaves the slider still")
	check(settings.values.fov == 75, "slider is not saved before Apply")
	app.setting_fields.walk_forward.text = "8,5"
	app.settings_apply_button.pressed.emit()
	check(settings.values.fov == 90 and settings.values.walk_forward == 8.5, "Apply saves slider values")
	# Réinitialisations : les barres suivent.
	app.setting_resets.fov.pressed.emit()
	check(app.setting_fields.fov.text == Settings.number_text(75) and app.setting_sliders.fov.value == 75, "field reset moves the slider back")
	app.settings_reset_all_button.pressed.emit()
	check(app.setting_sliders.walk_forward.value == Settings.SPECS.walk_forward.default, "reset all moves attribute sliders back")
	app.category_resets.Panneaux.pressed.emit()
	check(app.setting_sliders.panel_size.value == 72 and app.setting_sliders.nav_width.value == 120, "category reset moves its sliders back")
	# Interrupteur Oui / Non.
	var switch: CheckButton = app.choice_switches.menu_depth
	check(switch.button_pressed and app.choice_buttons.menu_depth.is_empty(), "depth uses one on/off switch, on by default")
	switch.button_pressed = false
	check(app.choice_values.menu_depth == "off" and settings.values.menu_depth == "on", "switch off is pending until Apply")
	app.settings_apply_button.pressed.emit()
	check(settings.values.menu_depth == "off", "Apply saves the switch")
	app.setting_resets.menu_depth.pressed.emit()
	check(switch.button_pressed and app.choice_values.menu_depth == "on", "↻ turns the switch back on")
	check(app.choice_buttons.theme_mode.size() == 3 and app.choice_buttons.text_detail.size() == 3, "three-way choices keep their buttons")
	# Les barres tiennent dans les petites fenêtres, texte grand compris.
	app.setting_fields.text_px.text = "27"
	app.settings_apply_button.pressed.emit()
	var ok := true
	for size in [Vector2i(800, 450), Vector2i(1280, 720)]:
		root.size = size
		for section in ["general", "video", "attributes"]:
			app.show_page("settings")
			app.show_settings_section(section)
			await process_frame
			await process_frame
			var view: Vector2 = app.get_viewport().get_visible_rect().size
			var rect: Rect2 = app.menu_panel.get_global_rect()
			if rect.position.x < -0.5 or rect.end.x > view.x + 0.5 or rect.end.y > view.y + 0.5:
				ok = false
				print("OVERFLOW: ", section, " ", rect, " in ", view)
	check(ok, "settings with sliders stay inside the window")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for menu in Settings.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.file_path(menu)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d slider/switch checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

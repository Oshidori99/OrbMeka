extends SceneTree
const Settings = preload("res://scripts/user_settings.gd")
var checks := 0
var failures := 0
var fixture := ""

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func texts(values: Dictionary) -> Dictionary:
	var result := {}
	for key in values:
		result[key] = str(values[key])
	return result

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)

func measure(player: CharacterBody3D, values: Dictionary) -> Dictionary:
	player.set_physics_process(false)
	player.apply_settings(values)
	player.position = Vector3(45.5, 0.02, 45.5)
	player.velocity = Vector3.ZERO
	for index in range(10):
		await physics_frame
		player.step_movement(1.0/60.0, Vector2.ZERO, false)
	var base := player.position.y
	var peak := 0.0
	var ascent := 0.0
	var flight := 0.0
	for index in range(600):
		await physics_frame
		player.step_movement(1.0/60.0, Vector2.ZERO, index == 0)
		if player.position.y - base > peak:
			peak = player.position.y - base
			ascent = (index+1)/60.0
		if index > 2 and player.is_on_floor():
			flight = (index+1)/60.0
			break
	print("PROFILE: h=%.3f v=%.3f g=%.3f => peak=%.3f ascent=%.3f flight=%.3f" % [values.jump_height,values.jump_speed,values.fall_gravity,peak,ascent,flight])
	return {"peak":peak,"ascent":ascent,"flight":flight}

func _run() -> void:
	root.size = Vector2i(1280,720)
	fixture = "res://.godot/attributes-test-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	check(is_equal_approx(settings.values.jump_height, 2.52) and settings.values.jump_speed == 8.4 and settings.values.fall_gravity == 14, "defaults derived from original impulse and gravity")
	check(settings.values.place_ms == 300 and settings.values.break_ms == 300, "both block defaults remain 300 ms")
	var defaults: Dictionary = settings.values.duplicate()
	var desired := {"jump_height":"3,0","jump_speed":"9","fall_gravity":"18","place_ms":"450","break_ms":"650","walk_forward":"7","walk_side":"4,5","walk_back":"3"}
	check(settings.apply_texts(desired), "French decimal comma and custom attributes accepted")
	check(Settings.new(fixture).values == settings.values, "all settings persist independently in local file")
	var committed: Dictionary = settings.values.duplicate()
	for field in Settings.SPECS:
		var invalid := texts(committed)
		invalid[field] = "0"
		check(not settings.apply_texts(invalid) and settings.values == committed, "zero rejected without changing active " + field)
	for invalid_value in ["-2", "abc", "NaN", "1e999", "999999"]:
		var invalid := texts(committed)
		invalid.jump_height = invalid_value
		check(not settings.apply_texts(invalid), "invalid or extreme height rejected: " + invalid_value)
	var empty := texts(committed)
	empty.jump_height = ""
	check(settings.apply_texts(empty) and settings.values.jump_height == defaults.jump_height and settings.values.jump_speed == committed.jump_speed, "empty field resets only its default")
	var bad := fixture + ".invalid"
	var file := FileAccess.open(bad,FileAccess.WRITE)
	file.store_string('{"jump_height":0,"jump_speed":"broken","fall_gravity":999,"place_ms":null,"break_ms":-1}')
	file.close()
	check(Settings.new(bad).values == defaults, "invalid persisted values restore safe defaults")
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture+".worlds")
	var item: Dictionary = app.catalog.create_world("Réglages isolés","123")
	var world_file_before := FileAccess.get_file_as_bytes(fixture+".worlds")
	root.add_child(app)
	current_scene = app
	app.settings_button.pressed.emit()
	check(app.pages.settings.get_child(0).text == "Paramètres" and app.setting_fields.size() == 8 and app.setting_resets.size() == 8, "Attributs contains eight numeric fields and eight individual reset buttons")
	for field in app.setting_fields:
		check(app.setting_fields[field].text == Settings.number_text(settings.values[field]) and app.setting_fields[field].placeholder_text == Settings.number_text(Settings.SPECS[field].default), "active value and default placeholder: " + field)
		var before := {}
		for other in app.setting_fields:
			before[other] = app.setting_fields[other].text
		app.setting_resets[field].pressed.emit()
		var others_unchanged := true
		for other in before:
			if other != field and app.setting_fields[other].text != before[other]:
				others_unchanged = false
		check(others_unchanged and app.setting_fields[field].text == Settings.number_text(Settings.SPECS[field].default), "reset affects only " + field)
	for field in desired:
		app.setting_fields[field].text = desired[field]
	app.settings_apply_button.pressed.emit()
	check(settings.values.jump_height == 3 and settings.values.place_ms == 450 and settings.values.break_ms == 650, "Apply saves UI values")
	check(FileAccess.get_file_as_bytes(fixture+".worlds") == world_file_before, "settings never modify worlds catalog or seeds")
	await process_frame
	await process_frame
	var panel: Control = app.pages.settings.get_parent().get_parent()
	check(panel.get_global_rect().position.y >= 0 and panel.get_global_rect().end.y <= 720, "scrolling attribute screen fits 1280 by 720")
	app.show_page("worlds")
	app.open_world(item.id)
	var world: Node3D = app.active_world
	var player: CharacterBody3D = world.player
	check(player.jump_height == 3 and player.jump_speed == 9 and player.gravity == 18, "world receives active jump attributes")
	check(player.actions.place_interval == 0.45 and player.actions.break_interval == 0.65, "world receives separate millisecond intervals")
	var count: int = world.blocks.size()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._unhandled_input(click)
	check(world.blocks.size() == count and not player.actions.breaking, "launch click cannot trigger a block action in transition frame")
	check(player.input_ready_frame == Engine.get_process_frames(), "opening world arms direct-control transition without OS input in headless")
	check(player.actions.set_place_pressed(true,true) and not player.actions.tick_place(0.449,true,true) and player.actions.tick_place(0.001,true,true), "custom placement interval is exact")
	check(player.actions.set_break_pressed(true,true) and not player.actions.tick_break(0.649,true,true) and player.actions.tick_break(0.001,true,true), "custom breaking interval is exact")
	check(player.actions.tick_place(2,true,true) and not player.actions.tick_place(0,true,true), "custom intervals never catch up with a burst")
	key(KEY_ESCAPE)
	check(paused and app.page == "pause" and not player.actions.placing and not player.actions.breaking, "Escape always pauses and cancels both customized timers")
	app.resume_game()
	player.actions.set_place_pressed(true,true)
	player.actions.set_break_pressed(true,true)
	player._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not player.actions.placing and not player.actions.breaking and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "focus loss releases pointer and cancels custom actions")
	var normal: Dictionary = await measure(player,defaults)
	check(absf(normal.peak-defaults.jump_height)<0.03 and normal.flight>1.15 and normal.flight<1.28, "default trajectory matches requested height and remains close to previous flight time")
	var faster := defaults.duplicate()
	faster.jump_speed = 12.0
	var fast: Dictionary = await measure(player,faster)
	check(absf(fast.peak-normal.peak)<0.03 and fast.ascent<normal.ascent-0.1, "ascent speed changes rise time without changing height")
	var heavier := defaults.duplicate()
	heavier.fall_gravity = 28.0
	var heavy: Dictionary = await measure(player,heavier)
	check(absf(heavy.peak-normal.peak)<0.03 and absf(heavy.ascent-normal.ascent)<0.02 and heavy.flight<normal.flight-0.1, "descent gravity changes only falling duration")
	var higher := defaults.duplicate()
	higher.jump_height = 4.0
	var high: Dictionary = await measure(player,higher)
	check(absf(high.peak-4.0)<0.03, "height setting reaches independent four metre target")
	app.return_to_worlds()
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for path in [fixture,bad,fixture+".worlds"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d attribute/entry checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
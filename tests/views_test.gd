extends SceneTree
# 0.0.4.9 (#85) : trois vues avec F4 : première personne, de derrière, de devant.
# La visée reste celle des yeux ; corps entier visible hors première personne ; caméra rapprochée
# devant un bloc. F4 réservée, montrée dans Contrôles → Menus, Comment jouer et les rappels.
const Settings = preload("res://scripts/user_settings.gd")
const Controls = preload("res://scripts/controls.gd")
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

func press_f4(player: CharacterBody3D) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_F4
	event.physical_keycode = KEY_F4
	event.pressed = true
	player._unhandled_input(event)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	check(KEY_F4 in Controls.RESERVED_KEYS and Controls.MENU_KEYS[-1] == ["Changer de vue", "F4"], "F4 reserved, shown in Menus")
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var player: CharacterBody3D = world.player
	player.set_physics_process(false)
	var values := Settings.default_values()
	values.character = "boy14"
	player.apply_settings(values)
	# En l'air, loin des collines (une colline commence à 2 m derrière le départ).
	player.position = Vector3(0.5, 20.0, 8.5)
	player.rotation = Vector3.ZERO
	player.camera.rotation.x = 0.0
	await physics_frame
	check(player.view == "first" and player.camera.current and player.body.visible, "first person at start, cut body")
	var aim_before: Vector3 = player.camera.global_position
	press_f4(player)
	await physics_frame
	player.update_view()
	check(player.view == "back" and player.view_camera.current, "F4: view from behind")
	check(absf(player.view_camera.position.z - player.VIEW_DISTANCE) < 0.01 and player.view_camera.global_position.z > player.camera.global_position.z + 3.9, "camera 4 m behind the eyes (%.2f)" % player.view_camera.position.z)
	check(not player.body.visible and player.body_shadow.find_children("*", "GeometryInstance3D", true, false).all(func(node): return node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON), "whole body visible, head included")
	check(player.camera.global_position == aim_before and player.view_camera.global_transform.basis.z.dot(player.camera.global_transform.basis.z) > 0.99, "aiming stays at the eyes, same direction")
	press_f4(player)
	await physics_frame
	player.update_view()
	check(player.view == "front" and player.view_camera.current and player.view_camera.global_position.z < player.camera.global_position.z - 3.9, "F4 again: view from the front")
	check(player.view_camera.global_transform.basis.z.dot(player.camera.global_transform.basis.z) < -0.99, "front view looks back at the player")
	press_f4(player)
	await physics_frame
	check(player.view == "first" and player.camera.current and player.body.visible and player.body_shadow.find_children("*", "GeometryInstance3D", true, false).all(func(node): return node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY), "F4 a third time: first person again")
	# Un bloc derrière : la caméra se rapproche.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(4, 4, 0.5)
	wall.add_child(shape)
	world.add_child(wall)
	wall.global_position = player.camera.global_position + Vector3(0, 0, 2.0)
	await physics_frame
	await physics_frame
	player.set_view("back")
	check(player.view_camera.position.z < 2.0 and player.view_camera.position.z >= 0.3, "a block behind: camera comes closer (%.2f)" % player.view_camera.position.z)
	world.remove_child(wall)
	wall.queue_free()
	# Animal : pas de copie d'ombre, le corps reste visible dans chaque vue.
	values.character = "fox"
	player.apply_settings(values)
	player.set_view("front")
	check(player.body.visible, "animal body visible from the front")
	player.set_view("first")
	# FOV suivi.
	values.fov = 90.0
	player.apply_settings(values)
	check(player.view_camera.fov == 90.0, "third-person views follow the FOV")
	root.remove_child(world)
	world.queue_free()
	# Menus.
	var fixture := "res://.godot/views-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	root.add_child(app)
	await process_frame
	check(app.control_menu_buttons.has("Changer de vue") and app.control_menu_buttons["Changer de vue"].text == "F4" and app.control_menu_buttons["Changer de vue"].disabled, "Contrôles → Menus: F4, not editable")
	check(app.shortcut_hints.text.contains("F4 : Changer de vue"), "shortcut reminder shows F4")
	var help: String = load("res://scripts/world.gd").get_help_text(2)
	check(help.contains("F4 : changer de vue") and load("res://scripts/world.gd").get_help_text(0).contains("F4"), "Comment jouer explains F4")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d view checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

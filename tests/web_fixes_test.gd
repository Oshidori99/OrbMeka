extends SceneTree
# 0.0.4.17 : corrections de la version Web. Couleurs : lumière baissée dans le rendu Compatibility
# (celui du navigateur) ; souris : mouvement réel (screen_relative), pas agrandi selon l'affichage ;
# symboles et emojis : polices de secours (voir licences_test.gd).
const WorldRules = preload("res://scripts/world.gd")
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
	check(WorldRules.COMPAT_SUN < 1.0 and WorldRules.COMPAT_SUN >= 0.5 and WorldRules.COMPAT_AMBIENT < 1.0 and WorldRules.COMPAT_AMBIENT >= 0.4, "web renderer: sun and ambient light lowered")
	check(not WorldRules.is_compat() or RenderingServer.get_current_rendering_method() == "gl_compatibility", "compatibility renderer detected by its name")
	var showcase := FileAccess.get_file_as_string("res://scripts/menu_showcase.gd")
	check(showcase.contains("WorldRules.is_compat()") and showcase.contains("WorldRules.COMPAT_SUN"), "home showcase uses the same correction")
	# Souris.
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var player: CharacterBody3D = world.player
	player.rotation = Vector3.ZERO
	player.camera.rotation.x = 0.0
	player.turn_view(Vector2(100, 40))
	check(is_equal_approx(player.rotation.y, -100.0 * player.sensitivity) and is_equal_approx(player.camera.rotation.x, -40.0 * player.sensitivity), "view turns by the mouse movement times the sensitivity")
	var source := FileAccess.get_file_as_string("res://scripts/player.gd")
	check(source.contains("turn_view(event.screen_relative)") and not source.contains("event.relative.x"), "real mouse movement, not scaled by the display size")
	root.remove_child(world)
	world.queue_free()
	await process_frame
	print("RESULT: %d web fix checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

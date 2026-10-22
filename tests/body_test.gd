extends SceneTree
# 0.0.3.26 : corps du personnage visible en première personne (surtout en regardant en bas).
# La caméra garde la hauteur des yeux réglée pour tous ; la tête d'un humain est cachée à l'œil,
# mais son ombre reste entière ; animaux et Brioche entiers sous la caméra.
const Settings = preload("res://scripts/user_settings.gd")
const CharacterPreview = preload("res://scripts/character_preview.gd")
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

# Boîte du modèle dans le repère du joueur.
func bounds(player: CharacterBody3D, model: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var box: AABB = player.global_transform.affine_inverse() * mesh_instance.global_transform * mesh_instance.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

func _run() -> void:
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var player: CharacterBody3D = world.player
	player.set_physics_process(false)
	var values := Settings.default_values()
	var eye: float = values.eye_height
	for id in CharacterPreview.CHARACTERS:
		values.character = id
		values.skin = "brown"
		player.apply_settings(values)
		var body: Node3D = player.body
		check(is_instance_valid(body) and body.get_parent() == player and not body.find_children("*", "MeshInstance3D", true, false).is_empty(), "body shown in game: " + id)
		check(is_equal_approx(player.camera.position.y, eye), "view height stays the eye height: " + id)
		var box := bounds(player, body)
		check(absf(box.position.y) < 0.01 and absf(box.get_center().x) < 0.05 and box.get_center().z > 0.0, "feet on the ground, centred just behind the camera: " + id)
		check(is_equal_approx(body.rotation.y, PI), "body faces forward (-Z): " + id)
		var meshes: Array = body.find_children("*", "MeshInstance3D", true, false)
		if CharacterPreview.is_human(id):
			var cut := meshes.all(func(mesh): return mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and range(mesh.mesh.get_surface_count()).all(func(surface): return mesh.get_surface_override_material(surface) is ShaderMaterial))
			var neck: float = meshes[0].get_surface_override_material(0).get_shader_parameter("neck")
			check(cut and neck < box.end.y * 0.6 and neck + body.position.y < eye - 0.4, "human head hidden from the eye, cut at the neck: " + id)
			var shadow: Node3D = player.body_shadow
			check(is_instance_valid(shadow) and shadow.find_children("*", "GeometryInstance3D", true, false).all(func(mesh): return mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY), "whole body still casts its shadow: " + id)
		else:
			check(box.end.y < eye - 0.3 and player.body_shadow == null and meshes.all(func(mesh): return mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF), "animal whole under the camera, with its shadow: " + id)
	# Changer de peau reconstruit le corps ; mêmes réglages : rien n'est refait.
	values.character = "boy14"
	values.skin = "light"
	player.apply_settings(values)
	var first: Node3D = player.body
	player.apply_settings(values)
	check(player.body == first, "same character and skin keep the same body")
	values.skin = "dark"
	player.apply_settings(values)
	await process_frame
	check(player.body != first and not is_instance_valid(first) and player.find_children("Body*", "", false, false).size() == 2, "new skin rebuilds the body, old one removed")
	var skin_found := false
	for node in player.body.find_children("*", "MeshInstance3D", true, false):
		for surface in range(node.mesh.get_surface_count()):
			var material: Material = node.get_surface_override_material(surface)
			if material is ShaderMaterial and material.get_shader_parameter("albedo").is_equal_approx(CharacterPreview.tone_color("dark")):
				skin_found = true
	check(skin_found, "body takes the chosen skin")
	# Le corps n'arrête pas le regard : la cible reste devant, pas sur soi.
	check(player.get_target().is_empty() or not player.is_ancestor_of(player.get_target().collider), "body never targeted for breaking or placing")
	root.remove_child(world)
	world.queue_free()
	await process_frame
	print("RESULT: %d body checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

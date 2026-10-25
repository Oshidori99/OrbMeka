extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, text: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + text)
	else:
		failures += 1
		push_error("FAIL: " + text)

func _run() -> void:
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	check(world.block_material is ShaderMaterial, "original procedural earth shader assigned")
	check(world.get_node("Ground").get_child(0).material_override is ShaderMaterial, "grass ground uses original procedural surface")
	check(world.find_children("GrassDetail","MultiMeshInstance3D",true,false).size()>0, "grass tufts generated")
	# 0.0.5.7 : brins de 24 à 56 cm, 200 par carré de 50 cm en densité moyenne.
	var patch: ArrayMesh = world.find_children("GrassDetail","MultiMeshInstance3D",true,false)[0].multimesh.mesh
	check(patch.get_aabb().size.y > 0.5 and patch.get_aabb().size.y <= 0.57, "grass blades about 40 cm tall, up to 56 cm")
	check(patch.surface_get_array_len(0) == 200 * 3, "medium density has 200 blades per 50 cm patch")
	check(world.save_folder.is_empty(), "visual test never opens personal world storage")
	var before: Dictionary = world.blocks.duplicate()
	# 0.0.5.8 : clics = gestes sur le terrain lisse ; sans cible, rien ; maintenir ne répète pas.
	check(not world.break_target({}) and not world.place_target({},2), "empty target sculpts nothing")
	for index in range(20):
		world.player.step_breaking(0.3,true,true)
		world.player.step_placement(0.3,true,true)
	check(world.blocks == before and world.dirty_zones.is_empty() and world.terrain.changes.is_empty(), "held actions neither change blocks, terrain nor save data")
	check(not world.player.actions.breaking and not world.player.actions.placing, "repetition timers remain disarmed")
	check(world.find_child("ExplorationNotice",true,false).text.contains("creuse"), "player sees how to sculpt the terrain")
	for level in range(3):
		check(world.get_help_text(level).contains("creuser"), "help explains digging at detail level %d" % level)
	check(world.Zones.ZONE_SIZE == 8 and world.Zones.DENSITY_STEP == 0.5, "agreed zone and future sub-cell scale unchanged")
	check(world.generated.is_empty() and world.SAND_RADIUS > 0.0, "flat start: no blocks, a painted sand beach (0.0.5.5)")
	root.remove_child(world)
	world.queue_free()
	await process_frame
	print("RESULT: %d visual exploration checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
extends SceneTree

func _initialize() -> void:
	root.hide()
	call_deferred("_render")

func _render() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1400,900)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_2X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var started := Time.get_ticks_usec()
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	view.add_child(world)
	world.player.set_physics_process(false)
	world.player.set_process_unhandled_input(false)
	for layer in world.find_children("*","CanvasLayer",true,false):
		layer.hide()
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.position = Vector3(-4.5,3.1,7.0)
	camera.look_at(Vector3(-9.5,1.0,-0.5))
	camera.fov = 64
	camera.make_current()
	var load_ms := (Time.get_ticks_usec()-started)/1000.0
	var draw_times: Array[float] = []
	for index in range(35):
		await process_frame
		var draw_start := Time.get_ticks_usec()
		RenderingServer.force_draw()
		RenderingServer.force_sync()
		if index > 15:
			draw_times.append((Time.get_ticks_usec()-draw_start)/1000.0)
	var picture := view.get_texture().get_image()
	if picture == null or picture.is_empty():
		push_error("Offscreen image unavailable.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://docs/previews")
	var error := picture.save_png("res://docs/previews/0.0.5.2-terrain.png")
	draw_times.sort()
	print("DRAW_MEDIAN_MS: %.3f" % draw_times[draw_times.size()/2])
	print("OFFSCREEN: result=%d load_ms=%.2f render_method=%s" % [error,load_ms,RenderingServer.get_current_rendering_method()])
	root.remove_child(view)
	view.queue_free()
	await process_frame
	quit(0 if error == OK else 1)
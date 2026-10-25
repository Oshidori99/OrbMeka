extends SceneTree
const Generation = preload("res://scripts/world_generation.gd")
const Terrain = preload("res://scripts/smooth_terrain.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const Store = preload("res://scripts/world_store.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for source in ["res://scripts/world_generation.gd.uid","res://tests/custom_generation_test.gd.uid","res://tests/custom_world_menu_test.gd.uid"]:
		check(ResourceUID.text_to_id(FileAccess.get_file_as_string(source).strip_edges()) > 0, "new script UID is valid")
	var options := Generation.defaults()
	check(options.small_deserts == 8 and options.steep_hills == 9 and options.smooth_holes == 9, "defaults share actual standard generator constants")
	check(options.medium_deserts == 0 and options.large_deserts == 0 and options.stone_holes == 0, "new categories are absent by default, never assigned an invented reference")
	check(Generation.valid({}) and Generation.valid(options), "legacy and custom options accepted")
	for invalid in [-1,65,1.5,"24",null]:
		var bad := options.duplicate()
		bad.small_deserts = invalid
		check(not Generation.valid(bad), "invalid frequency rejected")
	var all := options.duplicate()
	for spec in Generation.SPECS:
		all[spec.key] = 1
	for x in range(16):
		var info := Generation.chunk_info(42,Vector2i(x,3),all)
		check(info.small_desert and info.landforms.size() == 7, "1/1 produces each feature at every chunk")
		for key in ["medium_desert","big_desert"]:
			var cells: Array = info[key]
			check(cells.size() >= (4 if key == "medium_desert" else 8) and cells.size() <= (6 if key == "medium_desert" else 11), "desert has requested chunk count")
			var unique := {}
			for cell in cells:
				unique[cell] = true
			check(unique.size() == cells.size(), "desert chunks never duplicated")
			var reachable := {Vector2i.ZERO:true}
			for attempt in range(cells.size()):
				for cell in cells:
					for side in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
						if reachable.has(cell+side):
							reachable[cell] = true
			check(reachable.size() == cells.size(), "desert chunks form a connected group")
	var rare := options.duplicate()
	for spec in Generation.SPECS:
		rare[spec.key] = 64
	var rare_count := 0
	for x in range(512):
		if Generation.chunk_info(42,Vector2i(x,9),rare).small_desert:
			rare_count += 1
	check(rare_count > 0 and rare_count < 24, "1/64 really reduces generated desert frequency")
	var a := Terrain.new()
	var b := Terrain.new()
	a.setup(123,[],options)
	b.setup(123,[],options)
	for x in range(-12,13,3):
		var point := Vector2i(x,9)
		check(a.ground_height(point) == b.ground_height(point) and a.is_desert(Vector2(point)) == b.is_desert(Vector2(point)), "same seed and options reproduce terrain")
	var all_desert := Terrain.new()
	all_desert.setup(123,[],all)
	for x in range(-16,16,4):
		check(all_desert.is_desert(Vector2(x,0)), "1/1 is desert even near spawn")
	var pits := rare.duplicate()
	pits.stone_holes = 1
	var deep := Terrain.new()
	deep.setup(123,[],pits)
	var info := deep._chunk(Vector2i(5,6))
	for form in info.landforms:
		if form.kind == "stone_holes":
			var at := Vector2i(roundi(form.center.x*2),roundi(form.center.y*2))
			check(deep.ground_height(at) >= -7.0 and deep.ground_height(at) <= -6.0, "large pit reaches 2-3 blocks into stone")
			check(deep.density(Vector3i(at.x,-10,at.y)) <= 0.0 and deep.solid(Vector3i(at.x,-16,at.y)), "stone exposed, bedrock remains solid")
	var path := "res://.godot/custom-generation-%d.json" % Time.get_ticks_usec()
	var catalog := Catalog.new(path)
	var item: Dictionary = catalog.create_world("Personnalisé","123","default",false,options)
	check(not item.is_empty(), "custom world created")
	var base_path: String = catalog.world_folder(item.id).path_join(Store.BASE_FILE)
	check(Generation.normalized(JSON.parse_string(FileAccess.get_file_as_string(base_path)).generation) == options, "settings saved in monde.json")
	var reopened := Catalog.new(path)
	check(reopened.find_world(item.id).generation == options, "settings restored from world metadata")
	check(reopened.rename_world(item.id,"Renommé") and reopened.find_world(item.id).generation == options, "rename preserves generation")
	var copy: Dictionary = reopened.duplicate_world(item.id)
	check(copy.id != item.id and copy.generation == options, "duplicate retains seed options with distinct identity")
	var legacy: Dictionary = reopened.create_world("Standard","123")
	check(legacy.generation.is_empty(), "standard world keeps historical generation")
	Store.delete_folder(catalog.worlds_root)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d custom generation checks, %d failures" % [checks,failures])
	quit(failures)

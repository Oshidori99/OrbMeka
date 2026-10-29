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
	check(options.version == 4 and options.rocks == 2 and options.lakes == 24 and options.small_deserts == 133 and options.medium_deserts == 100 and options.large_deserts == 80, "0.0.5.18 standard (version 3): small deserts rarer than big ones")
	check(options.deep_holes == 0 and absf(256.0 / options.stone_holes - 3.5) < 0.6 and absf(Generation.desert_share(options) - 0.12) < 0.015, "3 or 4 huge holes per 256 zones; deserts cover about 12 % of the ground")
	check(Generation.valid({}) and Generation.valid(options), "legacy and custom options accepted")
	for invalid in [-1,401,1.5,"24",null]:
		var bad := options.duplicate()
		bad.small_deserts = invalid
		check(not Generation.valid(bad), "invalid frequency rejected")
	var all := options.duplicate()
	for spec in Generation.SPECS:
		all[spec.key] = 1
	for x in range(16):
		var info := Generation.zone_info(42,Vector2i(x,3),all)
		check(info.small_desert and info.landforms.size() == 7, "1/1 produces each feature at every zone")
		for key in ["medium_desert","big_desert"]:
			var cells: Array = info[key]
			check(cells.size() >= (3 if key == "medium_desert" else 6) and cells.size() <= (4 if key == "medium_desert" else 7), "desert has the requested number of zones (version 3 : 3-4 and 6-7)")
			var unique := {}
			for cell in cells:
				unique[cell] = true
			check(unique.size() == cells.size(), "desert zones never duplicated")
			var reachable := {Vector2i.ZERO:true}
			for attempt in range(cells.size()):
				for cell in cells:
					for side in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
						if reachable.has(cell+side):
							reachable[cell] = true
			check(reachable.size() == cells.size(), "desert zones form a connected group")
	# Version 1 (0.0.5.16) : mêmes tailles qu'avant, pour les mondes déjà créés avec elle.
	var old := all.duplicate()
	old.version = 1
	old.erase("rocks")
	old.erase("lakes")
	var old_info := Generation.zone_info(42, Vector2i(2, 3), old)
	check(old_info.medium_desert.size() >= 4 and old_info.medium_desert.size() <= 6 and old_info.big_desert.size() >= 8 and old_info.big_desert.size() <= 11, "version 1 worlds keep their desert sizes")
	check(Generation.valid(old) and not Generation.valid({"version": 5}), "versions 1 to 4 accepted, others refused")
	check(Generation.estimate_text("medium_deserts", 25).contains("environ 16 désert") and Generation.estimate_text("steep_hills", 8).contains("environ 50 dans le monde"), "estimates in plain words (400 zones)")
	var rare := options.duplicate()
	for spec in Generation.SPECS:
		rare[spec.key] = 64
	var rare_count := 0
	for x in range(512):
		if Generation.zone_info(42,Vector2i(x,9),rare).small_desert:
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
	pits.lakes = 0
	var deep := Terrain.new()
	deep.setup(123,[],pits)
	var info := deep._zone_info(Vector2i(5,6))
	for form in info.landforms:
		if form.kind == "stone_holes":
			var at := Vector2i(roundi(form.center.x*2),roundi(form.center.y*2))
			check(deep.ground_height(at) >= -7.0 and deep.ground_height(at) <= -4.0, "huge pit goes down into the stone (2 to 3 blocks under the local relief, version 2 and later)")
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
	var standard: Dictionary = reopened.create_world("Standard","123")
	check(standard.generation == Generation.defaults(), "a new standard world saves the version 4 settings")
	var legacy: Dictionary = reopened.create_world("Ancien","124","default",false,{})
	check(legacy.generation.is_empty(), "worlds without settings keep the 0.0.5.15 generation")
	Store.delete_folder(catalog.worlds_root)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d custom generation checks, %d failures" % [checks,failures])
	quit(failures)

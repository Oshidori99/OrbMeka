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
	check(options.version == 23 and options.fruit_trees == 14 and options.other_trees == 16 and options.cave_entrances == 24 and options.cave_systems == 20 and options.crevasses == 30 and options.mountain_chains == 1400 and options.smooth_holes == 30 and options.steep_holes == 45 and options.mud_pits == 40 and options.sand_mountains == 15 and not options.has("small_deserts") and not options.has("lakes_2") and not options.has("lakes_4") and options.large_deserts == 340 and options.lakes_small == 900 and options.lakes_medium == 40 and options.lakes_large == 90 and options.mountains == 850 and options.steep_mountains == 2800 and options.mud_regions == 70, "standard (version 23): fruit trees, big deserts, small, medium and large lakes, climbable and steep mountains")
	check(options.deep_holes == 0 and absf(256.0 / options.stone_holes - 3.5) < 0.6 and absf(Generation.desert_share(options) - 0.12) < 0.02, "3 or 4 huge holes per 256 zones; about 6 big deserts")
	check(Generation.valid({}) and Generation.valid(options), "legacy and custom options accepted")
	for invalid in [-1,4001,1.5,"24",null]:
		var bad := options.duplicate()
		bad.small_deserts = invalid
		check(not Generation.valid(bad), "invalid frequency rejected")
	# Tous les réglages de la version 5 à 1 sur 1 (la version 6 n'a plus de petits ni de moyens déserts).
	var all := {"version": 5}
	for spec in Generation.specs_for(5):
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
	# 0.0.6.9 : réglage des arbres seulement dès la version 21.
	old.erase("fruit_trees")
	old.erase("other_trees")
	old.erase("rocks")
	old.erase("lakes")
	old.erase("long_lakes")
	old.erase("clay")
	var old_info := Generation.zone_info(42, Vector2i(2, 3), old)
	check(old_info.medium_desert.size() >= 4 and old_info.medium_desert.size() <= 6 and old_info.big_desert.size() >= 8 and old_info.big_desert.size() <= 11, "version 1 worlds keep their desert sizes")
	check(Generation.valid(old) and not Generation.valid({"version": 15}), "versions 1 to 14 accepted, others refused")
	# Mondes créés avant l'ajout des crevasses : toujours valides, sans crevasses ; un réglage obligatoire manquant reste refusé.
	var before_cracks := options.duplicate()
	before_cracks.erase("crevasses")
	check(Generation.valid(before_cracks) and Generation.normalized(before_cracks).crevasses == 0, "a world saved before the crevasses setting stays valid, without crevasses")
	var missing_setting := options.duplicate()
	missing_setting.erase("clay")
	check(not Generation.valid(missing_setting), "a missing required setting is still refused")
	check(Generation.estimate_text("medium_deserts", 24).contains("environ 171 désert") and Generation.estimate_text("steep_hills", 8).contains("environ 512 dans le monde"), "estimates in plain words (4096 zones)")
	var rare := options.duplicate()
	for spec in Generation.specs_for(Generation.VERSION):
		rare[spec.key] = 64
	var rare_count := 0
	for x in range(512):
		if Generation.zone_info(42,Vector2i(x,9),rare).has("big_desert"):
			rare_count += 1
	check(rare_count > 0 and rare_count < 24, "1/64 really reduces generated desert frequency (big deserts, version 23)")
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
	pits.lakes_small = 0
	pits.lakes_medium = 0
	pits.lakes_large = 0
	pits.mountains = 0
	pits.steep_mountains = 0
	pits.mud_pits = 0
	pits.cave_entrances = 0
	pits.cave_systems = 0
	pits.crevasses = 0
	pits.mountain_chains = 0
	pits.sand_mountains = 0
	var deep := Terrain.new()
	deep.setup(123,[],pits)
	var info := deep._zone_info(Vector2i(5,6))
	for form in info.landforms:
		if form.kind == "stone_holes":
			var at := Vector2i(roundi(form.center.x*2),roundi(form.center.y*2))
			check(deep.ground_height(at) >= -7.0 and deep.ground_height(at) <= -4.0, "huge pit goes down into the stone (2 to 3 blocks under the local relief, version 2 and later)")
			check(deep.density(Vector3i(at.x,-10,at.y)) <= 0.0 and deep.solid(Vector3i(at.x,-16,at.y)), "stone exposed, mother_rock remains solid")
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
	check(standard.generation == Generation.defaults(), "a new standard world saves the version 23 settings")
	var legacy: Dictionary = reopened.create_world("Ancien","124","default",false,{})
	check(legacy.generation.is_empty(), "worlds without settings keep the 0.0.5.15 generation")
	Store.delete_folder(catalog.worlds_root)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# 0.0.6 : 64 × 64 zones en version 15 ; un monde d'avant garde ses 48 × 48.
	check(Generation.half_zones(15) == 32 and Generation.world_zones(15) == 4096 and Generation.half_zones(14) == 24 and Generation.world_zones(14) == 2304 and Generation.half_zones(0) == 24, "world size follows the generation version")
	var old_options := Generation.defaults()
	old_options.version = 14
	# 0.0.6.9 : réglage des arbres seulement dès la version 21.
	old_options.erase("fruit_trees")
	old_options.erase("other_trees")
	var sized: Node3D = load("res://scenes/world.tscn").instantiate()
	sized.generation_options = old_options
	root.add_child(sized)
	check(sized.build_limit == 189 and sized.base_size.x == 384 and sized.base_zones_high == Vector2i(23, 23) and sized.terrain.half_zones == 24 and sized.terrain.fall_limit == 189, "a version 14 world keeps 48 × 48 zones")
	root.remove_child(sized)
	sized.free()
	sized = load("res://scenes/world.tscn").instantiate()
	sized.generation_options = Generation.defaults()
	root.add_child(sized)
	check(sized.build_limit == 253 and sized.base_size.x == 512 and sized.base_zones_low == Vector2i(-32, -32) and sized.base_zones_high == Vector2i(31, 31) and sized.terrain.half_zones == 32 and sized.terrain.fall_limit == 253, "a new world has 64 × 64 zones")
	root.remove_child(sized)
	sized.free()
	print("RESULT: %d custom generation checks, %d failures" % [checks,failures])
	quit(failures)

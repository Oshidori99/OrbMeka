extends RefCounted
# 0.0.8.14 (rapport d'optimisation) : diagnostic du rendu, pour mesurer ce que coûte chaque sorte de chose à la carte
# graphique : masquer une sorte (terrain, herbe, lointain, eau, arbres, plantes, rochers et cailloux, objets au sol,
# joueur, interface) ou couper un effet (ciel, brume, ombres, saturation), puis remettre tout comme avant. Rien n'est
# enregistré ; utilisé par tools/mesure_gpu.gd (PC) et, sur le Web, par la console de Chrome (window.orbmeka, app.gd).

const SORTS := ["terrain", "herbe", "lointain", "eau", "arbres", "plantes", "rochers", "objets", "joueur", "interface"]
const EFFECTS := ["ciel", "brume", "ombres", "saturation", "sol_detaille"]
# Réglages plus légers à essayer (« cacher » = essayer le réglage plus léger ; « montrer » = revenir).
const VARIANTS := ["ciel_fixe", "ombres_2048", "ombres_1024", "ombres_1_niveau", "sans_anticrenelage", "arbres_28m", "feuilles_mipmaps", "ombres_arbres_proches", "ombres_sans_arbres"]
const Trees = preload("res://scripts/trees.gd")
const TerrainMaterials = preload("res://scripts/terrain_materials.gd")

# Ce qui est caché (nœud → visible d'avant) et effets coupés (nom → valeur d'avant), par monde.
static var _hidden := {}
static var _effects := {}

# Sorte d'une chose dessinée du monde ("" : ne compte pas).
static func sort_of(world: Node3D, node: GeometryInstance3D) -> String:
	if world.terrain_node != null and world.terrain_node.is_ancestor_of(node):
		return "terrain"
	if world.lawn != null and world.lawn.is_ancestor_of(node):
		return "herbe"
	if world.far_node != null and world.far_node.is_ancestor_of(node):
		return "lointain"
	if is_instance_valid(world.ground) and world.ground.is_ancestor_of(node):
		return "objets"
	if is_instance_valid(world.player) and world.player.is_ancestor_of(node):
		return "joueur"
	var look: Material = node.material_override
	if look == null and node is MeshInstance3D and node.mesh != null and node.mesh.get_surface_count() > 0:
		look = node.mesh.surface_get_material(0)
	if look is ShaderMaterial and look.shader != null and (look.shader.resource_path.ends_with("water.gdshader") or look.shader.resource_path.ends_with("river.gdshader")):
		return "eau"
	var up: Node = node
	while up != null and up != world:
		if up.is_in_group("trees") or up.has_meta("part"):
			return "arbres"
		if up.is_in_group("plants") or str(up.name).begins_with("Plantes"):
			return "plantes"
		up = up.get_parent()
	if world.has_method("_rocks_parent") and world._rocks_parent().is_ancestor_of(node):
		return "rochers"
	return ""

# Choses dessinées de chaque sorte.
static func sorted(world: Node3D) -> Dictionary:
	var result := {}
	for name in SORTS:
		result[name] = []
	for node: GeometryInstance3D in world.find_children("*", "GeometryInstance3D", true, false):
		var sort := sort_of(world, node)
		if not sort.is_empty():
			result[sort].append(node)
	return result

# Masque (shown = false) ou remontre une sorte ; vrai si elle existe.
static func show_sort(world: Node3D, sort: String, shown: bool) -> bool:
	if not sort in SORTS:
		return false
	if sort == "interface":
		for layer in world.find_children("*", "CanvasLayer", true, false):
			_remember(layer, shown)
		return true
	for node: Node in sorted(world)[sort]:
		_remember(node, shown)
	return true

static func _remember(node: Node, shown: bool) -> void:
	var id := node.get_instance_id()
	if not shown:
		if not _hidden.has(id):
			_hidden[id] = node.visible
		node.visible = false
	elif _hidden.has(id):
		node.visible = _hidden[id]
		_hidden.erase(id)

# Coupe (on = false) ou remet un effet ; vrai s'il existe.
static func set_effect(world: Node3D, effect: String, on: bool) -> bool:
	var environment: Environment = world.environment
	var sun: DirectionalLight3D = world.sun_light
	if environment == null or not (effect in EFFECTS or effect in VARIANTS):
		return false
	if not on and _effects.has(effect):
		return true
	match effect:
		"ciel":
			if on:
				environment.background_mode = _effects.get(effect, environment.background_mode)
			else:
				_effects[effect] = environment.background_mode
				environment.background_color = Color("#9fd0ef")
				environment.background_mode = Environment.BG_COLOR
		"brume":
			if on:
				environment.fog_enabled = _effects.get(effect, environment.fog_enabled)
			else:
				_effects[effect] = environment.fog_enabled
				environment.fog_enabled = false
		"ombres":
			if sun == null:
				return false
			if on:
				sun.shadow_enabled = _effects.get(effect, sun.shadow_enabled)
			else:
				_effects[effect] = sun.shadow_enabled
				sun.shadow_enabled = false
		"saturation":
			if on:
				environment.adjustment_enabled = _effects.get(effect, environment.adjustment_enabled)
			else:
				_effects[effect] = environment.adjustment_enabled
				environment.adjustment_enabled = false
		# Sol détaillé (grains, fibres, relief fin) : coupé = sol simplifié de la qualité Performance.
		"sol_detaille":
			if on:
				TerrainMaterials.set_simple(_effects.get(effect, TerrainMaterials.simple))
			else:
				_effects[effect] = TerrainMaterials.simple
				TerrainMaterials.set_simple(true)
		# Ciel calculé une seule fois (il ne change pas) au lieu d'un peu à chaque image.
		"ciel_fixe":
			if environment.sky == null:
				return false
			if on:
				environment.sky.process_mode = _effects.get(effect, environment.sky.process_mode)
			else:
				_effects[effect] = environment.sky.process_mode
				environment.sky.process_mode = Sky.PROCESS_MODE_QUALITY
		# Carte des ombres du soleil plus petite (2048 ou 1024 points de côté) que celle du réglage.
		"ombres_2048", "ombres_1024":
			var bits16: bool = ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/16_bits", true)
			var current: int = world.get_script().shadow_atlas if world.get_script().shadow_atlas > 0 else int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size", 4096))
			if on:
				RenderingServer.directional_shadow_atlas_set_size(int(_effects.get(effect, current)), bits16)
			else:
				_effects[effect] = current
				RenderingServer.directional_shadow_atlas_set_size(2048 if effect == "ombres_2048" else 1024, bits16)
		# Ombres du soleil en un seul niveau (au lieu de deux sur PC).
		"ombres_1_niveau":
			if sun == null:
				return false
			if on:
				sun.directional_shadow_mode = _effects.get(effect, sun.directional_shadow_mode)
			else:
				_effects[effect] = sun.directional_shadow_mode
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		"sans_anticrenelage":
			var viewport := world.get_viewport()
			if on:
				viewport.msaa_3d = _effects.get(effect, viewport.msaa_3d)
			else:
				_effects[effect] = viewport.msaa_3d
				viewport.msaa_3d = Viewport.MSAA_DISABLED
		# Images des feuilles avec mipmaps (versions réduites pour le lointain et la carte des ombres).
		"feuilles_mipmaps":
			if on:
				var textures: Dictionary = _effects.get(effect, {})
				for kind in textures:
					Trees.material(kind, "leaves").albedo_texture = textures[kind]
			else:
				var textures := {}
				for kind in range(Trees.FILES.size()):
					var material: StandardMaterial3D = Trees.material(kind, "leaves")
					var original: Texture2D = material.albedo_texture
					if original == null:
						continue
					textures[kind] = original
					var image := original.get_image()
					if image.is_compressed():
						image.decompress()
					image.generate_mipmaps()
					material.albedo_texture = ImageTexture.create_from_image(image)
				_effects[effect] = textures
		# Ombres des arbres : seulement celles des arbres proches (modèles simplifiés du lointain sans ombre).
		"ombres_arbres_proches", "ombres_sans_arbres":
			if on:
				var before: Dictionary = _effects.get(effect, {})
				for id in before:
					var node := instance_from_id(id) as GeometryInstance3D
					if node != null:
						node.cast_shadow = before[id][0]
						node.visible = before[id][1]
			else:
				var saved := {}
				for node: GeometryInstance3D in sorted(world).arbres:
					var part := str(node.get_meta("part", node.name))
					if effect == "ombres_arbres_proches" and part != "Loin":
						continue
					saved[node.get_instance_id()] = [node.cast_shadow, node.visible]
					# Modèle d'ombre seule : caché ; les autres : sans ombre.
					if node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
						node.visible = false
					else:
						node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_effects[effect] = saved
		# Arbres détaillés jusqu'à 28 m (comme la qualité Performance), au lieu de 40 m.
		"arbres_28m":
			if on:
				var before: Dictionary = _effects.get(effect, {})
				for id in before.get("noeuds", {}):
					var node := instance_from_id(id) as GeometryInstance3D
					if node != null:
						node.visibility_range_begin = before.noeuds[id][0]
						node.visibility_range_end = before.noeuds[id][1]
				Trees.detail_end = before.get("fin", Trees.detail_end)
			else:
				var saved := {"fin": Trees.detail_end, "noeuds": {}}
				for node: GeometryInstance3D in sorted(world).arbres:
					var part := str(node.get_meta("part", node.name))
					if not part in ["Detail", "Ombre", "Loin", "Liane"]:
						continue
					saved.noeuds[node.get_instance_id()] = [node.visibility_range_begin, node.visibility_range_end]
					if part == "Loin":
						node.visibility_range_begin = 28.0
					else:
						node.visibility_range_end = 28.0
				_effects[effect] = saved
				Trees.detail_end = 28.0
	if on:
		_effects.erase(effect)
	return true

# Tout remis comme avant.
static func restore_all(world: Node3D) -> void:
	for id in _hidden.keys():
		var node := instance_from_id(id) as Node
		if node != null:
			node.visible = _hidden[id]
	_hidden.clear()
	for effect in _effects.keys():
		set_effect(world, effect, true)
	_effects.clear()

# Nombre de choses dessinées de chaque sorte (pour le rapport).
static func counts(world: Node3D) -> Dictionary:
	var result := {}
	var all := sorted(world)
	for sort in all:
		result[sort] = all[sort].size()
	return result

# --- Endroits de mesure (mêmes pour tools/mesure_gpu.gd et la console du Web) ---
const SPOTS := ["depart", "foret", "lac", "riviere"]

# [place, regard] d'un endroit (mètres, x et z) ; [] : introuvable dans ce monde.
static func spot_target(world: Node3D, name: String) -> Array:
	var terrain = world.terrain
	var lakes: Array = terrain._lakes_near(Vector2.ZERO)
	var lake_center := Vector2(60, 0)
	var lake_radius := 10.0
	if not lakes.is_empty():
		var nearest: Dictionary = lakes[0]
		for lake: Dictionary in lakes:
			if ((lake.start + lake.end) * 0.5).length() < ((nearest.start + nearest.end) * 0.5).length():
				nearest = lake
		lake_center = (nearest.start + nearest.end) * 0.5
		lake_radius = float(nearest.radius)
	match name:
		"depart":
			return [Vector2(0.5, 0.5), lake_center]
		"lac":
			return [lake_center + (Vector2(0.5, 0.5) - lake_center).normalized() * (lake_radius + 3.0), lake_center]
		"foret":
			var center := Vector2(-80, 40)
			var best := INF
			for forest: Dictionary in terrain.forests():
				var distance: float = (forest.center as Vector2).length() - (10000.0 if forest.kind == terrain.FOREST_PINE else 0.0)
				if distance < best:
					best = distance
					center = forest.center
			return [center, center + Vector2(20, 5)]
		"riviere":
			var rivers: Array = terrain.rivers()
			if rivers.is_empty():
				return []
			var points: PackedVector2Array = rivers[0].points
			var index := points.size() / 2
			var along := points[mini(index + 1, points.size() - 1)] - points[index]
			var side := along.normalized().orthogonal() * (float(rivers[0].widths[index]) + 2.0)
			return [points[index] + side, points[mini(index + 3, points.size() - 1)]]
	return []

# Le joueur à cet endroit, au sol, regard un peu vers le bas (la vue suit ; attendre que tout soit construit).
static func go_to_spot(world: Node3D, name: String) -> bool:
	var target := spot_target(world, name)
	if target.is_empty():
		return false
	var at: Vector2 = target[0]
	var look: Vector2 = target[1]
	var player: CharacterBody3D = world.player
	player.global_position = Vector3(at.x, world.terrain.height_at(at.x, at.y) + 0.05, at.y)
	player.velocity = Vector3.ZERO
	var direction := (look - at).normalized()
	player.rotation.y = atan2(-direction.x, -direction.y)
	if player.camera != null:
		player.camera.rotation.x = -0.12
	return true

# Le monde est-il entièrement construit autour (files vides) ?
static func built(world: Node3D) -> bool:
	return world.terrain_queue.is_empty() and world.far_queue.is_empty() and world.tree_queue.is_empty() and world.detail_queue.is_empty()

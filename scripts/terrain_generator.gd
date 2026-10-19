extends RefCounted
# Pure height data, independent of rendering, collisions and player controls.
# A future terrain renderer can consume this data without changing the player.
const SEED := 70621
const MAX_HEIGHT := 3
const MIN_CELL := -20
const MAX_CELL := 20

static func generate_hills(terrain_seed: int = SEED) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain_seed
	var hills: Array[Vector3] = []
	# Three or four separate sectors; modest hills, with a clear central spawn.
	var count := rng.randi_range(3, 4)
	var centers := [Vector2(-10, 0), Vector2(10, -1), Vector2(0, -12), Vector2(0, 14)]
	for index in range(count):
		var center: Vector2 = centers[index]
		hills.append(Vector3(center.x + rng.randf_range(-1.0, 1.0), center.y + rng.randf_range(-1.0, 1.0), rng.randf_range(4.0, 5.0)))
	return hills

static func generate_heights(terrain_seed: int = SEED) -> Dictionary:
	var hills := generate_hills(terrain_seed)
	var heights: Dictionary = {}
	for x in range(MIN_CELL, MAX_CELL + 1):
		for z in range(MIN_CELL, MAX_CELL + 1):
			# Preserve the original construction display and a clear spawn area.
			if x >= -5 and x <= 5 and z >= -6 and z <= 10:
				continue
			var height := 0
			for hill in hills:
				var distance := Vector2(x + 0.5, z + 0.5).distance_to(Vector2(hill.x, hill.y))
				var profile := maxf(0.0, 1.0 - distance / hill.z)
				height = maxi(height, ceili(profile * MAX_HEIGHT))
			if height > 0:
				heights[Vector2i(x, z)] = height
	return heights

static func generate_cells(terrain_seed: int = SEED) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	var heights := generate_heights(terrain_seed)
	for column: Vector2i in heights:
		for y in range(heights[column]):
			cells.append(Vector3i(column.x, y, column.y))
	return cells
extends SceneTree
# 0.0.8.27 (#160, demandes de l'utilisateur) : jour et nuit : 24 minutes par jour (1 s = 1 min), nouveau monde à 8 h,
# lever à 6 h 30, coucher à 22 h ; la nuit sombre mais pas noire ; l'heure affichée et sauvegardée.
const DayNight = preload("res://scripts/day_night.gd")
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

func frames(count: int) -> void:
	for index in range(count):
		await process_frame

func _run() -> void:
	# Règles.
	check(DayNight.START == 480.0 and DayNight.clock_text(DayNight.START) == "08:00" and DayNight.clock_text(1439.6) == "23:59", "a new world starts at 08:00; the clock shows hours and minutes")
	check(absf(DayNight.sun_height(390.0)) < 0.5 and absf(DayNight.sun_height(1320.0)) < 0.5, "the sun rises at 06:30 and sets at 22:00")
	check(DayNight.sun_height(855.0) > 60.0 and DayNight.sun_height(120.0) < -30.0, "high at mid-day (14:15), far below at night")
	check(is_equal_approx(DayNight.daylight(720.0), 1.0) and is_equal_approx(DayNight.daylight(0.0), 0.0) and DayNight.daylight(390.0) > 0.3 and DayNight.daylight(390.0) < 0.7, "daylight: full by day, none at night, half at sunrise")
	check(DayNight.light_share(0.0) > 0.1 and DayNight.light_share(0.0) < 0.25 and DayNight.ambient_share(0.0) > 0.2, "the night is dark, not black")
	var east: Vector3 = DayNight.light_rotation(400.0)
	var west: Vector3 = DayNight.light_rotation(1310.0)
	check(east.y > 80.0 and west.y < -80.0 and east.x < 0.0 and west.x < 0.0, "the sun goes from east to west, always above (the moon too)")
	check(DayNight.sky_horizon(1320.0).r > DayNight.sky_horizon(720.0).r and DayNight.sky_top(0.0).v < 0.25, "warm horizon at sunset, dark sky at night")
	# En partie.
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await frames(10)
	check(absf(world.day_time - 480.0) < 1.0 and world.clock_label.text == "08:00", "a new world: 08:00 shown at the top right")
	var start: float = world.day_time
	world._update_day(60.0)
	check(absf(world.day_time - start - 60.0) < 0.01 and world.clock_label.text == "09:00", "60 seconds = one hour")
	world.day_time = 0.0
	world._update_day(0.0)
	world.apply_day_sky()
	check(world.sun_light.light_energy < world.sun_base_energy * 0.25 and not world.sun_light.shadow_enabled and world.environment.ambient_light_energy < world.ambient_base_energy * 0.4, "midnight: weak moonlight, no shadows, dim ambient light")
	check(world.sky_material.sky_top_color.v < 0.25 and world.environment.fog_light_color.v < 0.4, "midnight: dark sky and haze")
	world.day_time = 720.0
	world._update_day(0.0)
	world.apply_day_sky()
	check(world.sun_light.light_energy > world.sun_base_energy * 0.9 and world.sun_light.shadow_enabled == (world.shadow_quality != "off"), "noon: full sun, shadows back")
	check(is_equal_approx(float(world.player_data().heure), 720.0), "the time is saved with the player")
	world.queue_free()
	await frames(2)
	print("RESULT: %d day and night checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

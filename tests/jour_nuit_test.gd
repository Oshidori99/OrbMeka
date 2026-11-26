extends SceneTree
# 0.0.8.27 (#160, demandes de l'utilisateur) : jour et nuit : 24 minutes par jour (1 s = 1 min), nouveau monde à 8 h,
# lever à 6 h 30, coucher à 22 h ; la nuit sombre mais pas noire ; l'heure affichée et sauvegardée.
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
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
	# 0.0.8.43 : la nuit est complète ; seulement un peu de lumière par pleine lune.
	check(DayNight.light_share(0.0) < 0.15 and DayNight.ambient_share(0.0) < 0.15, "the night is dark (full moon: a little light)")
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
	# --- 0.0.8.43 (demandes de l'utilisateur) : nuit complète, lune et ses phases, sombre sous terre, réglages. ---
	check(DayNight.moon_light(0.0) < 0.01 and DayNight.moon_light(0.5) > 0.99 and DayNight.moon_name(0.5) == "Pleine lune" and DayNight.moon_name(0.0) == "Nouvelle lune", "moon phases: new moon dark, full moon lit")
	check(is_equal_approx(DayNight.moon_phase(28, 0.0, 28), DayNight.moon_phase(0, 0.0, 28)) and is_equal_approx(DayNight.moon_phase(8, 0.0, 8), DayNight.moon_phase(0, 0.0, 8)) and not is_equal_approx(DayNight.moon_phase(14, 0.0, 28), DayNight.moon_phase(0, 0.0, 28)), "a full cycle every 28 days (or 8)")
	check(DayNight.light_share(0.0, 0.0) < 0.03 and DayNight.ambient_share(0.0, 0.0) < 0.04 and DayNight.ambient_share(0.0, 1.0) > DayNight.ambient_share(0.0, 0.0) * 3.0, "a new-moon night is black; a full moon gives some light")
	var days_before: int = world.day_count
	world.day_time = 1439.0
	world._update_day(2.0)
	check(world.day_count == days_before + 1 and world.player_data().jour == world.day_count, "midnight passed: one more day (saved, for the moon)")
	world.set_world_time_options("cycle", 48, 8)
	check(is_equal_approx(world.minutes_per_second(), 0.5) and world.moon_days == 8, "world settings: a 48-minute day, full moon every 8 days")
	world.set_world_time_options("day", 24, 28)
	world.day_time = 100.0
	world._update_day(1.0)
	check(is_equal_approx(world.day_time, 720.0), "« Toujours le jour »: always noon")
	world.set_world_time_options("cycle", 24, 28)
	# Sous terre : le ciel caché, la lumière tombe ; le réglage de luminosité la garde.
	world.day_time = 720.0
	world.sky_open = 0.0
	world._sky_target = 0.0
	world.night_light = 0.0
	world.apply_day_light()
	var cave: Vector2 = world.light_factors()
	check(cave.x < 0.01 and cave.y < 0.03, "deep underground at noon: almost black without a torch (%.3f, %.3f)" % [cave.x, cave.y])
	world.set_light_options({"night_light": "100"})
	check(world.light_factors().y >= 0.999 and world.environment.ambient_light_energy >= world.ambient_base_energy * 0.99, "Luminosité 100 %: we always see well, even underground")
	world.set_light_options({"night_light": "0"})
	var outside: float = world.sky_visible_share(world.player.camera.global_position)
	check(outside > 0.7, "outside: most of the sky is visible (%.2f)" % outside)
	var deep: Vector3 = world.player.camera.global_position + Vector3(0.0, -9.0, 0.0)
	var timed := Time.get_ticks_usec()
	var buried: float = world.sky_visible_share(deep)
	var open_ms := 0.0
	for rep in range(10):
		var t0 := Time.get_ticks_usec()
		world.sky_visible_share(world.player.camera.global_position)
		open_ms = maxf(open_ms, (Time.get_ticks_usec() - t0) / 1000.0)
	check(open_ms < 3.0 or OS.get_environment("GITHUB_ACTIONS") == "true", "sky check stays light: %.2f ms at most outside (judged on the PC only)" % open_ms)
	check(buried < 0.2, "9 m under the ground: the sky is hidden (%.2f)" % buried)
	world.sky_open = 1.0
	check(Settings.CHOICES.has("night_light") and Settings.CHOICES.night_light.default == "0" and Catalog.TIME_OPTIONS.has("moon_cycle") and Catalog.TIME_OPTIONS.day_length.default == "24", "settings: Vidéo → Lumière, and the world's day and night (Paramètres → Monde)")
	# La lune : un disque, la nuit seulement, selon sa phase.
	world.day_time = 30.0
	world._update_day(0.0)
	check(is_instance_valid(world.moon_disc) and world.moon_disc.visible and world.sun_light.sky_mode == DirectionalLight3D.SKY_MODE_LIGHT_ONLY, "at night the moon disc is shown (phase %s)" % DayNight.moon_name(DayNight.moon_phase(world.day_count, world.day_time, world.moon_days)))
	world.day_time = 720.0
	world._update_day(0.0)
	check(not world.moon_disc.visible, "not by day")
	world.queue_free()
	await frames(2)
	print("RESULT: %d day and night checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

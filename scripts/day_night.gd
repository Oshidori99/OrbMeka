extends RefCounted
# 0.0.8.27 (#160, demandes de l'utilisateur) : jour et nuit. Une journée dure 24 minutes : 1 seconde = 1 minute du jeu.
# Un nouveau monde commence à 8 h ; le soleil se lève à 6 h 30 et se couche à 22 h (choix de l'utilisateur). Le jour, le
# soleil passe de l'est (lever) à l'ouest (coucher) et monte jusqu'à SUN_TOP degrés ; la nuit, la lune fait de même,
# moins haut, d'une lumière faible et bleutée, sans ombres (plus léger). Autour du lever et du coucher : l'aube et le
# crépuscule (TWILIGHT minutes), ciel et lumière plus chauds. La nuit est sombre mais pas noire.
# Tout se calcule ici (fonctions pures, testées) ; world.gd applique la lumière, le ciel et la brume.
const DAY := 1440.0
const START := 480.0
const SUNRISE := 390.0
const SUNSET := 1320.0
const MINUTES_PER_SECOND := 1.0
const SUN_TOP := 62.0
const MOON_TOP := 38.0
# Minutes de part et d'autre du lever et du coucher où la lumière monte ou descend.
const TWILIGHT := 45.0
# Lumière de la nuit (part de celle du jour) : sombre, pas noire.
const NIGHT_SUN := 0.16
const NIGHT_AMBIENT := 0.28
# Couleurs : jour (celles d'avant 0.0.8.27), crépuscule, nuit.
const DAY_TOP := Color("#428de0")
const DAY_HORIZON := Color("#b9e2fa")
const DUSK_TOP := Color("#5a6fae")
const DUSK_HORIZON := Color("#f0a46a")
const NIGHT_TOP := Color("#0b1530")
const NIGHT_HORIZON := Color("#22314f")
const SUN_COLOR := Color("#fff1d8")
const LOW_SUN_COLOR := Color("#ffb878")
const MOON_COLOR := Color("#a8bcff")
const DAY_AMBIENT := Color("#dbe7ed")
const NIGHT_AMBIENT_COLOR := Color("#7c8fb8")

static func day_wrap(minutes: float) -> float:
	return fposmod(minutes, DAY)

static func is_day(minutes: float) -> bool:
	var t := day_wrap(minutes)
	return t >= SUNRISE and t < SUNSET

# Part du chemin du soleil (jour) ou de la lune (nuit) : 0 au lever, 1 au coucher.
static func progress(minutes: float) -> float:
	var t := day_wrap(minutes)
	if is_day(t):
		return (t - SUNRISE) / (SUNSET - SUNRISE)
	var night := DAY - (SUNSET - SUNRISE)
	return fposmod(t - SUNSET, DAY) / night

# Hauteur du soleil (degrés ; négative la nuit, sous l'horizon).
static func sun_height(minutes: float) -> float:
	var share := progress(minutes)
	if is_day(minutes):
		return sin(PI * share) * SUN_TOP
	return -sin(PI * share) * SUN_TOP

# Jour : 1 ; nuit : 0 ; entre les deux à l'aube et au crépuscule (TWILIGHT minutes avant et après).
static func daylight(minutes: float) -> float:
	var t := day_wrap(minutes)
	var after_rise := t - SUNRISE
	var before_set := SUNSET - t
	if after_rise < -DAY * 0.5:
		after_rise += DAY
	var up := smoothstep(-TWILIGHT, TWILIGHT, after_rise)
	var down := smoothstep(-TWILIGHT, TWILIGHT, before_set)
	return clampf(minf(up, down), 0.0, 1.0)

# Aube et crépuscule : 1 tout près du lever ou du coucher, 0 loin d'eux.
static func dusk(minutes: float) -> float:
	var t := day_wrap(minutes)
	var gap := minf(absf(t - SUNRISE), absf(t - SUNSET))
	return 1.0 - smoothstep(0.0, TWILIGHT * 2.0, gap)

# Rotation (degrés) de la lumière : le soleil le jour, la lune la nuit ; d'est en ouest.
static func light_rotation(minutes: float) -> Vector3:
	var share := progress(minutes)
	var top := SUN_TOP if is_day(minutes) else MOON_TOP
	var height := maxf(sin(PI * share) * top, 4.0)
	return Vector3(-height, lerpf(100.0, -100.0, share), 0.0)

# Part de la lumière directe (1 = le soleil de midi d'avant) : soleil le jour, la lune faible la nuit.
static func light_share(minutes: float) -> float:
	var day := daylight(minutes)
	var low := clampf(sun_height(minutes) / 25.0, 0.35, 1.0) if is_day(minutes) else 0.35
	return lerpf(NIGHT_SUN, low, day)

static func ambient_share(minutes: float) -> float:
	return lerpf(NIGHT_AMBIENT, 1.0, daylight(minutes))

static func light_color(minutes: float) -> Color:
	var day := daylight(minutes)
	var warm := SUN_COLOR.lerp(LOW_SUN_COLOR, dusk(minutes))
	return MOON_COLOR.lerp(warm, day)

static func ambient_color(minutes: float) -> Color:
	return NIGHT_AMBIENT_COLOR.lerp(DAY_AMBIENT, daylight(minutes))

static func sky_top(minutes: float) -> Color:
	var day := daylight(minutes)
	return NIGHT_TOP.lerp(DAY_TOP.lerp(DUSK_TOP, dusk(minutes) * 0.6), day)

static func sky_horizon(minutes: float) -> Color:
	var day := daylight(minutes)
	var twilight := dusk(minutes)
	# Au crépuscule, l'horizon reste coloré un peu après le coucher.
	return NIGHT_HORIZON.lerp(DAY_HORIZON.lerp(DUSK_HORIZON, twilight), maxf(day, twilight * 0.9))

static func clock_text(minutes: float) -> String:
	var t := int(floor(day_wrap(minutes)))
	return "%02d:%02d" % [t / 60, t % 60]

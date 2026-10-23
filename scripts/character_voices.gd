extends Node
# Voix des personnages (0.0.4.12) : jouée quand on choisit un personnage (Paramètres → Personnage).
# Humains : synthèse vocale de l'ordinateur (voix française du système, rien d'enregistré), plus
# aiguë pour les plus jeunes ; chaque âge a ses phrases (les 9 ans plus enfantines).
# Animaux : cris fabriqués par le jeu (ondes simples, aucun fichier ni son d'un autre jeu).
# Volume : Paramètres généraux → Son → Volume des personnages (0 = muet).
const RATE := 22050
const LINES := {
	"9 ans": ["Jouons ensemble !", "On construit une cabane ?", "Viens, on fait la course !"],
	"14 ans": ["Salut ! On part explorer ?", "Allez, on construit un truc stylé.", "On va voir ce qu'il y a derrière la colline ?"],
	"adulte": ["Bonjour ! Prêt à construire ?", "Belle journée pour bâtir.", "En route pour l'aventure."],
}
# [hauteur de la voix (1 = normale), débit]
const PITCHES := {
	"boy9": [1.6, 1.1], "girl9": [1.8, 1.1], "boy14": [1.15, 1.05], "girl14": [1.45, 1.05],
	"man": [0.8, 1.0], "woman": [1.2, 1.0],
}
# Cri de chaque animal : parties [de (Hz), à (Hz), durée (s), force, harmoniques (0 à 1), vibrato (Hz)] ;
# une force de 0 est un silence.
const ANIMAL_CALLS := {
	"cat": [[480.0, 820.0, 0.18, 0.5, 0.35, 6.0], [820.0, 430.0, 0.32, 0.5, 0.35, 6.0]],
	"brioche": [[700.0, 980.0, 0.12, 0.4, 0.2, 8.0], [980.0, 760.0, 0.2, 0.4, 0.2, 8.0]],
	"squirrel": [[2400.0, 2900.0, 0.05, 0.35, 0.1, 0.0], [0.0, 0.0, 0.04, 0.0, 0.0, 0.0], [2500.0, 3000.0, 0.05, 0.35, 0.1, 0.0], [0.0, 0.0, 0.04, 0.0, 0.0, 0.0], [2600.0, 3100.0, 0.06, 0.35, 0.1, 0.0]],
	"fox": [[850.0, 1350.0, 0.09, 0.45, 0.6, 0.0], [0.0, 0.0, 0.08, 0.0, 0.0, 0.0], [900.0, 1400.0, 0.11, 0.45, 0.6, 0.0]],
	"turtle": [[170.0, 140.0, 0.4, 0.55, 0.3, 3.0]],
	"rabbit": [[1700.0, 2100.0, 0.07, 0.3, 0.1, 0.0], [0.0, 0.0, 0.05, 0.0, 0.0, 0.0], [90.0, 60.0, 0.08, 0.6, 0.0, 0.0]],
}
var volume := 80.0
var animal_player: AudioStreamPlayer
var animal_streams: Dictionary = {}
# Dernière phrase ou dernier cri (pour les tests) : {"character", "text" ou "call", "pitch"}.
var last := {}
var line_index := 0

func _ready() -> void:
	animal_player = AudioStreamPlayer.new()
	animal_player.name = "AnimalCall"
	add_child(animal_player)
	set_volume(volume)

static func is_animal(id: String) -> bool:
	return ANIMAL_CALLS.has(id)

# Cri d'un animal, fabriqué une fois puis gardé.
func animal_stream(id: String) -> AudioStreamWAV:
	if not animal_streams.has(id):
		animal_streams[id] = make_call(ANIMAL_CALLS[id])
	return animal_streams[id]

static func make_call(parts: Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	var phase := 0.0
	for part in parts:
		var count := int(RATE * part[2])
		var start := data.size()
		data.resize(start + count * 2)
		for index in range(count):
			var t := float(index) / count
			var sample := 0.0
			if part[3] > 0.0:
				var wobble: float = 1.0 + 0.03 * sin(TAU * part[5] * index / RATE)
				phase += TAU * lerpf(part[0], part[1], t) * wobble / RATE
				var tone: float = sin(phase) * (1.0 - part[4]) + (sin(phase) + 0.5 * sin(2.0 * phase) + 0.3 * sin(3.0 * phase)) / 1.8 * part[4]
				sample = tone * minf(1.0, t * 15.0) * pow(1.0 - t, 1.5) * part[3]
			data.encode_s16(start + index * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream

func set_volume(percent: float) -> void:
	volume = clampf(percent, 0.0, 100.0)
	if is_instance_valid(animal_player):
		animal_player.volume_db = linear_to_db(maxf(volume, 0.01) / 100.0)

# Phrase suivante de l'âge du personnage (elles tournent), avec sa hauteur de voix.
func next_line(id: String, age: String) -> Dictionary:
	var lines: Array = LINES.get(age, LINES.adulte)
	var text: String = lines[line_index % lines.size()]
	line_index += 1
	var pitch: Array = PITCHES.get(id, [1.0, 1.0])
	return {"character": id, "text": text, "pitch": pitch[0], "rate": pitch[1]}

func speak(id: String, age: String) -> void:
	if volume <= 0.0:
		return
	if is_animal(id):
		last = {"character": id, "call": id}
		animal_player.stream = animal_stream(id)
		animal_player.play()
		return
	last = next_line(id, age)
	# Synthèse vocale du système, si elle existe (pas en mode sans fenêtre) ; voix française d'abord.
	if DisplayServer.get_name() == "headless" or not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	var voices := DisplayServer.tts_get_voices_for_language("fr")
	if voices.is_empty():
		return
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(last.text, voices[0], int(volume), last.pitch, last.rate)

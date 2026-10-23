extends Node
# Sons des menus (0.0.4.11, #96) : fabriqués par le code (ondes simples), sans fichier ni son
# d'un autre jeu. « hover » : petit tic au survol d'un bouton ; « click » : bip montant ;
# « back » : bip descendant (Retour, Annuler). Volume : Paramètres généraux → Son (0 = muet).
const RATE := 22050
# [fréquence de départ (Hz), fréquence d'arrivée, durée (s), force (0 à 1)]
const SOUNDS := {
	"hover": [1500.0, 1500.0, 0.03, 0.25],
	"click": [620.0, 930.0, 0.07, 0.5],
	"back": [560.0, 380.0, 0.09, 0.5],
}
var players: Dictionary = {}
var volume := 60.0
# Derniers sons joués (pour les tests) : nom, du plus ancien au plus récent.
var played: Array = []

func _ready() -> void:
	for sound in SOUNDS:
		var player := AudioStreamPlayer.new()
		player.name = "Sound_" + sound
		player.stream = make_tone(SOUNDS[sound][0], SOUNDS[sound][1], SOUNDS[sound][2], SOUNDS[sound][3])
		add_child(player)
		players[sound] = player
	set_volume(volume)

# Onde sinusoïdale qui glisse d'une fréquence à l'autre, attaque courte et fin qui s'éteint.
static func make_tone(from_hz: float, to_hz: float, duration: float, strength: float) -> AudioStreamWAV:
	var count := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for index in range(count):
		var t := float(index) / count
		phase += TAU * lerpf(from_hz, to_hz, t) / RATE
		var envelope := minf(1.0, t * 20.0) * pow(1.0 - t, 2.0)
		data.encode_s16(index * 2, int(clampf(sin(phase) * envelope * strength, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream

func set_volume(percent: float) -> void:
	volume = clampf(percent, 0.0, 100.0)
	for sound in players:
		players[sound].volume_db = linear_to_db(maxf(volume, 0.01) / 100.0)

func play(sound: String) -> void:
	if volume <= 0.0 or not players.has(sound):
		return
	played.append(sound)
	if played.size() > 20:
		played.pop_front()
	players[sound].play()

# Branche un bouton : survol (s'il est actif) et appui ; Retour et Annuler font le son « back ».
func attach(button: BaseButton) -> void:
	button.mouse_entered.connect(func(): if not button.disabled: play("hover"))
	var text: String = button.text if button is Button else ""
	var sound: String = "back" if text.begins_with("Retour") or text.begins_with("Annuler") else "click"
	button.pressed.connect(func(): play(sound))

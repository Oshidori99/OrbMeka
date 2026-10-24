extends RefCounted
# Licences (0.0.4.17) : mentions obligatoires de Godot (licence MIT) et de ses composants, et origine
# des sons CC0 et des polices. Montrées dans le jeu (Paramètres → Licences, dernier onglet) et copiées dans LICENCES.txt, à côté du jeu
# dans chaque zip et sur itch.io (fichier docs/LICENCES.txt, refait par tests/licences_test.gd).

const GAME := "OrbMeka — © 2026 Oshidori99. Tous droits réservés (fichier LICENSE). Code, personnages et formes : créations originales d'OrbMeka."
const SOUNDS := "Sons d'animaux, CC0 1.0 (domaine public) : « Meow » (IgnasD, OpenGameArt), « Kitten Mew » (AntumDeluge, OpenGameArt), « Bunny hutch » n° 1376 (Joseph Sardin, BigSoundBank, extrait). Autres sons fabriqués par le jeu."
const FONTS := "Polices de secours (version Web) : DejaVu Sans (© Bitstream, Tavmjong Bah ; licence Bitstream Vera / Arev, libre) et Noto Emoji (© 2013 Google LLC ; SIL Open Font License 1.1). Textes complets dans LICENCES.txt."
const FONT_LICENSES := {"DejaVu Sans": "res://assets/fonts/DejaVuSans-LICENSE.txt", "Noto Emoji": "res://assets/fonts/NotoEmoji-OFL.txt"}

# Texte de la page Licences : OrbMeka, Godot (licence MIT complète), sons, et la liste des composants.
static func summary() -> String:
	var lines := [GAME, "", "Moteur : Godot Engine (https://godotengine.org), licence MIT :", "", Engine.get_license_text(), "", SOUNDS, "", FONTS, "", "Composants de Godot inclus (textes complets dans LICENCES.txt, à côté du jeu) :"]
	for component in Engine.get_copyright_info():
		var licenses := []
		for part in component.parts:
			if not part.license in licenses:
				licenses.append(part.license)
		lines.append("· %s — %s" % [component.name, ", ".join(licenses)])
	return "\n".join(lines)

# LICENCES.txt : le résumé, puis chaque composant (copyright) et le texte de chaque licence.
static func full_text() -> String:
	var lines := [summary(), "", "", "=== COPYRIGHTS DES COMPOSANTS ==="]
	for component in Engine.get_copyright_info():
		lines.append("")
		lines.append(str(component.name))
		for part in component.parts:
			for holder in part.copyright:
				lines.append("  Copyright " + str(holder))
			lines.append("  Licence : " + str(part.license))
	lines.append("")
	lines.append("")
	lines.append("=== TEXTES DES LICENCES ===")
	for font in FONT_LICENSES:
		lines.append("")
		lines.append("--- Police " + font + " ---")
		lines.append(FileAccess.get_file_as_string(FONT_LICENSES[font]).replace("\r\n", "\n").strip_edges())
	var info := Engine.get_license_info()
	var names := info.keys()
	names.sort()
	for license_name in names:
		lines.append("")
		lines.append("--- " + str(license_name) + " ---")
		lines.append(str(info[license_name]))
	return "\n".join(lines) + "\n"

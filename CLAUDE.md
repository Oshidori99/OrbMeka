# OrbMeka — règles pour Claude

Jeu de construction en blocs, Godot 4.7.2 / GDScript, formes simples sans assets externes.
Guide complet : docs/README.md. Fichiers techniques : docs/ORGANISATION.txt.

## Communication
- Répondre en français, de façon **très synthétique** (l'utilisateur lit souvent à voix haute).
- L'utilisateur n'est pas expert Git : expliquer les étapes simplement.

## Structure
- scenes/ : main.tscn (menus), world.tscn (partie). scripts/ : code. tests/ : tests sans fenêtre.
- Garder les .gd.uid avec leurs scripts. Ne pas toucher à .godot/ (cache) ni à Archives/ (local, ignoré par Git).
- Données joueur dans user:// (worlds.json, settings.json), jamais dans les sources.

## Tests
Depuis PowerShell, à la racine du projet :

    & 'C:\Users\Dev\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/<nom>_test.gd

Lancer les tests liés au changement ; ce qui ne peut être vérifié qu'en jouant (aspect, souris) est signalé comme « à tester manuellement ».

## Nouvelle version
1. Numéro dans project.godot (config/version) et en tête de docs/README.md et README.md.
2. Entrée en haut de HISTORIQUE.txt : « X.Y.Z — Titre » + 1 à 2 lignes courtes.
3. Section dans docs/README.md : ce qui change, tests réussis, ce qui reste à tester.
4. Item dans le GitHub Project https://github.com/users/Oshidori99/projects/10 (Done une fois fini).
5. Commit puis push sur Oshidori99/OrbMeka (main).

gh CLI : "C:\Program Files\GitHub CLI\gh.exe" (connecté en Oshidori99).

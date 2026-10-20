# OrbMeka — règles pour Claude

Jeu de construction en blocs, Godot 4.7.2 / GDScript, formes simples sans assets externes.
Guide complet : docs/README.md. Fichiers techniques : docs/ORGANISATION.txt.

## Communication
- Répondre en français, de façon **très synthétique** (l'utilisateur lit souvent à voix haute).
- L'utilisateur n'est pas expert Git : expliquer les étapes simplement.

## Juridique (prioritaire)
- Signaler **immédiatement** tout risque : droit suisse/UE, Mojang/Microsoft, licences, données personnelles.
- Ne rien reprendre de Minecraft (code, assets, noms, éléments emblématiques, interface identique) ; proposer une alternative originale.
- Voir « Cadre juridique » dans README.md.

## Structure
- scenes/ : main.tscn (menus), world.tscn (partie). scripts/ : code. tests/ : tests sans fenêtre.
- Garder les .gd.uid avec leurs scripts. Ne pas toucher à .godot/ (cache) ni au contenu existant d'Archives/ (local, ignoré par Git) ; on y ajoute seulement l'archive de chaque version.
- Données joueur dans user:// (worlds.json, parametres-generaux.json, video.json, controles.json, personnage.json, attributs.json), jamais dans les sources.

## Tests
Depuis PowerShell, à la racine du projet :

    & 'C:\Users\Dev\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/<nom>_test.gd

Lancer les tests liés au changement ; ce qui ne peut être vérifié qu'en jouant (aspect, souris) est signalé comme « à tester manuellement ».

## Branches et builds
- `dev` : travail en cours. `main` : seulement les versions validées.
- Un tag `vX.Y.Z` lance .github/workflows/build.yml : exports Windows et Web (export_presets.cfg),
  Release GitHub (OrbMeka-X.Y.Z-windows.zip, OrbMeka-X.Y.Z-web.zip), puis itch.io si les secrets
  BUTLER_API_KEY et ITCH_TARGET existent. Reconstruire un ancien tag : Actions > Build > Run workflow.
- Ne jamais lire, afficher ni demander la clé itch.io : l'utilisateur la met lui-même dans les Secrets.

## Travail depuis le cloud (téléphone)
L'utilisateur peut lancer Claude Code dans le cloud depuis son téléphone, sur le dépôt GitHub Oshidori99/OrbMeka.
- Dans le cloud : travailler **uniquement sur `dev`** (commit + push sur dev). Ne jamais toucher à `main`, ni créer de tag, ni lancer de Release.
- Godot, gh CLI, Archives/ et les chemins C:\… n'existent pas dans le cloud : pas de tests Godot, pas d'archive, pas de modification du Project.
  Le dire à l'utilisateur et lister ce qui reste à faire sur le PC.
- Ajouter en bas de docs/README.md une note « À vérifier sur PC » avec les changements faits depuis le cloud.
- De retour sur le PC (« récupère dev et teste ») : `git pull` sur dev, lancer les tests, faire tester en jeu,
  puis, si l'utilisateur valide, suivre « Nouvelle version » (fusion dans main, tag, Project, archive).

## Nouvelle version
0. Travailler et committer sur `dev`.
1. Numéro dans project.godot (config/version) et en tête de docs/README.md et README.md.
   Mettre à jour la vitrine de l'accueil (section VITRINE de scripts/menu_showcase.gd).
2. Entrée en haut de docs/HISTORIQUE.txt : « X.Y.Z — Titre » + 1 à 2 lignes courtes.
3. Section dans docs/README.md : ce qui change, tests réussis, ce qui reste à tester.
4. Item dans le GitHub Project https://github.com/users/Oshidori99/projects/10 (Done une fois fini).
5. Commit sur `dev`, puis fusionner dans `main` (`git checkout main`, `git merge dev`),
   créer le tag (`git tag vX.Y.Z`), pousser (`git push origin main dev vX.Y.Z`), revenir sur `dev`.
   Vérifier que l'Action Build est verte et que la Release existe.
6. Archive : copie du dossier du jeu (sans .git/ ni Archives/) dans « Archives/orb-meka X.Y.Z ». Ne jamais écraser une archive existante.

gh CLI : "C:\Program Files\GitHub CLI\gh.exe" (connecté en Oshidori99).

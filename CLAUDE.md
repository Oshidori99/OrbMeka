# OrbMeka — règles pour Claude

Jeu de construction et d'exploration, Godot 4.7.2 / GDScript (pas de C# : il empêcherait l'export Web).
Personnages 3D faits dans Blender (assets/characters), sons en partie CC0 ; assets externes seulement sous licence vérifiée, notée dans README.md.
Guide complet : docs/README.md. Fichiers techniques : docs/ORGANISATION.txt.

## Communication
- Répondre en français, de façon **très synthétique** (l'utilisateur lit souvent à voix haute).
- L'utilisateur n'est pas expert Git : expliquer les étapes simplement.

## Juridique (prioritaire)
- Signaler **immédiatement** tout risque : droit suisse/UE, autres jeux et éditeurs (surtout le jeu de blocs le plus connu), licences, données personnelles.
- Ne rien reprendre d'un autre jeu (code, assets, noms, éléments emblématiques, interface identique) ; proposer une alternative originale. Ne jamais citer un autre jeu dans le dépôt (il est public).
- Voir « Cadre juridique » dans README.md.

## Structure
- scenes/ : main.tscn (menus), world.tscn (partie). scripts/ : code. tests/ : tests sans fenêtre.
- Garder les .gd.uid avec leurs scripts. Ne pas toucher à .godot/ (cache) ni au contenu existant des archives (dossier voisin « ..\Archives OrbMeka », hors du dépôt) ; on y ajoute seulement l'archive de chaque **nouvelle série** (0.0.x).
- Données joueur dans user://, jamais dans les sources :
  - réglages dans user://parametres/ : parametres-generaux.json, video.json, controles.json, personnage.json, attributs.json, menus.json ;
  - mondes : worlds.json (index) et un dossier par monde mondes/<id>/ : monde.json (nom, **graine**, mode),
    joueur.json (position, regard), zones/zone_X_Y_Z.bin (seulement les changements, format versionné) ;
  - launcher : launcher/.

## Tests
Depuis PowerShell, à la racine du projet, en parallèle (4 à la fois) :

    .\tests\run_all.ps1 -Only fly,controls   # toujours : seulement les plus pertinents (≈ 65 %), même avant une version
    .\tests\run_all.ps1                      # tous : seulement sur demande (l'Action Dev les lance tous à chaque envoi)

Les tests juridiques (licences, aucun autre jeu cité) passent **toujours**, même avec -Only.
**Sécurité du PC** (planté le 24.10.2026, mémoire à 99 %) : run_all.ps1 ne lance plus de test au-delà de 85 % de mémoire,
arrête tout au-delà de 90 % et coupe un test qui dépasse 2 Go. Ne jamais lancer de tests depuis deux sessions à la fois ;
utiliser -Jobs 2 si le PC est en mode économie d'énergie ou si d'autres gros programmes tournent (Blender, éditeur Godot).
Godot console : C:\Users\Dev\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe
Un seul test : `& '<Godot console>' --headless --path . --script res://tests/<nom>_test.gd`.
L'Action Dev lance tous les tests en parallèle à chaque envoi. Ce qui ne peut être vérifié qu'en
jouant (aspect, souris) est signalé comme « à tester manuellement ».

## Plan du Monde (milestone « 0.0.5 — Monde », issues #119 à #124)
Ordre obligatoire de 1 à 4, ensuite libre :
1. Dossier du monde et sauvegarde des seuls changements : fait (0.0.5).
2. Zones (#119) : fait en 0.0.5.1 ; taille confirmée : 8 × 8 × 8 mètres (scripts/world_zones.gd).
3. Terrain lisse sculptable (#120) : en cours ; première version livrée en 0.0.5.8 (scripts/smooth_terrain.gd :
   sol lisse, creuser / ajouter 50 cm par clic, sauvegarde des points changés). Chaque bloc de 1 m de côté est
   divisé en 2 × 2 × 2 = 8 sous-cellules au total : chacune mesure 50 cm de côté et représente
   1/8 du volume du bloc. Une zone de 8 m contient donc 16 × 16 × 16 sous-cellules ; une grille
   de sommets incluant les deux bords aurait 17 sommets par axe (pas 16 points).
   Rendu lisse, pinceaux (creuser, ajouter, aplanir, lisser : faits en 0.0.5.9), sauvegarde de l'état des zones modifiées point par point (pas geste par geste). En petites versions.
4. Relief procédural et sous-sol (#121) : terre, pierre, granite, grottes ; « Roche-mère » incassable en bas
   (0.0.5.12 : couches faites, 4 m de terre, 4 m de pierre, Roche-mère à 8 m ; relief et grottes à faire)
   (ne pas reprendre le nom anglais courant d'un autre jeu).
5. Matières (#122) · 6. Structures (#123) · 7. Créatif/Survie (#73) · Inventaire (milestone HUD) ·
   Eau réaliste (#124 : lacs-réservoirs à volume, rivières en hauteur d'eau).
   Note pour plus tard (gravité réaliste, demandée par l'utilisateur ; 0.0.5.11 n'en fait qu'une première version) :
   sable : glisse au-delà d'environ 34° et ne tient jamais en plafond ; terre : pentes raides possibles
   et petit plafond d'environ 1 m au plus, au-delà elle s'effondre ; pierre : ne tombe pas. Plus tard,
   des poutres pourront soutenir la terre. Casser la pierre : plus tard, avec une belle animation (0.0.5.12 : incassable).
Règles : même graine = même monde ; mondes légers (seulement les changements, compressés) ;
mesurer les performances sur PC et sur le Web à chaque étape.

## Branches et builds
- `dev` : travail en cours. `main` : seulement les versions validées.
- Un tag `vX.Y.Z` lance .github/workflows/build.yml : exports Windows et Web (export_presets.cfg),
  Release GitHub (OrbMeka-X.Y.Z-windows.zip, OrbMeka-X.Y.Z-web.zip), puis itch.io si les secrets
  BUTLER_API_KEY et ITCH_TARGET existent. Reconstruire un ancien tag : Actions > Build > Run workflow.
- Ne jamais lire, afficher ni demander la clé itch.io : l'utilisateur la met lui-même dans les Secrets.

## Travail depuis le cloud (téléphone)
L'utilisateur peut lancer Claude Code dans le cloud depuis son téléphone, sur le dépôt GitHub Oshidori99/OrbMeka.
- Travailler **sur `dev`** (commit + push). Chaque push sur dev lance .github/workflows/dev.yml :
  tous les tests Godot sans fenêtre, puis, s'ils passent, la version Web sur la page itch.io unique et privée (secret ITCH_TARGET).
  Cette page montre donc toujours la dernière version, même non validée. Pas de deuxième page itch.io.
- Après chaque push : attendre le résultat de l'Action « Dev » (onglet Actions, ou `gh run list --branch dev` si gh existe).
  Si les tests échouent, corriger avant toute autre chose. Dire à l'utilisateur quand la page itch.io est à jour.
- Sur téléphone, l'utilisateur ne peut tester que menus et affichage (pas de commandes tactiles) : le rappeler pour le gameplay.
- **« Envoie dans main »** (dit explicitement par l'utilisateur, Action Dev verte) : suivre « Nouvelle version » étapes 1 à 5
  (version, historique, README, fusion dans main, tag, push). Le Project (étape 4) et, pour une nouvelle série, l'archive (étape 6) se font si possible,
  sinon les noter dans docs/README.md « À faire sur PC ».
- Godot local, les archives et les chemins C:\… n'existent pas dans le cloud. De retour sur le PC : `git pull`,
  rattraper le Project (et l'archive d'une nouvelle série) notés « À faire sur PC », puis supprimer la note.

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
6. Archive, **seulement pour une nouvelle série à trois chiffres** (0.0.6, 0.0.7…), pas pour les sous-versions (0.0.5.7…),
   déjà conservées sur GitHub (tags et Releases) : copie du dossier du jeu (sans .git/ ni .godot/, le cache se recrée)
   dans « ..\Archives OrbMeka\orb-meka X.Y.Z » (dossier Godot, à côté d'orb-meka). Ne jamais écraser une archive existante.

gh CLI : "C:\Program Files\GitHub CLI\gh.exe" (connecté en Oshidori99).

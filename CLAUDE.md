# OrbMeka — règles pour Claude

Jeu de construction et d'exploration, Godot 4.7.2 / GDScript (pas de C# : il empêcherait l'export Web).
Personnages, arbres et plantes 3D faits dans Blender (assets/), sons en partie CC0 ; assets externes seulement sous licence vérifiée, notée dans README.md.
Guide complet : docs/README.md. Fichiers techniques : docs/ORGANISATION.txt. Historique de toutes les versions : docs/HISTORIQUE.txt.
Suivi du travail : GitHub Project https://github.com/users/Oshidori99/projects/10 (une milestone par série, issues détaillées).

## Communication
- Répondre en français, de façon **très synthétique**.
- L'utilisateur n'est pas expert Git : expliquer les étapes simplement.

## Juridique (prioritaire)
- Signaler **immédiatement** tout risque à l'utilisateur : droit suisse/UE, autres jeux et éditeurs (surtout le jeu de blocs le plus connu), licences, données personnelles.
- Ne rien reprendre d'un autre jeu (code, assets, noms, éléments emblématiques, interface identique) ; proposer une alternative originale. Ne jamais citer un autre jeu dans le dépôt (il est public).
- Voir « Cadre juridique » dans README.md.

## Règles de l'utilisateur pour le jeu
- Jamais tuer d'animaux ni de robots ; rien de gore. Les robots (Meka) sont des amis.
- Tout doit rester original : mécaniques, interface et noms propres à OrbMeka.
- Qualité d'abord : sur PC, 5 à 5,5 Go de mémoire au plus (environ 3 Go aujourd'hui, acceptable) ; enlever seulement le gaspillage. Sur le Web, réglages plus légers.

## Structure
- scenes/ : main.tscn (menus), world.tscn (partie). scripts/ : code. tests/ : tests sans fenêtre.
- Garder les .gd.uid avec leurs scripts. Ne pas toucher à .godot/ (cache) ni au contenu existant des archives (dossier voisin « ..\Archives OrbMeka », hors du dépôt) ; on y ajoute seulement l'archive de chaque **nouvelle série** (0.0.x).
- Données joueur dans user://, jamais dans les sources :
  - réglages dans user://parametres/ : parametres-generaux.json, video.json, controles.json, personnage.json, attributs.json, menus.json ;
  - mondes : worlds.json (index) et un dossier par monde mondes/<nom du monde>/ : monde.json (nom, **graine**, mode, génération),
    objets.json (rochers, cailloux cassés, objets au sol), joueur.json (position, regard, inventaire), zones/zone_X_Y_Z.bin (seulement les changements, format versionné),
    eau/ (lacs.json et cases.json, seulement si l'eau a bougé) ;
  - mondes en sécurité (scripts/world_shelves.gd) : mondes-securises.json + mondes-securises/, mondes-versions.json
    + mondes-versions/ (jamais lus par les anciennes versions) ; sous-dossiers et exceptions dans mondes-dossiers.json ;
  - launcher : launcher/.

## Le monde aujourd'hui
- Terrain lisse sculptable (scripts/smooth_terrain.gd) : zones de 8 × 8 × 8 m (scripts/world_zones.gd) ; chaque bloc de 1 m est
  divisé en 2 × 2 × 2 = 8 sous-cellules de 50 cm (1/8 du bloc) ; une zone = 16 × 16 × 16 sous-cellules. Sauvegarde de l'état
  des zones modifiées point par point (pas geste par geste).
- Génération par graine, numérotée (scripts/world_generation.gd, VERSION, aujourd'hui 32). **Une génération qui change = un nouveau
  numéro** : les mondes existants ne changent jamais. Le détail de chaque version est dans docs/HISTORIQUE.txt et en commentaire dans le code.
- Monde de 96 × 96 zones (768 m, Generation.half_zones) ; sous-sol : 5 m de terre, 20 m de pierre, 20 m de pierre sombre, puis la
  « Roche-mère » incassable à 45 m (ne pas reprendre le nom anglais courant d'un autre jeu).
- Lointain simplifié (scripts/far_terrain.gd), eau qui coule (scripts/water.gd), arbres (scripts/trees.gd), plantes (scripts/plants.gd),
  rochers et cailloux (scripts/rocks.gd).
- Règles : même graine = même monde ; mondes légers (seulement les changements, compressés) ; mesurer les performances sur PC et sur le Web.
- Pour plus tard (gravité réaliste) : sable qui glisse au-delà d'environ 34° et ne tient jamais en plafond ; terre aux pentes raides et
  petit plafond d'environ 1 m au plus ; pierre qui ne tombe pas ; poutres pour soutenir la terre.

## Ordre des séries
0.0.7 — Inventaire (porter, ramasser, modes Créatif et Survie), 0.0.8 — Fabrication et survie (bâtons, fibres,
fabrication à la main, outils, vie, nuit), 0.0.9 — Animaux, 0.1 — Enfin un jeu (commencement), 0.1.1 — Paramètres 3.
Le contenu de chaque série est dans sa milestone GitHub. Dans une même 0.x, chaque thème n'a qu'une seule série.

## Tests
Depuis PowerShell, à la racine du projet, en parallèle (6 à la fois, moins si le PC est chargé) :

    .\tests\run_all.ps1 -Only fly,controls   # versions non publiées : seulement les tests de ce qui a changé
    .\tests\run_all.ps1                      # tous : seulement sur demande (à la publication, l'Action Dev les lance sur GitHub)

Les tests juridiques (licences, aucun autre jeu cité) passent **toujours**, même avec -Only.
**Sécurité du PC** (planté le 24.10.2026, mémoire à 99 %) : run_all.ps1 ne lance plus de test au-delà de 85 % de mémoire,
arrête tout au-delà de 90 % et coupe un test qui dépasse 2 Go. 6 tests à la fois par défaut, réduits à 3 au-delà
de 75 % de mémoire ou de 85 % de processeur (jamais d'arrêt à cause du processeur). Ne jamais lancer de tests depuis deux sessions à la fois ;
utiliser -Jobs 2 si le PC est en mode économie d'énergie ou si d'autres gros programmes tournent (Blender, éditeur Godot).
Godot console : C:\Users\Dev\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe
Un seul test : `& '<Godot console>' --headless --path . --script res://tests/<nom>_test.gd`.
Ce qui ne peut être vérifié qu'en jouant (aspect, souris) est signalé comme « à tester manuellement ».

## Rythme de publication
Publier une version sur 4, ou dès que l'utilisateur dit « publie », puis remettre le compteur à zéro.
Chaque version locale est une vraie version (X.Y.Z.1, X.Y.Z.2…) : « Nouvelle version » étapes 1 à 3, puis commit local
sur `dev` titré « X.Y.Z — Titre ». Seul ce qui est lourd attend la publication : push, fusion dans main, tag,
Action, Project (étapes 4 et 5). La version publiée est donc la dernière version locale.
Pas de tous les tests en local avant de publier : l'Action Dev les lance après l'envoi ; s'ils échouent, corriger aussitôt.
Entre-temps : sans push (chaque push lance l'Action et met à jour la page d'essais) ; tests de ce qui a changé seulement.
Toujours fermer les issues terminées (avec la version qui les a faites) et les passer en Done dans le Project.

## Branches et builds
- `dev` : travail en cours. `main` : seulement les versions validées.
- Un tag `vX.Y.Z` lance .github/workflows/build.yml : exports Windows et Web (export_presets.cfg),
  Release GitHub (OrbMeka-X.Y.Z-windows.zip, OrbMeka-X.Y.Z-web.zip), puis itch.io si les secrets
  BUTLER_API_KEY et ITCH_TARGET existent. Reconstruire un ancien tag : Actions > Build > Run workflow.
- Ne jamais lire, afficher ni demander la clé itch.io : l'utilisateur la met lui-même dans les Secrets.

## Travail depuis le cloud (téléphone)
L'utilisateur peut lancer Claude Code dans le cloud depuis son téléphone, sur le dépôt GitHub Oshidori99/OrbMeka.
- Travailler **sur `dev`** (commit + push). Chaque push sur dev lance .github/workflows/dev.yml :
  tous les tests Godot sans fenêtre, puis, s'ils passent, la version Web sur la page d'essais privée (secret ITCH_TARGET_DEV).
  La page principale (ITCH_TARGET) ne reçoit que les versions avec un tag.
- Après chaque push : attendre le résultat de l'Action « Dev ». Si les tests échouent, corriger avant toute autre chose.
- Sur téléphone, l'utilisateur ne peut tester que menus et affichage (pas de commandes tactiles) : le rappeler pour le gameplay.
- **« Envoie dans main »** (dit explicitement par l'utilisateur, Action Dev verte) : suivre « Nouvelle version » étapes 1 à 5.
  Le Project (étape 4) et l'archive d'une nouvelle série (étape 6) se font si possible, sinon les noter dans docs/README.md « À faire sur PC ».
- Godot local, les archives et les chemins C:\… n'existent pas dans le cloud. De retour sur le PC : `git pull`,
  rattraper ce qui est noté « À faire sur PC », puis supprimer la note.

## Nouvelle version
0. Travailler et committer sur `dev`.
1. Numéro dans project.godot (config/version) et en tête de docs/README.md et README.md.
   Mettre à jour la vitrine de l'accueil (section VITRINE de scripts/menu_showcase.gd).
2. Entrée en haut de docs/HISTORIQUE.txt : « X.Y.Z — Titre » + 1 à 2 lignes courtes.
3. Section dans docs/README.md : ce qui change, tests réussis, ce qui reste à tester.
4. Item dans le GitHub Project (Done une fois fini).
5. Commit sur `dev`, puis fusionner dans `main` (`git checkout main`, `git merge dev`),
   créer le tag (`git tag vX.Y.Z`), pousser (`git push origin main dev vX.Y.Z`), revenir sur `dev`.
   Vérifier que l'Action Build est verte et que la Release existe.
6. Archive, **seulement pour une nouvelle série à trois chiffres** (0.0.7, 0.0.8…), pas pour les sous-versions :
   copie du dossier du jeu (sans .git/ ni .godot/) dans « ..\Archives OrbMeka\orb-meka X.Y.Z ». Ne jamais écraser une archive existante.

gh CLI : "C:\Program Files\GitHub CLI\gh.exe" (connecté en Oshidori99).

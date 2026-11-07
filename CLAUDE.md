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
  - mondes : worlds.json (index) et un dossier par monde mondes/<nom du monde>/ (0.0.5.20 ; nom nettoyé, identifiant
    pour les mondes non migrés) : monde.json (nom, **graine**, mode, génération), objets.json (rochers),
    joueur.json (position, regard), zones/zone_X_Y_Z.bin (seulement les changements, format versionné) ;
  - mondes en sécurité (0.0.6, scripts/world_shelves.gd) : mondes-securises.json + mondes-securises/, mondes-versions.json
    + mondes-versions/ (jamais lus par les anciennes versions) ; sous-dossiers et exceptions dans mondes-dossiers.json ;
  - launcher : launcher/.

## Tests
Depuis PowerShell, à la racine du projet, en parallèle (4 à la fois) :

    .\tests\run_all.ps1 -Only fly,controls   # versions non publiées : seulement les tests de ce qui a changé
    .\tests\run_all.ps1                      # tous : avant une publication ou sur demande (l'Action Dev les relance à chaque envoi)

Les tests juridiques (licences, aucun autre jeu cité) passent **toujours**, même avec -Only.
**Sécurité du PC** (planté le 24.10.2026, mémoire à 99 %) : run_all.ps1 ne lance plus de test au-delà de 85 % de mémoire,
arrête tout au-delà de 90 % et coupe un test qui dépasse 3 Go. Ne jamais lancer de tests depuis deux sessions à la fois ;
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
   (0.0.5.12 : couches faites, 4 m de terre, 4 m de pierre, Roche-mère à 8 m ; 0.0.5.14 : petites collines
   de terre selon la graine ; 0.0.5.15 : collines 3 m, bosses, crêtes et trous (1 zone sur 9), petits déserts
   (1 sur 8) et grands (1 sur 12, 3 ou 4 zones) ; 0.0.5.16 : mondes personnalisés (chances par zone) ;
   0.0.5.17 : génération version 2 enregistrée avec chaque nouveau monde (relief moins plat, déserts plus rares),
   distance d'affichage horizontale ; 0.0.5.18 : version 3, monde 20 × 20 zones, déserts 12 % (1, 3-4, 6-7 zones),
   3-4 trous énormes pour 256 zones ; rochers en essai (scripts/rocks.gd, 7 tailles × 7 formes) ; 0.0.5.19 : version 4,
   rochers au hasard (minés à la pioche, objets.json) et petits lacs à l'eau calme ; 0.0.5.20 : version 5, monde
   48 × 48 zones, lacs 1 × 2 zones, boue (lacs) et argile (sous les lacs, en poches) ; 0.0.5.21 : version 6,
   lacs de 2 et 4 zones irréguliers, bandes de 4-5 m (argile grise, boue, herbe), régions de boue, grands déserts
   seulement (7-9 zones, 8 %) ; 0.0.5.23 : version 7, montagnes 20-32 m à cœur de pierre (7 %), lacs 2-3 / 10 / 16 zones,
   déserts 14-20 zones (9-10 %), hauteur max 40 m ; 0.0.5.24 : version 8, montagnes 9 %, gravissables sauf 20-25 % raides ; 0.0.5.26 : version 9, 5 m de terre, 10 m de pierre, 10 m de pierre sombre, Roche-mère à 25 m ; 0.0.5.32 : version 10, trous de boue ; 0.0.5.33 : version 11, 6 grands déserts (10 %), montagnes de sable, boue dans un trou sur 3 ; 0.0.5.34 : version 12, lacs sur des replats des montagnes, moins de trous ; 0.0.5.35 : version 13, lacs doublés, chaînes de montagnes ; version 14, grottes (entrées 6 %, vide 12 %), crevasses en éclair ; rivières à faire)
   Niveaux de détail (#128) : commencés en 0.0.5.22 (scripts/far_terrain.gd, relief simplifié par carrés de 4 × 4 zones ; 2 m près, 4 m puis 8 m loin, relevés gardés et étalés sur les images en 0.0.5.25).
   (ne pas reprendre le nom anglais courant d'un autre jeu).
5. Suite : voir « Série 0.0.6 — Monde 2 » plus bas. Grottes faites en 0.0.5.37 (génération version 14, crevasses comprises) ;
   sous-sol actuel : 5 m de terre, 10 m de pierre, 10 m de pierre sombre, puis la Roche-mère à 25 m.
   Note pour plus tard (gravité réaliste, demandée par l'utilisateur ; 0.0.5.11 n'en fait qu'une première version) :
   sable : glisse au-delà d'environ 34° et ne tient jamais en plafond ; terre : pentes raides possibles
   et petit plafond d'environ 1 m au plus, au-delà elle s'effondre ; pierre : ne tombe pas. Plus tard,
   des poutres pourront soutenir la terre. Pierre : cassée à la pioche depuis 0.0.5.13 (animation simple, à améliorer).
Règles : même graine = même monde ; mondes légers (seulement les changements, compressés) ;
mesurer les performances sur PC et sur le Web à chaque étape.

## Série 0.0.6 — Monde 2 (milestone du même nom)
Seulement le monde : arbres et fruitiers (#138), matières (#122), minerais (#134), lave (#137), lacs (#131),
eau et rivières (#124), dunes (#125), taille du monde (#135), structures (#123).
Pas d'inventaire, de récolte ni de modes créatif/survie (#73) sans demande de l'utilisateur.
Une génération qui change = un nouveau numéro de version : les mondes existants ne changent jamais.
Taille du monde : génération version 15, 64 × 64 zones (512 m) ; les versions d'avant restent à 48 × 48 (Generation.half_zones).
Génération version 16 : neige sur 1 montagne sur 4 (SNOW), gravier au pied des montagnes et sur 1 rive de lac sur 3 (GRAVEL) ; UV2 du terrain = neige, gravier.
Génération version 17 : lacs de montagne jamais collés (plus d'eau en l'air), cailloux (rocks.gd PEBBLE_SIZES, 8 à 60 cm ; smooth_terrain.gd pebbles_in_zone ; cassés : objets.json cailloux_casses).
Génération version 18 : calcaire (LIMESTONE), charbon (COAL), silex (FLINT) dans la pierre (smooth_terrain.gd _ores_of, une liste de formes par zone) ; CUSTOM0 du terrain = calcaire, charbon, silex ; rock_kind 1 (calcaire) et 2 (silex) pour rochers et cailloux.

## Rythme de publication
Publier une version sur 4, ou dès que l'utilisateur dit « publie », puis remettre le compteur à zéro.
Chaque version locale est une vraie version (demande de l'utilisateur, 07.11.2026) : après 0.0.6.1, les suivantes sont
0.0.6.2, 0.0.6.3… Pour chacune : « Nouvelle version » étapes 1 à 3 (numéro, vitrine, historique, README), puis commit local
sur `dev` titré « X.Y.Z — Titre ». Seul ce qui est lourd attend la publication : tous les tests, push, fusion dans main, tag,
Action, Project (étapes 4 et 5). La version publiée est donc la dernière version locale (ex. 0.0.6.5).
Entre-temps : sans push (chaque push lance l'Action et met à jour la page d'essais) ; tests de ce qui a changé seulement.

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
  Cette page montre donc la dernière version envoyée, même non validée. La page principale (ITCH_TARGET) ne reçoit que les versions avec un tag.
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

# OrbMeka™ 0.0.5.11

Dans Godot, ouvrez **project.godot**, puis **F5** pour lancer le jeu.

0.0.5.11 : gravité de la terre et du sable (chute, talus, petites piles) ; plus de page Comment jouer.
0.0.5.10 : touches du pinceau, de la taille et de F1 à F4 modifiables ; aplanir et lisser sans ajouter de matière ; terre posée sur la plage.
0.0.5.9 : pinceaux du clic droit (B + T : poser, aplanir, lisser), sable ou terre, taille 1/8, 1/4, 1/2 bloc (B + molette).
0.0.5.8 : terrain lisse (1re étape) : clic gauche creuse, clic droit ajoute 50 cm ; Web plus lumineux ; réglages Jeu en tête de Vidéo.
0.0.5.7 : herbe haute (environ 40 cm, deux fois plus de brins) et sol vert plus clair, aussi sur le Web.
0.0.5.5 : monde tout plat, sans bloc au départ ; plage de sable réaliste (grains, rides de vent) près de l'apparition.
0.0.5.4 : gazon dense, brins de 3 à 7 cm balancés par le vent ; Densité de l'herbe dans Vidéo ; FPS plus visibles.
0.0.5.3 : FPS discrets en jeu ; date et heure de création dans Informations du monde (pause/F3).
Une date absente reste inconnue. L'exploration visuelle de la 0.0.5.2 est conservée.

- [Guide détaillé et commandes](docs/README.md)
- [Organisation et fichiers techniques](docs/ORGANISATION.txt)
- [Historique des versions](docs/HISTORIQUE.txt)

Scènes : scenes/ · Scripts : scripts/ · Tests : tests/ · Documentation : docs/.
Les mondes personnels restent dans les données Godot user:// : un dossier par monde, mondes/<id>/,
avec monde.json (qui contient la graine), joueur.json et zones/ (seulement les changements).
Depuis 0.0.5, blocs posés et cassés, position et regard sont sauvegardés ; depuis 0.0.5.1,
les changements sont compressés par zone dans zones/zone_X_Y_Z.bin.

## Prochaines étapes (Monde)
0.0.5.2 : première passe visuelle originale sur l'herbe et la terre (matières procédurales et touffes).
Le relief reste anguleux. Casse, pose et pinceaux sont désactivés pendant cette étape ;
exploration, pause et anciennes constructions restent disponibles.

Zones (fait) → terrain lisse sculptable (en cours) → relief et sous-sol (avec la Roche-mère) → matières → structures
→ modes Créatif et Survie → inventaire → eau réaliste. Détail : CLAUDE.md et le GitHub Project.

Terrain lisse (première version en 0.0.5.8 : creuser et ajouter 50 cm par clic) : zones de **8 × 8 × 8 m**.
Chaque bloc de 1 m de côté est partagé en **2 × 2 × 2 = 8 sous-cellules au total**, de **50 cm de côté**
et de **1/8 du volume** chacune. Une zone contient **16 × 16 × 16 sous-cellules** ;
une grille de sommets avec les bords compterait **17 sommets par axe**.

## Cadre juridique
Objectif : aucun risque juridique, ni en droit suisse ou européen, ni vis-à-vis d'autres jeux ou éditeurs.
- Rien copié d'un autre jeu : ni code, textures, sons, noms, logos, blocs/créatures emblématiques ni interface identique.
- Aucun nom d'autre jeu dans le nom, la description ou la promotion, et pas de comparaison commerciale.
- Assets externes uniquement avec une licence vérifiée et notée ici.
  - Sons d'animaux (0.0.4.13), CC0 1.0 : « Meow » (IgnasD, OpenGameArt), « Kitten Mew »
    (AntumDeluge, OpenGameArt), « Bunny hutch » n° 1376 (Joseph Sardin, BigSoundBank).
    Détails : assets/sounds/CREDITS.txt.
  - Polices de secours de la version Web (0.0.4.17) : DejaVu Sans (licence Bitstream Vera / Arev,
    libre) et Noto Emoji (SIL Open Font License 1.1) ; textes dans assets/fonts/ et LICENCES.txt.
- Godot Engine (licence MIT) et ses composants : mentions dans Paramètres → Licences et dans
  LICENCES.txt (docs/LICENCES.txt), livré à côté du jeu dans chaque zip et sur itch.io (0.0.4.17).
- Nom « OrbMeka » : aucune marque trouvée dans TMview (UE, Suisse et autres offices, 24.10.2026) ;
  pas un registre officiel, à revérifier avant un lancement public. ™ permis, ® seulement si déposée.
- Licence du dépôt : tous droits réservés (fichier LICENSE) ; lire le code et jouer est permis, pas le
  copier ni le réutiliser. Les éléments de tiers gardent leur licence.
- Données personnelles : aucune collecte sans nécessité (protection des données suisse / RGPD).

# OrbMeka™ 0.0.6.25

Jeu de construction et d'exploration en 3D, fait avec Godot 4.7.2 (GDScript).
Monde au terrain lisse qu'on peut creuser et sculpter, généré à partir d'une graine.

## Jouer
- **Windows** : télécharger le zip de la dernière version dans les [Releases](../../releases), puis lancer OrbMeka.exe.
- **Navigateur** : version Web sur itch.io.

## Ce que contient le jeu (0.0.6.25)
- **Monde** de 96 × 96 zones (768 m de côté), découpé en zones de 8 m chargées autour du joueur ;
  même graine = même monde.
- **Terrain lisse** : creuser, ajouter, aplanir et lisser au pinceau, par morceaux de 50 cm ;
  pioche pour la pierre ; terre et sable tombent s'ils n'ont pas de support.
- **Relief** : plaines, collines, montagnes enneigées, déserts, lacs, rivières, grottes et crevasses.
- **Sous-sol** : terre, pierre, pierre sombre, puis la Roche-mère incassable à 45 m ;
  calcaire, charbon et silex ; cailloux et rochers en surface.
- **Eau** : lacs et rivières ; l'eau coule quand on creuse à côté ; on peut nager.
- **Végétation** : herbe, forêts de pins et de tilleuls, pommiers, noisetiers, plantes à fibres et lianes.
- **Personnages** : enfants, adultes et animaux (chats, renard, écureuil, tortue, lapin bleu), trois couleurs de peau.
- **Déplacements** : marcher, courir (plusieurs vitesses), se baisser, sauter, voler, trois vues.
- **Menus** : mondes enregistrés et sécurisés, paramètres (vidéo, son, contrôles à deux touches, attributs), launcher Windows.

Pas encore d'inventaire, de récolte ni de modes Créatif et Survie : ils arrivent en 0.0.7.

## Suite prévue
- **0.0.7 — Gameplay et inventaire** : récolte, fabrication (Simple, Classique, Réaliste), outils en pierre,
  Créatif et Survie, vie, jour et nuit.
- **0.0.8 — Animaux**, puis **0.1 — Enfin un jeu**, puis **0.1.1 — Paramètres 3**.
- Plus tard : climat et météo, monde vivant (animaux qui construisent), métaux, cultures.

Détails et suivi : [GitHub Project](https://github.com/users/Oshidori99/projects/10).

## Historique
Toutes les versions et leurs nouveautés : [historique des versions](docs/HISTORIQUE.txt).
Les mondes sont sauvegardés sur l'appareil du joueur, avec seulement les changements par rapport à la graine.

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
  Le jeu n'envoie aucune donnée ; le launcher Windows lit seulement la liste des versions sur GitHub (adresse IP visible par GitHub, comme toute visite). Sauvegardes : sur l'appareil du joueur.

# OrbMeka™ 0.0.8.34

Jeu de construction et d'exploration en 3D, fait avec Godot 4.7.2 (GDScript).
Monde au terrain lisse qu'on peut creuser et sculpter, généré à partir d'une graine.

## Jouer
- **Windows** : télécharger le zip de la dernière version dans les [Releases](../../releases), puis lancer OrbMeka.exe.
- **Navigateur** : version Web sur itch.io.

## Ce que contient le jeu (0.0.8.19)
- **Monde** de 96 × 96 zones (768 m de côté), découpé en zones de 8 m chargées autour du joueur ;
  même graine = même monde ; calculé sur plusieurs cœurs (PC et Web).
- **Terrain lisse** : creuser, poser, aplanir et lisser, par morceaux de 50 cm ; terre et sable tombent s'ils
  n'ont pas de support.
- **Relief** : plaines, collines, montagnes enneigées, déserts, lacs, rivières, grottes et crevasses.
- **Sous-sol** : terre, pierre, pierre sombre, puis la Roche-mère incassable à 45 m ;
  calcaire, charbon et silex ; cailloux et rochers en surface.
- **Eau** : lacs et rivières ; l'eau coule quand on creuse à côté ; on peut nager.
- **Végétation** : herbe, forêts de pins et de tilleuls, pommiers, noisetiers, orties, lin, herbes longues et lianes.
- **Modes Créatif et Survie** : en Créatif, tout est illimité ; en Survie, deux mains et quatre poches (poids et
  volume), la vie, manger des fruits, et une orbe de retour au point de départ.
- **Récolter** : ramasser cailloux, branches et fruits, couper et abattre les arbres, récolter des fibres et des
  lianes, arracher et replanter les plantes, prendre de la terre, du sable ou une motte de gazon.
- **Fabriquer à la main** (O + F) : tresser une ficelle, tailler une pierre (tête de hache ou de pioche, éclat
  tranchant), fendre une branche, assembler, ficeler : une hache et une pioche en pierre, qui s'usent ; chaque outil
  a sa fiche de fabrication, avec des conseils.
- **Carnet de route** (O + C) : les commandes, ce qu'on récupère et ce qu'on fabrique, du plus facile au plus
  difficile, coché au fur et à mesure.
- **Mains animées** : elles serrent ce qu'elles tiennent, creusent, attrapent, mangent, fabriquent.
- **Personnages** : enfants, adultes et animaux (chats, renard, écureuil, tortue, lapin bleu), trois couleurs de peau.
- **Déplacements** : marcher, courir (plusieurs vitesses), se baisser, sauter, voler, nager, trois vues.
- **Menus** : mondes enregistrés et sécurisés, paramètres (qualité d'affichage, ombres, son, contrôles
  modifiables), launcher Windows.

## Suite prévue
- **0.0.8 — Fabrication et survie** (en cours) : sac en filet, jour et nuit, torche, bras des personnages animés.
- **0.0.9 — Animaux**, puis **0.1 — Enfin un jeu**, puis **0.1.1 — Paramètres 3**.
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

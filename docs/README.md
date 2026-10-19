# OrbMeka™ — prototype 0.0.2.11.3

Godot 4.7 / GDScript. Formes et couleurs simples, sans assets externes.

## Lancer et choisir un monde
1. Dans Godot, arrêtez l'ancienne partie si nécessaire, puis appuyez sur **F5**.
2. L'accueil affiche **Jouer**, **Paramètres**, **Informations**, dans cet ordre.
   Jouer ouvre Mes mondes. Paramètres ouvre Attributs : Saut et Blocs.
   Informations explique la génération des mondes, sans désigner de monde particulier.
3. Choisissez **Créer un monde**, saisissez son nom et, si souhaité, une graine, puis **Créer**.
   La création ouvre directement la partie.
4. Pour un monde existant, sélectionnez son nom puis **Ouvrir**.
   Un double-clic ou Entrée sur la liste permet aussi de l'ouvrir.
   **Renommer** modifie uniquement le nom, en conservant identité et graine.
   **Supprimer** demande confirmation avec le nom du monde ; **Annuler**
   est sélectionné par défaut. Seules les métadonnées du monde choisi sont retirées.
5. Le monde se lance avec la souris directement capturée. **Échap** ouvre la pause et la libère.
6. Pour quitter la partie : **F1**, ou Échap puis **Retour aux mondes** dans la pause.
   **F8** arrête une partie lancée par l'éditeur.

Les menus acceptent Tab / Maj+Tab, flèches, Entrée et Espace selon le contrôle
sélectionné. Échap revient du formulaire à la liste, puis de la liste à l'accueil.
La souris reste libre dans les menus ; lancer un monde la capture automatiquement.
Le clic qui capture la souris ne casse ni ne pose de bloc.

## Mondes conservés, constructions réinitialisées
Chaque nouveau monde reçoit la graine saisie à la création, ou une graine aléatoire si le champ est vide.
**Seuls son identifiant, son nom et sa graine sont conservés après fermeture.**
La liste est enregistrée localement dans le dossier de données Godot du jeu,
fichier **user://worlds.json**. La graine est facultative à la création ; aucun autre réglage n'est proposé.

Réouvrir un monde utilise sa graine enregistrée et recrée son terrain initial.
**Les blocs posés ou cassés et la position du joueur ne sont pas sauvegardés**,
y compris lors d'un simple retour à la liste.

Le nom est obligatoire, limité à 48 caractères. Les espaces aux extrémités
sont retirés et un doublon de nom est refusé, sans distinction de majuscules.
Un problème de lecture ou d'enregistrement est affiché ; un fichier de liste
illisible est conservé sans être remplacé par une liste vide.

## Terrain
Chaque graine produit **3 ou 4 petites collines de terre brune**,
jusqu'à **3 blocs de hauteur**, dans une zone finie de 41 × 41 cellules.
Deux mondes aux graines différentes varient par le nombre et le profil des collines.
Le terrain reste reproductible pour une même graine dans cette version.

La base plate de 128 × 128 mètres est protégée. Les collines sont cassables.
L'aire de départ reste dégagée et les 74 blocs de démonstration en sable et pierre
sont conservés. L'apparition tient compte des blocs présents.

## Commandes en partie
- ZQSD / WASD / flèches : marcher ; souris : regarder.
- Espace : sauter, un appui par saut.
- Clic gauche : casse immédiate ; maintenir pour répéter selon les paramètres (**300 ms par défaut**).
- Clic droit : pose immédiate ; maintenir pour répéter selon les paramètres (**300 ms par défaut**).
- 1 : sable beige ; 2 : pierre grise ; 3 : terre brune ; molette : parcourir les blocs.
- Échap : ouvrir la pause et libérer la souris ; Reprendre ou Échap depuis la pause rend directement le contrôle du jeu.
- F1 : retourner à la liste des mondes.
- F2 : Comment jouer ; F3 : Informations du monde (ouvrent la pause).

Les répétitions s'arrêtent au relâchement, à Échap, à la pause et à la perte
de focus. Elles ne reprennent pas sans nouvel appui et ne rattrapent pas un
ralentissement par une rafale. Le sable reste immobile sans support.

Saut par défaut : hauteur cible de 2,52 m, vitesse initiale de 8,4 m/s,
gravité de descente de 14 m/s² ; environ 1,217 seconde en l'air à 60 Hz.
Tolérance de 100 ms après un bord et mémoire de 120 ms avant l'atterrissage,
sans double saut ni saut automatique au maintien.

## Limites
Portée de 5 mètres, aucune pose dans le personnage ou dans une cellule occupée.
Stock illimité, maximum 1200 blocs présents, terrain inclus.
**Hauteur maximale : 25 blocs au-dessus du sol plat, collines comprises.**
L'écran Pause → Comment jouer rappelle cette limite.
Pas de textures, plein écran, terrain lisse, biomes, machines, multijoueur
ou génération infinie dans cette version.

## Organisation
- scenes/main.tscn / scripts/app.gd : accueil, navigation, liste, création, retour de partie.
- scripts/world_catalog.gd : noms/graines et enregistrement local des métadonnées.
- scenes/world.tscn / scripts/world.gd : scène de jeu, blocs, base, ciel, aide et interactions.
- scripts/terrain_generator.gd : profils et cellules déterministes, séparés de l'affichage.
- scripts/player.gd : caméra, déplacements, collisions et commandes.
- scripts/action_timing.gd : délais de casse/pose et tolérances de saut.
- tests/ : tests sans fenêtre, sans injection d'entrée système.
- project.godot.before-prototype : configuration originale préservée.

Les objets 3D sont construits au lancement : world.tscn semble vide dans l'éditeur.
Pour le parcours complet, F5 lance scenes/main.tscn.

## Vérifications précédentes — 0.0.2, 19 octobre 2026
Godot 4.7.2, exclusivement sans fenêtre : **190 vérifications réussies** :
- 32 menus/catalogue : accueil à un seul bouton, navigation, focus clavier,
  formulaire à un seul champ, noms invalides et doublons, graines attribuées,
  lecture/écriture de métadonnées, fichier invalide préservé, retour de partie,
  graine identique à la réouverture, constructions réinitialisées et 3/4 collines.
- 71 terrain et interactions : apparition, collisions, matières, casse/pose,
  base protégée, portée, capacité de monter, doublons et hauteur de 25 blocs.
- 48 temporalité de pose et saut : délais, interruptions, tolérances et absence de répétition.
- 33 casse répétée : cadence, interruptions, portée et protection du sol.
- 6 trajectoire de saut : durée, hauteur et montée sur un bloc.

Un test supplémentaire en **deux processus Godot successifs** confirme que
le nom et la graine sont relus après l'arrêt du premier processus.
Les tests utilisent leurs propres fichiers temporaires dans .godot/ et ne
créent ni ne remplacent les mondes personnels.

Aucun contrôle du PC ni capture du pointeur utilisé. L'apparence des menus,
la lisibilité aux différentes tailles et le confort au clavier/souris restent
à essayer manuellement ; les tests déclenchent les signaux des contrôles
et les fonctions de déplacement sans interaction avec le PC.

Exemple de test depuis PowerShell dans le dossier du projet :

    & 'C:\Users\Dev\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --log-file (Join-Path (Get-Location) '.godot/menu-tests.log') --script res://tests/menu_test.gd

Même commande avec prototype_test.gd, action_timing_test.gd, breaking_test.gd
ou jump_profile_test.gd pour les autres suites. catalog_restart_test.gd se lance
d'abord avec les arguments finaux -- --write, puis une seconde fois sans eux.
## Ajustements 0.0.2.1
Pose répétée à 300 ms, comme la casse ; première action immédiate.
Les arrêts au relâchement, à Échap, à la pause et à la perte de focus sont conservés.

Renommer et Supprimer agissent sur la sélection de la liste. Le nom ne peut
être vide, dépasser 48 caractères ou reprendre le nom d'un autre monde.
Le renommage conserve l'identité et la graine. La confirmation de suppression
affiche le nom et reste liée à ce monde même si la sélection change ensuite.
Aucun fichier de terrain ou fichier hors du stockage des mondes n'est supprimé :
seule la liste de métadonnées est réenregistrée.

99 contrôles ciblés réussis sans fenêtre : 17 de gestion des mondes, 1 de
persistance dans un second processus, 48 de délais pose/saut et 33 de casse.
Annulation/confirmation, dernier monde supprimé, noms invalides, identité/graine
et rechargement sont vérifiés avec un catalogue de test distinct des données
personnelles. Les suites générales inchangées n'ont pas été relancées.
Affichage et confort des nouveaux boutons restent à vérifier manuellement.

Test de gestion : tests/world_management_test.gd, puis le même script dans un
second processus avec les arguments finaux -- --verify-restart.
## Informations d'interface — 0.0.2.2
Dans Mes mondes, les détails changent avec la sélection, sans alourdir les lignes :
- Monde : son nom.
- Base plate : largeur 128 × longueur 128 blocs.
- Zone de génération : largeur 41 × longueur 41 blocs.
- Construction : hauteur maximale 25 blocs au-dessus du sol plat.
- Collines : 3 ou 4, hauteur maximale 3 blocs.

Les trois dimensions utiles sont largeur, longueur et hauteur de construction ;
ce ne sont pas trois tailles de monde sélectionnables. La zone de génération
est la zone parcourue par le générateur, pas une surface entièrement remplie de collines.
Un bloc correspond à un mètre dans la scène actuelle.

La liste rappelle la conservation du nom et de la graine, la réinitialisation
des constructions et F1 pour revenir depuis la partie. Le formulaire de création
explique la graine automatique, les collines et le nom de 1 à 48 caractères.
Renommer précise que graine et terrain initial sont conservés.

L'aide en jeu nomme Sable/Pierre/Terre et leurs touches, la molette, la portée
de 5 blocs, la cadence de 0,3 seconde, la base protégée, les 1200 blocs maximum,
la hauteur de 25 blocs collines comprises, Échap, F1 et la réinitialisation.
Aucun nouveau réglage, menu ou changement de gameplay.

14 contrôles ciblés réussis sans fenêtre : paramètres et textes concordants,
détails mis à jour à la sélection, formulaire toujours limité au nom,
chargement sans erreur et panneau de liste contenu dans 1280 × 720
(dimensions calculées : 560 × 614 pixels). Pas de suite exhaustive relancée.
Le confort visuel réel et les autres tailles de fenêtre restent à vérifier
manuellement ; aucun contrôle du PC ni capture de souris.

Test ciblé : tests/interface_info_test.gd, avec la même commande sans fenêtre
que les autres tests et un fichier de journal dans .godot/.
## Pause et aide — 0.0.2.3
Le panneau permanent d'aide et de version a été retiré de la partie.
Le viseur, le bouton de retour existant et les messages ponctuels utiles restent.
Les détails des mondes dans la liste sont conservés.

Échap pendant la partie ouvre la pause et libère la souris. La physique,
les déplacements et les répétitions de casse/pose s'arrêtent complètement.
La pause contient Reprendre, Comment jouer et Retour aux mondes.
La version 0.0.2.3 est visible à l'accueil et dans cette pause.

Comment jouer regroupe commandes, matériaux et sélection, cadence de 300 ms,
portée de 5 blocs, capacité de 1200 blocs, base protégée, hauteur maximale de
25 blocs collines comprises, conservation des noms/graines et réinitialisation.
Il indique aussi le bloc actuellement choisi et le nombre de blocs présents.
L'aide peut défiler et propose Retour à la pause.

Échap dans Comment jouer revient uniquement à la pause.
Reprendre, ou Échap depuis la pause, reprend la même partie sans perdre les
constructions. La souris reste libre jusqu'à un nouveau clic dans le jeu ;
ce clic ne casse ni ne pose, et aucune répétition précédente ne redémarre.
F1 revient à la liste depuis la partie, la pause ou l'aide ; quitter le monde
réinitialise ses constructions comme avant.

39 contrôles ciblés pause/aide réussis sans fenêtre : versions aux deux
endroits, absence de l'ancien panneau, arrêt effectif de la physique et des
minuteries, maintien des blocs de session, reprise sans action résiduelle,
navigation Échap/boutons/F1 et présence des informations déplacées.
La pause tient dans le viewport 1280 × 720 selon les mesures de mise en page.
Aucune suite exhaustive relancée ; aucun contrôle du PC ni capture de pointeur.
Apparence, défilement et confort d'utilisation réels restent à vérifier manuellement.

Test ciblé : tests/pause_test.gd, avec la commande sans fenêtre décrite plus haut.
Précision Échap : l'accès à la pause fonctionne aussi lorsque la souris est déjà
libre. Échap dans la pause reprend ; Échap dans l'aide revient à la pause.
Trois cycles successifs sont vérifiés en envoyant les événements uniquement
au viewport Godot sans fenêtre : une transition par appui, répétition clavier
ignorée et aucune interaction résiduelle. La reprise laisse volontairement
la souris libre jusqu'au prochain clic de capture.
Les 14 contrôles d'informations d'interface passent également avec l'aide déplacée.
## Informations du monde — 0.0.2.4
Pause → Informations du monde ouvre un écran de lecture seule contenant :
- Nom et graine exacte du monde actuellement chargé.
- Nombre de collines réellement générées par cette graine : 3 ou 4.
- Hauteur maximale initiale des collines, mesurée sur les cellules générées.
- Zone de génération : largeur 41 × longueur 41 blocs.
- Base plate : largeur 128 × longueur 128 blocs.
- Hauteur maximale de construction : 25 blocs au-dessus du sol plat.

Ces données proviennent de l'instance du monde actif et de son générateur.
La hauteur initiale ne prétend pas décrire les collines après extraction de blocs.
La graine n'est pas éditable et la génération reste inchangée.

Le jeu et ses interactions restent arrêtés, souris libre, pendant cet écran.
Retour à la pause ou Échap ramène seulement à la pause. Échap depuis la pause
reprend la partie sans relancer une casse ou une pose maintenue.
F1 conserve le retour direct à la liste, y compris depuis les informations.

Comment jouer reste consacré aux commandes, matériaux et limites nécessaires
au jeu ; la règle des 25 blocs, collines comprises, reste dans l'aide.
Les détails des collines et la graine sont dans Informations du monde.
Les dimensions et détails existants de la liste des mondes sont conservés.
Version 0.0.2.4 à l'accueil et dans la pause.

67 contrôles ciblés sans fenêtre réussis : 28 pour le monde actif et 39 pour
la pause/aide/reprise. Cas couverts : graines produisant 3 et 4 collines,
graine entière 4294967295 affichée exactement, nom chargé, hauteur générée,
arrêt de la physique et des interactions, souris libre et navigation.
Pas de suite exhaustive relancée, ni contrôle du PC ou capture du pointeur.
L'apparence réelle de ce nouvel écran reste à confirmer manuellement.

Test ciblé : tests/world_info_test.gd ; régression de pause : tests/pause_test.gd.
## Raccourcis et bloc sélectionné — 0.0.2.5
F2 ouvre Comment jouer ; F3 ouvre Informations du monde. Ces raccourcis
fonctionnent pendant une partie, depuis la pause et entre les deux écrans.
Sans monde chargé, ils sont inactifs. Les répétitions clavier sont ignorées.

Depuis la partie, ils mettent réellement en pause la physique et les
interactions, puis libèrent la souris. Échap depuis un écran revient seulement
à la pause ; Échap depuis la pause reprend. F1 reste le retour à la liste.
Aucune casse/pose maintenue ne redémarre après fermeture d'un écran.

En haut à gauche de la partie, un texte discret affiche
« Bloc sélectionné : Sable », « Bloc sélectionné : Pierre » ou
« Bloc sélectionné : Terre ». Il s'actualise immédiatement après 1/2/3 ou
le cycle de la molette. Aucun panneau d'aide ni numéro de version n'est
réintroduit dans le jeu ; le viseur reste présent.

63 contrôles ciblés sans fenêtre réussis : 24 de raccourcis/sélection et
39 de pause/aide/reprise. Les touches sont envoyées uniquement au viewport
de test ; le cycle appelé par la molette est testé directement, sans entrée
souris système. Pas de suite exhaustive ni contrôle du PC, aucun pointeur capturé.
Lisibilité réelle de l'indicateur et confort des raccourcis restent à confirmer
manuellement. Test ajouté : tests/shortcuts_selection_test.gd.
## Textes — 0.0.2.5.1
Comment jouer ne présente plus les correspondances 1/2/3 avec les matériaux ;
« Molette : changer de bloc » est conservé. Les touches 1/2/3 restent actives.
L'indicateur de bloc sélectionné en jeu est inchangé.

Sous le rappel « Retour aux mondes (F1) », la même zone en haut à droite
affiche discrètement « F2 : Comment jouer » et « F3 : Informations du monde ».
Ces textes n'ajoutent ni bouton ni action et ne capturent pas les clics.
Aucun grand panneau d'aide réintroduit, aucune mécanique modifiée.
## Accueil et génération générale — 0.0.2.6
Accueil : Jouer, Paramètres, Informations.
Paramètres affiche seulement « Aucun paramètre disponible pour le moment »
et Retour. Aucun réglage ni plein écran n'a été ajouté.

Informations ouvre la section Génération des mondes : base plate de
128 × 128 blocs, zone de génération de 41 × 41 blocs, construction jusqu'à
25 blocs au-dessus du sol plat collines comprises, 3 ou 4 collines jusqu'à
3 blocs de hauteur, graine attribuée automatiquement, noms/graines conservés
et constructions non sauvegardées. Ces valeurs viennent des paramètres existants.
Aucun nom ni graine spécifique n'est affiché dans cet écran général.

Ces détails quittent Mes mondes, qui conserve noms, sélection et actions
Ouvrir, Créer un monde, Renommer, Supprimer et Retour, ainsi que les messages
de validation et d'erreur. L'écran Informations du monde en pause/F3 reste
distinct et conserve les données réelles du monde actuellement chargé.

Retour ou Échap depuis Paramètres/Informations ramène à l'accueil.
Ces écrans ne lancent pas de partie et ne capturent pas la souris.

24 contrôles ciblés sans fenêtre réussis : ordre des boutons, absence de
réglages inventés, navigation, valeurs générales, absence de nom/graine privée,
retrait des détails de la liste, maintien des actions et ouverture d'un monde,
informations spécifiques en pause. Écran général contenu dans 1280 × 720
selon les mesures de mise en page. Pas de suite exhaustive relancée.
Aucun contrôle du PC ou capture de pointeur. Apparence et confort réels
restent à confirmer manuellement. Test : tests/interface_info_test.gd.
## Organisation — 0.0.2.7
Les scènes sont regroupées dans scenes/ ; le guide détaillé est dans docs/.
Les scripts restent dans scripts/ et les tests dans tests/. Un README.md
court à la racine indique les documents. HISTORIQUE.txt reste accessible
à la racine. docs/ORGANISATION.txt explique les fichiers techniques.

Tous les chargements et la scène principale utilisent les nouveaux chemins.
Les fichiers .gd.uid sont conservés avec leurs scripts. Les paramètres,
l'icône et son import, le cache et les données user:// ne sont pas déplacés.
Aucun changement de gameplay ou d'interface, hors numéro 0.0.2.7.

Avant réorganisation, l'archive existante Archives/OrbMeka/orb-meka 0.0.2.6
(dans le dossier Godot parent) a été vérifiée : 45 fichiers hors cache identiques
au projet courant. Elle n'a pas été écrasée ou dupliquée.
Vérification de la réorganisation : références res:// contrôlées, import Godot
sans fenêtre réussi et 101 contrôles ciblés réussis (24 navigation/menus,
71 terrain/interactions, 6 trajectoire de saut). Identifiants .uid et fichiers
techniques comparés à l'archive et conservés. Pas de contrôle visuel ni de
capture du pointeur ; l'éditeur peut rescanner les fichiers avant F5.

## Historique et reprise directe — 0.0.2.8
L'accueil propose Historique des versions après Jouer, Paramètres et Informations.
L'écran lit HISTORIQUE.txt à chaque ouverture : aucune copie des notes dans
le code. Les versions vont de la plus récente en haut (0.0.2.8) à la première
en bas (0.0.1). Il défile à la molette ou au clavier après focus sur la zone
(Tab). Retour ou Échap ramène à l'accueil. Il suffit de mettre le fichier à jour
en ajoutant les prochaines versions en haut.

Le petit plugin d'éditeur addons/history_export/ inclut ce fichier texte dans
les exports : il ne modifie pas le jeu. Le jeu exporté lit la copie incluse
dans cet export ; il faut réexporter pour distribuer des notes modifiées.
Aucun accès Internet ou mise à jour distante n'est ajouté.

Reprendre, ou Échap depuis la pause, rend immédiatement le contrôle du jeu
et capture la souris sans clic supplémentaire. Échap pendant le jeu rouvre
toujours la pause et libère la souris. Échap dans l'aide ou les informations
du monde revient uniquement à la pause. Les blocs restent en place pendant
la pause ; les répétitions précédentes sont annulées à la reprise.
Un appui sur Espace pour activer Reprendre ne déclenche pas aussi un saut.
Le premier lancement d'un monde conserve son clic initial de capture.

22 contrôles ciblés réussis sans fenêtre : texte UTF-8 chargé depuis le fichier,
ordre des 14 versions (dont 0.0.2.5.1), relecture et retour en haut à l'ouverture,
défilement, navigation, versions, reprise par bouton/Échap répétée sans action
résiduelle, blocs conservés et protection contre le saut du bouton Reprendre.
Import de l'éditeur avec le plugin d'export réussi, sans erreur.
Aucun exécutable exporté n'a été construit. La capture réelle du pointeur et
le confort de reprise restent à essayer manuellement : le mode sans fenêtre
neutralise volontairement toute capture de souris. Aucun contrôle du PC utilisé.

Test ciblé : tests/history_resume_test.gd.
## Graines et actions des mondes — 0.0.2.9
Créer un monde propose maintenant un nom et une graine facultative.
Le champ vide conserve le fonctionnement aléatoire. Sinon, saisissez un entier
de 0 à 4294967295 ; un texte, une décimale ou une valeur hors limites est refusé
avec un message. La graine choisie est conservée et figure dans F3 en partie.
Deux mondes peuvent partager une graine et régénèrent alors le même terrain.

Le formulaire affiche en dessous le titre Options du monde, actuellement vide.
Aucun autre réglage ni mécanisme de génération n'est ajouté.

Mes mondes propose Dupliquer pour le monde sélectionné. La copie reçoit
la même graine, une identité indépendante et un nom disponible : « (copie) »,
puis « (copie 2) », etc. Elle apparaît sélectionnée dans la liste et ne lance
pas automatiquement la partie. Les noms longs sont ajustés à la limite existante.
Renommer ou supprimer une copie ne modifie pas son original.
Les constructions ne sont toujours pas sauvegardées ni dupliquées.

Paramètres du monde ouvre un écran associé au monde sélectionné, indiquant
qu'aucun paramètre n'est disponible pour le moment. Retour ou Échap revient
à la liste en conservant la sélection. Les boutons sont désactivés si aucun
monde n'est sélectionné. Les paramètres généraux de l'accueil restent inchangés.

58 vérifications ciblées sans fenêtre réussies : 26 graines/duplication/options
et 32 menus/catalogue existants. Vérifiés : bornes et erreurs de graine,
chargement de la graine saisie, persistance, identités distinctes avec même
terrain, copies successives et noms longs, indépendance de l'original,
navigation du nouvel écran et gabarits des formulaires/liste à 1280 × 720.
Les tests utilisent des catalogues temporaires, pas les mondes personnels.
Aucun contrôle du PC ni capture de pointeur. L'aspect réel et le confort
du nouveau formulaire restent à confirmer manuellement.

Test ajouté : tests/world_options_test.gd.
## Entrée directe et attributs — 0.0.2.10
Créer ou ouvrir un monde dans Mes mondes rend maintenant immédiatement
le contrôle du personnage et capture la souris : plus de clic supplémentaire.
Le clic de lancement ne casse ni ne pose. Échap ouvre toujours la pause et
libère la souris ; Reprendre ou Échap depuis la pause retourne directement au jeu.
Perdre le focus arrête les interactions et libère le pointeur.

Accueil → Paramètres ouvre Attributs, avec les sections Saut puis Blocs.
Chaque ligne présente sa valeur active, le défaut et les bornes, un champ
numérique et un bouton ↻ individuel. La virgule française est acceptée.
Un champ vide utilise son défaut lors d'Appliquer. Une valeur invalide donne
un message sans modifier les réglages actifs. ↻ prépare le défaut du seul champ ;
Appliquer enregistre les cinq valeurs. Retour/Échap abandonne les modifications
non appliquées. Les paramètres valent pour tous les mondes et sont conservés
dans user://settings.json, indépendamment de user://worlds.json.
Les données illisibles ou hors bornes sont remplacées par des défauts au chargement.

| Attribut | Défaut | Bornes |
| --- | --- | --- |
| Hauteur du saut | 2,52 m (= blocs) | 1,1 à 8 m |
| Vitesse de montée au départ | 8,4 m/s | 3 à 16 m/s |
| Gravité de descente | 14 m/s² | 4 à 40 m/s² |
| Pose maintenue | 300 ms | 100 à 2000 ms |
| Casse maintenue | 300 ms | 100 à 2000 ms |

La hauteur par défaut vient du saut précédent : 8,4² / (2 × 14) = 2,52 m.
Pour rendre les champs indépendants, la décélération de montée est calculée
à partir de la vitesse initiale et du sommet demandé ; la gravité de descente
ne s'applique qu'à la chute. La trajectoire est intégrée de part et d'autre
du sommet pour limiter l'écart entre hauteur saisie et hauteur obtenue.

Mesures à 60 Hz, avec les collisions réelles :

| Réglages hauteur / vitesse / descente | Sommet mesuré | Montée | Vol total |
| --- | --- | --- | --- |
| Avant 0.0.2.10 : impulsion 8,4, gravité 14 | 2,591 m | 0,600 s | 1,233 s |
| Défauts : 2,52 / 8,4 / 14 | 2,521 m | 0,600 s | 1,217 s |
| Montée plus rapide : 2,52 / 12 / 14 | 2,521 m | 0,417 s | 1,033 s |
| Descente plus rapide : 2,52 / 8,4 / 28 | 2,520 m | 0,600 s | 1,033 s |
| Saut plus haut : 4 / 8,4 / 14 | 4,001 m | 0,950 s | 1,717 s |

Les valeurs par défaut conservent donc le ressenti au plus près, en corrigeant
le petit dépassement de hauteur du calcul précédent. Les tolérances de 100/120 ms,
l'absence de double saut ou de rebond au maintien et la montée sur un bloc
sont conservées. Les répétitions personnalisées respectent les arrêts et ne
rattrapent pas un ralentissement par une rafale. Comment jouer indique désormais
que les délais dépendent des paramètres, sans annoncer une cadence fixe.

97 contrôles ciblés réussis sans fenêtre : 43 attributs/entrée, 48 temporalité
et tolérances, 6 trajectoire et montée sur un bloc. Réglages, monde et fichiers
des tests sont isolés des données personnelles. Le panneau Attributs défile et
tient dans 1280 × 720 selon les mesures de mise en page.
Aucun contrôle du PC ni capture réelle pendant les vérifications : en mode
headless, la capture est neutralisée. Apparence du formulaire, ressenti et
capture automatique sur une vraie fenêtre restent à confirmer manuellement.

Tests : tests/attributes_test.gd, tests/action_timing_test.gd,
tests/jump_profile_test.gd. Aucun test exhaustif supplémentaire effectué.
## Fenêtre redimensionnable — 0.0.2.11
La fenêtre garde ses boutons réduire / agrandir / fermer ; pas de plein écran.
En la redimensionnant ou en l'agrandissant, menus, HUD et vue 3D s'adaptent :
l'interface est mise à l'échelle sans déformation et l'espace en plus est
rempli (fond des menus, champ de vision). Le panneau des menus reste centré,
le viseur reste au centre (il était placé de façon fragile), le bloc choisi
en haut à gauche, Retour aux mondes en haut à droite, l'aide en bas.
Taille minimale de la fenêtre : 800 × 450, pour garder les menus lisibles.

Test ajouté : tests/window_resize_test.gd (34 contrôles, tailles 1280 × 720,
1920 × 1080, 960 × 540, 800 × 900 et 2560 × 1080). Tests liés réussis :
pause, menus, raccourcis, historique, prototype et autres tests de partie.
Échecs anciens, sans lien avec cette version : interface_info_test.gd
(attend encore la version 0.0.2.9) et catalog_restart_test.gd (relance
d'un second processus). À tester manuellement : aspect réel en agrandissant
et en réduisant la fenêtre, notamment écran large et fenêtre étroite.

## Menus élargis — 0.0.2.11.2
Les menus suivent maintenant la forme de la fenêtre. Dans une fenêtre plus
large que 16:9, le panneau s'élargit dans la même proportion (560 de base,
au plus 70 % de la largeur). Dans une fenêtre plus haute, la liste des mondes,
les paramètres, l'historique et Comment jouer gagnent en hauteur.
Dans une fenêtre 16:9 agrandie, tout est simplement mis à l'échelle, comme avant.

Test complété : tests/window_resize_test.gd (59 contrôles : largeur du
panneau, hauteur des zones défilantes, pages Historique, Paramètres et
Mes mondes dans la fenêtre, à 5 tailles). À tester manuellement : aspect
réel en élargissant la fenêtre, en dehors du mode intégré de l'éditeur.

## Tests réparés — 0.0.2.11.3
Les 15 tests passent maintenant en une seule commande chacun.
- catalog_restart_test.gd et world_management_test.gd lancent eux-mêmes
  le second processus qui vérifie la relance, puis effacent leur fichier
  de test ; un reste d'exécution interrompue ne les bloque plus.
- interface_info_test.gd lit la version dans project.godot au lieu
  d'attendre 0.0.2.9.
- Vrai défaut corrigé : quand un champ de saisie avait le focus (Paramètres,
  création, renommage), Échap était gardé par le champ et ne quittait pas
  la page. Échap revient maintenant à la page précédente.

Résultat : 15 tests, 0 échec (dont 24 contrôles d'interface, 18 de gestion
des mondes, 2 de relance). À tester manuellement : Échap dans Paramètres
et dans un champ de nom, dans une vraie fenêtre.

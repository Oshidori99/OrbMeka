# OrbMeka — toutes les actions (0.0.8.40)

Tableau objet → actions → résultat (issue #254). Les touches sont celles par défaut (Paramètres > Contrôles).
« Survie » : en mode Survie seulement ; sinon : les deux modes.

## Dans le monde

| Objet visé | Action (touches) | Résultat |
|---|---|---|
| Sol (terre, sable, argile, boue, gravier) | Creuser (clic gauche, mode « Creuser / Casser ») | Le sol disparaît ; Survie : la matière rejetée derrière soi |
| Sol | Récupérer des matériaux (R + I maintenus, ou mode du clic gauche) | Une poignée de la matière en main |
| Herbe | Récupérer des matériaux | Une motte de gazon |
| Sol | Poser (clic droit) ; Aplanir ; Lisser (menu B + T) | Matière posée, sol aplani ou lissé |
| Pierre du sol | Casser (pioche ; Créatif : à mains nues) | Éclats de pierre |
| Rocher | Casser (pioche ; Survie à mains nues : maintenu) | Un caillou et un éclat par coup ; un bout qui ne tient plus tombe en cailloux |
| Caillou au sol | Ramasser (R, clic de la molette) | Le caillou en main (taille 6 et 7 : trop gros) |
| Caillou au sol | Casser (clic gauche) | Éclats |
| Plante (ortie, lin, herbes longues) | Récolter (R maintenu 3 s ; éclat en main : 2 fois plus vite) | 1 à 3 fibres ; la plante repousse en 10 min |
| Plante | Arracher (clic gauche maintenu, « Casser / Arracher ») | La plante entière, à replanter (clic droit) |
| Mauvaise herbe | Arracher | Elle reste au sol |
| Liane d'un tilleul | Récolter (R) | Une liane |
| Arbre debout | Abattre (clic gauche maintenu près du pied ; hache : 3 fois plus vite, jusqu'à 80 cm ; au-delà de 40 cm, plus long) | L'arbre tombe et se couche |
| Branche, tige de noisetier | Couper (clic gauche maintenu) | Elle tombe entière, couchée avec ses feuilles |
| Branche ou arbre couché | Recouper (clic gauche maintenu) | Seul le bout coupé change ; un bout nu devient son bois au sol |
| Branche ou arbre couché | R (une fois) | Ses feuilles tombent en tas (Défeuiller) |
| Branche ou arbre couché sans feuilles | R | Son bois au sol, pièce par pièce (bâtons, bûches) ; le visé en main |
| Bois au sol (bûche, bâton) | Recasser (clic gauche maintenu là où on vise) | Deux morceaux, à leur vraie taille |
| Bois au sol, objet au sol | Ramasser (R) | En main (trop lourd : reste au sol) |
| Tas de feuilles | Ramasser (R) | Les feuilles qui tiennent |
| Branche morte au sol, rejet de noisetier | Ramasser (R) ; casser le rejet (maintenu) | Un bâton (le rejet : le meilleur manche) |
| Pommier, noisetier | Cueillir (R sur le fruit) | Pomme ou noisette |
| — | Point de repère (M + R) | Un repère sur la carte, là où l'on est |

## En main et dans l'inventaire

| Objet | Action (touches) | Résultat |
|---|---|---|
| Fruit | Manger (clic droit maintenu, mode « Manger ») | La vie remonte |
| Tout objet | Poser (clic droit) | Au sol, là où l'on vise |
| Tout objet | Jeter (J ; Ctrl + J : tout le tas) | Au sol devant soi |
| Tout objet (Créatif) | Supprimer (D + E, ou zone « Supprimer ») | Il disparaît |
| Tout objet | Détails (D + T, ou « + ») | Ses caractéristiques |
| Pile | Clic droit, main vide | La moitié de la pile |
| Pile | Double clic | Les objets pareils rassemblés (jusqu'à 99) |
| Sac en filet | Le porter (case Sac) | 4 cases de plus (ou 4 autres pour un 2e sac) |
| Orbe de retour | L'utiliser | Retour au point de départ |

## Fabrication à la main (O + F)

| Objets | Action | Résultat |
|---|---|---|
| 3 fibres du même type | Tresser | Une ficelle |
| 3 ficelles du même type | Tresser | Une cordelette |
| Un caillou + un silex ou calcaire (taille 3 à 5) | Tailler | Une tête de hache ou de pioche, et un éclat tranchant |
| Une branche (2 à 5 cm, 40 cm à 1 m) + un éclat | Fendre | Une branche fendue (le manche) |
| Une branche fine (1 à 2,5 cm, 15 à 40 cm) + un éclat | Fendre | Une navette |
| Une bûche fine | Fendre | Des bâtons |
| Une branche fendue + une tête | Assembler | Un outil à ficeler |
| Un outil à ficeler + 3 ficelles (ou 1 liane) ; navette : 2 fois plus vite | Ficeler | Une hache ou une pioche en pierre |
| Une ficelle ; une cordelette | Détresser (0.0.8.40) | Ses 3 fibres ; ses 3 ficelles |
| Une hache, une pioche (ou à ficeler) | Défaire un outil (0.0.8.40) | La tête, le manche fendu, une ficelle usée |
| Une hache ou une pioche usée + 3 ficelles (ou 1 liane) | Refaire le lien (0.0.8.40) | L'outil retrouve 60 % de ses coups |
| Un bâton ou une bûche + un éclat | Écorcer (0.0.8.40) | Le bois écorcé, plus léger |
| Un caillou + un silex ou calcaire (taille 2 à 5) | Tailler → « Éclat tranchant » | Un éclat seul, en 8 coups |
| 4 cordelettes + 1 cordelette ou liane | Nouer | Un sac en filet |

## Défeuiller (issue #254, partie 1)

Déjà couvert : depuis 0.0.8.30, une petite branche feuillue coupée donne un **bâton de sa longueur** et ses feuilles
tombent à part (plus de « rameau » feuillu) ; depuis 0.0.8.23, **R** sur une branche couchée fait tomber ses feuilles,
puis R encore donne son bois. Une action « Défeuiller » dans O + F n'est donc pas utile.

## Ce qui manquait (fait en 0.0.8.40)

Écorcer (#255), détresser (#256), défaire un outil (#257), refaire le lien (#258) : faits en 0.0.8.40. Tailler un éclat seul (#259) : existait déjà (Tailler → « Éclat tranchant »). L'écorce comme objet (liens) : plus tard.

Déjà prévus ailleurs : torche (#214) avec feu de camp (#209), cultures et planter des graines (#170), coffre (#210, version future).

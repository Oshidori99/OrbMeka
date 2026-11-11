# Arbres Blender — retouche 3 du 09.11.2026

Une variante de pommier et une de noisetier, faites dans Blender par un générateur original (aucun asset repris).
Deux versions : la **détaillée** (fichier Blender, taille standard) et la **légère**, lue par le jeu (0.0.6.10). Depuis 0.0.6.11 :
0.0.6.12 : **pin sylvestre** (make_pine, PINE_SIZES) et **tilleul** (make_linden, LINDEN_SIZES), cinq tailles aussi.
**cinq tailles** par espèce (APPLE_SIZES et HAZEL_SIZES dans generer_arbres.py : hauteur, largeur, hauteur des premières branches,
épaisseur du tronc) ; les tailles 1, 2, 4 et 5 sont construites « en forme seulement » pour la version légère.

## Retouche 3 (pommier, noisettes)

- Avant : environ 4 m de haut pour 5,8 m de large, couronne plate en parasol sur cinq branches basses.
- Maintenant : **5,7 m de haut pour 6,2 m de large**. Le tronc continue en axe central jusqu'en haut ; trois étages
  de branches, des pousses entre les étages et une cime ramifiée : couronne pleine du haut jusqu'en bas.
- Branches basses presque horizontales, garnies de rameaux feuillus jusqu'au tronc ; leurs bouts retombent doucement
  (poids des pommes). Pommes un peu plus grosses (8 à 10 cm), mieux visibles.
- Noisetier : même forme ; noisettes plus visibles (grappes de 2 ou 3 au bout des rameaux, un peu plus grosses,
  brun plus clair que l'écorce, collerette verte), deux fois plus de grappes.

## Fichiers

- `arbres_detail.blend` : source, scène `OrbMeka_Arbres_Atelier` (la scène `Scene` de l'utilisateur est gardée),
  **rangé hors du dépôt** dans `../../../Archives OrbMeka/Blender/` (le générateur l'y enregistre).
- `generer_arbres.py` : générateur (aussi enregistré dans le fichier Blender). Le relancer refait toute la scène
  et enregistre le fichier ; relancer ensuite `presentation.py` (lumières, caméra, rendu `apercu_ensemble.png`).
- `version_jeu.py` : relance le générateur, puis fait la **version légère** (objets `<Espèce>_Leger` et `_Leger_Loin`) :
  branches à peu de facettes, feuillage en plaques croisées avec une image de grappe de feuilles dessinée en code,
  fruits simples. Exporte dans `assets/trees/` : `pommier_jeu.glb`, `pommier_loin.glb`, `noisetier_jeu.glb`,
  `noisetier_loin.glb` (sans images) et les images `feuilles_*.png`, `ecorce_*.png`. Mesures : `mesures_jeu.json`.
  Le jeu met ses propres matériaux (scripts/trees.gd).
- `apercu_ensemble.png` : rendu des deux arbres. `detail_noisetier.png` : détail du noisetier.
- `mesures.json` : mesures écrites par le générateur.

## Mesures (source détaillée)

| Espèce | Triangles | Modèle lointain | Hauteur | Largeur | Feuilles |
|---|---:|---:|---:|---:|---:|
| Pommier | 1 317 756 | 10 763 | 5,67 m | 6,18 m | 42 744 |
| Noisetier | 447 446 | 7 592 | 4,66 m | 4,10 m | 14 492 |

C'est la source visuelle, bien trop lourde pour le jeu. Version légère (0.0.6.10) : pommier 8 265 triangles de près
et 1 009 au loin (456 plaques de feuillage, 64 pommes) ; noisetier 5 932 et 558 (366 plaques, 48 grappes).

Références botaniques consultées pour les formes, aucun asset ni image repris :
- MNHN, noisetier : https://www.mnhn.fr/en/common-hazel
- RHS, charpente du pommier : https://www.rhs.org.uk/fruit/apples/renovating-old-trees

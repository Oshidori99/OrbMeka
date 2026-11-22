# OrbMeka™ — prototype 0.0.8.4

Godot 4.7 / GDScript. Formes et couleurs simples ; assets externes seulement sous licence vérifiée (sons CC0, assets/sounds/CREDITS.txt).

## 0.0.8.4 — Récolte : R maintenu 1 s sur une ortie, du lin ou des herbes longues donne 1 à 3 fibres (la plante reste coupée), sur un tilleul à liane une liane ; et chaque arbre a son âge et sa souplesse, gardés par tout son bois
Version locale (3 sur 4). Génération inchangée (version 33). Demandes de l'utilisateur (#213, #228).
- **Fibres** : **R maintenu 1 s** (Créatif : 0,3 s, anneau) en visant une **ortie**, du **lin** ou des **herbes longues** (déjà dans le monde) : **1 à 3 fibres** (Fibre d'ortie, de lin, d'herbe ; même graine : même nombre). La plante reste **coupée** (tige basse), enregistrée ; pas encore de repousse.
- **Liane** : R maintenu en visant le tronc d'un **tilleul à liane** : une **liane** (lien grossier) ; elle disparaît du tronc.
- Dans la case choisie, comme ramasser ; ce qui ne tient pas tombe au sol devant soi. Message « 2 fibres d'herbe récoltées ».
- Objets : icônes (botte de brins, rouleau), petite botte et rouleau en main et au sol ; Créatif : nouvel onglet **Plantes** (après Bois).
- **Bois (#228)** : chaque arbre a son **âge** (1 à 5) et sa **souplesse** (1 à 5), toujours les mêmes pour lui ; tous ses bâtons et troncs les gardent (noisetier plus souple, pin plus raide ; avant : tirés au hasard à chaque morceau).
- Corrections : le lin (touffes serrées) se récolte bien : passer d'une plante à l'autre en visant ne remet plus le temps à zéro ; une plante se vise sous tous les angles, même de haut (le regard doit passer près de sa tige) ; le nom de l'objet pris en main ne s'affiche plus deux fois (seulement en bas, au-dessus de la barre). Orties : au bord des forêts de feuillus et près de l'eau (souvent à plus de 70 m du départ).
- Ensuite : tresser les fibres en ficelle (menu de fabrication O + F, 0.0.8.5).

Tests réussis : fibers (17, nouveau), hands_eat, inventory (seul ; avec d'autres en même temps, il échoue parfois à viser le sol avant le terrain prêt, comme en 0.0.7.35), inventory_more, plants, forests, trees, tree_fall, sticks, world_save, web_save, hands_eat, return_orb, action_timing, lawn_ring (+ tests juridiques). Captures hors écran : herbe longue coupée, fibres en main, icônes.
À tester : récolter des orties, du lin et des herbes longues, une liane sur un tilleul (cœur des forêts de feuillus) ; recharger le monde (plantes toujours coupées).

## 0.0.8.3 — Mains et poches : 2 pommes par main et 3 à deux mains, 5 noisettes par main et 15 par poche (les fruits ne comptent plus en litres dans les mains, une noisette compte 4 ml) ; manger plus simple, dans tous les modes du clic droit : noisette en 0,5 s, on continue en restant appuyé, « Manger » dans B + T ; nom de l'objet pris en main au-dessus de la barre (plus sous les cases) ; orbe de retour plus grande, brillante, qui éclaire autour d'elle
Version locale (2 sur 4). Génération inchangée (version 33). Demandes de l'utilisateur.
- **Mains** : les objets comptés (pommes, noisettes, cailloux, éclats) ne comptent plus en litres, seulement en nombre : **2 pommes par main, 3 pour les deux mains** (une pile tenue à deux mains, ou 2 + 1) ; **5 noisettes par main, 10 à deux mains** (avant : 8 et 16). Cailloux et éclats : inchangés (4 par main, 8).
- **Poches** : poids et volume comme avant, et **15 noisettes au plus par poche**. Une noisette compte comme une vraie (2 cm, environ 4 ml), quelle que soit sa taille dessinée dans l'arbre (avant : jusqu'à plus de 100 ml, 15 ne tenaient pas). Message : « 5 noisettes au plus dans une main, 10 à deux mains, 15 par poche. »
- **Manger** : noisette en **0,5 s**, pomme en 1 s ; en **restant appuyé**, on mange le suivant (relâcher pour s'arrêter ; on ne pose rien en relâchant).
- **Manger dans tous les modes** du clic droit (Poser, Aplanir, Lisser) : maintenu avec un fruit en main, on mange ; un clic court fait l'action du mode. **Menu B + T** : « **Manger** » au bout de la ligne du clic droit (pomme croquée) : le clic droit mange seulement, il ne pose jamais rien par erreur.
- **Barre d'objets** : plus de nom sous les cases (seulement le poids) ; le **nom de l'objet pris en main** s'affiche au milieu, au-dessus de la barre, 2 s.
- **Orbe de retour** : dessinée plus grande (11 cm au lieu de 7, poids et volume inchangés) pour la voir dans l'herbe ; plus brillante (reflets) ; posée au sol, elle **luit et éclaire autour d'elle** (2,5 m), ce qui la rendra visible la nuit (au plus 16 lumières).

Tests réussis : hands_eat (23, nouveau), return_orb (22), health, death, inventory, inventory_more, action_menu, smooth_terrain, breaking, rock_place, action_timing, interface_info, web_fixes, layout_lines (+ tests juridiques). Capture hors écran : orbe qui éclaire le sable, nom « Noisette » au-dessus de la barre.
À tester : prendre 3 pommes, des noisettes en poche, manger en restant appuyé, « Manger » dans B + T, l'orbe dans l'herbe.

## 0.0.8.2 — Orbe de retour en Survie (200 g, 2 dl, clic droit maintenu : retour au point de départ, puis elle disparaît ; une en poche et une au sol près du départ au début), et un arbre qui tombe blesse : de 15 à 80 points selon sa taille, tout pile dessous, très peu en étant frôlé
Version locale (1 sur 4). Génération inchangée (version 33). Demandes de l'utilisateur (#231, #229).
- **Orbe de retour** (Survie) : boule turquoise lumineuse cerclée d'un anneau doré, 200 g, 2 dl. En main, **clic droit maintenu** 1 s (anneau) : retour au point de départ, puis l'orbe disparaît (usage unique). Clic court : elle est posée au sol ; J la jette ; R la reprend, comme tout objet.
- **Au début** (une fois par monde de Survie) : une orbe dans une poche (au sol à ses pieds si les poches sont pleines) et une deuxième posée au sol à côté du point de départ, en réserve. Les mondes de Survie d'avant la reçoivent à leur première ouverture ; un monde ouvert en Créatif n'en reçoit jamais, même passé ensuite en Survie (Créatif : touche H).
- **Arbre qui tombe** (Survie) : à la fin de sa chute, il blesse celui qui est dessous : de 15 points (petit tronc, 10 cm) à 80 (très gros, 45 cm et plus) ; tout pile sous le tronc, de moins en moins sur le côté, quelques points en étant frôlé (70 cm plus loin), la moitié au plus sous les branches. Le haut d'un arbre coupé debout blesse aussi. Même effet rouge que pour une chute ; message « L'arbre vous est tombé dessus : −N ». À mains nues (troncs de 40 cm au plus) : jusqu'à environ 70.

Tests réussis : return_orb (21, nouveau), death, health, inventory, inventory_more, game_mode, tree_fall, trees, tree_stress, sticks, world_save, web_save, action_timing, breaking, appearance (+ tests juridiques). Capture hors écran : orbe en main et au sol, icône.
À tester : utiliser l'orbe (et la poser, la reprendre), un ancien monde de Survie (orbes données), se faire tomber un arbre dessus de face et de côté.

## 0.0.8.1 — À bout de forces en Survie : petit écran puis retour au point de départ, objets tombés sur place et gardés au sol (ou gardés sur soi, au choix du monde, à la création, dans Paramètres → Monde, défaut dans Paramètres → Survie), et en Créatif retour au départ avec H ou depuis la pause
Version publiée (4 sur 4, avec 0.0.7.34, 0.0.7.35 et 0.0.8). Génération inchangée (version 33). Demandes de l'utilisateur (#205, #188).
- **Vie à 0** (Survie) : écran « À bout de forces… » (rien de gore), souris libérée, bouton **Revenir au départ** : point de départ, vie pleine. Échap et l'inventaire ne font rien pendant cet écran. Quitter pendant l'écran : on revient au départ, vie pleine.
- **Objets à la mort**, propre à chaque monde : **Tombent sur place** (par défaut) : tout ce qu'on porte (mains et poches) tombe, éparpillé autour (jusqu'à 1,2 m), et reste au sol (objets.json), à récupérer ; ou **Gardés**. Choisi à la création du monde, modifiable en partie dans Paramètres → Monde ; le choix proposé à la création se règle dans Paramètres généraux → Survie.
- **Créatif** : **Revenir au point de départ** avec la touche **H** (modifiable, Contrôles → Raccourcis) ou le bouton de la pause (Créatif seulement). En Survie : l'orbe de retour viendra en 0.0.8.2 (#231).
- Rappel : au-delà de 3000 objets posés dans un monde, les plus anciens disparaissent (limite d'avant, ground_items.gd).

Tests réussis : death (21, nouveau), health (28), game_mode, inventory_more, controls, controls_groups, key_combos, shortcuts_selection, settings_files, pause, pause_settings, menu, interface_info, world_management, world_save, custom_world_menu, world_mode, folds, mouse_settings (+ tests juridiques). Captures hors écran : écran de mort, page de création.
À tester : mourir d'une vraie chute, ramasser ses objets tombés, la touche H en Créatif, le choix dans Paramètres → Monde.

## 0.0.8 — Vie en Survie : barre de 100 points en bas à gauche, dégâts de chute au-delà de 4 m (moins sur le sable, rien dans l'eau), vie qui revient lentement, pommes et noisettes à manger (clic droit maintenu), et pomme brune vieillie sans feuille
Version locale (3 sur 4), publiée avec 0.0.8.1. Génération inchangée (version 33). Première version de la série 0.0.8 — Fabrication et survie (#171, #204). Demandes de l'utilisateur.
- **Vie** (Survie seulement, rien en Créatif) : 100 points. **Barre** fine en bas à gauche : contour blanc, rouge vif à gauche, plus clair et transparent vers la droite, le nombre écrit en blanc (100, 95…).
- **Chute** : rien jusqu'à 4 m, puis 8 points par mètre (5 m : −8, 8 m : −32, 12 m : −64, vers 16,5 m : tout) ; 75 % sur le sable ; rien en tombant dans l'eau. La première chute après le passage en Survie ne blesse pas.
- **Dégât** : bord de l'écran rouge un court instant, vue qui tremble un peu, barre qui clignote (pas de sang).
- **Vie qui revient** : 1 point toutes les 3 s, après 6 s sans dégât.
- **Manger** : un fruit en main, **clic droit maintenu** 1 s (anneau) : pomme +15, vieille pomme brune +5, noisette +3. Clic court : le fruit est posé, comme avant. Vie pleine : rien n'est mangé.
- À 0 (en attendant l'écran de mort de 0.0.8.1, #205) : retour au point de départ avec toute sa vie.
- **Pomme brune** (vieille) : icône sans feuille, queue sèche, peau tachée et mate.
- Vie enregistrée dans joueur.json (« vie ») ; ancien monde : vie pleine.
- Test interface_info corrigé : 49 réglages depuis 0.0.7.35 (vitesse de la molette).

Tests réussis : health (27, nouveau), action_timing, inventory, inventory_more, game_mode, fly, swim, jump_profile, step_over, loaded_edge, world_save, web_save, sticks, tree_fall, interface_info, prototype, history_resume (+ tests juridiques).
À tester : l'aspect de la barre et de l'effet rouge, une vraie chute (falaise, sable, lac), manger au clic droit maintenu, l'icône de la pomme brune.

## 0.0.7.35 — Souris tout en haut de Contrôles : sensibilité de la vue (avant dans Paramètres généraux) et nouvelle vitesse de défilement de la molette (25 à 300 %)
Version locale (2 sur 4). Génération inchangée (version 33). Demande de l'utilisateur.
- **Souris** tout en haut de Paramètres → Contrôles (avant les touches) : **Sensibilité de la souris** (rotation de la vue en jeu, 10 à 300 %, déplacée depuis Paramètres généraux, valeur gardée) et **Vitesse de défilement** (nouvelle) : distance parcourue à chaque cran de la molette dans les menus, les listes et l'inventaire, de 25 à 300 % (100 % : vitesse d'origine, un huitième de la zone visible par cran).
- Sur une barre réglable, la molette garde son rôle ; une zone en butée laisse défiler la zone autour.

Tests réussis : mouse_settings (6, nouveau), sliders, folds, settings_files, controls, controls_groups, menu, pause_settings, custom_world_menu, menu_sounds, character_voices, inventory, inventory_more (+ tests juridiques). inventory a échoué une fois avec 15 tests en même temps (visée du sol avant le terrain prêt), réussi seul : fragile sous charge, sans lien.
À tester : la molette dans les menus, l'Historique et l'inventaire, à 50 % et à 200 %.
## 0.0.7.34 — Monde ouvert en 4 s au lieu de 7,5 sur PC (montré dès que les 9 × 9 colonnes autour sont prêtes, le reste se construit en jouant), et sur le Web le clic dans le jeu lui donne le clavier (itch.io), avec « Cliquez dans le jeu » et la pause quand la souris est libérée
Version locale (1 sur 4). Génération inchangée (version 33). Demandes de l'utilisateur.
- **Chargement plus court (PC)** : l'écran de chargement attendait toute la vue (289 colonnes). Maintenant, sur PC, le monde est montré dès que les **9 × 9 colonnes autour** sont faites, avec leurs arbres, leur herbe, l'horizon et les shaders ; le reste de la vue se construit en jouant. Les colonnes proches passent d'abord, puis leurs détails et l'horizon. Deux fois plus de travail par image derrière l'écran (80 ms, graine 100 ms). Mesuré 3 fois sur ce PC : **4,0 s au lieu de 7,5 s**. Le Web garde l'attente de toute la vue (saccades sinon, mesures 0.0.7.25).
- **Clavier sur le Web (itch.io)** : la personne pouvait tourner la tête à la souris, mais aucune touche ne répondait. Le jeu tourne dans un cadre venant d'un autre site, et Godot empêche le clic normal : dans certains navigateurs, le clavier restait à la page itch.io. Maintenant, chaque clic dans le jeu lui donne le clavier (export Web). Pas reproduit dans le navigateur intégré (il donne le clavier de toute façon) : à confirmer avec la personne.
- **« Cliquez dans le jeu pour jouer (souris et touches) »** au centre de l'écran quand la souris n'est pas capturée en jeu (les touches du jeu ne répondent que souris capturée).
- **Web : la souris libérée ouvre la pause** : le navigateur garde la première pression d'Échap pour libérer la souris ; le jeu ne la recevait pas.

Tests réussis : loading_screen (avec 4 vérifications de plus), prototype, menu, smooth_terrain, inventory (+ tests juridiques). Mesures de l'ouverture sur PC (fenêtre hors écran).
À tester : ouvrir un monde sur PC (vue lointaine qui se complète en jouant, fluidité) ; sur le Web (itch.io, Firefox ou Safari si possible) : touches et Échap après un clic.
## 0.0.7.33 — Le sol d'origine ne glisse plus en chaîne au bord d'un précipice (seul ce qui est posé ou déplacé glisse ; sans rien dessous, tout tombe encore), et une chute refait ses zones ensemble, sans ramer
Version publiée (4 sur 4, avec 0.0.7.30 à 0.0.7.32). Génération inchangée (version 33). Signalé par l'utilisateur.
- **Cause** : la règle du talus (le sable glisse dès 1 m de vide à côté, la terre dès 1,5 m) valait aussi pour le sol d'origine, alors que les falaises de la graine sont plus raides : un geste près du bord réveillait un point, qui glissait et réveillait son voisin, en chaîne le long de la falaise. Mesuré : 1 578 glissements pour 40 bords réveillés.
- **Corrigé** : le sol d'origine (jamais changé) ne glisse plus en talus ; il tombe seulement s'il n'a plus rien dessous (le petit plafond de terre d'environ 1 m tient toujours). Ce qui est posé ou a déjà bougé glisse comme avant (un tas de sable s'étale). Mesuré : 0 glissement.
- **Moins de lag pendant une chute** : les zones touchées sont refaites ensemble, au plus toutes les 0,45 s et quand tout est retombé (avant : à chaque cran, toutes les 0,15 s).
- Les mondes existants ne changent pas (rien d'enregistré n'est modifié).

Tests réussis : cliff_fall (5, nouveau), smooth_terrain, rock_place, prototype, web_save, loaded_edge (+ tests juridiques ; tous les autres par l'Action Dev).
À tester : creuser et poser au bord d'une falaise, sur sable et sur terre ; une grande chute (fluidité).
## 0.0.7.32 — Terre posée sur un rocher qui le touche enfin (avant : jusqu'à 1 m de vide dessous), et qui tombe quand elle dépasse du bord
Version locale (3 sur 4). Génération inchangée (version 33). Issue #216, signalée par l'utilisateur (capture).
- **Cause** : la terre prenait la case de 50 cm au-dessus du point visé, et, en geste de 2 ou 4, les cases voisines restaient à la hauteur du centre alors que le rocher descend sur les côtés ; un appui artificiel les tenait en l'air. Mesuré : 20 sous-cellules sur 47 à plus de 10 cm du rocher, jusqu'à 1,06 m.
- **Corrigé** : sur le dessus d'un rocher, d'un caillou ou d'un bloc, chaque sous-cellule du geste se pose sur la surface sous son propre centre ; quand le dessous de la terre resterait plus de 3 cm au-dessus, une sous-cellule de joint (cachée dans le rocher) comble le vide. Mesuré : 3 cm au plus.
- **Bord du rocher** : ce qui dépasse n'a plus d'appui artificiel et tombe au sol.
- **Survie** : les joints comptent (une poignée chacun), jamais plus que ce qu'on tient. Sur le sol lisse et sur les côtés d'un rocher : rien ne change.

Tests réussis : rock_place (7, nouveau), smooth_terrain, prototype, inventory, inventory_more (+ tests juridiques). Captures avant / après.
À tester : poser de la terre sur un rocher (petits et grands gestes, sur le dessus et près du bord).
## 0.0.7.31 — Glisser pour partager un tas (bouton gauche : parts égales, bouton droit : un par case), clic droit qui pose un seul objet et ne vide plus la case, D + E supprime tout le tas (Créatif), D + T : détails de l'objet en main, « + » du Créatif : détails de ce qu'on a, variantes en haut, J avec l'un ou l'autre Ctrl
Version locale (2 sur 4). Génération inchangée (version 33). Demandes de l'utilisateur.
- **Glisser l'objet tenu** : bouton gauche maintenu sur plusieurs cases (cadre jaune, part affichée « +2 ») : au relâchement, le tas est **réparti à parts égales** ; le reste de la division reste en main. Bouton droit maintenu : **un objet par case**. Une case d'un autre objet est sautée ; en Survie, une case trop lourde ou trop pleine aussi. Pris en appuyant puis glissé sur une case : posé comme un clic.
- **Clic droit** sur une case : avec un objet tenu, en pose **un seul** ; sans rien tenir, **ne fait rien** (avant, en Créatif, il vidait la case). Sur un objet du haut (Créatif) : toujours dans la première case libre.
- **D + E (Créatif)** : supprime **tout le tas** en main (en jeu) ou tenu / sous la souris (inventaire). En Survie, rien n'est supprimé (poubelles plus tard).
- **D + T** : toujours les détails de l'**objet en main** : en jeu, l'inventaire s'ouvre dessus ; dans l'inventaire, l'objet tenu par la souris, sinon la case en main. D + T de nouveau ou Échap : referme.
- **« + » du Créatif** : sur les objets qu'on a (barre, grille), **seulement leurs cartes de détails** ; sur les objets du haut, **seulement les variantes** (et le « + » seulement s'il y en a).
- **J + Ctrl** (gauche ou droit) : tout le tas au sol, en jeu et dans l'inventaire.
- Note juridique : partager un tas en glissant est une mécanique générique (risque faible, accepté par l'utilisateur).

Tests réussis : inventory_more (53), inventory, controls, controls_groups, key_combos, shortcuts_selection, menu (+ tests juridiques).
À tester : le glisser à la souris (gauche et droit, parts « +N », cadre jaune), clic droit avec un tas, D + T en jeu et dans l'inventaire, D + E en Créatif.
## 0.0.7.30 — Détails de chaque objet en Créatif (cartes au « + »), « − » rouge pour refermer, cartes de Survie plus compactes, J pour jeter au sol partout (inventaire et Créatif compris), D + E pour supprimer en Créatif, D + T pour les détails, Ctrl droit pour tout le tas
Version locale (1 sur 4). Génération inchangée (version 33). Demandes de l'utilisateur.
- **Créatif : détails de chaque objet** : le « + » est maintenant sur tous les objets (ceux du haut, de la grille et de la barre). Il ouvre d'abord les **cartes de détails** sur toute une ligne (un tas : une carte par objet, au plus 12, puis « … et N autres »), puis les variantes.
- **« − » pour refermer** : une fois ouvert, le « + » vert devient un « − » blanc gras sur fond rouge.
- **Cartes plus compactes** (Survie et Créatif) : petite image, le nom en haut, puis **deux détails par ligne**, le poids toujours en dernier ; tous les détails, un par ligne, au survol de la carte.
- **J (Jeter, au sol)** : en jeu, en Survie et **en Créatif** ; **dans l'inventaire** aussi : l'objet tenu par la souris, sinon celui de la case sous la souris, sinon rien. Un objet à la fois (le dernier pris). La zone Jeter et le lâcher hors de la fenêtre font aussi tomber l'objet au sol en Créatif. Objet illimité (Créatif) : une copie tombe, il reste.
- **D + E (Supprimer, Créatif seulement)** : en jeu et dans l'inventaire, l'objet disparaît sans rien faire tomber. En Survie, rien n'est supprimé.
- **D + T (Détails)** : ouvre ou ferme les détails de l'objet sous la souris (avant : D seul, qui ne fait plus rien dans l'inventaire).
- **Ctrl droit + J** ou **Ctrl droit + D + E** : tout le tas. Ces touches sont modifiables dans Contrôles → Inventaire.
- Pas fait : erreur passagère « PackedVector3Array » vue dans les tests (sans lien avec ce lot) : à chercher.

Tests réussis : inventory_more (47), inventory, controls, controls_groups, key_combos, shortcuts_selection, menu (+ tests juridiques).
À tester : l'aspect du « − » rouge et des cartes compactes, les cartes du Créatif dans la grille (au-dessus des variantes), J et D + E sous la souris, D + T, Ctrl droit + J / D + E au clavier (en jeu, D fait aussi un petit pas à droite).
## 0.0.7.29 — Mode Survie ou Créatif choisi à la création (Survie par défaut), bouton « + » sur les objets de l'inventaire (toutes les variantes en Créatif, tous les détails en Survie), jeter un objet (zone Jeter, hors de la fenêtre, touche J en Survie)
Version publiée (4 sur 4, avec 0.0.7.26 à 0.0.7.28). Génération inchangée (version 33). Demandes de l'utilisateur.
- **Création d'un monde** : choix Survie / Créatif (Survie par défaut), modifiable ensuite dans les réglages du monde. Les mondes existants ne changent pas.
- **Bouton « + »** en haut à droite des cases de l'inventaire (fond vert, « + » blanc ; jamais sur la barre du jeu) : il ouvre une **ligne complète juste sous la case**, le reste descend ; fermée dès que la souris quitte la case et ses lignes. **D** sur une case : ouvre (reste ouvert) ; **D** ou **Échap** : ferme (Échap ferme d'abord les sous-possibilités, puis l'inventaire).
  - **Créatif** : toutes les variantes : bois de chaque essence en 7 tailles × 5 états (jeune, adulte, vieux, mort, pourri) × 5 souplesses (175), cailloux en 7 tailles, pommes en 3 tailles × 5 couleurs ; à prendre comme les objets du haut. La zone des objets **défile** (barre jaune bien visible), au plus la moitié de l'écran.
  - **Survie** : une carte par objet porté du même genre (tous les bois, tous les cailloux…), mains et poches, avec tous ses détails, un par ligne.
- **Ordre fixe des détails** (accepté) : nom, longueur, épaisseur (gros → petit bout), forme, état (vert, mort, pourri), souplesse, âge, note de manche ; puis taille, couleur, diamètre, coups ; **poids toujours en dernier**.
- **Jeter** : zone « Jeter » avec une croix, sous la barre à droite, et lâcher l'objet **hors de la fenêtre** de l'inventaire. Créatif : il disparaît ; Survie : il tombe au sol devant soi. **Touche J** (Survie, modifiable dans Contrôles → Inventaire) : jette l'objet en main, un à la fois.
- Pas fait : erreur passagère « PackedVector3Array » vue deux fois dans les tests (sans lien avec ce lot) : à chercher.

Tests réussis : inventory_more (23, nouveau), inventory (106), game_mode, controls, menu, custom_world_menu et les tests touchés (18) (+ tests juridiques). Captures : variantes du Créatif avec défilement, cartes de détails en Survie.
À tester : le « + » et la touche D à la souris, jeter en lâchant hors de la fenêtre, J en Survie, création d'un monde en Survie.
## 0.0.7.28 — Herbe et plantes de nouveau sur toute la distance (seulement 9 colonnes depuis 0.0.7.25), pierres deux fois plus rapides à mains nues, rochers et cailloux cassables à mains nues en Survie
Version locale (3 sur 4). Génération inchangée (version 33). Signalé par l'utilisateur.
- **Herbe et plantes** : depuis 0.0.7.25, elles n'apparaissaient que sur les 9 colonnes autour du point d'arrivée (au-delà, la file des détails était vidée juste après la mise en file) ; un trou creusé faisait apparaître l'herbe d'un seul carré. Corrigé : toute la distance de l'herbe est de nouveau remplie, les plus proches d'abord.
- **Pierres deux fois plus rapides** à mains nues (Survie) : pierre et charbon 10 s, calcaire 7,5 s, pierre sombre et silex 15 s par sous-cellule (avant 20, 15 et 30 s).
- **Rochers à mains nues** (Survie) : en maintenant le clic, une sous-cellule du rocher à la fois, avec la durée de sa pierre (10 s, calcaire 7,5 s), sans rien récupérer.
- **Cailloux à mains nues** (Survie) : 5 s en maintenant, sans éclats.
- Toujours avec la pioche (Créatif) : morceaux et éclats comme avant.

Tests réussis : lawn_ring (nouveau), smooth_terrain (171 : pierre 10 s, rocher, caillou), inventory et les tests touchés (14) (+ tests juridiques).
À tester : ouvrir un monde et regarder l'herbe à 4 zones ; en Survie, casser un rocher et un caillou à mains nues.
## 0.0.7.27 — Durées de cassage selon la matière (Survie : creuser en maintenant, la pierre à mains nues en 20 s sans rien récupérer, gestes plus grands plus rapides), Créatif : tout en 0,3 s, pierre et rochers à mains nues
Version locale (2 sur 4). Génération inchangée (version 33). Issue #217.
- **Survie, à mains nues** : on creuse en maintenant le clic ; durée par sous-cellule de 50 cm : neige 0,3 s, sable et aiguilles 0,4, boue 0,5, terre 0,6, gravier 0,8, argile 1 s ; **pierre 20 s**, calcaire 15 s, pierre sombre et silex 30 s, une sous-cellule à la fois et **sans rien récupérer** ; Roche-mère jamais. Changer de cible recommence ; anneau de chargement au-delà de 0,5 s.
- **Gestes plus grands** (demande de l'utilisateur) : la somme des sous-cellules × 0,8 pour chaque groupe de 4 (4 sous-cellules : 80 %, plus tard 8 : 64 %…).
- **Bois** : comme avant (2,5 s par 10 cm d'épaisseur, 40 cm au plus), bois mort, pourri et vert depuis 0.0.7.26.
- **Créatif** : tout au rythme du clic (0,3 s), pierre, cailloux et rochers compris, à mains nues (la pioche reste dans les Outils) ; bois en 0,3 s (avant 1 s).
- Plus tard, avec les outils : pioche ÷ 6 sur la pierre (avec des morceaux), pelle ÷ 3 sur la terre, hache ÷ 4 sur le bois. Cailloux et rochers en Survie : toujours avec une pioche.

Tests réussis : smooth_terrain (pierre 20 s, ordre des matières, gestes × 0,8, Créatif à mains nues), inventory (creuser en maintenant), et les tests du cassage (13) (+ tests juridiques).
À tester : en Survie, creuser terre, sable et pierre en maintenant (anneau), changer de cible ; en Créatif, casser la pierre et un rocher à mains nues.
## 0.0.7.26 — Branches mortes au sol dans les forêts (rares ailleurs), rejets de noisetier à casser en maintenant, qualités du bâton et note de manche, longueurs affichées avant de recasser un bâton
Version locale (1 sur 4). **Génération 33** (nouveaux mondes seulement ; les mondes existants ne changent pas). Issue #212.
- **Branches mortes au sol** : placées selon la graine, beaucoup en forêt (environ une tous les 5 m²), rares ailleurs (une fois sur 4 sous un arbre seul), jamais dans l'eau. Chacune a l'essence de l'arbre le plus proche, 30 à 90 cm de long, 1,5 à 5 cm d'épaisseur, droite ou tordue, saine ou pourrie. Montrées à 3 zones autour du joueur ; ramassées avec R ; seules celles ramassées ou recassées sont enregistrées (objets.json).
- **Rejets de noisetier** : 2 à 5 tiges droites au pied de chaque noisetier (60 à 150 cm, 1,5 à 3 cm) ; cassés en maintenant le clic (2 s, bois vert ; 0,3 s en Créatif), ils tombent au sol (« Rejet de noisetier »).
- **Qualités visibles** dans le détail d'un bâton : longueur, épaisseur, droit ou tordu, sain, mort ou pourri, et la note de manche (excellent, bon, moyen, mauvais : un bon manche est droit, sain, 40 à 70 cm, 2 à 4 cm ; noisetier excellent, pommier bon, pin et tilleul moyens).
- **Recasser un bâton au sol** : en le visant, les deux longueurs qu'il donnerait et le temps (« Casser ici : 32 cm et 41 cm (0,3 s) ») ; bois mort 2,5 fois plus vite, pourri plus vite encore, rejet vert 1,5 fois plus lent. Le repère à la molette viendra en 0.0.8.
- Branches et rejets ajoutés par la file de fond (une colonne à la fois, 2 ms au plus).
- Pas fait : herbe haute qui cache les branches (à voir en jouant), couleur du bois mort (comme l'écorce de son essence).

Tests réussis : sticks (19, nouveau), inventory (105), custom_generation, world_save, prototype, breaking, history_resume et les tests touchés (+ tests juridiques). perf_guard : « le monde suit en courant » échoue aussi sans ces changements (pic d'un arbre à 42 ms, déjà là) : à revoir. Captures : rejets au pied d'un noisetier, branches dans une forêt de pins.
À tester : ramasser des branches mortes avec R, casser un rejet en maintenant, recasser un bâton (longueurs affichées), qualités dans l'inventaire.
## 0.0.7.25 — Terrain creusé et place du joueur enregistrés sur le Web, rouvrir un monde sans image figée (toute la vue prête derrière l'écran de chargement), troncs et grosses branches solides, Résolution 3D à 100 % sur le Web, herbe et plantes après la surface, pause plus légère, modèles d'arbres plus légers à télécharger
Version publiée (4 sur 4). Génération inchangée (version 32). D'après le troisième rapport de mesures Web (Chrome, Radeon 610M).
- **Sauvegarde Web** : le terrain creusé ou posé est enregistré 0,5 s après (oublié avant : un trou perdu même 10 s après), ainsi que la place du joueur dès qu'il a bougé de 8 m.
- **Rouvrir un monde sans image figée** : derrière l'écran de chargement, même la colonne du joueur passe par la file (avant : 1,7 s figées en forêt dans Chrome) ; l'écran reste jusqu'à ce que toute la vue proche soit construite, herbe, plantes, arbres et lointain compris (30 s au plus) : plus de saccades juste après l'arrivée. Rendu Web sur ce PC, monde rouvert en forêt : 6,8 s, pire image 0,08 s, ensuite 15 ms au pire.
- **Troncs et grosses branches solides** : une collision par tige principale et par grosse branche basse (8 au plus par arbre), tirée des branches calculées d'avance : la caméra n'entre plus dans les arbres à plusieurs tiges.
- **Résolution 3D à 100 % sur le Web** (mesures : 75 % y était le plus lent, 60 % ne gagnait presque rien) ; le réglage reste dans Vidéo. Les préréglages Web de 0.0.7.24 sont repris à 100 %.
- **Herbe et plantes après la surface** quand on se déplace : la surface et sa collision d'abord, les détails ensuite (les plus proches d'abord) ; en vol rapide, moins d'arrêts « Chargement du terrain… ».
- **Pause** : le flou calculé une seule fois (image réduite) au lieu de chaque image.
- **Feuilles contre la caméra** : effacées entre 12 et 40 cm (avant 25 et 80 cm : la trame se voyait trop).
- **Sol simplifié** : bord des couches de terre de nouveau irrégulier (sans lui, bandes droites tous les mètres).
- **Téléchargement** : modèles d'arbres importés sans ombres séparées ni éclairage précalculé (inutilisés) : 16,7 → 9,0 Mo ; branches et modèles identiques (vérifié : les arbres coupés des mondes existants sont relus pareil).
- Gardé tel quel (demande de l'utilisateur) : les ombres. Pas fait : anticrénelage et saturation (coût incertain), coupe d'un arbre.

Tests réussis : web_save (10), quality (26), loading_screen, trees (tiges solides, branches enregistrées = calculées) et les tests touchés (43) (+ tests juridiques).
À tester : sur le Web (Claude Code web) : réouverture d'un monde en forêt, vol rapide, sauvegarde après un trou creusé ; sur PC : passer entre des tiges de noisetier et sous des branches basses de pommier (on peut s'y cogner la tête).

## 0.0.7.24 — Plus de vide en vol rapide, ouverture d'un monde sans gel (préparée derrière l'écran de chargement), réglage Résolution 3D, Web : Équilibré et Beauté moins loin, sauvegarde Web 0,5 s après un changement, pause figée, relief au-delà du bord du monde, feuilles effacées contre la caméra
Version locale (3 sur 4). Génération inchangée (version 32). D'après le deuxième rapport de mesures Web (Chrome, Radeon 610M).
- **Plus de vide en vol rapide** : quand une colonne proche attend, le terrain a trois quarts du temps et le lointain le reste (avant : tout pour le terrain ; en vol, le lointain n'avançait plus et le paysage disparaissait).
- **Ouverture d'un monde sans gel** : le monde s'ouvre derrière l'écran de chargement (fond uni, accueil 3D retiré) et y prépare ses 8 colonnes autour, ses arbres et ses shaders (quelques-uns par image) ; il est montré quand tout est prêt (30 s au plus). Rendu Web sur ce PC : 2,6 s en tout, pire image 0,23 s (mesures Web avant : jusqu'à 19 s figées à la première ouverture). Barre 2 fois plus rapide (60 ms par image).
- **Résolution 3D** (Paramètres → Vidéo, demande de l'utilisateur) : 50 à 100 % ; l'interface reste nette. Sur le Web : 60 % en Performance, 75 % en Équilibré et Beauté ; PC : 100 %.
- **Web : Équilibré et Beauté moins loin** (accord de l'utilisateur) : 6 zones et +10, 8 zones et +16 (Beauté à 16 zones y passait sous 9 images par seconde). Les défauts affichés dans Vidéo sont ceux du Web.
- **Anciens réglages Web** (ancienne Performance) repris en nouvelle Performance au lieu de Personnalisé.
- **Sol simplifié et densité de l'herbe** appliqués tout de suite en jeu (avant : à la prochaine ouverture).
- **Travail de fond** : budget calculé sur l'image sans lui (il ne s'emballe plus, 90 à 110 ms par image mesurées), 15 ms au plus sur le Web.
- **Sauvegarde Web** 0,5 s après un changement (avant 2 s) ; un arbre qui tombe ne la retarde plus.
- **Pause figée** : l'image du jeu photographiée une fois et floutée, la 3D plus dessinée pendant la pause (le flou vivant coûtait 24 ms par image sur le Web).
- **Bord du monde** (PC et Web) : le relief simplifié continue au-delà de la limite jusqu'à la brume (avant : vide bleu pâle) ; on reste bloqué à la limite.
- **Feuilles contre la caméra** : sous les branches, les feuilles à moins de 25 cm s'effacent en douceur (entières dès 80 cm). Les troncs : collisions vérifiées, toujours au moins aussi larges que le tronc visible.
- Pas fait : ciel simplifié et saturation sans passe (gain non mesurable sur ce PC, la saturation garde le Web proche du PC), mipmaps du feuillage (feuillage clairsemé au loin à craindre), coupe d'un arbre.

Tests réussis : quality (25), loading_screen (6), web_save, menu_style (pause figée), interface_info (48 champs) et les tests touchés (38) (+ tests juridiques). Captures : pause figée, bord du monde (PC et rendu Web).
À tester : sur le Web (Claude Code web) : vol rapide, première ouverture d'un monde, Résolution 3D ; sur PC : passer sous des branches.

## 0.0.7.23 — Écran de chargement avec barre de progression, Performance plus légère (sol simplifié, ombres « Aucune » et herbe « Très basse » sur le Web), sauvegarde Web peu après chaque changement, voile des menus sans copie d'écran, monde construit plus vite quand le jeu est lent, accueil Web allégé
Version locale (2 sur 4). Génération inchangée (version 32). D'après les mesures de la version Web sur une petite carte graphique (Chrome, Radeon 610M : 7 à 13 images par seconde).
- **Écran de chargement** (demande de l'utilisateur) : ouvrir un monde depuis les menus affiche « Chargement du monde », l'étape (Montagnes, Lacs, Rivières, Crevasses, Grottes) et une barre ; la graine se prépare par étapes, puis le monde s'ouvre (environ 0,2 s sur PC au lieu de 2 s de gel ; sur le Web, 2,6 à 6,9 s de gel avant). Même monde qu'avant, vérifié.
- **Qualité Performance plus légère** (PC bon marché et Web) : sol simplifié (bruit à une seule couche, gravier et relief fin effacés, mêmes couleurs) ; sur le Web, **pas d'ombres** et herbe **très basse**.
- **Nouveaux choix** : Ombres *Aucune*, herbe *Très basse* (40 brins).
- **Sauvegarde Web** : enregistrée 2 s après un changement (arbre coupé, terrain, objet, inventaire), une fois que plus rien ne tombe ; avant, seulement en fermant l'onglet, et le dernier changement pouvait être perdu.
- **Voile des menus** : à l'accueil, posé par transparence (même image) au lieu de recopier l'écran à chaque image ; la recopie reste pour le flou de la pause.
- **Monde construit plus vite quand le jeu est lent** : sous 30 images par seconde, le travail de fond prend un quart de l'image (30 ms au plus) ; à 8 images par seconde, le monde se construisait 6 à 7 fois moins vite.
- **Accueil sur le Web** : moitié moins de pins, lointain jusqu'à environ 130 m, et la même construction plus rapide quand le jeu est lent (60 à 75 s mesurées pour le voir entier).
- Pas encore fait : la coupe d'un arbre (20 à 60 ms sur PC, environ 300 ms sur le Web) ; il faut réécrire le découpage des morceaux.

Tests réussis : loading_screen (nouveau), web_save (nouveau), quality (18 vérifications), perf_guard, menu_style (voile), et les tests touchés (34) (+ tests juridiques). Captures en rendu Web : Beauté, Performance Web, écran de chargement.
À tester sur le Web (Claude Code web, même ordinateur que la première fois) : temps de chargement, images par seconde dans chaque qualité, et la sauvegarde (couper un arbre, attendre 3 s, recharger la page).

## 0.0.7.22 — Arrêt au bord du terrain pas encore construit (sans tomber), colonnes autour du point d'arrivée construites à l'ouverture, calcul du terrain repris où il en était, Beauté à 16 zones et lointain +24
Version locale (1 sur 4). Génération inchangée (version 32).
- **Arrêt au bord** (demande de l'utilisateur) : si le sol devant n'est pas encore construit (PC lent, vol rapide), on s'arrête juste avant (60 cm), à pied, en vol ou à la nage, en glissant le long si un seul côté manque ; au-dessus d'un sol pas prêt, on attend sur place sans tomber. Après un court moment : « Chargement du terrain… ». Cette colonne passe en tête de la file.
- **Ouverture d'un monde** : les 8 colonnes autour du point d'arrivée sont construites tout de suite (on peut marcher dès la première image ; ouverture environ 0,5 s plus longue sur PC).
- **Calcul du terrain repris où il en était** quand une autre colonne passe devant (avant : recommencé).
- **Beauté** (demande de l'utilisateur) : distance d'affichage 16 zones et lointain +24 (avant : 8 et +16, comme Équilibré, qui reste le défaut).
- Retiré : le plus grand budget pour une colonne voisine (0.0.7.21 après publication) : mesuré, des images de 8 ms ralentissaient tout (forêt 300 → 210 images par seconde) ; la colonne voisine garde tout le budget normal de l'image.

Tests réussis : loaded_edge (nouveau : arrêt au bord, file, message, pas de chute, on repart), les tests qui déplacent le joueur (34) et les tests touchés (+ tests juridiques). Mesures : forêt 305 images par seconde, en vol à 15 m/s aucune colonne proche en retard.
À tester manuellement : voler vite loin dans un monde neuf.
Une erreur rare (« Nil » dans une liste de points) est apparue une fois en lançant plusieurs tests ensemble, pas reproduite ensuite.

## 0.0.7.21 — Qualité d'affichage en tête de Vidéo (Performance, Équilibré, Beauté), ombres et anticrénelage réglables, distance lointaine en plus de la distance d'affichage (« +16 »), herbe « Réduite », travail de fond dans un budget par image (300 images par seconde en forêt), arbres intacts dessinés en série, branches des arbres calculées d'avance, garde-fou de vitesse, Jouer du launcher sur plusieurs lignes
Version publiée (sur demande). Génération inchangée (version 32).
- **Qualité d'affichage** (Paramètres → Vidéo, en premier, demande de l'utilisateur) : *Performance* (le plus rapide), *Équilibré* (défaut sur PC), *Beauté* (l'affichage d'avant) ; *Personnalisé* dès qu'on change à la main un de ses réglages. Elle règle d'un coup la densité et la distance de l'herbe, les distances d'affichage, les ombres et l'anticrénelage. Sur le Web : Performance par défaut.
  - Équilibré : ombres jusqu'à 48 m (avant 64), herbe « Réduite » (140 brins au lieu de 200), mêmes distances.
  - Performance : ombres 32 m en un seul niveau, herbe basse sur 24 m, distance 6 zones, lointain 16, sans anticrénelage, arbres simplifiés dès 28 m.
- **Nouveaux réglages** : *Ombres* (Proches, Moyennes, Loin), *Anticrénelage* (Oui, Non), herbe *Réduite*.
- **Distance lointaine** (demande de l'utilisateur) : affichée en plus de la distance d'affichage, de « +0 » à « +48 » (« +16 » par défaut) ; un ancien réglage (au total) est repris tel quel (32 avec une distance de 16 : « +16 »).
- **Travail de fond dans un budget par image** (terrain, arbres, lointain) selon la limite d'images par seconde (avant : jusqu'à 15 ms en tout, ce qui faisait passer sous 100 images par seconde en marchant). Les colonnes proches du joueur passent d'abord. Mesures (PC, sans limite) : forêt 140 → 300 images par seconde, images sous 100 par seconde en marchant 118 → 6 ; en vol à 15 m/s, le sol autour est toujours prêt.
- **Arbres intacts dessinés en série** : par colonne et par modèle, un dessin pour tous ; un arbre reprend ses propres modèles dès qu'on le coupe ou qu'il tombe.
- **Branches des arbres calculées d'avance** (assets/trees/squelettes, tools/squelettes.gd) : plus d'à-coup de 40 à 100 ms à la première coupe de chaque sorte d'arbre.
- **Garde-fou de vitesse** (tests/perf_guard_test.gd) : en traversant une forêt, le travail de fond reste dans son budget, rien ne bloque une image et le monde suit.
- Outil de mesure : temps de calcul et d'affichage séparés, vol rapide, monde entièrement construit.
- **Launcher** : le bouton « Jouer » passe à la ligne quand le nom de la dernière version est long (la flèche ▼ sortait de l'écran).

Tests réussis : quality (nouveau, 13 vérifications), perf_guard (nouveau), trees (arbres en série, squelettes enregistrés = calculés), tree_fall, tree_stress, breaking, run et les tests touchés (+ tests juridiques). Captures hors écran : Beauté, Équilibré, Performance.
À tester manuellement : choisir chaque qualité dans Vidéo ; couper un arbre (il quitte la série sans clignoter) ; voler vite.

## 0.0.7.20 — Plus fluide : terrain calculé en petites étapes (plus d'à-coups en forêt), arbres créés peu à peu avec des ombres simplifiées, accueil deux fois plus rapide (forêt de pins, personnages au sol et chargés à la demande), shaders préparés d'avance sur le Web
Version publiée (4 sur 4). Génération inchangée (version 32) : les mondes restent exactement les mêmes.
- **Terrain en petites étapes** (scripts/surface_job.gd) : la surface d'une zone se calcule en morceaux de 3 ms au plus par image (avant : 27 à 160 ms d'un coup, surtout près des grottes). Résultat identique, vérifié zone par zone.
- **Arbres créés peu à peu** : en se déplaçant, quelques arbres par image (avant : tous ceux d'une colonne d'un coup, jusqu'à 100 ms en forêt). À l'ouverture et autour du joueur, tout de suite.
- **Ombres des arbres simplifiées** : de près, l'ombre vient du modèle simplifié (tronc, grosses branches, quelques grandes plaques de feuillage, environ 7 fois moins de sommets). Un arbre coupé ou couché garde l'ombre de son modèle détaillé.
- **Accueil** : première image en 1,5 s au lieu de 3,4 s ; le petit monde se construit ensuite, sans gel (les montagnes, lacs, rivières, crevasses et grottes de sa graine, environ 2 s d'un coup avant, se calculent en petites étapes, même résultat). **Forêt de pins** en fond (pins du jeu, dessinés en série, simplifiés au loin). Le renard et le lapin restent **au sol** (plus de vol).
- **Personnages à la demande** : à l'accueil, seulement ceux de la vitrine ; les autres se lisent en ouvrant les Paramètres, un par image, celui du joueur d'abord. Les aperçus de la page Personnage se montent quand on la regarde.
- **Accueil calme** (PC) : les modèles d'arbres se préparent d'avance, un par image ; ouvrir un monde arrête tout de suite.
- **Web** (rendu Compatibility) : à l'ouverture d'un monde, chaque sorte de modèle est dessinée une fois, invisible, pour préparer ses shaders (mesuré sur PC en rendu Web : pire image en marchant 263 → 26 ms). Pas sur PC, où Godot les prépare déjà.
- Mesures (PC sur secteur, tools/mesure_perf.gd) : marche en forêt 45–51 → 139 images/s, images de plus de 50 ms 89–115 → 0.

Tests réussis : surface_job (nouveau : zones par étapes = d'un coup ; graine par étapes = d'un coup, deux graines), character (modèles lus à la demande), menu_style (vitrine : pins en série, personnages au sol, sol construit après la première image) et les tests touchés (+ tests juridiques).
À tester manuellement : l'accueil (forêt de pins), marcher en forêt, les ombres des arbres de près ; la version Web (demander à Claude Code web de la mesurer).

## 0.0.7.19 — 4 kg par main et 8 kg à deux, volume (1,5 L et 3 L), nombre au plus par main (8 noisettes…), barres de poids et de volume, refus expliqués
Version locale (3 sur 4). Génération inchangée (version 32).
- **Poids** (demande de l'utilisateur) : 4 kg par main, 8 kg à deux mains ; au-delà de ce que tient une main, l'objet se porte à deux mains et la marche ralentit (jusqu'à 60 % à 8 kg). Poches : 500 g.
- **Volume** : 1,5 L par main, 3 L à deux mains, 0,5 L dans les poches. Une poignée de terre ou de sable : 0,25 L (12 poignées à deux mains). Le bois compte par sa longueur (1 L par mètre) : un bâton de 3,5 m est trop encombrant, une bûche de 15 cm × 60 cm (8 kg) se porte à deux mains.
- **Nombre au plus par main** (petits objets qui tomberaient) : 8 noisettes, 2 pommes, 4 cailloux ou éclats (le double à deux mains).
- **Refus expliqués** : « Trop lourd », « Trop encombrant » ou « 8 noisettes au plus dans une main ».
- **Barres** comme la batterie d'un téléphone, avec le pourcentage dedans : vert, jaune dès 60 %, orange dès 80 %, rouge à 100 %. En jeu (en bas à droite) : la petite image de la main ou de la poche, une barre (la limite la plus proche, kg ou L) et le texte un peu plus petit. Dans l'inventaire : le texte (poids et volume), puis dessous, centrées, deux petites barres côte à côte (poids à gauche, volume à droite).
- Poids des matières inchangés (une poignée réelle) ; une poignée remplit toujours une sous-cellule (règle de jeu).

Tests réussis : inventory (105 vérifications : 12 poignées à deux mains, 8 kg au plus, noisettes 8 et 16, bâton de 3,5 m refusé, bûche de 8 kg à deux mains, textes, barres) et les tests touchés (+ tests juridiques). Captures hors écran : barres en jeu et dans l'inventaire.
À tester manuellement : ramasser jusqu'aux limites en Survie, lire les messages ; marcher chargé.

## 0.0.7.18 — Onglet Bois en Créatif (un tronc et une branche de chaque arbre), bois nommé selon son arbre
Version locale (2 sur 4). Génération inchangée (version 32).
- **Onglet Bois** (Créatif, après Outils, demande de l'utilisateur) : pour le pommier, le noisetier, le pin et le tilleul, un **tronc** (20 cm d'épaisseur, 18 cm au petit bout, 1 m) et une **branche** (4 cm, 1 m), séparés, illimités, toujours les mêmes. Sous chaque case, le nom de l'arbre ; le nom complet au survol.
- **Bois nommé selon son arbre** partout : « Tronc de pin », « Branche de noisetier » (comme les rameaux, « Tige de noisetier »).

Tests réussis : inventory (onglet Bois : 8 objets, tailles, noms, image de l'onglet) et les tests touchés (+ tests juridiques). Capture hors écran : onglet Bois.
À tester manuellement : prendre un tronc de l'onglet Bois, le poser, le recasser.

## 0.0.7.17 — Menu des actions (B + T) : clic gauche Creuser / Casser, Casser / Récupérer des objets, Récupérer des matériaux ; clic droit Poser, Aplanir, Lisser
Version locale (1 sur 4). Génération inchangée (version 32).
- **Menu des actions** (scripts/action_menu.gd, demande de l'utilisateur) : B + T ouvre deux lignes de cases au-dessus de la barre d'objets. En haut, le **clic gauche** : *Creuser / Casser* (creuse le terrain, coupe le bois visé), *Casser / Récupérer des objets* (ne creuse jamais : clic maintenu = casser, clic court = ramasser), *Récupérer des matériaux* (clic maintenu = une poignée de terre, de sable…). En bas, le **clic droit** : *Poser*, *Aplanir*, *Lisser*.
- Chaque case : une petite image et un petit texte, juste assez large pour tout le texte. La ligne active est claire, la case choisie entourée de jaune.
- **Molette** : choisir (aussitôt pris en compte) ; **T** (ou B + T) : l'autre ligne ; **un clic, Échap ou Entrée** ferment le menu (Échap n'ouvre pas la pause), ou **un moment sans rien** (2,5 s). R reste le raccourci pour ramasser, R + I pour une poignée.
- La ligne d'aide en haut à gauche rappelle ce que font les deux clics.

Tests réussis : action_menu (nouveau, 23 vérifications : disposition, molette, T, fermeture, seul Creuser creuse) et 17 autres tests touchés (+ tests juridiques). Captures hors écran : menu ouvert sur chaque ligne.
À tester manuellement : B + T en jouant, molette, T, Échap (sans pause) ; clic court sur un caillou ou un bâton en mode Casser / Récupérer ; clic maintenu sur la terre en mode Récupérer des matériaux (Survie).

## 0.0.7.16 — Petit plafond de terre qui tient (galeries de 2 m), petit bout de tronc entre deux coupes proches enfin à part, anciens arbres réparés à l'ouverture
Version publiée (avec 0.0.7.13 à 0.0.7.15). Génération inchangée (version 32).
- **Petit plafond de terre** (l'utilisateur : le plafond d'une grotte s'est effondré en chaîne) : la terre et l'argile sans rien dessous tiennent si un mur porté est à 1 m au plus sur le côté. Une galerie de 2 m de large garde son plafond ; au milieu d'une grande salle, la terre tombe. Le sable, la boue, la neige et le gravier tombent toujours.
- **Petit bout de tronc** (monde T56, pin coupé deux fois à 15 cm d'écart) : sans triangle ni branche entre les deux coupes, la seconde coupe restait vide et le petit bout collé au haut couché (impossible à ramasser). Départage corrigé (pièce la plus profonde, puis coupe la plus loin) ; vérifié sur tous les arbres, tailles et formes (2 221 essais de coupes à 6 cm).
- **Anciens arbres réparés à l'ouverture** : dans une sauvegarde d'avant, la coupe restée vide est retirée (l'arbre reste tel qu'on le voyait) ; on peut ensuite recouper.
- Vérifié sur une copie du monde T56 (l'original n'est pas touché) : pin réparé, recoupé : bûche de 15 cm au sol, haut à part.

Tests réussis : smooth_terrain (galerie de 1 m qui tient, salle de 4 m dont le milieu tombe, sable en plafond qui tombe), tree_stress (483 vérifications), tree_fall et les tests touchés (+ tests juridiques).
À tester manuellement : creuser une galerie et une grande salle dans la terre ; recouper un petit bout de tronc. En Survie, un tronc épais même court reste trop lourd pour les mains (bûche de 15 cm d'un pin de 33 cm : 9,4 kg).

## 0.0.7.15 — Arbres tombés posés comme en vrai (léger sur ses branches, lourd sur son tronc), bois juste entre deux coupes proches, pas deux coupes au même endroit, test d'endurance
Version locale (3 sur 4). Génération inchangée (version 32).
- **Comme en vrai** (demande de l'utilisateur) : un arbre **léger** (noisetier, taille 1) couché garde son bout lourd (pied ou bout coupé) au sol et ne penche qu'autant que ses branches l'exigent (20° au plus ; au-delà, elles plient). Un arbre **lourd** (tailles 2 à 5) repose sur son tronc : ses branches du dessous s'écartent nettement sur les côtés. Fini le soulèvement d'un bloc qui laissait un bout en l'air.
- **Reposé après chaque coupe** : un morceau couché qui perd les branches qui le portaient se repose (avant : il restait en l'air, de 25 cm à 1 m).
- **Bois juste entre deux coupes proches** (trouvé dans le monde T56 de l'utilisateur, lu sans le modifier) : un tronçon de 23 cm devenait un tronc de 9,5 m. Les bouts de chaque morceau se calculent maintenant d'une coupe à l'autre.
- **Pas deux coupes au même endroit** (moins de 5 cm sur la même pièce) ni tout au bout : plus de morceau vide.
- **Test d'endurance** (tests/tree_stress_test.gd, nouveau) : 12 arbres (4 espèces, tailles 1 à 3) abattus en hauteur, recoupés couchés (coupes proches comprises), branches cassées, bois recassé ; après chaque geste : rien de perdu ni en double, aucun bois plus grand que son arbre, aucun morceau vide, aucun morceau couché en l'air ; noisetier tombé sur un obstacle : penché, un bout porté, l'autre au sol.

Tests réussis : tree_stress (477 vérifications, nouveau), tree_fall (54) et les tests touchés (+ tests juridiques). Captures hors écran : petit pommier couché (pied au sol), gros pommier couché (tronc au sol, branches écartées), pommier coupé couché (bûche à côté, haut au sol).
À tester manuellement : abattre et recouper un noisetier et un petit pommier ; regarder qu'aucun bout ne flotte ; recasser une bûche.

## 0.0.7.14 — Recasser le bois au sol là où on vise, plus de trou en cassant un tronc, de nouveau 40 cm à mains nues
Version locale (2 sur 4). Génération inchangée (version 32).
- **Recasser le bois au sol** : clic gauche maintenu sur un tronc, une branche, un bâton ou un rameau au sol (temps selon l'épaisseur au point visé) : il se coupe en deux là où on vise. Chaque moitié garde sa vraie longueur, ses épaisseurs (gros bout et petit bout), son essence, son âge et sa souplesse ; poids selon son volume. Un rameau garde ses feuilles sur la moitié fine (l'autre devient une branche ou un tronc). Pas à moins de 5 cm d'un bout.
- **Plus de trou en cassant un tronc** (l'utilisateur : « parfois ça creuse ») : viser du bois au sol, ou une branche devant le sol, ne creuse jamais.
- **De nouveau 40 cm au plus à mains nues** (80 cm rendait la future hache inutile), 2,5 s par tranche de 10 cm (40 cm : 10 s).
- CLAUDE.md : prévenir avant d'exécuter une demande incohérente ou moins bonne qu'une autre ; ne jamais commencer avant « vas-y ».

Tests réussis : tree_fall (54 vérifications : bâton et tronc au sol recassés, longueurs, épaisseurs et poids des moitiés, feuilles sur la moitié fine, jamais de trou, 40 cm et 10 s…) et les tests touchés (+ tests juridiques). Capture hors écran : tronc et rameau au sol coupés en deux.
À tester manuellement : recasser un tronc puis une moitié ; viser un tronc posé sur l'herbe sans creuser.

## 0.0.7.13 — Vrai diamètre des branches et du bois coupé, mains nues jusqu'à 80 cm (2,5 s par 10 cm), morceaux tombés qui ne flottent plus
Version locale (1 sur 4). Génération inchangée (version 32).
- **Vrai diamètre** (captures de l'utilisateur : bois au sol plus petit que la souche, faces de coupe trop grandes) : l'épaisseur d'une branche ou d'une tige est mesurée par une vraie tranche de cette seule pièce (largeur la plus petite), plus par la distance moyenne à son axe, qui doublait presque sur une branche courbée. Sert au temps de coupe, aux faces claires, au bois au sol et à sa collision.
- **Bois au sol** : toujours le même modèle de bâton pour tous (dessiné en série, léger), à la vraie longueur et au vrai diamètre du morceau, à sa place.
- **Mains nues jusqu'à 80 cm**, 2,5 s par tranche de 10 cm (80 cm : 20 s).
- **Morceau tombé qui ne flotte plus** : posé sur ses branches d'après 90 % de ses points (une branche dans un rocher ne soulève plus tout), 50 cm au plus.

Tests réussis : tree_fall (45 vérifications : bûche au vrai diamètre du tronc et à sa place, 80 cm et 2,5 s par 10 cm…) et les tests touchés (+ tests juridiques). Captures hors écran : souche, haut tombé à côté, faces de coupe à la taille du tronc, rameau au sol.
À tester manuellement : couper un petit arbre près d'un rocher ; comparer la bûche au sol et la souche.

## 0.0.7.12 — Couper seulement la branche ou la tige visée, souche, une seule tige de noisetier, rameaux avec feuilles, coupe visible, tige tombée posée sur ses branches
Version publiée (avec 0.0.7.11). Génération inchangée (version 32).
- **Couper seulement ce qu'on vise** (scripts/tree_parts.gd) : dans les modèles Blender, chaque tronc, tige et branche est un tube séparé ; on vise la vraie branche (plus seulement le tronc), et seule elle est coupée, à l'endroit visé, avec ses petites branches et ses feuilles. Plus tard, la hache en coupera plusieurs d'un coup.
- **Branche cassée = rameau au sol**, à sa vraie taille : « Tige de noisetier », « Rameau de pommier », de pin, de tilleul ; un même petit feuillage pour tous (icône et au sol). Sans feuilles : un bâton (branche ou tronc).
- **Abattre à la hauteur visée** : près du pied (moins de 50 cm), l'arbre tombe depuis la racine ; plus haut, une souche reste debout (coupe nette, face claire) et le haut tombe depuis la coupe.
- **Noisetier** : une seule tige tombe, celle qu'on vise ; les autres restent debout.
- **Coupe visible** : face de bois clair sur chaque coupe ; arbre couché coupé : le morceau écarté de 40 cm et tourné de 20° (12 cm se cachaient dans les feuilles).
- **Tige ou haut tombé posé sur ses branches** (avant : feuillage écrasé à plat) ; une tige légère (moins de 8 cm) presque sans plier.
- Gardé dans objets.json (« arbres_branches »). Les arbres coupés en 0.0.7.9 à 0.0.7.11 gardent l'ancienne coupe.

Tests réussis : tree_fall (44 vérifications : chute depuis la racine, pied nu = bûche à sa taille, coupe au point visé, écart et tour, branche seule = rameau nommé et dessiné, une tige de noisetier, souche à la hauteur de la coupe, monde rouvert, ramassé avec R, 40 cm au plus) et les tests touchés (+ tests juridiques). Captures hors écran : souche nette, branche cassée, noisetier avant et après, tige couchée sur ses branches.
À tester manuellement : casser une brindille de noisetier et voir le rameau au sol puis dans l'inventaire ; abattre un pommier à hauteur de poitrine ; une tige de noisetier ; rouvrir le monde. Dans la main, le rameau est encore dessiné comme un bâton (sans feuilles).

## 0.0.7.11 — Couper à mains nues jusqu'à 40 cm (5 s par 10 cm), tronc devenu du bois ramassable, bois à sa vraie épaisseur
Version locale (publiée avec 0.0.7.12, à la demande de l'utilisateur). Génération inchangée (version 32).
- **Couper à mains nues jusqu'à 40 cm** (avant 30 cm) ; temps : 5 s par tranche de 10 cm (40 cm : 20 s).
- **Le tronc devient du bois** : les petits arbres ont des rameaux feuillus dès 40 cm, donc le bas du tronc restait entier. Maintenant, un morceau coupé qui porte moins de 10 % des feuilles de l'arbre devient aussitôt un tronc ou une branche au sol, à ramasser avec R.
- **Bois à sa vraie épaisseur** : le gros bout est mesuré à 30 cm du pied au moins (avant, dans l'évasement des racines).

Tests réussis : tree_fall (40 cm et 20 s, tronc avec quelques rameaux = bois, coupe au point visé, morceaux qui se suivent, bois + reste = longueur de l'arbre, épaisseur hors racines), trees, menu, prototype, history_resume (+ tests juridiques).
À tester manuellement : couper un petit pommier couché vers 1 m et ramasser le tronc avec R ; couper un tronc de 30 à 40 cm à mains nues.

## 0.0.7.10 — Main gauche, porter à deux mains (case double), ramasser dans l'autre main, couper jusqu'à 30 cm, nom automatique, statistiques du monde
Version locale (3 sur 4). Génération inchangée (version 32).
- **Main gauche** à la première personne : la main droite en miroir (pouce en haut), sans Blender. En Survie, la case 1 est dans la main gauche, la case 2 dans la main droite ; une poche choisie : son objet sorti dans la main droite si elle est libre. En Créatif : l'objet choisi dans la main droite.
- **Porter à deux mains** : un objet de plus de 1,5 kg prend les deux mains : une seule case double dans la barre et dans l'inventaire (une case de moins), les deux mains glissent vers le centre et tiennent l'objet entre elles.
- **Ramasser (R)** : dans la case choisie ; si elle est pleine, dans l'autre main libre (la droite d'abord), au lieu d'être refusé.
- **Couper à mains nues jusqu'à 30 cm** (avant 15 cm) ; temps : 8 s par tranche de 10 cm (30 cm : 24 s). Mesure toujours au-dessus de l'évasement des racines (vérifiée : même valeur tout autour du tronc).
- **Nom automatique** : un monde créé sans nom prend le suivant de la série T (T56 après T55), montré en gris dans le champ.
- **Statistiques du monde** (statistiques.json, dans son dossier) : version qui l'a créé, dernière ouverture (date, heure, version), nombre d'ouvertures, temps de jeu (pauses non comptées), dans Pause → Infos du monde. Anciens mondes : « inconnue » jusqu'à leur prochaine ouverture.

Tests réussis : world_stats (nouveau, 7 vérifications), inventory (case double, autre main), tree_fall (30 cm, 8 s par 10 cm) et les autres tests touchés (+ tests juridiques). Captures hors écran : deux mains en Survie, objet lourd à deux mains, inventaire avec case double.
À tester manuellement : tenir des objets dans chaque main, ramasser un objet lourd puis le lâcher (mains qui reviennent), couper un tronc de 20 à 30 cm, créer un monde sans nom, statistiques après une partie.

## 0.0.7.9 — Couper en deux là où on vise, temps selon l'épaisseur, arbres posés sur leurs appuis, pas de vol en Survie, terre sur rocher, travois au sol, noms dans l'inventaire Créatif
Version locale (2 sur 4). Génération inchangée (version 32).
- **Couper en deux** un arbre couché, à l'endroit visé (tous les arbres, plus seulement les petits) : chaque morceau garde sa vraie forme et sa taille. Un morceau sans feuilles devient aussitôt un tronc (ou une branche) au sol, à sa longueur et à son épaisseur exactes ; un morceau avec branches et feuilles reste couché et peut être recoupé. Gardé dans objets.json (« arbres_tombes » : coupes et morceaux devenus du bois).
- **Temps de coupe selon l'épaisseur** du bois visé : 8 s pour 10 cm, 8 s × (épaisseur / 10 cm)^2,5 (15 cm : environ 22 s) ; plus de 15 cm : impossible à mains nues (message) ; Créatif : 1 s. L'épaisseur est celle de la tige visée (une touffe de noisetier compte tige par tige).
- **Arbre couché sur ses appuis** : tronc rigide posé sur ses points les plus hauts (bosse, tas de terre, rocher), jamais dans le sol ; branches du dessous écrasées vers les côtés, sans soulever le tronc. Mesure du vrai sol (terrain creusé ou posé, rochers) ; grille du sol corrigée (elle restait parfois vide).
- **Pas de vol en Survie** (le vol s'arrête en passant en Survie).
- **Terre sur un rocher** : elle reste posée (avant : elle tombait à travers et disparaissait).
- **Travois** : icône vue de côté, le bout arrière traîné sur le sol.
- **Inventaire Créatif** : le nom sous chaque objet (onglets et cases).
- **Corrections après essai** : seul le tronc est solide (on s'approche et on entre dans la couronne couchée ; une tige invisible permet encore de viser pour couper) ; fente de 12 cm entre deux morceaux (la coupe se voit) ; bois coupé à sa vraie épaisseur, gros bout et petit bout (mesure par tranche du modèle : l'ancienne donnait environ 18 cm au lieu de 60 pour un pommier moyen) ; mesure du sol de secours exacte.

Tests réussis : tree_fall (26 vérifications : épaisseur, temps, chute, appuis, coupe en deux, approcher la couronne, fente, taille du bois, réouverture, 15 cm au plus), trees, inventory, fly, game_mode, smooth_terrain, breaking, step_over, world_save, forests, plants, interface_info, catalog_restart (+ tests juridiques). Captures hors écran : arbre coupé en deux puis recoupé, inventaires Créatif et Survie, travois.
À tester manuellement : couper en jouant (viser le tronc, puis la couronne), arbre tombé sur une bosse ou un tas, terre sur un rocher, ramasser un long tronc coupé.

## 0.0.7.8 — Abattre et couper les arbres, bâtons, porter lourd, poser partout, anneau de chargement, troncs solides
Version locale (1 sur 4). Génération inchangée (version 32).
- **Abattre** : clic gauche maintenu sur un arbre, 8 s à mains nues (1 s en Créatif) ; il tombe vers le joueur (#229 pour la vie, plus tard).
- **Arbre couché** : branches et feuilles repoussées hors du sol, fruits déplacés avec elles (toujours cueillables) ; glisse sur une pente raide ; reste tombé (objets.json « arbres_tombes »).
- **Couper** un arbre tombé de taille 1 à 3 (8 s) : un tronc et 3 à 7 branches au sol (« arbres_coupes ») ; les gros restent couchés.
- **Bâtons** (tronc, branche) : épaisseur, longueur, essence, âge (1 à 5), souplesse (1 à 5), poids ; effets plus tard (#228). Icône, dans la main, au sol avec l'écorce de l'arbre ; ramassés avec R.
- **Porter lourd** : mains 3 kg ; au-delà de 1,5 kg dans une main, à deux mains (l'autre grisée) ; marche jusqu'à 40 % plus lente ; plus de 3 kg : ne se ramasse pas.
- **Poser partout** : terre et autres matières aussi sur un rocher, un caillou ou un bloc.
- **Anneau de chargement** autour de la croix (abattre, couper, R + I) ; plus de pourcentage écrit.
- **Troncs solides** : la collision des arbres était ignorée (on les traversait) ; corrigé.

Tests réussis : tree_fall (nouveau, 14 vérifications), inventory (100), et 36 autres (déplacement, arbres, terrain, interface) (+ tests juridiques). Captures hors écran : anneau, chute, arbre couché, bâtons.
À tester manuellement : abattre et couper en jouant, glissade sur une vraie pente, porter un tronc (lenteur), poser de la terre sur un rocher.

## 0.0.7.7 — Enjamber, pentes plus lentes, équipement à venir
Version publiée (4 sur 4 : avec 0.0.7.5 et 0.0.7.6). Génération inchangée (version 32).
- **Enjamber** : un obstacle bas devant soi (caillou, marche du terrain), jusqu'à 45 cm, se passe en avançant, sans sauter ; la vue suit en douceur. Plus haut (ou une pente) : on monte en marchant ou on saute.
- **Pentes raides** : en montée, on marche moins vite (jusqu'à moitié moins près de la pente la plus raide qu'on puisse monter) ; en descente et de côté, vitesse normale.
- **Équipement à venir** (écran d'inventaire en Survie, à droite) : 2 cases Sac, 2 Panier, 2 Travois (deux bâtons qu'on traîne), 2 Chariot (à roues), grisées, avec leur silhouette ; leurs cases de contenu apparaîtront en bas à gauche quand on les portera.
- Issues pour plus tard : animations des bras (#224, #225, série 0.0.8) et des jambes et des pattes (#226, #227, série 0.0.9) ; écran de ce qu'on porte (#219) et objet en main en vue de derrière (#201) en 0.0.8.

Tests réussis : step_over (nouveau : pentes, caillou enjambé, mur bloquant), inventory (équipement), et 35 autres (déplacement, contrôles, interface, arbres, terrain) (+ tests juridiques). Capture hors écran : écran de Survie avec l'équipement.
À tester manuellement : enjamber des cailloux et des marches en jouant, monter une pente raide, sur le Web aussi.

## 0.0.7.6 — Une main qui tient l'objet, poids réalistes
Version locale (2 sur 4, correction demandée par l'utilisateur). Génération inchangée (version 32).
- **Main à la première personne** (#201) : main droite en bas à droite, petite, faite dans Blender (sources_blender/main/generer_main.py → assets/hands/main_droite.glb), couleur de peau du personnage ; elle tient l'objet choisi (petit tas de terre ou de sable, caillou, éclat, pomme, noisette) et bouge un peu quand on creuse ou qu'on pose. Pioche : son propre dessin, la main est cachée.
- **Pentes** : on monte un peu plus facilement les petites pentes (jusqu'à 52° au lieu de 45°), et on reste collé au sol en descente.
- **Tout se pose** : le gravier se pose enfin (oublié en 0.0.7.3) ; matières dans le terrain, cailloux, éclats et fruits au sol ; la pioche ne se pose pas.
- **Poids plus réalistes** (une grosse poignée d'environ 0,25 L × la densité) : terre 325 g, sable et boue 400 g, gravier 440 g, argile 450 g, pierre, calcaire et silex 650 g, pierre sombre 750 g. Mains : 1,400 kg en tout ; caillou de taille 6 : 1,100 kg, il se ramasse maintenant.
- **Silex** : l'icône du rognon a l'aspect des rognons du monde (blanchâtre, taches sombres), toujours la même.
- **Fruits reposés identiques** : une pomme ou une noisette cueillie garde sa vraie taille dans l'arbre ; au sol et dans la main, même petit modèle que dans l'arbre (avec le dégradé rouge et jaune).
- **Contrôles → Arrêter de voler au sol** : Exception (par défaut, à gauche) : en volant, descendre jusqu'à toucher le sol arrête le vol ; Toujours : on vole encore au sol.

Tests réussis : inventory (main, gravier, taille 6, diamètre des fruits), fly (Exception et Toujours), trees, forests, smooth_terrain, controls, controls_groups, key_combos, crouch_mode, run_mode, shortcuts_selection, prototype, action_timing, window_resize, fps_creation, display_settings, breaking, reach, game_mode, menu, body, character, jump_profile, crouch, swim, settings_walk, interface_info, pause, pause_settings, history_resume (+ tests juridiques). Captures hors écran : la main avec terre, pomme, silex, sable, main vide.
À tester manuellement : monter les pentes, place et taille de la main en jouant, vol qui s'arrête au sol.

## 0.0.7.5 — Objets uniques, cueillette, pommes de toutes les couleurs
Version locale (1 sur 4, correction demandée par l'utilisateur). Génération inchangée (version 32) ; les mondes gardent les mêmes arbres.
- **Chaque objet garde toutes ses caractéristiques** (taille, forme, orientation, poids, couleur, coups reçus), ramassé, porté, reposé ou sauvegardé : un rognon de silex reposé est le même qu'avant. Des objets du même type mais de tailles différentes vont dans la même case, chacun gardé à part ; le dernier pris est le premier reposé. Cailloux et éclats au sol ont le rendu des cailloux du monde.
- **Ramasser (R) et récupérer (R + I) remplissent la case choisie** de la barre ; si toute la barre est pleine, une case libre de l'inventaire ; si seule la case choisie est prise : message, l'objet reste au sol.
- **Cueillir** (Survie et Créatif) : R en visant vraiment une pomme ou une noisette dans un pommier ou un noisetier (rien à travers le tronc). Le fruit disparaît de cet arbre seulement ; sauvegardé dans objets.json (« fruits_cueillis »).
- **Pommes en trois tailles** (7,5, 10,5 et 13 cm ; la taille 2, la normale, un peu plus grande qu'avant) et **cinq couleurs** : verte, rouge, jaune, brune, moitié rouge moitié jaune. Pommes et noisettes refaites dans le jeu en petits fruits lisses, dessinés en série (un même petit modèle pour tous : léger).
- **Créatif** : onglets en images Matériaux naturels (un seul tas de pierre, terre et sable), Cailloux (pierre, calcaire, silex, taille 4), Fruits (pomme rouge, noisette), Outils, et tout à droite Inventaire (un petit sac) : la grille de 5 lignes n'apparaît que là ; sinon les objets de l'onglet et la barre.
- Anciennes sauvegardes (0.0.7.3, 0.0.7.4) relues : cailloux et éclats deviennent des objets uniques.

Tests réussis : inventory (92 vérifications : caractéristiques gardées, piles, case choisie, cueillette en visant, onglets), trees (modèles sans fruits, fruits retrouvés), forests, smooth_terrain, shortcuts_selection, prototype, action_timing, window_resize, fps_creation, display_settings, breaking, reach, game_mode, menu, plants, world_consistency, terrain_visuals, history_resume (+ tests juridiques). Captures hors écran : onglets, objets au sol, pommier, pomme de près.
À tester manuellement : cueillir en visant (marge de visée), aspect des pommes dans les arbres et sur le Web.

## 0.0.7.4 — Inventaire plus joli, mains et poches plus grandes
Version publiée (4 sur 4, correction demandée par l'utilisateur). Génération inchangée (version 32).
- **Reposer un objet** : caillou ou éclat en main, clic droit : il est posé au sol là où l'on vise.
- **Poids** : 1 kg pour les deux mains ensemble, 500 g pour les quatre poches ensemble ; cailloux de 50 g à 2 kg selon la taille (inchangés) ; les deux plus gros ne se ramassent pas.
- **Icônes** : de petits tas où l'on voit la texture (grains de sable, mottes de terre, argile fendillée, boue luisante, graviers, morceaux de pierre), galets mouchetés, éclats à facettes ; pioche, main et poche en petits dessins de jeu vidéo. Faites dans le jeu, une seule fois (42 ms pour toutes sur PC), sans fichier à télécharger.
- **Créatif** : onglets en images (cinq petits tas : Matériaux naturels ; la pioche : Outils), le nom en bulle d'aide.
- **Survie, écran O + I** : une ligne pour les mains (image de main, deux cases, « 550,0 g / 1,000 kg » à droite), une ligne pour les poches (image de poche, quatre cases, leur poids).
- **Sous chaque case** : le nom de l'objet, puis son poids (barre en jeu et inventaire). En bas à droite en jeu : poids des mains et des poches, 4 pixels plus grand.

Tests réussis : inventory (71 vérifications : limites de 1 kg et 500 g, reposer au sol, icônes, onglets en images, lignes des mains et des poches), shortcuts_selection, prototype, controls, controls_groups, key_combos, smooth_terrain, trees, breaking, reach, game_mode, pause_settings, pause, settings_walk, interface_info, menu, run_mode, fly, history_resume (+ tests juridiques). Captures hors écran : planche des icônes, Survie en jeu et inventaire, Créatif.
À tester manuellement : clic droit pour reposer un caillou, aspect des icônes et des noms sous les cases sur le Web.

## 0.0.7.3 — Mains, poches et objets au sol
Version locale (3 sur 4). Génération inchangée (version 32). Décision de l'utilisateur du 15.11.2026 (issue #40) : presque pas d'inventaire au début.
- **Survie : deux mains et quatre poches**, plus de grille ni de cases grisées. Barre : case 1 main gauche, case 2 main droite (400 g chacune), cases 3 à 6 les poches (150 g en tout) ; plus tard, sacs et paniers ajouteront des cases (10 au plus). Poids sous chaque case (rien sous une case vide) et total des poches en bas à droite. Poids toujours en 4 chiffres, de 1,000 à 999,9 par unité (mg, g, kg, Mg).
- **Piles** : seuls des objets vraiment identiques s'empilent (même objet, même taille, même poids), selon le poids permis.
- **Creuser en Survie** : la terre, le sable, l'argile, la boue ou le gravier ne donnent pas d'objet : ils sont rejetés derrière soi en petit tas ; jamais dans le trou qu'on creuse, jamais assez haut pour boucher un passage (2 m libres au-dessus) ; mur derrière : sur le côté.
- **Récupérer une poignée** (R et I maintenus, Contrôles → Inventaire) : visée sur un tas ou le sol, une poignée après 1 s (plus long que creuser) ; dans les mains, puis les poches. Poids : sable 120 g, terre 100 g, argile 130 g, boue 150 g, gravier 140 g. **Poser** utilise une poignée par sous-cellule.
- **Pierre cassée à la pioche** (aussi en Créatif) : deux petits morceaux de 125 g par sous-cellule tombent à côté du joueur ; cailloux cassés et rochers creusés aussi. **Ramasser** (R, comme Courir : seulement si un objet est visé) : main gauche, sinon main droite, puis poches ; aussi les petits cailloux et silex du monde (jusqu'à 400 g).
- **Objets au sol** : tout petits modèles, chacun visible à sa place, dessinés ensemble par type ; sauvegardés dans objets.json (« objets_au_sol »). Ce qui ne tient plus dans l'inventaire est posé au sol, jamais perdu.
- **Icônes** : rondes pour les matières (demande de l'utilisateur), ovales pour les cailloux, anguleuses pour les éclats ; nombre dans le coin. Gravier ajouté aux Matériaux naturels.
- Pas encore de pioche en Survie ; pas encore de lancer d'objets.

Tests réussis : inventory (68 vérifications : poids, piles, mains, poches, R, R + I, terre rejetée, morceaux au sol, sauvegarde), shortcuts_selection, prototype, controls, controls_groups, key_combos, smooth_terrain, trees, breaking, reach, game_mode, pause_settings, pause, settings_walk, interface_info, menu, run_mode, crouch, fly, swim, water, history_resume (+ tests juridiques). Captures hors écran : Survie en jeu et inventaire, Créatif.
À tester manuellement : R et R + I au clavier (R fait aussi courir), creuser en Survie près d'un mur ou dans un tunnel, aspect des morceaux au sol.

## 0.0.7.2 — Inventaire et barre d'objets
Version locale (2 sur 4). Génération inchangée (version 32).
- **Plus de choix de matière** : le texte « Bloc sélectionné » en haut à gauche, la molette et les touches 1 à 5 qui choisissaient sable, terre, argile, boue ou pioche sont retirés. On pose seulement ce qu'on a en main.
- **Barre d'objets** : 10 cases en bas au centre, la case en main encadrée. Molette ou touches 1 à 9 et 0 pour changer de case ; le nom de l'objet s'affiche au-dessus.
- **Inventaire** (Contrôles → nouvelle partie Inventaire : O et I en même temps ; fermer : O + I ou Échap) : panneau un peu transparent au centre, le monde visible autour ; grille de 5 lignes × 10 colonnes, puis, plus bas et séparée, la barre. Clic gauche : prendre ou poser (échange si la case est occupée) ; clic droit : vider la case.
- **Créatif** : rien de grisé ; onglets en haut, **Matériaux naturels** (sable, terre, argile, boue, pierre, calcaire, pierre sombre, silex) et **Outils** (la pioche). Objets illimités ; clic droit sur un objet d'un onglet : dans la première case libre.
- **Survie** : tout est grisé sauf les 4 cases de droite de la barre (touches 7, 8, 9, 0). Inventaire séparé de celui de Créatif (chacun est gardé). Pas de pioche en Survie pour l'instant ; pas encore de ramassage (prochaine version : poids, 5 kg au plus).
- Pierre, calcaire, pierre sombre et silex se posent à nouveau.
- **Sauvegarde** : inventaires, barre et case en main dans joueur.json (« inventaire ») ; ancien monde : inventaire vide, sans erreur.

Tests réussis : inventory (nouveau, 42 vérifications), shortcuts_selection, prototype, controls, controls_groups, smooth_terrain, trees, breaking, reach, game_mode, pause_settings, pause, settings_walk, interface_info, key_combos, menu, coordinates, fly, history_resume (+ tests juridiques). Captures hors écran : barre en jeu, inventaire en Créatif et en Survie.
À tester manuellement : O + I au clavier, clics dans l'inventaire et objet qui suit la souris, molette, Échap.

## 0.0.7.1 — Mode de jeu : Survie ou Créatif
Version locale (1 sur 4), première de la série 0.0.7 — Gameplay et inventaire. Génération inchangée (version 32).
- **Paramètres → Monde** (nouvel onglet tout en haut, seulement en partie) : **Mode de jeu**, Survie à gauche, Créatif à droite.
- Propre à chaque monde, enregistré aussitôt (worlds.json : « game_mode » ; monde.json : « mode_de_jeu »). Mondes d'avant et nouveaux mondes : Créatif.
- Pour l'instant le choix est seulement enregistré : il ne change rien au jeu.

Tests réussis : game_mode (nouveau), pause_settings, pause, menu, catalog_restart, developer_return, controls, settings_walk, appearance, character, coordinates, crouch_mode, display_settings, folds, interface_info, key_combos, layout_lines, run_mode (+ tests juridiques).
À tester manuellement : aspect de l'onglet Monde en partie.

## 0.0.6.25 — Web plus fluide
Version publiée (demande de l'utilisateur). Génération inchangée (version 32).
- **Web** : ombres du soleil plus légères (carte de 2048 au lieu de 4096, bords sans adoucissement), 4 fois moins de mémoire graphique pour les ombres ; le PC ne change pas.
- Essai : export Web local lancé dans le navigateur, jeu jouable d'après l'utilisateur (la page d'essais en 0.0.6.24 ne l'était pas).
- À tester manuellement : aspect des ombres sur le Web (si trop pixelisées, revenir à 4096).
## 0.0.6.24 — Lacs en cuvette, rivières plus douces
Version locale (1 sur 4). Fichiers d'eau inchangés ; mondes de la génération 31 identiques (vérifié).
- **Lacs (génération 32)** : en cuvette, le sol descend vers l'eau en pente douce (environ 1 pour 3) sur une vingtaine de mètres, on en ressort à pied (avant : un mur autour des lacs abaissés) ; un lac sur deux a une plage de sable ; moitié moins de petits lacs (moins de lacs, en moyenne plus grands) ; quelques cailloux dans l'eau peu profonde (moins de 80 cm).
- **Rivières** : près d'un lac, elles y entrent tout droit (plus de rivière qui longe le lac derrière un petit mur) et ne reviennent jamais longer leur lac de départ ; sortie du lac de montagne par le passage le plus doux ; pente limitée (1 m pour 2 m) : avant une chute, le lit se creuse plus tôt et descend petit à petit ; le lit est creusé un peu dans les lacs au départ et à l'arrivée (sans eau dessinée en double).
- Mesures (3 graines) : 5 à 10 rivières par monde, toutes depuis un lac de montagne ; berges en l'air environ 1 % ; aucun bord de lac de montagne en l'air ; rives de lacs raides : 1,5 % des pas.
- Reste : une petite cascade quand un lac de montagne est perché au bord d'une pente raide.

Tests réussis : smooth_terrain (nouveau contrôle des lacs), water, swim, custom_generation, world_consistency, trees, forests, plants, history_resume, prototype (+ tests juridiques).
À tester manuellement : marcher autour d'un lac et en ressortir, suivre une rivière de son lac jusqu'en bas.

## 0.0.6.23 — Rivières raccordées aux lacs
Version locale (1 sur 4). Fichiers d'eau inchangés ; mondes de la génération 30 identiques (vérifié).
- **Génération version 31** : les rivières passaient par des vallées plus basses que le lac de plaine où elles arrivent (on voyait leur eau sous le lac). Ce lac est maintenant abaissé jusqu'à l'eau la plus basse de la rivière (6 m au plus, sinon la rivière n'est pas faite ; idée de l'utilisateur) : il est un peu en creux. Les rivières qui se jettent dans une autre ne passent jamais plus bas qu'elle.
- **Raccords** : au départ, l'eau sort 2 cm sous la surface du lac de montagne et y reste en traversant la rive ; à l'arrivée, le ruban s'arrête au bord de l'eau du lac (plus de tache sombre de deux eaux l'une sur l'autre).
- Rivières tracées dès la préparation du terrain (les lacs abaissés comptent partout). 4 à 9 rivières par monde ; berges en l'air : moins de 1 %.

Tests réussis : smooth_terrain (rivières jamais sous leur lac), water, swim, custom_generation, world_consistency, trees, forests, plants, history_resume, prototype (+ tests juridiques).
À tester manuellement : arrivée d'une rivière dans un lac abaissé, départ d'un lac de montagne.

## 0.0.6.22 — Rivières qui partent des lacs (#194)
Version locale (2 sur 4). Fichiers d'eau (niveaux des lacs, eau libre) inchangés.
- **Génération version 30** : chaque lac de montagne donne une rivière, par son exutoire (le point le plus bas de sa rive) ; l'eau sort au niveau du lac et y reste en traversant la rive, puis descend jusqu'à un lac de la plaine ou se jette dans une rivière déjà tracée, au même niveau (plus de rivières qui se croisent). 4 à 11 rivières par monde (avant : 1 à 5, nées « du néant »).
- **Eau qui flottait** : berges plus franches (au bord de l'eau, le sol est déjà au-dessus de la surface ; avant, 25 cm dessous) et berges vérifiées des deux côtés, aussi entre les points du tracé ; arrivée jamais plus haute que le lac. Points de berge en l'air : 40 % → moins de 1 % (seulement en traversant la rive d'un lac).
- Les mondes d'avant gardent leurs rivières.

Tests réussis : smooth_terrain (nouveau contrôle des rivières), water, swim, world_consistency, custom_generation, trees, forests, plants, history_resume, prototype (+ tests juridiques).
À tester manuellement : suivre une rivière de son lac jusqu'en bas, nager à l'exutoire.

## 0.0.6.21 — Arbres de trois formes (#177)
Version locale (1 sur 4).
- **Génération version 29** : chaque arbre des nouveaux mondes prend une de trois formes (même graine = même forme) ; les mondes existants gardent la première.
- **Blender** (sources_blender/arbres) : même charpente et mêmes proportions, branches tirées autrement (forme 1 inchangée) ; la forme 3 du pommier, du pin et du tilleul a un trou ovale dans le tronc (haut d'un rayon de tronc, bourrelet d'écorce, fond sombre), futur abri d'écureuil (#150). Versions détaillées des formes 2 et 3 dans arbres_detail.blend (Archives), légères dans assets/trees (_f2, _f3 ; +20 Mo).
- Mesures (graine de T47) : PC 284 i/s immobile, 260 en marche, 130 en vol (comme avant) ; rendu Web 488 / 433 / 237.

Tests réussis : trees, forests, plants, smooth_terrain, world_consistency, custom_generation, world_options, world_info, interface_info, web_fixes, history_resume, prototype (+ tests juridiques).
À tester manuellement : le trou dans le tronc vu en jeu, variété des forêts.

## 0.0.6.20 — Version Web encore allégée
Publié. Seulement le Web (le PC ne change pas). Mesuré par l'utilisateur en 0.0.6.19 : 15 à 25 images par seconde dans le navigateur.
- Image 3D calculée à 75 % de la taille de la page puis agrandie (presque moitié moins de pixels) ; menus et textes restent nets.
- Herbe peu dense par défaut (Basse ; modifiable dans Vidéo).

Tests réussis : settings_files, display_settings, web_fixes, history_resume, prototype, interface_info, custom_world_menu (+ tests juridiques).
À tester manuellement : images par seconde sur la page publique (après Ctrl + F5).

## 0.0.6.19 — Version Web allégée
Version locale. Seulement le Web (rendu Compatibility) ; le PC ne change pas.
- **Optimisé** : la préparation d'avance des modèles d'arbres (0.0.6.18) est coupée sur le Web, où elle prend 50 à 100 ms par modèle ; ils sont lus quand il faut, comme avant.
- **Allégé** (réglages par défaut du Web, modifiables dans Vidéo) : distance d'affichage 5 zones (avant 6), lointain 12 (avant 16), herbe 2 (avant 3) ; ombres sur un seul niveau jusqu'à 40 m ; pas de lissage des bords (MSAA) ; image à la taille de la page sans multiplier les pixels des écrans haute densité.
- Mesure : le navigateur intégré de l'outil freine la page (une image toutes les 2 s, même sans rien à dessiner) : pas de chiffres fiables ici ; le code d'avant 0.0.6.18 y est aussi lent, la lenteur du Web n'est donc pas due à 0.0.6.18.

Tests réussis : web_fixes, trees, display_settings, settings_files, world_consistency, smooth_terrain, history_resume, prototype (+ tests juridiques).
À tester manuellement : la vraie page Web (images par seconde, chargement), netteté du texte sur un écran haute densité.

## 0.0.6.18 — Jeu plus fluide (#175)
Version locale (1 sur 4 avant la prochaine publication). Même monde, même image (captures avant/après identiques sur PC et Web, à l'herbe agitée par le vent près).
- **Terrain** : calcul des zones 40 % plus rapide (sous-cellules examinées au plus juste, matières lues dans des tables, une seule lecture des caches), sommets partagés (6 fois moins à envoyer à la carte graphique) ; résultat vérifié identique sur 2 783 zones (montagnes, grottes, zones creusées).
- **Plus d'à-coups en vol** : les colonnes qui entrent dans la vue sont relevées peu à peu, celles qui sortent retirées peu à peu ; une étape de terrain commence seulement si elle tient dans le temps de l'image ; le lointain ne prend double temps qu'à l'ouverture ; l'ancien système de blocs ne relit plus le disque.
- **Collisions seulement près du joueur** : terrain (2 zones autour) et cailloux (1 zone autour) ; au loin, seulement le dessin.
- **Cailloux** dessinés par carré de 4 × 4 colonnes (aspect pierre, calcaire ou silex porté par chaque caillou) : 1 825 dessins par image → 225.
- **Arbres** : modèles lus d'avance (en arrière-plan sur PC, une image calme à la fois sur le Web) : plus d'à-coup au premier arbre de chaque sorte.
- Corrigé au passage : une erreur possible pour un point solide à plus d'un mètre au-dessus du sol naturel (poches d'argile).

Mesures (graine de T47, réglages par défaut, même PC ; rendu Web = Compatibility sur ce PC) :

| | PC avant | PC après | Web avant | Web après |
|---|---|---|---|---|
| Ouverture | 1,85 s + blocage 3 s | 1,2 s (pire image 160 ms) | 1,5 s + 470 ms | 1,2 s (pire 100 ms) |
| Immobile | 244 i/s | 273 i/s | 370-400 i/s | 494 i/s |
| Marche | 133 i/s, pire image 610 ms | 268 i/s, pire 18 ms | 258 i/s | 343 i/s |
| Vol 20 m/s | 64 i/s, 46 à-coups (> 33 ms) | 126 i/s, 0 à-coup | 70 i/s, 45 à-coups | 139 i/s, 0 à-coup |
| Dessins par image | 1 300-2 700 | 400-1 130 | 1 150-1 650 | 375-685 |
| Nœuds | 7 000-12 000 | 2 000-3 300 | 5 000-8 000 | 1 800-2 300 |
| Mémoire du jeu | 300-357 Mo | 233-316 Mo | 220-265 Mo | 199-246 Mo |
| Mémoire vidéo | 550-640 Mo | 450-545 Mo | ~100 Mo | 70-75 Mo |
| Processus (pic) | — | 807 Mo | — | 611 Mo |

Tests réussis : smooth_terrain, zones, prototype, breaking, swim, trees, web_fixes, water, plants, forests, body, terrain_visuals, world_consistency, fly, custom_world_menu, menu_style, reach, views (+ tests juridiques).
À tester manuellement : vol rapide et retour en arrière (colonnes qui reviennent), coups de pioche sur les cailloux, sculpter loin de l'apparition ; vraie page Web (navigateur).

## 0.0.6.17 — Monde plus grand, version Web corrigée (#183)
Version publiée (avec 0.0.6.16).
- **Génération version 28** : nouveaux mondes de **96 × 96 zones (768 m de côté)** au lieu de 64 × 64 (512 m) ; montagnes, lacs, déserts, forêts et rivières suivent (même densité, plus de place). Les mondes existants gardent leur taille.
- **Version Web corrigée** : les cailloux et les rochers y ressemblaient à de la terre rayée (dans le rendu Web, le canal de la litière d'aiguilles valait 1 sur les objets qui ne l'ont pas) ; seul le sol lit maintenant ce canal, et le sol plat le porte à zéro.
- **Couleurs du Web alignées sur le PC** (mesurées sur captures des deux rendus) : soleil et saturation du rendu Web réduits, feuillage des arbres et plantes, rivière, lacs, sable et terrain lointain un peu moins clairs, boue et litière moins sombres. Écart restant de moins de 10 % sur l'herbe, les arbres, le ciel, le sable et les rochers.
- **Monde d'essai T47** (graine 3463503054) ; la vitrine de l'accueil le montre.

Tests concernés réussis (taille du monde 768 m, estimations, forêts en proportion, grottes, plantes, arbres). Mesures, même graine, monde de 512 m puis 768 m : ouverture 1,3 → 1,9 s sur PC (1,0 → 1,6 s en rendu Web), mémoire +33 Mo, FPS identiques (vol 83 → 75 sur PC, 87 → 108 en rendu Web) ; 2 768 arbres au lieu de 1 089.
À tester manuellement : la page Web sur itch.io (cailloux, couleurs), traverser un monde de 768 m.

## 0.0.6.16 — Plantes à fibres et lianes (#182)
Version locale (publiée avec 0.0.6.17).
- **Plantes modélisées dans Blender** (sources_blender/plantes/generer_plantes.py, fichier plantes.blend rangé dans ../Archives OrbMeka/Blender), puis rendues en images sur fond transparent (assets/plants) : **ortie** (tiges droites, feuilles en cœur dentées, chatons), **lin** (tiges fines, fleurs bleu ciel), **herbes longues** (feuilles arquées, épis plumeux), **liane** (petites feuilles en cœur sur une tige en zigzag).
- Dans le jeu (scripts/plants.gd) : trois plaques croisées par plante (ortie jusqu'à 1,5 m, lin 1 m, herbes 1,5 m), une MultiMesh par sorte et par colonne, visibles jusqu'à 45 m ; on passe au travers. Liane : deux rubans enroulés en hélice autour du tronc.
- **Génération version 27** (nouveaux mondes ; les autres ne changent pas), par petites taches selon les milieux : **orties** en lisière des feuillus et des vergers et au bord de l'eau ; **lin** dans les prairies et clairières ; **herbes longues** dans les prairies, lisières et clairières ; **lianes** sur environ un tiers des tilleuls du cœur des forêts de feuillus. Jamais dans l'eau, le sable, la boue, le gravier, la neige, la pierre ni sur la litière d'aiguilles. Pas de récolte (série 0.0.6).
- **Monde d'essai T46** (graine 1420169977) ; la vitrine de l'accueil le montre.

Tests concernés réussis (nouveau test « plants » : les trois plantes poussent, bons milieux, jamais dans l'eau ni le sable, lin hors des forêts, orties en lisière ou près de l'eau, lianes sur des tilleuls de feuillus, affichage, génération 26 sans plantes). Mesures en lisière d'une forêt de feuillus, génération 26 puis 27, sans limite d'images : PC 218 → 229 FPS, rendu Web 315 → 312 (pas de coût visible).
À tester manuellement : aspect des plantes de près (les orties restent un peu plates), taches de lin, lianes sur les tilleuls.

## 0.0.6.15 — Sol d'aiguilles et vergers sauvages (#181)
Version publiée (avec 0.0.6.14).
- **Génération version 26** (nouveaux mondes ; les autres ne changent pas).
- **Sol d'aiguilles** sous les pinèdes (un peu en dedans de la lisière) : nouvelle matière « litière d'aiguilles », couche de 20 cm sur la terre, brun-orangé avec de fines aiguilles couchées en tous sens et des taches sombres ; pas d'herbe dessus. Visible aussi au loin (terrain simplifié).
- **Verger sauvage** : troisième sorte de forêt, en plaine (environ 1 forêt de plaine sur 4) : pommiers et noisetiers clairsemés dans l'herbe, de toutes tailles.
- **Monde d'essai T45** (graine 1193425969) ; la vitrine de l'accueil le montre.

Tests concernés réussis (test « forests » : vergers sauvages seulement de pommiers et noisetiers, aiguilles seulement sous les pinèdes et en surface, génération 25 inchangée). Mesures au cœur d'une pinède (même graine), génération 25 puis 26, sans limite d'images : PC 215 → 292 FPS, rendu Web 283 → 338 (moins d'herbe à dessiner).
À tester manuellement : marcher dans une pinède (aspect du sol), trouver un verger sauvage.

## 0.0.6.14 — Grandes montagnes douces (#184)
Version locale (publiée avec 0.0.6.15).
- **Génération version 25** (nouveaux mondes ; les autres ne changent pas) : montagnes plus grandes, 24 à 36 m de haut (20 à 32 avant) et 70 à 115 m de rayon (40 à 70 avant), crêtes moins marquées : pentes moyennes de 0,61 au lieu de 0,77 (environ 31° au lieu de 38°), moins de passages trop raides. Chaînes de montagnes plus douces aussi. Les montagnes raides restent, rares.
- Un peu moins de montagnes (environ 10 de terre par monde), mais elles couvrent plus de sol (30 à 40 %, selon la graine).
- **Pins plus haut** : pins et pinèdes montent jusqu'aux trois quarts des pentes ; environ 30 % des forêts naissent sur les pentes des montagnes (pinèdes).
- Rivières toujours présentes (1 à 3 par monde selon la graine).
- **Monde d'essai T44** (graine 4088120467) ; la vitrine de l'accueil le montre.

Tests concernés réussis (montagnes de la génération 25 plus hautes et plus douces ; forêts, arbres, terrain, eau, mondes anciens : les tests d'anciennes versions gardent leurs anciens réglages de montagnes). Mesures dans la même séance (graine de T43), génération 24 puis 25, sans limite d'images : PC à l'arrêt 685 → 398 FPS, en vol 106 → 93 ; rendu Web 702 → 672 et 166 → 139 (plus de terrain visible avec les grandes montagnes ; large marge avec la limite de 60).
À tester manuellement : monter sur une grande montagne, pinèdes sur les pentes, rivières.
Prochaines étapes décidées : finir les forêts (sol d'aiguilles, verger sauvage), plantes à fibres et lianes (#182), puis agrandir les mondes (#183).

## 0.0.6.13 — Forêts (#138)
Version publiée (avec 0.0.6.10 à 0.0.6.12).
- **Génération version 24** (nouveaux mondes ; les autres ne changent pas) : environ 18 forêts de 25 à 40 m de rayon (un quart du sol), bord irrégulier ; réglage « Forêts » des mondes personnalisés.
- **Deux sortes** : **pinède** au pied et sur les pentes basses des montagnes (seulement des pins) ; **forêt de feuillus** en plaine (grands tilleuls au cœur, noisetiers en sous-bois).
- **Lisières** : arbres plus espacés et plus petits vers le bord ; au bord des feuillus, noisetiers, pommiers et petits tilleuls. **Clairières** d'herbe dans les grandes forêts, parfois avec un grand arbre seul au milieu.
- Arbres sur une grille de 5,5 m un peu décalée, serrés au cœur ; jamais dans l'eau, le sable, la boue ni sur les pentes trop raides (des trous dans la forêt là où elle touche un désert ou un lac). Les arbres isolés et petits groupes restent hors des forêts. Environ 1 260 arbres dans un monde de 512 m.
- **Monde d'essai T43** (graine 2114718997) ; la vitrine de l'accueil le montre.

Tests concernés réussis (nouveau test « forests » : nombre, sortes et taille des forêts, part du sol, espèces du cœur et de la lisière, grands arbres au cœur, densité, clairières, arbres isolés dehors, génération 23 sans forêt). Mesures au cœur d'une forêt, sans limite d'images : PC 330 → 216 FPS (feuillus), 462 → 189 (pinède) ; rendu Web 445 → 299 et 414 → 253 (environ 3 ms de plus par image, large marge avec la limite de 60).
À tester manuellement : se promener dans une forêt et en lisière, clairières, fluidité sur un PC plus faible et sur la page Web.

## 0.0.6.12 — Pins et tilleuls (#146)
Version locale (publiée avec 0.0.6.13).
- **Petit sifflement corrigé** : le jeu calculait jusqu'à 240 images par seconde (plus de 500 sans synchronisation), même dans les menus ; la carte graphique pouvait siffler ou grésiller. Nouveau réglage Paramètres → Vidéo → Jeu : **Images par seconde au plus** (60 par défaut, 30 à 240), appliqué aux menus et au jeu.
- **Pin sylvestre** fait dans Blender : tronc droit, écorce orangée ; branches en étages, touffes d'aiguilles bleu-vert, petites pommes de pin. Jeune : conique et garni jusqu'en bas ; adulte : tronc nu sur plus de la moitié de sa hauteur (quelques chicots), cime large et aplatie. Tailles 1 à 5 : 7,6 / 11,6 / 15,8 / 18,9 / 21,9 m.
- **Tilleul** fait dans Blender : tronc droit, écorce grise fissurée, branches qui montent, couronne ovale haute et dense, feuilles en cœur. Tailles 1 à 5 : 6,6 / 10,3 / 14,3 / 17,3 / 20,1 m.
- Version légère dans le jeu (comme les arbres fruitiers) : aiguilles et feuilles en plaques avec une image de grappe (dessinée en code), 2 000 à 9 200 triangles de près, 280 à 1 500 au loin. Versions détaillées de la taille standard dans `arbres_detail.blend` (archives Blender).
- **Génération version 23** (nouveaux mondes ; les autres gardent exactement leurs arbres) : pins et tilleuls seuls ou par 2 à 3, dans une zone sur 16 (nouveau réglage « Pins et tilleuls ») ; trois fois plus souvent au pied et sur les pentes douces des montagnes, où ce sont surtout des pins (pentes un peu plus raides permises), deux fois plus en lisière, où ce sont plutôt des tilleuls ; 7 m au moins entre eux. Environ 280 pins et 140 tilleuls dans un monde de 512 m.
- **Monde d'essai T42** (graine 1755064997) ; la vitrine de l'accueil montre un pin, un tilleul et un pommier.

Tests concernés réussis (limite d'images par seconde ; test « trees » : quatre espèces, pins surtout au pied des montagnes, espacement, génération 22 inchangée, hauteurs ; générations et mondes anciens). Mesures dans la même séance, 0.0.6.11 puis 0.0.6.12 : à l'arrêt et face aux arbres, FPS au plafond de 120 du PC dans les deux cas ; en vol, 55 → 57 sur PC, 60 → 58 en rendu Web (bruit de mesure).
À tester manuellement : le sifflement a-t-il disparu ; aspect des pins et tilleuls de près et de loin ; monde T42.

## 0.0.6.11 — Arbres de cinq tailles (#178, #180)
Version locale (publiée avec 0.0.6.13).
- **Arbres plus réalistes** (taille 3, standard) : pommier de 7,5 m au tronc plus large, tronc dégagé jusqu'aux premières branches vers 2 m, couronne plus large en haut ; noisetier de 5,8 m, tiges plus épaisses, feuillage à partir d'environ 1 m.
- **Cinq tailles par espèce**, chacune son propre modèle (un grand arbre a un tronc plus épais et plus de branches, pas le même arbre agrandi) : 1 petit, 2 plutôt petit, 3 standard, 4 plutôt grand, 5 grand. Pommier 4,0 / 5,5 / 7,4 / 8,7 / 9,7 m ; noisetier 3,0 / 4,3 / 5,8 / 6,5 / 7,5 m. De près : 5 900 à 14 900 triangles (pommier), 3 500 à 11 200 (noisetier) ; au loin : 100 à 1 500.
- **Génération version 22** (nouveaux mondes) : tailles tirées selon la graine (15 % petit, 25 % plutôt petit, 30 % standard, 20 % plutôt grand, 10 % grand) ; arbres d'un groupe à 5 m au moins. Les mondes en génération 21 gardent leurs arbres aux mêmes endroits ; leurs trois variantes deviennent les tailles 3, 4 et 2.
- Blender : le générateur garde la version détaillée de la taille 3 dans `arbres_detail.blend` (rangé dans ../Archives OrbMeka/Blender) et fait les autres tailles « en forme seulement » pour la version légère (`version_jeu.py`).
- **Monde d'essai T41** (graine 1112514211) ; la vitrine de l'accueil le montre.

Tests concernés réussis (test « trees » : cinq tailles, standard la plus courante, groupes espacés, génération 21 inchangée, modèles de plus en plus hauts ; générations et mondes anciens). Mesures dans la même séance, 0.0.6.10 puis 0.0.6.11 : à l'arrêt et face aux arbres, FPS au plafond de 120 dans les deux cas (PC et Web) ; en vol, 58 → 58 sur PC, 60 → 61 en rendu Web.
À tester manuellement : aspect des cinq tailles de près et de loin, forme des grands pommiers (tailles 4 et 5), buter contre un tronc, monde T41.

## 0.0.6.10 — Arbres faits dans Blender (#138)
Version locale (publiée avec 0.0.6.13).
- **Pommier et noisetier refaits dans Blender** (sources_blender/arbres). Pommier : 5,7 m de haut, axe central, trois étages de branches, couronne pleine jusqu'en bas, branches basses presque à plat dont le bout retombe, pommes bien visibles. Noisetier : touffe de tiges, noisettes en grappes de 2 ou 3 avec leur collerette, au bord du feuillage.
- **Deux versions** : la version détaillée (1,3 million de triangles pour le pommier, 450 000 pour le noisetier) reste dans `arbres_detail.blend` (rangé hors du dépôt, dans ../Archives OrbMeka/Blender) ; le jeu lit une **version légère** faite à partir d'elle (`version_jeu.py` → assets/trees) : branches à peu de facettes, feuillage en plaques croisées avec une image de grappe de feuilles (bords découpés), fruits simples. De près : 8 300 triangles (pommier), 5 900 (noisetier) ; au loin (40 à 150 m) : 1 000 et 560.
- Un modèle par espèce : les trois variantes de la génération donnent un arbre normal, grand ou jeune (taille). Placement inchangé : **mêmes mondes**, pas de nouvelle génération.
- **Monde d'essai T40** (graine 1814019520) ; la vitrine de l'accueil le montre.

Tests concernés réussis (test « trees » mis à jour : modèles Blender, feuillage découpé, hauteur du pommier). Mesures dans la même séance, anciens puis nouveaux arbres, face à 3 arbres : 514 → 400 FPS sur PC, 480 → 461 en rendu Web (environ 0,5 ms de plus par image) ; en vol et à l'arrêt, différences dans le bruit de mesure.
À tester manuellement : aspect de près et de loin, passage d'un modèle à l'autre, buter contre un tronc, monde T40.

## 0.0.6.9 — Pommiers et noisetiers (#149, #138)
Version publiée (avec 0.0.6.6 à 0.0.6.8).
- **Génération version 21** (nouveaux mondes ; les anciens ne changent pas) : premiers arbres fruitiers, selon la graine. Dans une zone sur 14 environ (réglage « Arbres fruitiers » des mondes personnalisés), un arbre seul ou un petit groupe de 2 à 3, plus souvent en lisière (près d'un lac, au pied d'une montagne, au bord d'un désert). Environ 400 arbres dans un monde de 512 m.
- Seulement sur l'herbe : jamais dans l'eau ni sur la rive, ni sur le sable, la boue, le gravier, la neige ou la pierre, ni sur une pente raide, ni contre un rocher.
- **Modèles** faits en code (scripts/trees.gd), formes douces : **pommier** (tronc un peu penché, branches, couronne ronde de boules de feuilles, pommes rouges à orangées) et **noisetier** (touffe de tiges droites, feuillage plus clair, noisettes par 2 ou 3). Trois variantes chacun (rond, large, jeune ; touffe moyenne, grande, petite), taille et orientation au hasard.
- **Au loin** : modèle détaillé jusqu'à 40 m, simplifié (tronc + une boule) jusqu'à 150 m, puis rien. Environ 800 à 1 600 sommets par arbre de près, une centaine au loin.
- **Collision** du tronc (ou du pied de la touffe). Pas de récolte ni de coupe : la pioche et la pose ne font rien sur un arbre.
- **Monde d'essai T39** (graine 1820305098, génération 21) ; la vitrine de l'accueil montre trois arbres sur l'herbe.

Tests concernés réussis (nouveau test « trees » : même graine = mêmes arbres, autre graine = autres arbres, pas d'arbre dans l'eau, le sable ou sur une pente raide, génération 20 sans arbre et relief identique, modèles et distances, tronc solide, pas de coupe). Mesures dans la même séance, génération 20 puis 21 : vol rapide 63 → 64 FPS sur PC, 71 → 68 en rendu Web ; à l'arrêt 239 dans les deux cas.
À tester manuellement : aspect des arbres de près et de loin, passage d'un modèle à l'autre, buter contre un tronc, monde T39.

## 0.0.6.8 — Nager
Version locale (publiée avec 0.0.6.9).
- **Nage** (scripts/player.gd) : eau à plus de 1,1 m au-dessus des pieds (lacs, eau libre) : on nage. Sans rien toucher, on remonte et on flotte, les yeux juste hors de l'eau.
  Espace maintenu : monter ; Y maintenu : plonger ; avancer en regardant vers le bas plonge aussi. R : nager vite. Plus lent qu'à pied (2,6 m/s).
  Espace à la surface contre une rive ou sur le fond : on sort de l'eau d'un bond. Eau peu profonde : on marche moins vite. Les rivières emportent doucement vers l'aval.
- **Correction : on voyait à travers les montagnes.** Certaines zones de 8 m en haut des montagnes n'étaient jamais construites (le sommet était mesuré trop grossièrement) : un trou laissait voir le monde derrière. Les zones suivent maintenant la vraie hauteur du sol (0 zone manquante sur tout le monde T37, 20 avant). Les mondes ne changent pas.
- **Monde d'essai T38** (graine 397857267, génération 20) ; la vitrine de l'accueil le montre.

Tests concernés réussis (nouveau test « swim » : flotter les yeux hors de l'eau, plonger, remonter, vitesse, rester à la surface, plonger en regardant en bas, pas de nage au sec, courant vers l'aval, aucune zone de sol oubliée). Captures : sommet complet, vue à la surface d'un lac.
À tester manuellement : nager, plonger, sortir de l'eau sur une rive raide, nager dans une rivière ; dire si l'on voit encore à travers quelque chose (où, et en regardant quoi).

## 0.0.6.7 — Rivières (#124)
Version locale (publiée avec 0.0.6.9).
- **Correction de l'eau qui coule** : l'eau garde un élan d'une case à l'autre (calcul en petits pas) ; un fossé se met au niveau du lac en 10 à 15 s au lieu de garder une longue pente d'eau.
- **Génération version 20** (nouveaux mondes) : **rivières** selon la graine. Sources sur environ une montagne sur deux, descente jusqu'au lac de plaine le plus proche (plus bas que la source), jamais près d'un lac de montagne.
- Lit creusé dans le terrain, fond en **gravier**, sans rochers ; l'eau reste sous les rives et descend toujours.
- **Eau en mouvement** : ruban d'eau animé dans le sens du courant (shaders/river.gdshader), un peu d'écume sur les bords.
- Pour l'eau qui coule, une rivière est une source sans fin et un puits : un fossé creusé depuis une rivière se remplit.
- **Monde d'essai T37** (graine 1019681621, génération 20) ; la vitrine de l'accueil le montre.

Tests concernés réussis (rivières qui descendent jusqu'aux lacs, eau sous les rives, même graine = mêmes rivières, gravier dans le lit, version 19 sans rivière ; eau du fossé au niveau du lac après 30 s). Mesures dans la même séance : FPS identiques entre génération 19 et 20 ; environ 130 ms de plus à la première construction des rivières d'un monde.
À tester manuellement : suivre une rivière depuis sa source jusqu'au lac (aspect, animation), creuser un fossé depuis une rivière. Pas encore de nage.

## 0.0.6.6 — L'eau coule (#124, début)
Version locale (publiée avec 0.0.6.9).
- **Eau qui coule** (scripts/water.gd) : chaque case de 50 cm a un fond (le haut du terrain) et une hauteur d'eau ; l'eau passe vers les cases voisines plus basses, sans jamais se créer ni se perdre. Creuser à côté d'un lac fait couler son eau dans le trou ou le fossé.
- **Lacs-réservoirs** : l'eau qui sort d'un lac le fait baisser (volume ÷ surface) ; un lac peut se vider. Le relief du lac ne change pas.
- **Seulement près du joueur** (32 m) et seulement les cases qui bougent : rien à calculer quand l'eau est calme.
- **Sauvegarde** dans le dossier du monde, seulement si l'eau a bougé : `eau/lacs.json` (niveaux des lacs) et `eau/cases.json` (eau libre). Relue à l'ouverture.
- Sous l'eau : la vue sous-marine suit aussi l'eau libre et les lacs qui ont baissé.
- **Monde d'essai T36** (graine 3460613564) ; la vitrine de l'accueil le montre.

Tests concernés réussis (nouveau test « water » : le fossé se remplit, le lac baisse du même volume à 1 % près, sauvegarde et relecture, aucun fichier si l'eau n'a pas bougé). Mesures : un pas de calcul 0,7 ms avec un fossé en train de se remplir ; FPS identiques à 0.0.6.5 (repos 240, vol rapide environ 74 sur PC).
À tester manuellement : creuser un fossé depuis un lac, regarder l'eau arriver, rouvrir le monde. Pas encore de rivières ni de nage.

## 0.0.6.5 — Sous-sol plus profond, cailloux de calcaire et de silex
- **Génération version 19** (nouveaux mondes) : 5 m de terre, **20 m de pierre** et **20 m de pierre sombre**, puis la Roche-mère à 45 m (avant : 10 m et 10 m, Roche-mère à 25 m). Grottes et crevasses descendent jusqu'à la nouvelle Roche-mère.
- **Cailloux de calcaire** (nouveaux, environ 2 par zone, plus sur les pentes, au bord de l'eau et dans le gravier) et **cailloux de silex** : de toutes les tailles (8 à 60 cm), autant de gros que de petits. Les rochers de calcaire (1 sur 5) restent.
- **Monde d'essai T35** : créé dans la liste des mondes (mode par défaut, génération standard, graine au hasard 3718082877) ; la vitrine de l'accueil montre ce monde. Un monde d'essai par version (T36 à la prochaine).
- Test de casse rendu fiable (le terrain sous le joueur est construit avant de viser).

Tests concernés réussis (couches de la version 19, cailloux de toutes tailles, anciens mondes inchangés). Mesures dans la même séance (PC plus lent qu'au début de la séance) : génération 18 et 19 à peu près pareilles, environ 50 FPS en vol rapide sur PC et en rendu Web.
À tester manuellement : creuser jusqu'à la Roche-mère (45 m), cailloux de calcaire et de silex, monde T35, vitrine.

## 0.0.6.4 — Calcaire, charbon et silex
Version locale (pas encore publiée). Issues #143 et #134.
- **Génération version 18** (nouveaux mondes), dans la pierre, en sous-cellules de 50 cm :
  - **calcaire** : poches ou couches minces de 16 à 48 sous-cellules, seulement dans la pierre claire, environ 8 % (≈ 336 par zone de pierre claire) ; gris très clair à beige, mat, un peu granuleux ;
  - **charbon** : filons allongés de 4 à 12 sous-cellules dans la pierre claire et sombre, environ 1,5 %, jamais dans le calcaire ; noir mat en couches, quelques éclats brillants ;
  - **silex** : rognons de 1 à 3 sous-cellules au cœur du calcaire (3 à 6 par zone, environ 9 sous-cellules, un peu plus de 1 % du calcaire) ; gris foncé à noir, lisse, croûte blanche crayeuse autour.
  Jamais dans la terre ni la Roche-mère. Dans une zone en partie seulement de pierre : en proportion.
- **Surface** : silex parmi les cailloux (environ 3,5 par zone, plus près de l'eau et sur les pentes, jusqu'à 8 dans le gravier) ; environ 1 rocher sur 5 en calcaire, et 1 sur 4 de ceux-là cache un rognon de silex, visible en le creusant.
- **Pioche** : calcaire et charbon en 1 coup par sous-cellule, silex en 2 ; ils ne tombent pas. Pas de récolte.
- **Rendu** : une donnée de plus par sommet du terrain (CUSTOM0), vérifiée sur PC et en rendu Web.

Tests concernés réussis (proportions sur des zones entières : calcaire 8,8 %, poches de 32 sous-cellules en médiane ; charbon 1,6 %, filons de 8 ; silex aux bons endroits ; anciens mondes et terre inchangés). Mesures (vol rapide, 3 essais) : PC environ 74 FPS (80 en 0.0.6.3), rendu Web environ 83 FPS (103 en 0.0.6.3) : le calcul des minerais quand de nouvelles zones apparaissent coûte environ 20 % de plus ; à l'arrêt, rien ne change.
À tester manuellement : creuser dans la pierre pour voir le calcaire et le charbon, casser un rocher de calcaire, silex au bord de l'eau, fluidité dans un navigateur.

## 0.0.6.3 — Cailloux et lacs de montagne
Version locale (publiée avec 0.0.6.5).
- **Génération version 17** (nouveaux mondes) : **cailloux** posés sur le sol, 7 tailles (8 à 60 cm : le plus gros ne dépasse pas le plus petit rocher) et les 7 formes des rochers ; un peu partout, bien plus nombreux sur le gravier, au pied des montagnes et au bord des lacs ; plus de petits que de gros (environ 4,6 par zone de 8 m).
- **Pioche** : les petits cailloux partent en 1 coup, les plus gros en 2 ou 3 (ils rapetissent entre deux coups). Cassés, ils sont gardés dans objets.json (« cailloux_casses ») ; pas de récolte. Les petits ne gênent pas la marche, les deux plus grosses tailles arrêtent le joueur.
- **Lacs de montagne** : jamais collés l'un à l'autre (le replat de l'un écrasait le bord de l'autre : de l'eau restait en l'air, parfois sur tout le bord). Plusieurs lacs par montagne restent possibles. Les mondes déjà créés gardent leurs lacs.
- Tests du menu : le terrain est terminé avant de vérifier l'herbe (depuis 0.0.6.2, seule la colonne du joueur est faite tout de suite).

Tests concernés réussis. Mesures : sur 5 graines, plus aucun lac de montagne avec de l'eau hors du sol (avant : 1 sur 10) ; vol rapide PC environ 80 FPS, rendu Web environ 100 FPS, sans image de plus de 33 ms ou presque.
À tester manuellement : marcher sur le gravier parmi les cailloux, les casser à la pioche, lac de montagne vu de près, fluidité dans un navigateur.

## 0.0.6.2 — Jeu plus fluide
Version locale (publiée avec 0.0.6.5).
- **Herbe** : envoyée d'un coup à la carte graphique (avant : deux appels par touffe, puis une relecture) : environ 0,3 ms par carré de 8 m au lieu de 27 ms. Même herbe.
- **Terrain** : la file construit zone par zone (une colonne de montagne prenait jusqu'à 50 ms d'un coup) ; seule la colonne du joueur est faite tout de suite.
- **Vue** : zones visibles gardées par colonne, morceaux, herbe et objets retrouvés par colonne (pire image de la mise à jour : 21 → 4 ms).
- **Maillage** du terrain lisse : tableaux simples au lieu de dictionnaires (8 % plus rapide, même résultat vérifié sur 160 zones).

Tests concernés réussis. Mesures (3 essais) : ouverture d'un monde 0,91 → 0,60 s ; vol rapide en rendu Web 86 → 113 FPS en moyenne, images de plus de 33 ms 45 → 2 ; sur PC, vol très variable selon l'essai (48 à 83 FPS, contre 46 avant).
À tester manuellement : fluidité en volant et en marchant, sur PC et dans un navigateur.

## 0.0.6.1 — Neige, gravier et pioche
- **Génération version 16** (nouveaux mondes) : neige en haut d'environ 1 montagne sur 4 ; gravier au pied des montagnes et sur la rive d'environ 1 lac sur 3 (#122). Ils glissent comme le sable.
- **Sous l'eau** : brume bleu-vert proche, voile teinté, surface claire vue de dessous. L'eau vue de dessus ne change pas.
- **Pioche** : la pierre se casse une sous-cellule de 50 cm par coup (pierre sombre : 2 coups ; Roche-mère jamais) ; les rochers se creusent morceau par morceau, gardés dans objets.json. Éclats et petit son de choc fait dans le jeu.
- **Lointain** : plus de trou en s'approchant d'une montagne (le relief lointain reste tant que le détail n'est pas affiché).
- **Contrôles** : Échap et un clic ailleurs annulent le choix d'une touche (les touches ne changent plus toutes seules) ; ✕ pour désactiver une touche seule. Creuser sans effet : message.

Tests : tous réussis (59). Mesures : vol rapide sur PC environ 47 FPS (56 avant la génération 16) ; coup de pioche : pierre 25 à 40 ms, plus gros rocher jusqu'à 80 ms.
À tester manuellement : montagne enneigée, gravier, plongée dans un lac, casser en maintenant le clic, gros rocher creusé puis monde rouvert, fluidité dans un navigateur.

## 0.0.6 — Monde plus grand, mondes en sécurité
Début de la série « Monde 2 ».
- **Génération version 15** (nouveaux mondes) : monde de **64 × 64 zones** (512 m, contre 384 m). Les mondes déjà créés gardent 48 × 48 zones (#135).
- **Mes mondes** : « ! » jaune à droite des mondes d'une ancienne génération ; les ouvrir demande une confirmation.
- **Paramètres généraux → Mondes** : cacher les anciens mondes ; **dossiers sécurisés** (onglets Par défaut, Sécurisés, Versions sécurisées), rangés à part et jamais lus par les anciennes versions du jeu ; rangement automatique des anciens mondes, avec exceptions ; sous-dossiers (+) et bouton Déplacer.
- **Informations** : mises à jour du jeu, de la génération et des menus. **Historique** : version de génération et des menus de chaque version.
- **Icône du jeu** : l'orbe au-dessus d'une crevasse.

Tests : tous réussis (59). Mesures (rendu Web simulé sur PC) : à l'arrêt 210 FPS, en vol 63 FPS sur PC et 29 en rendu Web (34 avant) ; ouverture d'un monde 0,95 s (0,83 avant).
À tester manuellement : bord du monde à 256 m, déplacer des mondes et ouvrir un sous-dossier, une ancienne version du jeu ne voit pas les mondes sécurisés, fluidité dans un navigateur.

## 0.0.5.37 — Grottes et crevasses
- **Génération version 14** (nouveaux mondes) : **grottes** (entrées dans environ 6 % des zones, environ 13 % de vide sous terre), certaines jusqu'à la Roche-mère, jamais creusée ; **crevasses en éclair** (environ 8 par monde), peu profondes à un bout, très profondes à l'autre. Curseurs dans le monde personnalisé.
- Plus de retour au départ dans les grottes : seulement sous le monde.
- **Liste des mondes** : un monde illisible est signalé et conservé, sans cacher les autres.
- **Optimisation** : accueil construit petit à petit (menu tout de suite disponible, 1,7 s de calcul contre 5 s), moins de grottes chargées depuis la surface, maillage et calcul plus rapides, même monde (empreintes identiques).
- **Vitrine** : vue en hauteur sur une grande crevasse.

Tests : tous réussis. Mesures PC, rendu PC et Web : images lentes en vol 13 ms, 400 à 600 FPS à vide sur ce PC. À tester manuellement : descendre une crevasse, entrer dans une grotte, fluidité dans un navigateur.

## 0.0.5.36 — Lointain plus net
- **Lointain** : plus de blocs gris (seuls les sommets rocheux restent gris), boue et argile moins sombres, brume seulement tout au bout.
- **Eau** : plus de double couche entre l'eau proche et l'eau lointaine.
- **Web** : distances plus courtes par défaut (affichage 6 zones, lointain 16, herbe 3), réglables dans Vidéo (#128).
- **Publication** : les envois sur `dev` vont sur une page d'essais privée (`ITCH_TARGET_DEV`) ; seules les versions avec un tag vont sur la page principale.

Tests choisis réussis. À tester manuellement : FPS et aspect dans un navigateur, page d'essais.

## 0.0.5.35 — Grands lacs et chaînes de montagnes
- **Génération version 13** (nouveaux mondes) : lacs deux fois plus grands en surface (petits 4 à 6 zones, moyens environ 20, grands environ 32), moins de petits lacs ; les plus grands sont choisis en premier sur tout le monde. Environ 10 % d'eau.
- **Chaînes de montagnes** : 3 à 5 sommets à la suite (curseur dans le monde personnalisé). Environ 18 % du sol en montagnes.
- Les rivières restent à faire.

Mesures sur 10 graines : eau 9,7 %, montagnes 17,7 %, déserts 10,9 %. Tests choisis réussis. À tester manuellement : aspect et fluidité sur le Web.

## 0.0.5.34 — Lacs de montagne
- **Génération version 12** (nouveaux mondes) : petits lacs (1 à 3 par montagne de terre douce) sur des replats, pas à flanc de pente.
- **Plus de lacs** ailleurs (moyens 1 sur 90, grands 1 sur 260) ; **moins de trous** (1 sur 30 et 1 sur 45) et bords moins ronds.

Tests : smooth_terrain, custom_generation ; tests choisis réussis. À tester manuellement : marcher autour d'un lac de montagne.

## 0.0.5.33 — Très grands déserts, montagnes de sable
- **Génération version 11** (nouveaux mondes) : environ 6 déserts par monde, de 40 à 48 zones, environ 10 % du sol en moyenne (de 3 à 17 % selon la graine).
- **Montagnes de sable**, dans les déserts : 10 à 16 m, pente d'environ 30°, sans pierre, 1 à 2 par monde en moyenne (curseur dans le monde personnalisé).
- **Trous** : un sur 3 environ a de la boue au fond. Les trous de boue restent.

Tests : smooth_terrain, custom_generation, custom_world_menu ; tests choisis réussis. Empreinte : anciennes générations inchangées. À tester manuellement : monter sur une montagne de sable.

## 0.0.5.32 — Trous de boue
- **Génération version 10** (nouveaux mondes) : parfois un trou de boue, 2 à 4 m de rayon, 60 cm à 1,2 m de fond, sans eau (1 chance sur 40 par zone, réglable dans le monde personnalisé). Même relief que la version 9 ailleurs.

Tests : smooth_terrain, custom_generation, custom_world_menu ; tests choisis réussis. À tester manuellement : entrer dans un trou et en sortir.

## 0.0.5.31 — Boue et argile glissantes
- **Boue** : un peu glissante, surtout dans les pentes. **Argile** : encore moins. Sur le plat, on ne glisse pas tout seul : le pas réagit juste un peu moins vite.

Tests : smooth_terrain ; tests choisis réussis. À tester manuellement : le ressenti en marchant sur les pentes.

## 0.0.5.30 — Mêmes couleurs sur PC et sur le Web
- **Couleurs** : PC et Web rapprochés, herbe plus sombre que l'ancien PC et plus claire que l'ancien Web : même tonemap, lumière
  réglée pour chacun, saturation un peu baissée sur le Web. Tout change un peu, pas seulement l'herbe.
- **Zones d'herbe** : grandes zones plus claires et plus sombres, les mêmes dans les brins, le sol et le lointain.

Mesures sur captures, herbe proche : PC #97b06b → #6d8452, Web #344f21 → #4a682f. Tests choisis réussis.
À tester manuellement : aspect dans un vrai navigateur (le rendu du navigateur peut différer un peu des captures).

## 0.0.5.29 — Erreur clavier du Web
- **Web** : le jeu ne demande plus la disposition du clavier, que le navigateur ne donne pas (erreur en boucle dans la console).
  Sur le Web, les noms de touches restent ceux d'un clavier QWERTY.

Tests choisis réussis. À tester manuellement : fluidité dans un navigateur, noms des touches sur clavier AZERTY.

## 0.0.5.28 — Licences dans Informations
- **Informations** : bouton **Licences**, qui ouvre la page existante (Retour et Échap reviennent à Informations).
- **Vitrine** : seulement le renard et le lapin.
- Vérification avant publication : mentions, licences, pas de secret ni de donnée personnelle dans le dépôt. Code : « Roche-mère » partout.

Tests : licences, menu_style, tests choisis réussis. À revérifier avant un lancement public : le nom « OrbMeka » (TMview).

## 0.0.5.27 — Roche-mère irrégulière
- **Roche-mère** : plus de fond avec des points : toute la surface en petites taches irrégulières (noir, gris foncé,
  gris clair, bleu et rouge), sans couleur principale. Notre propre motif, sans pixels.

Tests choisis réussis ; captures PC. À tester manuellement : aspect en jeu et sur le Web.

## 0.0.5.26 — Sous-sol plus profond (#130)
- **Génération version 9** (nouveaux mondes) : 5 m de terre, 10 m de pierre, 10 m de **pierre sombre** (un peu noircie,
  à la pioche aussi), puis seulement la **Roche-mère**, à 25 m. Même relief que la version 8 pour une même graine.
  Les mondes déjà créés gardent leurs couches.
- **Roche-mère** : nouvel aspect, fond gris-noir semé de points noirs, gris foncés, gris clairs, bleus et rouges.

Tests : smooth_terrain (couches, pioche, zones profondes), custom_generation ; tests choisis réussis. Empreinte : anciennes
générations inchangées. Captures PC d'un puits. À tester manuellement : creuser jusqu'en bas, aspect sur le Web.

## 0.0.5.25 — Jeu plus fluide, lointain plus rapide (#128)
- **Lointain (niveaux de détail)** : réécrit. Sommets partagés (bien moins de calcul pour la carte graphique), un sommet
  tous les 2 m, 4 m puis 8 m selon la distance ; relevé étalé sur plusieurs images (plus d'à-coup) et gardé
  (repasser au même endroit ne recalcule rien) ; calculé avant le terrain détaillé à l'ouverture.
- **Terrain détaillé** : maillage plus rapide, exactement le même terrain (empreinte vérifiée, génération 0 à 8).
- **Herbe** : complète jusqu'à 16 m, 3 fois moins de brins (plus larges) au-delà. **Ombres** : jusqu'à 64 m, 2 niveaux.
- **Eau des lacs** (version 7 et plus) : suit le contour du lac ; ne déborde plus sur la rive (défaut de 0.0.5.23).
- Tests : limite de mémoire par test à 3 Go (2 avant).

Mesures sur ce PC (vol à 12 m/s) : images lentes (95 %) de 16 à 3-5 ms ; triangles de 1343 k à 735 k.
Tests choisis réussis. À tester manuellement : fluidité sur le Web, aspect de l'herbe à 16 m, petits traits clairs
parfois visibles à la limite du terrain détaillé et du lointain (déjà là avant).

## 0.0.5.24 — Montagnes où l'on peut monter (#121)
- **Génération version 8** (nouveaux mondes ; les anciens ne changent pas) : un peu plus de montagnes (environ
  9 % du sol, 7 % avant). La plupart sont plus larges : on peut monter à pied jusqu'au sommet (toutes les montagnes
  douces mesurées). Quelques-unes (20 à 25 % au plus) sont **trop raides** pour y monter.
- **Monde personnalisé** : deux curseurs, « Montagnes où l'on peut monter » (1 sur 850) et « Montagnes raides »
  (1 sur 2800) ; réglage jusqu'à 1 sur 4000.
- **Vitrine** : nouvelle vraie graine (2171).

Tests : custom_generation, custom_world_menu (16 réglages), smooth_terrain ; tests choisis réussis.
Mesure à pied sur 12 graines (pente de moins de 45°, sans sauter), avant le dernier petit réglage des chances.
À tester manuellement : monter sur une montagne douce, essayer une raide, FPS sur le Web.

## 0.0.5.23 — Montagnes, grands lacs et grands déserts (#121, #124, #128)
- **Génération version 7** (nouveaux mondes ; les anciens mondes ne changent pas).
- **Montagnes** (notre propre forme) : 20 à 32 m de haut, environ 50 zones chacune, environ 7 % du sol (1 chance
  sur 700 par zone) ; pied doux, crêtes, bord irrégulier ; **cœur de pierre** qui monte vers le sommet (sommets
  rocheux) et quelques plaques de pierre sur les pentes. Jamais au départ, pas de lac ni de sable dessus.
  Les petites collines restent. On peut poser et creuser jusqu'à 40 blocs de haut (4 avant).
- **Lacs** : petits de 2 à 3 zones (rares, 1 sur 500), moyens d'environ 10 zones (les plus courants, 1 sur 180),
  grands d'environ 16 zones (rares, 1 sur 450) ; environ 5 % du sol en eau, comme avant ; bords irréguliers.
- **Déserts** : grands de 14 à 20 zones (1 sur 200), environ 9 à 10 % du sol.
- **Lointain plus rapide** : un point tous les 4 m au-delà de 2 carrés (2 m plus près), une seule hauteur par point,
  lacs proches rangés par zone ; une petite jupe cache les fentes. Curseurs des réglages : jusqu'à 1 sur 2000.
- **Vitrine** : vraie graine (719) avec deux montagnes au loin et un lac moyen.

Tests : custom_generation, custom_world_menu (15 réglages), smooth_terrain (tailles de lacs, montagnes à sommet
de pierre, zones hautes dessinées, lointain 2 m / 4 m) ; tests choisis réussis. Mesures sur 3 graines : déserts
9,6 %, eau 4,9 %, montagnes 6,9 %. Captures PC et Web d'une montagne, vitrine.
À tester manuellement : monter sur une montagne, creuser la pierre du sommet, vitesse du lointain sur le Web.

## 0.0.5.22 — Voir loin : niveaux de détail (#128)
- **Niveaux de détail** (notre propre méthode) : au-delà de la distance d'affichage (terrain détaillé), le terrain
  lointain est un relief simplifié par carrés de 4 × 4 zones (32 m), un point tous les 2 m, coloré selon ce
  qu'on y verrait (herbe, sable, argile, boue, eau des lacs) ; ni herbe, ni collision, ni changements du joueur.
  Il passe juste sous le bord du terrain détaillé (pas de fente) et se refait peu à peu en marchant.
- Nouveau réglage **Distance lointaine** (Vidéo → Jeu) : 24 zones par défaut, de 0 (aucune) à 48. La brume va
  jusqu'au bout du relief simplifié.
- **Boue** plus liquide : mate et gorgée d'eau, petites flaques (seules un peu brillantes), coulures lisses.
- **Argile** plus vraie : lisse, un peu humide, fines craquelures.

Tests : smooth_terrain (carrés lointains autour du terrain détaillé, jamais dessous, bord sous le terrain
détaillé, brume, distance 0), interface_info (réglage en plus) ; tests choisis réussis.
Captures PC (vue d'en haut) et Web (au sol, 4 ms par image).
À tester manuellement : marcher et voler loin, Distance lointaine de 0 à 48, FPS sur le Web.

## 0.0.5.21 — Lacs irréguliers, boue et argile grise (#121, #122, #124)
- **Génération version 6** (nouveaux mondes) : plus de lacs d'une zone ; **lacs d'environ 2 zones** (1 chance
  sur 26) et **grands lacs d'environ 4 zones** (1 sur 55), bords irréguliers, jamais l'un sur l'autre.
- **Bandes de 4 à 5 m autour des lacs**, irrégulières, selon le lac : tout argile ; moitié boue, moitié argile ;
  ou un tiers argile, un tiers herbe, un tiers boue. Fond : boue (ou argile).
- **Régions de boue** d'environ 2 zones, de forme irrégulière (1 chance sur 70 par zone).
- **Argile grise** (comme en vrai) au lieu d'orangée.
- **Déserts** : plus de petits ni de moyens, seulement des grands de 7 à 9 zones (1 sur 110), environ 8 % du sol.
- Mesures sur 3 graines : désert 7,8 %, eau 5,1 %, boue 6,3 %, argile en surface 8,7 % ; environ 39 lacs de
  2 zones et 18 grands lacs par monde.
- Les mondes déjà créés gardent leur génération.

Tests : smooth_terrain (lacs 2 et 4 zones, trois sortes de bords, régions de boue), custom_generation et
custom_world_menu (version 6, 13 réglages) ; tests choisis réussis. Captures PC et Web : grand lac et argile.
À tester manuellement : bords des lacs, couleur de l'argile, FPS sur le Web.

## 0.0.5.20 — Grand monde, argile, boue et lacs allongés (#121, #122, #124, #128)
- **Monde de 48 × 48 zones** (384 m, X et Z de −192 à 191 ; construction de −189 à 189), pour préparer les
  niveaux de détail (#128). Seules les zones à portée sont préparées : l'ouverture reste rapide (environ 0,5 s sur PC).
- **Génération version 5** (nouveaux mondes) : **lacs allongés** sur 1 × 2 zones (1 chance sur 48) en plus des
  petits lacs d'une zone (1 sur 24), tous deux réglables dans Monde personnalisé ; **boue** au fond et au bord
  des lacs (1 m), **argile** dessous (jusqu'à 2,5 m) et en **poches** dans la terre (1 chance sur 10 par zone,
  0,5 à 1 m sous l'herbe), réglable aussi.
- **Argile et boue** : nouvelles matières, avec leur aspect (argile orangée à grain fin, boue sombre et mouillée),
  sans herbe ; la boue glisse comme le sable, l'argile tient comme la terre. On peut les poser : molette
  (Sable, Terre, Argile, Boue, Pioche) ou touches 4 (argile) et 5 (boue).
- **Dossiers des mondes au nom du monde** (ex. mondes/Test12) : les mondes existants sont renommés à la prochaine
  ouverture du jeu ; renommer un monde renomme son dossier. Nom nettoyé (caractères interdits remplacés,
  pas de « .. », pas de nom réservé de Windows, « (2) » si déjà pris).

Tests : smooth_terrain (lacs 1 et 1 × 2 zones, boue, argile, poches, boue qui glisse, monde 48 × 48),
world_save (dossiers nommés, renommage, noms sûrs), custom_generation, custom_world_menu, world_consistency,
interface_info, menu, shortcuts_selection ; tests choisis réussis. Capture : lac allongé.
À tester manuellement : argile et boue (aspect, pose), lacs, dossiers renommés, FPS sur le Web.

## 0.0.5.19 — Rochers à miner et petits lacs (#121, #124)
- **Rochers plus gros** : de 60 cm (minuscule) à 5,4 m (énorme). Monde TestTailleRocher mis à jour.
- **Génération version 4** (nouveaux mondes) : rochers au hasard (1 chance sur 2 par zone, parfois deux ;
  bien plus de petits que de gros), et **petits lacs** (1 chance sur 24 par zone) : cuvette de 3,5 à 6 m de rayon,
  petit bord autour, eau calme bleu-vert un peu transparente avec des rides. Pas près de l'apparition ni de la plage.
  Réglables dans Monde personnalisé (Rochers, Petits lacs). Les mondes plus anciens n'en ont pas.
- **Miner un rocher** : pioche en main, clic gauche ; il se fend à chaque coup et casse au bout d'autant de coups
  que sa taille (1 à 7). Sans la pioche, un message. Les rochers cassés sont gardés (objets.json) et ne reviennent pas.
- L'eau ne coule pas encore et on ne nage pas : ce sera l'eau réaliste (#124).
- Ouverture d'un monde : environ 1,2 s sur PC (le reste du terrain arrive peu à peu).

Tests : smooth_terrain (rochers au hasard, plus de petits, minage, sauvegarde, pas de retour, lacs, anciens mondes
sans rochers), custom_generation et custom_world_menu (version 4, 12 réglages) ; tests choisis réussis.
Captures PC et Web : lac et rochers.
À tester manuellement : miner à la pioche, lacs, FPS sur le Web.

## 0.0.5.18 — Monde plus grand, déserts et rochers (#121)
- **Mondes de 20 × 20 zones** (160 m, X et Z de −80 à 79 ; construction de −73 à 73), anciens mondes compris
  (leur terrain d'origine ne change pas, il s'agrandit autour).
- **Génération version 3** (nouveaux mondes) : déserts sur environ 12 % du sol, tailles 1, 3 à 4 et 6 à 7 zones,
  plus de grands que de petits (petits 1 chance sur 133 par zone, moyens 1 sur 100, grands 1 sur 80) ;
  3 ou 4 trous énormes pour 256 zones (1 sur 72), jusque dans la pierre. Curseurs : de 1 sur 1 à 1 sur 400.
- **Roche-mère** : noire, teintée de rouge (au fond d'un puits creusé à la pioche).
- **Rochers (essai)** : une norme de 7 tailles (minuscule 40 cm, petit, plutôt petit, moyen, plutôt grand,
  grand, énorme 4 m) et 7 formes (rond, plat, dressé, anguleux, allongé, bosselé, en coin), faits dans le jeu
  (scripts/rocks.gd). Monde **TestTailleRocher** créé avec les 49 rochers et leurs étiquettes (objets.json).
  Les plus petits rochers restent plus gros qu'un gros caillou (les cailloux viendront à part).
- **Vitrine de l'accueil** : vrai terrain (collines, herbe dessus, brume), graine 20612.

Tests : smooth_terrain (Roche-mère, rochers), custom_generation et custom_world_menu (version 3, 1 sur 400),
world_consistency et interface_info (160 m) ; tests choisis réussis. Captures : rochers, vitrine.
À tester manuellement : TestTailleRocher, trous énormes, FPS du monde plus grand sur le Web.

## 0.0.5.17 — Distance d'affichage et relief version 2 (#121)
- **Distance d'affichage** (Vidéo → Jeu) : 8 zones de 8 m par défaut, de 1 à 32, comptée à l'horizontale.
  Toutes les zones où passe le sol d'une colonne proche sont affichées, même en volant très haut ;
  les plus lointaines arrivent peu à peu, d'abord plates. Brume au bord de la vue. Le monde fait toujours
  16 × 16 zones (128 m) : au-delà d'environ 8, rien de plus à voir pour l'instant.
- **Herbe** : distance réglée en zones (4 par défaut, 1 à 12) au lieu de mètres.
- **Génération version 2**, enregistrée avec chaque nouveau monde : relief moins plat (collines douces
  partout, longues ondulations, bosses ; les trous se creusent dedans), déserts aux bords irréguliers,
  plus rares (environ 1/6 du sol au lieu de 1/3) ; déserts moyens 2 à 4 zones, grands 4 à 6.
  Les mondes déjà créés gardent exactement leur génération (version 1 ou celle de 0.0.5.15).
- **Monde personnalisé** : « zone » au lieu de « chunk » ; chaque réglage dit ce qu'il donne dans le monde
  (nombre de reliefs ou de déserts sur 256 zones, part du sol en désert). Ce sont des chances par zone,
  pas des nombres maximum (cause des nombreux déserts du monde Test12 : 71 zones sur 256).
- **Informations** (accueil, page renommée) et **Informations du monde** (pause) : partie repliable
  « Génération du monde » qui explique comment le monde a été généré (graine, réglages, sous-sol).

Tests : smooth_terrain (distance horizontale, colonnes affichées et retirées, sol sous le joueur en vol,
brume), custom_generation (version 2, tailles, estimations, mondes version 1 inchangés),
custom_world_menu, interface_info, folds et menu mis à jour ; tests choisis réussis.
Captures PC (vue d'en haut) et Web (au sol). Ouverture d'un monde : environ 0,7 s sur PC.
À tester manuellement : marcher et voler loin, distance 1 à 32, FPS sur le Web.

## 0.0.5.16 — Mondes personnalisés
- Créer un monde → Options du monde → Monde personnalisé, sous la note des attributs.
- Catégorie Génération du terrain : dix barres de fréquence, 1/64 à gauche (rare), 1/1 à droite
  (chaque zone), tous les entiers intermédiaires. Une zone mesure 8 × 8 m.
- Sous chaque barre : Valeur par défaut et bouton ↻. Les valeurs connues viennent des mêmes constantes
  que la génération standard : petits déserts 1/8, crêtes et trous lisses 1/9. Les collines standards
  sont un relief continu jusqu’à 3 blocs, sans fréquence distincte pour les deux tailles.
  Catégories nouvelles : indiquées absentes et désactivées ; un interrupteur permet de les activer
  à 1/64. Le curseur actif conserve bien ses bornes 1/64 à 1/1.
- Déserts : petits (1 zone), moyens (4 à 6), grands (8 à 11), en groupes connexes ;
  les groupes peuvent se recouvrir. Les trois fréquences règlent le départ d'un désert par zone.
  Les déserts standards de 3 à 4 zones (1/12) n'ont pas d'équivalent exact dans ces nouvelles tailles.
- Collines : lisses de 1 bloc, lisses de 2 à 3 blocs, abruptes.
- Trous : plutôt lisses, abrupts, bien profonds (près de la pierre), grands trous atteignant
  2 à 3 blocs dans la pierre (fond entre Y −6 et −7). La Roche-mère reste intacte à Y −8.
- Appliquer sans changer les valeurs de référence conserve exactement la génération standard.
  Tant que les deux tailles de collines ne sont pas personnalisées, leur relief continu est conservé.
- Les reliefs peuvent se superposer ; leurs hauteurs ne s'additionnent pas indéfiniment.
  Le départ et la plage restent plats pour les reliefs ; à 1/1, le sable peut couvrir aussi le départ.
- Appliquer garde les choix ainsi que le nom, la graine et le mode. Annuler/Échap garde les choix
  précédemment appliqués. Génération standard retire la personnalisation.
- Les réglages sont enregistrés dans monde.json et l'index, champ generation version 1 : même graine
  et mêmes options donnent le même monde. Renommer, rouvrir et dupliquer conservent les options.
  Les mondes sans ce champ continuent d'utiliser exactement leur génération historique.
- Vidéo → Jeu : Distance d'affichage de l'herbe, de 8 à 96 m, 36 m par défaut (avant : 24 m).
  Appliquée immédiatement et sauvegardée dans les réglages vidéo ; la densité reste séparée.
- FPS : lecture directe de Engine.get_frames_per_second(), actualisée toutes les 0,5 s ;
  apparence conservée à la demande de l'utilisateur.

Validation : 18 suites pertinentes vérifiées sur 58 (31 %), génération, sauvegarde, menus,
paramètres et compatibilité ; les trois suites corrigées ont été revérifiées (dernier lot 5/5
avec les contrôles juridiques). Les valeurs par défaut et leur rétablissement ont ensuite été
revérifiés dans 8 suites (8/8). Deux tests à la fois, pics observés : CPU 31 %, mémoire 73 %.
Runner local : CPU et mémoire du PC surveillés, arrêt de nos seuls tests au-delà de 85 %,
quatre simultanés au maximum et réduction à deux si la charge monte ; pas de deuxième runner.
À tester manuellement : aspect des terrains extrêmes, défilement du menu et coût GPU de l'herbe,
notamment dans le navigateur. Aucun contrôle de la souris ni capture d'écran du PC pendant les tests.

## 0.0.5.15 — Relief varié et déserts (#121)
- Collines jusqu'à 3 m, surtout douces ; petites bosses partout (le sol est moins plat), toujours en gazon.
- Environ 1 zone de 8 m sur 9 : une crête abrupte (ça monte, puis ça tombe d'un coup).
- Environ 1 zone sur 9 : un trou, petit ou gros, jamais jusqu'à la pierre (3,5 m au plus) ; le gazon
  reste dedans (seul ce qu'on creuse soi-même perd son herbe).
- Environ 1 zone sur 8 : un petit désert (une zone) ; 1 sur 12 : le départ d'un grand désert (3 ou 4 zones).
  Sable sur 2 m, puis la terre ; ce sable tombe et glisse comme le sable posé ; pas d'herbe.
- Toujours plat autour de l'apparition et de la plage ; même graine = même monde.

Tests : smooth_terrain (fréquences sur 1600 zones, déserts en sable, trous avant la pierre) ;
tests choisis réussis. Captures PC (vue d'en haut) et Web (désert). Ouverture : environ 0,9 s sur PC.
À tester manuellement : se promener (crêtes, trous, déserts), FPS et ouverture sur le Web.

## 0.0.5.14 — Petites collines (#121)
- La graine crée de petites collines de terre douces (1,6 m au plus, jamais sous Y 0), plates autour
  de l'apparition et de la plage. Même graine = mêmes collines. L'herbe pousse dessus.
- Ouverture rapide : les zones proches sont faites tout de suite, les autres peu à peu pendant le jeu
  (d'abord plates, quelques-unes par image). Calcul d'une zone bien plus rapide (2 à 5 ms sur PC).
- Clic gauche ou droit maintenu : le geste se répète (creuser, poser, aplanir, lisser, pioche),
  au rythme de Attributs → Blocs.
- B + molette haut : geste plus grand ; B + molette bas : plus petit (l'ancien réglage par défaut
  enregistré est mis à jour tout seul).

Tests : smooth_terrain (collines, même graine, herbe sur les collines, faces bien tournées, chargement
peu à peu, B + molette), breaking et action_timing (répétition) ; tests choisis réussis.
Captures PC et Web : collines. Ouverture d'un monde : environ 0,5 s sur PC.
À tester manuellement : marcher sur les collines, clic maintenu, FPS et ouverture sur le Web.

## 0.0.5.13 — La pioche
- La pioche rejoint la sélection existante : molette Sable → Terre → Pioche, ou touches 1, 2, 3.
  Un petit texte en bas dit « Outil : Pioche » quand on la prend.
- Pioche en main (vue à la première personne) : clic gauche casse la terre et aussi la pierre,
  jusqu'à la Roche-mère (toujours incassable). Sans la pioche, la pierre ne casse pas (un message le dit).
- Animation simple : la pioche s'abat et revient (0,25 s), des éclats gris (pierre) ou bruns (terre) volent.
- La pioche ne pose rien ; aplanir et lisser ne touchent pas la pierre.

Tests : smooth_terrain (pioche, pierre, Roche-mère, éclats), prototype et shortcuts_selection mis à jour ;
tests choisis réussis. Capture PC : pioche en main.
À tester manuellement : coup de pioche et éclats, creuser la pierre jusqu'à la Roche-mère.

## 0.0.5.12 — Pierre et Roche-mère (#121)
- Sous le gazon : 4 m de terre (comme avant), puis 4 m de pierre, puis la Roche-mère, à 8 m sous le sol.
- La pierre a son aspect (roche grise, veines sombres), sans herbe ; elle ne tombe jamais.
  Elle ne se casse pas encore (plus tard, avec une animation) : « La pierre ne se casse pas encore. »
- La Roche-mère est incassable et porte tout le monde.
- La terre et le sable tombent plus lentement (0,15 s par 50 cm au lieu de 0,06), pour bien les voir tomber.

Tests : smooth_terrain (couches, pierre incassable, fond de puits en pierre, la pierre ne tombe pas) ;
tests choisis réussis. Capture PC : puits jusqu'à la pierre.
À tester manuellement : creuser jusqu'à la pierre, voir tomber la terre et le sable.

## 0.0.5.11 — Gravité de la terre et du sable
- Un point de terre ou de sable sans rien juste dessous tombe, 50 cm à la fois (on le voit descendre).
- Talus : le sable glisse sur le côté dès qu'il dépasse son voisin de 50 cm (pentes de 45° au plus),
  il s'étale en tas bas ; la terre tient en petites piles (jusqu'à 1 m de haut sur 50 cm de large).
  Le sol de départ se comporte comme la terre : creuser un puits de plus d'1 m fait s'ébouler les bords.
- Un vide plus loin (pas juste dessous ni à côté) ne fait rien tomber.
- Avant d'enregistrer, ce qui tombe encore est posé à sa place.
- Plus de page Comment jouer (ni de touche F2) : la pause garde Paramètres et Informations du monde.

Tests : smooth_terrain (gravité : chute, sable qui s'étale, pile de terre, trou dessous ou plus loin) ;
pause, shortcuts_selection, appearance, world_info, menu_style, controls_groups mis à jour ;
tests choisis réussis. Capture PC : tas de sable et de terre après la chute.
À tester manuellement : voir tomber la terre et le sable, creuser sous une pile, FPS sur le Web.

## 0.0.5.10 — Touches modifiables et corrections des pinceaux
- Paramètres → Contrôles → Blocs : « Pinceau suivant » (B + T), « Geste plus grand » (B + molette bas)
  et « Geste plus petit » (B + molette haut) se changent comme les autres touches.
- Nouvelle partie Raccourcis : Retour aux mondes (F1), Comment jouer (F2), Informations du monde (F3),
  Changer de vue (F4), modifiables. Seule Échap (pause) reste réservée.
- Aplanir et lisser n'ajoutent plus jamais de matière : aplanir coupe les bosses, lisser adoucit ;
  seul Poser ajoute du sable ou de la terre.
- Terre posée sur la plage : elle reste de la terre (avant, la plage la peignait en sable).
- Le terrain est enregistré point par point (gestes « figés » dans la grille) : en revenant dans le
  monde, il est exactement le même.

Tests : controls, controls_groups, views, menu, pause, pause_settings, shortcuts_selection et
smooth_terrain mis à jour ; tests choisis réussis. Capture Web : terre sur la plage.
À tester manuellement : changer ces touches et les utiliser en jeu, aplanir près d'un trou.

## 0.0.5.9 — Pinceaux du terrain (#120)
- Clic droit : pinceau choisi avec **B + T** (Poser → Aplanir → Lisser). Clic gauche : toujours creuser.
- Poser : **sable ou terre** (molette, ou 1 : sable, 2 et 3 : terre) ; plus de pierre pour l'instant.
  Le sable posé a l'aspect de la plage, la terre posée reste nue (sans herbe). Jusqu'à 4 blocs au-dessus du sol.
- Aplanir : le sol prend la hauteur visée sur un disque (bosses coupées, creux remplis avec la matière choisie).
- Lisser : les formes s'adoucissent (chaque point se rapproche de ses voisins).
- **B + molette** : taille du geste, 1/8, 1/4 ou 1/2 bloc (1, 2 ou 4 sous-cellules) ; aplanir et lisser
  agissent alors sur 50 cm, 1 m ou 1,5 m autour.
- Un petit texte en bas dit le choix (matière, pinceau, taille), seulement quand on le change.
- La matière posée est enregistrée avec chaque point (5e nombre dans le fichier de zone).

Tests : smooth_terrain (37 vérifications : matières, tailles, aplanir, lisser, textes, réouverture) ;
shortcuts_selection et prototype mis à jour ; tests choisis réussis. Captures PC vérifiées.
À tester manuellement : B + T et B + molette au clavier, sensation des pinceaux, FPS sur le Web.

## 0.0.5.8 — Terrain lisse, première étape (#120)
- Chaque bloc de 1 m est divisé en 2 × 2 × 2 = 8 sous-cellules de 50 cm (16 par axe dans une zone de 8 m,
  17 points de grille avec les deux bords). Le sol est maintenant ce terrain lisse, une pièce par zone
  (scripts/smooth_terrain.gd) ; sable et herbe restent comme avant.
- Clic gauche : creuser 50 cm ; clic droit : ajouter 50 cm. La surface reste lisse (pentes en terre),
  l'herbe disparaît autour. Jusqu'à 3,5 m sous le sol ; la base indestructible est dessous.
- Sauvegarde : seuls les points changés, dans le fichier de la zone (format 3 ; les anciens restent lisibles).
- Les blocs posés avant restent ; plus de casse ni de pose de blocs pour l'instant.
- Web : soleil et lumière ambiante plus forts (le jeu y paraissait sombre).
- Paramètres → Vidéo : le groupe « Jeu » est en premier.

Tests : nouveau smooth_terrain (25 vérifications : échelle 50 cm, sol plat calculé, creuser, ajouter,
limites, herbe, sauvegarde et réouverture) ; breaking, action_timing, web_fixes et terrain_visuals mis à jour ;
tests choisis réussis. Recalcul d'une zone sculptée : environ 10 ms sur PC.
Captures comparées en rendu PC et Web.
À tester manuellement : creuser et ajouter à la souris, marcher dans les trous, FPS sur le Web.

## 0.0.5.7 — Herbe haute
- Brins d'herbe de 24 à 56 cm (environ 40 cm, 8 fois plus longs), un peu plus larges,
  plus penchés et balancés plus fort par le vent.
- Deux fois plus de brins pour chaque densité (Basse 80, Moyenne 200, Haute 440 par carré de 50 cm).
- Sol vert plus clair, proche des brins : au loin, il paraissait presque noir sur le Web.

Tests : terrain_visuals vérifie la hauteur et le nombre de brins ; tests choisis réussis.
Captures comparées en rendu PC et Web (Compatibility).
À tester manuellement : aspect de l'herbe et FPS, surtout sur le Web (baisser la densité si le jeu ralentit).

## 0.0.5.6 — Vitrine de l'accueil à jour (#126)
- Le fond 3D de l'accueil montre ce qui existe dans le jeu : sol plat, gazon réaliste
  (densité basse pour rester fluide derrière les menus), plage de sable plate, l'orbe
  et les personnages. Plus de collines de terre ni de tour de pierre : la caméra est
  à hauteur des yeux, sur le sol.

Tests : menu_style mis à jour ; tests choisis réussis.
À tester manuellement : aspect et fluidité de l'accueil.

## 0.0.5.5 — Monde plat et plage de sable
- Tous les mondes (anciens et nouveaux) commencent **tout plats**, en herbe : plus de
  collines de terre ni de blocs de démonstration (sable et pierre). Les blocs posés
  et la position restent sauvegardés.
- **Plage de sable** plate d'environ 21 m², au niveau de l'herbe, à une dizaine de
  mètres de l'apparition (X 11, Z 9) : grains fins, teintes chaudes, rides de vent,
  bord irrégulier fondu avec l'herbe. Les blocs de sable ont la même matière.
- Mesure PC : environ 180 images/s.

Tests : monde, zones, sauvegarde, informations et actions mis à jour ; tests choisis réussis.
À tester manuellement : aspect de la plage de près, bord avec l'herbe, FPS sur le Web.

## 0.0.5.4 — Gazon réaliste
- Gazon dense sur le sol et sur la terre : brins fins de 3 à 7 cm (environ 5 cm),
  base sombre, pointe claire, quelques brins secs, balancés par un vent léger.
  Groupés par carrés de 50 cm, affichés jusqu'à 24 m (au-delà, le sol vert suffit).
- **Paramètres → Vidéo → Densité de l'herbe** : Basse (160 brins/m²), Moyenne (400,
  par défaut), Haute (880). Appliquée à la prochaine ouverture d'un monde.
- FPS plus visibles (20 px, blanc, contour épais).
- Mesures PC (RTX 4070 portable, fenêtre 1280 × 720) : 150 à 240 images/s ; ouverture 70 ms.
  Web : à mesurer avec le compteur FPS ; si c'est lent, choisir Basse.

Tests : terrain_visuals, interface_info, settings et tests du monde réussis.
À tester manuellement : aspect du gazon de près et en marchant, FPS sur le Web.

## 0.0.5.3 — FPS et date de création
Un compteur discret affiche les FPS en haut à gauche sous les indications existantes,
avec une mise à jour toutes les 0,5 s. Il disparaît pendant la pause et suit la taille du texte.
Informations du monde (pause ou F3) affiche la date et l'heure de création à tous les niveaux
de synthèse. Lecture de monde.json sans modification : présentation française,
heure locale enregistrée par Godot (les anciennes dates ne contiennent pas de fuseau).
Une date absente ou invalide reste inconnue, y compris après migration d'un ancien monde.
Renommer garde la date ; dupliquer crée un nouveau monde avec sa propre date.
Validation : 8 tests ciblés réussis, puis suite complète 55/55 en 103 s.
Exécution avec deux tests à la fois (-Jobs 2), binaire Godot natif et protections mémoire actives.
fps_creation vérifie le rythme du compteur, la pause, les tailles de texte de 50 à 150 %,
la lecture de la date, le renommage, la duplication et la migration sans date inventée.
Aspect en mouvement et comportement souris restent à vérifier manuellement.

## 0.0.5.2 — Première passe visuelle du terrain (#120)
Herbe et terre utilisent des matières procédurales originales, sans texture externe,
avec des touffes regroupées par section. Le relief et les collisions restent ceux des blocs :
le terrain lisse et les pinceaux sont encore à réaliser. Les zones restent de 8 m,
avec des sous-cellules prévues de 50 cm (16 cellules, 17 sommets par axe).
Casse et pose sont désactivées, même avec une touche réaffectée ou maintenue.
Les anciennes constructions, la position, le regard, l'exploration et la pause sont conservés.
Les anciennes instructions de construction ci-dessous décrivent les versions précédentes.

Aperçu natif hors écran : [terrain](previews/0.0.5.2-terrain.png).
Mesure indicative en Compatibility à 1400 × 900 : 3,769 ms de rendu médian forcé,
chargement chaud 834 ms sur le PC de développement ; ce n'est pas une mesure de FPS en partie.
Performances Web et aspect en mouvement restent à vérifier manuellement.
Validation : suite complète tests/run_all.ps1 réussie (54/54, 81 s) ; terrain_visuals couvre
les matières, les entrées désactivées et l'absence de modifications du monde.

## Lancer et choisir un monde
1. Dans Godot, arrêtez l'ancienne partie si nécessaire, puis appuyez sur **F5**.
2. L'accueil affiche **Jouer**, **Paramètres**, **Informations**, dans cet ordre.
   Jouer ouvre Mes mondes. Paramètres : Paramètres généraux (souris, synthèse), Vidéo (panneaux, zones et boutons, texte, thème, profondeur, FOV), Contrôles, Personnage, Attributs.
   Informations explique la génération des mondes, sans désigner de monde particulier.
3. Choisissez **Créer un monde**, saisissez son nom et, si souhaité, une graine, puis **Créer**.
   La création ouvre directement la partie.
4. Pour un monde existant, sélectionnez son nom puis **Ouvrir**.
   Un double-clic ou Entrée sur la liste permet aussi de l'ouvrir.
   **Renommer** modifie uniquement le nom, en conservant identité et graine.
   **Supprimer** demande confirmation avec le nom du monde ; **Annuler**
   est sélectionné par défaut. Le dossier du monde choisi est supprimé.
5. Le monde se lance avec la souris directement capturée. **Échap** ouvre la pause et la libère.
6. Pour quitter la partie : **F1**, ou Échap puis **Retour aux mondes** dans la pause.
   **F8** arrête une partie lancée par l'éditeur.

Les menus acceptent Tab / Maj+Tab, flèches, Entrée et Espace selon le contrôle
sélectionné. Échap revient du formulaire à la liste, puis de la liste à l'accueil.
La souris reste libre dans les menus ; lancer un monde la capture automatiquement.
Le clic qui capture la souris ne casse ni ne pose de bloc.

## Mondes sauvegardés (dossier par monde, 0.0.5)
Chaque nouveau monde reçoit la graine saisie à la création, ou une graine aléatoire si le champ est vide.
Nom, graine, mode, **blocs posés et cassés, position et regard** sont sauvegardés.
La liste est enregistrée localement dans le dossier de données Godot du jeu,
fichier **user://worlds.json**. La graine est facultative à la création.

## Mode du monde (depuis 0.0.3)
Dans Créer un monde, section **Options du monde** : **Par défaut** (à gauche,
choisi d'office) ou **Mode développeur** (à droite).
- Par défaut : Saut, Blocs et Marche gardent leurs valeurs par défaut dans ce
  monde ; les réglages de Paramètres → Attributs y sont ignorés.
- Mode développeur : le monde utilise les réglages de Paramètres → Attributs.
Mes mondes → ⚙️ Paramètres du monde permet de **passer** en mode développeur,
après une confirmation (Annuler sélectionné), puis d'y **revenir** (0.0.4.10).
La mention « Mode développeur utilisé au moins une fois » reste alors,
**définitive**, dans Informations du monde (F3), où s'affiche aussi le mode. Une copie garde le mode de l'original.
Les mondes créés avant 0.0.3 sont en mode Par défaut.

Réouvrir un monde recalcule le terrain avec sa graine, puis applique les changements enregistrés.
Sauvegarde : pause, retour aux mondes, fermeture (navigateur compris) et toutes les 45 s.
Dossier actuel : user://mondes/<identifiant>/ (monde.json, joueur.json, zones/zone_X_Y_Z.bin).
Depuis 0.0.5.1, les changements sont compressés par zone ; l'ancien zones/modifications.json
est converti puis conservé sous zones/modifications-etape1.json.

Le nom est obligatoire, limité à 48 caractères. Les espaces aux extrémités
sont retirés et un doublon de nom est refusé, sans distinction de majuscules.
Un problème de lecture ou d'enregistrement est affiché ; un fichier de liste
illisible est conservé sans être remplacé par une liste vide.

## Terrain
Chaque graine produit **3 ou 4 petites collines de terre brune**,
jusqu'à **3 blocs de hauteur** (sommet à Y 3), dans une zone finie de 41 × 41 cellules (X et Z de -20 à 20).
Deux mondes aux graines différentes varient par le nombre et le profil des collines.
Le terrain reste reproductible pour une même graine dans cette version.

La base plate de 128 × 128 blocs (1 bloc = 1 m ; X et Z de -64 à 63) est protégée. Les collines sont cassables.
L'aire de départ reste dégagée et les 74 blocs de démonstration en sable et pierre
sont conservés. L'apparition tient compte des blocs présents.

## Plan confirmé — terrain lisse (première version livrée en 0.0.5.8)
Les zones restent de **8 × 8 × 8 mètres**. Chaque bloc de 1 m de côté sera découpé en
**2 divisions sur chaque axe**, donc **2 × 2 × 2 = 8 sous-cellules au total**.
Chaque sous-cellule mesurera **50 cm de côté** et représentera **1/8 du volume**
du bloc. Une zone contiendra **16 subdivisions par axe**, soit **16 × 16 × 16
sous-cellules de 50 cm**. Si la densité est portée par les sommets, les deux
bords inclus demandent **17 sommets par axe** ; ce ne sont pas 16 points.
Depuis 0.0.5.8, le sol est ce terrain lisse (scripts/smooth_terrain.gd) : on y creuse et on y ajoute
50 cm par clic ; depuis 0.0.5.9, aussi aplanir et lisser (B + T), sable ou terre, trois tailles.

## Commandes en partie
- ZQSD / WASD : marcher ; ← → : aller de côté ; souris : regarder.
- Espace : sauter, un appui par saut.
- Y : se baisser ; R : courir. Mode de chaque touche dans Contrôles :
  Maintenir ou Basculer, et pour courir **Maintenir conditionnel** (0.0.3.25).
- ↑ ↓ maintenues : marcher, courir, se baisser plus ou moins vite (0.0.4.3) ;
  ↑ ↓ + A : tout le déplacement (0.0.4.7) ; + W : marche, + R : course,
  + clic : casse ou pose ; ⌫ + touche : par défaut ; ⌫ deux fois : tout.
- Espace deux fois : voler ; en vol, Espace monte, Y descend (0.0.4.5) ;
  R en vol : voler vite (0.0.4.8).
- F4 : changer de vue, première personne, de derrière, de devant (0.0.4.9).
- Contrôles : deuxième touche facultative par action, double appui ou
  en même temps (0.0.3.27).
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
- scripts/world_catalog.gd : liste des mondes (worlds.json) ; scripts/world_store.gd : dossier de chaque monde.
- scenes/world.tscn / scripts/world.gd : scène de jeu, blocs, base, ciel, aide et interactions.
- scripts/terrain_generator.gd : profils et cellules déterministes, séparés de l'affichage.
- scripts/player.gd : caméra, déplacements, collisions et commandes.
- scripts/action_timing.gd : délais de casse/pose et tolérances de saut.
- tests/ : tests sans fenêtre, sans injection d'entrée système.

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

## Menus Orbe violet — 0.0.2.12
Tous les menus partagent un thème commun « Orbe violet » (scripts/ui_theme.gd) :
panneau violet légèrement transparent, boutons en pavés avec contour sable au
survol et au clavier, titres sable, sous-titres turquoise, champs et liste
assortis. Style propre à OrbMeka, couleurs reprises des blocs du jeu.
- Accueil : derrière les menus, un petit monde en blocs généré en code
  (scripts/menu_showcase.gd) : sol, collines, place en sable et pierre, ciel
  de fin de journée, orbe lumineux ; la caméra tourne lentement autour.
  Un bandeau « Nouveau » sous la version résume la dernière nouveauté.
- Pause : le monde reste visible derrière, assombri et flouté
  (scripts/menu_backdrop.gdshader). Le jeu reste bien en pause.

**Changer la vitrine à chaque version** : ouvrir scripts/menu_showcase.gd,
section « VITRINE DE LA VERSION » en haut du fichier. Modifier NEWS_VERSION
et NEWS_TEXT (bandeau de l'accueil), puis _build_news() et _animate_news()
(construction 3D de la nouveauté). Le reste du fichier ne change pas.
Pour 0.0.2.12 : un cadre de fenêtre en blocs qui s'élargit et se resserre
pas à pas (fenêtre redimensionnable), avec un panneau de menu violet.
Le test menu_style_test.gd vérifie que NEWS_VERSION suit la version du projet.

Test ajouté : tests/menu_style_test.gd (50 contrôles : thème commun, titres,
fond 3D et sa caméra, cadre animé, pause floutée, retour du fond, 6 pages à
800 × 450, 1920 × 1080, 2560 × 1080 et 800 × 900). Résultat : 16 tests,
0 échec. À tester manuellement : aspect réel des menus et du fond 3D,
fluidité de la caméra, flou de la pause, survol des boutons à la souris.

## Menus plus larges et icônes — 0.0.2.13
- Panneau des menus plus transparent (on voit mieux le fond), texte avec
  une ombre légère pour rester lisible.
- Pages de contenu (Mes mondes, formulaires, Attributs, Informations,
  Historique, Comment jouer) : panneau à 72 % de la largeur de la fenêtre,
  zones défilantes qui prennent toute la hauteur libre. Phrases plus longues
  sur une ligne, beaucoup moins de défilement. Accueil et pause restent compacts.
- Mes mondes : une seule rangée, ▶ Ouvrir puis des boutons-icônes
  ➕ Créer, ✏️ Renommer, 📋 Dupliquer, ⚙️ Paramètres du monde, 🗑️ Supprimer
  (nom de l'action au survol). Créer, Renommer et Confirmer la suppression
  ont aussi leur icône. Tous les boutons sont un peu moins hauts.
- Fond de l'accueil : seuls des éléments déjà dans le jeu. Le panneau de
  verre violet de la 0.0.2.12 est retiré (le verre n'existe pas encore) ;
  son image est gardée pour plus tard dans docs/idees/vitrine-verre-0.0.2.12.png.
  Le point de vue est celui d'un joueur debout sur une tour de 4 blocs de
  pierre, qui tourne lentement la tête : on ne vole plus.
- Règle ajoutée en tête de scripts/menu_showcase.gd : la vitrine ne montre
  que ce qui existe dans le jeu.

Tests : menu_style_test.gd (59 contrôles : point de vue fixe sur la tour,
pas de verre, boutons-icônes avec infobulle, transparence) et
window_resize_test.gd (74 contrôles : panneau large des pages de contenu,
hauteur libre des zones défilantes). Résultat : 16 tests, 0 échec.
À tester manuellement : lisibilité sur le panneau transparent, icônes
(police emoji de Windows), aspect du fond depuis la tour, fenêtre agrandie.

## Paramètres en onglets et marche réglable — 0.0.2.14
- Historique des versions réparé : le fichier a été rangé dans
  docs/HISTORIQUE.txt, mais le jeu le cherchait encore à la racine (écran
  « indisponible »). Le jeu et le plugin d'export lisent maintenant docs/.
- Accueil → Paramètres : menu latéral à gauche, boutons rectangulaires.
  « Paramètres généraux » (ouvert par défaut, aucun réglage pour le moment)
  et « Attributs » (l'écran des attributs). Changer d'onglet garde les
  saisies ; Retour ou Échap les abandonne toujours.
- Attributs : bouton ↻ par catégorie (Saut, Blocs, Marche) et
  « ↻ Tout réinitialiser ». Comme le ↻ d'un champ, ils remettent les
  défauts dans les champs ; Appliquer enregistre.
- Nouvelle catégorie Marche (en dernier) : Avancer, Avancer de côté, Reculer,
  de 1 à 12 m/s, défaut 5,5 m/s (ancienne vitesse unique). Enregistrées dans
  user://settings.json et utilisées par le joueur. Un ancien fichier de
  réglages se charge sans avertissement, avec les défauts de marche.
- Vitrine de l'accueil : un marcheur en blocs de pierre avance vite sur une
  piste de sable, puis recule plus lentement.

Test ajouté : tests/settings_walk_test.gd (44 contrôles : historique,
menu latéral, réinitialisations, bornes et sauvegarde de la marche, vitesses
réelles du joueur, mise en page de 800 × 450 à 2560 × 1080). Tests mis à jour
pour la nouvelle page et la vitrine. Résultat : 17 tests, 0 échec.
À tester manuellement : aspect du menu latéral et des onglets, sensation de
marche aux différentes vitesses, vitrine animée, écran Historique dans le jeu.

## Raccourcis en texte et ↻ orange — 0.0.2.14.2
- En jeu, le bouton violet « Retour aux mondes (F1) » est retiré. En haut à
  droite, F1 (Retour aux mondes), F2 et F3 sont rappelés en simple texte,
  tous dans le même style. La touche F1 fonctionne comme avant.
- Attributs : un espace plus grand avant chaque catégorie (Saut, Blocs,
  Marche). Les boutons ↻ de catégorie sont orange-jaune, plus grands ;
  ↻ Tout réinitialiser et les ↻ de chaque champ gardent le style violet.

Tests mis à jour : menu_style_test, menu_test, window_resize_test (rappels
en texte en haut à droite) ; settings_walk_test (48 contrôles : couleur
orange, espacement). Résultat : 17 tests, 0 échec.
À tester manuellement : lisibilité des rappels F1-F3 sur le monde, rendu de
l'orange et de l'espacement dans Attributs.

## Mode par défaut et mode développeur — 0.0.3
Première version du thème « Contrôles et Paramètres » ; la série 0.0.2 est terminée.
- Créer un monde, Options du monde : bouton **Par défaut** à gauche (choisi
  d'office) et **Mode développeur** à droite.
- Monde par défaut : attributs (Saut, Blocs, Marche) à leurs valeurs par
  défaut, réglages de Paramètres → Attributs ignorés. Monde développeur :
  réglages de Paramètres → Attributs.
- Paramètres du monde : affiche le mode ; bouton « Passer en mode
  développeur… » seulement pour un monde par défaut, avec confirmation
  claire (choix irréversible, Annuler sélectionné). Aucun retour possible.
- Mode enregistré dans user://worlds.json, conservé par la copie, affiché
  dans Informations du monde (F3). Anciens mondes : Par défaut. Un mode
  inconnu dans le fichier est signalé et le fichier n'est jamais écrasé.
- Vitrine de l'accueil : deux sauteurs, le développeur saute plus haut.

Test ajouté : tests/world_mode_test.gd (création, valeurs appliquées,
confirmation, irréversibilité, copie, rechargement, F3, fichier invalide).
Tests mis à jour : world_options_test, attributes_test, settings_walk_test,
menu_style_test, version. Résultat : 18 tests, 0 échec.
À tester manuellement : aspect des boutons de mode et de la page de
confirmation, vitrine animée.

## Vidéo et sensibilité de la souris — 0.0.3.1
- Paramètres, menu de gauche : **Paramètres généraux**, **Vidéo**, **Attributs**.
- Paramètres généraux → Souris : **Sensibilité de la souris**, de 10 à 300 %
  (100 % par défaut = sensibilité d'avant). Valable dans tous les mondes,
  y compris en mode par défaut.
- Vidéo → Panneaux : **Taille des panneaux**, de 50 à 95 % de la largeur de
  la fenêtre (72 % par défaut, comme avant). Tous les panneaux suivent dans la
  même proportion (accueil, pause, création, listes…), sans jamais dépasser la
  fenêtre. **Largeur du menu de gauche** : 120 à 400 px (190 par défaut), au
  plus 40 % du panneau pour laisser la place au contenu.
- Mêmes boutons qu'Attributs : ↻ par champ, ↻ orange par catégorie.
  Un seul bouton **Appliquer** sous les sections enregistre tout ; Retour annule.
  ↻ Tout réinitialiser (Attributs) ne touche que les attributs.
- Réglages enregistrés dans user://settings.json ; un ancien fichier se charge
  sans avertissement avec les nouveaux défauts.

Test ajouté : tests/display_settings_test.gd (panneaux dans la fenêtre à 50
et 95 % en 800 × 450, 1280 × 720, 2560 × 1080 ; menu de gauche ; bornes ;
réinitialisations ; sauvegarde ; sensibilité en monde par défaut).
Tests mis à jour : attributes, interface_info, settings_walk, window_resize,
version. Résultat : 19 tests, 0 échec.
À tester manuellement : sensation de la souris, aspect des panneaux aux
tailles extrêmes et du menu de gauche élargi.

## Taille du texte et textes copiables — 0.0.3.2
- Vidéo → Texte : **Taille du texte**, de 75 à 150 % (100 % par défaut).
  Tous les textes des menus suivent, ainsi que les textes affichés en jeu.
- Vidéo → Largeur du menu de gauche : **150 px** par défaut (190 avant).
- Textes des menus sélectionnables à la souris et copiables (Ctrl+C ou
  clic droit → Copier) : explications, historique, Comment jouer, infos…
- Paramètres allégés : plus de titre de section qui répète l'onglet, notes
  raccourcies, noms des champs en blanc (plus lisibles).
- Un panneau plus haut que la fenêtre (grand texte, petite fenêtre) défile
  au lieu de sortir de l'écran.

Test étendu : tests/display_settings_test.gd (34 contrôles : tailles du
texte, panneaux dans la fenêtre en largeur et hauteur, textes
sélectionnables, aucun titre répété). Les tests utilisent désormais des
réglages par défaut isolés, jamais ceux du joueur. Résultat : 19 tests, 0 échec.
À tester manuellement : sélection et copie des textes, lisibilité à 75 et
150 %, défilement d'un panneau à 150 % dans une petite fenêtre.

## Texte en px et menu de gauche plus étroit — 0.0.3.3
- Vidéo → Texte : **Taille du texte** en px, de 7 (environ 40 %) à 27 px,
  18 par défaut (taille d'origine). L'ancien réglage en % est ignoré.
- Vidéo → Largeur du menu de gauche : échelle abaissée, **80 à 250 px**,
  120 par défaut.

Test mis à jour : display_settings_test (bornes en px, 7 et 27 px dans les
petites et grandes fenêtres). Résultat : 19 tests, 0 échec.
À tester manuellement : lisibilité à 7 et 27 px, menu de gauche à 80 px.

## Synthèse des textes et thèmes — 0.0.3.4
- Paramètres généraux → Textes : **Synthèse des textes** −, Par défaut, +.
  « + » garde les textes complets d'avant ; « Par défaut » les raccourcit ;
  « − » ne garde que l'essentiel (certaines explications disparaissent).
  Concerne Informations, Comment jouer, Informations du monde, Paramètres,
  création, renommage, suppression, Paramètres du monde. La confirmation du
  mode développeur dit toujours « irréversible ».
- Vidéo → Apparence : **Thème** Sombre, Par défaut (couleurs d'avant) ou Clair.
- Choix en boutons, avec ↻ par réglage et ↻ de catégorie ; Appliquer enregistre.

Test ajouté : tests/appearance_test.gd (choix, thèmes, niveaux de texte,
sauvegarde, pages dans la fenêtre). Tests de contenu passés en « + ».
Résultat : 20 tests, 0 échec.
À tester manuellement : rendu des thèmes sombre et clair, textes en « − ».

## Profondeur des menus — 0.0.3.5
- Vidéo → Apparence : **Profondeur des menus** Oui (par défaut) ou Non.
- Oui : le titre reste sur le panneau ; le contenu est dans un encadré
  creusé, et chaque bloc de réglages dans un encadré encore plus profond.
  Non : menus à plat, comme avant.
- Fonctionne avec les trois thèmes ; les panneaux restent dans la fenêtre.

Tests mis à jour : appearance_test (encadrés, Oui / Non, pages dans la
fenêtre avec et sans profondeur), settings_walk_test, et les tests qui
cherchent des boutons dans les pages. Résultat : 20 tests, 0 échec.
À tester manuellement : effet de profondeur dans les trois thèmes.

## Échelle des menus, FOV et fichiers par menu — 0.0.3.6
- Vidéo → Échelle : **Échelle des menus**, 50 à 150 % (100 % par défaut).
  Zoom de tout l'affichage : panneaux, textes et boutons ensemble (comme un
  dézoom), en plus des réglages de taille des panneaux et du texte.
- Vidéo → Jeu : **Champ de vision (FOV)**, 50 à 110° (75° par défaut,
  vue d'origine), dans tous les mondes.
- Un fichier par menu de Paramètres, nommé d'après lui, dans user://parametres/
  depuis 0.0.4.22 (Windows : %APPDATA%\Godot\app_userdata\OrbMeka\parametres\) :
  parametres-generaux.json, video.json, attributs.json.
  L'ancien settings.json est lu une fois pour reprendre les réglages, sans
  être modifié ni supprimé. Un fichier illisible ne remet à zéro que son menu.

Test ajouté : tests/settings_files_test.gd (noms et contenu des trois
fichiers, reprise de l'ancien fichier, fichier illisible, échelle 50 à
150 % dans les petites et grandes fenêtres, FOV en jeu). Résultat : 21 tests, 0 échec.
À tester manuellement : échelle des menus à 50 et 150 %, sensation du FOV.

## Barres de réglage et interrupteur — 0.0.3.7
- Chaque réglage chiffré a une **barre** entre son nom et son champ :
  la glisser remplit le champ, saisir dans le champ déplace la barre.
  Pas adaptés : 0,1 pour les petites plages, 1 (%, °, px), 10 ms pour les blocs.
  Rien n'est enregistré avant Appliquer ; les ↻ remettent aussi les barres.
- Profondeur des menus : **interrupteur on/off** au lieu de Oui / Non.
  Les choix à trois options (synthèse, thème) gardent leurs boutons.

Test ajouté : tests/sliders_test.gd (barres liées aux champs, bornes, pas,
réinitialisations, interrupteur, place dans les petites fenêtres).
Résultat : 22 tests, 0 échec.
À tester manuellement : prise en main des barres à la souris et au clavier,
aspect de l'interrupteur dans les trois thèmes.

## Enregistrement automatique et menu de gauche en % — 0.0.3.8
- Plus de bouton **Appliquer** : chaque changement (champ, barre, choix,
  interrupteur, ↻) est enregistré et appliqué aussitôt. Retour et Échap
  gardent donc tout. Une valeur invalide affiche un message et n'est pas
  enregistrée ; Entrée dans un champ réaffiche la valeur enregistrée.
- Vidéo → Panneaux : **Largeur du menu de gauche** en % de la largeur du
  panneau, 5 à 40 % (15 % par défaut). L'ancien réglage en px est ignoré.

Tests mis à jour : enregistrement immédiat (barres, interrupteur, ↻,
saisie), plus de bouton Appliquer, menu de gauche en %. Résultat : 22 tests, 0 échec.
À tester manuellement : saisie au clavier dans les champs (pas de saut du
curseur), glisser les barres, menu de gauche à 5 et 40 %.

## Paramètres dans la pause — 0.0.3.9
- Pause : bouton **Paramètres** en 2e position, sous Reprendre. Il ouvre le
  même panneau Paramètres ; Retour et Échap reviennent à la pause, F1 aux mondes.
- En partie, chaque réglage s'applique aussitôt : FOV, souris, taille du
  texte du jeu, thème, échelle… et les attributs dans un monde développeur.
- Monde par défaut : l'onglet Attributs reste dans la colonne de gauche,
  mais explique qu'il faut passer le monde en mode développeur et le propose.
  Confirmation claire : « irréversible », sans retour au mode par défaut
  (Annuler sélectionné). Après confirmation, les attributs deviennent
  modifiables et s'appliquent tout de suite ; le mode est enregistré.

Test ajouté : tests/pause_settings_test.gd (bouton, retour, Échap, F1,
réglages en direct, passage au mode développeur avec confirmation).
Résultat : 23 tests, 0 échec.
À tester manuellement : régler en pause puis reprendre (souris, FOV).

## Taille des zones et boutons, texte à 13 px — 0.0.3.10
- Vidéo → Zones : **Taille des zones et boutons**, 50 à 150 % (100 % par
  défaut). Change la hauteur et la largeur minimales des boutons et des
  zones de saisie, les marges (dont celle entre le bord du menu et le texte)
  et les espaces entre éléments. Ne change ni le texte ni la largeur des
  menus ; le texte reste toujours dans sa zone et occupe toute la largeur
  disponible. Remplace l'« échelle des menus » de 0.0.3.6 (réglage ignoré).
- Taille du texte : **13 px par défaut** (texte courant réellement à 13 px ;
  titres, boutons et notes en proportion). 18 px redonne la taille d'avant.
- Paramètres : la mise en page est refaite aussitôt après chaque réglage.

Test mis à jour : settings_files_test (zones et boutons à 50, 100 et 150 %,
texte inchangé et toujours dans sa zone, largeur des menus inchangée,
textes élargis avec le menu). Résultat : 23 tests, 0 échec.
À tester manuellement : rendu à 50 et 150 %, lisibilité à 13 px, mise à
jour immédiate de la colonne de gauche dans Paramètres.

## Taille des menus appliquée après réglage — 0.0.3.11
- Largeur des menus, menu de gauche, taille des zones et taille du texte :
  enregistrées tout de suite, mais le menu ne change pas pendant qu'on
  glisse la barre (elle ne bouge plus sous la souris). La nouvelle taille
  s'applique en quittant Paramètres, avec le bouton **Appliquer la taille
  des menus** (Vidéo, sous Texte) ou avec Entrée dans un champ.
- Les autres réglages restent appliqués aussitôt.

Tests mis à jour : sliders_test (taille inchangée pendant le réglage, bouton,
sortie de Paramètres), pause_settings_test. Résultat : 23 tests, 0 échec.
À tester manuellement : glisser les barres de Vidéo puis Appliquer.

## Contrôles — 0.0.3.12
- Paramètres → **Contrôles**, entre Vidéo et Attributs, depuis l'accueil et
  depuis la pause : Avancer, Reculer, Aller à gauche, Aller à droite, Sauter,
  Casser, Poser, Bloc précédent, Bloc suivant.
- Cliquer le bouton d'une action, puis appuyer sur la touche ou le bouton de
  souris voulu : clic gauche, clic droit, clic molette, molette haut / bas,
  boutons 4 et 5. **Échap : aucune touche.** F1, F2, F3 et Échap sont réservées.
  Une touche déjà prise est retirée de l'autre action (message).
- ↻ par action et ↻ Tout réinitialiser. Appliqué aussitôt, en partie aussi.
- Par défaut : une touche par direction, à la place de W A S D (Z Q S D sur
  un clavier AZERTY, affichées ainsi), Espace, clic gauche / droit, molette.
  Les flèches restent toujours actives pour marcher.
- Enregistré dans user://controles.json.
- Paramètres : minimum et maximum toujours affichés, même en synthèse « − ».

Test ajouté : tests/controls_test.gd (onglet, choix clavier et souris, Échap,
touches réservées, ↻, fichier, en pause). Résultat : 24 tests, 0 échec.
À tester manuellement : jouer avec des touches changées (clavier et souris).

## Portées de casse et de pose — 0.0.3.13
- Attributs → Blocs : **Portée de casse** et **Portée de pose**, de 1 à
  20 blocs (5 par défaut, comme avant). Distance maximale à laquelle on peut
  casser, et à laquelle on peut poser. La visée va jusqu'à la plus grande.
- Comme les autres attributs : réglables en mode développeur ; un monde par
  défaut garde 5 blocs.

Test ajouté : tests/reach_test.gd (casse et pose refusées au-delà de leur
portée, acceptées en deçà, mondes développeur et par défaut).
Résultat : 25 tests, 0 échec.
À tester manuellement : casser et poser loin avec de grandes portées.

## Coordonnées — 0.0.3.14
- Axes : **X** largeur (est-ouest), **Y** hauteur, **Z** longueur (nord-sud).
  Coordonnées de la case des pieds ; Y = 1 debout sur le sol plat.
- Apparition en **X 0, Y 1, Z 0**, au centre de la base. Les blocs de
  démonstration sont décalés d'une case vers -Z pour libérer ce point.
  Après une chute, on réapparaît au même endroit, sur les blocs posés s'il y en a.
- Vidéo → Jeu : **Afficher les coordonnées** (interrupteur, désactivé par
  défaut) : X · Y · Z en haut à droite, sous les rappels F1 à F3, en direct.
- Informations du monde (F3) : **Votre position actuelle** en tête.

Test ajouté : tests/coordinates_test.gd (apparition, interrupteur, position
en haut à droite, suivi du joueur, réapparition, F3). prototype_test adapté.
Résultat : 26 tests, 0 échec.
À tester manuellement : lecture des coordonnées en marchant et en sautant.

## Se baisser — 0.0.3.15
- Contrôles : **Se baisser**, touche **Y** par défaut (modifiable), à maintenir.
- Baissé : on avance, recule et va de côté bien plus lentement (1,5 m/s par
  défaut), la vue descend un peu, et on est plus lourd : la chute est plus
  rapide (gravité 28 m/s² au lieu de 14).
- Attributs → **Se baisser** (sous Marche) : Avancer baissé, De côté baissé,
  Reculer baissé, Gravité baissé. Mode développeur, comme les autres attributs.

Test ajouté : tests/crouch_test.gd (vitesses, chute plus rapide, réglages,
touche Y, catégorie). Résultat : 27 tests, 0 échec.
À tester manuellement : se baisser en marchant et en tombant.

## Personnage — 0.0.3.16
- Paramètres → **Personnage**, entre Contrôles et Attributs (aussi en pause) :
  **Garçon** et **Fille** (environ 14 ans), **Homme** et **Femme**. Chacun a un
  petit aperçu dessiné en code : tête ronde (une « orbe »), couleurs propres
  à OrbMeka, sans rien reprendre d'autres jeux.
- Le choix est enregistré aussitôt (user://personnage.json) ; on est ce
  personnage en partie (indiqué dans Informations du monde), même si on ne
  peut pas encore se voir. Garçon par défaut.

Test ajouté : tests/character_test.gd (onglet, quatre personnages, choix,
fichier, en partie et en pause, fichier invalide). Résultat : 28 tests, 0 échec.
À tester manuellement : aspect des quatre aperçus dans les trois thèmes.

## Hauteur de la vue — 0.0.3.17
- Attributs → **Vue** (sous Se baisser) : **Hauteur des yeux**, en blocs,
  de 0,3 à 3 (1,62 par défaut, comme avant). 1 = vue à un bloc du sol,
  2 = à deux blocs. Deux décimales possibles (1,9 ; 2,15) ; barre au pas de 0,01.
- Baissé, la vue descend un peu sous cette hauteur. Mode développeur seulement,
  comme les autres attributs ; un monde par défaut garde 1,62.
- Au-delà de 1,8 bloc, la vue passe au-dessus du corps du joueur (taille
  inchangée) : elle peut entrer dans un plafond bas.

Test ajouté : tests/eye_height_test.gd (catégorie, décimales, arrondi à
0,01, bornes, monde développeur et par défaut, se baisser). Résultat : 29 tests, 0 échec.
À tester manuellement : sensation de la vue à 1 et à 2,5 blocs.

## Mode pour se baisser — 0.0.3.18
- Contrôles → catégorie **Se baisser** : **Maintenir** (par défaut : rester
  appuyé) ou **Basculer** (un appui pour se baisser, un autre pour se
  relever). Enregistré dans controles.json ; ↻ et ↻ Tout réinitialiser.
- Correction : la touche par défaut est maintenant la touche **marquée Y**
  sur le clavier du joueur. Sur un clavier suisse ou allemand (QWERTZ), Y et
  Z sont inversés : avant, il fallait appuyer sur Z pour se baisser.
- Rappel : la vue descend un peu quand on est baissé.

Test ajouté : tests/crouch_mode_test.gd (choix, fichier, Maintenir et
Basculer en partie, ↻). Résultat : 30 tests, 0 échec.
À tester manuellement : se baisser avec Y (QWERTZ) dans les deux modes.

## Chat peluche — 0.0.3.19
- Paramètres → Personnage : 5e choix, **Chat**, façon peluche toute mignonne :
  grosse tête ronde, grands yeux brillants, joues roses, oreilles roses,
  rayures douces, petit corps assis, queue relevée et foulard violet.
- Création originale d'OrbMeka, dessinée en code : elle ne copie aucune
  peluche ni aucun personnage existant.
- Comme les autres personnages : on est ce chat en partie (Informations du
  monde), sans pouvoir encore se voir.

Test mis à jour : character_test (cinq personnages, choix du chat, en partie).
Résultat : 30 tests, 0 échec.
À tester manuellement : aspect du chat dans les trois thèmes.

## Brioche, chat mochi — 0.0.3.20
- Paramètres → Personnage : 6e choix, **Brioche**, chat « mochi » blanc
  couché, tout mignon : grosse tête douce, grands yeux noirs brillants,
  joues pêche avec petits traits, nez en cœur, sourire, oreilles lavande,
  petite queue, et une **couronne dorée** à orbes turquoise, inclinée.
- Création originale d'OrbMeka, dans l'esprit des peluches mochi, sans
  reprendre de personnage existant (ni visage, ni couleurs, ni nom).
- Aperçu de référence : docs/idees/brioche-0.0.3.20.png.

Test mis à jour : character_test (six personnages, choix de Brioche).
Résultat : 30 tests, 0 échec.
À tester manuellement : aspect de Brioche dans les trois thèmes.

## Brioche retouché — 0.0.3.21
- Oreilles **arrondies** (plus de pointe), intérieur lavande.
- Dos et queue **bien visibles** : gris très clair et fin contour gris
  autour du chat, lisible sur fond sombre comme sur fond clair.
- La version précédente reste archivée : Archives/orb-meka 0.0.3.20 et
  docs/idees/brioche-0.0.3.20.png. Nouvel aperçu : docs/idees/brioche-0.0.3.21.png.

Tests : 30 tests, 0 échec (dessin seulement).
À tester manuellement : aspect de Brioche dans les trois thèmes.

## Peaux, coordonnées justes et vitrine — 0.0.3.22
- **Coordonnées** : Y = hauteur des pieds au-dessus du sol plat, en blocs
  (1 bloc = 1 m). **Y 0** debout sur le sol plat (avant : Y 1), Y 3 au
  sommet d'une colline de 3 blocs, Y 25 sur le plus haut bloc permis.
  L'écart venait de là : le jeu comptait le sol comme Y 1, alors que les
  écrans d'information comptent les hauteurs à partir du sol.
- Accueil → Informations, F3 et Comment jouer donnent les mêmes repères :
  base X et Z de -64 à 63, génération de -20 à 20, construction de -57 à 57
  (cette limite n'était pas annoncée), sommets en Y.
- **Personnage** : trois couleurs de peau pour Garçon, Fille, Homme, Femme :
  peau claire en haut, brune au milieu, foncée en bas, chats tout en bas.
  Enregistré dans personnage.json (« skin ») ; un ancien fichier reste
  lisible et garde le ton d'avant du personnage.
- **Accueil** : tous les personnages sautent sur la vitrine (12 humains et
  les 2 chats), à la place des blocs sauteurs. Règle : la vitrine fera
  toujours sauter tous les personnages existants.

Test ajouté : tests/world_consistency_test.gd (textes et valeurs réelles :
base, zone générée, collines, hauteur et zone de construction, Y 0).
Tests mis à jour : coordinates, character, menu_style, attributes, history_resume,
pause, prototype, shortcuts_selection (numéro de version).
Résultat : 31 tests, 0 échec.
À tester manuellement : aspect des personnages 3D de la vitrine et des
aperçus de peau (trois thèmes), lecture des coordonnées en grimpant.

## Enfants et nouveaux animaux, en 3D — 0.0.3.23
- **Personnage** : l'ancien Garçon et l'ancienne Fille (≈ 14 ans) sont
  remplacés par quatre enfants : **Garçon 9 ans**, **Fille 9 ans**,
  **Garçon 14 ans**, **Fille 14 ans**, chacun dans les trois couleurs de peau.
  Style OrbMeka : grosse tête ronde, grands yeux brillants, joues roses,
  petite orbe brodée sur le haut. Homme et Femme ne changent pas.
- **Animaux** (rangée du bas) : Chat, Brioche, puis **Écureuil** (gland-orbe
  turquoise), **Renard** (foulard turquoise), **Tortue** (carapace lavande,
  orbe dorée) et **Lapin bleu** (oreilles tombantes, médaillon doré).
  Créations originales : aucune copie d'un personnage connu.
- Les huit nouveaux sont modélisés dans **Blender** (sources_blender/personnages.blend),
  exportés en .glb (assets/characters/) et montrés **en 3D** dans le menu.
  Prototypes de chacun (3 au plus) dans **idee/** (docs/idees/personnages/ depuis 0.0.4.21) ; le meilleur est gardé
  (renard : le 2 ; les autres : le 3).
- Ancien personnage.json : « boy » devient Garçon 14 ans, « girl » Fille 14 ans,
  avec la même peau. Défaut : Garçon 14 ans, peau claire.
- **Accueil** : 30 personnages avec les peaux, c'est trop pour la vitrine.
  Elle n'en fait plus sauter que trois nouveautés : Fille 9 ans, Renard,
  Lapin bleu.

Tests mis à jour : character (12 personnages, 24 cartes, aperçus 3D et
peaux, anciens fichiers), menu_style (vitrine à 3), pause, prototype,
shortcuts_selection, history_resume (numéro de version).
Résultat : 31 tests, 0 échec.
À tester manuellement : aspect des aperçus 3D dans les trois thèmes et dans
la version Web, vitrine de l'accueil.

## Courir — 0.0.3.24
- **Contrôles** : nouvelle action **Courir**, touche **R** par défaut
  (la touche R du clavier du joueur, en QWERTZ comme ailleurs). Maintenir
  pour courir, relâcher pour marcher.
- **Attributs → Courir** (sous Marche) : Avancer, De côté, Reculer en
  courant, **8,5 m/s** par défaut (marche : 5,5 m/s). Comme les autres
  attributs : utilisés dans un monde en mode développeur.
- Se baisser l'emporte sur courir : baissé, on reste lent.
- Vitrine : mêmes sauteurs qu'en 0.0.3.23, nouveau bandeau.

Test ajouté : tests/run_test.gd (touche R, vitesses, se baisser prioritaire,
réglages). Tests mis à jour : crouch, settings_walk (ordre des catégories),
interface_info (24 champs), pause, prototype,
shortcuts_selection, history_resume (numéro de version).
Résultat : 32 tests, 0 échec.
À tester manuellement : courir en jeu avec R, et changer la touche.

## Modes pour courir — 0.0.3.25
- **Contrôles → Courir** : nouvelle catégorie, sous Se baisser, avec trois
  modes dans cet ordre :
  - **Maintenir** (défaut, comme en 0.0.3.24) : courir tant que R est enfoncé.
  - **Maintenir conditionnel** : un appui sur R lance la course, qui continue
    touche relâchée. Elle s'arrête si l'on s'arrête de marcher, saute, se
    baisse, met en pause (Échap), ouvre un menu ou perd le focus ; il faut
    ensuite réappuyer sur R.
  - **Basculer** : un appui pour courir, un autre pour marcher.
- Enregistré dans controles.json (run_mode) ; les anciens fichiers restent
  lisibles (Maintenir).
- Comment jouer : touches Y (se baisser) et R (courir) et leurs modes.
- Vitrine de l'accueil : Fille de 9 ans, renard et lapin bleu courent en
  aller-retour dans l'herbe, devant la place (sans animation des jambes).

Test ajouté : tests/run_mode_test.gd (trois modes, chaque interruption,
réappui nécessaire, anciens fichiers). Tests mis à jour : menu_style
(vitrine qui court), pause, prototype,
shortcuts_selection, history_resume (numéro de version).
Résultat : 33 tests, 0 échec.
À tester manuellement : ressenti des trois modes en jeu, affichage de la
catégorie Courir dans Contrôles (bouton « Maintenir conditionnel »), vitrine
de l'accueil (coureurs visibles selon la taille de la fenêtre).

## Voir son corps — 0.0.3.26
- En jeu (toujours en première personne), le personnage choisi dans
  Paramètres → Personnage est visible, surtout en regardant en bas :
  torse, bras et jambes pour les humains, l'animal entier pour les animaux
  et Brioche. Il tourne avec le joueur et projette son ombre au sol.
- La caméra garde la hauteur des yeux réglée (Attributs → Vue), même pour
  un petit personnage ou un animal : on voit alors l'animal sous soi.
- Humains : la tête, juste sous la caméra, cacherait la vue ; elle est
  cachée à l'œil (coupe au cou), mais l'ombre reste entière.
- Le corps ne gêne ni la visée, ni casser, ni poser (aucune collision).
- Les modèles de la vitrine et du jeu sont fabriqués au même endroit
  (scripts/character_model.gd). Pas encore d'animation des jambes.

Test ajouté : tests/body_test.gd (tous les personnages : corps visible,
hauteur des yeux, pieds au sol, tête cachée, ombre, peau, pas de cible).
Tests mis à jour : pause, prototype, shortcuts_selection, history_resume
(numéro de version). Résultat : 34 tests, 0 échec.
À tester manuellement : aspect du corps en jeu (regard en bas, en marchant,
en se baissant, pour chaque personnage), ombre, vitrine de l'accueil.

## Deux touches et clic sur le personnage — 0.0.3.27
- Paramètres → Personnage : un clic sur l'aperçu (image ou modèle 3D) ou
  sur le cadre choisit le personnage, comme son nom. La carte prend le
  focus : Tab, flèches et Entrée continuent de marcher.
- Paramètres → Contrôles : chaque action a un bouton **2e touche…** et ✕.
  - Une seule touche : comme avant.
  - La même touche deux fois : **double appui** (deux appuis à 300 ms au
    plus) ; l'action dure tant que le second appui est tenu.
  - Deux touches différentes : **en même temps** (par exemple Maj + Z),
    dans n'importe quel ordre.
  - Le nom de l'action indique « double appui » ou « en même temps ».
    ✕ ou Échap pendant le choix de la 2e touche la retire.
  - Même combinaison sur deux actions : retirée de l'autre, avec message.
    Touche seule d'une action incluse dans la combinaison d'une autre :
    avertissement (les deux se déclenchent).
- Enregistré dans user://controles.json (« second » en plus de la touche) ;
  les anciens fichiers à une touche restent lus tels quels.

Tests ajoutés : tests/key_combos_test.gd (double appui, délai, en même
temps dans les deux ordres, pause, interface, conflits, ancien
controles.json) ; tests/character_test.gd (clic sur l'aperçu, flèches,
Entrée). Tests mis à jour : pause, prototype, shortcuts_selection,
history_resume (numéro de version). Résultat : 35 tests, 0 échec.
À tester manuellement : ressenti du double appui et de Maj + Z en jeu,
place des boutons 2e touche et ✕ dans Contrôles, clic sur les cartes
du menu Personnage (curseur main), vitrine de l'accueil.

## Launcher et Quitter — 0.0.4
- Accueil : **Aller au launcher**, puis **Quitter le jeu** tout en bas
  (Quitter est caché dans un navigateur).
- Launcher (version Windows seulement, pour le propriétaire tant que le
  dépôt est privé) : passe par GitHub CLI déjà connecté sur le PC, sans
  jeton gardé par le jeu.
  - **Dernière version** en haut, puis toutes les versions des Releases,
    groupées par 0.0.x et espacées, avec leur nom (docs/HISTORIQUE.txt).
  - « Installer et jouer » télécharge le zip Windows dans
    user://launcher/<version>/ (AppData), puis lance la version ;
    « Jouer » si elle est déjà installée ; « Ouverte » = celle-ci (retour
    à l'accueil).
  - Pendant qu'une autre version tourne, cette fenêtre se réduit ; elle
    revient au launcher dès que l'autre version est fermée. Les anciennes
    versions n'ont donc pas besoin du bouton.
  - Releases disponibles depuis 0.0.2.6 (les plus anciennes n'en ont pas).

Test ajouté : tests/launcher_test.gd (groupes, noms, dossier installé,
boutons de l'accueil, page, Échap). Tests mis à jour : interface_info et
menu (boutons de l'accueil), pause, prototype, shortcuts_selection,
history_resume (numéro de version). Résultat : 36 tests, 0 échec.
Essai réel sur le PC : liste de 40 versions avec noms, téléchargement de
0.0.3.26 dans AppData, lancement, retour au launcher à sa fermeture.
À tester manuellement : boutons en bas de l'accueil (petite fenêtre),
lisibilité de la liste, lancer une ancienne version puis la fermer.

## Launcher à part — 0.0.4.1
- Le launcher ressemble à une application séparée : fond gris uni (le
  monde de l'accueil disparaît), panneau et boutons gris, titre de
  fenêtre « OrbMeka — Launcher ». « Retour au jeu » en haut à gauche.
- En haut : **Dernières versions jouées** (6 au plus, la plus récente en
  bas), enregistrées dans user://launcher/versions-jouees.json. La version
  ouverte compte comme jouée.
- En bas : gros bouton vert **▶ Jouer** (toujours la dernière version, avec
  son nom) et **▼** vert collé à sa droite : il déplie toutes les versions
  en dessous, groupées par 0.0.x, de la plus ancienne à la dernière, tout
  en bas (la liste s'ouvre déjà défilée jusqu'à elle). ▼ à nouveau : replie.

Test mis à jour : tests/launcher_test.gd (écran à part, versions jouées,
6 au plus, ordre, boutons verts, ▼). Tests mis à jour : pause, prototype,
shortcuts_selection, history_resume (numéro de version).
Résultat : 36 tests, 0 échec. Capture réelle vérifiée (1280×720).
À tester manuellement : ressenti « hors du jeu », lancer une ancienne
version depuis les versions jouées et depuis ▼, petite fenêtre.

## Courir plus vite — 0.0.4.2
- **Contrôles** : trois nouvelles actions sous Courir, avec deux touches par
  défaut (par lettre) : **Accélérer** R + T, **Ralentir** R + F, **Vitesse
  normale** R + G. Pas R + D : D (Aller à droite) remettrait la vitesse
  normale en courant de côté. Touches et deuxième touche modifiables.
- Accélérer maintenu : la vitesse monte peu à peu jusqu'au maximum ; elle
  reste ensuite tant qu'on court (R tenu, Basculer, ou même R relâché), et
  même après un saut ou un baissé, y compris en Maintenir conditionnel.
- Ralentir maintenu : redescend, jamais sous la course normale. Vitesse
  normale : retour immédiat à la course normale. Ces touches font aussi courir
  (R + T en mode Basculer ne coupe pas la course).
- Vrai arrêt (aucune touche de déplacement), pause ou fenêtre quittée :
  vitesse normale.
- **Attributs → Courir** : Vitesse maximale (14 m/s, en avançant ; les
  autres directions suivent en proportion), Accélération (3 m/s²),
  Ralentissement (6 m/s²), avec bornes, ↻ et validation.
- Comment jouer et vitrine de l'accueil (le renard accélère) mis à jour.

Test ajouté : tests/run_faster_test.gd (accélération progressive, maximum,
ralentissement, vitesse normale, saut, arrêt, pause, modes, attributs,
anciens controles.json et attributs.json, menus). Tests mis à jour :
interface_info (27 champs), pause, prototype, shortcuts_selection,
history_resume (numéro de version). Résultat : 37 tests, 0 échec.
À tester manuellement : ressenti de l'accélération, R + T / R + F / R + G
en jeu dans les trois modes, vitrine du renard.

## Vitesse aux flèches — 0.0.4.3
Remplace les touches de la 0.0.4.2 (R + T, R + F, R + G retirés, avec leurs
attributs ; les anciens fichiers restent lisibles, sans avertissement).
- **Contrôles** : **Plus vite** (↑) et **Moins vite** (↓), sous Courir,
  modifiables avec deuxième touche facultative. ↑ ↓ ne font plus avancer ni
  reculer ; ← → restent pour aller de côté. Les flèches s'affichent ← ↑ → ↓.
- ↑ maintenue : la marche **et** la course accélèrent peu à peu, ensemble (la
  course reste plus rapide que la marche) ; ↓ maintenue : elles ralentissent.
  Se baisser n'est pas touché. La vitesse choisie reste jusqu'au prochain
  changement (arrêt, saut et pause ne la changent pas).
- **Attributs** : vitesses normales de marche et de course dans Marche et
  Courir (inchangées) ; nouvelle catégorie **Changer de vitesse**, sous Se baisser : vitesse
  maximale (200 %, jusqu'à 500 %), vitesse minimale (50 %, de 10 à 100 %),
  rapidité pour accélérer et pour ralentir (40 %/s chacune, jusqu'à 300 %/s).
- Comment jouer et vitrine de l'accueil (le renard accélère puis ralentit).

Test ajouté : tests/speed_change_test.gd (remplace run_faster_test : touches,
accélération progressive, maximum, minimum, marche et course, baissé, vitesse
gardée, attributs, anciens controles.json et attributs.json, menus). Tests
mis à jour : controls et key_combos (plus de flèche ↑ pour avancer),
interface_info (28 champs), eye_height et settings_walk (ordre des catégories), numéro de version. Résultat : 37 tests, 0 échec.
À tester manuellement : ressenti de ↑ ↓ en marchant et en courant, limites.

## Vitesse par défaut — 0.0.4.4
- **Contrôles** : nouvelle action **Vitesse par défaut**, **R + ↓** ensemble
  par défaut (sous Moins vite) : retour immédiat à 100 %, même si ↓ reste
  tenue. Modifiable comme les autres. En mode Basculer, R + ↓ bascule aussi
  la course (R est dedans).
- ↑ ↓ changent maintenant aussi la vitesse quand on se baisse (même %
  que la marche et la course).
- Comment jouer, aide de Attributs → Changer de vitesse et vitrine mis à jour.

Test mis à jour : tests/speed_change_test.gd (R + ↓ dans Contrôles et par
deux touches, retour à 100 %, rien en pause, baissé suit ↑ ↓) ; numéro de
version (pause, prototype, shortcuts_selection, history_resume).
Résultat : 37 tests, 0 échec.
À tester manuellement : R + ↓ en jeu, ↑ ↓ en étant baissé.

## Voler — 0.0.4.5
- **Contrôles** : nouvelle action **Voler**, **Espace deux fois** par défaut
  (choix de l'utilisateur ; mécanique courante, non protégée). Le premier
  appui fait sauter, le second lance le vol ; Espace deux fois à nouveau :
  on retombe. Modifiable comme les autres.
- En vol : pas de gravité ; **Sauter** (Espace) maintenu monte, **Se
  baisser** (Y) maintenu descend (on ne se baisse pas en vol) ; ZQSD/WASD
  et ← → pour avancer, reculer, aller de côté. Plafond : 60 m.
- **Attributs → Voler** (sous Se baisser) : Avancer, De côté, Reculer en
  volant (10 m/s, un peu plus que courir), Monter et Descendre (7 m/s).
  ↑ ↓ (Plus vite / Moins vite) comptent aussi en vol.
- **Contrôles** : le bouton de deuxième touche affiche « Aucune » (au lieu
  de « 2e touche… ») quand il n'y en a pas.
- **Vitrine** : les trois personnages volent, montent et descendent en
  avançant (pas encore d'animation de vol).
- Comment jouer mis à jour. Issues #39 (Voler) et #45 (Attributs de vol).

Test ajouté : tests/fly_test.gd (touche, double appui, attributs, sans
gravité, vitesses dans chaque direction, monter, descendre, ↑ ↓, plafond,
sol, retour de la gravité, anciens fichiers, menus, « Aucune »). Tests mis à
jour : menu_style (vitrine en vol), key_combos (« Aucune »), interface_info
(33 champs), settings_walk et speed_change (ordre des catégories), numéro de
version. Résultat : 38 tests, 0 échec.
À tester manuellement : ressenti du vol, double appui sur Espace (saut puis
vol), montée et descente, vitrine.

## Chaque vitesse à part — 0.0.4.6
Issue #105. Remplace R + ↓ (0.0.4.4) ; un ancien controles.json garde ses
autres touches, R + ↓ y est ignoré.
- **↑ ou ↓ seule** : tout le déplacement (marche, course, baissé, vol),
  comme avant.
- **↑ / ↓ + W** : la marche seule (et la marche baissée) ; **+ R** : la
  course seule ; **+ clic gauche** : la casse plus ou moins rapide ; **+ clic
  droit** : la pose. Avec une autre touche, la flèche seule ne compte pas ; un
  clic avec ↑, ↓ ou ⌫ ne casse ni ne pose.
- **⌫ + W, R, clic gauche ou clic droit** : cette valeur par défaut ;
  **⌫ deux fois** : tout par défaut.
- **Monde par défaut** : 75 à 150 %, casse et pose fixes. **Mode
  développeur** : limites de Attributs → Changer de vitesse (50 à 200 % par
  défaut, réglables de 10 à 500 %), casse et pose réglables.
- 13 nouvelles actions dans Contrôles, modifiables (⌫ affiché « ⌫ »).
- Comment jouer, aide des Attributs et vitrine mis à jour.

Test ajouté : tests/speed_targets_test.gd (touches, combinaisons, marche,
course, casse, pose, limites des deux modes, ⌫, clic sans casser, ancien
controles.json, menus, Comment jouer). Tests mis à jour : speed_change (⌫
deux fois, monde développeur), numéro de version. Résultat : 39 tests, 0 échec.
Corrigé en passant : « 150 % » dans Comment jouer cassait la mise en forme du
texte.
À tester manuellement : ↑ + W, ↑ + R, ↑ + clic en jeu (sans casser), ⌫,
mode Basculer (↑ + R bascule aussi la course).

## Tout avec ↑ ↓ + A — 0.0.4.7
- **↑ + A / ↓ + A** (Tout plus vite / Tout moins vite) : tout le déplacement
  (marche, course, baissé, vol), à la place de la flèche seule, qui ne fait
  plus rien. **⌫ + A** (Déplacement par défaut) : cette vitesse à 100 %.
- Une touche de déplacement qui sert à un réglage ne fait pas bouger tant
  que ↑, ↓ ou ⌫ est tenue : **A ne va pas à gauche**, et W n'avance pas non
  plus (même règle).
- Ancien controles.json avec ↑ ou ↓ seules (ancien défaut) : relu comme
  ↑ + A / ↓ + A.
- Comment jouer, aide des Attributs et vitrine mis à jour.

Tests mis à jour : speed_targets (↑ + A, ⌫ + A, A sans aller à gauche,
ancien défaut relu), speed_change (touches par défaut), numéro de version.
Résultat : 39 tests, 0 échec.
À tester manuellement : ↑ + A et ↓ + A en jeu, ↑ + W (sans avancer), ⌫ + A.

## Voler vite et Contrôles rangés — 0.0.4.8
- **Courir en volant** : la touche Courir (R, avec son mode) fait voler
  vite. Attributs → Voler : Avancer, De côté, Reculer en volant vite
  (15 m/s ; 10 m/s sans courir). ↑ + R compte aussi. Monter et descendre ne
  changent pas. En vol, Espace (monter) n'arrête pas la course en Maintenir
  conditionnel.
- **Contrôles rangés en 4 parties**, chacune avec son titre : Mouvements
  (marcher, sauter, se baisser, courir, voler), Blocs (casser, poser,
  changer de bloc), Vitesses (toutes les combinaisons ↑ ↓ ⌫), Menus (Échap,
  F1, F2, F3 : affichées, réservées, non modifiables). Blocs à part plutôt
  que 3 parties : casser et poser ne sont ni des mouvements ni des vitesses.

Test ajouté : tests/controls_groups_test.gd (parties, chaque action une
fois, ordre, Menus non modifiables, voler vite, attributs, ancien
attributs.json). Tests mis à jour : interface_info (36 champs), numéro de
version. Résultat : 40 tests, 0 échec.
À tester manuellement : R en vol, lisibilité des parties de Contrôles.

## Trois vues — 0.0.4.9
Issue #85 (Vues du joueur).
- **F4** passe de la **première personne** à la **vue de derrière**, puis à
  la **vue de devant** (on voit son personnage de face), puis revient.
- La visée (casser, poser, portée) reste celle des yeux, quelle que soit la
  vue. Caméra à 4 m, rapprochée si un bloc est entre elle et les yeux.
- Hors première personne, le corps est entier (tête comprise) ; en
  première personne, il reste coupé au cou comme avant.
- F4 est réservée, comme F1 à F3 : affichée dans Contrôles → Menus, dans les
  rappels en haut à droite et dans Comment jouer. La vue revient à la
  première personne en entrant dans un monde.

Test ajouté : tests/views_test.gd (F4, trois vues, positions, visée, corps
entier, bloc derrière, animal, FOV, Contrôles → Menus, rappels, Comment
jouer). Tests mis à jour : controls_groups (F4 dans Menus), numéro de
version. Résultat : 41 tests, 0 échec.
À tester manuellement : F4 en jeu (aspect des vues, corps, ombre), caméra
près des murs, viser et casser en vue de derrière.

## Retour au mode par défaut — 0.0.4.10
- Un monde en mode développeur peut **repasser en mode par défaut** :
  Mes mondes → ⚙️ Paramètres du monde → « Repasser en mode par défaut », ou
  en partie, Paramètres → Attributs → « Repasser ce monde en mode par
  défaut » (attributs par défaut appliqués tout de suite).
- Le monde garde alors la mention définitive **« Mode développeur utilisé au
  moins une fois »**, dans Informations du monde (F3, à chaque niveau de
  détail) et dans Paramètres du monde. Enregistrée dans worlds.json
  (developer_used) ; une copie la garde.
- La confirmation du mode développeur ne dit plus « sans retour » : seule la
  mention est irréversible.
- Ancien worlds.json : les mondes déjà en mode développeur ont la mention,
  les autres non.

Test ajouté : tests/developer_return_test.gd (catalogue, mention gardée et
enregistrée, copie, ancien worlds.json, Paramètres du monde, Informations du
monde, retour en partie). Tests mis à jour : world_mode (retour possible),
menu (developer_used enregistré), numéro de version. Résultat : 42 tests, 0 échec.
À tester manuellement : repasser en mode par défaut depuis Mes mondes et en
pause, lecture des Informations du monde (F3).

## Sons des menus — 0.0.4.11
Issue #96 (milestone Sons).
- Trois petits sons, **fabriqués par le jeu** (ondes simples, aucun fichier
  ni son d'un autre jeu) : un tic au **survol** d'un bouton actif, un bip
  montant au **clic**, un bip descendant pour **Retour** et **Annuler**.
  Interrupteurs Oui / Non compris. Ils jouent aussi en pause.
- **Paramètres généraux → Son** : Volume des menus (60 % par défaut, 0 =
  muet), enregistré dans parametres-generaux.json.
- Les autres sons viendront avec ce qu'ils accompagnent (personnages,
  animaux, monde).

Test ajouté : tests/menu_sounds_test.gd (sons générés, fin sans clic,
survol, clic, retour, volume, muet, ancien fichier). Tests mis à jour :
attributes (0 accepté pour le volume), settings_files (ordre des clés),
interface_info (37 champs), numéro de version. Résultat : 43 tests, 0 échec.
Corrigé avant publication : erreur de type dans menu_sounds.gd (vue dans
l'éditeur).
À tester manuellement : écouter les sons (agréables ? trop forts ?),
volume, muet.

## Voix des personnages — 0.0.4.12
- **Choisir un personnage** (Paramètres → Personnage) le fait parler ou
  crier.
- **Humains** : synthèse vocale de l'ordinateur (voix française du système,
  rien d'enregistré ni de téléchargé), plus aiguë pour les plus jeunes. Des
  phrases propres à chaque âge, qui tournent : 9 ans plus enfantines
  (« Jouons ensemble ! », « On construit une cabane ? »), 14 ans (« Salut !
  On part explorer ? »…), adultes (« Bonjour ! Prêt à construire ? »…). Sans
  voix française sur l'ordinateur : pas de voix.
- **Animaux** : cris fabriqués par le jeu (ondes simples, aucun fichier ni
  son d'un autre jeu) : miaulements des deux chats, petits cris de
  l'écureuil, jappements du renard, grognement doux de la tortue, couinement
  et petit bond du lapin.
- **Paramètres généraux → Son** : Volume des personnages (80 %, 0 = muet).
- Note : sur la version Web, le navigateur choisit la voix ; certaines voix
  de navigateur passent par Internet (seule la phrase du jeu est envoyée,
  aucune donnée du joueur).

Test ajouté : tests/character_voices_test.gd (voix ou cri pour chaque
personnage, phrases par âge, hauteur de voix, cris générés et différents,
choix dans Personnage, muet, réglage). Tests mis à jour : interface_info
(38 champs), numéro de version. Résultat : 44 tests, 0 échec.
À tester manuellement : écouter les voix (Windows : voix française
installée ?) et les cris, volume.

## Vrais sons d'animaux — 0.0.4.13
- Le **chat**, **Brioche** et le **lapin** ont de vrais sons enregistrés,
  sous licence **CC0 1.0** (domaine public, libre même pour un usage
  commercial) : « Meow » (IgnasD, OpenGameArt), « Kitten Mew »
  (AntumDeluge, OpenGameArt), et un bruit de patte extrait de « Bunny
  hutch » n° 1376 (Joseph Sardin, BigSoundBank : 0,45 s vers 32,7 s, mono,
  fondus). Fichiers dans assets/sounds/, origine et licences dans
  assets/sounds/CREDITS.txt et dans le cadre juridique de README.md.
- Renard, écureuil et tortue : pas de son CC0 trouvé sans compte ; ils
  gardent leur cri fabriqué par le jeu.
- Règle du projet assouplie (avec accord) : assets externes seulement sous
  licence vérifiée et notée (CLAUDE.md).

Test mis à jour : tests/character_voices_test.gd (sons enregistrés du chat,
de Brioche et du lapin, durées, crédits). Résultat : 44 tests, 0 échec.
À tester manuellement : écouter les trois sons (volume, propreté).

## Paramètres repliables — 0.0.4.14
- Dans Paramètres, **chaque titre** (catégories des Paramètres généraux, de
  Vidéo et des Attributs, parties de Contrôles, modes Se baisser et Courir)
  se **réduit ou se développe d'un clic** : ▾ développé, ▸ réduit (il ne
  reste que le titre).
- **En haut de Paramètres**, une petite ligne de trois boutons, de gauche à
  droite : **Tout réduire**, **Tout développer**, et le choix à l'ouverture,
  qui change à chaque clic : « comme la dernière fois » (défaut), « tout
  développé », « tout réduit ».
- Titres réduits et choix enregistrés dans user://menus.json (fichier
  abîmé : valeurs par défaut).

Test ajouté : tests/folds_test.gd (titres, clic, contenu caché, trois
boutons, choix à l'ouverture, menus.json, redémarrage, fichier abîmé).
Tests mis à jour : controls_groups (▾ et blocs), appearance (profondeur),
numéro de version. Résultat : 45 tests, 0 échec.
À tester manuellement : cliquer les titres, Tout réduire / Tout développer,
fermer et rouvrir Paramètres dans chaque mode.

## Vitesses actuelles — 0.0.4.15
- Nouvelle catégorie **Attributs → Vitesses actuelles** (sous Changer de
  vitesse) : Déplacement, Marche, Course, Casse et Pose actuels, en % de la
  normale (100 % par défaut), avec leur barre.
- Dans un monde en **mode développeur**, les touches de vitesse (↑ ↓ + A, W,
  R, clic ; ⌫) changent ces valeurs **en direct** : le champ et la barre
  bougent, et c'est enregistré dans attributs.json peu après le dernier
  changement. On peut aussi les régler à la main ; en jeu, elles restent
  dans les limites de Changer de vitesse.
- Monde par défaut : les touches changent la vitesse en jeu seulement
  (75 à 150 %), rien n'est enregistré.

Test ajouté : tests/current_speeds_test.gd (attributs, barres, touches en
direct, maximum, ⌫, réglage à la main, limites, monde par défaut, ancien
fichier). Tests mis à jour : interface_info (43 champs), eye_height et
settings_walk (ordre des catégories), numéro de version.
Résultat : 46 tests, 0 échec.
À tester manuellement : en mode développeur, ouvrir la pause → Attributs
après avoir changé les vitesses, et voir les barres.

## Launcher et menus plus lisibles — 0.0.4.16
- **Launcher** : la page prend toute la hauteur de la fenêtre, **Jouer tout
  en bas**. ▼ ouvre la liste des versions **au-dessus** de Jouer (la plus
  récente tout en bas, les plus anciennes en haut), **6 versions** visibles
  au plus, moins si la place manque ; les versions jouées restent au-dessus
  (repliées seulement si la liste manque vraiment de place). Lignes plus
  basses, marges réduites.
- **Bug corrigé** : en ouvrant la liste ▼, le bas de la page sortait de la
  fenêtre (tout n'était plus visible).
- **Traits fins gris**, discrets, entre les lignes des menus (Paramètres,
  Contrôles, launcher), pour suivre une ligne de gauche à droite.
- **Espacements** : un peu moins entre les lignes, un peu plus entre les
  catégories et les sous-titres.
- **Attributs → Voler** en sous-catégories repliables : Normal, Rapide,
  Monter et descendre.

Test ajouté : tests/layout_lines_test.gd (Jouer en bas, liste au-dessus, 6
versions, ouvrir/fermer plusieurs fois sans rien couper, traits, espacements,
sous-catégories). Tests mis à jour : launcher (nouvel ordre), folds
(sous-titres), numéro de version. Résultat : 47 tests, 0 échec.
À tester manuellement : launcher (ouvrir ▼ plusieurs fois, petite fenêtre),
lisibilité des traits et des espacements.

## Licences et version Web corrigée — 0.0.4.17
- **Paramètres → Licences** (dernier onglet, Windows et Web) : OrbMeka,
  **Godot Engine (licence MIT, texte complet)**, ses composants et leurs
  licences, sons CC0, polices. **LICENCES.txt** (docs/LICENCES.txt : textes
  complets) est mis à côté du jeu dans chaque zip et sur itch.io ; une
  ancienne version reconstruite (Actions → Build → Run workflow) le reçoit
  aussi. Obligatoire pour la licence MIT de Godot.
- **Version Web** :
  - **Couleurs** : le navigateur utilise le rendu « Compatibility », où la
    lumière paraissait trop forte (couleurs délavées) ; soleil × 0,7 et
    lumière ambiante × 0,55 dans ce rendu seulement (Windows inchangé).
    Vérifié en comparant les deux rendus sur le PC.
  - **Souris** : la vue tournait trop vite, car le mouvement était agrandi
    selon la taille de l'affichage (plus petit dans un navigateur) ; le jeu
    prend maintenant le mouvement réel de la souris.
  - **Symboles et emojis** (↻ ▾ ← ⌫ ▼ ✕ ⚙ ✏ ➕ 🗑 📋) : carrés vides dans le
    navigateur, faute de polices du système ; polices de secours DejaVu Sans
    et Noto Emoji (licences libres, texte joint), dans le navigateur
    seulement.
- Point juridique : nom « OrbMeka » absent de TMview ; cadre juridique de
  README.md complété.

Tests ajoutés : tests/licences_test.gd (mentions, LICENCES.txt à jour, zips,
onglet Licences, polices, chaque symbole affichable), tests/web_fixes_test.gd
(lumière du rendu Web, souris). Tests mis à jour : controls et
settings_walk (onglet Licences), numéro de version. Résultat : 49 tests, 0 échec.
À tester manuellement : la version Web sur itch.io (couleurs, sensibilité de
la souris, symboles), l'onglet Licences, LICENCES.txt dans le zip.

## Dépôt public et launcher par Internet — 0.0.4.18
- **Launcher par Internet** : il lit les versions (API GitHub) et télécharge
  les zips Windows directement, sans compte ni jeton, dès que le dépôt est
  public. Tant qu'il est privé (ou sans Internet), GitHub CLI connecté reste
  utilisé en secours, comme avant.
- **Web et Windows séparés** : pas de bouton « Aller au launcher » dans la
  version Web (un navigateur ne lance pas de programme), comme Quitter.
- **Licence** : fichier LICENSE, « tous droits réservés » (lire le code et
  jouer : permis ; copier, modifier, revendre : non, sans accord) ; Godot,
  sons et polices gardent leur licence. Rappel dans Paramètres → Licences.
- **Aucun autre jeu cité** dans le dépôt : règles de CLAUDE.md et cadre
  juridique de README.md reformulés ; un test le vérifie. Vérifié avant
  de rendre le dépôt public : pas d'e-mail personnel ni de clé dans
  l'historique.

Test ajouté : tests/public_launcher_test.gd (API, adresses, https seul,
secours GitHub CLI, Web sans launcher, LICENSE, aucun autre jeu cité).
Essai réel : téléchargement par Internet (redirection comprise) vérifié sur
un fichier public. Tests mis à jour : numéro de version.
Résultat : 50 tests, 0 échec.
À tester manuellement : une fois le dépôt public, launcher sur un PC sans
GitHub CLI (liste, téléchargement, lancement).

## Version Web plus juste — 0.0.4.19
- **Couleurs** : en partie, le sable et la pierre restaient blancs et l'herbe
  très pâle dans le navigateur (rendu « Compatibility »). Réglé en comparant
  des captures des deux rendus sur le PC : conversion des couleurs simple
  (tonemap linéaire), soleil × 0,48, lumière ambiante × 0,38, en partie et
  à l'accueil. Windows inchangé.
- **Souris** : encore trop sensible dans le navigateur ; mouvements × 0,4
  dans la version Web seulement (réglage Sensibilité de la souris en plus).
- Rappel : le launcher est dans la version Windows (Release → zip →
  OrbMeka.exe → Aller au launcher) ; la version Web vient du même code,
  exporté par la GitHub Action.

Tests mis à jour : web_fixes (nouvelles valeurs, souris), numéro de
version. Résultat : 50 tests, 0 échec.
À tester manuellement : version Web sur itch.io (couleurs en partie et à
l'accueil, sensibilité de la souris).

## Touches à la carte — 0.0.4.20
Issue #101 (combinaisons avancées).
- **Bouton +** à droite de ↻ sur chaque action, avec un petit menu :
  - **Nouvelle option** : une autre façon de faire l'action, sur une ligne
    « Avancer (2) » (3 options au plus). Un clic sur « ▾ Avancer » cache ou
    montre les autres options ; ✕ à droite d'une option la retire.
  - **Appuyer en même temps** : une touche de plus à droite, reliée par une
    accolade ︸.
  - **Appuyer après** : une étape de plus, après une flèche → (0,5 s au plus
    entre deux ; la même touche deux fois = double appui).
  - 4 touches au plus par combinaison ; ✕ sur chaque touche ajoutée.
  Remplace la colonne « 2e touche » : les anciens réglages sont convertis
  (double appui = « Espace → Espace », en même temps = « ↑ + A »).
- **Recherche**, trois barres fines qui se combinent : **Partie**
  (Mouvements, Vitesses…), **Nom** (Avancer…), **Touche** (« Espace » ;
  « Z, X » ou « Z - X » = Z puis X ; « ↑ A » ou « ↑ + A » = en même temps ;
  « Clic gauche » en deux mots). Nom et partie : un morceau, ou les
  premières lettres (« tpv » = Tout plus vite, « mar pl » = Marche plus vite).
- **Conflits** (à droite de la barre Partie) : seulement les actions en
  conflit (même combinaison, ou une touche seule dans la combinaison d'une
  autre, sauf quand le jeu l'évite déjà) ; sinon « Aucun conflit. ».
- Nouvelle partie **Vitesses — réinitialiser** (les ⌫), séparée de Vitesses.
- controles.json : nouveau format (options, étapes) ; les anciens fichiers
  restent lus.

Tests : key_combos réécrit (format, conversions, limites, en même temps,
après, options, menu +, accolade, flèche, ✕, recherche, Conflits, jeu).
Tests mis à jour pour le nouveau format : controls, controls_groups,
crouch_mode, fly, folds, layout_lines, speed_change, speed_targets, et
d'autres (comparaisons converties), numéro de version.
À tester manuellement : + et son menu, accolade et flèche à l'écran, les
trois barres, Conflits, une combinaison « après » en jeu.

## Plus sûr et mieux rangé — 0.0.4.21
- **Sécurité du launcher** : chaque zip téléchargé est vérifié avec
  l'empreinte SHA-256 publiée par GitHub ; s'il ne correspond pas, il est
  effacé et jamais ouvert. Seuls des numéros de version simples sont acceptés
  (un nom piégé ne peut pas écrire hors du dossier du launcher), et seuls les
  serveurs de GitHub sont contactés, même après une redirection.
- **AppData** : chaque version installée pèse environ 100 Mo. Seules les
  versions jouées récemment (6) restent installées ; les autres sont retirées
  au lancement d'une version. Bouton **Supprimer** sur chaque version
  installée (réinstallable). L'ancien settings.json (avant 0.0.3.6), déjà
  repris, est effacé.
- **Code** : app.gd (2 374 lignes) découpé en cinq fichiers empilés :
  app_base (constantes, variables, outils), app_controls, app_launcher,
  app_settings, app (pages, mondes, partie). Même jeu.
- **Fichiers** : main.tscn à la racine (doublon inutilisé) et
  project.godot.before-prototype retirés (toujours dans l'historique Git) ;
  idee/ rangé dans docs/idees/personnages/.
- Petit bug corrigé : un ajustement de taille différé pouvait s'exécuter
  après la fermeture des menus.

Test ajouté : tests/security_cleanup_test.gd (versions piégées, serveurs,
empreintes, nettoyage, Supprimer, fichiers rangés). Tous les tests :
51 / 51 en parallèle.
À tester manuellement : launcher (installer, Supprimer, nettoyage après
plusieurs versions jouées).

## Contrôles plus rapides — 0.0.4.22
- **↻ Tout réinitialiser** (Contrôles) : 5,7 s → 0,2 s. Toutes les touches
  sont changées d'un coup : un seul fichier écrit, la page refaite une fois.
- **↻ par partie** à droite des titres Mouvements, Blocs, Vitesses et
  Vitesses — réinitialiser : seules les touches de cette partie reviennent
  par défaut.
- **Une touche changée** : 0,19 s → 0,01 s (seules l'action changée et
  celle qui a perdu la touche sont refaites ; recherche appliquée une fois).
- **Accolade** dessinée sous les touches simultanées, du début de la
  première touche à la fin de la dernière. Le menu + dit
  **Simultanément** (avant : Appuyer en même temps).
- **AppData** : les fichiers de réglages (parametres-generaux, video,
  personnage, attributs, controles, menus) sont rangés dans un dossier
  **parametres/**. Les anciens y sont copiés au premier lancement, sans
  rien écraser, et restent à leur place pour les versions plus anciennes du
  launcher (qui gardent ainsi leurs réglages) ; worlds.json et launcher/ ne
  bougent pas.
- **Choix des Contrôles** (ex. mode pour se baisser) : seuls leurs boutons
  sont mis à jour, plus toute la page.
- **Optimisation générale** (mesurée) : changer de page refaisait tout le
  thème des menus (≈ 2 000 éléments) à chaque fois. Il n'est maintenant refait
  que si la taille du texte, des zones, le thème, la profondeur ou la synthèse
  ont changé. Changer de page : 0,16–0,42 s → moins de 0,01 s ; pause :
  0,3 s → 0,001 s ; retour aux mondes : 0,26 s → 0,002 s. Le reste mesuré
  (ouvrir un monde 0,02 s, image en jeu, démarrage ≈ 1 s) était déjà correct.

Tests mis à jour : controls_groups (↻ par partie, Tout réinitialiser),
key_combos (accolade, Simultanément), settings_files (dossier parametres,
copie sans écraser), character, controls.
À tester manuellement : aspect de l'accolade et des ↻ de partie, rapidité
ressentie, réglages bien retrouvés après la mise à jour.

## Monde 1 : dossier et sauvegarde — 0.0.5
Début de la série « Monde ».
- **Un dossier par monde** : user://mondes/<identifiant>/ (Windows :
  %APPDATA%\Godot\app_userdata\OrbMeka\mondes\).
  - **monde.json** : nom, **graine**, mode, date de création, version du format.
  - **joueur.json** : position et regard (le personnage reste celui de Paramètres).
  - **zones/modifications.json** : blocs posés et cassés, seulement les
    **différences** avec le terrain recalculé par la graine (format 1, prévu
    pour être converti en zones puis en terrain lisse).
- **Sauvegarde** : pause, retour aux mondes, Quitter, fermeture de la
  fenêtre ou de l'onglet, et toutes les 45 s. Rechargement à l'ouverture.
- **worlds.json reste l'index** (le plus simple : liste et anciens mondes
  inchangés). Les mondes existants reçoivent leur dossier au premier lancement.
- **Dupliquer** copie aussi constructions et position ; **Supprimer** efface
  le dossier (après confirmation).
- **Fichier illisible** : renommé « .illisible-<date> » et gardé, avec un
  message ; jamais écrasé. Écriture sûre (fichier temporaire, puis remplacement).
- **Paramètres du monde** affiche la graine et la taille du monde.

Tests : world_save (sauvegarde, redémarrage en deux processus, migration,
duplication, suppression, fichiers illisibles) ; tous les tests réussis.
À tester manuellement : sauvegarde en fermant l'onglet du navigateur,
absence de saccade pendant la sauvegarde régulière.

## Monde 2 : zones — 0.0.5.1
Note de lecture historique : les mentions « 16 possible », « 25 cm possible plus tard »
et « 16 × 16 × 16 points » de l'annonce initiale ci-dessous ne sont pas le plan courant.
Le plan confirmé ci-dessus les remplace : zones de 8 m, sous-cellules de 50 cm,
16 cellules par axe (17 sommets avec les bords). L'annonce ancienne est conservée.

- **Zones de 8 m × 8 m × 8 m**, empilées en hauteur (constante ZONE_SIZE dans
  scripts/world_zones.gd ; 16 possible). Choix : 8 = 2 × 2 × 2, et à
  l'étape 3, 1 m = 8 parties de 50 cm (grille de 16 × 16 × 16 points par
  zone, DENSITY_STEP ; 25 cm possible plus tard).
- **Affichage fusionné** par section de 8 m (une seule forme par section,
  faces cachées retirées) : un bloc posé ou cassé ne recalcule que sa section,
  et la voisine s'il est au bord.
- **Chargement autour du joueur**, les zones proches d'abord, travail étalé
  (3 ms au plus par image, sans thread, compatible Web) ; zones lointaines
  déchargées (enregistrées avant si modifiées). **Paramètres → Vidéo →
  Distance de chargement** : 1 à 8 zones (4 par défaut).
- **Sauvegarde** : un fichier compressé par zone modifiée
  (zones/zone_X_Y_Z.bin, format 2, type « blocs ») ; aucun fichier pour une
  zone jamais touchée ou revenue au terrain de la graine.
- **Migration** : le fichier de l'étape 1 (zones/modifications.json) est
  réparti en zones, puis gardé sous le nom modifications-etape1.json.
- Terrain inchangé : même graine, même monde.
- **F3 (Informations du monde)** affiche en direct les zones chargées, le temps
  de chargement d'une zone, de recalcul et les images/s.

Mesures sur PC (RTX 4070 portable, Forward+) : chargement d'une zone 0,1 ms ;
recalcul après une modification 0,8 ms ; image la plus chargée pendant un
déplacement 3 ms ; 159 images/s ; ouverture du monde entier (distance 8) 0,5 s.
Web (itch.io) : pas mesuré par Claude (page privée). À mesurer avec F3 :
si les images/s sont trop basses, baisser la Distance de chargement.

Tests : zones (découpage, chargement/déchargement étalé, sauvegarde par zone,
migration étape 1, même monde pour une même graine, recalcul limité),
world_save mis à jour ; tous les tests réussis.
À tester manuellement : aspect des blocs fusionnés, fluidité en marchant
loin, mesures F3 dans le navigateur.

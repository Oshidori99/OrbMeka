# OrbMeka — référence pour ChatGPT

Ce document est un contexte à lire ; il ne promet pas un chargement automatique par les outils.
Références partagées : [CLAUDE.md](CLAUDE.md), [README.md](README.md),
[guide détaillé](docs/README.md). Les lire avant un travail pour éviter des consignes divergentes.

- Projet Godot / GDScript, Windows et Web. Répondre en français concis.
- Travailler sur dev ; publier dans main uniquement sur demande explicite de l'utilisateur.
  Suivre les procédures de tests et de version de CLAUDE.md quand le travail demandé les appelle.
- Respecter les règles d'originalité et de licences de CLAUDE.md et README.md.
- Une simple question ou analyse n'autorise pas à modifier le projet.
  Ne pas contrôler le PC sans accord. Signaler ce qui n'a pas été testé manuellement.
- Garder les données joueur dans user://, hors des sources ; conserver les .uid,
  laisser Godot gérer son cache et préserver les archives existantes hors du dépôt.
- Les constructions sont bien sauvegardées depuis 0.0.5 : blocs posés/cassés,
  position et regard. Les chemins actuels sont décrits dans docs/ORGANISATION.txt.

## Décision terrain à respecter

Les zones sont de **8 × 8 × 8 mètres**.
Pour le terrain lisse, chaque bloc de 1 m de côté est divisé en **2 × 2 × 2 = 8 sous-parties au total**,
chacune de **50 cm de côté**, soit **1/8 du volume** du bloc.
Une zone a donc 16 sous-cellules par axe ; la grille de sommets avec les deux bords
en compte 17 par axe. **Première version livrée en 0.0.5.8** (scripts/smooth_terrain.gd) : sol lisse,
creuser et ajouter 50 cm par clic ; aplanir et lisser depuis 0.0.5.9.

# Projet Phénix

[![Tests](https://github.com/jonathan-sousa/tactical-srd/actions/workflows/tests.yml/badge.svg)](https://github.com/jonathan-sousa/tactical-srd/actions/workflows/tests.yml)

Mini jeu tactique au tour par tour pour PC, en 2D vue de dessus sur grille, basé sur les règles publiées dans le SRD 5.2.1. « Projet Phénix » est un titre provisoire.

Le jeu enchaîne un écran titre, un menu, une intro narrative, un combat 1v1 (Guerrier contre Gobelin), une outro, avec options et sauvegarde. Le sprint 2 l'a peaufiné : toutes les règles d'un Guerrier de niveau 1 et d'un Gobelin guerrier, prévisions et retours en combat, graphismes, son et export Windows.

## Règles implémentées

Source : SRD 5.2.1. Chaque simplification est consignée, avec la règle officielle en regard, dans `docs/rules-deviations.md`.

- **Tour de combat** : déplacement case par case, action, action bonus, réaction ; Foncer, Se désengager, Esquiver, Chercher, Se relever.
- **Attaques** : au corps à corps, à distance et lancées, portées normale et longue, désavantage avec un ennemi au contact, ligne de vue (un obstacle est un abri total), avantage et désavantage qui s'annulent, coups critiques, attaques d'opportunité (le joueur est consulté à chaque fois).
- **Guerrier humain niveau 1, historique Soldat** : Great Weapon Fighting, Second Wind, Weapon Mastery (épée à deux mains : Graze, fléau : Sap, javelots : Slow), Savage Attacker, Inspiration héroïque.
- **Gobelin guerrier** : cimeterre et arc court, +1d4 dégâts avec l'avantage, Nimble Escape (se désengager ou se cacher par une action bonus).
- **Se cacher et chercher** : condition Invisible, attaque à l'aveugle d'une case, embuscade et surprise au début du combat. Un caché est trouvé par l'action Chercher, s'il finit son tour en vue d'un ennemi, si un ennemi finit son déplacement en vue de lui, par une Perception passive suffisante ou si on le heurte (règles de MJ, voir `docs/rules-deviations.md`).
- **0 PV** : mort du monstre, Guerrier inconscient et à terre, jets contre la mort, dégâts massifs, critique automatique au contact.
- **IA** : une action à la fois ; elle se cache, tire de loin, se désengage avant de reculer à l'abri, achève un Guerrier inconscient.

## Prérequis

- [Godot 4.7.2 stable](https://godotengine.org/download/archive/), version standard (pas .NET).
- [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) 6.2.3, déjà inclus dans `addons/gdUnit4`.

## Ouvrir le projet

1. Lancer Godot, cliquer sur **Importer**, choisir le `project.godot` à la racine du dépôt.
2. À la première ouverture, Godot importe les ressources dans `.godot/` (ignoré par Git).
3. Le plugin gdUnit4 est activé dans le projet : l'onglet **GdUnit** apparaît dans l'éditeur.

## Lancer le jeu

- Depuis l'éditeur : touche **F5**. Écran titre, menu, intro, combat, puis outro (ou écran de défaite). **Échap** ouvre le menu pause pendant le dialogue et le combat. Dans un dialogue, **Tab** passe la scène et **H** ouvre l'historique.
- Combat seul : ouvrir `scenes/combat/combat.tscn` puis touche **F6**.

Commandes du combat :

- clic sur une case bleue : se déplacer (le chemin passe en croix rouges s'il provoque une attaque d'opportunité) ;
- clic sur un ennemi : l'attaquer avec l'arme choisie ; le survol affiche les chances de toucher et les dégâts ;
- clic sur un ennemi caché (pion transparent), ou **Maj** + clic sur une case : attaque à l'aveugle ;
- trois premières lettres de la rangée du haut (**A Z E** en AZERTY) : choisir l'épée, le fléau ou les javelots ;
- **1** à **6** : Foncer, Se désengager, Esquiver, Second souffle, Chercher, Se relever ;
- **O** / **N** : répondre à une question (attaque d'opportunité, relance) ;
- **Espace** : finir le tour.
- En ligne de commande : `godot --path .`

## Mode démo

Le jeu peut se jouer tout seul, de l'écran titre à la fin de l'histoire, puis se fermer :

```sh
godot --path . -- --autoplay --seed=42 --speed=2
```

- `--seed=N` : graine des dés. Même graine, même code, même partie, à chaque fois.
- `--speed=N` : accélère le jeu (de 0,25 à 16, 1 par défaut).
- Le Guerrier est conduit par la même IA que le Gobelin. Le journal du combat est recopié dans la console (lignes `[démo]`), avec un résumé à la fin.
- La partie du joueur n'est pas touchée : le mode démo sauvegarde dans `user://autoplay_save.json`.
- Sans fenêtre, pour ne lire que le journal : ajouter `--headless` avant `--path`.

Pour reproduire un comportement signalé, il suffit de donner sa graine.

### Escarmouche

Une rencontre peut aussi se lancer directement, hors de l'histoire, avec le groupe voulu (ids des fiches de `data/characters`, séparés par des virgules) :

```sh
godot --path . -- --encounter=goblin_band --party=fighter_lvl1,fighter_lvl1
```

Le joueur commande alors le groupe. Avec `--autoplay`, l'IA joue les deux camps et le jeu se ferme à la fin du combat.


En ligne de commande, en mode headless :

```sh
GODOT_BIN=/chemin/vers/godot scripts/test.sh
```

Le script importe le projet, puis exécute toutes les suites de `tests/`. Le code de sortie vaut 0 si tout passe. Les rapports HTML et XML sont écrits dans `reports/` (ignoré par Git).

Pour un seul fichier : `scripts/test.sh -a res://tests/project_settings_test.gd`.

Les mêmes vérifications tournent sur GitHub Actions à chaque push, sur toutes les branches (`.github/workflows/tests.yml`) : toute la suite de tests, puis un démarrage du jeu qui échoue sur la moindre erreur ou le moindre avertissement.

Depuis l'éditeur : clic droit sur le dossier `tests/` puis **Run Tests**.

### Combats automatiques et graines

`CombatSimulator` (dans `rules/`) joue un combat entier sans affichage, les deux camps conduits par l'IA. Avec des dés à graine, le combat est déterministe. Trois familles de tests s'en servent :

- `tests/rules/reference_combats_test.gd` : une graine par comportement à garantir (embuscade et tir caché, Nimble Escape, Second souffle, Inspiration héroïque, Graze, Chercher, relevé sur un 20, stabilisé, mort, victoire). Les comportements sont décrits dans `tests/helpers/combat_scenarios.gd`.
- `tests/rules/invariants_test.gd` : 300 combats, et après chaque action des règles qui ne doivent jamais être violées (PV dans les bornes, une action et une action bonus par tour, une réaction entre deux tours, aucune action refusée à l'IA, combat toujours terminé…).
- `tests/scenes/combat_scene_test.gd` vérifie que la scène en mode démo joue exactement le même combat que le simulateur.

Si un changement voulu des règles ou de l'IA modifie les combats, retrouver une graine pour chaque comportement :

```sh
godot --headless --path . -s scripts/find_seeds.gd -- --max=3000
```

puis recopier les graines dans `tests/rules/reference_combats_test.gd`.

## Arborescence

```text
autoload/      singletons : SceneRouter, GameState, SaveManager, Settings, AudioManager, Autoplay
rules/         moteur de règles pur (RefCounted, aucun Node)
  actions/     actions du joueur et de l'IA (déplacement, attaque, se cacher…)
  events/      événements émis par le moteur, rejoués par la présentation
data/
  defs/        scripts des types de Resource (CharacterDef, WeaponDef…)
  characters/  .tres des personnages et monstres
  weapons/
  encounters/
  dialogues/
scenes/        title, menu, dialogue, combat, options, credits
ui/            composants réutilisables, Theme commun, textes et palette
assets/        tuiles, sprites, interface, police et sons (voir assets/CREDITS.md)
tests/         gdUnit4, en miroir de rules/ et autoload/
docs/          écarts de règles, notes d'architecture
scripts/       outils en ligne de commande
```

## Exporter le jeu

Les presets « Windows Desktop » et « Linux » sont dans `export_presets.cfg`. Chacun produit un exécutable unique, données intégrées, dans `build/` (ignoré par Git). Les dossiers `tests/`, `addons/`, `docs/` et `scripts/` sont exclus du jeu exporté.

1. Installer les modèles d'export de Godot 4.7.2 : menu **Éditeur > Gérer les modèles d'export > Télécharger et installer**. Pour Windows seul, il suffit de copier `version.txt` et les fichiers `windows_*_x86_64*.exe` de l'archive `.tpz` dans `%APPDATA%\Godot\export_templates\4.7.2.stable\`.
2. Menu **Projet > Exporter…**, choisir le preset, puis **Exporter le projet** (décocher « Exporter avec le débogage »).

En ligne de commande :

```sh
godot --headless --path . --export-release "Windows Desktop" build/windows/ProjetPhenix.exe
godot --headless --path . --export-release "Linux" build/linux/ProjetPhenix.x86_64
```

L'exécutable Windows porte l'icône du jeu, sa version (`config/version` de `project.godot`) et ses métadonnées (nom, éditeur, mentions). Il n'est pas signé : SmartScreen peut afficher un avertissement au premier lancement (« Informations complémentaires » puis « Exécuter quand même »).

## Publier une version

Le workflow `.github/workflows/release.yml` exporte le jeu pour Windows et Linux et publie les archives dans une Release GitHub, à chaque tag de version :

1. Mettre la même version dans `project.godot` (`config/version="1.2.0"`) et dans `export_presets.cfg` (`application/file_version` et `application/product_version`, avec un `.0` de plus : `1.2.0.0`). Un test vérifie qu'elles concordent.
2. Fusionner dans `main`, puis poser et pousser le tag :

```sh
git tag v1.2.0
git push origin v1.2.0
```

La Release « Projet Phénix 1.2.0 » apparaît avec `ProjetPhenix-1.2.0-windows.zip` et `ProjetPhenix-1.2.0-linux.tar.gz`, et des notes tirées des PR fusionnées. Le workflow refuse un tag qui ne correspond pas à la version du projet.

Pour vérifier l'export sans rien publier : onglet **Actions**, workflow **Release**, **Run workflow**. Les archives sont alors téléchargeables dans les artefacts du lancement.

## Rejouer un combat

Chaque combat est enregistré au fil des choix du joueur dans `user://replays/last_combat.json` (sous Windows : `%APPDATA%\Godot\app_userdata\Projet Phénix\replays\`). Le fichier contient la graine des dés, la situation de départ du Guerrier et ses choix ; l'IA et les dés étant déterministes, cela suffit à reproduire tout le combat. Il est écrit après chaque choix : il reste utilisable si le jeu est quitté en plein combat.

Pour rejouer le dernier combat :

```sh
godot --path . -- --replay=user://replays/last_combat.json --speed=2
```

Le combat se rejoue sous les yeux, puis la console dit s'il aboutit au même résultat que l'enregistrement (`[démo] rejeu : conforme…`) avant de quitter. Si les règles ou l'IA ont changé depuis, le rejeu s'arrête au premier choix qui ne correspond plus et le signale. Joint à un rapport de bug, ce fichier permet de reproduire exactement la partie.

## Enchaînement des écrans

- `SceneRouter` (autoload) est le seul point d'entrée pour changer de scène, avec un fondu au noir.
- `GameState` (autoload) suit l'étape courante de `data/story.tres` et les PV du Guerrier. Une étape terminée (dialogue lu, combat gagné ou perdu) indique quoi afficher ensuite.
- Une défaite sans étape de défaite définie mène à l'écran de défaite : « Réessayer le combat » relance l'étape à l'identique.
- Quitter un combat en cours le fait recommencer au prochain « Continuer ».

## Sauvegarde et options

- Sauvegarde automatique à chaque étape franchie, dans `user://save_1.json` (sous Windows : `%APPDATA%\Godot\app_userdata\Projet Phénix\`). Pas de sauvegarde en plein combat.
- Écriture atomique (fichier `.tmp` puis renommage) et champ `version` avec migrations. Un fichier illisible ou d'une version inconnue affiche un message et grise « Continuer ».
- Seul du JSON validé champ par champ est lu depuis `user://`, jamais une Resource.
- Les options (volumes général, musique et effets, plein écran, texte agrandi) sont dans `user://settings.cfg`, indépendamment de la sauvegarde. Un fichier d'options plus ancien garde son volume général ; les nouveaux réglages prennent leur valeur par défaut.

## Conventions

- GDScript typé partout : l'avertissement `untyped_declaration` est réglé en erreur.
- Fichiers et dossiers en snake_case, classes en PascalCase via `class_name`, signaux au passé (`turn_ended`), constantes en UPPER_SNAKE.
- Rendu Compatibility, résolution de base 1280×720, stretch `canvas_items`, aspect `keep`.
- Commits en français, un par étape cohérente.

## Son

Trois bus audio (`default_bus_layout.tres`) : Master, Music et Effects, réglables séparément dans les options. L'autoload `AudioManager` enchaîne les musiques en fondu et joue les bruitages ; la présentation les déclenche à partir des événements du moteur. Sans écran (tests, intégration continue), il garde l'état sans rien jouer.

## État du jeu

Critères d'acceptation du brief :

- Partie complète depuis l'exécutable exporté (titre, menu, intro, combat, outro, retour au menu) : l'export Windows est produit et démarre sans erreur sur un PC Windows ; la partie complète au clavier et à la souris reste à jouer à la main depuis l'exécutable.
- La défaite propose de réessayer, et le réessai repart d'un combat propre : vérifié.
- Quitter puis Continuer reprend à la dernière étape franchie : vérifié, y compris après fermeture du jeu.
- Le journal affiche chaque jet avec son détail : vérifié et couvert par des tests.
- Tous les tests passent en ligne de commande : `scripts/test.sh`.
- Un deuxième Gobelin ne demande que de modifier `data/encounters/goblin_ambush.tres` (ajouter une entrée à `enemies`) : vérifié puis annulé. Seul `tests/scenes/combat_scene_test.gd`, qui vérifie les deux combattants de la rencontre v1, est à adapter dans ce cas.

Les simplifications de règles sont listées dans `docs/rules-deviations.md`.

## Licence et attribution

Les règles proviennent du System Reference Document 5.2.1, publié sous licence Creative Commons CC-BY-4.0. Mention d'attribution officielle, recopiée telle quelle depuis le SRD :

> This work includes material from the System Reference Document 5.2.1 (“SRD 5.2.1”) by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode.

Elle est aussi affichée dans l'écran Crédits, avec la licence de Godot Engine et de ses composants tiers.

gdUnit4 est distribué sous licence MIT (voir `addons/gdUnit4/LICENSE`).

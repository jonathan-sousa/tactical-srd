# Projet Phénix

Mini jeu tactique au tour par tour pour PC, en 2D vue de dessus sur grille, basé sur les règles publiées dans le SRD 5.2.1. « Projet Phénix » est un titre provisoire.

La v1 enchaîne un écran titre, un menu, une intro narrative, un combat 1v1 (Guerrier contre Gobelin), une outro, avec options et sauvegarde.

## Prérequis

- [Godot 4.7.2 stable](https://godotengine.org/download/archive/), version standard (pas .NET).
- [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) 6.2.3, déjà inclus dans `addons/gdUnit4`.

## Ouvrir le projet

1. Lancer Godot, cliquer sur **Importer**, choisir le `project.godot` à la racine du dépôt.
2. À la première ouverture, Godot importe les ressources dans `.godot/` (ignoré par Git).
3. Le plugin gdUnit4 est activé dans le projet : l'onglet **GdUnit** apparaît dans l'éditeur.

## Lancer le jeu

- Depuis l'éditeur : touche **F5**. Écran titre, menu, intro, combat, puis outro (ou écran de défaite). **Échap** ouvre le menu pause pendant le dialogue et le combat.
- Combat seul : ouvrir `scenes/combat/combat.tscn` puis touche **F6**. Clic sur une case bleue pour se déplacer, clic sur un ennemi adjacent pour attaquer, **Espace** pour finir le tour.
- En ligne de commande : `godot --path .`

## Lancer les tests

En ligne de commande, en mode headless :

```sh
GODOT_BIN=/chemin/vers/godot scripts/test.sh
```

Le script importe le projet, puis exécute toutes les suites de `tests/`. Le code de sortie vaut 0 si tout passe. Les rapports HTML et XML sont écrits dans `reports/` (ignoré par Git).

Pour un seul fichier : `scripts/test.sh -a res://tests/project_settings_test.gd`.

Depuis l'éditeur : clic droit sur le dossier `tests/` puis **Run Tests**.

## Arborescence

```text
autoload/      singletons : SceneRouter, GameState, SaveManager, Settings
rules/         moteur de règles pur (RefCounted, aucun Node)
  actions/     MoveAction, AttackAction, EndTurnAction
  events/      événements émis par le moteur
data/
  defs/        scripts des types de Resource (CharacterDef, WeaponDef…)
  characters/  .tres des personnages et monstres
  weapons/
  encounters/
  dialogues/
scenes/        title, menu, dialogue, combat, options, credits
ui/            composants réutilisables et Theme commun
assets/        placeholders : sprites, tiles, polices
tests/         gdUnit4, en miroir de rules/ et autoload/
docs/          écarts de règles, notes d'architecture
scripts/       outils en ligne de commande
```

## Enchaînement des écrans

- `SceneRouter` (autoload) est le seul point d'entrée pour changer de scène, avec un fondu au noir.
- `GameState` (autoload) suit l'étape courante de `data/story.tres` et les PV du Guerrier. Une étape terminée (dialogue lu, combat gagné ou perdu) indique quoi afficher ensuite.
- Une défaite sans étape de défaite définie mène à l'écran de défaite : « Réessayer le combat » relance l'étape à l'identique.
- Quitter un combat en cours le fait recommencer au prochain « Continuer ».

## Sauvegarde et options

- Sauvegarde automatique à chaque étape franchie, dans `user://save_1.json` (sous Windows : `%APPDATA%\Godot\app_userdata\Projet Phénix\`). Pas de sauvegarde en plein combat.
- Écriture atomique (fichier `.tmp` puis renommage) et champ `version` avec migrations. Un fichier illisible ou d'une version inconnue affiche un message et grise « Continuer ».
- Seul du JSON validé champ par champ est lu depuis `user://`, jamais une Resource.
- Les options (volume général, plein écran) sont dans `user://settings.cfg`, indépendamment de la sauvegarde.

## Conventions

- GDScript typé partout : l'avertissement `untyped_declaration` est réglé en erreur.
- Fichiers et dossiers en snake_case, classes en PascalCase via `class_name`, signaux au passé (`turn_ended`), constantes en UPPER_SNAKE.
- Rendu Compatibility, résolution de base 1280×720, stretch `canvas_items`, aspect `keep`.
- Commits en français, un par étape cohérente.

## Licence et attribution

Les règles proviennent du System Reference Document 5.2.1, publié sous licence Creative Commons CC-BY-4.0. Mention d'attribution officielle, recopiée telle quelle depuis le SRD :

> This work includes material from the System Reference Document 5.2.1 (“SRD 5.2.1”) by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode.

Elle sera aussi affichée dans l'écran Crédits (J6).

gdUnit4 est distribué sous licence MIT (voir `addons/gdUnit4/LICENSE`).

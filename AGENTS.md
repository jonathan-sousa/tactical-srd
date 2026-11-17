# Consignes pour les agents

Le brief complet du projet est dans le document « Brief agent — Mini tactical D&D 5.5 (Godot) ». Ce fichier en reprend les règles de travail.

## Méthode

- Avancer jalon par jalon (J0 à J6). Montrer un plan court avant chaque jalon (fichiers créés, choix notables, questions ouvertes) et ne passer au suivant qu'une fois le précédent validé.
- Poser les questions plutôt que de deviner sur le gameplay.
- Tests d'abord pour tout ce qui est dans `rules/`.
- Ne pas inventer de règles : la source de vérité est le SRD 5.2.1. Chaque simplification est consignée dans `docs/rules-deviations.md` avec la règle officielle en regard.
- Pas de sur-ingénierie : pas de système générique sans usage en v1, sauf les points d'extension prévus par le brief.
- Fin de jalon : résumé de ce qui est fait, de ce qui reste, et des étapes pour vérifier à la main.

## Code

- Godot 4.7.2 stable, GDScript typé partout (variables, paramètres, retours).
- `rules/` ne contient que des classes `RefCounted`, jamais de Node. La présentation ne calcule jamais une règle.
- Commenter les concepts Godot la première fois qu'ils apparaissent : le commanditaire vient de Ruby on Rails.
- Aucun addon autre que gdUnit4 sans proposition et justification préalables.
- Ne jamais charger une Resource (`.tres`, `.res`) depuis `user://`.

## Markdown

- Un paragraphe (ou un élément de liste) par ligne : ne jamais couper la prose pour respecter une longueur de ligne.

## Vérification

- Avant de considérer une tâche terminée : `GODOT_BIN=/chemin/vers/godot scripts/test.sh` doit sortir avec le code 0, et `godot --headless --path . --quit-after 30` ne doit afficher ni erreur ni avertissement.

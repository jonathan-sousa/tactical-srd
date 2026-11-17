## Définition d'une arme, éditable dans l'inspecteur et sauvegardée en .tres.
##
## Note Godot : une Resource est un objet de données sérialisable, un peu
## comme un modèle ActiveRecord sans base de données : ses champs `@export`
## apparaissent dans l'éditeur et sont écrits dans un fichier .tres.
## Ce n'est pas un Node : on peut la créer et la tester sans aucune scène.
class_name WeaponDef
extends Resource

## Identifiant stable, utilisé par la sauvegarde et le registre de données.
@export var id: StringName
@export var display_name: String
## Dés de dégâts sans modificateur, par exemple "2d6".
@export var damage_dice: String = "1d4"
@export var damage_type: DamageType.Type = DamageType.Type.BLUDGEONING
## Caractéristique utilisée pour l'attaque et les dégâts.
@export var ability: Abilities.Ability = Abilities.Ability.STRENGTH
## Allonge en pieds (5 ft = une case).
@export var reach_feet: int = 5
## Propriétés d'arme (Finesse, Lourde, maîtrises…). Vide en v1.
@export var properties: Array[StringName] = []

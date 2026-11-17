## Fiche d'un personnage ou d'un monstre, sauvegardée en .tres.
##
## Immuable pendant le combat : l'état qui change (PV, position) vit dans
## `Combatant`. Voir weapon_def.gd pour la notion de Resource.
class_name CharacterDef
extends Resource

## Identifiant stable, utilisé par la sauvegarde et le registre de données.
@export var id: StringName
@export var display_name: String
## Image du pion. Vide jusqu'aux placeholders du J3.
@export var sprite: Texture2D

# Note Godot : @export_group ne fait que regrouper les champs dans l'inspecteur.
@export_group("Caractéristiques")
@export var strength: int = 10
@export var dexterity: int = 10
@export var constitution: int = 10
@export var intelligence: int = 10
@export var wisdom: int = 10
@export var charisma: int = 10

@export_group("Combat")
@export var max_hp: int = 1
@export var armor_class: int = 10
## Vitesse en pieds, comme dans le SRD (30 ft = 9 m = 6 cases).
@export var speed_feet: int = 30
@export var proficiency_bonus: int = 2
@export var initiative_bonus: int = 0
@export var weapons: Array[WeaponDef] = []


func ability_score(ability: Abilities.Ability) -> int:
	match ability:
		Abilities.Ability.STRENGTH:
			return strength
		Abilities.Ability.DEXTERITY:
			return dexterity
		Abilities.Ability.CONSTITUTION:
			return constitution
		Abilities.Ability.INTELLIGENCE:
			return intelligence
		Abilities.Ability.WISDOM:
			return wisdom
		_:
			return charisma

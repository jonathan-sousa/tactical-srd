## Un combattant pendant un combat : sa fiche (immuable) et son état courant.
##
## La fiche (`CharacterDef`) est partagée et jamais modifiée ; tout ce qui
## change en combat (PV, position, réaction) vit ici. Les effets temporaires
## sont rangés dans CombatState (voir Effect).
class_name Combatant
extends RefCounted

enum Side { PLAYER, ENEMY }

var definition: CharacterDef
var side: Combatant.Side
var hp: int
var position: Vector2i
## Réaction encore disponible ? Une seule entre deux de ses tours (SRD).
var reaction_available: bool = true


func _init(p_definition: CharacterDef, p_side: Combatant.Side, p_position: Vector2i = Vector2i.ZERO) -> void:
	definition = p_definition
	side = p_side
	position = p_position
	hp = p_definition.max_hp


func is_down() -> bool:
	return hp <= 0


func armor_class() -> int:
	return definition.armor_class


## Bonus au jet d'attaque : modificateur de la caractéristique de l'arme +
## bonus de maîtrise.
func attack_bonus(weapon: WeaponDef) -> int:
	return damage_modifier(weapon) + definition.proficiency_bonus


## Modificateur ajouté aux dégâts : celui de la caractéristique de l'arme.
func damage_modifier(weapon: WeaponDef) -> int:
	return Abilities.modifier(definition.ability_score(weapon.ability))


## Retire des PV sans descendre sous 0. Renvoie les PV réellement perdus.
func take_damage(amount: int) -> int:
	assert(amount >= 0, "Des dégâts ne peuvent pas être négatifs.")
	var lost := mini(amount, hp)
	hp -= lost
	return lost


## Arme utilisée au corps à corps, pour attaquer comme pour les attaques
## d'opportunité : la première de la fiche. `null` sans arme.
func melee_weapon() -> WeaponDef:
	return null if definition.weapons.is_empty() else definition.weapons[0]


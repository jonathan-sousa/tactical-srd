## Attaque à l'aveugle sur une case où ne se trouve personne : elle rate
## (SRD « Unseen Attackers and Targets »).
class_name AttackedEmptyCellEvent
extends CombatEvent

var attacker: Combatant
var cell: Vector2i
var weapon: WeaponDef


func _init(p_attacker: Combatant, p_cell: Vector2i, p_weapon: WeaponDef) -> void:
	attacker = p_attacker
	cell = p_cell
	weapon = p_weapon

## Des dégâts ont été appliqués à une cible.
class_name DamageDealtEvent
extends CombatEvent

var target: Combatant
var amount: int
var damage_type: DamageType.Type
var hp_after: int
## Dégâts de la maîtrise Graze, infligés malgré un échec.
var is_graze: bool


func _init(p_target: Combatant, p_amount: int, p_damage_type: DamageType.Type, p_hp_after: int, p_is_graze: bool = false) -> void:
	target = p_target
	amount = p_amount
	damage_type = p_damage_type
	hp_after = p_hp_after
	is_graze = p_is_graze

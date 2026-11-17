## Des dégâts ont été appliqués à une cible.
class_name DamageDealtEvent
extends CombatEvent

var target: Combatant
var amount: int
var damage_type: DamageType.Type
var hp_after: int


func _init(p_target: Combatant, p_amount: int, p_damage_type: DamageType.Type, p_hp_after: int) -> void:
	target = p_target
	amount = p_amount
	damage_type = p_damage_type
	hp_after = p_hp_after

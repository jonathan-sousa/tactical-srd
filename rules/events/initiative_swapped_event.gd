## Alert : `combatant` a échangé son initiative avec celle de `ally`.
class_name InitiativeSwappedEvent
extends CombatEvent

var combatant: Combatant
var ally: Combatant


func _init(p_combatant: Combatant, p_ally: Combatant) -> void:
	combatant = p_combatant
	ally = p_ally

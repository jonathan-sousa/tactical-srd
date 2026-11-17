## Un combattant est tombé à 0 PV.
class_name CombatantDownedEvent
extends CombatEvent

var combatant: Combatant


func _init(p_combatant: Combatant) -> void:
	combatant = p_combatant

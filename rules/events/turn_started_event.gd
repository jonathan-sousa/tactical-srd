## Début du tour d'un combattant.
class_name TurnStartedEvent
extends CombatEvent

var combatant: Combatant
var round: int


func _init(p_combatant: Combatant, p_round: int) -> void:
	combatant = p_combatant
	round = p_round

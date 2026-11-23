## `mover` s'apprête à quitter l'allonge de `reactor` : le déplacement est
## suspendu jusqu'à ce que `reactor` décide de sa réaction.
class_name ReactionTriggeredEvent
extends CombatEvent

var reactor: Combatant
var mover: Combatant


func _init(p_reactor: Combatant, p_mover: Combatant) -> void:
	reactor = p_reactor
	mover = p_mover

## `reactor` a laissé passer `mover` sans attaque d'opportunité.
class_name ReactionDeclinedEvent
extends CombatEvent

var reactor: Combatant
var mover: Combatant


func _init(p_reactor: Combatant, p_mover: Combatant) -> void:
	reactor = p_reactor
	mover = p_mover

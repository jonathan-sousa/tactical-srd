## Le combat est terminé : `winner` est le camp vainqueur.
class_name CombatEndedEvent
extends CombatEvent

var winner: Combatant.Side


func _init(p_winner: Combatant.Side) -> void:
	winner = p_winner

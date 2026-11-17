## Fin du tour : la main passe au combattant suivant dans l'initiative.
class_name EndTurnAction
extends Action


func _execute(state: CombatState, _dice: Dice) -> Array[CombatEvent]:
	return state.advance_turn()

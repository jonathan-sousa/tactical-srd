## Fin du tour : la main passe au combattant suivant dans l'initiative.
class_name EndTurnAction
extends Action


func usable_while_incapacitated() -> bool:
	return true


func _execute(state: CombatState, dice: Dice) -> Array[CombatEvent]:
	return state.advance_turn(dice)

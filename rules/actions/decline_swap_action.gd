## Alert : garder son initiative. Le combat commence.
class_name DeclineSwapAction
extends Action


func answers() -> Script:
	return InitiativeSwapWindow


func _execute(state: CombatState, _dice: Dice) -> Array[CombatEvent]:
	state.pending = null
	return state.begin_first_turn()

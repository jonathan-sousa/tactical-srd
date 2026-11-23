## Garde le jet raté sans dépenser l'Inspiration héroïque : l'attaque se
## termine comme un échec (Graze compris).
class_name DeclineInspirationAction
extends Action


func answers() -> Script:
	return InspirationWindow


func _execute(state: CombatState, dice: Dice) -> Array[CombatEvent]:
	var window := state.pending as InspirationWindow
	state.pending = null
	var events := AttackSequence.finish(state, window.result, dice)
	events.append_array(state.resume_movement(window.resume))
	return events

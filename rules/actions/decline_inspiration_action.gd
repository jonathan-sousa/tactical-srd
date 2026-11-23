## Garde le d20 raté sans dépenser l'Inspiration héroïque : l'attaque se
## termine comme un échec (Graze compris), ou le jet contre la mort compte
## comme raté.
class_name DeclineInspirationAction
extends Action


func answers() -> Script:
	return InspirationWindow


# Le jet contre la mort se relance à 0 PV, inconscient.
func usable_while_incapacitated() -> bool:
	return true


func _execute(state: CombatState, dice: Dice) -> Array[CombatEvent]:
	var window := state.pending as InspirationWindow
	state.pending = null
	if window.result == null:
		return HitPoints.resolve_death_save(state, actor, window.death_save)
	var events := AttackSequence.finish(state, window.result, dice)
	events.append_array(state.resume_movement(window.resume))
	return events

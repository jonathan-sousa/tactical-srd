## Réaction refusée : le combattant laisse passer, garde sa réaction, et le
## déplacement suspendu reprend.
class_name DeclineReactionAction
extends Action


func answers() -> Script:
	return ReactionWindow


func _execute(state: CombatState, _dice: Dice) -> Array[CombatEvent]:
	var window := state.pending as ReactionWindow
	state.pending = null
	var events: Array[CombatEvent] = [ReactionDeclinedEvent.new(actor, window.mover)]
	events.append_array(state.resume_movement(window))
	return events

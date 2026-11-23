## Réaction refusée : le combattant laisse passer, garde sa réaction, et le
## déplacement suspendu reprend.
class_name DeclineReactionAction
extends Action


func is_reaction() -> bool:
	return true


func _execute(state: CombatState, _dice: Dice) -> Array[CombatEvent]:
	var window := state.reaction_window
	state.reaction_window = null
	var events: Array[CombatEvent] = [ReactionDeclinedEvent.new(actor, window.mover)]
	events.append_array(state.walk(window.mover, window.remaining_path, window.asked))
	return events

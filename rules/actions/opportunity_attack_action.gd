## Réaction : attaque d'opportunité contre le combattant qui quitte
## l'allonge (SRD « Opportunity Attacks »). Une attaque au corps à corps,
## juste avant qu'il ne parte ; puis son déplacement reprend s'il tient
## encore debout.
class_name OpportunityAttackAction
extends Action


func is_reaction() -> bool:
	return true


func _validate(_state: CombatState) -> StringName:
	if actor.melee_weapon() == null:
		return NO_WEAPON
	return &""


func _execute(state: CombatState, dice: Dice) -> Array[CombatEvent]:
	var window := state.reaction_window
	state.reaction_window = null
	actor.reaction_available = false
	var events := AttackAction.strike(state, actor, window.mover, actor.melee_weapon(), dice, true)
	if not window.mover.is_down() and not state.is_over:
		events.append_array(state.walk(window.mover, window.remaining_path, window.asked))
	return events

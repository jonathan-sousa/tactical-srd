## Réaction : attaque d'opportunité contre le combattant qui quitte
## l'allonge (SRD « Opportunity Attacks »). Une attaque au corps à corps,
## juste avant qu'il ne parte ; puis son déplacement reprend s'il tient
## encore debout.
class_name OpportunityAttackAction
extends Action


func answers() -> Script:
	return ReactionWindow


func _validate(_state: CombatState) -> StringName:
	if actor.melee_weapon() == null:
		return NO_WEAPON
	return &""


func _execute(state: CombatState, dice: Dice) -> Array[CombatEvent]:
	var window := state.pending as ReactionWindow
	state.pending = null
	actor.reaction_available = false
	return AttackSequence.begin(state, actor, window.mover, actor.melee_weapon(), dice, true, window)

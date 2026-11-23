## Dépense l'Inspiration héroïque pour relancer le d20 d'une attaque ratée.
##
## Avec avantage ou désavantage, le SRD ne permet de relancer qu'un des deux
## dés : on relance le plus bas, le seul qui peut améliorer le résultat.
class_name UseInspirationAction
extends Action


func answers() -> Script:
	return InspirationWindow


func _execute(state: CombatState, dice: Dice) -> Array[CombatEvent]:
	var window := state.pending as InspirationWindow
	state.pending = null
	actor.heroic_inspiration = false

	var old := window.result.d20
	var new_value := dice.roll_die(20)
	var rolls: Array[int] = []
	rolls.assign(old.rolls)
	var lowest := 0 if rolls.size() == 1 or rolls[0] <= rolls[1] else 1
	var replaced := rolls[lowest]
	rolls[lowest] = new_value
	var kept := rolls[0]
	if rolls.size() > 1:
		kept = maxi(rolls[0], rolls[1]) if old.mode == Dice.RollMode.ADVANTAGE else mini(rolls[0], rolls[1])
	var result := AttackResolver.with_d20(window.result, D20Roll.new(old.mode, rolls, kept))

	var events: Array[CombatEvent] = [
		InspirationUsedEvent.new(actor, replaced, new_value),
		AttackRolledEvent.new(result),
	]
	events.append_array(AttackSequence.finish(state, result, dice))
	events.append_array(state.resume_movement(window.resume))
	return events

## Alert : échange l'initiative du personnage avec celle d'un allié, puis le
## combat commence (voir InitiativeSwapWindow).
class_name SwapInitiativeAction
extends Action

var ally: Combatant


func _init(p_actor: Combatant, p_ally: Combatant) -> void:
	super(p_actor)
	ally = p_ally


func answers() -> Script:
	return InitiativeSwapWindow


func _validate(state: CombatState) -> StringName:
	if not (state.pending as InitiativeSwapWindow).allies.has(ally):
		return NO_TARGET
	return &""


func _execute(state: CombatState, _dice: Dice) -> Array[CombatEvent]:
	state.pending = null
	# Chaque ligne d'initiative garde son total : on échange les combattants.
	var mine: InitiativeEntry = null
	var theirs: InitiativeEntry = null
	for entry in state.initiative:
		if entry.combatant == actor:
			mine = entry
		elif entry.combatant == ally:
			theirs = entry
	mine.combatant = ally
	theirs.combatant = actor
	mine.swapped = true
	theirs.swapped = true
	var events: Array[CombatEvent] = [
		InitiativeSwappedEvent.new(actor, ally),
		InitiativeRolledEvent.new(state.initiative),
	]
	events.append_array(state.begin_first_turn())
	return events

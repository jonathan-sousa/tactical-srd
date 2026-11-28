## Action Chercher (SRD « Search ») : test de Sagesse (Perception) pour
## trouver une créature cachée. Chaque ennemi caché dont le jet de
## Discrétion est atteint est trouvé : il n'est plus caché ni invisible.
class_name SearchAction
extends Action

const ID := &"search"


func _validate(state: CombatState) -> StringName:
	if state.action_used:
		return ACTION_ALREADY_USED
	if state.hidden_enemies_of(actor).is_empty():
		return NOTHING_TO_SEARCH
	return &""


func _execute(state: CombatState, dice: Dice) -> Array[CombatEvent]:
	state.action_used = true
	var roll := dice.roll_d20(Dice.RollMode.NORMAL, actor.is_lucky())
	var event := SearchedEvent.new(actor, roll.natural, actor.definition.skill_bonus(CharacterDef.PERCEPTION))
	event.lucky = roll.luck_rerolls > 0
	var events: Array[CombatEvent] = [event]
	for enemy in state.hidden_enemies_of(actor):
		var dc := state.hide_dc(enemy)
		if event.total >= dc:
			event.found.append(enemy)
			event.found_dcs.append(dc)
			events.append_array(state.reveal(enemy, RevealedEvent.FOUND))
	return events

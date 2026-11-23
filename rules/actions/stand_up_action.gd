## Se relever (condition Prone) : coûte la moitié de sa vitesse en
## déplacement, arrondie à l'inférieur. Impossible avec une vitesse de 0.
class_name StandUpAction
extends Action

const ID := &"stand_up"


## Déplacement nécessaire pour se relever, en cases.
@warning_ignore("integer_division")
static func cost(state: CombatState, combatant: Combatant) -> int:
	return state.speed_in_squares(combatant) / 2


func _validate(state: CombatState) -> StringName:
	if not state.has_effect(actor, Effect.PRONE):
		return NOT_PRONE
	var squares := cost(state, actor)
	if state.speed_in_squares(actor) == 0 or state.movement_left < squares:
		return NOT_ENOUGH_MOVEMENT
	return &""


func _execute(state: CombatState, _dice: Dice) -> Array[CombatEvent]:
	state.movement_left -= cost(state, actor)
	state.remove_effect(actor, Effect.PRONE)
	return [EffectEndedEvent.new(actor, Effect.PRONE)]

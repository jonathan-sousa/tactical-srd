## Second Wind (Guerrier niveau 1) : action bonus, regagne 1d10 + niveau de
## Guerrier en PV. Deux utilisations au niveau 1.
class_name SecondWindAction
extends Action

const HEALING_DIE := "1d10"


func _validate(state: CombatState) -> StringName:
	if actor.definition.second_wind_uses <= 0:
		return FEATURE_UNAVAILABLE
	if actor.second_wind_uses <= 0:
		return NO_USES_LEFT
	if state.bonus_action_used:
		return BONUS_ACTION_ALREADY_USED
	return &""


func _execute(state: CombatState, dice: Dice) -> Array[CombatEvent]:
	state.bonus_action_used = true
	actor.second_wind_uses -= 1
	var expression := DiceExpression.parse(HEALING_DIE).with_modifier(actor.definition.level)
	var roll := dice.roll(expression)
	var healed := actor.heal(roll.total)
	return [HealedEvent.new(actor, healed, roll, actor.hp)]

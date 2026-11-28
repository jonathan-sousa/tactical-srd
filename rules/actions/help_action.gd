## Action Aider (SRD « Help »), sur une créature au contact (5 ft) :
## - un ennemi qu'on voit : on le distrait (« Assist an Attack Roll »). La
##   prochaine attaque d'un de nos alliés contre lui a l'avantage, jusqu'au
##   début de notre prochain tour ;
## - un allié mourant : on tente de le stabiliser (« Stabilizing a
##   Character »), test de Sagesse (Médecine) DD 10. Le SRD ne dit pas à
##   quelle distance : premiers soins, donc au contact (écart consigné).
##
## L'aide à un test de caractéristique (« Assist an Ability Check ») n'a pas
## d'usage dans le jeu.
class_name HelpAction
extends Action

const ID := &"help"
## DD du test de Médecine pour stabiliser.
const STABILIZE_DC := 10

## Ennemi à distraire ou allié à stabiliser.
var target: Combatant


func _init(p_actor: Combatant, p_target: Combatant) -> void:
	super(p_actor)
	target = p_target


func _validate(state: CombatState) -> StringName:
	if state.action_used:
		return ACTION_ALREADY_USED
	if target == null or target == actor or target.is_dead:
		return NO_TARGET
	if GridPathfinder.chebyshev(actor.position, target.position) > 1:
		return TARGET_OUT_OF_REACH
	if target.side == actor.side:
		return &"" if target.is_dying() else NOT_DYING
	if state.is_hidden_from(target, actor):
		return NO_TARGET
	return &""


func _execute(state: CombatState, dice: Dice) -> Array[CombatEvent]:
	state.action_used = true
	if target.side == actor.side:
		return _stabilize(state, dice)
	state.add_effect(Effect.new(Effect.HELPED, target, actor, Effect.Expiry.START_OF_SOURCE_TURN))
	return [ActionTakenEvent.new(actor, ID, false), EffectAppliedEvent.new(target, Effect.HELPED)]


func _stabilize(state: CombatState, dice: Dice) -> Array[CombatEvent]:
	var roll := dice.roll_d20(Dice.RollMode.NORMAL, actor.is_lucky())
	var bonus := actor.definition.skill_bonus(CharacterDef.MEDICINE)
	var success := roll.natural + bonus >= STABILIZE_DC
	var event := StabilizeAttemptedEvent.new(actor, target, roll.natural, bonus, success)
	event.lucky = roll.luck_rerolls > 0
	var events: Array[CombatEvent] = [event]
	if success:
		target.is_stable = true
		target.reset_death_saves()
		events.append_array(state.check_end())
	return events

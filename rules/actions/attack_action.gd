## Action Attaque : une attaque au corps à corps avec l'arme de l'attaquant.
class_name AttackAction
extends Action

var target: Combatant
var weapon: WeaponDef


## Sans arme précisée, on prend la première de la fiche.
func _init(p_actor: Combatant, p_target: Combatant, p_weapon: WeaponDef = null) -> void:
	super(p_actor)
	target = p_target
	weapon = p_weapon
	if weapon == null and not p_actor.definition.weapons.is_empty():
		weapon = p_actor.definition.weapons[0]


func _validate(state: CombatState) -> StringName:
	if state.action_used:
		return ACTION_ALREADY_USED
	if weapon == null:
		return NO_WEAPON
	if target.side == actor.side:
		return TARGET_NOT_ENEMY
	if target.is_down():
		return TARGET_DOWN
	if not state.is_within_reach(actor, target, weapon):
		return TARGET_OUT_OF_REACH
	return &""


func _execute(state: CombatState, dice: Dice) -> Array[CombatEvent]:
	state.action_used = true
	var result := AttackResolver.resolve(actor, target, weapon, dice)
	var events: Array[CombatEvent] = [AttackRolledEvent.new(result)]
	if not result.is_hit:
		return events

	target.take_damage(result.damage)
	events.append(DamageDealtEvent.new(target, result.damage, result.damage_type, target.hp))
	if target.is_down():
		events.append(CombatantDownedEvent.new(target))
		events.append_array(state.check_end())
	return events

## Action Attaque : une attaque avec l'arme choisie, au corps à corps ou à
## distance selon l'arme et la distance (voir CombatState.attack_kind).
class_name AttackAction
extends Action

var target: Combatant
var weapon: WeaponDef


## Sans arme précisée, on prend l'arme de corps à corps du combattant.
func _init(p_actor: Combatant, p_target: Combatant, p_weapon: WeaponDef = null) -> void:
	super(p_actor)
	target = p_target
	weapon = p_weapon if p_weapon != null else p_actor.melee_weapon()


func _validate(state: CombatState) -> StringName:
	if state.action_used:
		return ACTION_ALREADY_USED
	if weapon == null or not actor.definition.weapons.has(weapon):
		return NO_WEAPON
	if actor.quantity(weapon) <= 0:
		return NO_AMMUNITION
	if target.side == actor.side:
		return TARGET_NOT_ENEMY
	if target.is_down():
		return TARGET_DOWN
	if state.attack_kind(actor, target, weapon) == CombatState.AttackKind.NONE:
		return TARGET_OUT_OF_RANGE if weapon.has_range() else TARGET_OUT_OF_REACH
	# Un obstacle entre les deux est un abri total : on ne peut pas viser.
	if not state.can_see(actor, target):
		return TARGET_NOT_VISIBLE
	return &""


func _execute(state: CombatState, dice: Dice) -> Array[CombatEvent]:
	state.action_used = true
	return AttackSequence.begin(state, actor, target, weapon, dice)

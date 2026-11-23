## Action Attaque : une attaque au corps à corps avec l'arme de l'attaquant.
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
	return AttackAction.strike(state, actor, target, weapon, dice)


## Une attaque complète : avantage ou désavantage, jet, dégâts, chute de la
## cible, fin du combat. Partagée avec l'attaque d'opportunité.
static func strike(
	state: CombatState,
	attacker: Combatant,
	target: Combatant,
	weapon: WeaponDef,
	dice: Dice,
	is_opportunity: bool = false,
) -> Array[CombatEvent]:
	var advantage := AdvantageResolver.for_attack(state, attacker, target, weapon)
	var result := AttackResolver.resolve(attacker, target, weapon, dice, advantage.mode)
	result.advantage = advantage
	result.is_opportunity = is_opportunity
	var events: Array[CombatEvent] = [AttackRolledEvent.new(result)]
	if not result.is_hit:
		return events

	target.take_damage(result.damage)
	events.append(DamageDealtEvent.new(target, result.damage, result.damage_type, target.hp))
	if target.is_down():
		events.append(CombatantDownedEvent.new(target))
		events.append_array(state.check_end())
	return events

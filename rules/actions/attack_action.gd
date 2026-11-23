## Action Attaque : une attaque avec l'arme choisie, au corps à corps ou à
## distance selon l'arme et la distance (voir CombatState.attack_kind).
##
## On vise une case. D'habitude, c'est celle d'un ennemi qu'on voit. Contre
## un ennemi caché, on vise à l'aveugle la case où on le croit (SRD « Unseen
## Attackers and Targets ») : désavantage s'il y est, échec s'il n'y est pas.
class_name AttackAction
extends Action

## Case visée.
var cell: Vector2i
## Cible désignée (un ennemi qu'on voit), ou `null` pour une case visée à
## l'aveugle : la cible est alors celui qui s'y trouve vraiment, s'il y en a.
var target: Combatant
var weapon: WeaponDef


## Sans arme précisée, on prend l'arme de corps à corps du combattant.
func _init(p_actor: Combatant, p_target: Combatant, p_weapon: WeaponDef = null) -> void:
	super(p_actor)
	target = p_target
	if p_target != null:
		cell = p_target.position
	weapon = p_weapon if p_weapon != null else p_actor.melee_weapon()


## Attaque à l'aveugle d'une case, quand un ennemi est caché.
static func at_cell(p_actor: Combatant, p_cell: Vector2i, p_weapon: WeaponDef = null) -> AttackAction:
	var action := AttackAction.new(p_actor, null, p_weapon)
	action.cell = p_cell
	return action


func is_blind() -> bool:
	return target == null


func _validate(state: CombatState) -> StringName:
	if state.action_used:
		return ACTION_ALREADY_USED
	if weapon == null or not actor.definition.weapons.has(weapon):
		return NO_WEAPON
	if actor.quantity(weapon) <= 0:
		return NO_AMMUNITION
	if is_blind():
		# Viser une case n'a de sens que si un ennemi se cache quelque part.
		if state.hidden_enemies_of(actor).is_empty():
			return NO_TARGET
		var occupant := state.combatant_at(cell)
		if occupant != null and not state.is_hidden_from(occupant, actor):
			return NO_TARGET
	else:
		if target.side == actor.side:
			return TARGET_NOT_ENEMY
		if target.is_dead:
			return TARGET_DEAD
		if state.is_hidden_from(target, actor):
			return NO_TARGET
	if state.attack_kind_at(actor, cell, weapon) == CombatState.AttackKind.NONE:
		return TARGET_OUT_OF_RANGE if weapon.has_range() else TARGET_OUT_OF_REACH
	# Un obstacle entre les deux est un abri total : on ne peut pas viser.
	if not state.has_line_of_sight_to(actor, cell):
		return TARGET_NOT_VISIBLE
	return &""


func _execute(state: CombatState, dice: Dice) -> Array[CombatEvent]:
	state.action_used = true
	var victim := target if target != null else state.combatant_at(cell)
	if victim == null:
		return AttackSequence.strike_empty_cell(state, actor, cell, weapon)
	return AttackSequence.begin(state, actor, victim, weapon, dice)

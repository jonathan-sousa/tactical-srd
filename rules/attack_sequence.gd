## Déroulé complet d'une attaque, partagé par l'action Attaque et l'attaque
## d'opportunité :
##
## 1. `begin` : munition dépensée, avantage ou désavantage, jet d'attaque.
##    Si le jet rate et que l'attaquant a l'Inspiration héroïque, l'attaque
##    s'arrête sur une décision (InspirationWindow).
## 2. `finish` : dégâts (Great Weapon Fighting, Savage Attacker), maîtrises
##    (Graze sur un échec, Sap et Slow sur une touche), chute de la cible.
class_name AttackSequence
extends RefCounted


## `resume` : déplacement à reprendre après une attaque d'opportunité.
static func begin(
	state: CombatState,
	attacker: Combatant,
	target: Combatant,
	weapon: WeaponDef,
	dice: Dice,
	is_opportunity: bool = false,
	resume: ReactionWindow = null,
) -> Array[CombatEvent]:
	var kind := state.attack_kind(attacker, target, weapon)
	# Un javelot lancé quitte la main : un exemplaire de moins.
	if kind == CombatState.AttackKind.RANGED and attacker.quantities.has(weapon.id):
		attacker.quantities[weapon.id] -= 1

	var advantage := AdvantageResolver.for_attack(state, attacker, target, weapon)
	var result := AttackResolver.roll_attack(attacker, target, weapon, dice, advantage.mode)
	result.advantage = advantage
	result.is_opportunity = is_opportunity
	result.is_ranged = kind == CombatState.AttackKind.RANGED
	var events: Array[CombatEvent] = [AttackRolledEvent.new(result)]

	# Sap : le désavantage ne vaut que pour une attaque.
	if state.remove_effect(attacker, Effect.SAPPED):
		events.append(EffectEndedEvent.new(attacker, Effect.SAPPED))

	if not result.is_hit and attacker.heroic_inspiration:
		state.pending = InspirationWindow.new(result, resume)
		return events
	events.append_array(finish(state, result, dice))
	events.append_array(state.resume_movement(resume))
	return events


## Fin de l'attaque, une fois le jet d'attaque définitif.
static func finish(state: CombatState, result: AttackResult, dice: Dice) -> Array[CombatEvent]:
	var attacker := result.attacker
	var target := result.target
	var weapon := result.weapon
	var mastery := weapon.mastery if attacker.definition.masters(weapon) else &""
	var events: Array[CombatEvent] = []

	if not result.is_hit:
		# Graze : le modificateur de caractéristique, même en cas d'échec.
		var graze := attacker.damage_modifier(weapon)
		if mastery == WeaponDef.GRAZE and graze > 0:
			result.graze_damage = graze
			events.append_array(_deal_damage(state, target, graze, result.damage_type, true))
		return events

	var great_weapon_fighting := attacker.definition.fighting_style == CharacterDef.GREAT_WEAPON_FIGHTING \
		and not result.is_ranged \
		and (weapon.has_property(WeaponDef.TWO_HANDED) or weapon.has_property(WeaponDef.VERSATILE))
	var savage_attacker := attacker.definition.has_feat(CharacterDef.SAVAGE_ATTACKER) \
		and attacker.savage_attacker_turn != state.turn_count
	if savage_attacker:
		attacker.savage_attacker_turn = state.turn_count
	AttackResolver.roll_damage(result, dice, great_weapon_fighting, savage_attacker)
	events.append_array(_deal_damage(state, target, result.damage, result.damage_type, false))
	if target.is_down():
		return events

	match mastery:
		WeaponDef.SAP:
			events.append_array(state.apply_effect(Effect.new(Effect.SAPPED, target, attacker, Effect.Expiry.START_OF_SOURCE_TURN)))
		WeaponDef.SLOW:
			if result.damage > 0:
				events.append_array(state.apply_effect(Effect.new(Effect.SLOWED, target, attacker, Effect.Expiry.START_OF_SOURCE_TURN)))
	return events


static func _deal_damage(state: CombatState, target: Combatant, amount: int, type: DamageType.Type, is_graze: bool) -> Array[CombatEvent]:
	target.take_damage(amount)
	var events: Array[CombatEvent] = [DamageDealtEvent.new(target, amount, type, target.hp, is_graze)]
	if target.is_down():
		events.append(CombatantDownedEvent.new(target))
		events.append_array(state.check_end())
	return events

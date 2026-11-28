## Déroulé complet d'une attaque, partagé par l'action Attaque et l'attaque
## d'opportunité :
##
## 1. `begin` : munition dépensée, avantage ou désavantage, jet d'attaque.
##    Un attaquant caché est révélé par son jet. Si le jet rate et que
##    l'attaquant a l'Inspiration héroïque, l'attaque s'arrête sur une
##    décision (InspirationWindow).
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
	off_hand: bool = false,
) -> Array[CombatEvent]:
	var kind := state.attack_kind(attacker, target, weapon)
	_spend_thrown_weapon(attacker, weapon, kind)

	var advantage := AdvantageResolver.for_attack(state, attacker, target, weapon)
	var result := AttackResolver.roll_attack(attacker, target, weapon, dice, advantage.mode, critical_on_hit(state, attacker, target), state.cover_bonus(attacker, target))
	result.advantage = advantage
	result.is_opportunity = is_opportunity
	result.is_ranged = kind == CombatState.AttackKind.RANGED
	result.off_hand = off_hand

	# Un attaquant caché trahit sa position par son jet, qu'il touche ou
	# non (SRD « Unseen Attackers and Targets ») : on l'annonce d'abord.
	var events := state.reveal(attacker, RevealedEvent.ATTACKED)
	events.append(AttackRolledEvent.new(result))

	# Sap : le désavantage ne vaut que pour une attaque. Vex : l'avantage non
	# plus, et seulement pour celui qui a touché.
	if state.remove_effect(attacker, Effect.SAPPED):
		events.append(EffectEndedEvent.new(attacker, Effect.SAPPED))
	if state.remove_effect_from(target, Effect.VEXED, attacker):
		events.append(EffectEndedEvent.new(target, Effect.VEXED))
	# Aider : la distraction ne sert qu'à une attaque.
	if advantage.advantages.has(AdvantageResolver.TARGET_DISTRACTED) and state.remove_effect(target, Effect.HELPED):
		events.append(EffectEndedEvent.new(target, Effect.HELPED))

	if not result.is_hit and attacker.heroic_inspiration:
		state.pending = InspirationWindow.for_attack(result, resume)
		return events
	events.append_array(finish(state, result, dice))
	events.append_array(state.resume_movement(resume))
	return events


## Attaque à l'aveugle sur une case vide : elle rate sans jet (« If the
## target isn't in the location you targeted, you miss »). Le javelot lancé
## est quand même perdu.
static func strike_empty_cell(state: CombatState, attacker: Combatant, cell: Vector2i, weapon: WeaponDef) -> Array[CombatEvent]:
	_spend_thrown_weapon(attacker, weapon, state.attack_kind_at(attacker, cell, weapon))
	return [AttackedEmptyCellEvent.new(attacker, cell, weapon)]


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
			events.append_array(HitPoints.apply_damage(state, target, graze, result.damage_type, true))
		return events

	var great_weapon_fighting := uses_great_weapon_fighting(attacker, weapon, result.is_ranged)
	var savage_attacker := attacker.definition.has_feat(CharacterDef.SAVAGE_ATTACKER) \
		and attacker.savage_attacker_turn != state.turn_count
	if savage_attacker:
		attacker.savage_attacker_turn = state.turn_count
	AttackResolver.roll_damage(result, dice, great_weapon_fighting, savage_attacker)
	if sneak_attack_applies(state, attacker, target, weapon, result.d20.mode):
		attacker.sneak_attack_turn = state.turn_count
		AttackResolver.roll_sneak_attack(result, dice)
	events.append_array(HitPoints.apply_damage(state, target, result.damage, result.damage_type, false, result.is_critical))
	if target.is_down():
		return events

	match mastery:
		WeaponDef.SAP:
			events.append_array(state.apply_effect(Effect.new(Effect.SAPPED, target, attacker, Effect.Expiry.START_OF_SOURCE_TURN)))
		WeaponDef.SLOW:
			if result.damage > 0:
				events.append_array(state.apply_effect(Effect.new(Effect.SLOWED, target, attacker, Effect.Expiry.START_OF_SOURCE_TURN)))
		WeaponDef.VEX:
			if result.damage > 0:
				events.append_array(state.apply_effect(Effect.new(Effect.VEXED, target, attacker, Effect.Expiry.END_OF_SOURCE_NEXT_TURN)))
	return events


## Attaque sournoise (Roublard), une fois par tour : arme Finesse ou à
## distance, et l'avantage, ou bien un allié non neutralisé à 5 ft de la
## cible sans désavantage. `mode` : avantage ou désavantage du jet.
static func sneak_attack_applies(state: CombatState, attacker: Combatant, target: Combatant, weapon: WeaponDef, mode: Dice.RollMode) -> bool:
	if attacker.definition.sneak_attack_dice.is_empty() or attacker.sneak_attack_turn == state.turn_count:
		return false
	if not weapon.has_property(WeaponDef.FINESSE) and weapon.kind != WeaponDef.Kind.RANGED:
		return false
	if mode == Dice.RollMode.ADVANTAGE:
		return true
	if mode == Dice.RollMode.DISADVANTAGE:
		return false
	for ally in state.combatants:
		if ally != attacker and ally.side == attacker.side and not ally.is_down() \
				and GridPathfinder.chebyshev(ally.position, target.position) <= 1:
			return true
	return false


## Condition Unconscious : toute touche à 5 ft ou moins est un critique.
static func critical_on_hit(state: CombatState, attacker: Combatant, target: Combatant) -> bool:
	return target.is_down() and state.distance_feet(attacker, target) <= CombatState.FEET_PER_SQUARE


## Great Weapon Fighting : arme de corps à corps à deux mains (ou
## polyvalente), maniée au corps à corps.
static func uses_great_weapon_fighting(attacker: Combatant, weapon: WeaponDef, is_ranged: bool) -> bool:
	return attacker.definition.fighting_style == CharacterDef.GREAT_WEAPON_FIGHTING \
		and not is_ranged \
		and (weapon.has_property(WeaponDef.TWO_HANDED) or weapon.has_property(WeaponDef.VERSATILE))


# Un javelot lancé quitte la main : un exemplaire de moins.
static func _spend_thrown_weapon(attacker: Combatant, weapon: WeaponDef, kind: CombatState.AttackKind) -> void:
	if kind == CombatState.AttackKind.RANGED and attacker.quantities.has(weapon.id):
		attacker.quantities[weapon.id] -= 1

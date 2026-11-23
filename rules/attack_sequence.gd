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
) -> Array[CombatEvent]:
	var kind := state.attack_kind(attacker, target, weapon)
	_spend_thrown_weapon(attacker, weapon, kind)

	var advantage := AdvantageResolver.for_attack(state, attacker, target, weapon)
	# Condition Unconscious : toute touche à 5 ft ou moins est un critique.
	var critical_on_hit := target.is_down() and state.distance_feet(attacker, target) <= CombatState.FEET_PER_SQUARE
	var result := AttackResolver.roll_attack(attacker, target, weapon, dice, advantage.mode, critical_on_hit)
	result.advantage = advantage
	result.is_opportunity = is_opportunity
	result.is_ranged = kind == CombatState.AttackKind.RANGED

	# Un attaquant caché trahit sa position par son jet, qu'il touche ou
	# non (SRD « Unseen Attackers and Targets ») : on l'annonce d'abord.
	var events := state.reveal(attacker, RevealedEvent.ATTACKED)
	events.append(AttackRolledEvent.new(result))

	# Sap : le désavantage ne vaut que pour une attaque.
	if state.remove_effect(attacker, Effect.SAPPED):
		events.append(EffectEndedEvent.new(attacker, Effect.SAPPED))

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

	var great_weapon_fighting := attacker.definition.fighting_style == CharacterDef.GREAT_WEAPON_FIGHTING \
		and not result.is_ranged \
		and (weapon.has_property(WeaponDef.TWO_HANDED) or weapon.has_property(WeaponDef.VERSATILE))
	var savage_attacker := attacker.definition.has_feat(CharacterDef.SAVAGE_ATTACKER) \
		and attacker.savage_attacker_turn != state.turn_count
	if savage_attacker:
		attacker.savage_attacker_turn = state.turn_count
	AttackResolver.roll_damage(result, dice, great_weapon_fighting, savage_attacker)
	events.append_array(HitPoints.apply_damage(state, target, result.damage, result.damage_type, false, result.is_critical))
	if target.is_down():
		return events

	match mastery:
		WeaponDef.SAP:
			events.append_array(state.apply_effect(Effect.new(Effect.SAPPED, target, attacker, Effect.Expiry.START_OF_SOURCE_TURN)))
		WeaponDef.SLOW:
			if result.damage > 0:
				events.append_array(state.apply_effect(Effect.new(Effect.SLOWED, target, attacker, Effect.Expiry.START_OF_SOURCE_TURN)))
	return events


# Un javelot lancé quitte la main : un exemplaire de moins.
static func _spend_thrown_weapon(attacker: Combatant, weapon: WeaponDef, kind: CombatState.AttackKind) -> void:
	if kind == CombatState.AttackKind.RANGED and attacker.quantities.has(weapon.id):
		attacker.quantities[weapon.id] -= 1

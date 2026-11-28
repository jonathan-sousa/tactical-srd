## Dégâts, chute à 0 PV et jets contre la mort (SRD 5.2.1, « Damage and
## Healing »).
##
## - Un monstre meurt dès qu'il tombe à 0 PV.
## - Un personnage perd connaissance (Unconscious, donc à terre) et fait un
##   jet contre la mort au début de chacun de ses tours : 10 ou plus est une
##   réussite ; 1 compte pour deux échecs ; 20 lui rend 1 PV.
## - Trois réussites : il est stabilisé. Trois échecs : il meurt.
## - Des dégâts à 0 PV comptent pour un échec, deux sur un coup critique.
## - Dégâts massifs : il meurt sur le coup si le reste des dégâts (ou les
##   dégâts subis à 0 PV) atteint ses PV maximum.
class_name HitPoints
extends RefCounted

const DEATH_SAVE_DC := 10
## Réussites ou échecs nécessaires pour être stabilisé ou mourir.
const DEATH_SAVES_NEEDED := 3


## Inflige des dégâts et applique tout ce qui en découle.
static func apply_damage(
	state: CombatState,
	target: Combatant,
	amount: int,
	type: DamageType.Type,
	is_graze: bool = false,
	is_critical: bool = false,
) -> Array[CombatEvent]:
	var max_hp := target.definition.max_hp
	if target.is_down():
		var at_zero: Array[CombatEvent] = [DamageDealtEvent.new(target, amount, type, 0, is_graze)]
		if target.is_dead:
			return at_zero
		if amount >= max_hp:
			at_zero.append_array(_die(state, target, CombatantDiedEvent.MASSIVE_DAMAGE))
			return at_zero
		# Un combattant stabilisé qui subit des dégâts recommence ses jets.
		target.is_stable = false
		target.death_save_failures += 2 if is_critical else 1
		at_zero.append(DeathSaveEvent.new(target, 0, is_critical))
		at_zero.append_array(_check_death_saves(state, target))
		return at_zero

	var hp_before := target.hp
	target.take_damage(amount)
	var events: Array[CombatEvent] = [DamageDealtEvent.new(target, amount, type, target.hp, is_graze)]
	if target.hp > 0:
		return events

	if target.definition.is_monster:
		events.append_array(_die(state, target, CombatantDiedEvent.MONSTER_AT_ZERO))
	elif amount - hp_before >= max_hp:
		events.append_array(_die(state, target, CombatantDiedEvent.MASSIVE_DAMAGE))
	else:
		target.reset_death_saves()
		target.is_stable = false
		# Inconscient : à terre, et plus caché (il ne se cache plus de rien).
		state.add_effect(Effect.new(Effect.PRONE, target, target, Effect.Expiry.UNTIL_REMOVED))
		state.remove_effect(target, Effect.HIDDEN)
		events.append(CombatantDownedEvent.new(target))
		events.append_array(state.check_end())
	return events


## Jet contre la mort au début du tour d'un combattant mourant. Avec
## l'Inspiration héroïque, un échec ouvre une décision : relancer ou non.
static func roll_death_save(state: CombatState, combatant: Combatant, dice: Dice) -> Array[CombatEvent]:
	var roll := dice.roll_d20(Dice.RollMode.NORMAL, combatant.is_lucky())
	var natural := roll.natural
	if natural < DEATH_SAVE_DC and combatant.heroic_inspiration:
		state.pending = InspirationWindow.for_death_save(combatant, natural)
		return []
	var events := resolve_death_save(state, combatant, natural)
	if roll.luck_rerolls > 0:
		for event in events:
			if event is DeathSaveEvent:
				(event as DeathSaveEvent).lucky = true
	return events


## Applique le résultat définitif d'un jet contre la mort.
static func resolve_death_save(state: CombatState, combatant: Combatant, natural: int) -> Array[CombatEvent]:
	if natural == 20:
		combatant.heal(1)
		# Debout ou presque : il joue ce tour-ci, mais reste à terre.
		if combatant == state.active():
			state.movement_left = state.speed_in_squares(combatant)
		return [DeathSaveEvent.new(combatant, natural, false, true)]

	if natural >= DEATH_SAVE_DC:
		combatant.death_save_successes += 1
	else:
		combatant.death_save_failures += 2 if natural == 1 else 1
	var events: Array[CombatEvent] = [DeathSaveEvent.new(combatant, natural)]
	events.append_array(_check_death_saves(state, combatant))
	return events


static func _check_death_saves(state: CombatState, combatant: Combatant) -> Array[CombatEvent]:
	if combatant.death_save_failures >= DEATH_SAVES_NEEDED:
		return _die(state, combatant, CombatantDiedEvent.DEATH_SAVES)
	if combatant.death_save_successes >= DEATH_SAVES_NEEDED:
		combatant.is_stable = true
		combatant.reset_death_saves()
		var events: Array[CombatEvent] = [CombatantStabilizedEvent.new(combatant)]
		events.append_array(state.check_end())
		return events
	return []


static func _die(state: CombatState, combatant: Combatant, cause: StringName) -> Array[CombatEvent]:
	combatant.hp = 0
	combatant.is_dead = true
	combatant.is_stable = false
	# Les effets sur un mort, ou qui devaient finir à son tour, n'ont plus
	# d'objet.
	var kept: Array[Effect] = []
	for effect in state.effects:
		if effect.target != combatant and effect.source != combatant:
			kept.append(effect)
	state.effects = kept
	var events: Array[CombatEvent] = [CombatantDiedEvent.new(combatant, cause)]
	events.append_array(state.check_end())
	return events

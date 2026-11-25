## Invariants vérifiés après chaque action, sur des centaines de combats
## automatiques (une graine par combat). Ce que le moteur ne doit jamais
## faire, quels que soient les dés.
extends GdUnitTestSuite

const Scenarios := preload("res://tests/helpers/combat_scenarios.gd")
const SEED_COUNT := 300


func test_rules_hold_after_every_action() -> void:
	var registry := DataRegistry.load_from()
	var encounter := registry.encounter(&"goblin_ambush")
	var fighter := registry.character(&"fighter_lvl1")
	var problems: Array[String] = []
	for seed_value in range(1, SEED_COUNT + 1):
		var sim := CombatSimulator.new(CombatState.create(encounter, fighter), Dice.seeded(seed_value))
		sim.start()
		var tracker := _Tracker.new()
		while not sim.is_finished():
			var before := sim.actions.size()
			sim.step()
			for i in range(before, sim.actions.size()):
				tracker.record(sim.state, sim.actions[i])
			_check_state(sim.state, "graine %d, action %d" % [seed_value, sim.actions.size()], problems)
		problems.append_array(tracker.problems.map(func(text: String) -> String: return "graine %d : %s" % [seed_value, text]))
		if not sim.refused.is_empty():
			problems.append("graine %d : actions refusées %s" % [seed_value, sim.refused])
		if not sim.state.is_over:
			problems.append("graine %d : combat non terminé" % seed_value)
		if problems.size() > 20:
			break
	assert_array(problems).override_failure_message("\n".join(problems.slice(0, 20))).is_empty()


func _check_state(state: CombatState, where: String, problems: Array[String]) -> void:
	for combatant in state.combatants:
		var name := combatant.definition.display_name
		if combatant.hp < 0 or combatant.hp > combatant.definition.max_hp:
			problems.append("%s : %s a %d PV" % [where, name, combatant.hp])
		if combatant.is_dead and combatant.hp != 0:
			problems.append("%s : %s mort avec %d PV" % [where, name, combatant.hp])
		# Trois échecs : il est mort ; trois réussites : stabilisé (compteurs remis à zéro).
		if not combatant.is_dead and (combatant.death_save_successes > 2 or combatant.death_save_failures > 2):
			problems.append("%s : %s a %d réussites et %d échecs" % [where, name, combatant.death_save_successes, combatant.death_save_failures])
		if combatant.hp > 0 and (combatant.death_save_successes > 0 or combatant.death_save_failures > 0):
			problems.append("%s : %s debout avec des jets contre la mort en cours" % [where, name])
		for weapon_id: StringName in combatant.quantities:
			if combatant.quantities[weapon_id] < 0:
				problems.append("%s : %s a %d %s" % [where, name, combatant.quantities[weapon_id], weapon_id])
		if combatant.second_wind_uses < 0:
			problems.append("%s : %s, Second Wind négatif" % [where, name])
		if state.is_hidden(combatant) and state.hide_dc(combatant) < CombatState.HIDE_DC:
			problems.append("%s : %s caché avec un DD de %d" % [where, name, state.hide_dc(combatant)])
		if combatant.is_down() and state.is_hidden(combatant):
			problems.append("%s : %s à terre mais caché" % [where, name])
	if not state.is_over:
		if state.active().is_dead:
			problems.append("%s : c'est le tour d'un mort" % where)
		if state.movement_left < 0:
			problems.append("%s : déplacement restant négatif" % where)
	for effect in state.effects:
		if effect.target.is_dead:
			problems.append("%s : effet %s sur un mort" % [where, effect.id])


## Budget d'actions : une action et une action bonus par tour, une réaction
## entre deux tours du même combattant.
class _Tracker:
	extends RefCounted

	var problems: Array[String] = []
	var _turn := -1
	var _actions := 0
	var _bonus_actions := 0
	var _reactions: Dictionary[Combatant, int] = {}

	func record(state: CombatState, action: Action) -> void:
		if state.turn_count != _turn:
			_turn = state.turn_count
			_actions = 0
			_bonus_actions = 0
		if action is OpportunityAttackAction:
			var reactor := action.actor
			_reactions[reactor] = _reactions.get(reactor, 0) + 1
			if _reactions[reactor] > 1:
				problems.append("%s a réagi deux fois avant son tour" % reactor.definition.display_name)
		elif action is EndTurnAction:
			_reactions[state.active()] = 0
		elif action is SecondWindAction or (action is HideAction and (action as HideAction).bonus_action) \
				or (action is StandardAction and (action as StandardAction).bonus_action):
			_bonus_actions += 1
			if _bonus_actions > 1:
				problems.append("deux actions bonus au tour %d" % _turn)
		elif action is AttackAction or action is StandardAction or action is HideAction or action is SearchAction:
			_actions += 1
			if _actions > 1:
				problems.append("deux actions au tour %d" % _turn)

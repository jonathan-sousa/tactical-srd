## Comportements qu'un combat automatique doit pouvoir montrer, reconnus à
## partir des événements du moteur. Chaque scénario est une fonction qui
## reçoit le simulateur, une fois le combat terminé, et dit s'il s'est
## produit.
##
## L'attaque d'opportunité n'y figure pas : les deux IA évitent toujours d'en
## provoquer une (elles se désengagent d'abord). La règle est couverte par
## tests/rules/opportunity_attack_test.gd.
##
## Partagé par les combats de référence (tests/rules/reference_combats_test.gd)
## et l'outil qui cherche une graine pour chacun (scripts/find_seeds.gd).
extends RefCounted


static func all() -> Dictionary[StringName, Callable]:
	return {
		&"embuscade_tir_cache": _ambush_shot,
		&"desengagement_nimble_escape": _nimble_disengage,
		&"second_souffle": _second_wind,
		&"inspiration_heroique": _inspiration,
		&"graze": _graze,
		&"chercher_trouve": _search_finds,
		&"releve_sur_20": _revived,
		&"stabilise": _stabilized,
		&"guerrier_meurt": _fighter_dies,
		&"victoire": _victory,
	}


## Le Gobelin caché tire avec l'avantage et se révèle.
static func _ambush_shot(sim: CombatSimulator) -> bool:
	for event in sim.events:
		if event is AttackRolledEvent:
			var advantage := (event as AttackRolledEvent).result.advantage
			if advantage != null and advantage.advantages.has(AdvantageResolver.ATTACKER_HIDDEN):
				return true
	return false


static func _nimble_disengage(sim: CombatSimulator) -> bool:
	for event in sim.events:
		if event is ActionTakenEvent:
			var taken := event as ActionTakenEvent
			if taken.bonus_action and taken.action == StandardAction.DISENGAGE:
				return true
	return false


static func _second_wind(sim: CombatSimulator) -> bool:
	return _has(sim, HealedEvent)


static func _inspiration(sim: CombatSimulator) -> bool:
	return _has(sim, InspirationUsedEvent)


static func _graze(sim: CombatSimulator) -> bool:
	for event in sim.events:
		if event is DamageDealtEvent and (event as DamageDealtEvent).is_graze:
			return true
	return false


static func _search_finds(sim: CombatSimulator) -> bool:
	for event in sim.events:
		if event is SearchedEvent and not (event as SearchedEvent).found.is_empty():
			return true
	return false


static func _revived(sim: CombatSimulator) -> bool:
	for event in sim.events:
		if event is DeathSaveEvent and (event as DeathSaveEvent).revived:
			return true
	return false


static func _stabilized(sim: CombatSimulator) -> bool:
	return _has(sim, CombatantStabilizedEvent)


static func _fighter_dies(sim: CombatSimulator) -> bool:
	return sim.state.combatants[0].is_dead


static func _victory(sim: CombatSimulator) -> bool:
	return sim.state.is_over and sim.state.winner == Combatant.Side.PLAYER


static func _has(sim: CombatSimulator, script: Script) -> bool:
	for event in sim.events:
		if event.get_script() == script:
			return true
	return false


## Combat de l'histoire (vraies données), joué jusqu'au bout avec cette graine.
static func play(seed_value: int) -> CombatSimulator:
	var registry := DataRegistry.load_from()
	var state := CombatState.create(registry.encounter(&"goblin_ambush"), registry.character(&"fighter_lvl1"))
	var sim := CombatSimulator.new(state, Dice.seeded(seed_value))
	sim.start()
	sim.run_to_end()
	return sim

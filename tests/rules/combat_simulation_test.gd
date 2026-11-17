## Combats complets avec les vraies données, les deux camps joués par l'IA.
## Preuve que le moteur fait tourner un combat de bout en bout sans scène.
extends GdUnitTestSuite

const MAX_ROUNDS := 30


func test_full_combats_always_end(seed_value: int, test_parameters := [[1], [2], [3], [42], [99], [2024]]) -> void:
	var registry := DataRegistry.load_from()
	var state := CombatState.create(registry.encounter(&"goblin_ambush"), registry.character(&"fighter_lvl1"))
	var dice := Dice.seeded(seed_value)
	state.start(dice)

	while not state.is_over and state.round <= MAX_ROUNDS:
		for action in EnemyAI.plan_turn(state, state.active()):
			assert_str(action.validate(state)).is_empty()
			action.execute(state, dice)
			if state.is_over:
				break

	assert_bool(state.is_over).override_failure_message("Combat non terminé après %d rounds" % MAX_ROUNDS).is_true()
	var loser_side := Combatant.Side.ENEMY if state.winner == Combatant.Side.PLAYER else Combatant.Side.PLAYER
	for combatant in state.combatants:
		if combatant.side == loser_side:
			assert_bool(combatant.is_down()).is_true()


func test_same_seed_replays_the_same_combat() -> void:
	assert_array(_play(7)).is_equal(_play(7))


func _play(seed_value: int) -> Array[int]:
	var registry := DataRegistry.load_from()
	var state := CombatState.create(registry.encounter(&"goblin_ambush"), registry.character(&"fighter_lvl1"))
	var dice := Dice.seeded(seed_value)
	state.start(dice)
	var hp_trace: Array[int] = []
	while not state.is_over and state.round <= MAX_ROUNDS:
		for action in EnemyAI.plan_turn(state, state.active()):
			action.execute(state, dice)
			hp_trace.append(state.combatants[0].hp)
			hp_trace.append(state.combatants[1].hp)
			if state.is_over:
				break
	return hp_trace

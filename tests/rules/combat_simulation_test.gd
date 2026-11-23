## Combats complets avec les vraies données, les deux camps joués par l'IA.
## Preuve que le moteur fait tourner un combat de bout en bout sans scène,
## embuscade, cachettes et jets contre la mort compris.
extends GdUnitTestSuite

const MAX_ROUNDS := 30
## Garde-fou contre une IA qui ne finirait jamais son tour.
const MAX_ACTIONS := 2000


func test_full_combats_always_end(seed_value: int, test_parameters := [[1], [2], [3], [42], [99], [2024]]) -> void:
	var state := _new_combat()
	var dice := Dice.seeded(seed_value)
	state.start(dice)

	var steps := 0
	while not state.is_over and state.round <= MAX_ROUNDS and steps < MAX_ACTIONS:
		var action := EnemyAI.next_action(state, state.active())
		assert_str(action.validate(state)).is_empty()
		action.execute(state, dice)
		_resolve_decisions(state, dice)
		steps += 1

	assert_bool(state.is_over).override_failure_message("Combat non terminé après %d rounds" % MAX_ROUNDS).is_true()
	var loser_side := Combatant.Side.ENEMY if state.winner == Combatant.Side.PLAYER else Combatant.Side.PLAYER
	for combatant in state.combatants:
		if combatant.side == loser_side:
			assert_bool(combatant.is_dead or combatant.is_stable).is_true()


func test_same_seed_replays_the_same_combat() -> void:
	assert_array(_play(7)).is_equal(_play(7))


func _new_combat() -> CombatState:
	var registry := DataRegistry.load_from()
	return CombatState.create(registry.encounter(&"goblin_ambush"), registry.character(&"fighter_lvl1"))


func _play(seed_value: int) -> Array[int]:
	var state := _new_combat()
	var dice := Dice.seeded(seed_value)
	state.start(dice)
	var hp_trace: Array[int] = []
	while not state.is_over and state.round <= MAX_ROUNDS and hp_trace.size() < MAX_ACTIONS:
		EnemyAI.next_action(state, state.active()).execute(state, dice)
		_resolve_decisions(state, dice)
		hp_trace.append(state.combatants[0].hp)
		hp_trace.append(state.combatants[1].hp)
	return hp_trace


## Les deux camps sont joués par l'IA, réactions et relances comprises.
func _resolve_decisions(state: CombatState, dice: Dice) -> void:
	while state.pending != null:
		EnemyAI.decide(state).execute(state, dice)

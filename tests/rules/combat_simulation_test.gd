## Combats complets avec les vraies données, les deux camps joués par l'IA.
## Preuve que le moteur fait tourner un combat de bout en bout sans scène,
## embuscade, cachettes et jets contre la mort compris.
extends GdUnitTestSuite

const Scenarios := preload("res://tests/helpers/combat_scenarios.gd")


func test_full_combats_always_end(seed_value: int, test_parameters := [[1], [2], [3], [42], [99], [2024]]) -> void:
	var sim := Scenarios.play(seed_value)
	assert_array(sim.refused).is_empty()
	assert_bool(sim.state.is_over).override_failure_message("Combat non terminé (graine %d)" % seed_value).is_true()
	var loser_side := Combatant.Side.ENEMY if sim.state.winner == Combatant.Side.PLAYER else Combatant.Side.PLAYER
	for combatant in sim.state.combatants:
		if combatant.side == loser_side:
			assert_bool(combatant.is_dead or combatant.is_stable).is_true()


func test_different_seeds_give_different_combats() -> void:
	var rounds: Dictionary[int, bool] = {}
	for seed_value in range(1, 21):
		rounds[Scenarios.play(seed_value).events.size()] = true
	assert_int(rounds.size()).is_greater(1)

## Combats de référence : pour chaque comportement attendu, une graine dont
## le combat automatique (les deux camps joués par l'IA, vraies données) le
## montre. Même graine, même code : même combat.
##
## Si un changement voulu des règles ou de l'IA fait échouer ce test, relancer
## `godot --headless --path . -s scripts/find_seeds.gd` et recopier ici les
## graines trouvées. Si un comportement n'a plus aucune graine, c'est qu'il
## ne se produit plus : à examiner.
extends GdUnitTestSuite

const Scenarios := preload("res://tests/helpers/combat_scenarios.gd")

## Graines trouvées par scripts/find_seeds.gd.
const SEEDS: Dictionary[StringName, int] = {
	&"embuscade_tir_cache": 1,
	&"desengagement_nimble_escape": 876,
	&"second_souffle": 1,
	&"inspiration_heroique": 2,
	&"graze": 531,
	&"chercher_trouve": 1,
	&"releve_sur_20": 42,
	&"stabilise": 4,
	&"guerrier_meurt": 2,
	&"victoire": 1,
}


func test_every_scenario_has_a_reference_seed() -> void:
	for name: StringName in Scenarios.all():
		assert_bool(SEEDS.has(name)).override_failure_message("Scénario sans graine : %s" % name).is_true()


func test_each_reference_seed_shows_its_behaviour() -> void:
	var scenarios := Scenarios.all()
	for name: StringName in SEEDS:
		var sim := Scenarios.play(SEEDS[name])
		assert_array(sim.refused).override_failure_message("Graine %d : actions refusées %s" % [SEEDS[name], sim.refused]).is_empty()
		assert_bool(scenarios[name].call(sim)) \
			.override_failure_message("La graine %d ne montre plus « %s » : relancer scripts/find_seeds.gd." % [SEEDS[name], name]) \
			.is_true()


func test_same_seed_gives_the_same_events() -> void:
	var first := Scenarios.play(42)
	var second := Scenarios.play(42)
	assert_int(second.events.size()).is_equal(first.events.size())
	assert_int(second.actions.size()).is_equal(first.actions.size())
	for i in first.events.size():
		assert_str(second.events[i].get_script().get_global_name()).is_equal(first.events[i].get_script().get_global_name())
	assert_int(second.state.combatants[0].hp).is_equal(first.state.combatants[0].hp)
	assert_int(second.state.round).is_equal(first.state.round)

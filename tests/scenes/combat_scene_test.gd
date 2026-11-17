## Test de fumée : la scène de combat se charge, démarre et laisse la main
## au bon combattant, sans erreur.
extends GdUnitTestSuite


func test_combat_scene_starts() -> void:
	# Note gdUnit4 : scene_runner charge la scène et permet d'avancer image
	# par image ou de simuler la souris et le clavier.
	var runner := scene_runner("res://scenes/combat/combat.tscn")
	await runner.simulate_frames(20)
	var state: CombatState = runner.get_property("state")
	assert_object(state).is_not_null()
	assert_int(state.round).is_greater_equal(1)
	assert_object(state.active()).is_not_null()
	assert_int(state.combatants.size()).is_equal(2)

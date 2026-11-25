## Cherche, pour chaque comportement de tests/helpers/combat_scenarios.gd, la
## plus petite graine dont le combat automatique le montre.
##
##     godot --headless --path . -s scripts/find_seeds.gd -- --max=2000
##
## À relancer quand un changement voulu des règles ou de l'IA modifie les
## combats : on recopie alors les graines trouvées dans
## tests/rules/reference_combats_test.gd.
extends SceneTree

const Scenarios := preload("res://tests/helpers/combat_scenarios.gd")


func _initialize() -> void:
	var max_seed := 1000
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--max=") and arg.trim_prefix("--max=").is_valid_int():
			max_seed = arg.trim_prefix("--max=").to_int()

	var scenarios := Scenarios.all()
	var found: Dictionary[StringName, int] = {}
	for seed_value in range(1, max_seed + 1):
		if found.size() == scenarios.size():
			break
		var sim := Scenarios.play(seed_value)
		for name: StringName in scenarios:
			if not found.has(name) and scenarios[name].call(sim):
				found[name] = seed_value
	for name: StringName in scenarios:
		print("%s : %s" % [name, str(found[name]) if found.has(name) else "aucune graine jusqu'à %d" % max_seed])
	quit()

## Garde-fou d'architecture : le moteur de règles ne doit dépendre d'aucun
## Node, pour rester testable sans lancer le jeu ni charger de scène.
extends GdUnitTestSuite

const RULES_DIR := "res://rules"


func test_no_rules_script_extends_node() -> void:
	var scripts := _collect_scripts(RULES_DIR)
	assert_array(scripts).is_not_empty()
	for path in scripts:
		var script: Script = load(path)
		var base := script.get_instance_base_type()
		assert_bool(ClassDB.is_parent_class(base, &"Node")) \
			.override_failure_message("%s hérite de %s, donc de Node." % [path, base]) \
			.is_false()


func _collect_scripts(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	for sub_dir in DirAccess.get_directories_at(dir_path):
		found.append_array(_collect_scripts(dir_path.path_join(sub_dir)))
	return found

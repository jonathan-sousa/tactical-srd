extends GdUnitTestSuite

var _registry: DataRegistry


# Note gdUnit4 : before() s'exécute une seule fois avant toute la suite.
func before() -> void:
	_registry = DataRegistry.load_from()


func test_real_data_loads_without_errors() -> void:
	assert_array(_registry.errors()).is_empty()


func test_finds_each_definition_by_id() -> void:
	assert_str(_registry.character(&"fighter_lvl1").display_name).is_equal("Guerrier")
	assert_str(_registry.character(&"goblin_warrior").display_name).is_equal("Gobelin guerrier")
	assert_str(_registry.weapon(&"greatsword").display_name).is_equal("Épée à deux mains")
	assert_str(_registry.weapon(&"scimitar").display_name).is_equal("Cimeterre")
	assert_object(_registry.encounter(&"goblin_ambush")).is_not_null()
	assert_object(_registry.dialogue(&"intro")).is_not_null()
	assert_object(_registry.dialogue(&"victory")).is_not_null()
	assert_object(_registry.story).is_not_null()


func test_unknown_id_returns_null() -> void:
	assert_object(_registry.character(&"dragon")).is_null()
	assert_object(_registry.weapon(&"")).is_null()


func test_characters_reference_the_shared_weapon_files() -> void:
	# Les armes des fiches sont les mêmes objets que ceux du registre : modifier
	# greatsword.tres suffit à changer l'arme du Guerrier.
	assert_object(_registry.character(&"fighter_lvl1").weapons[0]).is_same(_registry.weapon(&"greatsword"))


func test_reports_badly_named_and_wrongly_typed_files() -> void:
	var bad := DataRegistry.load_from("res://tests/fixtures/bad_data")
	var errors := "\n".join(bad.errors())
	assert_str(errors).contains("wrong_id.tres : id « another_id » différent du nom de fichier « wrong_id »")
	assert_str(errors).contains("not_a_weapon.tres n'est pas un WeaponDef")
	assert_str(errors).contains("Histoire introuvable")
	assert_object(bad.character(&"another_id")).is_null()
	assert_object(bad.weapon(&"not_a_weapon")).is_null()

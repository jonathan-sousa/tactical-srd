## Cohérence des rencontres : un combat doit pouvoir commencer et se jouer.
extends GdUnitTestSuite

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const ENCOUNTER_IDS: Array[StringName] = [&"goblin_ambush", &"goblin_band"]

var _registry: DataRegistry


func before() -> void:
	_registry = DataRegistry.load_from()


## Les rencontres du jeu, avec leur grille (les questions de grille, dedans
## ou bloquée, sont celles du moteur).
func _encounters() -> Array[EncounterDef]:
	var found: Array[EncounterDef] = []
	for id in ENCOUNTER_IDS:
		var encounter := _registry.encounter(id)
		assert_object(encounter).override_failure_message("Rencontre introuvable : %s" % id).is_not_null()
		found.append(encounter)
	return found


## Grille du déplacement : obstacles et murets bloquent le passage.
func _grid(encounter: EncounterDef) -> GridPathfinder:
	return GridPathfinder.new(encounter.grid_size, encounter.blocked_cells + encounter.low_walls, encounter.difficult_cells)


func test_grids_fit_the_board() -> void:
	# Le plateau affiche 12 × 8 cases de 64 px.
	for encounter in _encounters():
		assert_that(encounter.grid_size).is_equal(Vector2i(12, 8))


func test_each_has_at_least_one_enemy_with_a_definition() -> void:
	for encounter in _encounters():
		assert_array(encounter.enemies).is_not_empty()
		for placement in encounter.enemies:
			assert_object(placement.character).is_not_null()


func test_blocked_cells_and_low_walls_are_inside_the_grid() -> void:
	for encounter in _encounters():
		for cell in encounter.blocked_cells + encounter.low_walls:
			assert_bool(_grid(encounter).is_inside(cell)).override_failure_message("%s : obstacle hors grille %s" % [encounter.id, cell]).is_true()


func test_difficult_terrain_is_inside_the_grid_and_on_free_cells() -> void:
	for encounter in _encounters():
		var grid := _grid(encounter)
		var starts: Array[Vector2i] = encounter.player_starts.duplicate()
		for placement in encounter.enemies:
			starts.append(placement.cell)
		for cell in encounter.difficult_cells:
			assert_bool(grid.is_inside(cell)).override_failure_message("%s : terrain difficile hors grille %s" % [encounter.id, cell]).is_true()
			assert_bool(grid.is_blocked(cell)).override_failure_message("%s : terrain difficile sur un obstacle %s" % [encounter.id, cell]).is_false()
			assert_bool(starts.has(cell)).override_failure_message("%s : départ en terrain difficile %s" % [encounter.id, cell]).is_false()


func test_each_has_at_least_one_player_start() -> void:
	for encounter in _encounters():
		assert_array(encounter.player_starts).is_not_empty()


func test_starting_cells_are_free_and_distinct() -> void:
	for encounter in _encounters():
		var grid := _grid(encounter)
		var starts: Array[Vector2i] = encounter.player_starts.duplicate()
		for placement in encounter.enemies:
			starts.append(placement.cell)
		for cell in starts:
			assert_bool(grid.is_inside(cell)).override_failure_message("%s : départ hors grille %s" % [encounter.id, cell]).is_true()
			assert_bool(grid.is_blocked(cell)).override_failure_message("%s : départ sur un obstacle %s" % [encounter.id, cell]).is_false()
			assert_int(starts.count(cell)).override_failure_message("%s : deux combattants sur %s" % [encounter.id, cell]).is_equal(1)


func test_every_character_can_reach_every_enemy() -> void:
	# Parcours en largeur sur 4 directions : plus strict que le déplacement du
	# jeu (8 directions), donc un chemin trouvé ici existe aussi en jeu.
	for encounter in _encounters():
		for start in encounter.player_starts:
			var reachable := _reachable_from(_grid(encounter), start)
			for placement in encounter.enemies:
				assert_bool(reachable.has(placement.cell)) \
					.override_failure_message("%s : ennemi inaccessible en %s depuis %s" % [encounter.id, placement.cell, start]) \
					.is_true()


func _reachable_from(grid: GridPathfinder, start: Vector2i) -> Dictionary[Vector2i, bool]:
	var seen: Dictionary[Vector2i, bool] = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for direction in DIRECTIONS:
			var next := cell + direction
			if grid.is_inside(next) and not grid.is_blocked(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen


func test_goblin_ambush_starts_hidden_behind_the_rock() -> void:
	# Embuscade : au départ, le rocher cache le Gobelin du Guerrier, il peut
	# donc tenter de se cacher (Surprise).
	var encounter := _registry.encounter(&"goblin_ambush")
	assert_bool(encounter.ambush).is_true()
	var line_of_sight := LineOfSight.new(encounter.blocked_cells)
	assert_bool(line_of_sight.is_clear(encounter.player_starts[0], encounter.enemies[0].cell)).is_false()


func test_goblin_band_is_a_warrior_and_two_minions_against_two_characters() -> void:
	var encounter := _registry.encounter(&"goblin_band")
	assert_int(encounter.player_starts.size()).is_equal(2)
	var ids: Array[StringName] = []
	for placement in encounter.enemies:
		ids.append(placement.character.id)
	assert_array(ids).contains_exactly_in_any_order([&"goblin_minion", &"goblin_minion", &"goblin_warrior"])


func test_goblin_ambush_has_a_start_for_each_character() -> void:
	assert_int(_registry.encounter(&"goblin_ambush").player_starts.size()).is_equal(2)


func test_low_walls_are_not_also_obstacles() -> void:
	for encounter in _encounters():
		for cell in encounter.low_walls:
			assert_bool(encounter.blocked_cells.has(cell)).override_failure_message("%s : %s est obstacle et muret" % [encounter.id, cell]).is_false()


func test_goblin_band_archers_start_behind_low_walls() -> void:
	# Abri partiel des gobelins guerriers contre les tirs venus des cases de
	# départ du groupe.
	var registry := DataRegistry.load_from()
	var fighter := registry.character(&"fighter_lvl1")
	var party: Array[CharacterDef] = [fighter, fighter]
	var state := CombatState.create_party(registry.encounter(&"goblin_band"), party)
	for archer in state.combatants:
		if archer.definition.id != &"goblin_warrior":
			continue
		for member in state.party():
			assert_int(state.cover_bonus(member, archer)).override_failure_message("%s sans abri contre %s" % [archer.display_name, member.display_name]).is_equal(CombatState.HALF_COVER_BONUS)

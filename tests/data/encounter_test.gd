## Cohérence de la rencontre : un combat doit pouvoir commencer et se jouer.
extends GdUnitTestSuite

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var _encounter: EncounterDef
## Les questions de grille (dedans, bloquée) sont celles du moteur.
var _grid: GridPathfinder


func before() -> void:
	_encounter = DataRegistry.load_from().encounter(&"goblin_ambush")
	_grid = GridPathfinder.new(_encounter.grid_size, _encounter.blocked_cells)


func test_grid_is_about_12_by_8() -> void:
	assert_that(_encounter.grid_size).is_equal(Vector2i(12, 8))


func test_has_at_least_one_enemy_with_a_definition() -> void:
	assert_array(_encounter.enemies).is_not_empty()
	for placement in _encounter.enemies:
		assert_object(placement.character).is_not_null()


func test_blocked_cells_are_inside_the_grid() -> void:
	for cell in _encounter.blocked_cells:
		assert_bool(_grid.is_inside(cell)).override_failure_message("Obstacle hors grille : %s" % cell).is_true()


func test_starting_cells_are_free_and_distinct() -> void:
	var starts: Array[Vector2i] = [_encounter.player_start]
	for placement in _encounter.enemies:
		starts.append(placement.cell)

	for cell in starts:
		assert_bool(_grid.is_inside(cell)).override_failure_message("Départ hors grille : %s" % cell).is_true()
		assert_bool(_grid.is_blocked(cell)).override_failure_message("Départ sur un obstacle : %s" % cell).is_false()
		assert_int(starts.count(cell)).override_failure_message("Deux combattants sur %s" % cell).is_equal(1)


func test_player_can_reach_every_enemy() -> void:
	# Parcours en largeur sur 4 directions : plus strict que le déplacement du
	# jeu (8 directions), donc un chemin trouvé ici existe aussi en jeu.
	var reachable := _reachable_from(_encounter.player_start)
	for placement in _encounter.enemies:
		assert_bool(reachable.has(placement.cell)) \
			.override_failure_message("Gobelin inaccessible en %s" % placement.cell) \
			.is_true()


func _reachable_from(start: Vector2i) -> Dictionary[Vector2i, bool]:
	var seen: Dictionary[Vector2i, bool] = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for direction in DIRECTIONS:
			var next := cell + direction
			if _grid.is_inside(next) and not _grid.is_blocked(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen


func test_goblin_ambush_starts_hidden_behind_the_rock() -> void:
	# Embuscade : au départ, le rocher cache le Gobelin du Guerrier, il peut
	# donc tenter de se cacher (Surprise).
	var encounter := DataRegistry.load_from().encounter(&"goblin_ambush")
	assert_bool(encounter.ambush).is_true()
	var line_of_sight := LineOfSight.new(encounter.blocked_cells)
	assert_bool(line_of_sight.is_clear(encounter.player_start, encounter.enemies[0].cell)).is_false()

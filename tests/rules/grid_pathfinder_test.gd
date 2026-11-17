extends GdUnitTestSuite

const NO_OCCUPIED: Array[Vector2i] = []


func _pathfinder(size: Vector2i, blocked: Array[Vector2i] = []) -> GridPathfinder:
	return GridPathfinder.new(size, blocked)


func test_straight_path_excludes_start() -> void:
	var path := _pathfinder(Vector2i(8, 8)).find_path(Vector2i(0, 0), Vector2i(3, 0), NO_OCCUPIED)
	assert_array(path).contains_exactly(Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0))


func test_diagonal_costs_one_square() -> void:
	var path := _pathfinder(Vector2i(8, 8)).find_path(Vector2i(0, 0), Vector2i(3, 3), NO_OCCUPIED)
	assert_array(path).contains_exactly(Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3))


func test_path_goes_around_obstacle() -> void:
	# Mur vertical en x = 2, de y = 0 à y = 2 : il faut passer par y = 3.
	var wall: Array[Vector2i] = [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]
	var path := _pathfinder(Vector2i(5, 5), wall).find_path(Vector2i(0, 1), Vector2i(4, 1), NO_OCCUPIED)
	assert_array(path).is_not_empty()
	assert_that(path.back()).is_equal(Vector2i(4, 1))
	for cell in wall:
		assert_bool(path.has(cell)).is_false()
	assert_bool(path.has(Vector2i(2, 3))).is_true()


func test_no_corner_cutting_past_an_obstacle() -> void:
	# Obstacle en (1, 0) : la diagonale (0, 0) -> (1, 1) le frôlerait.
	var path := _pathfinder(Vector2i(4, 4), [Vector2i(1, 0)]).find_path(Vector2i(0, 0), Vector2i(1, 1), NO_OCCUPIED)
	assert_array(path).contains_exactly(Vector2i(0, 1), Vector2i(1, 1))


func test_occupied_cell_is_avoided() -> void:
	var occupied: Array[Vector2i] = [Vector2i(1, 0)]
	var path := _pathfinder(Vector2i(3, 1)).find_path(Vector2i(0, 0), Vector2i(2, 0), occupied)
	# Couloir d'une case de haut, bouché par un combattant : aucun chemin.
	assert_array(path).is_empty()


func test_occupied_cell_cannot_be_a_destination() -> void:
	var occupied: Array[Vector2i] = [Vector2i(2, 0)]
	assert_array(_pathfinder(Vector2i(5, 5)).find_path(Vector2i(0, 0), Vector2i(2, 0), occupied)).is_empty()


func test_blocked_or_outside_destination_has_no_path() -> void:
	var pathfinder := _pathfinder(Vector2i(5, 5), [Vector2i(3, 3)])
	assert_array(pathfinder.find_path(Vector2i(0, 0), Vector2i(3, 3), NO_OCCUPIED)).is_empty()
	assert_array(pathfinder.find_path(Vector2i(0, 0), Vector2i(9, 9), NO_OCCUPIED)).is_empty()


func test_reachable_cells_are_limited_to_six_squares() -> void:
	var reachable := _pathfinder(Vector2i(12, 8)).reachable_cells(Vector2i(0, 0), 6, NO_OCCUPIED)
	assert_bool(reachable.has(Vector2i(6, 0))).is_true()
	assert_bool(reachable.has(Vector2i(6, 6))).is_true()
	assert_bool(reachable.has(Vector2i(7, 0))).is_false()
	assert_bool(reachable.has(Vector2i(0, 0))).is_false()
	assert_int(reachable[Vector2i(6, 6)]).is_equal(6)


func test_reachable_cells_respect_obstacles_and_occupants() -> void:
	var occupied: Array[Vector2i] = [Vector2i(0, 1)]
	var reachable := _pathfinder(Vector2i(8, 8), [Vector2i(1, 0)]).reachable_cells(Vector2i(0, 0), 6, occupied)
	assert_bool(reachable.has(Vector2i(1, 0))).is_false()
	assert_bool(reachable.has(Vector2i(0, 1))).is_false()
	# (1, 1) n'est atteignable qu'en diagonale, interdite ici (coin bloqué
	# par l'obstacle et par le combattant) : enfermé dans le coin.
	assert_bool(reachable.is_empty()).is_true()

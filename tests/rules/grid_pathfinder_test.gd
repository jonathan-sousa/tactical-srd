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
	# (1, 1) n'est atteignable qu'en diagonale, interdite ici : elle passerait
	# le coin de l'obstacle. Enfermé dans le coin.
	assert_bool(reachable.is_empty()).is_true()


# --- Coins (SRD « Corners ») ----------------------------------------------


func test_a_creature_does_not_block_a_diagonal() -> void:
	# Seul le décor qui remplit sa case interdit de couper le coin ; un
	# combattant en (1, 0) ne gêne pas la diagonale (0, 0) -> (1, 1).
	var occupied: Array[Vector2i] = [Vector2i(1, 0)]
	var path := _pathfinder(Vector2i(4, 4)).find_path(Vector2i(0, 0), Vector2i(1, 1), occupied)
	assert_array(path).contains_exactly(Vector2i(1, 1))


# --- Terrain difficile (SRD « Difficult Terrain ») -------------------------


func _difficult(size: Vector2i, difficult: Array[Vector2i], blocked: Array[Vector2i] = []) -> GridPathfinder:
	return GridPathfinder.new(size, blocked, difficult)


func test_entering_difficult_terrain_costs_two_squares() -> void:
	var difficult: Array[Vector2i] = [Vector2i(1, 0)]
	var pathfinder := _difficult(Vector2i(3, 1), difficult)
	var path := pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 0), NO_OCCUPIED)
	assert_array(path).contains_exactly(Vector2i(1, 0), Vector2i(2, 0))
	assert_int(pathfinder.path_cost(path)).is_equal(3)
	assert_bool(pathfinder.is_difficult(Vector2i(1, 0))).is_true()
	assert_bool(pathfinder.is_difficult(Vector2i(2, 0))).is_false()


func test_a_diagonal_into_difficult_terrain_costs_two_squares() -> void:
	var difficult: Array[Vector2i] = [Vector2i(1, 1)]
	var pathfinder := _difficult(Vector2i(2, 2), difficult)
	var path := pathfinder.find_path(Vector2i(0, 0), Vector2i(1, 1), NO_OCCUPIED)
	assert_int(pathfinder.path_cost(path)).is_equal(2)


func test_leaving_difficult_terrain_costs_one_square() -> void:
	# On paie la case où l'on entre, pas celle qu'on quitte.
	var difficult: Array[Vector2i] = [Vector2i(0, 0)]
	var pathfinder := _difficult(Vector2i(3, 1), difficult)
	var path := pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 0), NO_OCCUPIED)
	assert_int(pathfinder.path_cost(path)).is_equal(2)


func test_path_goes_around_difficult_terrain_when_cheaper() -> void:
	# Une case de broussailles en (1, 1) : passer par (1, 0) coûte 2, à
	# travers 3.
	var difficult: Array[Vector2i] = [Vector2i(1, 1)]
	var pathfinder := _difficult(Vector2i(3, 3), difficult)
	var path := pathfinder.find_path(Vector2i(0, 1), Vector2i(2, 1), NO_OCCUPIED)
	assert_int(path.size()).is_equal(2)
	assert_bool(path.has(Vector2i(1, 1))).is_false()
	assert_int(pathfinder.path_cost(path)).is_equal(2)


func test_path_crosses_difficult_terrain_when_no_cheaper_way() -> void:
	# Une bande de broussailles sur toute la hauteur : il faut la traverser.
	var difficult: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)]
	var pathfinder := _difficult(Vector2i(3, 3), difficult)
	var path := pathfinder.find_path(Vector2i(0, 1), Vector2i(2, 1), NO_OCCUPIED)
	assert_int(pathfinder.path_cost(path)).is_equal(3)


func test_reachable_cells_count_difficult_terrain_twice() -> void:
	var difficult: Array[Vector2i] = [Vector2i(1, 0)]
	var reachable := _difficult(Vector2i(8, 1), difficult).reachable_cells(Vector2i(0, 0), 6, NO_OCCUPIED)
	assert_int(reachable[Vector2i(1, 0)]).is_equal(2)
	assert_int(reachable[Vector2i(5, 0)]).is_equal(6)
	assert_bool(reachable.has(Vector2i(6, 0))).is_false()


func test_reachable_cells_keep_the_cheapest_cost() -> void:
	# (2, 0) se rejoint en 2 en contournant la broussaille (1, 0) par (1, 1).
	var difficult: Array[Vector2i] = [Vector2i(1, 0)]
	var reachable := _difficult(Vector2i(4, 2), difficult).reachable_cells(Vector2i(0, 0), 6, NO_OCCUPIED)
	assert_int(reachable[Vector2i(2, 0)]).is_equal(2)


func test_extra_difficult_cells_cost_two_and_can_be_crossed_without_stopping() -> void:
	# La case d'une créature qu'on peut traverser (neutralisée, par exemple)
	# est un terrain difficile pour qui n'est pas son allié.
	var creature: Array[Vector2i] = [Vector2i(1, 0)]
	var pathfinder := _pathfinder(Vector2i(3, 1))
	var path := pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 0), NO_OCCUPIED, creature, creature)
	assert_array(path).contains_exactly(Vector2i(1, 0), Vector2i(2, 0))
	assert_int(pathfinder.path_cost(path, creature)).is_equal(3)
	assert_array(pathfinder.find_path(Vector2i(0, 0), Vector2i(1, 0), NO_OCCUPIED, creature, creature)).is_empty()
	var reachable := pathfinder.reachable_cells(Vector2i(0, 0), 6, NO_OCCUPIED, creature, creature)
	assert_bool(reachable.has(Vector2i(1, 0))).is_false()
	assert_int(reachable[Vector2i(2, 0)]).is_equal(3)

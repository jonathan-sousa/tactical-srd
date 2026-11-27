## Ligne de vue : segment de centre à centre, bloqué par l'intérieur d'un
## obstacle, jamais par un simple coin.
extends GdUnitTestSuite


func _los(blocked: Array[Vector2i]) -> LineOfSight:
	return LineOfSight.new(blocked)


func test_open_grid_is_always_clear() -> void:
	var los := _los([])
	assert_bool(los.is_clear(Vector2i(0, 0), Vector2i(11, 7))).is_true()
	assert_bool(los.is_clear(Vector2i(3, 3), Vector2i(3, 3))).is_true()


func test_obstacle_in_between_blocks() -> void:
	var blocked: Array[Vector2i] = [Vector2i(2, 0)]
	assert_bool(_los(blocked).is_clear(Vector2i(0, 0), Vector2i(5, 0))).is_false()


func test_obstacle_beside_the_line_does_not_block() -> void:
	var blocked: Array[Vector2i] = [Vector2i(2, 1)]
	assert_bool(_los(blocked).is_clear(Vector2i(0, 0), Vector2i(5, 0))).is_true()


func test_touching_a_corner_does_not_block() -> void:
	# De (0,0) à (2,2), le segment passe pile par le coin de la case (1,0).
	var blocked: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	assert_bool(_los(blocked).is_clear(Vector2i(0, 0), Vector2i(2, 2))).is_true()


func test_diagonal_through_an_obstacle_blocks() -> void:
	var blocked: Array[Vector2i] = [Vector2i(1, 1)]
	assert_bool(_los(blocked).is_clear(Vector2i(0, 0), Vector2i(2, 2))).is_false()


func test_is_symmetric() -> void:
	var blocked: Array[Vector2i] = [Vector2i(4, 2), Vector2i(4, 3), Vector2i(6, 5)]
	var los := _los(blocked)
	for from: Vector2i in [Vector2i(1, 3), Vector2i(0, 0), Vector2i(7, 6)]:
		for to: Vector2i in [Vector2i(10, 4), Vector2i(5, 2), Vector2i(8, 1)]:
			assert_bool(los.is_clear(from, to)).is_equal(los.is_clear(to, from))


func test_ambush_starts_out_of_sight() -> void:
	# Dans la vraie rencontre, le rocher en (4,3) cache le Gobelin au départ.
	var encounter := DataRegistry.load_from().encounter(&"goblin_ambush")
	var los := LineOfSight.new(encounter.blocked_cells)
	assert_bool(los.is_clear(encounter.player_starts[0], encounter.enemies[0].cell)).is_false()

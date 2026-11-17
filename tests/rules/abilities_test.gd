extends GdUnitTestSuite


# Les valeurs impaires sous 10 vérifient l'arrondi à l'inférieur :
# (7 - 10) / 2 = -1,5 doit donner -2, pas -1.
func test_modifier(score: int, expected: int, test_parameters := [
	[1, -5], [3, -4], [7, -2], [8, -1], [9, -1], [10, 0], [11, 0], [13, 1], [15, 2], [17, 3], [20, 5], [30, 10],
]) -> void:
	assert_int(Abilities.modifier(score)).is_equal(expected)

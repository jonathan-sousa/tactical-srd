## État de santé vu de l'extérieur (PV approximatifs des ennemis) : Indemne,
## Blessé, En sang (SRD « Bloodied » : la moitié de ses PV ou moins), Hors de
## combat.
extends GdUnitTestSuite

const Fixtures := preload("res://tests/helpers/fixtures.gd")


func test_full_hit_points_is_unhurt() -> void:
	assert_int(HealthStatus.of(7, 7)).is_equal(HealthStatus.Status.UNHURT)


func test_bloodied_threshold_on_seven_hit_points() -> void:
	# La moitié de 7 est 3,5 : 3 PV ou moins.
	assert_int(HealthStatus.of(6, 7)).is_equal(HealthStatus.Status.WOUNDED)
	assert_int(HealthStatus.of(4, 7)).is_equal(HealthStatus.Status.WOUNDED)
	assert_int(HealthStatus.of(3, 7)).is_equal(HealthStatus.Status.BLOODIED)
	assert_int(HealthStatus.of(1, 7)).is_equal(HealthStatus.Status.BLOODIED)


func test_bloodied_threshold_on_ten_hit_points() -> void:
	# Exactement la moitié compte : « half its Hit Points or fewer ».
	assert_int(HealthStatus.of(6, 10)).is_equal(HealthStatus.Status.WOUNDED)
	assert_int(HealthStatus.of(5, 10)).is_equal(HealthStatus.Status.BLOODIED)


func test_zero_hit_points_is_down() -> void:
	assert_int(HealthStatus.of(0, 10)).is_equal(HealthStatus.Status.DOWN)


func test_status_of_a_combatant() -> void:
	var goblin := Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY)
	assert_int(HealthStatus.of_combatant(goblin)).is_equal(HealthStatus.Status.UNHURT)
	goblin.hp = 4
	assert_int(HealthStatus.of_combatant(goblin)).is_equal(HealthStatus.Status.BLOODIED)
	goblin.is_dead = true
	assert_int(HealthStatus.of_combatant(goblin)).is_equal(HealthStatus.Status.DOWN)


func test_bar_fraction_follows_the_status() -> void:
	# La barre d'un ennemi montre l'état, pas le chiffre exact.
	assert_float(HealthStatus.bar_fraction(HealthStatus.Status.UNHURT)).is_equal(1.0)
	assert_float(HealthStatus.bar_fraction(HealthStatus.Status.WOUNDED)).is_greater(0.5)
	assert_float(HealthStatus.bar_fraction(HealthStatus.Status.BLOODIED)).is_less_equal(0.5)
	assert_float(HealthStatus.bar_fraction(HealthStatus.Status.BLOODIED)).is_greater(0.0)
	assert_float(HealthStatus.bar_fraction(HealthStatus.Status.DOWN)).is_equal(0.0)

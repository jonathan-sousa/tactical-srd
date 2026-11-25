## Mode démo : lecture des arguments et dés à graine.
extends GdUnitTestSuite


func test_off_without_the_flag() -> void:
	var options := Autoplay.parse(PackedStringArray(["--seed=5"]))
	assert_bool(options["enabled"]).is_false()


func test_reads_seed_and_speed() -> void:
	var options := Autoplay.parse(PackedStringArray(["--autoplay", "--seed=42", "--speed=4"]))
	assert_bool(options["enabled"]).is_true()
	assert_int(options["seed"]).is_equal(42)
	assert_float(options["speed"]).is_equal(4.0)


func test_ignores_bad_values_and_bounds_the_speed() -> void:
	var options := Autoplay.parse(PackedStringArray(["--autoplay", "--seed=abc", "--speed=1000"]))
	assert_int(options["seed"]).is_equal(0)
	assert_float(options["speed"]).is_equal(16.0)


func test_demo_dice_follow_the_seed() -> void:
	var saved := [Autoplay.enabled, Autoplay.seed_value]
	Autoplay.enabled = true
	Autoplay.seed_value = 7
	var first := Autoplay.make_dice().roll_die(20)
	var second := Autoplay.make_dice().roll_die(20)
	Autoplay.enabled = saved[0]
	Autoplay.seed_value = saved[1]
	assert_int(first).is_equal(second)
	assert_int(first).is_equal(Dice.seeded(7).roll_die(20))

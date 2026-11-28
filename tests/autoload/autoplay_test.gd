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


func test_reads_the_replay_file() -> void:
	var options := Autoplay.parse(PackedStringArray(["--replay=user://replays/last_combat.json"]))
	assert_str(options["replay"]).is_equal("user://replays/last_combat.json")
	assert_bool(options["enabled"]).is_false()


func test_reads_a_skirmish_encounter_and_party() -> void:
	var options := Autoplay.parse(PackedStringArray(["--encounter=goblin_band", "--party=fighter_lvl1,fighter_lvl1"]))
	assert_str(options["encounter"]).is_equal("goblin_band")
	assert_array(options["party"]).contains_exactly([&"fighter_lvl1", &"fighter_lvl1"])
	assert_bool(options["enabled"]).is_false()


func test_no_skirmish_by_default() -> void:
	var options := Autoplay.parse(PackedStringArray(["--autoplay"]))
	assert_str(options["encounter"]).is_empty()
	assert_array(options["party"]).is_empty()

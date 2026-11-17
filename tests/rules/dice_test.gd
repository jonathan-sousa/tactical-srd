extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")


# --- Lancers simples -------------------------------------------------------


func test_roll_die_stays_in_range(sides: int, test_parameters := [[4], [6], [8], [10], [12], [20]]) -> void:
	var dice := Dice.seeded(1234)
	for i in 300:
		assert_int(dice.roll_die(sides)).is_between(1, sides)


func test_same_seed_gives_same_results() -> void:
	var first := Dice.seeded(42)
	var second := Dice.seeded(42)
	for i in 50:
		assert_int(first.roll_die(20)).is_equal(second.roll_die(20))
	assert_int(first.roll(DiceExpression.parse("3d6+2")).total).is_equal(second.roll(DiceExpression.parse("3d6+2")).total)


# --- Expressions -------------------------------------------------------------


func test_parse_valid_expression(text: String, count: int, sides: int, modifier: int, test_parameters := [
	["2d6+3", 2, 6, 3],
	["1d8", 1, 8, 0],
	["d20", 1, 20, 0],
	["1d6-1", 1, 6, -1],
	[" 2d6 + 3 ", 2, 6, 3],
	["4D4", 4, 4, 0],
]) -> void:
	var expression := DiceExpression.parse(text)
	assert_object(expression).is_not_null()
	assert_int(expression.count).is_equal(count)
	assert_int(expression.sides).is_equal(sides)
	assert_int(expression.modifier).is_equal(modifier)


func test_parse_invalid_expression(text: String, test_parameters := [[""], ["abc"], ["2d7"], ["0d6"], ["2d6+"], ["2x6"], ["2d6+3+1"]]) -> void:
	assert_object(DiceExpression.parse(text)).is_null()


func test_expression_to_string() -> void:
	assert_str(str(DiceExpression.parse("2d6+3"))).is_equal("2d6+3")
	assert_str(str(DiceExpression.parse("1d6-1"))).is_equal("1d6-1")
	assert_str(str(DiceExpression.parse("d8"))).is_equal("1d8")


func test_doubled_dice_keeps_modifier() -> void:
	var doubled := DiceExpression.parse("2d6+3").with_doubled_dice()
	assert_str(str(doubled)).is_equal("4d6+3")


func test_with_modifier_adds_to_existing_modifier() -> void:
	assert_str(str(DiceExpression.parse("1d6+1").with_modifier(2))).is_equal("1d6+3")
	assert_str(str(DiceExpression.parse("1d6").with_modifier(-2))).is_equal("1d6-2")


func test_roll_expression_sums_dice_and_modifier() -> void:
	var dice := FixedDice.new([4, 5])
	var result := dice.roll(DiceExpression.parse("2d6+3"))
	assert_array(result.rolls).contains_exactly(4, 5)
	assert_int(result.modifier).is_equal(3)
	assert_int(result.total).is_equal(12)
	assert_int(dice.remaining()).is_equal(0)


func test_roll_text_parses_then_rolls() -> void:
	var dice := FixedDice.new([2, 6])
	assert_int(dice.roll_text("2d6-1").total).is_equal(7)


# --- d20, avantage et désavantage ---------------------------------------------


func test_d20_normal_rolls_once() -> void:
	var dice := FixedDice.new([13])
	var d20 := dice.roll_d20()
	assert_array(d20.rolls).contains_exactly(13)
	assert_int(d20.natural).is_equal(13)
	assert_int(dice.remaining()).is_equal(0)


func test_d20_advantage_keeps_highest() -> void:
	var d20 := FixedDice.new([7, 15]).roll_d20(Dice.RollMode.ADVANTAGE)
	assert_array(d20.rolls).contains_exactly(7, 15)
	assert_int(d20.natural).is_equal(15)


func test_d20_disadvantage_keeps_lowest() -> void:
	var d20 := FixedDice.new([7, 15]).roll_d20(Dice.RollMode.DISADVANTAGE)
	assert_array(d20.rolls).contains_exactly(7, 15)
	assert_int(d20.natural).is_equal(7)


func test_d20_natural_flags() -> void:
	assert_bool(FixedDice.new([20]).roll_d20().is_natural_20()).is_true()
	assert_bool(FixedDice.new([1]).roll_d20().is_natural_1()).is_true()
	var middle := FixedDice.new([10]).roll_d20()
	assert_bool(middle.is_natural_20()).is_false()
	assert_bool(middle.is_natural_1()).is_false()

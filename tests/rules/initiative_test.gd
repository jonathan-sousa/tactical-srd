extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const Fixtures := preload("res://tests/helpers/fixtures.gd")

var _fighter: Combatant
var _goblin: Combatant


func before_test() -> void:
	_fighter = Combatant.new(Fixtures.fighter(), Combatant.Side.PLAYER)
	_goblin = Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY)


func test_highest_total_goes_first() -> void:
	# Guerrier 5 + 1 = 6, Gobelin 10 + 2 = 12.
	var order := Initiative.roll_order([_fighter, _goblin], FixedDice.new([5, 10]))
	assert_object(order[0].combatant).is_same(_goblin)
	assert_object(order[1].combatant).is_same(_fighter)


func test_entries_record_the_roll() -> void:
	var order := Initiative.roll_order([_fighter, _goblin], FixedDice.new([5, 10]))
	var goblin_entry: InitiativeEntry = order[0]
	assert_int(goblin_entry.d20).is_equal(10)
	assert_int(goblin_entry.bonus).is_equal(2)
	assert_int(goblin_entry.total).is_equal(12)


func test_tie_puts_player_first() -> void:
	# Guerrier 11 + 1 = 12, Gobelin 10 + 2 = 12. Le Gobelin est passé en
	# premier dans la liste, le Guerrier doit quand même commencer.
	var order := Initiative.roll_order([_goblin, _fighter], FixedDice.new([10, 11]))
	assert_int(order[0].total).is_equal(order[1].total)
	assert_object(order[0].combatant).is_same(_fighter)


func test_tie_between_same_side_keeps_input_order() -> void:
	var other_goblin := Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY)
	var order := Initiative.roll_order([_goblin, other_goblin], FixedDice.new([8, 8]))
	assert_object(order[0].combatant).is_same(_goblin)
	assert_object(order[1].combatant).is_same(other_goblin)


func test_same_seed_gives_same_order() -> void:
	for seed_value: int in [3, 17, 512]:
		var first := Initiative.roll_order([_fighter, _goblin], Dice.seeded(seed_value))
		var second := Initiative.roll_order([_fighter, _goblin], Dice.seeded(seed_value))
		assert_int(first[0].total).is_equal(second[0].total)
		assert_object(first[0].combatant).is_same(second[0].combatant)

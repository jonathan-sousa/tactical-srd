extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const Fixtures := preload("res://tests/helpers/fixtures.gd")

var _fighter: Combatant
var _goblin: Combatant


# Note gdUnit4 : before_test() s'exécute avant chaque test (comme `setup`
# dans Minitest), donc chaque test repart de combattants neufs.
func before_test() -> void:
	_fighter = Combatant.new(Fixtures.fighter(), Combatant.Side.PLAYER, Vector2i(0, 0))
	_goblin = Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY, Vector2i(1, 0))


func _fighter_attacks(dice: Dice, mode: Dice.RollMode = Dice.RollMode.NORMAL) -> AttackResult:
	return AttackResolver.resolve(_fighter, _goblin, Fixtures.greatsword(), dice, mode)


# --- Touché ou raté -----------------------------------------------------------


func test_total_equal_to_armor_class_hits() -> void:
	# 10 + 5 = 15 contre CA 15 : touché.
	var result := _fighter_attacks(FixedDice.new([10, 1, 1]))
	assert_int(result.attack_total).is_equal(15)
	assert_int(result.target_armor_class).is_equal(15)
	assert_bool(result.is_hit).is_true()
	assert_bool(result.is_critical).is_false()


func test_total_below_armor_class_misses() -> void:
	# 9 + 5 = 14 contre CA 15 : raté, et aucun dé de dégâts n'est lancé.
	var dice := FixedDice.new([9])
	var result := _fighter_attacks(dice)
	assert_bool(result.is_hit).is_false()
	assert_object(result.damage_roll).is_null()
	assert_int(result.damage).is_equal(0)
	assert_int(dice.remaining()).is_equal(0)


func test_natural_20_hits_and_is_critical_even_against_high_armor_class() -> void:
	_goblin.definition.armor_class = 30
	var result := _fighter_attacks(FixedDice.new([20, 1, 2, 3, 4]))
	assert_bool(result.is_hit).is_true()
	assert_bool(result.is_critical).is_true()


func test_natural_1_misses_even_against_low_armor_class() -> void:
	_goblin.definition.armor_class = 1
	var dice := FixedDice.new([1])
	var result := _fighter_attacks(dice)
	assert_bool(result.is_hit).is_false()
	assert_bool(result.is_critical).is_false()
	assert_int(dice.remaining()).is_equal(0)


# --- Dégâts ------------------------------------------------------------------


func test_hit_rolls_weapon_dice_plus_ability_modifier() -> void:
	var result := _fighter_attacks(FixedDice.new([12, 6, 2]))
	assert_str(str(result.damage_roll.expression)).is_equal("2d6+3")
	assert_array(result.damage_roll.rolls).contains_exactly(6, 2)
	assert_int(result.damage).is_equal(11)
	assert_int(result.damage_type).is_equal(DamageType.Type.SLASHING)


func test_critical_doubles_dice_but_not_modifier() -> void:
	var dice := FixedDice.new([20, 1, 2, 3, 4])
	var result := _fighter_attacks(dice)
	assert_str(str(result.damage_roll.expression)).is_equal("4d6+3")
	assert_array(result.damage_roll.rolls).contains_exactly(1, 2, 3, 4)
	assert_int(result.damage).is_equal(13)
	assert_int(dice.remaining()).is_equal(0)


func test_damage_is_never_negative() -> void:
	# FOR 1 : modificateur -5, donc 2d6-5 peut descendre sous 0.
	_fighter.definition.strength = 1
	_goblin.definition.armor_class = 1
	var result := _fighter_attacks(FixedDice.new([10, 1, 1]))
	assert_bool(result.is_hit).is_true()
	assert_int(result.damage_roll.total).is_equal(-3)
	assert_int(result.damage).is_equal(0)


func test_goblin_scimitar_uses_dexterity() -> void:
	var result := AttackResolver.resolve(_goblin, _fighter, Fixtures.scimitar(), FixedDice.new([12, 3]))
	# 12 + 4 = 16 contre CA 16 : touché, 1d6+2 = 5.
	assert_int(result.attack_bonus).is_equal(4)
	assert_bool(result.is_hit).is_true()
	assert_int(result.damage).is_equal(5)


# --- Avantage et désavantage --------------------------------------------------


func test_advantage_uses_higher_d20() -> void:
	var result := _fighter_attacks(FixedDice.new([3, 18, 1, 1]), Dice.RollMode.ADVANTAGE)
	assert_int(result.d20.natural).is_equal(18)
	assert_bool(result.is_hit).is_true()


func test_disadvantage_uses_lower_d20() -> void:
	var result := _fighter_attacks(FixedDice.new([18, 3]), Dice.RollMode.DISADVANTAGE)
	assert_int(result.d20.natural).is_equal(3)
	assert_bool(result.is_hit).is_false()


func test_disadvantage_with_a_natural_20_still_uses_lower_d20() -> void:
	var result := _fighter_attacks(FixedDice.new([20, 5]), Dice.RollMode.DISADVANTAGE)
	assert_bool(result.is_critical).is_false()


# --- Pureté et reproductibilité ----------------------------------------------


func test_resolve_does_not_change_hit_points() -> void:
	_fighter_attacks(FixedDice.new([20, 6, 6, 6, 6]))
	assert_int(_goblin.hp).is_equal(10)


func test_same_seed_gives_same_attack() -> void:
	for seed_value: int in [1, 7, 99, 2024]:
		var first := _fighter_attacks(Dice.seeded(seed_value))
		var second := _fighter_attacks(Dice.seeded(seed_value))
		assert_array(first.d20.rolls).is_equal(second.d20.rolls)
		assert_bool(first.is_hit).is_equal(second.is_hit)
		assert_int(first.damage).is_equal(second.damage)

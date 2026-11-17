extends GdUnitTestSuite

const Fixtures := preload("res://tests/helpers/fixtures.gd")


func test_starts_with_max_hp() -> void:
	var fighter := Combatant.new(Fixtures.fighter(), Combatant.Side.PLAYER, Vector2i(2, 3))
	assert_int(fighter.hp).is_equal(12)
	assert_that(fighter.position).is_equal(Vector2i(2, 3))
	assert_bool(fighter.is_down()).is_false()
	assert_array(fighter.conditions).is_empty()


func test_armor_class_comes_from_definition() -> void:
	assert_int(Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY).armor_class()).is_equal(15)


func test_attack_bonus_is_ability_modifier_plus_proficiency() -> void:
	var fighter := Combatant.new(Fixtures.fighter(), Combatant.Side.PLAYER)
	var goblin := Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY)
	# Brief : Épée à deux mains +5 (FOR 17), Cimeterre +4 (DEX 15).
	assert_int(fighter.attack_bonus(Fixtures.greatsword())).is_equal(5)
	assert_int(goblin.attack_bonus(Fixtures.scimitar())).is_equal(4)


func test_damage_modifier_is_ability_modifier() -> void:
	assert_int(Combatant.new(Fixtures.fighter(), Combatant.Side.PLAYER).damage_modifier(Fixtures.greatsword())).is_equal(3)
	assert_int(Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY).damage_modifier(Fixtures.scimitar())).is_equal(2)


func test_take_damage_reduces_hp() -> void:
	var goblin := Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY)
	assert_int(goblin.take_damage(4)).is_equal(4)
	assert_int(goblin.hp).is_equal(6)
	assert_bool(goblin.is_down()).is_false()


func test_take_damage_stops_at_zero() -> void:
	var goblin := Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY)
	# 15 dégâts sur 10 PV : seuls 10 PV sont réellement perdus.
	assert_int(goblin.take_damage(15)).is_equal(10)
	assert_int(goblin.hp).is_equal(0)
	assert_bool(goblin.is_down()).is_true()


func test_two_combatants_do_not_share_state() -> void:
	var definition := Fixtures.goblin()
	var first := Combatant.new(definition, Combatant.Side.ENEMY)
	var second := Combatant.new(definition, Combatant.Side.ENEMY)
	first.take_damage(5)
	assert_int(second.hp).is_equal(10)
	assert_int(definition.max_hp).is_equal(10)

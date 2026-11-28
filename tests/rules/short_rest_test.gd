## Repos court (SRD « Short Rest ») : dépenser un dé de vie pour regagner
## des PV (dé + CON, au moins 1), et Second Wind récupère une utilisation.
extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const Fixtures := preload("res://tests/helpers/fixtures.gd")


func _dice(values: Array) -> Dice:
	var typed: Array[int] = []
	typed.assign(values)
	return FixedDice.new(typed)


func test_a_wounded_character_spends_its_hit_die() -> void:
	var fighter := Fixtures.full_fighter()
	var member := PartyMember.fresh(fighter)
	member.hp = 3
	var result := ShortRest.take(member, fighter, _dice([6]))
	# d10 : 6, + CON 2 = 8 PV.
	assert_int(result.hit_die_roll).is_equal(6)
	assert_int(result.healed).is_equal(8)
	assert_int(member.hp).is_equal(11)
	assert_int(member.hit_dice).is_equal(0)


func test_healing_stops_at_the_maximum() -> void:
	var fighter := Fixtures.full_fighter()
	var member := PartyMember.fresh(fighter)
	member.hp = 10
	var result := ShortRest.take(member, fighter, _dice([9]))
	assert_int(result.healed).is_equal(2)
	assert_int(member.hp).is_equal(12)


func test_no_hit_die_spent_at_full_health() -> void:
	var rogue := Fixtures.rogue()
	var member := PartyMember.fresh(rogue)
	var result := ShortRest.take(member, rogue, _dice([]))
	assert_int(result.hit_die_roll).is_equal(0)
	assert_int(member.hit_dice).is_equal(1)


func test_no_hit_die_left_no_healing() -> void:
	var rogue := Fixtures.rogue()
	var member := PartyMember.fresh(rogue)
	member.hp = 2
	member.hit_dice = 0
	var result := ShortRest.take(member, rogue, _dice([]))
	assert_int(result.healed).is_equal(0)
	assert_int(member.hp).is_equal(2)


func test_rogue_uses_a_d8() -> void:
	var rogue := Fixtures.rogue()
	var member := PartyMember.fresh(rogue)
	member.hp = 1
	ShortRest.take(member, rogue, _dice([8]))
	assert_int(member.hp).is_equal(10)


func test_second_wind_regains_one_use() -> void:
	var fighter := Fixtures.full_fighter()
	var member := PartyMember.fresh(fighter)
	member.second_wind_uses = 0
	var result := ShortRest.take(member, fighter, _dice([]))
	assert_bool(result.second_wind_regained).is_true()
	assert_int(member.second_wind_uses).is_equal(1)
	member.second_wind_uses = 2
	assert_bool(ShortRest.take(member, fighter, _dice([])).second_wind_regained).is_false()


func test_heroic_inspiration_does_not_come_back() -> void:
	# Elle revient au repos long (trait Ingénieux de l'Humain), pas au court.
	var fighter := Fixtures.full_fighter()
	var member := PartyMember.fresh(fighter)
	member.heroic_inspiration = false
	ShortRest.take(member, fighter, _dice([]))
	assert_bool(member.heroic_inspiration).is_false()


func test_hit_dice_are_saved_and_default_to_full() -> void:
	var member := PartyMember.fresh(Fixtures.rogue())
	member.hit_dice = 0
	var read := PartyMember.from_dict(JSON.parse_string(JSON.stringify(member.to_dict())))
	assert_int(read.hit_dice).is_equal(0)
	var old := PartyMember.from_dict({"def_id": "rogue_lvl1", "hp_current": 10, "second_wind_uses": 0, "heroic_inspiration": false})
	old.clamp_to(Fixtures.rogue())
	assert_int(old.hit_dice).is_equal(1)


func test_hit_dice_survive_a_fight() -> void:
	var before := PartyMember.fresh(Fixtures.rogue())
	before.hit_dice = 0
	var rogue := Combatant.new(Fixtures.rogue(), Combatant.Side.PLAYER)
	before.apply_to(rogue)
	assert_int(PartyMember.after_combat(before, rogue).hit_dice).is_equal(0)

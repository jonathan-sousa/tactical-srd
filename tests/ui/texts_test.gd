## Format des lignes du journal de combat.
extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const Fixtures := preload("res://tests/helpers/fixtures.gd")


func _goblin_attacks(values: Array[int], mode: Dice.RollMode = Dice.RollMode.NORMAL) -> AttackResult:
	var goblin := Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY)
	var fighter := Combatant.new(Fixtures.fighter(), Combatant.Side.PLAYER)
	return AttackResolver.resolve(goblin, fighter, Fixtures.scimitar(), FixedDice.new(values), mode)


func test_hit_line_matches_brief_example() -> void:
	assert_str(Texts.attack_line(_goblin_attacks([14, 3]))) \
		.is_equal("Gobelin guerrier attaque (Cimeterre) : 14 + 4 = 18 contre CA 16, touché, 5 dégâts tranchants (1d6+2 : 3 + 2)")


func test_miss_line() -> void:
	assert_str(Texts.attack_line(_goblin_attacks([5]))).is_equal("Gobelin guerrier attaque (Cimeterre) : 5 + 4 = 9 contre CA 16, raté")


func test_natural_one_line() -> void:
	assert_str(Texts.attack_line(_goblin_attacks([1]))).ends_with(", 1 naturel, raté")


func test_critical_line_shows_doubled_dice() -> void:
	assert_str(Texts.attack_line(_goblin_attacks([20, 6, 5]))) \
		.ends_with("20 naturel, coup critique, 13 dégâts tranchants (2d6+2 : 6 + 5 + 2)")


func test_advantage_line_shows_both_dice() -> void:
	assert_str(Texts.attack_line(_goblin_attacks([7, 15, 3], Dice.RollMode.ADVANTAGE))) \
		.starts_with("Gobelin guerrier attaque (Cimeterre) : 15 [7, 15] + 4 = 19")


func test_every_action_reason_has_a_text() -> void:
	# Toutes les constantes de raison déclarées par Action, sans les lister
	# à la main : une nouvelle raison sans texte fait échouer ce test.
	for constant: String in (Action as Script).get_script_constant_map():
		var code: StringName = (Action as Script).get_script_constant_map()[constant]
		assert_bool(Texts.REASONS.has(code)).override_failure_message("Raison sans texte : %s" % code).is_true()


func test_every_standard_action_and_effect_has_texts() -> void:
	for kind in StandardAction.ALL:
		assert_bool(Texts.ACTION_NAMES.has(kind)).is_true()
		assert_bool(Texts.ACTION_DESCRIPTIONS.has(kind)).is_true()
		assert_bool(Texts.ACTION_LOG.has(kind)).is_true()
	for id: StringName in [Effect.DODGING, Effect.DISENGAGED, Effect.SAPPED, Effect.SLOWED]:
		assert_bool(Texts.EFFECT_NAMES.has(id)).is_true()
		assert_bool(Texts.EFFECT_APPLIED_LOG.has(id)).is_true()
		assert_bool(Texts.EFFECT_ENDED_LOG.has(id)).is_true()
	for code: StringName in [
		AdvantageResolver.TARGET_DODGING, AdvantageResolver.ATTACKER_SAPPED,
		AdvantageResolver.LONG_RANGE, AdvantageResolver.HOSTILE_NEARBY,
	]:
		assert_bool(Texts.ADVANTAGE_REASONS.has(code)).is_true()
	for mastery: StringName in [WeaponDef.GRAZE, WeaponDef.SAP, WeaponDef.SLOW, WeaponDef.NICK, WeaponDef.VEX]:
		assert_bool(Texts.MASTERY_DESCRIPTIONS.has(mastery)).is_true()


func test_opportunity_attack_line_shows_disadvantage_reason() -> void:
	var result := _goblin_attacks([18, 3], Dice.RollMode.DISADVANTAGE)
	result.is_opportunity = true
	result.advantage = AdvantageResult.new()
	result.advantage.mode = Dice.RollMode.DISADVANTAGE
	result.advantage.disadvantages = [AdvantageResolver.TARGET_DODGING]
	assert_str(Texts.attack_line(result)) \
		.is_equal("Gobelin guerrier attaque d'opportunité (Cimeterre) : 3 [18, 3] + 4 = 7 contre CA 16, raté (désavantage : la cible esquive)")


func test_great_weapon_fighting_shows_raised_dice() -> void:
	var fighter := Combatant.new(Fixtures.fighter(), Combatant.Side.PLAYER)
	var goblin := Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY)
	var result := AttackResolver.roll_attack(fighter, goblin, Fixtures.greatsword(), FixedDice.new([15]))
	AttackResolver.roll_damage(result, FixedDice.new([1, 5]), true)
	assert_str(Texts.attack_line(result)).ends_with("touché, 11 dégâts tranchants (2d6+3 : 1→3 + 5 + 3)")


func test_savage_attacker_shows_the_discarded_roll() -> void:
	var fighter := Combatant.new(Fixtures.fighter(), Combatant.Side.PLAYER)
	var goblin := Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY)
	var result := AttackResolver.roll_attack(fighter, goblin, Fixtures.greatsword(), FixedDice.new([15]))
	AttackResolver.roll_damage(result, FixedDice.new([2, 2, 6, 5]), false, true)
	assert_str(Texts.attack_line(result)).ends_with("14 dégâts tranchants (2d6+3 : 6 + 5 + 3 ; meilleur de deux jets, l'autre faisait 7)")


func test_thrown_javelin_line() -> void:
	var fighter := Combatant.new(Fixtures.full_fighter(), Combatant.Side.PLAYER)
	var goblin := Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY)
	var result := AttackResolver.resolve(fighter, goblin, Fixtures.javelin(), FixedDice.new([5]))
	result.is_ranged = true
	assert_str(Texts.attack_line(result)).starts_with("Guerrier lance (Javelot) : 5 + 5 = 10")


func test_every_damage_type_has_a_label() -> void:
	for type: int in DamageType.Type.values():
		assert_bool(Texts.DAMAGE_TYPES.has(type)).is_true()

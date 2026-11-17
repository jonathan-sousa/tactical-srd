## Valeurs des fiches, vérifiées contre le SRD 5.2.1 et le tableau du brief.
extends GdUnitTestSuite

var _registry: DataRegistry


func before() -> void:
	_registry = DataRegistry.load_from()


func test_fighter_matches_srd() -> void:
	var fighter := _registry.character(&"fighter_lvl1")
	# Tableau standard (15, 14, 13, 12, 10, 8) + Soldat : +2 FOR, +1 CON.
	assert_array([fighter.strength, fighter.dexterity, fighter.constitution]).contains_exactly(17, 13, 15)
	assert_array([fighter.intelligence, fighter.wisdom, fighter.charisma]).contains_exactly(8, 12, 10)
	# Niveau 1 : 10 + modificateur de CON.
	assert_int(fighter.max_hp).is_equal(10 + Abilities.modifier(fighter.constitution))
	assert_int(fighter.max_hp).is_equal(12)
	# Cotte de mailles : CA 16 (exige FOR 13).
	assert_int(fighter.armor_class).is_equal(16)
	assert_int(fighter.strength).is_greater_equal(13)
	assert_int(fighter.initiative_bonus).is_equal(Abilities.modifier(fighter.dexterity))
	assert_int(fighter.speed_feet).is_equal(30)
	assert_int(fighter.proficiency_bonus).is_equal(2)


func test_goblin_matches_srd() -> void:
	var goblin := _registry.character(&"goblin_warrior")
	assert_array([goblin.strength, goblin.dexterity, goblin.constitution]).contains_exactly(8, 15, 10)
	assert_array([goblin.intelligence, goblin.wisdom, goblin.charisma]).contains_exactly(10, 8, 8)
	# HP 10 (3d6) : on prend la valeur fixe du bloc de statistiques.
	assert_int(goblin.max_hp).is_equal(10)
	assert_int(goblin.armor_class).is_equal(15)
	assert_int(goblin.initiative_bonus).is_equal(2)
	assert_int(goblin.speed_feet).is_equal(30)
	assert_int(goblin.proficiency_bonus).is_equal(2)


func test_weapons_match_srd() -> void:
	var greatsword := _registry.weapon(&"greatsword")
	assert_str(greatsword.damage_dice).is_equal("2d6")
	assert_int(greatsword.damage_type).is_equal(DamageType.Type.SLASHING)
	assert_int(greatsword.ability).is_equal(Abilities.Ability.STRENGTH)
	assert_int(greatsword.reach_feet).is_equal(5)

	var scimitar := _registry.weapon(&"scimitar")
	assert_str(scimitar.damage_dice).is_equal("1d6")
	assert_int(scimitar.damage_type).is_equal(DamageType.Type.SLASHING)
	# Finesse : le Gobelin utilise sa DEX (+4 au bloc de statistiques).
	assert_int(scimitar.ability).is_equal(Abilities.Ability.DEXTERITY)


func test_attack_bonuses_match_stat_blocks() -> void:
	var fighter := Combatant.new(_registry.character(&"fighter_lvl1"), Combatant.Side.PLAYER)
	var goblin := Combatant.new(_registry.character(&"goblin_warrior"), Combatant.Side.ENEMY)
	# Épée à deux mains +5, 2d6+3 ; Cimeterre +4, 1d6+2.
	assert_int(fighter.attack_bonus(fighter.definition.weapons[0])).is_equal(5)
	assert_int(fighter.damage_modifier(fighter.definition.weapons[0])).is_equal(3)
	assert_int(goblin.attack_bonus(goblin.definition.weapons[0])).is_equal(4)
	assert_int(goblin.damage_modifier(goblin.definition.weapons[0])).is_equal(2)


func test_every_weapon_has_valid_damage_dice() -> void:
	for id: StringName in [&"greatsword", &"scimitar"]:
		assert_object(DiceExpression.parse(_registry.weapon(id).damage_dice)) \
			.override_failure_message("Dés invalides pour %s" % id) \
			.is_not_null()

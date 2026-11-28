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


func test_fighter_has_every_level_1_feature() -> void:
	var fighter := _registry.character(&"fighter_lvl1")
	assert_str(fighter.species).is_equal("Humain")
	assert_str(fighter.background).is_equal("Soldat")
	assert_int(fighter.level).is_equal(1)
	# Fighting Style, Second Wind (2 utilisations), Weapon Mastery (3 armes).
	assert_str(fighter.fighting_style).is_equal(CharacterDef.GREAT_WEAPON_FIGHTING)
	assert_int(fighter.second_wind_uses).is_equal(2)
	assert_array(fighter.weapon_masteries).contains_exactly_in_any_order([&"greatsword", &"flail", &"javelin"])
	# Soldat : Savage Attacker. Humain : Inspiration héroïque.
	assert_array(fighter.feats).contains_exactly([CharacterDef.SAVAGE_ATTACKER])
	assert_bool(fighter.heroic_inspiration).is_true()
	# Équipement de départ A : épée à deux mains, fléau, 8 javelots.
	var weapon_ids: Array[StringName] = []
	for weapon in fighter.weapons:
		weapon_ids.append(weapon.id)
	assert_array(weapon_ids).contains_exactly([&"greatsword", &"flail", &"javelin"])
	assert_int(fighter.weapon_quantities[&"javelin"]).is_equal(8)


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


func test_goblin_has_its_full_stat_block() -> void:
	var goblin := _registry.character(&"goblin_warrior")
	var weapon_ids: Array[StringName] = []
	for weapon in goblin.weapons:
		weapon_ids.append(weapon.id)
	assert_array(weapon_ids).contains_exactly([&"scimitar", &"shortbow"])
	# Discrétion +6, Perception passive 9 (10 + SAG − 1).
	assert_int(goblin.skill_bonus(CharacterDef.STEALTH)).is_equal(6)
	assert_int(10 + goblin.skill_bonus(CharacterDef.PERCEPTION)).is_equal(9)
	assert_array(goblin.traits).contains_exactly([CharacterDef.NIMBLE_ESCAPE])
	assert_str(goblin.advantage_damage_dice).is_equal("1d4")
	assert_bool(goblin.is_monster).is_true()
	# Les monstres n'ont pas de maîtrise d'arme.
	assert_array(goblin.weapon_masteries).is_empty()


func test_goblin_minion_matches_srd() -> void:
	var minion := _registry.character(&"goblin_minion")
	assert_array([minion.strength, minion.dexterity, minion.constitution]).contains_exactly(8, 15, 10)
	assert_array([minion.intelligence, minion.wisdom, minion.charisma]).contains_exactly(10, 8, 8)
	# HP 7 (2d6) : la valeur fixe du bloc de statistiques.
	assert_int(minion.max_hp).is_equal(7)
	assert_int(minion.armor_class).is_equal(12)
	assert_int(minion.initiative_bonus).is_equal(2)
	assert_int(minion.speed_feet).is_equal(30)
	# Équipement : 3 dagues, qui se lancent.
	assert_array(minion.weapons).has_size(1)
	assert_str(minion.weapons[0].id).is_equal(&"dagger")
	assert_int(minion.weapon_quantities[&"dagger"]).is_equal(3)
	assert_int(minion.skill_bonus(CharacterDef.STEALTH)).is_equal(6)
	assert_int(10 + minion.skill_bonus(CharacterDef.PERCEPTION)).is_equal(9)
	assert_array(minion.traits).contains_exactly([CharacterDef.NIMBLE_ESCAPE])
	# Pas de dé de dégâts en plus avec l'avantage, contrairement au guerrier.
	assert_str(minion.advantage_damage_dice).is_empty()
	assert_bool(minion.is_monster).is_true()
	assert_array(minion.weapon_masteries).is_empty()


func test_fighter_is_proficient_in_perception() -> void:
	var fighter := _registry.character(&"fighter_lvl1")
	# SAG + 1, maîtrise + 2 (compétence choisie au niveau 1 de Guerrier).
	assert_int(fighter.skill_bonus(CharacterDef.PERCEPTION)).is_equal(3)
	assert_bool(fighter.is_monster).is_false()


func test_weapons_match_srd() -> void:
	var greatsword := _registry.weapon(&"greatsword")
	assert_str(greatsword.damage_dice).is_equal("2d6")
	assert_int(greatsword.damage_type).is_equal(DamageType.Type.SLASHING)
	assert_int(greatsword.ability).is_equal(Abilities.Ability.STRENGTH)
	assert_int(greatsword.reach_feet).is_equal(5)
	assert_array(greatsword.properties).contains_exactly_in_any_order([WeaponDef.HEAVY, WeaponDef.TWO_HANDED])
	assert_str(greatsword.mastery).is_equal(WeaponDef.GRAZE)

	var flail := _registry.weapon(&"flail")
	assert_str(flail.damage_dice).is_equal("1d8")
	assert_int(flail.damage_type).is_equal(DamageType.Type.BLUDGEONING)
	assert_str(flail.mastery).is_equal(WeaponDef.SAP)

	var javelin := _registry.weapon(&"javelin")
	assert_str(javelin.damage_dice).is_equal("1d6")
	assert_int(javelin.damage_type).is_equal(DamageType.Type.PIERCING)
	assert_int(javelin.kind).is_equal(WeaponDef.Kind.MELEE)
	assert_array(javelin.properties).contains_exactly([WeaponDef.THROWN])
	assert_int(javelin.range_normal_feet).is_equal(30)
	assert_int(javelin.range_long_feet).is_equal(120)
	assert_str(javelin.mastery).is_equal(WeaponDef.SLOW)

	var shortbow := _registry.weapon(&"shortbow")
	assert_int(shortbow.kind).is_equal(WeaponDef.Kind.RANGED)
	assert_str(shortbow.damage_dice).is_equal("1d6")
	assert_int(shortbow.damage_type).is_equal(DamageType.Type.PIERCING)
	assert_int(shortbow.ability).is_equal(Abilities.Ability.DEXTERITY)
	assert_int(shortbow.range_normal_feet).is_equal(80)
	assert_int(shortbow.range_long_feet).is_equal(320)
	assert_array(shortbow.properties).contains_exactly_in_any_order([WeaponDef.AMMUNITION, WeaponDef.TWO_HANDED])
	assert_str(shortbow.mastery).is_equal(WeaponDef.VEX)

	var scimitar := _registry.weapon(&"scimitar")
	assert_str(scimitar.damage_dice).is_equal("1d6")
	assert_int(scimitar.damage_type).is_equal(DamageType.Type.SLASHING)
	# Finesse : le Gobelin utilise sa DEX (+4 au bloc de statistiques).
	assert_int(scimitar.ability).is_equal(Abilities.Ability.DEXTERITY)

	var dagger := _registry.weapon(&"dagger")
	assert_str(dagger.damage_dice).is_equal("1d4")
	assert_int(dagger.damage_type).is_equal(DamageType.Type.PIERCING)
	assert_int(dagger.kind).is_equal(WeaponDef.Kind.MELEE)
	assert_int(dagger.ability).is_equal(Abilities.Ability.DEXTERITY)
	assert_array(dagger.properties).contains_exactly_in_any_order([WeaponDef.FINESSE, WeaponDef.LIGHT, WeaponDef.THROWN])
	assert_int(dagger.range_normal_feet).is_equal(20)
	assert_int(dagger.range_long_feet).is_equal(60)
	assert_str(dagger.mastery).is_equal(WeaponDef.NICK)


func test_attack_bonuses_match_stat_blocks() -> void:
	var fighter := Combatant.new(_registry.character(&"fighter_lvl1"), Combatant.Side.PLAYER)
	var goblin := Combatant.new(_registry.character(&"goblin_warrior"), Combatant.Side.ENEMY)
	# Épée à deux mains +5, 2d6+3 ; Cimeterre +4, 1d6+2.
	assert_int(fighter.attack_bonus(fighter.definition.weapons[0])).is_equal(5)
	assert_int(fighter.damage_modifier(fighter.definition.weapons[0])).is_equal(3)
	assert_int(goblin.attack_bonus(goblin.definition.weapons[0])).is_equal(4)
	assert_int(goblin.damage_modifier(goblin.definition.weapons[0])).is_equal(2)
	# Arc court +4, 1d6+2.
	assert_int(goblin.attack_bonus(goblin.definition.weapons[1])).is_equal(4)
	assert_int(goblin.damage_modifier(goblin.definition.weapons[1])).is_equal(2)
	# Sbire : dague +4, 1d4+2.
	var minion := Combatant.new(_registry.character(&"goblin_minion"), Combatant.Side.ENEMY)
	assert_int(minion.attack_bonus(minion.definition.weapons[0])).is_equal(4)
	assert_int(minion.damage_modifier(minion.definition.weapons[0])).is_equal(2)


func test_every_weapon_has_valid_damage_dice() -> void:
	for id: StringName in [&"greatsword", &"flail", &"javelin", &"scimitar", &"shortbow", &"dagger"]:
		assert_object(DiceExpression.parse(_registry.weapon(id).damage_dice)) \
			.override_failure_message("Dés invalides pour %s" % id) \
			.is_not_null()

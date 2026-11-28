## Format des lignes du journal de combat.
extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const Fixtures := preload("res://tests/helpers/fixtures.gd")


func _goblin_attacks(values: Array[int], mode: Dice.RollMode = Dice.RollMode.NORMAL) -> AttackResult:
	var goblin := Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY)
	var fighter := Combatant.new(Fixtures.fighter(), Combatant.Side.PLAYER)
	return AttackResolver.resolve(goblin, fighter, Fixtures.scimitar(), FixedDice.new(values), mode)


func test_hit_lines_split_outcome_and_roll_detail() -> void:
	var result := _goblin_attacks([14, 3])
	assert_str(Texts.attack_summary(result)).is_equal("Gobelin guerrier attaque (Cimeterre) : touché, 5 dégâts tranchants")
	assert_str(Texts.attack_detail(result)).is_equal("14 + 4 = 18 contre CA 16 ; 1d6+2 : 3 + 2")


func test_miss_lines() -> void:
	var result := _goblin_attacks([5])
	assert_str(Texts.attack_summary(result)).is_equal("Gobelin guerrier attaque (Cimeterre) : raté")
	assert_str(Texts.attack_detail(result)).is_equal("5 + 4 = 9 contre CA 16")


func test_natural_one_line() -> void:
	assert_str(Texts.attack_summary(_goblin_attacks([1]))).ends_with(" : 1 naturel, raté")


func test_critical_line_shows_doubled_dice() -> void:
	var result := _goblin_attacks([20, 6, 5])
	assert_str(Texts.attack_summary(result)).ends_with("20 naturel, coup critique, 13 dégâts tranchants")
	assert_str(Texts.attack_detail(result)).ends_with("2d6+2 : 6 + 5 + 2")


func test_advantage_line_shows_both_dice() -> void:
	assert_str(Texts.attack_detail(_goblin_attacks([7, 15, 3], Dice.RollMode.ADVANTAGE))).starts_with("15 [7, 15] + 4 = 19")


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
	for id: StringName in [Effect.DODGING, Effect.DISENGAGED, Effect.SAPPED, Effect.SLOWED, Effect.HIDDEN, Effect.PRONE]:
		assert_bool(Texts.EFFECT_NAMES.has(id)).is_true()
		assert_bool(Texts.EFFECT_APPLIED_LOG.has(id)).is_true()
		assert_bool(Texts.EFFECT_ENDED_LOG.has(id)).is_true()
	for constant: String in (AdvantageResolver as Script).get_script_constant_map():
		var code: StringName = (AdvantageResolver as Script).get_script_constant_map()[constant]
		assert_bool(Texts.ADVANTAGE_REASONS.has(code)).override_failure_message("Raison d'avantage sans texte : %s" % code).is_true()
	for constant: String in (CombatantDiedEvent as Script).get_script_constant_map():
		var cause: StringName = (CombatantDiedEvent as Script).get_script_constant_map()[constant]
		assert_bool(Texts.DEATH_CAUSES.has(cause)).override_failure_message("Cause de mort sans texte : %s" % cause).is_true()
	for id: StringName in [SearchAction.ID, StandUpAction.ID, HideAction.ID]:
		assert_bool(Texts.ACTION_NAMES.has(id)).is_true()
		assert_bool(Texts.ACTION_DESCRIPTIONS.has(id)).is_true()
	for mastery: StringName in [WeaponDef.GRAZE, WeaponDef.SAP, WeaponDef.SLOW, WeaponDef.NICK, WeaponDef.VEX]:
		assert_bool(Texts.MASTERY_DESCRIPTIONS.has(mastery)).is_true()


func test_opportunity_attack_line_shows_disadvantage_reason() -> void:
	var result := _goblin_attacks([18, 3], Dice.RollMode.DISADVANTAGE)
	result.is_opportunity = true
	result.advantage = AdvantageResult.new()
	result.advantage.mode = Dice.RollMode.DISADVANTAGE
	result.advantage.disadvantages = [AdvantageResolver.TARGET_DODGING]
	assert_str(Texts.attack_summary(result)).is_equal("Gobelin guerrier attaque d'opportunité (Cimeterre) : raté")
	assert_str(Texts.attack_detail(result)).is_equal("3 [18, 3] + 4 = 7 contre CA 16 (désavantage : la cible esquive)")


func test_great_weapon_fighting_shows_raised_dice() -> void:
	var fighter := Combatant.new(Fixtures.fighter(), Combatant.Side.PLAYER)
	var goblin := Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY)
	var result := AttackResolver.roll_attack(fighter, goblin, Fixtures.greatsword(), FixedDice.new([15]))
	AttackResolver.roll_damage(result, FixedDice.new([1, 5]), true)
	assert_str(Texts.attack_summary(result)).ends_with("touché, 11 dégâts tranchants")
	assert_str(Texts.attack_detail(result)).ends_with("2d6+3 : 1→3 + 5 + 3")


func test_savage_attacker_shows_the_discarded_roll() -> void:
	var fighter := Combatant.new(Fixtures.fighter(), Combatant.Side.PLAYER)
	var goblin := Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY)
	var result := AttackResolver.roll_attack(fighter, goblin, Fixtures.greatsword(), FixedDice.new([15]))
	AttackResolver.roll_damage(result, FixedDice.new([2, 2, 6, 5]), false, true)
	assert_str(Texts.attack_detail(result)).ends_with("2d6+3 : 6 + 5 + 3 ; meilleur de deux jets, l'autre faisait 7")


func test_thrown_javelin_line() -> void:
	var fighter := Combatant.new(Fixtures.full_fighter(), Combatant.Side.PLAYER)
	var goblin := Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY)
	var result := AttackResolver.resolve(fighter, goblin, Fixtures.javelin(), FixedDice.new([5]))
	result.is_ranged = true
	assert_str(Texts.attack_summary(result)).starts_with("Guerrier lance (Javelot) : ")
	assert_str(Texts.attack_detail(result)).starts_with("5 + 5 = 10")


func test_every_damage_type_has_a_label() -> void:
	for type: int in DamageType.Type.values():
		assert_bool(Texts.DAMAGE_TYPES.has(type)).is_true()


func test_goblin_advantage_die_is_shown() -> void:
	var goblin := Combatant.new(Fixtures.full_goblin(), Combatant.Side.ENEMY)
	var fighter := Combatant.new(Fixtures.fighter(), Combatant.Side.PLAYER)
	var result := AttackResolver.resolve(goblin, fighter, Fixtures.scimitar(), FixedDice.new([7, 15, 3, 2]), Dice.RollMode.ADVANTAGE)
	assert_str(Texts.attack_summary(result)).ends_with("7 dégâts tranchants")
	assert_str(Texts.attack_detail(result)).contains("1d6+2 : 3 + 2 ; avec l'avantage, 1d4 : 2")


func test_automatic_critical_on_an_unconscious_target_is_explained() -> void:
	var goblin := Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY)
	var fighter := Combatant.new(Fixtures.fighter(), Combatant.Side.PLAYER)
	var result := AttackResolver.roll_attack(goblin, fighter, Fixtures.scimitar(), FixedDice.new([12]), Dice.RollMode.NORMAL, true)
	AttackResolver.roll_damage(result, FixedDice.new([1, 1]))
	assert_str(Texts.attack_summary(result)).contains("coup critique (cible inconsciente au contact)")


func test_death_save_lines() -> void:
	var fighter := Combatant.new(Fixtures.fighter(), Combatant.Side.PLAYER)
	fighter.death_save_successes = 1
	fighter.death_save_failures = 2
	assert_str(Texts.death_save_line(DeathSaveEvent.new(fighter, 1))) \
		.is_equal("Jet contre la mort de Guerrier : 1, 1 naturel, deux échecs (1 réussite, 2 échecs).")
	assert_str(Texts.death_save_line(DeathSaveEvent.new(fighter, 0, true))) \
		.is_equal("Guerrier est frappé à 0 PV : deux échecs (coup critique) aux jets contre la mort (1 réussite, 2 échecs).")
	assert_str(Texts.death_saves_line(fighter)).is_equal("Jets contre la mort : 1 réussite, 2 échecs")


func test_hide_line_keeps_the_successful_total_secret() -> void:
	var goblin := Combatant.new(Fixtures.full_goblin(), Combatant.Side.ENEMY)
	var hidden := Texts.hide_line(HideAttemptedEvent.new(goblin, 12, 6, true, true))
	assert_str(hidden).is_equal("Gobelin guerrier se cache (Nimble Escape) : invisible tant qu'on ne l'a pas trouvé.")
	assert_str(hidden).not_contains("18")
	assert_str(Texts.hide_line(HideAttemptedEvent.new(goblin, 5, 6, false, false))) \
		.is_equal("Gobelin guerrier tente de se cacher : Discrétion 5 + 6 = 11 contre DD 15, raté.")


func test_initiative_line_explains_surprise() -> void:
	var goblin := Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY)
	var fighter := Combatant.new(Fixtures.fighter(), Combatant.Side.PLAYER)
	var surprised := InitiativeEntry.new(fighter, D20Roll.new(Dice.RollMode.DISADVANTAGE, [15, 4], 4), 1)
	var hidden := InitiativeEntry.new(goblin, D20Roll.new(Dice.RollMode.ADVANTAGE, [3, 12], 12), 2)
	assert_str(Texts.initiative_line([hidden, surprised])) \
		.is_equal("Initiative : Gobelin guerrier 14 (12 [3, 12 ; caché, avantage] + 2), Guerrier 5 (4 [15, 4 ; surpris, désavantage] + 1).")


func test_attack_tooltip_shows_the_estimate() -> void:
	var estimate := AttackEstimate.new()
	estimate.hit_chance = 0.55
	estimate.critical_chance = 0.05
	estimate.damage_min = 9
	estimate.damage_max = 15
	estimate.graze_damage = 3
	estimate.cover_bonus = 2
	estimate.advantage = AdvantageResult.new()
	estimate.advantage.disadvantages = [AdvantageResolver.LONG_RANGE]
	var text := _plain(Texts.attack_tooltip(Fixtures.greatsword(), estimate, false))
	assert_str(text).contains("Épée à deux mains")
	assert_str(text).contains("55 % pour toucher · 9 à 15 dégâts")
	assert_str(text).contains("Graze : 3 si raté")
	assert_str(text).contains("Abri partiel : +2 CA")
	assert_str(text).contains("Désavantage : longue portée")


func test_opportunity_warning_names_the_attackers() -> void:
	var goblin := Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY)
	assert_str(_plain(Texts.opportunity_warning([goblin]))) \
		.is_equal("▼ Attaque d'opportunité de Gobelin guerrier (Se désengager l'évite).")


func test_health_text_exact_or_approximate() -> void:
	var goblin := Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY)
	goblin.hp = 7
	assert_str(Texts.health_text(goblin, true)).is_equal("PV 7 / 10")
	assert_str(Texts.health_text(goblin, false)).is_equal("Blessé")
	goblin.hp = 5
	assert_str(Texts.health_text(goblin, false)).is_equal("En sang")
	goblin.is_dead = true
	assert_str(Texts.health_text(goblin, false)).is_equal("mort")


func test_unit_title_and_body() -> void:
	var goblin := Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY)
	goblin.hp = 7
	var effects: Array[StringName] = [Effect.SAPPED]
	assert_str(_plain(Texts.unit_title(goblin, true))).is_equal("Gobelin guerrier · CA 15")
	assert_str(_plain(Texts.unit_body(goblin, effects, 3, false))).is_equal("Blessé · à 3 cases\nSapé")
	assert_str(_plain(Texts.unit_body(goblin, [], 1, true))).is_equal("PV 7 / 10 · au contact")


func test_every_terrain_with_a_rule_has_a_name_and_a_rule() -> void:
	for terrain: CellInfo.Terrain in [CellInfo.Terrain.OBSTACLE, CellInfo.Terrain.LOW_WALL, CellInfo.Terrain.DIFFICULT]:
		assert_str(Texts.terrain_title(terrain)).is_not_empty()
		assert_str(Texts.terrain_rule(terrain)).is_not_empty()


## Texte sans balises BBCode.
static func _plain(bbcode: String) -> String:
	var regex := RegEx.create_from_string("\\[[^\\]]*\\]")
	return regex.sub(bbcode, "", true)


func test_every_effect_has_a_badge() -> void:
	for id: StringName in Texts.EFFECT_NAMES:
		assert_bool(Texts.EFFECT_BADGES.has(id)).override_failure_message("Effet sans pastille : %s" % id).is_true()


func test_every_reveal_reason_has_its_own_line() -> void:
	var goblin := Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY)
	var fighter := Combatant.new(Fixtures.fighter(), Combatant.Side.PLAYER)
	var lines: Array[String] = []
	for constant: String in (RevealedEvent as Script).get_script_constant_map():
		var reason: StringName = (RevealedEvent as Script).get_script_constant_map()[constant]
		var line := Texts.revealed_line(RevealedEvent.new(goblin, Vector2i.ZERO, reason, fighter))
		assert_str(line).contains(goblin.definition.display_name)
		assert_array(lines).override_failure_message("Même ligne pour %s" % reason).not_contains([line])
		lines.append(line)
	assert_int(lines.size()).is_equal(5)
	var seen := Texts.revealed_line(RevealedEvent.new(goblin, Vector2i.ZERO, RevealedEvent.SEEN, fighter))
	assert_str(seen).contains(fighter.definition.display_name)


func test_cover_is_shown_next_to_the_armor_class() -> void:
	var goblin := Combatant.new(Fixtures.goblin(), Combatant.Side.ENEMY)
	var fighter := Combatant.new(Fixtures.fighter(), Combatant.Side.PLAYER)
	var result := AttackResolver.roll_attack(goblin, fighter, Fixtures.scimitar(), FixedDice.new([13]), Dice.RollMode.NORMAL, false, CombatState.HALF_COVER_BONUS)
	assert_str(Texts.attack_detail(result)).is_equal("13 + 4 = 17 contre CA 18 (abri partiel, +2 CA)")


func test_every_effect_has_a_description() -> void:
	for id: StringName in Texts.EFFECT_NAMES:
		assert_bool(Texts.EFFECT_DESCRIPTIONS.has(id)).override_failure_message("Effet sans description : %s" % id).is_true()


func test_every_trait_of_the_game_characters_has_a_name_and_a_description() -> void:
	var registry := DataRegistry.load_from()
	for id: StringName in [&"fighter_lvl1", &"rogue_lvl1", &"goblin_warrior", &"goblin_minion"]:
		var definition := registry.character(id)
		assert_object(definition).is_not_null()
		for trait_id in Texts.traits_of(definition):
			assert_bool(Texts.TRAIT_NAMES.has(trait_id)).override_failure_message("%s : trait sans nom %s" % [id, trait_id]).is_true()
			assert_bool(Texts.TRAIT_DESCRIPTIONS.has(trait_id)).override_failure_message("%s : trait sans description %s" % [id, trait_id]).is_true()


func test_traits_of_the_rogue() -> void:
	var traits := Texts.traits_of(Fixtures.rogue())
	assert_bool(traits.has(Texts.SNEAK_ATTACK_TRAIT)).is_true()
	assert_bool(traits.has(CharacterDef.HALFLING_LUCK)).is_true()
	assert_bool(traits.has(Texts.SECOND_WIND_TRAIT)).is_false()


func test_tactical_label() -> void:
	var goblin := Combatant.new(Fixtures.minion(), Combatant.Side.ENEMY)
	goblin.number = 2
	goblin.hp = 3
	assert_str(Texts.tactical_label(goblin, false)).ends_with("2 · En sang")
	assert_str(Texts.tactical_label(goblin, true)).ends_with("2 · 3 / 7")

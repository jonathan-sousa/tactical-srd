## Guerrier niveau 1 complet : Great Weapon Fighting, Savage Attacker,
## maîtrises (Graze, Sap, Slow), javelots, Second Wind, Inspiration héroïque.
##
## Fiche de départ : Fixtures.full_fighter(), dont chaque test retire ce qui
## brouillerait les dés (Savage Attacker relance les dés de dégâts,
## l'Inspiration ouvre une décision sur un échec).
extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const Fixtures := preload("res://tests/helpers/fixtures.gd")

var _definition: CharacterDef
var _state: CombatState
var _fighter: Combatant
var _goblin: Combatant


func before_test() -> void:
	_definition = Fixtures.full_fighter()
	_definition.feats = []
	_definition.heroic_inspiration = false


## Grille 30×3 sans obstacle : Guerrier en (0,1), Gobelin(s) aux cases
## données. Initiative : Guerrier 10 + 1, Gobelins 5 + 2 : le Guerrier
## commence.
func _start(goblin_cells: Array[Vector2i], blocked: Array[Vector2i] = []) -> void:
	_state = CombatState.create(Fixtures.encounter(Vector2i(30, 3), Vector2i(0, 1), goblin_cells, blocked), _definition)
	var initiative: Array[int] = [10]
	for cell in goblin_cells:
		initiative.append(5)
	_state.start(FixedDice.new(initiative))
	_fighter = _state.combatants[0]
	_goblin = _state.combatants[1]


func _start_next_to_goblin() -> void:
	_start([Vector2i(1, 1)])


func _weapon(id: StringName) -> WeaponDef:
	for weapon in _definition.weapons:
		if weapon.id == id:
			return weapon
	return null


func _run(action: Action, values: Array = []) -> Array[CombatEvent]:
	assert_str(action.validate(_state)).is_empty()
	var typed: Array[int] = []
	typed.assign(values)
	var dice := FixedDice.new(typed)
	var events := action.execute(_state, dice)
	assert_int(dice.remaining()).override_failure_message("Dés non consommés").is_equal(0)
	return events


func _attack(weapon_id: StringName, values: Array) -> AttackResult:
	var events := _run(AttackAction.new(_fighter, _goblin, _weapon(weapon_id)), values)
	return (events[0] as AttackRolledEvent).result


func _end_turns(count: int) -> void:
	for i in count:
		_run(EndTurnAction.new(_state.active()))


# --- Great Weapon Fighting -----------------------------------------------------------


func test_great_weapon_fighting_turns_ones_and_twos_into_threes() -> void:
	_start_next_to_goblin()
	_goblin.hp = 50
	# 15 + 5 : touché. 1 et 2 comptent comme 3 : 3 + 3 + 3 = 9.
	var result := _attack(&"greatsword", [15, 1, 2])
	assert_bool(result.great_weapon_fighting).is_true()
	assert_array(result.damage_roll.natural_rolls).is_equal([1, 2])
	assert_array(result.damage_roll.rolls).is_equal([3, 3])
	assert_int(result.damage).is_equal(9)


func test_great_weapon_fighting_needs_a_two_handed_weapon() -> void:
	_start_next_to_goblin()
	_goblin.hp = 50
	var result := _attack(&"flail", [15, 1])
	assert_bool(result.great_weapon_fighting).is_false()
	assert_int(result.damage).is_equal(4)


func test_great_weapon_fighting_needs_the_style() -> void:
	_definition.fighting_style = &""
	_start_next_to_goblin()
	_goblin.hp = 50
	assert_int(_attack(&"greatsword", [15, 1, 2]).damage).is_equal(6)


# --- Savage Attacker ----------------------------------------------------------------


func test_savage_attacker_keeps_the_best_of_two_damage_rolls() -> void:
	_definition.feats = [CharacterDef.SAVAGE_ATTACKER]
	_start_next_to_goblin()
	_goblin.hp = 50
	# Premier jet 3 + 3 + 3 = 9 (GWF), second 5 + 6 + 3 = 14 : on garde 14.
	var result := _attack(&"greatsword", [15, 1, 1, 5, 6])
	assert_int(result.damage).is_equal(14)
	assert_int(result.discarded_damage_roll.total).is_equal(9)


func test_savage_attacker_works_once_per_turn() -> void:
	_definition.feats = [CharacterDef.SAVAGE_ATTACKER]
	_start_next_to_goblin()
	_goblin.hp = 50
	_attack(&"greatsword", [15, 1, 1, 5, 6])
	# Seconde touche dans le même tour (directement par la séquence d'attaque).
	_state.action_used = false
	var second := _attack(&"greatsword", [15, 4, 4])
	assert_object(second.discarded_damage_roll).is_null()
	# Le tour suivant (celui du Gobelin), il resservirait.
	_end_turns(1)
	assert_int(_fighter.savage_attacker_turn).is_less(_state.turn_count)


# --- Maîtrises ---------------------------------------------------------------------------


func test_graze_deals_strength_modifier_on_a_miss() -> void:
	_start_next_to_goblin()
	var events := _run(AttackAction.new(_fighter, _goblin, _weapon(&"greatsword")), [5])
	var graze := events[1] as DamageDealtEvent
	assert_bool(graze.is_graze).is_true()
	assert_int(graze.amount).is_equal(3)
	assert_int(_goblin.hp).is_equal(7)


func test_graze_applies_even_on_a_natural_one() -> void:
	_start_next_to_goblin()
	_attack(&"greatsword", [1])
	assert_int(_goblin.hp).is_equal(7)


func test_no_graze_without_the_mastery() -> void:
	_definition.weapon_masteries = []
	_start_next_to_goblin()
	_attack(&"greatsword", [5])
	assert_int(_goblin.hp).is_equal(10)


func test_sap_gives_disadvantage_on_the_next_attack_only() -> void:
	_start_next_to_goblin()
	_goblin.hp = 50
	_attack(&"flail", [15, 4])
	assert_bool(_state.has_effect(_goblin, Effect.SAPPED)).is_true()
	_end_turns(1)

	# Désavantage : 18 et 2, on garde 2. 2 + 4 = 6, raté.
	var events := _run(AttackAction.new(_goblin, _fighter), [18, 2])
	var result := (events[0] as AttackRolledEvent).result
	assert_int(result.d20.mode).is_equal(Dice.RollMode.DISADVANTAGE)
	assert_array(result.advantage.disadvantages).contains([AdvantageResolver.ATTACKER_SAPPED])
	assert_bool(_state.has_effect(_goblin, Effect.SAPPED)).is_false()


func test_sap_ends_at_the_start_of_the_fighter_next_turn() -> void:
	_start_next_to_goblin()
	_goblin.hp = 50
	_attack(&"flail", [15, 4])
	_end_turns(2)
	assert_bool(_state.has_effect(_goblin, Effect.SAPPED)).is_false()


func test_slow_reduces_speed_by_two_squares_until_the_fighter_next_turn() -> void:
	_start([Vector2i(5, 1)])
	# Javelot lancé à 25 ft : portée normale. 15 + 5, 1d6+3 = 7.
	var result := _attack(&"javelin", [15, 4])
	assert_bool(result.is_ranged).is_true()
	assert_bool(_state.has_effect(_goblin, Effect.SLOWED)).is_true()
	_end_turns(1)
	assert_object(_state.active()).is_same(_goblin)
	assert_int(_state.movement_left).is_equal(4)
	_end_turns(1)
	assert_bool(_state.has_effect(_goblin, Effect.SLOWED)).is_false()


func test_slow_does_not_stack() -> void:
	_start([Vector2i(5, 1)])
	_goblin.hp = 50
	_attack(&"javelin", [15, 4])
	_state.action_used = false
	_attack(&"javelin", [15, 4])
	assert_int(_state.speed_in_squares(_goblin)).is_equal(4)


# --- Javelots et attaques à distance ----------------------------------------------------


func test_throwing_a_javelin_uses_one_but_stabbing_does_not() -> void:
	_start_next_to_goblin()
	_goblin.hp = 50
	_attack(&"javelin", [2])
	assert_int(_fighter.quantity(_weapon(&"javelin"))).is_equal(8)

	_goblin.position = Vector2i(5, 1)
	_state.action_used = false
	_attack(&"javelin", [2])
	assert_int(_fighter.quantity(_weapon(&"javelin"))).is_equal(7)


func test_no_javelin_left() -> void:
	_start([Vector2i(5, 1)])
	_fighter.quantities[&"javelin"] = 0
	var attack := AttackAction.new(_fighter, _goblin, _weapon(&"javelin"))
	assert_str(attack.validate(_state)).is_equal(Action.NO_AMMUNITION)


func test_long_range_gives_disadvantage_and_beyond_is_out_of_range() -> void:
	# 50 ft : au-delà des 30 ft de portée normale.
	_start([Vector2i(10, 1)])
	var result := _attack(&"javelin", [15, 18, 4])
	assert_int(result.d20.mode).is_equal(Dice.RollMode.DISADVANTAGE)
	assert_array(result.advantage.disadvantages).contains([AdvantageResolver.LONG_RANGE])

	# 125 ft : au-delà des 120 ft de portée longue.
	_goblin.position = Vector2i(25, 1)
	_state.action_used = false
	var attack := AttackAction.new(_fighter, _goblin, _weapon(&"javelin"))
	assert_str(attack.validate(_state)).is_equal(Action.TARGET_OUT_OF_RANGE)


func test_ranged_attack_with_a_hostile_next_to_you_has_disadvantage() -> void:
	_start([Vector2i(5, 1), Vector2i(1, 1)])
	var advantage := AdvantageResolver.for_attack(_state, _fighter, _goblin, _weapon(&"javelin"))
	assert_array(advantage.disadvantages).contains([AdvantageResolver.HOSTILE_NEARBY])


func test_cannot_attack_through_an_obstacle() -> void:
	var blocked: Array[Vector2i] = [Vector2i(3, 1)]
	_start([Vector2i(5, 1)], blocked)
	var attack := AttackAction.new(_fighter, _goblin, _weapon(&"javelin"))
	assert_str(attack.validate(_state)).is_equal(Action.TARGET_NOT_VISIBLE)


func test_greatsword_cannot_reach_far_targets() -> void:
	_start([Vector2i(5, 1)])
	var attack := AttackAction.new(_fighter, _goblin, _weapon(&"greatsword"))
	assert_str(attack.validate(_state)).is_equal(Action.TARGET_OUT_OF_REACH)


# --- Second Wind -------------------------------------------------------------------------


func test_second_wind_heals_as_a_bonus_action() -> void:
	_start_next_to_goblin()
	_fighter.hp = 3
	# 1d10 + 1 : 6 + 1 = 7.
	var events := _run(SecondWindAction.new(_fighter), [6])
	var healed := events[0] as HealedEvent
	assert_int(healed.amount).is_equal(7)
	assert_int(_fighter.hp).is_equal(10)
	assert_int(_fighter.second_wind_uses).is_equal(1)
	assert_bool(_state.bonus_action_used).is_true()
	assert_bool(_state.action_used).is_false()
	assert_str(SecondWindAction.new(_fighter).validate(_state)).is_equal(Action.BONUS_ACTION_ALREADY_USED)


func test_second_wind_does_not_exceed_max_hp() -> void:
	_start_next_to_goblin()
	_fighter.hp = 10
	var healed := _run(SecondWindAction.new(_fighter), [9])[0] as HealedEvent
	assert_int(healed.amount).is_equal(2)
	assert_int(_fighter.hp).is_equal(12)


func test_second_wind_has_two_uses() -> void:
	_start_next_to_goblin()
	_fighter.second_wind_uses = 0
	assert_str(SecondWindAction.new(_fighter).validate(_state)).is_equal(Action.NO_USES_LEFT)


func test_second_wind_needs_the_feature() -> void:
	_definition.second_wind_uses = 0
	_start_next_to_goblin()
	assert_str(SecondWindAction.new(_fighter).validate(_state)).is_equal(Action.FEATURE_UNAVAILABLE)


# --- Inspiration héroïque ------------------------------------------------------------


func test_a_miss_with_inspiration_waits_for_a_decision() -> void:
	_definition.heroic_inspiration = true
	_start_next_to_goblin()
	var events := _run(AttackAction.new(_fighter, _goblin, _weapon(&"greatsword")), [5])
	assert_int(events.size()).is_equal(1)
	assert_object(_state.pending).is_instanceof(InspirationWindow)
	assert_object(_state.pending.decider).is_same(_fighter)
	# Ni Graze ni autre action tant que le joueur n'a pas décidé.
	assert_int(_goblin.hp).is_equal(10)
	assert_str(EndTurnAction.new(_fighter).validate(_state)).is_equal(Action.DECISION_PENDING)


func test_using_inspiration_rerolls_the_d20() -> void:
	_definition.heroic_inspiration = true
	_start_next_to_goblin()
	_run(AttackAction.new(_fighter, _goblin, _weapon(&"greatsword")), [5])
	# Relance : 17 + 5 = 22, touché ; 2d6+3 avec 4 et 4 = 11.
	var events := _run(UseInspirationAction.new(_fighter), [17, 4, 4])
	var used := events[0] as InspirationUsedEvent
	assert_int(used.old_value).is_equal(5)
	assert_int(used.new_value).is_equal(17)
	var result := (events[1] as AttackRolledEvent).result
	assert_bool(result.is_hit).is_true()
	assert_bool(_fighter.heroic_inspiration).is_false()
	assert_int(_goblin.hp).is_equal(0)
	assert_object(_state.pending).is_null()


func test_declining_inspiration_finishes_the_miss_with_graze() -> void:
	_definition.heroic_inspiration = true
	_start_next_to_goblin()
	_run(AttackAction.new(_fighter, _goblin, _weapon(&"greatsword")), [5])
	_run(DeclineInspirationAction.new(_fighter))
	assert_bool(_fighter.heroic_inspiration).is_true()
	assert_int(_goblin.hp).is_equal(7)
	assert_object(_state.pending).is_null()


func test_inspiration_rerolls_the_lower_die_with_disadvantage() -> void:
	_definition.heroic_inspiration = true
	_start_next_to_goblin()
	_state.add_effect(Effect.new(Effect.DODGING, _goblin, _goblin, Effect.Expiry.START_OF_SOURCE_TURN))
	# Désavantage : 12 et 3, on garde 3 : raté.
	_run(AttackAction.new(_fighter, _goblin, _weapon(&"greatsword")), [12, 3])
	# Le 3 est relancé en 19 : on garde min(12, 19) = 12, 12 + 5 = 17, touché.
	var events := _run(UseInspirationAction.new(_fighter), [19, 1, 1])
	var result := (events[1] as AttackRolledEvent).result
	assert_array(result.d20.rolls).is_equal([12, 19])
	assert_int(result.d20.natural).is_equal(12)
	assert_bool(result.is_hit).is_true()


func test_opportunity_attack_miss_then_inspiration_then_the_move_resumes() -> void:
	_definition.heroic_inspiration = true
	_start_next_to_goblin()
	_end_turns(1)
	_run(MoveAction.new(_goblin, Vector2i(3, 1)))
	_run(OpportunityAttackAction.new(_fighter), [4])
	assert_object(_state.pending).is_instanceof(InspirationWindow)
	assert_that(_goblin.position).is_equal(Vector2i(1, 1))
	_run(DeclineInspirationAction.new(_fighter))
	assert_that(_goblin.position).is_equal(Vector2i(3, 1))
	# Graze sur l'attaque d'opportunité ratée.
	assert_int(_goblin.hp).is_equal(7)

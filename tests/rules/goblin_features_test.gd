## Gobelin guerrier complet : arc court, +1d4 dégâts avec l'avantage,
## Nimble Escape, compétences.
extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const Fixtures := preload("res://tests/helpers/fixtures.gd")

var _state: CombatState
var _fighter: Combatant
var _goblin: Combatant


## Grille 30×3 sans obstacle : Guerrier en (0,1), Gobelin complet à la case
## donnée. Le Gobelin commence (5 + 1 contre 10 + 2).
func _start(goblin_cell: Vector2i) -> void:
	var cells: Array[Vector2i] = [goblin_cell]
	_state = CombatState.create(Fixtures.encounter(Vector2i(30, 3), Vector2i(0, 1), cells, [], Fixtures.full_goblin()), Fixtures.fighter())
	_state.start(_dice([5, 10]))
	_fighter = _state.combatants[0]
	_goblin = _state.combatants[1]


func _dice(values: Array) -> FixedDice:
	var typed: Array[int] = []
	typed.assign(values)
	return FixedDice.new(typed)


func _bow() -> WeaponDef:
	return _goblin.definition.weapons[1]


func _attack(weapon: WeaponDef, values: Array) -> AttackResult:
	var action := AttackAction.new(_goblin, _fighter, weapon)
	assert_str(action.validate(_state)).is_empty()
	var dice := _dice(values)
	var events := action.execute(_state, dice)
	assert_int(dice.remaining()).override_failure_message("Dés non consommés").is_equal(0)
	return (events[0] as AttackRolledEvent).result


func test_attack_with_advantage_adds_1d4() -> void:
	_start(Vector2i(1, 1))
	_state.add_effect(Effect.new(Effect.PRONE, _fighter, _fighter, Effect.Expiry.UNTIL_REMOVED))
	# À terre au contact : avantage. 4 et 14, on garde 14 ; 18 contre CA 16.
	# 1d6 + 2 puis 1d4 : 5 + 2 + 3 = 10.
	var result := _attack(_goblin.melee_weapon(), [4, 14, 5, 3])
	assert_object(result.advantage_damage_roll).is_not_null()
	assert_int(result.damage).is_equal(10)


func test_no_bonus_die_without_advantage() -> void:
	_start(Vector2i(1, 1))
	var result := _attack(_goblin.melee_weapon(), [14, 5])
	assert_object(result.advantage_damage_roll).is_null()
	assert_int(result.damage).is_equal(7)


func test_no_bonus_die_when_advantage_is_cancelled() -> void:
	_start(Vector2i(1, 1))
	_state.add_effect(Effect.new(Effect.PRONE, _fighter, _fighter, Effect.Expiry.UNTIL_REMOVED))
	_state.add_effect(Effect.new(Effect.PRONE, _goblin, _goblin, Effect.Expiry.UNTIL_REMOVED))
	var result := _attack(_goblin.melee_weapon(), [14, 5])
	assert_int(result.d20.mode).is_equal(Dice.RollMode.NORMAL)
	assert_object(result.advantage_damage_roll).is_null()


func test_bonus_die_is_doubled_on_a_critical() -> void:
	_start(Vector2i(1, 1))
	_state.add_effect(Effect.new(Effect.PRONE, _fighter, _fighter, Effect.Expiry.UNTIL_REMOVED))
	# 20 naturel : 2d6 + 2 et 2d4.
	var result := _attack(_goblin.melee_weapon(), [20, 2, 1, 1, 1, 1])
	assert_int(result.advantage_damage_roll.rolls.size()).is_equal(2)
	assert_int(result.damage).is_equal(6)


func test_shortbow_shoots_80_ft_normally_and_up_to_320_ft_with_disadvantage() -> void:
	_start(Vector2i(16, 1))
	var close := _attack(_bow(), [14, 3])
	assert_bool(close.is_ranged).is_true()
	assert_int(close.d20.mode).is_equal(Dice.RollMode.NORMAL)

	_start(Vector2i(17, 1))
	var far := _attack(_bow(), [14, 3])
	assert_array(far.advantage.disadvantages).contains([AdvantageResolver.LONG_RANGE])
	assert_int(far.d20.mode).is_equal(Dice.RollMode.DISADVANTAGE)


func test_shortbow_cannot_strike_in_melee_but_shoots_with_disadvantage() -> void:
	_start(Vector2i(1, 1))
	var result := _attack(_bow(), [14, 3])
	assert_bool(result.is_ranged).is_true()
	assert_array(result.advantage.disadvantages).contains([AdvantageResolver.HOSTILE_NEARBY])


func test_goblin_has_no_weapon_mastery() -> void:
	_start(Vector2i(1, 1))
	assert_bool(_goblin.definition.masters(_bow())).is_false()
	assert_bool(_goblin.definition.masters(_goblin.melee_weapon())).is_false()


func test_nimble_escape_disengages_with_the_bonus_action() -> void:
	_start(Vector2i(1, 1))
	var disengage := StandardAction.new(_goblin, StandardAction.DISENGAGE, true)
	assert_str(disengage.validate(_state)).is_empty()
	var events := disengage.execute(_state, _dice([]))
	assert_bool((events[0] as ActionTakenEvent).bonus_action).is_true()
	assert_bool(_state.bonus_action_used).is_true()
	assert_bool(_state.action_used).is_false()
	assert_bool(_state.has_effect(_goblin, Effect.DISENGAGED)).is_true()


func test_nimble_escape_is_only_disengage_or_hide() -> void:
	_start(Vector2i(1, 1))
	assert_str(StandardAction.new(_goblin, StandardAction.DASH, true).validate(_state)).is_equal(Action.FEATURE_UNAVAILABLE)
	assert_str(StandardAction.new(_goblin, StandardAction.DODGE, true).validate(_state)).is_equal(Action.FEATURE_UNAVAILABLE)


func test_fighter_has_no_nimble_escape() -> void:
	_start(Vector2i(1, 1))
	_run_end_turn()
	assert_str(StandardAction.new(_fighter, StandardAction.DISENGAGE, true).validate(_state)).is_equal(Action.FEATURE_UNAVAILABLE)


func test_skill_bonuses() -> void:
	assert_int(Fixtures.full_goblin().skill_bonus(CharacterDef.STEALTH)).is_equal(6)
	# Sans maîtrise : le modificateur de la caractéristique (SAG 8, DEX 13).
	assert_int(Fixtures.full_goblin().skill_bonus(CharacterDef.PERCEPTION)).is_equal(-1)
	assert_int(Fixtures.full_fighter().skill_bonus(CharacterDef.PERCEPTION)).is_equal(3)
	assert_int(Fixtures.fighter().skill_bonus(CharacterDef.STEALTH)).is_equal(1)


func _run_end_turn() -> void:
	EndTurnAction.new(_state.active()).execute(_state, _dice([]))

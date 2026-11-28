## Action Aider (SRD « Help ») : distraire un ennemi au contact (avantage à
## la prochaine attaque d'un allié contre lui), ou stabiliser un allié
## mourant au contact (Sagesse (Médecine) DD 10).
extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const Fixtures := preload("res://tests/helpers/fixtures.gd")

var _state: CombatState
var _fighter: Combatant
var _rogue: Combatant


## Guerrier (joue en premier) et Roublard contre des gobelins de base. Le
## Roublard refuse l'échange d'Alert.
func _fight(fighter_cell: Vector2i, rogue_cell: Vector2i, goblin_cells: Array[Vector2i]) -> void:
	var starts: Array[Vector2i] = [fighter_cell, rogue_cell]
	var encounter := Fixtures.party_encounter(Vector2i(12, 8), starts, goblin_cells)
	var party: Array[CharacterDef] = [Fixtures.fighter(), Fixtures.rogue()]
	_state = CombatState.create_party(encounter, party)
	var rolls: Array = [20, 2]
	for cell in goblin_cells:
		rolls.append(2)
	_state.start(_dice(rolls))
	_fighter = _state.combatants[0]
	_rogue = _state.combatants[1]
	DeclineSwapAction.new(_rogue).execute(_state, _dice([]))
	assert_object(_state.active()).is_same(_fighter)


func _goblin(index: int = 0) -> Combatant:
	return _state.combatants[2 + index]


func _dice(values: Array) -> Dice:
	var typed: Array[int] = []
	typed.assign(values)
	return FixedDice.new(typed)


func _end_turns_until(who: Combatant) -> void:
	EndTurnAction.new(_state.active()).execute(_state, _dice([10, 10, 10]))
	while _state.active() != who:
		EndTurnAction.new(_state.active()).execute(_state, _dice([10, 10, 10]))


# --- Distraire un ennemi -------------------------------------------------------------------


func test_distracting_an_enemy_gives_an_ally_advantage() -> void:
	_fight(Vector2i(4, 3), Vector2i(0, 7), [Vector2i(5, 3)])
	var help := HelpAction.new(_fighter, _goblin())
	assert_str(help.validate(_state)).is_empty()
	help.execute(_state, _dice([]))
	assert_bool(_state.action_used).is_true()
	assert_bool(_state.has_effect(_goblin(), Effect.HELPED)).is_true()
	var bow := _rogue.definition.weapons[1]
	var advantage := AdvantageResolver.for_attack(_state, _rogue, _goblin(), bow)
	assert_int(advantage.mode).is_equal(Dice.RollMode.ADVANTAGE)
	assert_array(advantage.advantages).contains([AdvantageResolver.TARGET_DISTRACTED])
	# Le Guerrier n'aide pas sa propre attaque.
	assert_int(AdvantageResolver.for_attack(_state, _fighter, _goblin(), _fighter.definition.weapons[0]).mode).is_equal(Dice.RollMode.NORMAL)


func test_the_distraction_is_spent_by_the_next_ally_attack() -> void:
	_fight(Vector2i(4, 3), Vector2i(0, 3), [Vector2i(5, 3)])
	HelpAction.new(_fighter, _goblin()).execute(_state, _dice([]))
	_end_turns_until(_rogue)
	# Arc court, avantage : 3 et 4, raté. Le Guerrier est au contact de la
	# cible : pas de désavantage, et la distraction est dépensée.
	AttackAction.new(_rogue, _goblin(), _rogue.definition.weapons[1]).execute(_state, _dice([3, 4]))
	assert_bool(_state.has_effect(_goblin(), Effect.HELPED)).is_false()


func test_the_distraction_ends_at_the_start_of_the_helpers_next_turn() -> void:
	_fight(Vector2i(4, 3), Vector2i(0, 7), [Vector2i(5, 3)])
	HelpAction.new(_fighter, _goblin()).execute(_state, _dice([]))
	_end_turns_until(_rogue)
	assert_bool(_state.has_effect(_goblin(), Effect.HELPED)).is_true()
	_end_turns_until(_fighter)
	assert_bool(_state.has_effect(_goblin(), Effect.HELPED)).is_false()


func test_help_needs_an_enemy_within_5_feet() -> void:
	_fight(Vector2i(2, 3), Vector2i(0, 7), [Vector2i(5, 3)])
	assert_str(HelpAction.new(_fighter, _goblin()).validate(_state)).is_equal(Action.TARGET_OUT_OF_REACH)


func test_help_costs_the_action() -> void:
	_fight(Vector2i(4, 3), Vector2i(0, 7), [Vector2i(5, 3)])
	_state.action_used = true
	assert_str(HelpAction.new(_fighter, _goblin()).validate(_state)).is_equal(Action.ACTION_ALREADY_USED)


func test_cannot_distract_a_hidden_enemy() -> void:
	_fight(Vector2i(4, 3), Vector2i(0, 7), [Vector2i(5, 3)])
	_state.add_effect(Effect.new(Effect.HIDDEN, _goblin(), _goblin(), Effect.Expiry.UNTIL_REMOVED, 20))
	assert_str(HelpAction.new(_fighter, _goblin()).validate(_state)).is_equal(Action.NO_TARGET)


# --- Stabiliser un allié -----------------------------------------------------------------


func test_stabilizing_a_dying_ally() -> void:
	_fight(Vector2i(4, 3), Vector2i(4, 4), [Vector2i(10, 7)])
	_rogue.hp = 0
	_rogue.death_save_failures = 2
	# Médecine : 9 + 1 = 10 contre DD 10, réussi.
	var events := HelpAction.new(_fighter, _rogue).execute(_state, _dice([9]))
	var attempt := events[0] as StabilizeAttemptedEvent
	assert_int(attempt.total).is_equal(10)
	assert_bool(attempt.success).is_true()
	assert_bool(_rogue.is_stable).is_true()
	assert_bool(_rogue.is_dying()).is_false()
	assert_int(_rogue.death_save_failures).is_equal(0)
	assert_bool(_state.is_over).is_false()


func test_a_failed_medicine_check_leaves_the_ally_dying() -> void:
	_fight(Vector2i(4, 3), Vector2i(4, 4), [Vector2i(10, 7)])
	_rogue.hp = 0
	var events := HelpAction.new(_fighter, _rogue).execute(_state, _dice([8]))
	assert_bool((events[0] as StabilizeAttemptedEvent).success).is_false()
	assert_bool(_rogue.is_dying()).is_true()
	assert_bool(_state.action_used).is_true()


func test_only_a_dying_ally_can_be_stabilized() -> void:
	_fight(Vector2i(4, 3), Vector2i(4, 4), [Vector2i(10, 7)])
	assert_str(HelpAction.new(_fighter, _rogue).validate(_state)).is_equal(Action.NOT_DYING)
	_rogue.hp = 0
	_rogue.is_stable = true
	assert_str(HelpAction.new(_fighter, _rogue).validate(_state)).is_equal(Action.NOT_DYING)


func test_stabilizing_needs_to_be_within_5_feet() -> void:
	_fight(Vector2i(4, 3), Vector2i(6, 3), [Vector2i(10, 7)])
	_rogue.hp = 0
	assert_str(HelpAction.new(_fighter, _rogue).validate(_state)).is_equal(Action.TARGET_OUT_OF_REACH)


func test_halfling_luck_applies_to_the_medicine_check() -> void:
	_fight(Vector2i(4, 3), Vector2i(4, 4), [Vector2i(10, 7)])
	_end_turns_until(_rogue)
	_fighter.hp = 0
	var events := HelpAction.new(_rogue, _fighter).execute(_state, _dice([1, 12]))
	var attempt := events[0] as StabilizeAttemptedEvent
	assert_int(attempt.d20).is_equal(12)
	assert_bool(attempt.lucky).is_true()
	assert_bool(_fighter.is_stable).is_true()


# --- IA --------------------------------------------------------------------------------------


func test_ai_character_goes_to_stabilize_an_ally_one_failure_from_death() -> void:
	_fight(Vector2i(1, 3), Vector2i(4, 3), [Vector2i(11, 7)])
	_rogue.hp = 0
	_rogue.death_save_failures = 2
	var move := EnemyAI.next_action(_state, _fighter)
	assert_object(move).is_instanceof(MoveAction)
	move.execute(_state, _dice([]))
	assert_int(GridPathfinder.chebyshev(_fighter.position, _rogue.position)).is_equal(1)
	var help := EnemyAI.next_action(_state, _fighter)
	assert_object(help).is_instanceof(HelpAction)
	assert_object((help as HelpAction).target).is_same(_rogue)


func test_ai_keeps_fighting_while_the_dying_ally_is_not_in_danger() -> void:
	_fight(Vector2i(4, 4), Vector2i(4, 3), [Vector2i(5, 4)])
	_rogue.hp = 0
	_rogue.death_save_failures = 1
	assert_object(EnemyAI.next_action(_state, _fighter)).is_instanceof(AttackAction)


func test_medicine_is_a_wisdom_skill() -> void:
	assert_int(Fixtures.fighter().skill_bonus(CharacterDef.MEDICINE)).is_equal(1)
	assert_int(Fixtures.rogue().skill_bonus(CharacterDef.MEDICINE)).is_equal(1)


func test_help_round_trips_in_a_record() -> void:
	_fight(Vector2i(4, 3), Vector2i(0, 7), [Vector2i(5, 3)])
	var entry := CombatRecord.encode(HelpAction.new(_fighter, _goblin()))
	var decoded := CombatRecord.decode(JSON.parse_string(JSON.stringify(entry)), _fighter, _state) as HelpAction
	assert_object(decoded).is_not_null()
	assert_object(decoded.target).is_same(_goblin())

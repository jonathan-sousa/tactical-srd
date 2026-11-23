## Foncer, Se désengager, Esquiver, et la durée de leurs effets.
extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const Fixtures := preload("res://tests/helpers/fixtures.gd")

var _state: CombatState
var _fighter: Combatant
var _goblin: Combatant


## Grille 12×8, Guerrier en (3,3), Gobelin au contact en (4,3).
## Initiative : Guerrier 10 + 1, Gobelin 5 + 2 : le Guerrier commence.
func before_test() -> void:
	var cells: Array[Vector2i] = [Vector2i(4, 3)]
	_state = CombatState.create(Fixtures.encounter(Vector2i(12, 8), Vector2i(3, 3), cells), Fixtures.fighter())
	_state.start(FixedDice.new([10, 5]))
	_fighter = _state.combatants[0]
	_goblin = _state.combatants[1]


func _run(action: Action, dice: Dice = FixedDice.new([])) -> Array[CombatEvent]:
	assert_str(action.validate(_state)).is_empty()
	return action.execute(_state, dice)


func _has_event(events: Array[CombatEvent], script: Script) -> bool:
	return events.any(func(event: CombatEvent) -> bool: return event.get_script() == script)


func test_dash_doubles_movement_and_uses_the_action() -> void:
	var events := _run(StandardAction.new(_fighter, StandardAction.DASH))
	assert_int(_state.movement_left).is_equal(12)
	assert_bool(_state.action_used).is_true()
	assert_object((events[0] as ActionTakenEvent).combatant).is_same(_fighter)
	assert_str(AttackAction.new(_fighter, _goblin).validate(_state)).is_equal(Action.ACTION_ALREADY_USED)


func test_dash_after_moving_adds_full_speed() -> void:
	# Gobelin écarté pour que s'éloigner ne provoque pas d'attaque d'opportunité.
	_goblin.position = Vector2i(10, 7)
	_run(MoveAction.new(_fighter, Vector2i(3, 0)))
	assert_int(_state.movement_left).is_equal(3)
	_run(StandardAction.new(_fighter, StandardAction.DASH))
	assert_int(_state.movement_left).is_equal(9)


func test_only_one_action_per_turn() -> void:
	_run(StandardAction.new(_fighter, StandardAction.DODGE))
	for kind: StringName in StandardAction.ALL:
		assert_str(StandardAction.new(_fighter, kind).validate(_state)).is_equal(Action.ACTION_ALREADY_USED)


func test_dodge_gives_disadvantage_until_the_dodger_next_turn() -> void:
	_run(StandardAction.new(_fighter, StandardAction.DODGE))
	assert_bool(_state.has_effect(_fighter, Effect.DODGING)).is_true()
	_run(EndTurnAction.new(_fighter))

	# Désavantage : 18 et 3, on garde 3. 3 + 4 = 7 contre CA 16, raté.
	var events := _run(AttackAction.new(_goblin, _fighter), FixedDice.new([18, 3]))
	var result := (events[0] as AttackRolledEvent).result
	assert_int(result.d20.mode).is_equal(Dice.RollMode.DISADVANTAGE)
	assert_int(result.d20.natural).is_equal(3)
	assert_array(result.advantage.disadvantages).contains([AdvantageResolver.TARGET_DODGING])

	# L'esquive prend fin au début du tour suivant du Guerrier.
	var next_turn := _run(EndTurnAction.new(_goblin))
	assert_bool(_state.has_effect(_fighter, Effect.DODGING)).is_false()
	assert_bool(_has_event(next_turn, EffectEndedEvent)).is_true()


func test_dodge_does_not_help_against_an_unseen_attacker() -> void:
	var cells: Array[Vector2i] = [Vector2i(2, 0)]
	var blocked: Array[Vector2i] = [Vector2i(1, 0)]
	var state := CombatState.create(Fixtures.encounter(Vector2i(12, 8), Vector2i(0, 0), cells, blocked), Fixtures.fighter())
	var fighter := state.combatants[0]
	state.add_effect(Effect.new(Effect.DODGING, fighter, fighter, Effect.Expiry.START_OF_SOURCE_TURN))
	var advantage := AdvantageResolver.for_attack(state, state.combatants[1], fighter, Fixtures.scimitar())
	assert_int(advantage.mode).is_equal(Dice.RollMode.NORMAL)


func test_disengage_ends_with_the_turn() -> void:
	_run(StandardAction.new(_fighter, StandardAction.DISENGAGE))
	assert_bool(_state.has_effect(_fighter, Effect.DISENGAGED)).is_true()
	var events := _run(EndTurnAction.new(_fighter))
	assert_bool(_state.has_effect(_fighter, Effect.DISENGAGED)).is_false()
	# L'effet se termine avant que le tour suivant commence.
	assert_object(events[0]).is_instanceof(EffectEndedEvent)
	assert_object(events[1]).is_instanceof(TurnStartedEvent)


func test_effects_of_others_do_not_expire_on_my_turn() -> void:
	_run(StandardAction.new(_fighter, StandardAction.DODGE))
	_run(EndTurnAction.new(_fighter))
	assert_bool(_state.has_effect(_fighter, Effect.DODGING)).is_true()


func test_advantage_and_disadvantage_cancel_out() -> void:
	assert_int(AdvantageResolver.combine(0, 0)).is_equal(Dice.RollMode.NORMAL)
	assert_int(AdvantageResolver.combine(1, 0)).is_equal(Dice.RollMode.ADVANTAGE)
	assert_int(AdvantageResolver.combine(3, 0)).is_equal(Dice.RollMode.ADVANTAGE)
	assert_int(AdvantageResolver.combine(0, 2)).is_equal(Dice.RollMode.DISADVANTAGE)
	assert_int(AdvantageResolver.combine(1, 1)).is_equal(Dice.RollMode.NORMAL)
	# Un seul avantage annule plusieurs désavantages (SRD).
	assert_int(AdvantageResolver.combine(1, 3)).is_equal(Dice.RollMode.NORMAL)

## Attaques d'opportunité : quitter l'allonge d'un ennemi suspend le
## déplacement et ouvre une fenêtre de réaction.
extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const Fixtures := preload("res://tests/helpers/fixtures.gd")

var _state: CombatState
var _fighter: Combatant
var _goblin: Combatant


## Grille 12×8, Guerrier en (3,3), Gobelin au contact en (4,3).
## Initiative : Guerrier 1 + 1, Gobelin 20 + 2 : le Gobelin commence.
func before_test() -> void:
	var cells: Array[Vector2i] = [Vector2i(4, 3)]
	_state = CombatState.create(Fixtures.encounter(Vector2i(12, 8), Vector2i(3, 3), cells), Fixtures.fighter())
	_state.start(FixedDice.new([1, 20]))
	_fighter = _state.combatants[0]
	_goblin = _state.combatants[1]


func _run(action: Action, dice: Dice = FixedDice.new([])) -> Array[CombatEvent]:
	assert_str(action.validate(_state)).is_empty()
	return action.execute(_state, dice)


func _goblin_walks_away() -> Array[CombatEvent]:
	return _run(MoveAction.new(_goblin, Vector2i(6, 3)))


func test_leaving_reach_suspends_the_move() -> void:
	var events := _goblin_walks_away()
	assert_int(events.size()).is_equal(1)
	var triggered := events[0] as ReactionTriggeredEvent
	assert_object(triggered.reactor).is_same(_fighter)
	assert_object(triggered.mover).is_same(_goblin)
	# Le Gobelin n'a pas encore bougé ni dépensé de déplacement.
	assert_that(_goblin.position).is_equal(Vector2i(4, 3))
	assert_int(_state.movement_left).is_equal(6)
	assert_object(_state.pending.decider).is_same(_fighter)


func test_only_the_reactor_can_act_while_the_window_is_open() -> void:
	_goblin_walks_away()
	assert_str(EndTurnAction.new(_goblin).validate(_state)).is_equal(Action.DECISION_PENDING)
	assert_str(MoveAction.new(_goblin, Vector2i(5, 5)).validate(_state)).is_equal(Action.DECISION_PENDING)
	assert_str(OpportunityAttackAction.new(_goblin).validate(_state)).is_equal(Action.NOT_YOUR_DECISION)
	assert_str(OpportunityAttackAction.new(_fighter).validate(_state)).is_empty()
	assert_str(DeclineReactionAction.new(_fighter).validate(_state)).is_empty()


func test_no_reaction_without_a_window() -> void:
	assert_str(OpportunityAttackAction.new(_fighter).validate(_state)).is_equal(Action.NO_DECISION_PENDING)
	assert_str(DeclineReactionAction.new(_fighter).validate(_state)).is_equal(Action.NO_DECISION_PENDING)


func test_opportunity_attack_hits_then_the_move_resumes() -> void:
	_goblin_walks_away()
	# 15 + 5 = 20 contre CA 15 : touché. 2d6+3 avec 1 et 1 : 5 dégâts.
	var events := _run(OpportunityAttackAction.new(_fighter), FixedDice.new([15, 1, 1]))
	var result := (events[0] as AttackRolledEvent).result
	assert_bool(result.is_opportunity).is_true()
	assert_bool(result.is_hit).is_true()
	assert_int(_goblin.hp).is_equal(5)
	assert_object(events.back()).is_instanceof(MovedEvent)
	assert_that(_goblin.position).is_equal(Vector2i(6, 3))
	assert_int(_state.movement_left).is_equal(4)
	assert_bool(_fighter.reaction_available).is_false()
	assert_object(_state.pending).is_null()


func test_declining_keeps_the_reaction_and_resumes_the_move() -> void:
	_goblin_walks_away()
	var events := _run(DeclineReactionAction.new(_fighter))
	assert_object(events[0]).is_instanceof(ReactionDeclinedEvent)
	assert_that(_goblin.position).is_equal(Vector2i(6, 3))
	assert_bool(_fighter.reaction_available).is_true()
	assert_object(_state.pending).is_null()


func test_opportunity_attack_can_end_the_combat() -> void:
	_goblin_walks_away()
	# 20 naturel : 4d6+3 avec quatre 6 = 27 dégâts.
	_run(OpportunityAttackAction.new(_fighter), FixedDice.new([20, 6, 6, 6, 6]))
	assert_bool(_state.is_over).is_true()
	assert_int(_state.winner).is_equal(Combatant.Side.PLAYER)
	assert_that(_goblin.position).is_equal(Vector2i(4, 3))


func test_disengaged_mover_provokes_nothing() -> void:
	_run(StandardAction.new(_goblin, StandardAction.DISENGAGE))
	var events := _goblin_walks_away()
	assert_object(events[0]).is_instanceof(MovedEvent)
	assert_object(_state.pending).is_null()
	assert_that(_goblin.position).is_equal(Vector2i(6, 3))


func test_moving_within_reach_provokes_nothing() -> void:
	var events := _run(MoveAction.new(_goblin, Vector2i(4, 4)))
	assert_object(events[0]).is_instanceof(MovedEvent)
	assert_object(_state.pending).is_null()


func test_no_opportunity_attack_once_the_reaction_is_spent() -> void:
	_fighter.reaction_available = false
	_goblin_walks_away()
	assert_object(_state.pending).is_null()
	assert_that(_goblin.position).is_equal(Vector2i(6, 3))


func test_reaction_comes_back_at_the_start_of_the_reactor_turn() -> void:
	_goblin_walks_away()
	_run(OpportunityAttackAction.new(_fighter), FixedDice.new([2]))
	assert_bool(_fighter.reaction_available).is_false()
	_run(EndTurnAction.new(_goblin))
	assert_object(_state.active()).is_same(_fighter)
	assert_bool(_fighter.reaction_available).is_true()


func test_entering_reach_is_free_but_leaving_it_triggers() -> void:
	# Tous les plus courts chemins de (3,1) à (0,3) longent le Guerrier en
	# (1,1) : le Gobelin entre dans son allonge sans rien provoquer, puis
	# s'arrête juste avant d'en sortir.
	_fighter.position = Vector2i(1, 1)
	_goblin.position = Vector2i(3, 1)
	var events := _run(MoveAction.new(_goblin, Vector2i(0, 3)))
	assert_object(events[0]).is_instanceof(MovedEvent)
	assert_object(events.back()).is_instanceof(ReactionTriggeredEvent)
	assert_int(GridPathfinder.chebyshev(_goblin.position, _fighter.position)).is_equal(1)


func test_enemy_ai_takes_the_opportunity() -> void:
	_run(EndTurnAction.new(_goblin))
	_run(MoveAction.new(_fighter, Vector2i(1, 3)))
	var reaction := EnemyAI.decide(_state)
	assert_object(reaction).is_instanceof(OpportunityAttackAction)
	assert_object(reaction.actor).is_same(_goblin)
	assert_str(reaction.validate(_state)).is_empty()

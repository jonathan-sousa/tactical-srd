## Terrain difficile en combat (SRD « Difficult Terrain ») : chaque case
## coûte une case de plus. Et la case d'une créature qu'on peut traverser
## sans être son allié (SRD « Moving Around Other Creatures » : une créature
## Incapacitated) est un terrain difficile.
extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const Fixtures := preload("res://tests/helpers/fixtures.gd")


## Guerrier en (0, 0), Gobelin loin en (11, 7), broussailles en `difficult`.
## Le Guerrier commence (initiative 20 contre 1).
func _state(difficult: Array[Vector2i], grid := Vector2i(12, 8), enemy_cell := Vector2i(11, 7)) -> CombatState:
	var cells: Array[Vector2i] = [enemy_cell]
	var encounter := Fixtures.encounter(grid, Vector2i(0, 0), cells)
	encounter.difficult_cells = difficult
	var state := CombatState.create(encounter, Fixtures.fighter())
	state.start(FixedDice.new([20, 1]))
	return state


func _run(state: CombatState, action: Action, dice: Dice = FixedDice.new([])) -> Array[CombatEvent]:
	assert_str(action.validate(state)).is_empty()
	return action.execute(state, dice)


func test_moving_through_difficult_terrain_spends_double() -> void:
	# Corridor (1, 0)-(2, 0) en broussailles, sur une rangée.
	var difficult: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0)]
	var state := _state(difficult, Vector2i(12, 1), Vector2i(11, 0))
	var fighter := state.combatants[0]
	_run(state, MoveAction.new(fighter, Vector2i(3, 0)))
	assert_that(fighter.position).is_equal(Vector2i(3, 0))
	# 2 + 2 + 1 = 5 cases sur 6.
	assert_int(state.movement_left).is_equal(1)


func test_cannot_move_beyond_what_difficult_terrain_allows() -> void:
	var difficult: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0)]
	var state := _state(difficult, Vector2i(12, 1), Vector2i(11, 0))
	var fighter := state.combatants[0]
	# (5, 0) coûterait 7 cases.
	assert_str(MoveAction.new(fighter, Vector2i(5, 0)).validate(state)).is_equal(Action.NOT_ENOUGH_MOVEMENT)
	assert_str(MoveAction.new(fighter, Vector2i(4, 0)).validate(state)).is_empty()
	var reachable := state.reachable_cells()
	assert_int(reachable[Vector2i(4, 0)]).is_equal(6)
	assert_bool(reachable.has(Vector2i(5, 0))).is_false()


func test_path_cost_is_reported_by_the_state() -> void:
	var difficult: Array[Vector2i] = [Vector2i(1, 0)]
	var state := _state(difficult, Vector2i(12, 1), Vector2i(11, 0))
	var fighter := state.combatants[0]
	var path := state.find_path(fighter, Vector2i(2, 0))
	assert_int(state.path_cost(fighter, path)).is_equal(3)
	assert_bool(state.is_difficult_terrain(Vector2i(1, 0))).is_true()


func test_dash_then_difficult_terrain() -> void:
	var difficult: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)]
	var state := _state(difficult, Vector2i(12, 1), Vector2i(11, 0))
	var fighter := state.combatants[0]
	_run(state, StandardAction.new(fighter, StandardAction.DASH))
	# 12 cases : 5 broussailles (10) puis 2 cases d'herbe.
	_run(state, MoveAction.new(fighter, Vector2i(7, 0)))
	assert_int(state.movement_left).is_equal(0)


func test_leaving_reach_from_difficult_terrain_still_provokes() -> void:
	# Le Guerrier, en broussailles au contact du Gobelin, s'éloigne : attaque
	# d'opportunité, puis le déplacement reprend au bon prix.
	var difficult: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0)]
	var state := _state(difficult, Vector2i(12, 1), Vector2i(3, 0))
	var fighter := state.combatants[0]
	var goblin := state.combatants[1]
	fighter.position = Vector2i(2, 0)
	var events := _run(state, MoveAction.new(fighter, Vector2i(0, 0)))
	assert_object((events.back() as ReactionTriggeredEvent).reactor).is_same(goblin)
	_run(state, DeclineReactionAction.new(goblin))
	assert_that(fighter.position).is_equal(Vector2i(0, 0))
	# (1, 0) en broussailles : 2, puis (0, 0) : 1.
	assert_int(state.movement_left).is_equal(3)


# --- Créature neutralisée ---------------------------------------------------


## Guerrier inconscient en (1, 0), Gobelin en (0, 0) : un couloir d'une case.
func _downed_fighter_in_corridor() -> CombatState:
	var cells: Array[Vector2i] = [Vector2i(0, 0)]
	var state := CombatState.create(Fixtures.encounter(Vector2i(6, 1), Vector2i(1, 0), cells), Fixtures.fighter())
	# Le Gobelin commence.
	state.start(FixedDice.new([1, 20]))
	state.combatants[0].hp = 0
	return state


func test_an_enemy_crosses_an_incapacitated_creature_as_difficult_terrain() -> void:
	var state := _downed_fighter_in_corridor()
	var goblin := state.combatants[1]
	var path := state.find_path(goblin, Vector2i(2, 0))
	assert_array(path).contains_exactly([Vector2i(1, 0), Vector2i(2, 0)])
	assert_int(state.path_cost(goblin, path)).is_equal(3)
	_run(state, MoveAction.new(goblin, Vector2i(2, 0)))
	assert_that(goblin.position).is_equal(Vector2i(2, 0))
	assert_int(state.movement_left).is_equal(3)


func test_cannot_end_a_move_on_an_incapacitated_creature() -> void:
	var state := _downed_fighter_in_corridor()
	var goblin := state.combatants[1]
	assert_str(MoveAction.new(goblin, Vector2i(1, 0)).validate(state)).is_equal(Action.CELL_UNREACHABLE)
	assert_bool(state.reachable_cells().has(Vector2i(1, 0))).is_false()


func test_a_conscious_enemy_still_blocks_the_way() -> void:
	var state := _downed_fighter_in_corridor()
	state.combatants[0].hp = 5
	assert_array(state.find_path(state.combatants[1], Vector2i(2, 0))).is_empty()


func test_an_ally_space_is_not_difficult_terrain() -> void:
	# SRD : « Another creature's space is Difficult Terrain for you unless
	# that creature is Tiny or your ally. »
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	var state := CombatState.create(Fixtures.encounter(Vector2i(6, 1), Vector2i(5, 0), cells), Fixtures.fighter())
	state.start(FixedDice.new([1, 20, 19]))
	var back_goblin := state.combatants[1]
	var path := state.find_path(back_goblin, Vector2i(2, 0))
	assert_int(state.path_cost(back_goblin, path)).is_equal(2)


# --- IA ------------------------------------------------------------------------


func test_enemy_ai_stops_where_its_movement_runs_out() -> void:
	# Le Gobelin approche à travers une bande de broussailles : il ne va pas
	# plus loin que ses 6 cases ne le permettent.
	var difficult: Array[Vector2i] = [Vector2i(9, 0), Vector2i(8, 0), Vector2i(7, 0)]
	var cells: Array[Vector2i] = [Vector2i(10, 0)]
	var encounter := Fixtures.encounter(Vector2i(11, 1), Vector2i(0, 0), cells)
	encounter.difficult_cells = difficult
	var state := CombatState.create(encounter, Fixtures.fighter())
	state.start(FixedDice.new([1, 20]))
	var goblin := state.combatants[1]
	var action := EnemyAI.next_action(state, goblin)
	assert_object(action).is_instanceof(MoveAction)
	var move := action as MoveAction
	assert_str(move.validate(state)).is_empty()
	# 3 broussailles (6 cases) : il s'arrête en (7, 0).
	assert_that(move.destination).is_equal(Vector2i(7, 0))

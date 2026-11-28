## Ce que le moteur sait dire du plateau, pour les aides de l'interface :
## zones de menace (attaques d'opportunité), cases pour se cacher, cases qui
## donnent un abri, et description d'une case.
extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const Fixtures := preload("res://tests/helpers/fixtures.gd")


## Guerrier en (0, 0), Gobelin en `goblin_cell`. Le Guerrier commence.
func _state(goblin_cell: Vector2i, blocked: Array[Vector2i] = [], low_walls: Array[Vector2i] = [], difficult: Array[Vector2i] = []) -> CombatState:
	var cells: Array[Vector2i] = [goblin_cell]
	var encounter := Fixtures.encounter(Vector2i(12, 8), Vector2i(0, 0), cells, blocked)
	encounter.low_walls = low_walls
	encounter.difficult_cells = difficult
	var state := CombatState.create(encounter, Fixtures.fighter())
	state.start(FixedDice.new([20, 1]))
	return state


# --- Zones de menace ----------------------------------------------------------


func test_threat_cells_are_the_reach_of_each_enemy() -> void:
	var state := _state(Vector2i(5, 3))
	var threats := state.threat_cells(state.combatants[0])
	assert_int(threats.size()).is_equal(8)
	assert_bool(threats.has(Vector2i(4, 2))).is_true()
	assert_bool(threats.has(Vector2i(6, 4))).is_true()
	assert_bool(threats.has(Vector2i(5, 3))).is_false()
	assert_bool(threats.has(Vector2i(3, 3))).is_false()
	assert_array(threats[Vector2i(4, 2)]).contains_exactly([state.combatants[1]])


func test_scenery_cells_are_not_threatened() -> void:
	var blocked: Array[Vector2i] = [Vector2i(4, 3)]
	var state := _state(Vector2i(5, 3), blocked)
	assert_bool(state.threat_cells(state.combatants[0]).has(Vector2i(4, 3))).is_false()


func test_no_threat_from_an_enemy_without_its_reaction() -> void:
	var state := _state(Vector2i(5, 3))
	state.combatants[1].reaction_available = false
	assert_bool(state.threat_cells(state.combatants[0]).is_empty()).is_true()


func test_no_threat_from_a_downed_enemy() -> void:
	var state := _state(Vector2i(5, 3))
	state.combatants[1].hp = 0
	assert_bool(state.threat_cells(state.combatants[0]).is_empty()).is_true()


func test_no_threat_once_disengaged() -> void:
	var state := _state(Vector2i(5, 3))
	var fighter := state.combatants[0]
	StandardAction.new(fighter, StandardAction.DISENGAGE).execute(state, FixedDice.new([]))
	assert_bool(state.threat_cells(fighter).is_empty()).is_true()


func test_no_threat_from_an_enemy_one_is_hidden_from() -> void:
	var state := _state(Vector2i(5, 3))
	var fighter := state.combatants[0]
	state.add_effect(Effect.new(Effect.HIDDEN, fighter, fighter, Effect.Expiry.UNTIL_REMOVED, 15))
	assert_bool(state.threat_cells(fighter).is_empty()).is_true()


func test_threat_cells_agree_with_opportunity_attacks() -> void:
	# Quitter une case menacée vers une case qui ne l'est pas provoque.
	var state := _state(Vector2i(5, 3))
	var fighter := state.combatants[0]
	fighter.position = Vector2i(4, 3)
	assert_bool(state.threat_cells(fighter).has(fighter.position)).is_true()
	var path: Array[Vector2i] = [Vector2i(3, 3)]
	assert_array(state.opportunity_attackers(fighter, path)).contains_exactly([state.combatants[1]])


# --- Cases pour se cacher ------------------------------------------------------


func test_hiding_cells_are_out_of_sight_of_every_enemy() -> void:
	# Un rideau d'arbres en x = 5 cache (4, 3) et (3, 3) du Gobelin en (10, 3).
	var blocked: Array[Vector2i] = [Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 4)]
	var state := _state(Vector2i(10, 3), blocked)
	var cells := state.hiding_cells(state.combatants[0])
	assert_bool(cells.has(Vector2i(4, 3))).is_true()
	assert_bool(cells.has(Vector2i(3, 3))).is_true()
	assert_bool(cells.has(Vector2i(8, 3))).is_false()
	# Ni le décor, ni la case du Gobelin.
	assert_bool(cells.has(Vector2i(5, 3))).is_false()
	assert_bool(cells.has(Vector2i(10, 3))).is_false()


func test_hiding_cells_agree_with_can_hide() -> void:
	var blocked: Array[Vector2i] = [Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 4)]
	var state := _state(Vector2i(10, 3), blocked)
	var fighter := state.combatants[0]
	fighter.position = Vector2i(4, 3)
	assert_bool(state.hiding_cells(fighter).has(fighter.position)).is_true()
	assert_bool(state.can_hide(fighter)).is_true()


func test_a_downed_enemy_sees_nothing() -> void:
	var state := _state(Vector2i(10, 3))
	state.combatants[1].hp = 0
	assert_bool(state.hiding_cells(state.combatants[0]).has(Vector2i(8, 3))).is_true()


# --- Abri ---------------------------------------------------------------------------


func test_cover_cells_name_the_low_wall_in_the_way() -> void:
	var walls: Array[Vector2i] = [Vector2i(3, 0)]
	var state := _state(Vector2i(6, 0), [], walls)
	var fighter := state.combatants[0]
	var goblin := state.combatants[1]
	assert_array(state.cover_cells(fighter, goblin)).contains_exactly([Vector2i(3, 0)])
	assert_int(state.cover_bonus(fighter, goblin)).is_equal(CombatState.HALF_COVER_BONUS)
	assert_array(AttackEstimate.of(state, fighter, goblin, fighter.definition.weapons[0]).cover_cells).contains_exactly([Vector2i(3, 0)])


func test_a_creature_in_the_way_gives_cover_too() -> void:
	var cells: Array[Vector2i] = [Vector2i(6, 0), Vector2i(3, 0)]
	var state := CombatState.create(Fixtures.encounter(Vector2i(12, 8), Vector2i(0, 0), cells), Fixtures.fighter())
	state.start(FixedDice.new([20, 1, 1]))
	assert_array(state.cover_cells(state.combatants[0], state.combatants[1])).contains_exactly([Vector2i(3, 0)])


func test_no_cover_cells_in_the_open() -> void:
	var state := _state(Vector2i(6, 0))
	assert_array(state.cover_cells(state.combatants[0], state.combatants[1])).is_empty()
	assert_int(state.cover_bonus(state.combatants[0], state.combatants[1])).is_equal(0)


# --- Description d'une case ------------------------------------------------------


func test_cell_info_terrain() -> void:
	var blocked: Array[Vector2i] = [Vector2i(2, 2)]
	var walls: Array[Vector2i] = [Vector2i(3, 2)]
	var difficult: Array[Vector2i] = [Vector2i(4, 2)]
	var state := _state(Vector2i(10, 7), blocked, walls, difficult)
	var fighter := state.combatants[0]

	var tree := CellInfo.of(state, Vector2i(2, 2), fighter)
	assert_int(tree.terrain).is_equal(CellInfo.Terrain.OBSTACLE)
	assert_bool(tree.blocks_movement).is_true()
	assert_bool(tree.blocks_sight).is_true()

	var wall := CellInfo.of(state, Vector2i(3, 2), fighter)
	assert_int(wall.terrain).is_equal(CellInfo.Terrain.LOW_WALL)
	assert_bool(wall.blocks_movement).is_true()
	assert_bool(wall.blocks_sight).is_false()
	assert_int(wall.cover_bonus).is_equal(CombatState.HALF_COVER_BONUS)

	var brush := CellInfo.of(state, Vector2i(4, 2), fighter)
	assert_int(brush.terrain).is_equal(CellInfo.Terrain.DIFFICULT)
	assert_int(brush.movement_cost).is_equal(2)
	assert_bool(brush.blocks_movement).is_false()

	var grass := CellInfo.of(state, Vector2i(5, 2), fighter)
	assert_int(grass.terrain).is_equal(CellInfo.Terrain.OPEN)
	assert_int(grass.movement_cost).is_equal(1)
	assert_bool(grass.has_rule()).is_false()
	assert_bool(brush.has_rule()).is_true()

	assert_int(CellInfo.of(state, Vector2i(20, 2), fighter).terrain).is_equal(CellInfo.Terrain.OUTSIDE)


func test_cell_info_occupant_as_seen_by_the_observer() -> void:
	var state := _state(Vector2i(5, 3))
	var fighter := state.combatants[0]
	var goblin := state.combatants[1]
	assert_object(CellInfo.of(state, Vector2i(5, 3), fighter).occupant).is_same(goblin)
	assert_object(CellInfo.of(state, Vector2i(6, 3), fighter).occupant).is_null()
	# Un ennemi caché n'apparaît pas : on ignore qu'il est là.
	state.add_effect(Effect.new(Effect.HIDDEN, goblin, goblin, Effect.Expiry.UNTIL_REMOVED, 15))
	assert_object(CellInfo.of(state, Vector2i(5, 3), fighter).occupant).is_null()
	# Un mort non plus : sa case est libre.
	state.remove_effect(goblin, Effect.HIDDEN)
	goblin.is_dead = true
	assert_object(CellInfo.of(state, Vector2i(5, 3), fighter).occupant).is_null()

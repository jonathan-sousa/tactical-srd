## Abri partiel (SRD « Cover ») : un muret ou une autre créature entre
## l'attaquant et la cible donne +2 à la CA. Un muret bloque le passage mais
## pas la vue ; il ne suffit pas pour se cacher.
extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const Fixtures := preload("res://tests/helpers/fixtures.gd")

var _state: CombatState
var _fighter: Combatant
var _goblin: Combatant


## Guerrier contre gobelins (le premier joue en premier), sur une grille
## avec des murets.
func _fight(fighter_cell: Vector2i, goblin_cells: Array[Vector2i], low_walls: Array[Vector2i] = [], blocked: Array[Vector2i] = [], goblin: CharacterDef = null) -> void:
	var encounter := Fixtures.encounter(Vector2i(12, 8), fighter_cell, goblin_cells, blocked, goblin if goblin != null else Fixtures.full_goblin())
	encounter.low_walls = low_walls
	_state = CombatState.create(encounter, Fixtures.full_fighter())
	var rolls: Array = [1, 20]
	for i in goblin_cells.size() - 1:
		rolls.append(1)
	_state.start(_dice(rolls))
	_fighter = _state.combatants[0]
	_goblin = _state.combatants[1]


func _dice(values: Array) -> Dice:
	var typed: Array[int] = []
	typed.assign(values)
	return FixedDice.new(typed)


# --- Qui donne un abri --------------------------------------------------------------


func test_no_cover_in_the_open() -> void:
	_fight(Vector2i(0, 3), [Vector2i(5, 3)])
	assert_int(_state.cover_bonus(_goblin, _fighter)).is_equal(0)


func test_a_low_wall_in_between_gives_half_cover() -> void:
	_fight(Vector2i(0, 3), [Vector2i(5, 3)], [Vector2i(2, 3)])
	assert_int(_state.cover_bonus(_goblin, _fighter)).is_equal(CombatState.HALF_COVER_BONUS)
	assert_int(_state.cover_bonus(_fighter, _goblin)).is_equal(2)


func test_another_creature_in_between_gives_half_cover() -> void:
	# Le deuxième gobelin couvre le Guerrier contre le premier, et le premier
	# contre le Guerrier : allié ou ennemi, une créature fait écran.
	_fight(Vector2i(0, 3), [Vector2i(6, 3), Vector2i(3, 3)])
	assert_int(_state.cover_bonus(_goblin, _fighter)).is_equal(2)
	assert_int(_state.cover_bonus(_fighter, _goblin)).is_equal(2)


func test_a_dead_creature_gives_no_cover() -> void:
	_fight(Vector2i(0, 3), [Vector2i(6, 3), Vector2i(3, 3)])
	_state.combatants[2].is_dead = true
	assert_int(_state.cover_bonus(_goblin, _fighter)).is_equal(0)


func test_a_creature_hidden_from_the_attacker_is_not_counted() -> void:
	# On ne sait pas qu'il est là : la prévision n'en dit rien.
	_fight(Vector2i(0, 3), [Vector2i(6, 3), Vector2i(3, 3)])
	var hidden := _state.combatants[2]
	_state.add_effect(Effect.new(Effect.HIDDEN, hidden, hidden, Effect.Expiry.UNTIL_REMOVED, 20))
	assert_bool(_state.is_hidden_from(hidden, _fighter)).is_true()
	assert_int(_state.cover_bonus(_fighter, _goblin)).is_equal(0)


func test_no_cover_against_an_adjacent_attacker() -> void:
	_fight(Vector2i(3, 3), [Vector2i(4, 4)], [Vector2i(4, 3), Vector2i(3, 4)])
	assert_int(_state.cover_bonus(_goblin, _fighter)).is_equal(0)


func test_a_line_grazing_a_low_wall_corner_gives_no_cover() -> void:
	_fight(Vector2i(0, 0), [Vector2i(4, 4)], [Vector2i(1, 0), Vector2i(0, 1)])
	assert_int(_state.cover_bonus(_goblin, _fighter)).is_equal(0)


# --- Le muret sur la carte -------------------------------------------------------------


func test_a_low_wall_blocks_movement() -> void:
	_fight(Vector2i(0, 3), [Vector2i(8, 3)], [Vector2i(1, 3)])
	var reachable := _state.reachable_from(_fighter, _fighter.position, 6)
	assert_bool(reachable.has(Vector2i(1, 3))).is_false()
	var path := _state.find_path(_fighter, Vector2i(2, 3))
	assert_bool(path.has(Vector2i(1, 3))).is_false()
	assert_array(path).is_not_empty()


func test_a_low_wall_does_not_block_sight_nor_allow_hiding() -> void:
	_fight(Vector2i(0, 3), [Vector2i(3, 3)], [Vector2i(2, 3)])
	assert_bool(_state.line_of_sight.is_clear(_fighter.position, _goblin.position)).is_true()
	assert_bool(_state.can_hide(_goblin)).is_false()


# --- L'abri dans l'attaque -----------------------------------------------------------------


func test_cover_raises_the_armor_class_of_the_attack() -> void:
	_fight(Vector2i(0, 3), [Vector2i(5, 3)], [Vector2i(2, 3)])
	var bow := _goblin.definition.weapons[1]
	# 13 + 4 = 17 : touche la CA 16 du Guerrier, pas 18 derrière le muret.
	var events := AttackAction.new(_goblin, _fighter, bow).execute(_state, _dice([13]))
	var result := (events[0] as AttackRolledEvent).result
	assert_int(result.cover_bonus).is_equal(2)
	assert_int(result.target_armor_class).is_equal(18)
	assert_bool(result.is_hit).is_false()
	assert_int(_fighter.hp).is_equal(_fighter.definition.max_hp)


func test_the_estimate_counts_cover() -> void:
	_fight(Vector2i(0, 3), [Vector2i(5, 3)])
	var bow := _goblin.definition.weapons[1]
	var open := AttackEstimate.of(_state, _goblin, _fighter, bow)
	_state.encounter.low_walls = [Vector2i(2, 3)]
	var covered := AttackEstimate.of(_state, _goblin, _fighter, bow)
	assert_int(open.cover_bonus).is_equal(0)
	assert_int(covered.cover_bonus).is_equal(2)
	# 4 + d20 contre 16 : 45 % ; contre 18 : 35 %.
	assert_float(open.hit_chance).is_equal_approx(0.45, 0.001)
	assert_float(covered.hit_chance).is_equal_approx(0.35, 0.001)


# --- IA -------------------------------------------------------------------------------------


func test_archer_prefers_a_firing_cell_behind_a_low_wall() -> void:
	# Le rocher en (7, 4) cache le gobelin : il doit bouger pour tirer. Les
	# cases (8, 3) et (8, 5) se valent, mais un muret couvre (8, 5).
	var rock: Array[Vector2i] = [Vector2i(7, 4)]
	_fight(Vector2i(1, 4), [Vector2i(8, 4)], [Vector2i(6, 5)], rock)
	var dice := _dice([10, 1, 1, 1, 1])
	var action := EnemyAI.next_action(_state, _goblin)
	if action is HideAction:
		action.execute(_state, dice)
		action = EnemyAI.next_action(_state, _goblin)
	assert_object(action).is_instanceof(MoveAction)
	assert_that((action as MoveAction).destination).is_equal(Vector2i(8, 5))

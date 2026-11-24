## Prévisions d'attaque (aides de survol) et attaques d'opportunité prévues
## sur un chemin.
extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const Fixtures := preload("res://tests/helpers/fixtures.gd")

var _state: CombatState
var _fighter: Combatant
var _goblin: Combatant


## Grille 12×3 : Guerrier complet en (0,1), Gobelin complet à la case
## donnée. Le Guerrier commence.
func _start(goblin_cell: Vector2i = Vector2i(1, 1)) -> void:
	var cells: Array[Vector2i] = [goblin_cell]
	_state = CombatState.create(Fixtures.encounter(Vector2i(12, 3), Vector2i(0, 1), cells, [], Fixtures.full_goblin()), Fixtures.full_fighter())
	_state.start(FixedDice.new([10, 5]))
	_fighter = _state.combatants[0]
	_goblin = _state.combatants[1]


func _weapon(combatant: Combatant, id: StringName) -> WeaponDef:
	for weapon in combatant.definition.weapons:
		if weapon.id == id:
			return weapon
	return null


func test_greatsword_against_ac_15() -> void:
	_start()
	var estimate := AttackEstimate.of(_state, _fighter, _goblin, _weapon(_fighter, &"greatsword"))
	# + 5 contre CA 15 : 10 à 20 touchent, 11 chances sur 20.
	assert_float(estimate.hit_chance).is_equal_approx(0.55, 0.0001)
	assert_float(estimate.critical_chance).is_equal_approx(0.05, 0.0001)
	# 2d6 + 3, Great Weapon Fighting : chaque dé vaut au moins 3.
	assert_int(estimate.damage_min).is_equal(9)
	assert_int(estimate.damage_max).is_equal(15)
	assert_int(estimate.graze_damage).is_equal(3)


func test_natural_1_and_20_bound_the_hit_chance() -> void:
	_start()
	_goblin.definition = Fixtures.full_goblin()
	_goblin.definition.armor_class = 40
	var hopeless := AttackEstimate.of(_state, _fighter, _goblin, _weapon(_fighter, &"greatsword"))
	assert_float(hopeless.hit_chance).is_equal_approx(0.05, 0.0001)
	_goblin.definition.armor_class = 1
	var certain := AttackEstimate.of(_state, _fighter, _goblin, _weapon(_fighter, &"greatsword"))
	assert_float(certain.hit_chance).is_equal_approx(0.95, 0.0001)


func test_disadvantage_squares_the_hit_chance() -> void:
	_start()
	_state.add_effect(Effect.new(Effect.DODGING, _goblin, _goblin, Effect.Expiry.START_OF_SOURCE_TURN))
	var estimate := AttackEstimate.of(_state, _fighter, _goblin, _weapon(_fighter, &"greatsword"))
	assert_int(estimate.advantage.mode).is_equal(Dice.RollMode.DISADVANTAGE)
	assert_float(estimate.hit_chance).is_equal_approx(0.55 * 0.55, 0.0001)


func test_goblin_with_advantage_adds_its_1d4() -> void:
	_start()
	_state.add_effect(Effect.new(Effect.PRONE, _fighter, _fighter, Effect.Expiry.UNTIL_REMOVED))
	var estimate := AttackEstimate.of(_state, _goblin, _fighter, _goblin.melee_weapon())
	# + 4 contre CA 16 : 12 à 20, 9 chances sur 20 ; avantage : 1 − 0,55².
	assert_float(estimate.hit_chance).is_equal_approx(1.0 - 0.55 * 0.55, 0.0001)
	# 1d6 + 2 et 1d4.
	assert_int(estimate.damage_min).is_equal(4)
	assert_int(estimate.damage_max).is_equal(12)
	assert_int(estimate.graze_damage).is_equal(0)


func test_unconscious_target_in_reach_is_always_a_critical() -> void:
	_start()
	HitPoints.apply_damage(_state, _fighter, 12, DamageType.Type.SLASHING)
	var estimate := AttackEstimate.of(_state, _goblin, _fighter, _goblin.melee_weapon())
	assert_float(estimate.critical_chance).is_equal_approx(estimate.hit_chance, 0.0001)
	# 2d6 + 2 et 2d4.
	assert_int(estimate.damage_min).is_equal(6)
	assert_int(estimate.damage_max).is_equal(22)


func test_thrown_javelin_has_no_great_weapon_fighting() -> void:
	_start(Vector2i(4, 1))
	var estimate := AttackEstimate.of(_state, _fighter, _goblin, _weapon(_fighter, &"javelin"))
	assert_int(estimate.damage_min).is_equal(4)
	assert_int(estimate.damage_max).is_equal(9)


func test_path_leaving_reach_lists_the_opportunity_attacker() -> void:
	_start()
	# Gobelin en (1,1), au contact : (0,0) et (0,2) restent dans son allonge.
	var stays: Array[Vector2i] = [Vector2i(0, 0)]
	assert_array(_state.opportunity_attackers(_fighter, stays)).is_empty()
	# Gobelin en (0,2) : le premier pas vers (1,0) sort de son allonge.
	_goblin.position = Vector2i(0, 2)
	var out: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0)]
	assert_array(_state.opportunity_attackers(_fighter, out)).contains_exactly([_goblin])


func test_disengaged_mover_provokes_nothing() -> void:
	_start()
	_goblin.position = Vector2i(0, 2)
	var out: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0)]
	_state.add_effect(Effect.new(Effect.DISENGAGED, _fighter, _fighter, Effect.Expiry.END_OF_SOURCE_TURN))
	assert_array(_state.opportunity_attackers(_fighter, out)).is_empty()


func test_hidden_mover_provokes_nothing() -> void:
	_start()
	_goblin.position = Vector2i(0, 2)
	var out: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0)]
	_state.add_effect(Effect.new(Effect.HIDDEN, _fighter, _fighter, Effect.Expiry.UNTIL_REMOVED, 15))
	assert_array(_state.opportunity_attackers(_fighter, out)).is_empty()

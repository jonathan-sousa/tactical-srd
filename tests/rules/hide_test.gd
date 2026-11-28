## Se cacher, chercher, attaquer à l'aveugle et embuscade (SRD 5.2.1 :
## « Hide », « Search », « Invisible », « Unseen Attackers and Targets »,
## « Surprise »).
##
## Règles de MJ retenues (docs/rules-deviations.md) : un caché est trouvé
## s'il finit son tour en vue d'un ennemi conscient, quand un ennemi finit
## son déplacement en vue de lui, quand une Perception passive suffisante le
## voit passer, ou quand on le heurte.
extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const Fixtures := preload("res://tests/helpers/fixtures.gd")

## Un mur en colonne x = 5 coupe la vue entre les deux moitiés de la grille.
const WALL: Array[Vector2i] = [Vector2i(5, 1), Vector2i(5, 2), Vector2i(5, 3)]

var _state: CombatState
var _fighter: Combatant
var _goblin: Combatant


## Grille 12×5 avec le mur : Guerrier en (1,2), Gobelin complet en (8,2),
## hors de vue. `goblin_first` : le Gobelin commence (5 + 1 contre 10 + 2).
func _start(goblin_first: bool = true, ambush: bool = false, initiative: Array = []) -> Array[CombatEvent]:
	var cells: Array[Vector2i] = [Vector2i(8, 2)]
	var encounter := Fixtures.encounter(Vector2i(12, 5), Vector2i(1, 2), cells, WALL, Fixtures.full_goblin())
	encounter.ambush = ambush
	_state = CombatState.create(encounter, Fixtures.full_fighter())
	var values: Array = initiative
	if values.is_empty():
		values = [5, 10] if goblin_first else [10, 5]
	var events := _state.start(_dice(values))
	_fighter = _state.combatants[0]
	_goblin = _state.combatants[1]
	return events


func _dice(values: Array) -> FixedDice:
	var typed: Array[int] = []
	typed.assign(values)
	return FixedDice.new(typed)


func _run(action: Action, values: Array = []) -> Array[CombatEvent]:
	assert_str(action.validate(_state)).is_empty()
	var dice := _dice(values)
	var events := action.execute(_state, dice)
	assert_int(dice.remaining()).override_failure_message("Dés non consommés").is_equal(0)
	return events


## Le Gobelin se cache par Nimble Escape avec ce d20 (Discrétion +6).
func _goblin_hides(d20: int) -> void:
	_run(HideAction.new(_goblin, true), [d20])


func _end_turn() -> void:
	_run(EndTurnAction.new(_state.active()))


# --- Se cacher ----------------------------------------------------------------------


func test_hide_succeeds_against_dc_15_and_its_total_becomes_the_dc() -> void:
	_start()
	var events := _run(HideAction.new(_goblin), [9])
	var attempt := events[0] as HideAttemptedEvent
	assert_bool(attempt.success).is_true()
	assert_int(attempt.total).is_equal(15)
	assert_bool(_state.is_hidden(_goblin)).is_true()
	assert_int(_state.hide_dc(_goblin)).is_equal(15)
	assert_bool(_state.action_used).is_true()


func test_hide_fails_below_dc_15() -> void:
	_start()
	var events := _run(HideAction.new(_goblin), [8])
	assert_bool((events[0] as HideAttemptedEvent).success).is_false()
	assert_bool(_state.is_hidden(_goblin)).is_false()


func test_hide_requires_being_out_of_every_enemy_sight() -> void:
	_start()
	_fighter.position = Vector2i(8, 0)
	assert_str(HideAction.new(_goblin).validate(_state)).is_equal(Action.SEEN_BY_ENEMY)


func test_nimble_escape_hides_with_the_bonus_action() -> void:
	_start()
	_goblin_hides(12)
	assert_bool(_state.bonus_action_used).is_true()
	assert_bool(_state.action_used).is_false()
	assert_str(HideAction.new(_goblin, true).validate(_state)).is_equal(Action.BONUS_ACTION_ALREADY_USED)


func test_bonus_action_hide_needs_nimble_escape() -> void:
	_start(false)
	_fighter.position = Vector2i(10, 0)
	assert_str(HideAction.new(_fighter, true).validate(_state)).is_equal(Action.FEATURE_UNAVAILABLE)


func test_cannot_hide_twice() -> void:
	_start()
	_goblin_hides(12)
	assert_str(HideAction.new(_goblin).validate(_state)).is_equal(Action.ALREADY_HIDDEN)


# --- Caché, donc invisible ----------------------------------------------------------


func test_passive_perception_is_10_plus_the_perception_bonus() -> void:
	_start()
	# Guerrier : Perception +3 ; Gobelin : Sagesse 8, soit -1.
	assert_int(_state.passive_perception(_fighter)).is_equal(13)
	assert_int(_state.passive_perception(_goblin)).is_equal(9)


func test_hidden_goblin_ending_its_turn_in_plain_sight_is_found() -> void:
	_start()
	_goblin_hides(12)
	# Il sort de derrière le mur, en pleine vue : son déplacement n'est pas
	# vu, et il reste caché tant que son tour dure.
	var events := _run(MoveAction.new(_goblin, Vector2i(5, 4)))
	assert_int(events.size()).is_equal(1)
	assert_bool((events[0] as MovedEvent).unseen).is_true()
	assert_bool(_state.line_of_sight.is_clear(_fighter.position, _goblin.position)).is_true()
	assert_bool(_state.is_hidden(_goblin)).is_true()
	# Il finit son tour en vue du Guerrier : trouvé.
	events = _run(EndTurnAction.new(_goblin))
	var revealed := events[0] as RevealedEvent
	assert_str(revealed.reason).is_equal(RevealedEvent.SEEN)
	assert_object(revealed.observer).is_same(_fighter)
	assert_that(revealed.cell).is_equal(Vector2i(5, 4))
	assert_bool(_state.can_see(_fighter, _goblin)).is_true()


func test_hidden_goblin_back_out_of_sight_before_the_end_of_its_turn_stays_hidden() -> void:
	_start()
	_goblin_hides(12)
	_run(MoveAction.new(_goblin, Vector2i(5, 4)))
	_run(MoveAction.new(_goblin, Vector2i(6, 3)))
	_end_turn()
	assert_bool(_state.is_hidden(_goblin)).is_true()


func test_hidden_goblin_steps_out_and_shoots_with_advantage() -> void:
	_start()
	_goblin_hides(12)
	_run(MoveAction.new(_goblin, Vector2i(5, 4)))
	var bow: WeaponDef = _goblin.definition.weapons[1]
	# Avantage : 15 et 3, on garde 15 ; 15 + 4 = 19 contre CA 16. 1d6 + 2
	# et 1d4 (avantage) : 3 + 2 + 2 = 7.
	var events := _run(AttackAction.new(_goblin, _fighter, bow), [15, 3, 3, 2])
	assert_str((events[0] as RevealedEvent).reason).is_equal(RevealedEvent.ATTACKED)
	var result := (events[1] as AttackRolledEvent).result
	assert_array(result.advantage.advantages).contains([AdvantageResolver.ATTACKER_HIDDEN])
	assert_int(_fighter.hp).is_equal(5)


func test_fighter_walking_around_the_wall_finds_the_hidden_goblin() -> void:
	_start()
	_goblin_hides(12)
	_end_turn()
	assert_bool(_state.is_hidden(_goblin)).is_true()
	var events := _run(MoveAction.new(_fighter, Vector2i(6, 4)))
	assert_object(events[0]).is_instanceof(MovedEvent)
	var revealed := events[1] as RevealedEvent
	assert_str(revealed.reason).is_equal(RevealedEvent.SEEN)
	assert_object(revealed.observer).is_same(_fighter)
	assert_that(revealed.cell).is_equal(Vector2i(8, 2))
	assert_bool(_state.is_hidden(_goblin)).is_false()


func test_fighter_moving_without_a_view_on_the_goblin_finds_nothing() -> void:
	_start()
	_goblin_hides(12)
	_end_turn()
	var events := _run(MoveAction.new(_fighter, Vector2i(3, 2)))
	assert_int(events.size()).is_equal(1)
	assert_bool(_state.is_hidden(_goblin)).is_true()


## Le Guerrier a une Perception passive de 20 : il remarque le Gobelin
## (Discrétion 15) dès la première case en vue de son trajet.
func test_high_passive_perception_notices_the_hidden_mover_on_the_first_cell_in_view() -> void:
	_start()
	_fighter.definition.skill_bonuses[CharacterDef.PERCEPTION] = 10
	_goblin_hides(9)
	var path := _state.find_path(_goblin, Vector2i(4, 4))
	var first_in_view := -1
	for i in path.size():
		if _state.line_of_sight.is_clear(_fighter.position, path[i]):
			first_in_view = i
			break
	assert_int(first_in_view).is_between(0, path.size() - 2)

	var events := _run(MoveAction.new(_goblin, Vector2i(4, 4)))
	# Le début du trajet, jusqu'à la case où il est remarqué, n'est pas vu.
	var hidden_part := events[0] as MovedEvent
	assert_bool(hidden_part.unseen).is_true()
	assert_that(hidden_part.path.back()).is_equal(path[first_in_view])
	var revealed := events[1] as RevealedEvent
	assert_str(revealed.reason).is_equal(RevealedEvent.NOTICED)
	assert_object(revealed.observer).is_same(_fighter)
	assert_that(revealed.cell).is_equal(path[first_in_view])
	# La suite du trajet est vue.
	var rest := events[2] as MovedEvent
	assert_bool(rest.unseen).is_false()
	assert_that(rest.path.back()).is_equal(Vector2i(4, 4))


func test_passive_perception_below_the_stealth_total_notices_nothing() -> void:
	_start()
	# Perception passive 13 contre Discrétion 15.
	_goblin_hides(9)
	var events := _run(MoveAction.new(_goblin, Vector2i(4, 4)))
	assert_int(events.size()).is_equal(1)
	assert_bool(_state.is_hidden(_goblin)).is_true()


func test_walking_into_a_hidden_goblin_bumps_into_it() -> void:
	_start()
	_goblin_hides(12)
	_end_turn()
	# (Situation forcée : le Gobelin caché juste à côté du Guerrier.)
	_goblin.position = Vector2i(2, 2)
	# Sa case n'est pas exclue des chemins : le Guerrier ignore qu'il y est.
	assert_array(_state.find_path(_fighter, Vector2i(2, 2))).contains_exactly([Vector2i(2, 2)])
	var events := _run(MoveAction.new(_fighter, Vector2i(2, 2)))
	var revealed := events[0] as RevealedEvent
	assert_str(revealed.reason).is_equal(RevealedEvent.BUMPED)
	assert_object(revealed.observer).is_same(_fighter)
	assert_that(_fighter.position).is_equal(Vector2i(1, 2))
	assert_int(_state.movement_left).is_equal(6)
	assert_bool(_state.is_hidden(_goblin)).is_false()


func test_bumping_stops_the_move_on_the_previous_cell() -> void:
	_start()
	_goblin_hides(12)
	_end_turn()
	_goblin.position = Vector2i(3, 2)
	var path := _state.find_path(_fighter, Vector2i(3, 2))
	assert_int(path.size()).is_equal(2)
	var events := _run(MoveAction.new(_fighter, Vector2i(3, 2)))
	assert_object(events[0]).is_instanceof(MovedEvent)
	assert_str((events[1] as RevealedEvent).reason).is_equal(RevealedEvent.BUMPED)
	assert_that(_fighter.position).is_equal(path[0])
	assert_int(_state.movement_left).is_equal(5)


func test_fighter_waking_up_in_view_finds_the_hidden_goblin() -> void:
	_start()
	_goblin_hides(12)
	HitPoints.apply_damage(_state, _fighter, _fighter.hp, DamageType.Type.SLASHING)
	# Le Guerrier est inconscient : le Gobelin finit son tour en vue sans
	# être trouvé. Puis 20 naturel au jet contre la mort : le Guerrier se
	# réveille, le voit et le trouve.
	_goblin.position = Vector2i(3, 2)
	var events := _run(EndTurnAction.new(_goblin), [20])
	assert_bool(_fighter.is_down()).is_false()
	var revealed := events.back() as RevealedEvent
	assert_object(revealed).is_not_null()
	assert_str(revealed.reason).is_equal(RevealedEvent.SEEN)
	for event: CombatEvent in events.slice(0, events.size() - 1):
		assert_object(event).is_not_instanceof(RevealedEvent)
	assert_bool(_state.is_hidden(_goblin)).is_false()


func test_hidden_attacker_has_advantage_and_is_revealed() -> void:
	_start()
	_goblin_hides(12)
	_goblin.position = Vector2i(2, 2)
	# Avantage : 3 et 15, on garde 15 ; 15 + 4 = 19 contre CA 16 : touché.
	# 1d6 + 2 et 1d4 (avantage) : 3 + 2 + 2 = 7.
	var events := _run(AttackAction.new(_goblin, _fighter), [3, 15, 3, 2])
	var revealed := events[0] as RevealedEvent
	assert_str(revealed.reason).is_equal(RevealedEvent.ATTACKED)
	var result := (events[1] as AttackRolledEvent).result
	assert_array(result.advantage.advantages).contains([AdvantageResolver.ATTACKER_HIDDEN])
	assert_int(result.damage).is_equal(7)
	assert_bool(_state.is_hidden(_goblin)).is_false()
	assert_int(_fighter.hp).is_equal(5)


func test_hidden_goblin_leaving_reach_provokes_no_opportunity_attack() -> void:
	_start()
	_goblin_hides(12)
	_goblin.position = Vector2i(2, 2)
	_run(MoveAction.new(_goblin, Vector2i(4, 4)))
	assert_object(_state.pending).is_null()
	assert_that(_goblin.position).is_equal(Vector2i(4, 4))


func test_dodge_does_not_work_against_a_hidden_attacker() -> void:
	_start()
	_state.add_effect(Effect.new(Effect.DODGING, _fighter, _fighter, Effect.Expiry.START_OF_SOURCE_TURN))
	_goblin_hides(12)
	_goblin.position = Vector2i(2, 2)
	var advantage := AdvantageResolver.for_attack(_state, _goblin, _fighter, _goblin.melee_weapon())
	assert_array(advantage.disadvantages).not_contains([AdvantageResolver.TARGET_DODGING])
	assert_int(advantage.mode).is_equal(Dice.RollMode.ADVANTAGE)


# --- Chercher -----------------------------------------------------------------------


func test_search_finds_the_goblin_when_meeting_its_stealth_total() -> void:
	_start()
	_goblin_hides(9)
	_end_turn()
	# Perception + 3 : 12 + 3 = 15, le total de sa Discrétion.
	var events := _run(SearchAction.new(_fighter), [12])
	var search := events[0] as SearchedEvent
	assert_int(search.total).is_equal(15)
	assert_array(search.found).contains_exactly([_goblin])
	assert_str((events[1] as RevealedEvent).reason).is_equal(RevealedEvent.FOUND)
	assert_bool(_state.is_hidden(_goblin)).is_false()
	assert_bool(_state.action_used).is_true()


func test_search_below_the_stealth_total_finds_nothing() -> void:
	_start()
	_goblin_hides(9)
	_end_turn()
	var events := _run(SearchAction.new(_fighter), [11])
	assert_array((events[0] as SearchedEvent).found).is_empty()
	assert_bool(_state.is_hidden(_goblin)).is_true()


func test_search_needs_a_hidden_enemy() -> void:
	_start(false)
	assert_str(SearchAction.new(_fighter).validate(_state)).is_equal(Action.NOTHING_TO_SEARCH)


# --- Attaquer à l'aveugle -------------------------------------------------------------


## Le Gobelin caché se trouve en (3,2), en vue mais pas encore trouvé
## (situation forcée : sur notre grille sans brouillard ni abri partiel, il
## serait trouvé en fin de tour ; l'attaque à l'aveugle servira avec eux).
func _goblin_hidden_in_plain_sight() -> void:
	_start()
	_goblin_hides(12)
	_end_turn()
	_goblin.position = Vector2i(3, 2)


func test_blind_attack_on_the_right_cell_has_disadvantage() -> void:
	_goblin_hidden_in_plain_sight()
	var javelin: WeaponDef = _fighter.definition.weapons[2]
	# Désavantage : 17 et 12, on garde 12 ; 12 + 5 = 17 contre CA 15 :
	# touché. 1d6 + 3, deux fois (Savage Attacker) : 4 et 2, on garde 4.
	var events := _run(AttackAction.at_cell(_fighter, Vector2i(3, 2), javelin), [17, 12, 4, 2])
	var result := (events[0] as AttackRolledEvent).result
	assert_object(result.target).is_same(_goblin)
	assert_int(result.d20.mode).is_equal(Dice.RollMode.DISADVANTAGE)
	assert_array(result.advantage.disadvantages).contains([AdvantageResolver.TARGET_UNSEEN])
	assert_bool(result.is_hit).is_true()
	# Touché, mais pas trouvé : il reste caché.
	assert_bool(_state.is_hidden(_goblin)).is_true()


func test_blind_attack_on_an_empty_cell_misses_without_a_roll() -> void:
	_goblin_hidden_in_plain_sight()
	var javelin: WeaponDef = _fighter.definition.weapons[2]
	var events := _run(AttackAction.at_cell(_fighter, Vector2i(3, 3), javelin))
	assert_object(events[0]).is_instanceof(AttackedEmptyCellEvent)
	assert_bool(_state.action_used).is_true()
	# Le javelot est quand même lancé.
	assert_int(_fighter.quantity(javelin)).is_equal(7)


func test_blind_attack_needs_a_hidden_enemy() -> void:
	_start(false)
	assert_str(AttackAction.at_cell(_fighter, Vector2i(2, 2)).validate(_state)).is_equal(Action.NO_TARGET)


func test_blind_attack_cannot_target_a_cell_behind_an_obstacle() -> void:
	_start()
	_goblin_hides(12)
	_end_turn()
	var javelin: WeaponDef = _fighter.definition.weapons[2]
	assert_str(AttackAction.at_cell(_fighter, Vector2i(8, 2), javelin).validate(_state)).is_equal(Action.TARGET_NOT_VISIBLE)


func test_a_hidden_enemy_cannot_be_targeted_directly() -> void:
	_goblin_hidden_in_plain_sight()
	var javelin: WeaponDef = _fighter.definition.weapons[2]
	assert_str(AttackAction.new(_fighter, _goblin, javelin).validate(_state)).is_equal(Action.NO_TARGET)


# --- Embuscade et surprise ------------------------------------------------------------


func test_ambush_hidden_goblin_surprises_the_fighter() -> void:
	# Discrétion 9 + 6 = 15 : caché. Guerrier surpris (désavantage) : 15 et
	# 4, on garde 4. Gobelin invisible (avantage) : 3 et 12, on garde 12.
	var events := _start(true, true, [9, 15, 4, 3, 12])
	assert_object(events[0]).is_instanceof(HideAttemptedEvent)
	assert_bool(_state.is_hidden(_goblin)).is_true()
	var order := _state.initiative
	assert_object(order[0].combatant).is_same(_goblin)
	assert_int(order[0].roll.mode).is_equal(Dice.RollMode.ADVANTAGE)
	assert_int(order[0].total).is_equal(14)
	assert_int(order[1].roll.mode).is_equal(Dice.RollMode.DISADVANTAGE)
	assert_int(order[1].total).is_equal(5)


func test_failed_ambush_means_no_surprise() -> void:
	_start(true, true, [8, 10, 5])
	assert_bool(_state.is_hidden(_goblin)).is_false()
	for entry in _state.initiative:
		assert_int(entry.roll.mode).is_equal(Dice.RollMode.NORMAL)


func test_no_ambush_from_a_goblin_in_plain_sight() -> void:
	var cells: Array[Vector2i] = [Vector2i(8, 2)]
	var encounter := Fixtures.encounter(Vector2i(12, 5), Vector2i(1, 2), cells, [], Fixtures.full_goblin())
	encounter.ambush = true
	_state = CombatState.create(encounter, Fixtures.full_fighter())
	var dice := _dice([10, 5])
	var events := _state.start(dice)
	assert_object(events[0]).is_instanceof(InitiativeRolledEvent)
	assert_int(dice.remaining()).is_equal(0)


func test_chain_mail_gives_disadvantage_on_stealth() -> void:
	var fighter := Combatant.new(DataRegistry.load_from().character(&"fighter_lvl1"), Combatant.Side.PLAYER)
	var state := CombatState.create(Fixtures.encounter(Vector2i(12, 8), Vector2i(0, 0), [Vector2i(11, 7)] as Array[Vector2i]), fighter.definition)
	# Désavantage : 18 et 3, on garde 3.
	var event := state.roll_hide(state.combatants[0], FixedDice.new([18, 3] as Array[int]), false)
	assert_int(event.d20).is_equal(3)
	assert_bool(event.success).is_false()

## 0 PV (SRD 5.2.1, « Dropping to 0 Hit Points ») : mort du monstre, dégâts
## massifs, personnage inconscient et à terre, jets contre la mort, attaques
## contre un combattant inconscient, se relever.
extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const Fixtures := preload("res://tests/helpers/fixtures.gd")

var _state: CombatState
var _fighter: Combatant
var _goblin: Combatant


## Grille 12×3 sans obstacle : Guerrier en (0,1), Gobelin complet à la case
## donnée. Initiative : Guerrier 10 + 1, Gobelin 5 + 2 : le Guerrier commence.
func _start(goblin_cell: Vector2i = Vector2i(1, 1), fighter: CharacterDef = null) -> void:
	var cells: Array[Vector2i] = [goblin_cell]
	var definition := fighter if fighter != null else Fixtures.fighter()
	_state = CombatState.create(Fixtures.encounter(Vector2i(12, 3), Vector2i(0, 1), cells, [], Fixtures.full_goblin()), definition)
	_state.start(FixedDice.new([10, 5]))
	_fighter = _state.combatants[0]
	_goblin = _state.combatants[1]


func _dice(values: Array) -> Dice:
	var typed: Array[int] = []
	typed.assign(values)
	return FixedDice.new(typed)


## Fait tomber le Guerrier à 0 PV, puis passe au tour du Gobelin.
func _drop_fighter() -> void:
	HitPoints.apply_damage(_state, _fighter, _fighter.hp, DamageType.Type.SLASHING)
	EndTurnAction.new(_fighter).execute(_state, _dice([]))
	assert_object(_state.active()).is_same(_goblin)


## Fin du tour du Gobelin : le Guerrier mourant fait son jet contre la mort.
func _goblin_ends_turn(death_save: Array) -> Array[CombatEvent]:
	var dice := _dice(death_save)
	var events := EndTurnAction.new(_goblin).execute(_state, dice)
	assert_int((dice as FixedDice).remaining()).is_equal(0)
	return events


func _events_of(events: Array[CombatEvent], script: Script) -> Array[CombatEvent]:
	var found: Array[CombatEvent] = []
	for event in events:
		if event.get_script() == script:
			found.append(event)
	return found


# --- Tomber à 0 PV ----------------------------------------------------------------


func test_monster_dies_at_zero_hp() -> void:
	_start()
	var events := HitPoints.apply_damage(_state, _goblin, 12, DamageType.Type.SLASHING)
	assert_bool(_goblin.is_dead).is_true()
	var died := _events_of(events, CombatantDiedEvent)
	assert_int(died.size()).is_equal(1)
	assert_str((died[0] as CombatantDiedEvent).cause).is_equal(CombatantDiedEvent.MONSTER_AT_ZERO)
	assert_bool(_state.is_over).is_true()
	assert_int(_state.winner).is_equal(Combatant.Side.PLAYER)
	# Un mort ne tient plus sa case.
	assert_object(_state.combatant_at(Vector2i(1, 1))).is_null()


func test_character_at_zero_hp_falls_unconscious_and_prone() -> void:
	_start()
	var events := HitPoints.apply_damage(_state, _fighter, 12, DamageType.Type.SLASHING)
	assert_bool(_fighter.is_dead).is_false()
	assert_bool(_fighter.is_down()).is_true()
	assert_bool(_fighter.is_dying()).is_true()
	assert_bool(_state.has_effect(_fighter, Effect.PRONE)).is_true()
	assert_int(_events_of(events, CombatantDownedEvent).size()).is_equal(1)
	# Mourant, il reste en lice et occupe sa case.
	assert_bool(_state.is_over).is_false()
	assert_object(_state.combatant_at(Vector2i(0, 1))).is_same(_fighter)
	assert_int(_state.speed_in_squares(_fighter)).is_equal(0)


func test_massive_damage_kills_outright() -> void:
	_start()
	_fighter.hp = 6
	# 18 dégâts : 6 pour tomber à 0, il en reste 12, ses PV maximum.
	var events := HitPoints.apply_damage(_state, _fighter, 18, DamageType.Type.SLASHING)
	assert_bool(_fighter.is_dead).is_true()
	assert_str((_events_of(events, CombatantDiedEvent)[0] as CombatantDiedEvent).cause).is_equal(CombatantDiedEvent.MASSIVE_DAMAGE)
	assert_bool(_state.is_over).is_true()
	assert_int(_state.winner).is_equal(Combatant.Side.ENEMY)


func test_just_below_massive_damage_only_knocks_out() -> void:
	_start()
	_fighter.hp = 6
	HitPoints.apply_damage(_state, _fighter, 17, DamageType.Type.SLASHING)
	assert_bool(_fighter.is_dead).is_false()
	assert_bool(_fighter.is_dying()).is_true()


func test_unconscious_fighter_cannot_act_but_his_turn_ends() -> void:
	_start()
	HitPoints.apply_damage(_state, _fighter, 12, DamageType.Type.SLASHING)
	assert_str(AttackAction.new(_fighter, _goblin).validate(_state)).is_equal(Action.INCAPACITATED)
	assert_str(StandardAction.new(_fighter, StandardAction.DODGE).validate(_state)).is_equal(Action.INCAPACITATED)
	assert_str(EndTurnAction.new(_fighter).validate(_state)).is_empty()


func test_unconscious_fighter_makes_no_opportunity_attack() -> void:
	_start()
	_drop_fighter()
	var events := MoveAction.new(_goblin, Vector2i(4, 1)).execute(_state, _dice([]))
	assert_object(_state.pending).is_null()
	assert_that(_goblin.position).is_equal(Vector2i(4, 1))
	assert_int(_events_of(events, ReactionTriggeredEvent).size()).is_equal(0)


# --- Jets contre la mort ------------------------------------------------------------


func test_death_save_at_start_of_turn_counts_success_and_failure() -> void:
	_start()
	_drop_fighter()
	var events := _goblin_ends_turn([10])
	var save := _events_of(events, DeathSaveEvent)[0] as DeathSaveEvent
	assert_int(save.natural).is_equal(10)
	assert_int(_fighter.death_save_successes).is_equal(1)
	assert_object(_state.active()).is_same(_fighter)

	EndTurnAction.new(_fighter).execute(_state, _dice([]))
	_goblin_ends_turn([9])
	assert_int(_fighter.death_save_failures).is_equal(1)
	assert_int(_fighter.death_save_successes).is_equal(1)


func test_natural_1_counts_as_two_failures() -> void:
	_start()
	_drop_fighter()
	_goblin_ends_turn([1])
	assert_int(_fighter.death_save_failures).is_equal(2)


func test_natural_20_restores_1_hp_and_the_turn_is_played_prone() -> void:
	_start()
	_drop_fighter()
	_fighter.death_save_failures = 2
	var events := _goblin_ends_turn([20])
	assert_bool((_events_of(events, DeathSaveEvent)[0] as DeathSaveEvent).revived).is_true()
	assert_int(_fighter.hp).is_equal(1)
	assert_bool(_fighter.is_down()).is_false()
	assert_int(_fighter.death_save_failures).is_equal(0)
	# Il joue son tour, mais il est toujours à terre.
	assert_int(_state.movement_left).is_equal(6)
	assert_bool(_state.has_effect(_fighter, Effect.PRONE)).is_true()
	assert_str(MoveAction.new(_fighter, Vector2i(0, 0)).validate(_state)).is_equal(Action.PRONE)


func test_three_successes_stabilize_and_end_the_fight_in_defeat() -> void:
	_start()
	_drop_fighter()
	_fighter.death_save_successes = 2
	var events := _goblin_ends_turn([15])
	assert_bool(_fighter.is_stable).is_true()
	assert_bool(_fighter.is_dead).is_false()
	assert_int(_events_of(events, CombatantStabilizedEvent).size()).is_equal(1)
	assert_bool(_state.is_over).is_true()
	assert_int(_state.winner).is_equal(Combatant.Side.ENEMY)


func test_three_failures_kill() -> void:
	_start()
	_drop_fighter()
	_fighter.death_save_failures = 2
	var events := _goblin_ends_turn([5])
	assert_bool(_fighter.is_dead).is_true()
	assert_str((_events_of(events, CombatantDiedEvent)[0] as CombatantDiedEvent).cause).is_equal(CombatantDiedEvent.DEATH_SAVES)
	assert_bool(_state.is_over).is_true()


func test_damage_at_zero_hp_is_a_failure_and_two_on_a_critical() -> void:
	_start()
	_drop_fighter()
	var events := HitPoints.apply_damage(_state, _fighter, 3, DamageType.Type.SLASHING)
	assert_int(_fighter.death_save_failures).is_equal(1)
	assert_int((_events_of(events, DeathSaveEvent)[0] as DeathSaveEvent).natural).is_equal(0)
	HitPoints.apply_damage(_state, _fighter, 3, DamageType.Type.SLASHING, false, true)
	assert_bool(_fighter.is_dead).is_true()


func test_damage_at_zero_hp_reaching_max_hp_kills() -> void:
	_start()
	_drop_fighter()
	HitPoints.apply_damage(_state, _fighter, 12, DamageType.Type.SLASHING)
	assert_bool(_fighter.is_dead).is_true()


func test_healing_wakes_up_and_resets_death_saves() -> void:
	_start()
	_drop_fighter()
	_fighter.death_save_failures = 2
	_fighter.death_save_successes = 1
	_fighter.heal(4)
	assert_bool(_fighter.is_down()).is_false()
	assert_int(_fighter.death_save_failures).is_equal(0)
	assert_int(_fighter.death_save_successes).is_equal(0)


func test_failed_death_save_offers_heroic_inspiration() -> void:
	var definition := Fixtures.fighter()
	definition.heroic_inspiration = true
	_start(Vector2i(1, 1), definition)
	_drop_fighter()
	var events := _goblin_ends_turn([4])
	assert_int(_events_of(events, DeathSaveEvent).size()).is_equal(0)
	var window := _state.pending as InspirationWindow
	assert_object(window).is_not_null()
	assert_object(window.decider).is_same(_fighter)
	assert_int(window.death_save).is_equal(4)

	var reroll := UseInspirationAction.new(_fighter)
	assert_str(reroll.validate(_state)).is_empty()
	var rerolled := reroll.execute(_state, _dice([15]))
	assert_object(rerolled[0]).is_instanceof(InspirationUsedEvent)
	assert_bool(_fighter.heroic_inspiration).is_false()
	assert_int(_fighter.death_save_successes).is_equal(1)
	assert_int(_fighter.death_save_failures).is_equal(0)


func test_declining_inspiration_keeps_the_failed_death_save() -> void:
	var definition := Fixtures.fighter()
	definition.heroic_inspiration = true
	_start(Vector2i(1, 1), definition)
	_drop_fighter()
	_goblin_ends_turn([1])
	DeclineInspirationAction.new(_fighter).execute(_state, _dice([]))
	assert_int(_fighter.death_save_failures).is_equal(2)
	assert_bool(_fighter.heroic_inspiration).is_true()


# --- Attaquer un combattant inconscient ----------------------------------------------


func test_melee_attack_on_unconscious_target_has_advantage_and_crits() -> void:
	_start()
	_drop_fighter()
	# Avantage : 12 et 3, on garde 12 ; 12 + 4 = 16 contre CA 16 : touché,
	# donc critique. 2d6 + 2 et 2d4 (avantage) : 2 + 2 + 2, 1 + 1.
	var events := AttackAction.new(_goblin, _fighter).execute(_state, _dice([12, 3, 2, 2, 1, 1]))
	var result := (events[0] as AttackRolledEvent).result
	assert_int(result.d20.mode).is_equal(Dice.RollMode.ADVANTAGE)
	assert_array(result.advantage.advantages).contains([AdvantageResolver.TARGET_UNCONSCIOUS, AdvantageResolver.TARGET_PRONE])
	assert_bool(result.is_critical).is_true()
	assert_int(_fighter.death_save_failures).is_equal(2)


func test_ranged_attack_on_unconscious_target_from_afar_is_plain() -> void:
	_start(Vector2i(4, 1))
	_drop_fighter()
	var bow: WeaponDef = _goblin.definition.weapons[1]
	# Inconscient (avantage) mais à terre et de loin (désavantage) : ils
	# s'annulent. 16 + 4 = 20, touché sans critique : 1d6 + 2.
	var events := AttackAction.new(_goblin, _fighter, bow).execute(_state, _dice([16, 3]))
	var result := (events[0] as AttackRolledEvent).result
	assert_int(result.d20.mode).is_equal(Dice.RollMode.NORMAL)
	assert_array(result.advantage.disadvantages).contains([AdvantageResolver.TARGET_PRONE_FAR])
	assert_bool(result.is_critical).is_false()
	assert_int(_fighter.death_save_failures).is_equal(1)


func test_unconscious_target_cannot_dodge() -> void:
	_start()
	_state.add_effect(Effect.new(Effect.DODGING, _fighter, _fighter, Effect.Expiry.START_OF_SOURCE_TURN))
	_drop_fighter()
	var advantage := AdvantageResolver.for_attack(_state, _goblin, _fighter, _goblin.melee_weapon())
	assert_array(advantage.disadvantages).not_contains([AdvantageResolver.TARGET_DODGING])


# --- À terre ------------------------------------------------------------------------


func test_standing_up_costs_half_speed() -> void:
	_start()
	_state.add_effect(Effect.new(Effect.PRONE, _fighter, _fighter, Effect.Expiry.UNTIL_REMOVED))
	var stand := StandUpAction.new(_fighter)
	assert_str(stand.validate(_state)).is_empty()
	stand.execute(_state, _dice([]))
	assert_bool(_state.has_effect(_fighter, Effect.PRONE)).is_false()
	assert_int(_state.movement_left).is_equal(3)
	assert_str(StandUpAction.new(_fighter).validate(_state)).is_equal(Action.NOT_PRONE)


func test_standing_up_needs_enough_movement() -> void:
	_start()
	_state.add_effect(Effect.new(Effect.PRONE, _fighter, _fighter, Effect.Expiry.UNTIL_REMOVED))
	_state.movement_left = 2
	assert_str(StandUpAction.new(_fighter).validate(_state)).is_equal(Action.NOT_ENOUGH_MOVEMENT)


func test_prone_attacker_has_disadvantage() -> void:
	_start()
	_state.add_effect(Effect.new(Effect.PRONE, _fighter, _fighter, Effect.Expiry.UNTIL_REMOVED))
	var advantage := AdvantageResolver.for_attack(_state, _fighter, _goblin, _fighter.melee_weapon())
	assert_array(advantage.disadvantages).contains([AdvantageResolver.ATTACKER_PRONE])
	assert_int(advantage.mode).is_equal(Dice.RollMode.DISADVANTAGE)

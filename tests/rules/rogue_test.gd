## Le Roublard halfelin : Attaque sournoise, Vex, Chance, Discrétion
## naturelle, Alert (échange d'initiative), combat à deux armes, flèches.
extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const Fixtures := preload("res://tests/helpers/fixtures.gd")

var _state: CombatState
var _fighter: Combatant
var _rogue: Combatant


## Guerrier et Roublard contre des gobelins de base. Le Roublard joue en
## premier (20 à l'initiative, 1 pour les autres) ; il refuse l'échange
## d'initiative d'Alert.
func _fight(fighter_cell: Vector2i, rogue_cell: Vector2i, goblin_cells: Array[Vector2i], blocked: Array[Vector2i] = []) -> void:
	var starts: Array[Vector2i] = [fighter_cell, rogue_cell]
	var encounter := Fixtures.party_encounter(Vector2i(12, 8), starts, goblin_cells, blocked)
	var party: Array[CharacterDef] = [Fixtures.fighter(), Fixtures.rogue()]
	_state = CombatState.create_party(encounter, party)
	var rolls: Array = [1, 20]
	for cell in goblin_cells:
		rolls.append(1)
	_state.start(_dice(rolls))
	_fighter = _state.combatants[0]
	_rogue = _state.combatants[1]
	assert_object(_state.pending).is_instanceof(InitiativeSwapWindow)
	DeclineSwapAction.new(_rogue).execute(_state, _dice([]))
	assert_object(_state.active()).is_same(_rogue)


func _goblin(index: int = 0) -> Combatant:
	return _state.combatants[2 + index]


func _dice(values: Array) -> Dice:
	var typed: Array[int] = []
	typed.assign(values)
	return FixedDice.new(typed)


func _weapon(id: StringName) -> WeaponDef:
	for weapon in _rogue.definition.weapons:
		if weapon.id == id:
			return weapon
	return null


func _attack(target: Combatant, weapon_id: StringName, rolls: Array, off_hand: bool = false) -> AttackResult:
	var action := AttackAction.new(_rogue, target, _weapon(weapon_id))
	action.off_hand = off_hand
	assert_str(action.validate(_state)).is_empty()
	for event in action.execute(_state, _dice(rolls)):
		if event is AttackRolledEvent:
			return (event as AttackRolledEvent).result
	return null


## Passe les tours (fin de tour de chacun) jusqu'au prochain tour de `who`.
func _end_turns_until(who: Combatant) -> void:
	EndTurnAction.new(_state.active()).execute(_state, _dice([]))
	while _state.active() != who:
		EndTurnAction.new(_state.active()).execute(_state, _dice([]))


# --- Attaque sournoise -----------------------------------------------------------------


func test_sneak_attack_when_an_ally_is_next_to_the_target() -> void:
	_fight(Vector2i(4, 2), Vector2i(4, 4), [Vector2i(4, 3)])
	# 15 + 5 = 20 : touché. Épée courte 4 + 3, Attaque sournoise 5.
	var result := _attack(_goblin(), &"shortsword", [15, 4, 5])
	assert_object(result.sneak_attack_roll).is_not_null()
	assert_int(result.sneak_attack_roll.total).is_equal(5)
	assert_int(result.damage).is_equal(12)


func test_no_sneak_attack_alone_without_advantage() -> void:
	_fight(Vector2i(0, 0), Vector2i(4, 4), [Vector2i(4, 3)])
	var result := _attack(_goblin(), &"shortsword", [15, 4])
	assert_object(result.sneak_attack_roll).is_null()
	assert_int(result.damage).is_equal(7)


func test_sneak_attack_with_advantage_even_alone() -> void:
	_fight(Vector2i(0, 0), Vector2i(4, 4), [Vector2i(4, 3)])
	_state.add_effect(Effect.new(Effect.PRONE, _goblin(), _goblin(), Effect.Expiry.UNTIL_REMOVED))
	# Cible à terre au contact : avantage, 3 et 15.
	var result := _attack(_goblin(), &"shortsword", [3, 15, 4, 5])
	assert_int(result.sneak_attack_roll.total).is_equal(5)


func test_disadvantage_cancels_the_ally_condition() -> void:
	_fight(Vector2i(4, 2), Vector2i(4, 4), [Vector2i(4, 3)])
	_state.add_effect(Effect.new(Effect.SAPPED, _rogue, _goblin(), Effect.Expiry.START_OF_SOURCE_TURN))
	var result := _attack(_goblin(), &"shortsword", [15, 18, 4])
	assert_object(result.sneak_attack_roll).is_null()


func test_a_downed_ally_does_not_count() -> void:
	_fight(Vector2i(4, 2), Vector2i(4, 4), [Vector2i(4, 3)])
	_fighter.hp = 0
	var result := _attack(_goblin(), &"shortsword", [15, 4])
	assert_object(result.sneak_attack_roll).is_null()


func test_sneak_attack_once_per_turn() -> void:
	_fight(Vector2i(4, 2), Vector2i(4, 4), [Vector2i(4, 3)])
	_goblin().definition.max_hp = 40
	_goblin().hp = 40
	_attack(_goblin(), &"shortsword", [15, 4, 5])
	# Vex : la deuxième attaque a l'avantage (15 et 15), mais l'Attaque
	# sournoise est déjà prise ce tour-ci.
	var off_hand := _attack(_goblin(), &"dagger", [15, 15, 2], true)
	assert_object(off_hand.sneak_attack_roll).is_null()


func test_critical_doubles_the_sneak_attack_dice() -> void:
	_fight(Vector2i(4, 2), Vector2i(4, 4), [Vector2i(4, 3)])
	_goblin().definition.max_hp = 40
	_goblin().hp = 40
	var result := _attack(_goblin(), &"shortsword", [20, 1, 2, 3, 4])
	assert_int(result.sneak_attack_roll.rolls.size()).is_equal(2)
	# 1 + 2 + 3 (Dex) + 3 + 4.
	assert_int(result.damage).is_equal(13)


func test_the_estimate_counts_sneak_attack() -> void:
	_fight(Vector2i(4, 2), Vector2i(4, 4), [Vector2i(4, 3)])
	var estimate := AttackEstimate.of(_state, _rogue, _goblin(), _weapon(&"shortsword"))
	assert_bool(estimate.sneak_attack).is_true()
	assert_int(estimate.damage_min).is_equal(1 + 3 + 1)
	assert_int(estimate.damage_max).is_equal(6 + 3 + 6)


# --- Vex ---------------------------------------------------------------------------------


func test_vex_gives_advantage_on_the_next_attack_against_that_target() -> void:
	_fight(Vector2i(0, 0), Vector2i(4, 4), [Vector2i(4, 3)])
	_goblin().definition.max_hp = 40
	_goblin().hp = 40
	_attack(_goblin(), &"shortsword", [15, 4])
	assert_bool(_state.has_effect(_goblin(), Effect.VEXED)).is_true()
	var advantage := AdvantageResolver.for_attack(_state, _rogue, _goblin(), _weapon(&"shortsword"))
	assert_int(advantage.mode).is_equal(Dice.RollMode.ADVANTAGE)
	assert_array(advantage.advantages).contains([AdvantageResolver.TARGET_VEXED])
	# Le Guerrier n'en profite pas.
	assert_int(AdvantageResolver.for_attack(_state, _fighter, _goblin(), _fighter.definition.weapons[0]).mode).is_equal(Dice.RollMode.NORMAL)


func test_vex_is_spent_by_the_next_attack() -> void:
	_fight(Vector2i(0, 0), Vector2i(4, 4), [Vector2i(4, 3)])
	_goblin().definition.max_hp = 40
	_goblin().hp = 40
	_attack(_goblin(), &"shortsword", [15, 4])
	_end_turns_until(_rogue)
	# Avantage : 2 et 3, raté ; l'avantage est dépensé, touché ou non.
	var result := _attack(_goblin(), &"shortsword", [2, 3])
	assert_int(result.d20.mode).is_equal(Dice.RollMode.ADVANTAGE)
	assert_bool(_state.has_effect(_goblin(), Effect.VEXED)).is_false()


func test_vex_lasts_until_the_end_of_the_rogues_next_turn() -> void:
	_fight(Vector2i(0, 0), Vector2i(4, 4), [Vector2i(4, 3)])
	_goblin().definition.max_hp = 40
	_goblin().hp = 40
	_attack(_goblin(), &"shortsword", [15, 4])
	_end_turns_until(_rogue)
	assert_bool(_state.has_effect(_goblin(), Effect.VEXED)).is_true()
	EndTurnAction.new(_rogue).execute(_state, _dice([]))
	assert_bool(_state.has_effect(_goblin(), Effect.VEXED)).is_false()


func test_no_vex_without_damage() -> void:
	_fight(Vector2i(0, 0), Vector2i(4, 4), [Vector2i(4, 3)])
	_attack(_goblin(), &"shortsword", [5])
	assert_bool(_state.has_effect(_goblin(), Effect.VEXED)).is_false()


# --- Chance halfeline --------------------------------------------------------------------


func test_luck_rerolls_a_natural_one_on_an_attack() -> void:
	_fight(Vector2i(0, 0), Vector2i(4, 4), [Vector2i(4, 3)])
	var result := _attack(_goblin(), &"shortsword", [1, 15, 4])
	assert_int(result.d20.natural).is_equal(15)
	assert_int(result.d20.luck_rerolls).is_equal(1)
	assert_bool(result.is_hit).is_true()


func test_luck_must_keep_the_new_roll() -> void:
	_fight(Vector2i(0, 0), Vector2i(4, 4), [Vector2i(4, 3)])
	var result := _attack(_goblin(), &"shortsword", [1, 1])
	assert_int(result.d20.natural).is_equal(1)
	assert_bool(result.is_hit).is_false()


func test_luck_on_hide_and_death_saves_but_not_for_the_fighter() -> void:
	var wall: Array[Vector2i] = [Vector2i(5, 3), Vector2i(5, 4), Vector2i(5, 5)]
	_fight(Vector2i(0, 7), Vector2i(4, 4), [Vector2i(8, 4)], wall)
	var hide := _state.roll_hide(_rogue, _dice([1, 10]), false)
	assert_int(hide.d20).is_equal(10)
	assert_bool(hide.lucky).is_true()
	var save := HitPoints.roll_death_save(_state, _rogue, _dice([1, 12]))
	assert_int((save[0] as DeathSaveEvent).natural).is_equal(12)
	assert_bool((save[0] as DeathSaveEvent).lucky).is_true()
	var fighter_roll := AttackResolver.roll_attack(_fighter, _goblin(), _fighter.definition.weapons[0], _dice([1]))
	assert_int(fighter_roll.d20.natural).is_equal(1)


# --- Discrétion naturelle ----------------------------------------------------------------


func test_rogue_can_hide_behind_a_larger_ally() -> void:
	# Le Guerrier (Moyen) est entre le gobelin et le Roublard (Petit).
	_fight(Vector2i(3, 3), Vector2i(1, 3), [Vector2i(6, 3)])
	assert_bool(_state.can_hide(_rogue)).is_true()
	assert_str(HideAction.new(_rogue).validate(_state)).is_empty()


func test_the_fighter_cannot_hide_behind_the_rogue() -> void:
	_fight(Vector2i(1, 3), Vector2i(3, 3), [Vector2i(6, 3)])
	assert_bool(_state.can_hide(_fighter)).is_false()


func test_a_creature_of_the_same_size_does_not_hide_the_rogue() -> void:
	# Un gobelin inconscient (Petit, comme le halfelin) entre les deux ne
	# suffit pas.
	_fight(Vector2i(0, 7), Vector2i(1, 3), [Vector2i(6, 3), Vector2i(3, 3)])
	_goblin(1).hp = 0
	assert_bool(_goblin(1).is_dead).is_false()
	assert_bool(_state.can_hide(_rogue)).is_false()


func test_hidden_behind_the_fighter_the_rogue_stays_unseen() -> void:
	_fight(Vector2i(3, 3), Vector2i(1, 3), [Vector2i(6, 3)])
	HideAction.new(_rogue).execute(_state, _dice([15]))
	assert_bool(_state.is_hidden(_rogue)).is_true()
	EndTurnAction.new(_rogue).execute(_state, _dice([]))
	assert_bool(_state.is_hidden(_rogue)).is_true()


# --- Alert ---------------------------------------------------------------------------------


func _alert_fight(rolls: Array) -> void:
	var starts: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1)]
	var goblins: Array[Vector2i] = [Vector2i(8, 4)]
	var party: Array[CharacterDef] = [Fixtures.fighter(), Fixtures.rogue()]
	_state = CombatState.create_party(Fixtures.party_encounter(Vector2i(12, 8), starts, goblins), party)
	_state.start(_dice(rolls))
	_fighter = _state.combatants[0]
	_rogue = _state.combatants[1]


func test_alert_asks_to_swap_before_the_first_turn() -> void:
	# Guerrier 18 + 1, Roublard 2 + 5, gobelin 10 + 2.
	var events := _state_start_events([18, 2, 10])
	assert_object(_state.pending).is_instanceof(InitiativeSwapWindow)
	var window := _state.pending as InitiativeSwapWindow
	assert_object(window.decider).is_same(_rogue)
	assert_array(window.allies).contains_exactly([_fighter])
	for event in events:
		assert_bool(event is TurnStartedEvent).is_false()


func test_swapping_exchanges_the_two_initiatives() -> void:
	_alert_fight([18, 2, 10])
	var events := SwapInitiativeAction.new(_rogue, _fighter).execute(_state, _dice([]))
	assert_object(_state.pending).is_null()
	assert_object(_state.initiative[0].combatant).is_same(_rogue)
	assert_int(_state.initiative[0].total).is_equal(19)
	assert_object(_state.initiative[2].combatant).is_same(_fighter)
	assert_object(_state.active()).is_same(_rogue)
	assert_object(events.back()).is_instanceof(TurnStartedEvent)


func test_declining_keeps_the_order() -> void:
	_alert_fight([18, 2, 10])
	DeclineSwapAction.new(_rogue).execute(_state, _dice([]))
	assert_object(_state.pending).is_null()
	assert_object(_state.active()).is_same(_fighter)


func test_no_swap_with_an_incapacitated_ally() -> void:
	var starts: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1)]
	var goblins: Array[Vector2i] = [Vector2i(8, 4)]
	var party: Array[CharacterDef] = [Fixtures.fighter(), Fixtures.rogue()]
	_state = CombatState.create_party(Fixtures.party_encounter(Vector2i(12, 8), starts, goblins), party)
	_state.combatants[0].hp = 0
	_state.start(_dice([18, 2, 10, 10]))
	assert_object(_state.pending).is_null()


func test_ai_swaps_to_let_the_fighter_go_first() -> void:
	# Roublard 15 + 5 avant le Guerrier 2 + 1 : l'IA échange.
	_alert_fight([2, 15, 10])
	var answer := EnemyAI.decide(_state)
	assert_object(answer).is_instanceof(SwapInitiativeAction)
	_alert_fight([18, 2, 10])
	assert_object(EnemyAI.decide(_state)).is_instanceof(DeclineSwapAction)


func _state_start_events(rolls: Array) -> Array[CombatEvent]:
	var starts: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1)]
	var goblins: Array[Vector2i] = [Vector2i(8, 4)]
	var party: Array[CharacterDef] = [Fixtures.fighter(), Fixtures.rogue()]
	_state = CombatState.create_party(Fixtures.party_encounter(Vector2i(12, 8), starts, goblins), party)
	_fighter = _state.combatants[0]
	_rogue = _state.combatants[1]
	return _state.start(_dice(rolls))


# --- Combat à deux armes -------------------------------------------------------------------


func test_off_hand_attack_after_a_light_weapon_without_the_modifier() -> void:
	_fight(Vector2i(0, 0), Vector2i(4, 4), [Vector2i(4, 3)])
	_goblin().definition.max_hp = 40
	_goblin().hp = 40
	# Dague d'abord (pas de maîtrise, donc pas de Vex), puis l'épée courte.
	_attack(_goblin(), &"dagger", [15, 4])
	var result := _attack(_goblin(), &"shortsword", [15, 3], true)
	assert_bool(result.off_hand).is_true()
	assert_int(result.damage).is_equal(3)
	assert_bool(_state.bonus_action_used).is_true()
	# La dague n'est pas lancée : elle reste.
	assert_int(_rogue.quantity(_weapon(&"dagger"))).is_equal(2)


func test_off_hand_needs_an_attack_with_a_light_weapon_first() -> void:
	_fight(Vector2i(0, 0), Vector2i(4, 4), [Vector2i(4, 3)])
	var early := AttackAction.new(_rogue, _goblin(), _weapon(&"dagger"))
	early.off_hand = true
	assert_str(early.validate(_state)).is_equal(Action.NO_OFF_HAND_ATTACK)
	# L'arc court n'est pas une arme Légère.
	_goblin().definition.max_hp = 40
	_goblin().hp = 40
	_attack(_goblin(), &"shortbow", [5, 5])
	var after_bow := AttackAction.new(_rogue, _goblin(), _weapon(&"dagger"))
	after_bow.off_hand = true
	assert_str(after_bow.validate(_state)).is_equal(Action.NO_OFF_HAND_ATTACK)


func test_off_hand_must_use_a_different_light_weapon() -> void:
	_fight(Vector2i(0, 0), Vector2i(4, 4), [Vector2i(4, 3)])
	_goblin().definition.max_hp = 40
	_goblin().hp = 40
	_attack(_goblin(), &"shortsword", [5])
	var same := AttackAction.new(_rogue, _goblin(), _weapon(&"shortsword"))
	same.off_hand = true
	assert_str(same.validate(_state)).is_equal(Action.OFF_HAND_WEAPON)


func test_two_daggers_make_two_different_weapons() -> void:
	_fight(Vector2i(0, 0), Vector2i(4, 4), [Vector2i(4, 3)])
	_goblin().definition.max_hp = 40
	_goblin().hp = 40
	_attack(_goblin(), &"dagger", [5])
	var second := AttackAction.new(_rogue, _goblin(), _weapon(&"dagger"))
	second.off_hand = true
	assert_str(second.validate(_state)).is_empty()
	# Avec une seule dague, ce serait la même arme.
	_rogue.quantities[&"dagger"] = 1
	assert_str(second.validate(_state)).is_equal(Action.OFF_HAND_WEAPON)


func test_monsters_use_their_stat_block_not_two_weapon_fighting() -> void:
	var minion_cells: Array[Vector2i] = [Vector2i(1, 0)]
	var encounter := Fixtures.encounter(Vector2i(12, 8), Vector2i(0, 0), minion_cells, [], Fixtures.minion())
	_state = CombatState.create(encounter, Fixtures.fighter())
	_state.start(_dice([1, 20]))
	var minion := _state.combatants[1]
	AttackAction.new(minion, _state.combatants[0], minion.definition.weapons[0]).execute(_state, _dice([5]))
	var second := AttackAction.new(minion, _state.combatants[0], minion.definition.weapons[0])
	second.off_hand = true
	assert_str(second.validate(_state)).is_equal(Action.NO_OFF_HAND_ATTACK)


# --- Flèches ---------------------------------------------------------------------------------


func test_each_shot_spends_an_arrow() -> void:
	_fight(Vector2i(0, 0), Vector2i(0, 4), [Vector2i(6, 4)])
	_attack(_goblin(), &"shortbow", [5])
	assert_int(_rogue.quantity(_weapon(&"shortbow"))).is_equal(19)


func test_half_the_spent_arrows_are_recovered_after_the_fight() -> void:
	var before := PartyMember.fresh(Fixtures.rogue())
	assert_int(before.ammunition[&"shortbow"]).is_equal(20)
	var rogue := Combatant.new(Fixtures.rogue(), Combatant.Side.PLAYER)
	rogue.quantities[&"shortbow"] = 15
	var after := PartyMember.after_combat(before, rogue)
	# 5 tirées : 2 récupérées (arrondi vers le bas).
	assert_int(after.ammunition[&"shortbow"]).is_equal(17)
	# Les dagues ne sont pas des munitions : elles ne sont pas suivies.
	assert_bool(after.ammunition.has(&"dagger")).is_false()


func test_arrows_are_saved_and_restored() -> void:
	var member := PartyMember.fresh(Fixtures.rogue())
	member.ammunition[&"shortbow"] = 12
	var read := PartyMember.from_dict(JSON.parse_string(JSON.stringify(member.to_dict())))
	assert_int(read.ammunition[&"shortbow"]).is_equal(12)
	var rogue := Combatant.new(Fixtures.rogue(), Combatant.Side.PLAYER)
	read.apply_to(rogue)
	assert_int(rogue.quantities[&"shortbow"]).is_equal(12)


func test_a_member_saved_without_arrows_has_a_full_quiver() -> void:
	var raw := {"def_id": "rogue_lvl1", "hp_current": 10, "second_wind_uses": 0, "heroic_inspiration": false}
	var member := PartyMember.from_dict(raw)
	assert_object(member).is_not_null()
	member.clamp_to(Fixtures.rogue())
	assert_int(member.ammunition[&"shortbow"]).is_equal(20)

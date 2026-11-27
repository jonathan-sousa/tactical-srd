## Combat à plusieurs personnages joueurs : création du groupe, déplacement
## à travers les alliés (SRD « Moving Around Other Creatures »), fin du
## combat quand un camp n'a plus personne en lice.
extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const Fixtures := preload("res://tests/helpers/fixtures.gd")

## Initiative : 20 pour le premier personnage, 1 pour les autres ; le
## premier personnage commence toujours.
const FIRST_PC_STARTS: Array[int] = [20, 1, 1, 1, 1]


## Un deuxième Guerrier, pour former un groupe sans nouvelle classe.
static func _second_fighter() -> CharacterDef:
	var def := Fixtures.fighter()
	def.id = &"fighter_b"
	def.display_name = "Guerrière"
	return def


func _party_state(starts: Array[Vector2i], enemy_cells: Array[Vector2i], blocked: Array[Vector2i] = [], grid := Vector2i(7, 1)) -> CombatState:
	var party: Array[CharacterDef] = [Fixtures.fighter(), _second_fighter()]
	var state := CombatState.create_party(Fixtures.party_encounter(grid, starts, enemy_cells, blocked), party)
	var dice := FixedDice.new(FIRST_PC_STARTS.slice(0, state.combatants.size()))
	state.start(dice)
	return state


func _run(state: CombatState, action: Action, dice: Dice = FixedDice.new([])) -> Array[CombatEvent]:
	assert_str(action.validate(state)).is_empty()
	return action.execute(state, dice)


static func _moves(events: Array[CombatEvent]) -> Array[MovedEvent]:
	var moves: Array[MovedEvent] = []
	for event: CombatEvent in events:
		if event is MovedEvent:
			moves.append(event as MovedEvent)
	return moves


# --- Création du groupe ------------------------------------------------------


func test_party_members_start_on_their_cells_in_order() -> void:
	var state := _party_state([Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(6, 0)])
	var party := state.party()
	assert_int(party.size()).is_equal(2)
	assert_str(party[0].definition.id).is_equal("fighter_lvl1")
	assert_str(party[1].definition.id).is_equal("fighter_b")
	assert_that(party[0].position).is_equal(Vector2i(0, 0))
	assert_that(party[1].position).is_equal(Vector2i(1, 0))
	for member in party:
		assert_int(member.side).is_equal(Combatant.Side.PLAYER)
	assert_int(state.combatants[2].side).is_equal(Combatant.Side.ENEMY)


func test_single_player_creation_still_works() -> void:
	var state := CombatState.create(Fixtures.encounter(Vector2i(7, 1), Vector2i(0, 0), [Vector2i(6, 0)]), Fixtures.fighter(), 5)
	assert_int(state.party().size()).is_equal(1)
	assert_int(state.party()[0].hp).is_equal(5)


# --- Se déplacer à travers un allié ------------------------------------------


func test_can_move_through_an_ally() -> void:
	# Couloir d'une case de large : la Guerrière barre le passage.
	var state := _party_state([Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(6, 0)])
	var fighter := state.party()[0]
	_run(state, MoveAction.new(fighter, Vector2i(2, 0)))
	assert_that(fighter.position).is_equal(Vector2i(2, 0))
	assert_int(state.movement_left).is_equal(4)


func test_cannot_end_a_move_on_an_ally() -> void:
	var state := _party_state([Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(6, 0)])
	var fighter := state.party()[0]
	assert_str(MoveAction.new(fighter, Vector2i(1, 0)).validate(state)).is_equal(Action.CELL_UNREACHABLE)
	var reachable := state.reachable_cells()
	assert_bool(reachable.has(Vector2i(1, 0))).is_false()
	assert_int(reachable.get(Vector2i(2, 0), -1)).is_equal(2)


func test_cannot_move_through_an_enemy() -> void:
	# Le gobelin, derrière les deux personnages, ne peut pas passer.
	var state := _party_state([Vector2i(1, 0), Vector2i(2, 0)], [Vector2i(6, 0)])
	var goblin := state.combatants[2]
	goblin.position = Vector2i(3, 0)
	assert_array(state.find_path(goblin, Vector2i(0, 0))).is_empty()


func test_enemies_move_through_each_other() -> void:
	var state := _party_state([Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(5, 0), Vector2i(6, 0)])
	var back_goblin := state.combatants[3]
	assert_array(state.find_path(back_goblin, Vector2i(4, 0))).contains_exactly([Vector2i(5, 0), Vector2i(4, 0)])


func test_bumping_a_hidden_enemy_from_an_ally_cell_steps_back_to_the_last_free_cell() -> void:
	# Le Guerrier traverse la Guerrière et heurte le gobelin caché juste
	# derrière : il ne peut pas rester dans la case de son alliée, il revient
	# sur sa dernière case libre, et le déplacement non fait lui est rendu.
	var state := _party_state([Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(2, 0)])
	var fighter := state.party()[0]
	var goblin := state.combatants[2]
	state.add_effect(Effect.new(Effect.HIDDEN, goblin, goblin, Effect.Expiry.UNTIL_REMOVED, 20))
	var events := _run(state, MoveAction.new(fighter, Vector2i(3, 0)))
	assert_that(fighter.position).is_equal(Vector2i(0, 0))
	assert_int(state.movement_left).is_equal(6)
	var moves := _moves(events)
	assert_int(moves.size()).is_equal(2)
	assert_array(moves[0].path).contains_exactly([Vector2i(1, 0)])
	assert_array(moves[1].path).contains_exactly([Vector2i(0, 0)])
	assert_object(events.back()).is_instanceof(RevealedEvent)
	assert_str((events.back() as RevealedEvent).reason).is_equal(RevealedEvent.BUMPED)


func test_downed_on_an_ally_cell_falls_back_to_the_last_free_cell() -> void:
	# Seul chemin vers (1, 2) : par la case de la Guerrière, en (1, 1), dans
	# l'allonge du gobelin. En la quittant, le Guerrier subit une attaque
	# d'opportunité qui le met à terre : il ne reste pas dans la case de son
	# alliée et retombe sur sa case de départ.
	var blocked: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 2)]
	var state := _party_state([Vector2i(0, 1), Vector2i(1, 1)], [Vector2i(2, 0)], blocked, Vector2i(4, 3))
	var fighter := state.party()[0]
	var goblin := state.combatants[2]
	fighter.hp = 1
	_run(state, MoveAction.new(fighter, Vector2i(1, 2)))
	assert_that(fighter.position).is_equal(Vector2i(1, 1))
	assert_object(state.pending).is_instanceof(ReactionWindow)
	# Attaque d'opportunité : 15 + 4 touche, 3 + 2 = 5 dégâts.
	var events := _run(state, OpportunityAttackAction.new(goblin), FixedDice.new([15, 3]))
	assert_bool(fighter.is_dying()).is_true()
	assert_that(fighter.position).is_equal(Vector2i(0, 1))
	var moves := _moves(events)
	assert_int(moves.size()).is_equal(1)
	assert_array(moves[0].path).contains_exactly([Vector2i(0, 1)])


# --- Fin du combat -----------------------------------------------------------


func test_fight_goes_on_while_one_party_member_stands() -> void:
	var state := _party_state([Vector2i(0, 0), Vector2i(2, 0)], [Vector2i(6, 0)])
	var second := state.party()[1]
	second.hp = 0
	second.is_dead = true
	assert_array(state.check_end()).is_empty()
	assert_bool(state.is_over).is_false()


func test_defeat_when_every_party_member_is_dead_or_stable() -> void:
	var state := _party_state([Vector2i(0, 0), Vector2i(2, 0)], [Vector2i(6, 0)])
	var party := state.party()
	party[0].hp = 0
	party[0].is_stable = true
	party[1].hp = 0
	party[1].is_dead = true
	var events := state.check_end()
	assert_bool(state.is_over).is_true()
	assert_int(state.winner).is_equal(Combatant.Side.ENEMY)
	assert_object(events.back()).is_instanceof(CombatEndedEvent)


func test_victory_gets_downed_party_members_back_up_at_one_hit_point() -> void:
	# La Guerrière est à terre, mourante, avec un échec. Le Guerrier abat le
	# dernier gobelin : après le combat, elle est stabilisée et se relève à
	# 1 PV (docs/rules-deviations.md).
	var state := _party_state([Vector2i(0, 0), Vector2i(2, 0)], [Vector2i(1, 0)])
	var party := state.party()
	var goblin := state.combatants[2]
	party[1].hp = 0
	party[1].death_save_failures = 1
	state.add_effect(Effect.new(Effect.PRONE, party[1], party[1], Effect.Expiry.UNTIL_REMOVED))
	goblin.hp = 1
	# 15 + 5 touche ; 1 + 1 + 3 = 5 dégâts.
	var events := _run(state, AttackAction.new(party[0], goblin, party[0].definition.weapons[0]), FixedDice.new([15, 1, 1]))
	assert_bool(state.is_over).is_true()
	assert_int(state.winner).is_equal(Combatant.Side.PLAYER)
	assert_int(party[1].hp).is_equal(1)
	assert_bool(party[1].is_stable).is_false()
	assert_int(party[1].death_save_failures).is_equal(0)
	var recovered: Array[CombatantRecoveredEvent] = []
	for event: CombatEvent in events:
		if event is CombatantRecoveredEvent:
			recovered.append(event as CombatantRecoveredEvent)
	assert_int(recovered.size()).is_equal(1)
	assert_object(recovered[0].combatant).is_same(party[1])
	assert_object(events.back()).is_instanceof(CombatEndedEvent)


func test_victory_also_gets_a_stable_party_member_back_up() -> void:
	var state := _party_state([Vector2i(0, 0), Vector2i(2, 0)], [Vector2i(6, 0)])
	var party := state.party()
	party[1].hp = 0
	party[1].is_stable = true
	state.combatants[2].hp = 0
	state.combatants[2].is_dead = true
	state.check_end()
	assert_int(state.winner).is_equal(Combatant.Side.PLAYER)
	assert_int(party[1].hp).is_equal(1)
	assert_bool(party[1].is_stable).is_false()

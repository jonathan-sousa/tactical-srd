## Enregistrement et rejeu d'un combat : chaque choix du joueur s'encode et
## se relit, le fichier est validé, et rejouer les choix avec la même graine
## redonne exactement le même combat.
extends GdUnitTestSuite

const Fixtures := preload("res://tests/helpers/fixtures.gd")
const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const RecordedGames := preload("res://tests/helpers/recorded_games.gd")

var _state: CombatState
var _fighter: Combatant
var _goblin: Combatant


func before_test() -> void:
	var cells: Array[Vector2i] = [Vector2i(3, 1)]
	_state = CombatState.create(Fixtures.encounter(Vector2i(12, 3), Vector2i(0, 1), cells, [], Fixtures.full_goblin()), Fixtures.full_fighter())
	var dice: Array[int] = [10, 5]
	_state.start(FixedDice.new(dice))
	_fighter = _state.combatants[0]
	_goblin = _state.combatants[1]


## Encode puis relit, en passant par le texte JSON comme dans le fichier :
## même type d'action, même encodage.
func _round_trip(action: Action) -> Action:
	var entry := CombatRecord.encode(action)
	assert_dict(entry).is_not_empty()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(entry))
	var decoded := CombatRecord.decode(parsed, _fighter, _state)
	assert_object(decoded).is_not_null()
	assert_str(decoded.get_script().get_global_name()).is_equal(action.get_script().get_global_name())
	assert_dict(CombatRecord.encode(decoded)).is_equal(entry)
	return decoded


func test_every_player_choice_round_trips() -> void:
	var javelin: WeaponDef = _fighter.definition.weapons[2]
	var move := _round_trip(MoveAction.new(_fighter, Vector2i(1, 0))) as MoveAction
	assert_that(move.destination).is_equal(Vector2i(1, 0))
	var attack := _round_trip(AttackAction.new(_fighter, _goblin, javelin)) as AttackAction
	assert_object(attack.target).is_same(_goblin)
	assert_object(attack.weapon).is_same(javelin)
	var blind := _round_trip(AttackAction.at_cell(_fighter, Vector2i(5, 2), javelin)) as AttackAction
	assert_bool(blind.is_blind()).is_true()
	var dodge := _round_trip(StandardAction.new(_fighter, StandardAction.DODGE)) as StandardAction
	assert_str(dodge.kind).is_equal(StandardAction.DODGE)
	var others: Array[Action] = [
		HideAction.new(_fighter), SecondWindAction.new(_fighter), SearchAction.new(_fighter),
		StandUpAction.new(_fighter), EndTurnAction.new(_fighter), OpportunityAttackAction.new(_fighter),
		DeclineReactionAction.new(_fighter), UseInspirationAction.new(_fighter), DeclineInspirationAction.new(_fighter),
	]
	for action in others:
		_round_trip(action)


func test_bad_entries_decode_to_null() -> void:
	var entries: Array[Dictionary] = [
		{}, {"type": "fly"}, {"type": "move", "cell": [1]}, {"type": "move", "cell": ["a", 2]},
		{"type": "attack", "cell": [3, 1], "weapon": "bazooka", "blind": false},
		{"type": "attack", "cell": [9, 0], "weapon": "greatsword", "blind": false},
		{"type": "standard", "kind": "teleport", "bonus": false}, {"type": "hide"},
	]
	for entry in entries:
		assert_object(CombatRecord.decode(entry, _fighter, _state)).override_failure_message("Accepté : %s" % entry).is_null()


func test_json_round_trip_keeps_everything() -> void:
	var recorded := RecordedGames.record(3)
	var loaded := CombatRecord.from_json(recorded.to_json())
	assert_object(loaded).is_not_null()
	assert_int(loaded.seed_value).is_equal(3)
	assert_str(loaded.encounter_id).is_equal(&"goblin_ambush")
	assert_int(loaded.player_hp).is_equal(recorded.player_hp)
	assert_int(loaded.entries.size()).is_equal(recorded.entries.size())
	assert_dict(loaded.outcome).is_equal(recorded.outcome)


func test_invalid_files_are_rejected() -> void:
	var good: Dictionary = JSON.parse_string(RecordedGames.record(3).to_json())
	for broken: String in ["pas du json", "[]", "{}"]:
		assert_object(CombatRecord.from_json(broken)).is_null()
	var changes: Array[Array] = [
		["version", 99], ["seed", "abc"], ["seed", 1.5], ["encounter", 3], ["entries", "x"], ["heroic_inspiration", 1],
	]
	for change in changes:
		var copy := good.duplicate(true)
		copy[change[0]] = change[1]
		assert_object(CombatRecord.from_json(JSON.stringify(copy))).override_failure_message("Accepté : %s" % [change]).is_null()


func test_replaying_the_choices_gives_the_same_combat() -> void:
	for seed_value: int in [1, 2, 4, 42]:
		var recorded := RecordedGames.record(seed_value)
		assert_array(recorded.entries).is_not_empty()
		var replayed := RecordedGames.replay(recorded)
		assert_object(replayed).override_failure_message("Graine %d : le rejeu a divergé" % seed_value).is_not_null()
		assert_dict(CombatRecord.outcome_of(replayed)).is_equal(recorded.outcome)


func test_a_different_choice_changes_or_breaks_the_replay() -> void:
	var recorded := RecordedGames.record(42)
	# Le joueur passe d'abord son tour : la suite des choix ne colle plus.
	recorded.entries.push_front({"type": CombatRecord.END_TURN})
	var replayed := RecordedGames.replay(recorded)
	var same := replayed != null and CombatRecord.outcome_of(replayed) == recorded.outcome
	assert_bool(same).is_false()

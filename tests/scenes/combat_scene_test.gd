## Scène de combat : déroulement d'un tour, fin de combat, pause.
##
## La scène est instanciée à la main pour lui donner des dés truqués avant son
## `_ready`, qui lance aussitôt l'initiative. Les clics sont simulés en
## appelant directement les gestionnaires du contrôleur : on teste ce qu'ils
## déclenchent, pas la conversion pixel → case (celle de BoardView).
extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const COMBAT_SCENE := "res://scenes/combat/combat.tscn"
## Initiative : le premier d20 est celui du Guerrier, le second celui du Gobelin.
const FIGHTER_FIRST: Array[int] = [20, 1]
const GOBLIN_FIRST: Array[int] = [1, 20]

var _runner: GdUnitSceneRunner
var _scene: Node
var _saved_step: StringName
var _saved_hp: int


func before_test() -> void:
	# Sans étape d'histoire en cours, la scène se lance en mode autonome.
	_saved_step = GameState.current_step_id
	_saved_hp = GameState.player_hp
	GameState.current_step_id = &""


func after_test() -> void:
	get_tree().paused = false
	GameState.current_step_id = _saved_step
	GameState.player_hp = _saved_hp


## Instancie la scène avec ces dés, sans délais, et attend la main du joueur
## (ou la fin du tour adverse).
func _start(dice: Array, enemy_delay := 0.0) -> void:
	_scene = auto_free(load(COMBAT_SCENE).instantiate())
	_scene.set("dice", _fixed_dice(dice))
	_scene.set("enemy_action_delay", enemy_delay)
	_scene.set("end_delay", 0.0)
	_runner = scene_runner(_scene)
	if enemy_delay == 0.0:
		await _settle()


# Piège GDScript : `[20, 1] + [6]` donne un Array non typé ; FixedDice attend
# un Array[int], d'où cette conversion.
func _fixed_dice(values: Array) -> Dice:
	var typed: Array[int] = []
	typed.assign(values)
	return FixedDice.new(typed)


func _state() -> CombatState:
	return _scene.get("state")


func _fighter() -> Combatant:
	return _state().combatants[0]


func _goblin() -> Combatant:
	return _state().combatants[1]


## Avance le jeu jusqu'à ce que le contrôleur attende le joueur ou que le
## combat soit fini. Échoue si cela prend plus de 15 s de jeu simulé.
func _settle() -> void:
	for _frame: int in 300:
		await _runner.simulate_frames(1, 50)
		if not _scene.get("_busy") and (_state().is_over or _scene.call("_is_player_turn")):
			return
	fail("Le combat ne rend jamais la main.")


## Place le Gobelin juste à droite du Guerrier, pour tester une attaque sans
## dépendre des déplacements.
func _put_goblin_next_to_fighter() -> void:
	var cell := _fighter().position + Vector2i(1, 0)
	assert_object(_state().combatant_at(cell)).is_null()
	_goblin().position = cell


func test_combat_scene_starts() -> void:
	await _start(FIGHTER_FIRST)
	assert_int(_state().round).is_equal(1)
	assert_object(_state().active()).is_same(_fighter())
	assert_int(_state().combatants.size()).is_equal(2)


func test_player_moves_then_ends_turn_and_goblin_plays() -> void:
	# 1 naturel pour une éventuelle attaque du Gobelin : un raté sans dégâts.
	await _start(FIGHTER_FIRST + [1])
	var reachable := _state().reachable_cells()
	var destination := _fighter().position + Vector2i(1, 0)
	assert_bool(reachable.has(destination)).is_true()

	_scene.call("_on_cell_clicked", destination)
	await _settle()
	assert_that(_fighter().position).is_equal(destination)
	assert_int(_state().movement_left).is_equal(_state().speed_in_squares(_fighter()) - 1)

	var goblin_start := _goblin().position
	_scene.call("_on_end_turn_pressed")
	await _settle()
	# Le Gobelin a joué son tour, puis la main revient au Guerrier au round 2.
	assert_that(_goblin().position).is_not_equal(goblin_start)
	assert_object(_state().active()).is_same(_fighter())
	assert_int(_state().round).is_equal(2)


func test_refused_click_explains_why() -> void:
	await _start(FIGHTER_FIRST)
	var far := Vector2i(11, 7)
	_scene.call("_on_cell_clicked", far)
	await _runner.simulate_frames(1)
	var hint: Label = _scene.get_node("%HintLabel")
	assert_str(hint.text).is_equal(Texts.reason(MoveAction.new(_fighter(), far).validate(_state())))
	assert_str(hint.text).is_not_empty()


func test_standalone_victory_shows_result_panel() -> void:
	# Coup critique (20 naturel) puis 4d6 à 6 : 27 dégâts, le Gobelin tombe.
	await _start(FIGHTER_FIRST + [20, 6, 6, 6, 6])
	_put_goblin_next_to_fighter()
	_scene.call("_on_cell_clicked", _goblin().position)
	await _settle()
	assert_bool(_state().is_over).is_true()
	assert_int(_state().winner).is_equal(Combatant.Side.PLAYER)
	assert_bool((_scene.get_node("%ResultPanel") as Control).visible).is_true()
	assert_str((_scene.get_node("%ResultLabel") as Label).text).is_equal(Texts.VICTORY)


func test_story_victory_reports_remaining_hp_without_result_panel() -> void:
	GameState.current_step_id = &"goblin_ambush"
	GameState.player_hp = 7
	var reported: Array = []
	_scene = auto_free(load(COMBAT_SCENE).instantiate())
	_scene.set("dice", _fixed_dice(FIGHTER_FIRST + [20, 6, 6, 6, 6]))
	_scene.set("end_delay", 0.0)
	_scene.set("on_story_end", func(outcome: int, hp: int) -> void: reported.append([outcome, hp]))
	_runner = scene_runner(_scene)
	await _settle()
	assert_int(_fighter().hp).is_equal(7)

	_put_goblin_next_to_fighter()
	_scene.call("_on_cell_clicked", _goblin().position)
	await _settle()
	await _runner.simulate_frames(2)
	assert_array(reported).is_equal([[GameState.Outcome.VICTORY, 7]])
	assert_bool((_scene.get_node("%ResultPanel") as Control).visible).is_false()


func test_pause_freezes_the_enemy_turn() -> void:
	await _start(GOBLIN_FIRST + [1], 0.5)
	await _runner.simulate_frames(2)
	var goblin_start := _goblin().position
	assert_object(_state().active()).is_same(_goblin())

	get_tree().paused = true
	await _runner.simulate_frames(40, 100)
	assert_that(_goblin().position).is_equal(goblin_start)
	assert_object(_state().active()).is_same(_goblin())

	get_tree().paused = false
	await _settle()
	assert_that(_goblin().position).is_not_equal(goblin_start)
	assert_object(_state().active()).is_same(_fighter())


func test_every_engine_event_has_a_display() -> void:
	await _start(FIGHTER_FIRST)
	var handlers: Dictionary = _scene.get("_event_handlers")
	var checked := 0
	# Note Godot : la liste des classes globales (`class_name`) donne pour
	# chacune son script et sa classe parente.
	for info: Dictionary in ProjectSettings.get_global_class_list():
		if info["base"] != &"CombatEvent":
			continue
		checked += 1
		assert_bool(handlers.has(load(info["path"]))) \
			.override_failure_message("Événement sans affichage : %s" % info["class"]) \
			.is_true()
	assert_int(checked).is_greater(0)

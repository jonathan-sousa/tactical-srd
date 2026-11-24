## Scène de combat : déroulement d'un tour, fin de combat, pause.
##
## La scène est instanciée à la main pour lui donner des dés truqués avant son
## `_ready`, qui lance aussitôt l'initiative. Les clics sont simulés en
## appelant directement les gestionnaires du contrôleur : on teste ce qu'ils
## déclenchent, pas la conversion pixel → case (celle de BoardView).
extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const COMBAT_SCENE := "res://scenes/combat/combat.tscn"
## Embuscade : le Gobelin tente d'abord de se cacher (1 + 6 = 7, raté, pas
## de surprise). Puis l'initiative : le d20 du Guerrier, puis celui du Gobelin.
const FIGHTER_FIRST: Array[int] = [1, 20, 1]
const GOBLIN_FIRST: Array[int] = [1, 1, 20]
## Embuscade réussie (12 + 6 = 18) : Guerrier surpris (20 et 20), Gobelin
## caché (1 et 1). Le Guerrier commence quand même.
const AMBUSHED_FIGHTER_FIRST: Array[int] = [12, 20, 20, 1, 1]

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


func _reaction_panel() -> Control:
	return _scene.get_node("%DecisionPanel")


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
		if _reaction_panel().visible:
			return
	fail("Le combat ne rend jamais la main.")


## Place le Gobelin juste à droite du Guerrier, pour tester une attaque sans
## dépendre des déplacements.
func _put_goblin_next_to_fighter() -> void:
	var cell := _fighter().position + Vector2i(1, 0)
	assert_object(_state().combatant_at(cell)).is_null()
	_place_goblin(cell)


## Déplace le Gobelin dans le moteur et son pion avec lui : les clics visent
## les pions affichés.
func _place_goblin(cell: Vector2i) -> void:
	_goblin().position = cell
	var token: TokenView = _scene.get("_tokens")[_goblin()]
	token.cell = cell
	token.position = (_scene.get_node("%Board") as BoardView).cell_center(cell)


func test_combat_scene_starts() -> void:
	await _start(FIGHTER_FIRST)
	assert_int(_state().round).is_equal(1)
	assert_object(_state().active()).is_same(_fighter())
	assert_int(_state().combatants.size()).is_equal(2)


func test_player_moves_then_ends_turn_and_goblin_plays() -> void:
	# Des 1 naturels pour le Gobelin : il rate sa cachette et son tir.
	await _start(FIGHTER_FIRST + [1, 1, 1])
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
	# Coup critique (20 naturel) puis 4d6 à 6, deux fois (Savage Attacker) :
	# 27 dégâts, le Gobelin tombe.
	await _start(FIGHTER_FIRST + [20, 6, 6, 6, 6, 6, 6, 6, 6])
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
	GameState.player_second_wind_uses = 1
	GameState.player_heroic_inspiration = false
	var reported: Array = []
	_scene = auto_free(load(COMBAT_SCENE).instantiate())
	_scene.set("dice", _fixed_dice(FIGHTER_FIRST + [20, 6, 6, 6, 6, 6, 6, 6, 6]))
	_scene.set("end_delay", 0.0)
	_scene.set("on_story_end", func(outcome: int, survivor: Combatant) -> void: reported.append([outcome, survivor.hp]))
	_runner = scene_runner(_scene)
	await _settle()
	# Les PV et ressources restants de l'histoire sont repris.
	assert_int(_fighter().hp).is_equal(7)
	assert_int(_fighter().second_wind_uses).is_equal(1)
	assert_bool(_fighter().heroic_inspiration).is_false()

	_put_goblin_next_to_fighter()
	_scene.call("_on_cell_clicked", _goblin().position)
	await _settle()
	await _runner.simulate_frames(2)
	assert_array(reported).is_equal([[GameState.Outcome.VICTORY, 7]])
	assert_bool((_scene.get_node("%ResultPanel") as Control).visible).is_false()


func test_pause_freezes_the_enemy_turn() -> void:
	await _start(GOBLIN_FIRST + [1, 1, 1], 0.5)
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


func test_action_bar_key_makes_the_fighter_dodge() -> void:
	await _start(FIGHTER_FIRST)
	_runner.simulate_key_pressed(KEY_3)
	await _settle()
	assert_bool(_state().has_effect(_fighter(), Effect.DODGING)).is_true()
	assert_bool(_state().action_used).is_true()
	# Les actions sont grisées ; Second souffle (action bonus) reste possible.
	var buttons: Dictionary = _scene.get("_action_buttons")
	for kind: StringName in StandardAction.ALL:
		assert_bool((buttons[kind] as Button).disabled).is_true()
	assert_bool((buttons[Texts.SECOND_WIND_ID] as Button).disabled).is_false()


func test_goblin_reacts_when_the_fighter_walks_away() -> void:
	# 1 naturel : l'attaque d'opportunité du Gobelin rate.
	await _start(FIGHTER_FIRST + [1])
	_put_goblin_next_to_fighter()
	var away := _fighter().position + Vector2i(-1, 0)
	_scene.call("_on_cell_clicked", away)
	await _settle()
	assert_that(_fighter().position).is_equal(away)
	assert_bool(_goblin().reaction_available).is_false()
	assert_bool(_reaction_panel().visible).is_false()


## Le tour du Gobelin est mis en attente (long délai), puis on le fait
## s'éloigner du Guerrier directement dans le moteur, pour tester la question
## posée au joueur sans dépendre des choix de l'IA.
func _goblin_walks_away_from_fighter(dice: Array) -> void:
	await _start(GOBLIN_FIRST + dice, 100.0)
	await _runner.simulate_frames(2)
	_put_goblin_next_to_fighter()
	# (3,5) : libre, et le premier pas sort déjà de l'allonge du Guerrier en (1,3).
	var away := _goblin().position + Vector2i(1, 2)
	MoveAction.new(_goblin(), away).execute(_state(), _scene.get("dice"))
	assert_object(_state().pending).is_not_null()
	_scene.call("_resolve_decisions")
	await _runner.simulate_frames(2)


func test_player_is_asked_and_accepts_the_opportunity_attack() -> void:
	# 15 + 5 = 20 contre CA 15, touché ; 2d6+3 avec 1 et 1, relevés à 3 par
	# Great Weapon Fighting, deux fois (Savage Attacker) : 9 dégâts.
	await _goblin_walks_away_from_fighter([15, 1, 1, 1, 1])
	assert_bool(_reaction_panel().visible).is_true()
	var question: Label = _scene.get_node("%DecisionQuestionLabel")
	assert_str(question.text).is_equal(Texts.reaction_prompt(_goblin()))

	_runner.simulate_key_pressed(KEY_O)
	await _runner.simulate_frames(40, 50)
	assert_bool(_reaction_panel().visible).is_false()
	assert_int(_goblin().hp).is_equal(1)
	assert_bool(_fighter().reaction_available).is_false()
	assert_object(_state().pending).is_null()


func test_player_can_decline_the_opportunity_attack() -> void:
	await _goblin_walks_away_from_fighter([])
	_runner.simulate_key_pressed(KEY_N)
	await _runner.simulate_frames(40, 50)
	assert_bool(_reaction_panel().visible).is_false()
	assert_int(_goblin().hp).is_equal(10)
	assert_bool(_fighter().reaction_available).is_true()
	assert_object(_state().pending).is_null()


func test_second_wind_key_heals_the_fighter() -> void:
	# 1d10 + 1 : 5 + 1 = 6 PV.
	await _start(FIGHTER_FIRST + [5])
	_fighter().hp = 4
	_runner.simulate_key_pressed(KEY_4)
	await _settle()
	assert_int(_fighter().hp).is_equal(10)
	assert_bool(_state().bonus_action_used).is_true()
	assert_bool(_state().action_used).is_false()


func test_missed_attack_offers_heroic_inspiration() -> void:
	# 2 + 5 = 7 : raté. Relance : 15, touché, 2d6 à 4 et 4 deux fois : 11.
	await _start(FIGHTER_FIRST + [2, 15, 4, 4, 4, 4])
	_put_goblin_next_to_fighter()
	_scene.call("_on_cell_clicked", _goblin().position)
	await _settle()
	assert_bool(_reaction_panel().visible).is_true()
	var question: Label = _scene.get_node("%DecisionQuestionLabel")
	assert_str(question.text).contains("Relancer")

	_runner.simulate_key_pressed(KEY_O)
	await _settle()
	assert_bool(_fighter().heroic_inspiration).is_false()
	assert_bool(_state().is_over).is_true()


func test_choosing_the_javelin_throws_it_at_range() -> void:
	# 15 + 5 : touché à 25 ft ; 1d6 à 1 et 1 (Savage Attacker) : 4 dégâts.
	await _start(FIGHTER_FIRST + [15, 1, 1])
	_place_goblin(_fighter().position + Vector2i(5, 1))
	var javelin: WeaponDef = _fighter().definition.weapons[2]
	_scene.call("_on_weapon_pressed", javelin)
	_scene.call("_on_cell_clicked", _goblin().position)
	await _settle()
	assert_int(_fighter().quantity(javelin)).is_equal(7)
	assert_int(_goblin().hp).is_equal(6)
	assert_bool(_state().has_effect(_goblin(), Effect.SLOWED)).is_true()


func test_ambush_shows_the_hidden_goblin_as_a_ghost_until_found() -> void:
	await _start(AMBUSHED_FIGHTER_FIRST + [20])
	var token: TokenView = _scene.get("_tokens")[_goblin()]
	assert_bool(_state().is_hidden(_goblin())).is_true()
	assert_bool(token.is_ghost).is_true()
	# Chercher (touche 5) : 20 + 3 = 23, au-dessus de sa Discrétion (18).
	_runner.simulate_key_pressed(KEY_5)
	await _settle()
	assert_bool(_state().is_hidden(_goblin())).is_false()
	assert_bool(token.is_ghost).is_false()


func test_clicking_the_ghost_attacks_blindly() -> void:
	# Désavantage : 10 et 10, 15 contre CA 15 : touché. 2d6 + 3 deux fois
	# (Savage Attacker), tout à 6 : 15 dégâts, le Gobelin meurt.
	await _start(AMBUSHED_FIGHTER_FIRST + [10, 10, 6, 6, 6, 6])
	var cell := _fighter().position + Vector2i(1, 0)
	_place_goblin(cell)
	_scene.call("_on_cell_clicked", cell)
	await _settle()
	assert_bool(_goblin().is_dead).is_true()
	assert_bool(_state().is_over).is_true()


func test_unconscious_player_turn_passes_with_a_death_save() -> void:
	# Le Gobelin tire sur le Guerrier inconscient et rate (1), puis le
	# troisième succès (10) stabilise le Guerrier : défaite.
	await _start(FIGHTER_FIRST + [1, 10])
	HitPoints.apply_damage(_state(), _fighter(), 12, DamageType.Type.SLASHING)
	_fighter().death_save_successes = 2
	_scene.call("_continue")
	await _settle()
	assert_bool(_fighter().is_stable).is_true()
	assert_bool(_state().is_over).is_true()
	assert_str((_scene.get_node("%ResultLabel") as Label).text).is_equal(Texts.DEFEAT)


func test_hovering_an_enemy_shows_hit_chance_and_target_panel() -> void:
	await _start(FIGHTER_FIRST)
	_put_goblin_next_to_fighter()
	_scene.call("_on_cell_hovered", _goblin().position)
	var hint: Label = _scene.get_node("%HintLabel")
	# Épée + 5 contre CA 15 : 55 %, 2d6 + 3 avec Great Weapon Fighting.
	assert_str(hint.text).contains("55 % de toucher, 9 à 15 dégâts")
	var target: Label = _scene.get_node("%TargetLabel")
	assert_str(target.text).starts_with("Gobelin guerrier · PV 10 / 10 · CA 15")


func test_path_out_of_reach_warns_of_an_opportunity_attack() -> void:
	await _start(FIGHTER_FIRST)
	_put_goblin_next_to_fighter()
	var away := _fighter().position + Vector2i(-1, 0)
	_scene.call("_on_cell_hovered", away)
	assert_str((_scene.get_node("%HintLabel") as Label).text).contains("attaque d'opportunité de Gobelin guerrier")
	assert_bool((_scene.get_node("%Board") as BoardView).path_warning).is_true()


func test_hit_shows_floating_damage() -> void:
	await _start(FIGHTER_FIRST + [15, 1, 1, 1, 1])
	_put_goblin_next_to_fighter()
	_scene.call("_on_cell_clicked", _goblin().position)
	# Élan puis clignotement (environ 0,45 s), puis le « −9 » apparaît.
	await _runner.simulate_frames(12, 50)
	var floating := 0
	for child in (_scene.get_node("%Tokens") as Node).get_children():
		if child is FloatingText:
			floating += 1
	assert_int(floating).is_greater(0)


func test_board_is_built_from_tiles() -> void:
	await _start(FIGHTER_FIRST)
	var board: BoardView = _scene.get_node("%Board")
	var floor_layer: TileMapLayer = board.get_node("Floor")
	var obstacles: TileMapLayer = board.get_node("Obstacles")
	var encounter := _state().encounter
	assert_int(floor_layer.get_used_cells().size()).is_equal(encounter.grid_size.x * encounter.grid_size.y)
	assert_array(obstacles.get_used_cells()).contains_exactly_in_any_order(encounter.blocked_cells)
	# Le plateau suit la zone que l'interface lui réserve.
	var area: Control = _scene.get_node("%BoardArea")
	assert_that(board.position).is_equal(area.global_position)

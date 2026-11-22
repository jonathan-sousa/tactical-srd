## Chef d'orchestre de la scène de combat.
##
## Il traduit les clics en actions, les fait valider et exécuter par le
## moteur (rules/), puis rejoue les événements renvoyés : journal, animations,
## rafraîchissement des vues. Il ne calcule jamais une règle lui-même.
##
## Dans l'histoire, la rencontre vient de l'étape courante (GameState). La
## scène se lance aussi seule (F6 dans l'éditeur) avec la rencontre et le
## personnage indiqués dans l'inspecteur.
extends Node

## Émis quand le combat se termine.
signal combat_finished(winner: Combatant.Side)

const ENEMY_ACTION_DELAY := 0.45
## Pause avant de quitter le combat, le temps de lire la dernière ligne.
const END_DELAY := 1.5
const LOG_TURN_COLOR := Color(1.0, 0.85, 0.3)
const LOG_MUTED_COLOR := Color(0.6, 0.6, 0.6)
const LOG_DOWN_COLOR := Color(1.0, 0.45, 0.4)

# Note Godot : @export rend la variable réglable dans l'inspecteur, pour
# chaque instance de la scène.
@export var encounter_id: StringName = &"goblin_ambush"
@export var player_id: StringName = &"fighter_lvl1"

var state: CombatState

var _dice := Dice.new()
var _player: Combatant
var _tokens: Dictionary[Combatant, TokenView] = {}
## Vrai pendant qu'une action se joue : les clics sont ignorés.
var _busy := false
var _pulse: Tween
## Vrai quand le combat fait partie de l'histoire (et non lancé seul).
var _story_mode := false

# Note Godot : `%Nom` retrouve un nœud marqué « nom unique » dans la scène,
# sans dépendre de son chemin exact. @onready attend que la scène soit prête.
@onready var _board: BoardView = %Board
@onready var _tokens_root: Node2D = %Tokens
@onready var _initiative_bar: InitiativeBar = %InitiativeBar
@onready var _panel: CharacterPanel = %CharacterPanel
@onready var _log: CombatLog = %CombatLog
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _hint_label: Label = %HintLabel
@onready var _result_panel: PanelContainer = %ResultPanel
@onready var _result_label: Label = %ResultLabel
@onready var _replay_button: Button = %ReplayButton


func _ready() -> void:
	var encounter: EncounterDef
	var player_definition: CharacterDef
	var player_hp := -1
	var step := GameState.current_step()
	if step != null and step.kind == StoryStep.Kind.ENCOUNTER:
		_story_mode = true
		encounter = step.encounter
		player_definition = GameState.player_definition()
		player_hp = GameState.player_hp
	else:
		var registry := GameState.registry
		encounter = registry.encounter(encounter_id)
		player_definition = registry.character(player_id)
	if encounter == null or player_definition == null:
		push_error("Combat : rencontre « %s » ou personnage « %s » introuvable." % [encounter_id, player_id])
		return

	state = CombatState.create(encounter, player_definition, player_hp)
	_player = state.combatants[0]
	_board.setup(encounter)
	for combatant in state.combatants:
		var token := TokenView.new()
		token.setup(combatant, _board.cell_center(combatant.position))
		_tokens_root.add_child(token)
		_tokens[combatant] = token

	# Note Godot : connecter un signal = s'abonner à un événement (callback).
	_board.cell_clicked.connect(_on_cell_clicked)
	_board.cell_hovered.connect(_on_cell_hovered)
	_end_turn_button.text = "%s (Espace)" % Texts.END_TURN
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_replay_button.text = Texts.REPLAY
	_replay_button.pressed.connect(_on_replay_pressed)
	_result_panel.hide()

	_start_combat()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("end_turn"):
		get_viewport().set_input_as_handled()
		_on_end_turn_pressed()


# --- Déroulement -------------------------------------------------------------


func _start_combat() -> void:
	_busy = true
	await _play(state.start(_dice))
	_busy = false
	await _continue()


## Après chaque action : fin de combat, tour de l'IA, ou main au joueur.
func _continue() -> void:
	_refresh()
	if state.is_over:
		_show_result()
	elif state.active().side == Combatant.Side.ENEMY:
		await _play_enemy_turn()


func _play_enemy_turn() -> void:
	_busy = true
	_refresh()
	_hint_label.text = Texts.ENEMY_TURN
	for action in EnemyAI.plan_turn(state, state.active()):
		await get_tree().create_timer(ENEMY_ACTION_DELAY).timeout
		if not action.validate(state).is_empty():
			continue
		await _play(action.execute(state, _dice))
		if state.is_over:
			break
	_busy = false
	_hint_label.text = ""
	await _continue()


## Le joueur tente une action : refusée avec sa raison, ou jouée.
func _perform(action: Action) -> void:
	var reason := action.validate(state)
	if not reason.is_empty():
		_hint_label.text = Texts.reason(reason)
		return
	_busy = true
	_board.path_preview = []
	_hint_label.text = ""
	_refresh()
	await _play(action.execute(state, _dice))
	_busy = false
	await _continue()


# --- Rejeu des événements ----------------------------------------------------


func _play(events: Array[CombatEvent]) -> void:
	for event in events:
		await _play_event(event)


func _play_event(event: CombatEvent) -> void:
	# Note GDScript : `is` teste le type, `as` convertit vers ce type pour
	# profiter du typage statique dans chaque branche.
	if event is InitiativeRolledEvent:
		var rolled := event as InitiativeRolledEvent
		_initiative_bar.set_order(rolled.entries)
		_log.add_line(Texts.initiative_line(rolled.entries), LOG_MUTED_COLOR)
	elif event is TurnStartedEvent:
		var turn := event as TurnStartedEvent
		_log.add_line(Texts.turn_line(turn), LOG_TURN_COLOR)
		for combatant: Combatant in _tokens:
			_tokens[combatant].is_active = combatant == turn.combatant
		_refresh()
	elif event is MovedEvent:
		var moved := event as MovedEvent
		_log.add_line(Texts.move_line(moved))
		var points: Array[Vector2] = []
		for cell in moved.path:
			points.append(_board.cell_center(cell))
		await _tokens[moved.combatant].move_along(points)
	elif event is AttackRolledEvent:
		var result := (event as AttackRolledEvent).result
		_log.add_line(Texts.attack_line(result))
		await _tokens[result.attacker].lunge(_tokens[result.target].position)
		if result.is_hit:
			await _tokens[result.target].flash()
	elif event is DamageDealtEvent:
		_tokens[(event as DamageDealtEvent).target].refresh()
		_refresh()
	elif event is CombatantDownedEvent:
		var downed := (event as CombatantDownedEvent).combatant
		_log.add_line(Texts.downed_line(downed), LOG_DOWN_COLOR)
		await _tokens[downed].fall()
	elif event is CombatEndedEvent:
		var winner := (event as CombatEndedEvent).winner
		_log.add_line(Texts.end_line(winner), LOG_TURN_COLOR)
		combat_finished.emit(winner)


# --- Saisie du joueur ----------------------------------------------------------


func _is_player_turn() -> bool:
	return not _busy and not state.is_over and state.active() == _player


func _on_cell_clicked(cell: Vector2i) -> void:
	if not _is_player_turn():
		return
	var target := state.combatant_at(cell)
	if target == null:
		_perform(MoveAction.new(_player, cell))
	elif target != _player:
		_perform(AttackAction.new(_player, target))


func _on_cell_hovered(cell: Vector2i) -> void:
	if not _is_player_turn():
		return
	_board.path_preview = []
	_hint_label.text = ""
	if cell == BoardView.NO_CELL or cell == _player.position:
		return

	var target := state.combatant_at(cell)
	if target != null:
		var attack := AttackAction.new(_player, target)
		var reason := attack.validate(state)
		_hint_label.text = Texts.reason(reason) if not reason.is_empty() else _attack_hint(attack)
		return

	var move := MoveAction.new(_player, cell)
	var reason := move.validate(state)
	if reason.is_empty():
		_board.path_preview = state.find_path(_player, cell)
		_hint_label.text = "%s : %s" % [Texts.MOVEMENT, Texts.squares(_board.path_preview.size())]
	else:
		_hint_label.text = Texts.reason(reason)


func _attack_hint(attack: AttackAction) -> String:
	var expression := DiceExpression.parse(attack.weapon.damage_dice).with_modifier(_player.damage_modifier(attack.weapon))
	return "Attaquer %s : %s, %s %s" % [
		attack.target.definition.display_name,
		attack.weapon.display_name,
		Texts.signed(_player.attack_bonus(attack.weapon)),
		expression,
	]


func _on_end_turn_pressed() -> void:
	if _is_player_turn():
		_perform(EndTurnAction.new(_player))


# --- Affichage -----------------------------------------------------------------


func _refresh() -> void:
	_panel.refresh(_player, state)
	_initiative_bar.refresh(state.active())

	var player_turn := _is_player_turn()
	var reachable: Dictionary[Vector2i, int] = {}
	if player_turn:
		reachable = state.reachable_cells()
	_board.reachable = reachable
	var attackable: Array[Vector2i] = []
	if player_turn:
		for enemy in state.living_enemies_of(_player):
			if AttackAction.new(_player, enemy).validate(state).is_empty():
				attackable.append(enemy.position)
	_board.attackable = attackable

	# Bouton « Fin de tour » grisé hors du tour du joueur, avec la raison.
	var end_turn_reason := EndTurnAction.new(_player).validate(state)
	_end_turn_button.disabled = _busy or not end_turn_reason.is_empty()
	_end_turn_button.tooltip_text = Texts.reason(end_turn_reason) if not end_turn_reason.is_empty() else ""

	# Plus rien à faire : le bouton pulse pour inviter à finir le tour.
	var nothing_left := player_turn and state.action_used and state.movement_left == 0
	_set_pulse(nothing_left)
	if nothing_left:
		_hint_label.text = Texts.NOTHING_LEFT


func _set_pulse(enabled: bool) -> void:
	if _pulse != null:
		_pulse.kill()
		_pulse = null
	_end_turn_button.modulate = Color.WHITE
	if enabled:
		_pulse = create_tween().set_loops()
		_pulse.tween_property(_end_turn_button, "modulate", Color(1.4, 1.25, 0.6), 0.5)
		_pulse.tween_property(_end_turn_button, "modulate", Color.WHITE, 0.5)


func _show_result() -> void:
	if _story_mode:
		await _leave_combat()
		return
	_set_pulse(false)
	var nothing: Dictionary[Vector2i, int] = {}
	_board.reachable = nothing
	_board.attackable = []
	_result_label.text = Texts.VICTORY if state.winner == Combatant.Side.PLAYER else Texts.DEFEAT
	_result_panel.show()
	_replay_button.grab_focus()


## Dans l'histoire : victoire → étape suivante, défaite → écran de défaite.
func _leave_combat() -> void:
	_set_pulse(false)
	await get_tree().create_timer(END_DELAY).timeout
	if state.winner == Combatant.Side.PLAYER:
		GameState.finish_step(GameState.Outcome.VICTORY, _player.hp)
	else:
		GameState.finish_step(GameState.Outcome.DEFEAT)


func _on_replay_pressed() -> void:
	SceneRouter.go_to(SceneRouter.COMBAT)

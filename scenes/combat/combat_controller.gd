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
## Émis quand le joueur répond à une question (réaction, relance).
signal decision_answered(accepted: bool)

## Touches de la barre d'actions, dans l'ordre des boutons.
const ACTION_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]
## Touches des armes, par position physique (les trois premières lettres de
## la rangée du haut : A Z E en AZERTY, Q W E en QWERTY).
const WEAPON_KEYS: Array[Key] = [KEY_Q, KEY_W, KEY_E]

const LOG_TURN_COLOR := Palette.GOLD
const LOG_MUTED_COLOR := Palette.MUTED
const LOG_DOWN_COLOR := Palette.DANGER
const LOG_HEAL_COLOR := Palette.HEAL
const FLOAT_DAMAGE_COLOR := Color(1.0, 0.45, 0.35)
const FLOAT_HEAL_COLOR := Color(0.5, 1.0, 0.55)
const FLOAT_MISS_COLOR := Color(0.85, 0.85, 0.9)
const FLOAT_CRITICAL_COLOR := Palette.GOLD
## Secousse du plateau sur un coup critique : amplitude en pixels, durée.
const SHAKE_STRENGTH := 6.0
const SHAKE_DURATION := 0.25

# Note Godot : @export rend la variable réglable dans l'inspecteur, pour
# chaque instance de la scène.
@export var encounter_id: StringName = &"goblin_ambush"
@export var player_id: StringName = &"fighter_lvl1"
## Pause avant chaque action de l'adversaire, en secondes.
@export var enemy_action_delay := 0.45
## Pause avant de quitter le combat, le temps de lire la dernière ligne.
@export var end_delay := 1.5

var state: CombatState
## Source de hasard du combat. Les tests la remplacent par des dés truqués
## avant d'ajouter la scène à l'arbre ; sinon `_ready` en crée (à graine en
## mode démo, voir Autoplay).
var dice: Dice
## Ce qui se passe à la fin d'un combat de l'histoire. Par défaut,
## GameState.finish_step ; les tests le remplacent pour ne pas changer de scène.
var on_story_end: Callable
var _player: Combatant
var _tokens: Dictionary[Combatant, TokenView] = {}
## Vrai pendant qu'une action se joue : les clics sont ignorés.
var _busy := false
var _pulse: Tween
## Vrai quand le combat fait partie de l'histoire (et non lancé seul).
var _story_mode := false
## Aiguillage des événements : type d'événement → méthode qui le rejoue.
var _event_handlers: Dictionary[Script, Callable] = {}

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
@onready var _action_bar: GridContainer = %ActionBar
@onready var _weapon_bar: HBoxContainer = %WeaponBar
@onready var _decision_panel: PanelContainer = %DecisionPanel
@onready var _decision_question: Label = %DecisionQuestionLabel
@onready var _decision_yes: Button = %DecisionYesButton
@onready var _decision_no: Button = %DecisionNoButton
@onready var _target_label: Label = %TargetLabel
@onready var _board_area: Control = %BoardArea

## Boutons de la barre d'actions, par code d'action, et l'action que chacun
## propose (une fonction qui la construit).
var _action_buttons: Dictionary[StringName, Button] = {}
var _action_factories: Dictionary[StringName, Callable] = {}
## Arme choisie pour attaquer, et les boutons des armes.
var _weapon: WeaponDef
var _weapon_buttons: Dictionary[WeaponDef, Button] = {}
## Lettre de la touche de chaque arme, calculée une fois.
var _weapon_key_labels: Array[String] = []
## Ennemi survolé, montré dans le panneau de la cible (sinon le premier
## ennemi vivant).
var _hovered_enemy: Combatant
## Dernier round annoncé dans le journal.
var _logged_round := 0
## Position de repos du plateau, que la secousse retrouve.
var _board_origin: Vector2


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
		if _story_mode:
			push_error("Combat : l'étape « %s » n'a pas de rencontre ou la fiche du joueur est introuvable." % GameState.current_step_id)
		else:
			push_error("Combat : rencontre « %s » ou personnage « %s » introuvable." % [encounter_id, player_id])
		return
	if not on_story_end.is_valid():
		on_story_end = GameState.finish_step
	if dice == null:
		dice = Autoplay.make_dice()
	_register_event_handlers()

	state = CombatState.create(encounter, player_definition, player_hp)
	_player = state.combatants[0]
	if _story_mode:
		# Ressources sans repos dans l'histoire : on reprend celles qui restent.
		_player.second_wind_uses = GameState.player_second_wind_uses
		_player.heroic_inspiration = GameState.player_heroic_inspiration
	_weapon = _player.melee_weapon()
	_board.setup(encounter)
	# Le plateau (un Node2D) suit la place que lui réserve l'interface.
	# Note Godot : `item_rect_changed` est émis quand un Control change de
	# position ou de taille, par exemple quand son conteneur le place.
	_board_area.item_rect_changed.connect(_place_board)
	_place_board()
	_apply_text_size()
	Settings.large_text_changed.connect(func(_enabled: bool) -> void: _apply_text_size())
	for combatant in state.combatants:
		var token := TokenView.new()
		token.setup(combatant, combatant.position, _board.cell_center(combatant.position))
		_tokens_root.add_child(token)
		_tokens[combatant] = token
		token.stepped.connect(AudioManager.play.bind(AudioManager.STEP))

	# Note Godot : connecter un signal = s'abonner à un événement (callback).
	_board.cell_clicked.connect(_on_cell_clicked)
	_board.cell_hovered.connect(_on_cell_hovered)
	_end_turn_button.text = Texts.END_TURN_WITH_KEY
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_replay_button.text = Texts.REPLAY
	_replay_button.pressed.connect(_on_replay_pressed)
	_result_panel.hide()
	_build_weapon_bar()
	_build_action_bar()
	_decision_yes.text = "%s (O)" % Texts.YES
	_decision_no.text = "%s (N)" % Texts.NO
	_decision_yes.shortcut = _key_shortcut(KEY_O)
	_decision_no.shortcut = _key_shortcut(KEY_N)
	_decision_yes.pressed.connect(func() -> void: decision_answered.emit(true))
	_decision_no.pressed.connect(func() -> void: decision_answered.emit(false))
	_decision_panel.hide()

	_start_combat()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("end_turn"):
		get_viewport().set_input_as_handled()
		_on_end_turn_pressed()


# --- Déroulement -------------------------------------------------------------


func _start_combat() -> void:
	AudioManager.play_music(AudioManager.COMBAT_MUSIC)
	_busy = true
	await _play(state.start(dice))
	_busy = false
	await _continue()


## Après chaque action : fin de combat, tour de l'IA, tour d'un joueur
## inconscient, ou main au joueur.
func _continue() -> void:
	_refresh()
	if state.is_over:
		_show_result()
	elif state.active().side == Combatant.Side.ENEMY:
		await _play_enemy_turn()
	elif state.active() == _player and _player.is_down():
		await _play_unconscious_turn()
	elif Autoplay.enabled:
		# Mode démo : l'IA joue aussi le Guerrier.
		await _play_ai_turn()


## L'IA choisit une action à la fois, jusqu'à finir son tour.
func _play_enemy_turn() -> void:
	_hint_label.text = Texts.ENEMY_TURN
	await _play_ai_turn()


## Tour joué par l'IA : celui du Gobelin, ou du Guerrier en mode démo.
func _play_ai_turn() -> void:
	_busy = true
	_refresh()
	var actor := state.active()
	for i in EnemyAI.MAX_ACTIONS_PER_TURN:
		if state.is_over or state.active() != actor:
			break
		await _wait(enemy_action_delay)
		var action := EnemyAI.next_action(state, actor)
		var reason := action.validate(state)
		if not reason.is_empty():
			push_error("IA : action refusée (%s), fin du tour." % reason)
			action = EndTurnAction.new(actor)
		await _play(action.execute(state, dice))
		await _resolve_decisions()
	_busy = false
	_hint_label.text = ""
	await _continue()


## Inconscient, le joueur ne peut rien faire : son jet contre la mort a
## déjà eu lieu au début du tour, qui se termine tout seul.
func _play_unconscious_turn() -> void:
	_busy = true
	_hint_label.text = Texts.UNCONSCIOUS_TURN
	await _wait(enemy_action_delay)
	_busy = false
	await _perform(EndTurnAction.new(_player))


## Tant qu'une décision est en attente : le joueur choisit si elle le
## concerne, l'IA sinon. Une réponse peut en ouvrir une autre (attaque
## d'opportunité ratée, puis relance), d'où la boucle.
func _resolve_decisions() -> void:
	while state.pending != null and not state.is_over:
		var decision := state.pending
		var answer: Action
		if decision.decider == _player and not Autoplay.enabled:
			answer = await _ask_player(decision)
		else:
			await _wait(enemy_action_delay)
			answer = EnemyAI.decide(state)
		await _play(answer.execute(state, dice))


## Pose au joueur la question qui correspond à la décision, et renvoie
## l'action qui traduit sa réponse.
func _ask_player(decision: PendingDecision) -> Action:
	if decision is InspirationWindow:
		var window := decision as InspirationWindow
		var question := Texts.death_save_inspiration_prompt(window.death_save) if window.result == null \
			else Texts.inspiration_prompt(window.result)
		if await _ask(question):
			return UseInspirationAction.new(_player)
		return DeclineInspirationAction.new(_player)
	var mover := (decision as ReactionWindow).mover
	if await _ask(Texts.reaction_prompt(mover)):
		return OpportunityAttackAction.new(_player)
	return DeclineReactionAction.new(_player)


## Affiche une question Oui / Non et attend la réponse du joueur.
func _ask(question: String) -> bool:
	_decision_question.text = question
	_decision_panel.show()
	_decision_yes.grab_focus()
	# Note GDScript : `await` sur un signal attend son émission et renvoie
	# ses arguments (ici le booléen de la réponse).
	var accepted: bool = await decision_answered
	_decision_panel.hide()
	return accepted


## Le joueur tente une action : refusée avec sa raison, ou jouée.
func _perform(action: Action) -> void:
	var reason := action.validate(state)
	if not reason.is_empty():
		_hint_label.text = Texts.reason(reason)
		AudioManager.play(AudioManager.REFUSED)
		return
	_busy = true
	_board.path_preview = []
	_hint_label.text = ""
	_refresh()
	await _play(action.execute(state, dice))
	await _resolve_decisions()
	_busy = false
	await _continue()


# --- Rejeu des événements ----------------------------------------------------


func _play(events: Array[CombatEvent]) -> void:
	for event in events:
		await _play_event(event)


func _play_event(event: CombatEvent) -> void:
	var handler: Callable = _event_handlers.get(event.get_script(), Callable())
	if not handler.is_valid():
		push_error("Combat : aucun affichage pour l'événement %s." % event.get_script().get_global_name())
		return
	# Note GDScript : `await` sur un appel qui n'attend rien rend la main
	# aussitôt ; on peut donc traiter tous les gestionnaires de la même façon.
	await handler.call(event)


# Note Godot : un nom de classe (`class_name`) désigne aussi son script, qui
# sert ici de clé. `event.get_script()` renvoie le script exact de l'objet.
func _register_event_handlers() -> void:
	_event_handlers = {
		InitiativeRolledEvent: _on_initiative_rolled,
		TurnStartedEvent: _on_turn_started,
		MovedEvent: _on_moved,
		AttackRolledEvent: _on_attack_rolled,
		DamageDealtEvent: _on_damage_dealt,
		CombatantDownedEvent: _on_combatant_downed,
		CombatEndedEvent: _on_combat_ended,
		ActionTakenEvent: _on_action_taken,
		EffectEndedEvent: _on_effect_ended,
		ReactionTriggeredEvent: _on_reaction_triggered,
		ReactionDeclinedEvent: _on_reaction_declined,
		EffectAppliedEvent: _on_effect_applied,
		HealedEvent: _on_healed,
		InspirationUsedEvent: _on_inspiration_used,
		HideAttemptedEvent: _on_hide_attempted,
		RevealedEvent: _on_revealed,
		SearchedEvent: _on_searched,
		AttackedEmptyCellEvent: _on_attacked_empty_cell,
		DeathSaveEvent: _on_death_save,
		CombatantStabilizedEvent: _on_combatant_stabilized,
		CombatantDiedEvent: _on_combatant_died,
	}


func _on_initiative_rolled(event: InitiativeRolledEvent) -> void:
	_initiative_bar.set_order(event.entries)
	_log.add_line(Texts.initiative_line(event.entries), LOG_MUTED_COLOR)


func _on_turn_started(event: TurnStartedEvent) -> void:
	if event.round != _logged_round:
		_logged_round = event.round
		_log.add_header(Texts.round_header(event.round))
	_log.add_line(Texts.turn_line(event), LOG_TURN_COLOR)
	for combatant: Combatant in _tokens:
		_tokens[combatant].is_active = combatant == event.combatant
	_refresh()


func _on_moved(event: MovedEvent) -> void:
	# Un ennemi caché se déplace sans être vu : son pion reste à sa
	# dernière position connue.
	if event.unseen and event.combatant.side != _player.side:
		return
	_log.add_line(Texts.move_line(event))
	var points: Array[Vector2] = []
	for cell in event.path:
		points.append(_board.cell_center(cell))
	var token := _tokens[event.combatant]
	token.cell = event.path.back()
	await token.move_along(points)


func _on_attack_rolled(event: AttackRolledEvent) -> void:
	var result := event.result
	_log.add_line(Texts.attack_summary(result))
	_log.add_detail(Texts.attack_detail(result))
	var target_token := _tokens[result.target]
	AudioManager.play(AudioManager.THROW if result.is_ranged else AudioManager.SWING)
	await _tokens[result.attacker].lunge(target_token.position)
	if not result.is_hit:
		AudioManager.play(AudioManager.MISS)
		_float(target_token.position, Texts.FLOAT_MISS, FLOAT_MISS_COLOR)
		return
	if result.is_critical:
		AudioManager.play(AudioManager.CRITICAL)
		_float(target_token.position + Vector2(0, -26), Texts.FLOAT_CRITICAL, FLOAT_CRITICAL_COLOR, 28)
		_shake()
	else:
		AudioManager.play(AudioManager.HIT)
	await target_token.flash()


func _on_damage_dealt(event: DamageDealtEvent) -> void:
	if event.is_graze:
		_log.add_line(Texts.graze_line(event))
		AudioManager.play(AudioManager.GRAZE)
		await _tokens[event.target].flash()
	_float(_tokens[event.target].position, "−%d" % event.amount, FLOAT_DAMAGE_COLOR)
	_tokens[event.target].refresh()
	_refresh()


func _on_effect_applied(event: EffectAppliedEvent) -> void:
	_log.add_line(Texts.effect_applied_line(event))
	_refresh()


func _on_healed(event: HealedEvent) -> void:
	_log.add_line(Texts.healed_line(event), LOG_HEAL_COLOR)
	_float(_tokens[event.combatant].position, "+%d" % event.amount, FLOAT_HEAL_COLOR)
	AudioManager.play(AudioManager.HEAL)
	_tokens[event.combatant].refresh()
	_refresh()


func _on_inspiration_used(event: InspirationUsedEvent) -> void:
	AudioManager.play(AudioManager.INSPIRATION)
	_log.add_line(Texts.inspiration_used_line(event), LOG_TURN_COLOR)


func _on_combatant_downed(event: CombatantDownedEvent) -> void:
	_log.add_line(Texts.downed_line(event.combatant), LOG_DOWN_COLOR)
	AudioManager.play(AudioManager.DOWN)
	_tokens[event.combatant].is_ghost = false
	await _tokens[event.combatant].fall()
	_refresh()


func _on_combatant_died(event: CombatantDiedEvent) -> void:
	_log.add_line(Texts.died_line(event), LOG_DOWN_COLOR)
	AudioManager.play(AudioManager.DEATH)
	_tokens[event.combatant].is_ghost = false
	await _tokens[event.combatant].die()
	_refresh()


func _on_combatant_stabilized(event: CombatantStabilizedEvent) -> void:
	_log.add_line(Texts.stabilized_line(event), LOG_MUTED_COLOR)
	_refresh()


func _on_death_save(event: DeathSaveEvent) -> void:
	var revived := event.revived
	_log.add_line(Texts.death_save_line(event), LOG_HEAL_COLOR if revived else LOG_DOWN_COLOR)
	AudioManager.play(AudioManager.HEAL if revived else AudioManager.DEATH_SAVE)
	if revived:
		await _tokens[event.combatant].rise()
	_tokens[event.combatant].refresh()
	_refresh()


func _on_hide_attempted(event: HideAttemptedEvent) -> void:
	_log.add_line(Texts.hide_line(event), LOG_MUTED_COLOR)
	if event.success:
		AudioManager.play(AudioManager.HIDE)
		_tokens[event.combatant].is_ghost = true
	_refresh()


## Révélé : le pion quitte sa dernière position connue pour sa vraie case.
func _on_revealed(event: RevealedEvent) -> void:
	_log.add_line(Texts.revealed_line(event), LOG_TURN_COLOR)
	AudioManager.play(AudioManager.REVEAL)
	var token := _tokens[event.combatant]
	token.cell = event.cell
	token.position = _board.cell_center(event.cell)
	token.is_ghost = false
	_refresh()


func _on_searched(event: SearchedEvent) -> void:
	_log.add_line(Texts.search_line(event))
	AudioManager.play(AudioManager.SEARCH)
	_refresh()


func _on_attacked_empty_cell(event: AttackedEmptyCellEvent) -> void:
	_log.add_line(Texts.empty_cell_attack_line(event))
	AudioManager.play(AudioManager.SWING)
	await _tokens[event.attacker].lunge(_board.cell_center(event.cell))
	_float(_board.cell_center(event.cell), Texts.FLOAT_MISS, FLOAT_MISS_COLOR)
	_refresh()


func _on_action_taken(event: ActionTakenEvent) -> void:
	_log.add_line(Texts.action_line(event))
	_refresh()


func _on_effect_ended(event: EffectEndedEvent) -> void:
	_log.add_line(Texts.effect_ended_line(event), LOG_MUTED_COLOR)
	_refresh()


func _on_reaction_triggered(event: ReactionTriggeredEvent) -> void:
	_log.add_line(Texts.reaction_triggered_line(event), LOG_MUTED_COLOR)


func _on_reaction_declined(event: ReactionDeclinedEvent) -> void:
	_log.add_line(Texts.reaction_declined_line(event), LOG_MUTED_COLOR)


func _on_combat_ended(event: CombatEndedEvent) -> void:
	if Autoplay.enabled:
		Autoplay.report("Résumé : %s au round %d, Guerrier %d / %d PV, Gobelin %d / %d PV." % [
			(Texts.VICTORY if event.winner == Combatant.Side.PLAYER else Texts.DEFEAT).to_lower(), state.round,
			_player.hp, _player.definition.max_hp,
			state.combatants[1].hp, state.combatants[1].definition.max_hp,
		])
	_log.add_line(Texts.end_line(event.winner), LOG_TURN_COLOR)
	AudioManager.play_jingle(AudioManager.VICTORY_JINGLE if event.winner == Combatant.Side.PLAYER else AudioManager.DEFEAT_JINGLE)
	combat_finished.emit(event.winner)


# --- Saisie du joueur ----------------------------------------------------------


func _is_player_turn() -> bool:
	return not _busy and not state.is_over and state.active() == _player


func _on_cell_clicked(cell: Vector2i) -> void:
	if not _is_player_turn():
		return
	var action := _action_for_cell(cell)
	if action != null:
		_perform(action)


## Ce que fait un clic sur une case, d'après ce que le joueur voit :
## attaquer l'ennemi affiché, attaquer à l'aveugle la dernière position
## connue d'un ennemi caché (ou toute case avec Maj), sinon s'y déplacer.
func _action_for_cell(cell: Vector2i) -> Action:
	if cell == _player.position:
		return null
	var shown := _enemy_token_at(cell)
	if shown != null and not state.is_hidden_from(shown, _player):
		return AttackAction.new(_player, shown, _weapon)
	var hidden_enemy := not state.hidden_enemies_of(_player).is_empty()
	if shown != null or (hidden_enemy and Input.is_key_pressed(KEY_SHIFT)):
		return AttackAction.at_cell(_player, cell, _weapon)
	return MoveAction.new(_player, cell)


## Ennemi vivant dont le pion est affiché sur cette case (éventuellement à
## sa dernière position connue, s'il est caché), ou `null`.
func _enemy_token_at(cell: Vector2i) -> Combatant:
	for combatant: Combatant in _tokens:
		if combatant.side != _player.side and not combatant.is_dead and _tokens[combatant].cell == cell:
			return combatant
	return null


func _on_cell_hovered(cell: Vector2i) -> void:
	if not _is_player_turn():
		return
	_board.path_preview = []
	_board.path_warning = false
	_hint_label.text = ""
	var shown := _enemy_token_at(cell) if cell != BoardView.NO_CELL else null
	if shown != _hovered_enemy:
		_hovered_enemy = shown
		_refresh_target()
	if cell == BoardView.NO_CELL or cell == _player.position:
		return

	var action := _action_for_cell(cell)
	var reason := action.validate(state)
	if action is AttackAction:
		var attack := action as AttackAction
		if not reason.is_empty():
			_hint_label.text = Texts.reason(reason)
		elif attack.is_blind():
			_hint_label.text = Texts.blind_attack_hint(attack.weapon)
		else:
			_hint_label.text = _attack_hint(attack)
		return

	if reason.is_empty():
		var path := state.find_path(_player, cell)
		var attackers := state.opportunity_attackers(_player, path)
		_board.path_warning = not attackers.is_empty()
		_board.path_preview = path
		_hint_label.text = Texts.move_hint(path.size(), attackers)
	else:
		_hint_label.text = Texts.reason(reason)
	if not state.hidden_enemies_of(_player).is_empty():
		_hint_label.text += "\n" + Texts.BLIND_ATTACK_SHIFT_HINT


## Aide au survol d'un ennemi : chances de toucher, dégâts possibles,
## raisons d'avantage ou de désavantage. Tout vient de la prévision du
## moteur (AttackEstimate).
func _attack_hint(attack: AttackAction) -> String:
	return Texts.attack_hint(attack.target, attack.weapon, AttackEstimate.of(state, _player, attack.target, attack.weapon))


## Un bouton par arme du personnage, avec sa touche. L'arme choisie sert à
## attaquer ; en changer ne coûte rien (voir docs/rules-deviations.md).
func _build_weapon_bar() -> void:
	var group := ButtonGroup.new()
	var weapons := _player.definition.weapons
	for i in weapons.size():
		var weapon := weapons[i]
		var button := _make_bar_button()
		button.add_theme_font_size_override(&"font_size", 16)
		# Noms courts : chaque bouton prend la largeur de son texte, sans « … ».
		button.clip_text = false
		button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		button.toggle_mode = true
		button.button_group = group
		if i < WEAPON_KEYS.size():
			button.shortcut = _key_shortcut(WEAPON_KEYS[i], true)
			_weapon_key_labels.append(_physical_key_label(WEAPON_KEYS[i]))
		button.pressed.connect(_on_weapon_pressed.bind(weapon))
		_weapon_bar.add_child(button)
		_weapon_buttons[weapon] = button


## Barre d'actions : Foncer, Se désengager, Esquiver, Second Wind si le
## personnage l'a, Chercher et Se relever. Chaque bouton a sa touche (1 à 6).
func _build_action_bar() -> void:
	for kind in StandardAction.ALL:
		_action_factories[kind] = func() -> Action: return StandardAction.new(_player, kind)
	if _player.definition.second_wind_uses > 0:
		_action_factories[Texts.SECOND_WIND_ID] = func() -> Action: return SecondWindAction.new(_player)
	_action_factories[SearchAction.ID] = func() -> Action: return SearchAction.new(_player)
	_action_factories[StandUpAction.ID] = func() -> Action: return StandUpAction.new(_player)
	var i := 0
	for id: StringName in _action_factories:
		var button := _make_bar_button()
		button.text = "%s (%d)" % [Texts.action_name(id), i + 1]
		if i < ACTION_KEYS.size():
			button.shortcut = _key_shortcut(ACTION_KEYS[i])
		button.pressed.connect(_on_action_pressed.bind(id))
		_action_bar.add_child(button)
		_action_buttons[id] = button
		i += 1


func _make_bar_button() -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 40)
	# Le texte ne fixe pas la largeur : trop long, il est coupé par « … ».
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return button


# Note Godot : un Shortcut associé à un bouton le déclenche quand la touche
# est pressée, même sans focus, tant que le bouton est actif et visible.
# `physical` : la touche est repérée par sa position sur le clavier, quelle
# que soit la disposition (AZERTY, QWERTY…).
static func _key_shortcut(key: Key, physical: bool = false) -> Shortcut:
	var event := InputEventKey.new()
	if physical:
		event.physical_keycode = key
	else:
		event.keycode = key
	var shortcut := Shortcut.new()
	shortcut.events = [event]
	return shortcut


## Lettre affichée pour une touche physique, selon la disposition du clavier.
## Sans écran (tests, CI), la disposition est inconnue : on garde QWERTY.
static func _physical_key_label(key: Key) -> String:
	if DisplayServer.get_name() == "headless":
		return OS.get_keycode_string(key)
	var label := DisplayServer.keyboard_get_label_from_physical(key)
	return OS.get_keycode_string(label if label != KEY_NONE else key)


func _on_action_pressed(id: StringName) -> void:
	if _is_player_turn():
		_perform(_action_factories[id].call())


func _on_weapon_pressed(weapon: WeaponDef) -> void:
	_weapon = weapon
	_refresh()


func _on_end_turn_pressed() -> void:
	if _is_player_turn():
		_perform(EndTurnAction.new(_player))


# --- Affichage -----------------------------------------------------------------


func _refresh() -> void:
	_panel.refresh(_player, state)
	_initiative_bar.refresh(state.active())
	for combatant: Combatant in _tokens:
		_tokens[combatant].conditions = state.effects_on(combatant)
	_refresh_target()

	var player_turn := _is_player_turn()
	var reachable: Dictionary[Vector2i, int] = {}
	if player_turn:
		reachable = state.reachable_cells()
	_board.reachable = reachable
	var attackable: Array[Vector2i] = []
	if player_turn:
		for enemy in state.living_enemies_of(_player):
			var cell := _tokens[enemy].cell
			var action := _action_for_cell(cell)
			if action is AttackAction and action.validate(state).is_empty():
				attackable.append(cell)
	_board.attackable = attackable

	# Barre d'actions : grisée si l'action est impossible, avec la raison.
	for id: StringName in _action_buttons:
		var button := _action_buttons[id]
		var action: Action = _action_factories[id].call()
		var reason := action.validate(state)
		button.disabled = not player_turn or not reason.is_empty()
		button.tooltip_text = Texts.ACTION_DESCRIPTIONS[id]
		if player_turn and not reason.is_empty():
			button.tooltip_text += "\n" + Texts.reason(reason)

	# Armes : plus de javelots, on revient à l'arme de corps à corps.
	if _weapon == null or _player.quantity(_weapon) <= 0:
		_weapon = _player.melee_weapon()
	var weapons := _player.definition.weapons
	for i in weapons.size():
		var weapon := weapons[i]
		var button := _weapon_buttons[weapon]
		button.text = Texts.weapon_button(_player, weapon)
		if i < _weapon_key_labels.size():
			button.text += " (%s)" % _weapon_key_labels[i]
		button.set_pressed_no_signal(weapon == _weapon)
		button.disabled = _player.quantity(weapon) <= 0
		button.tooltip_text = Texts.weapon_tooltip(_player, weapon)

	# Bouton « Fin de tour » grisé hors du tour du joueur, avec la raison.
	var end_turn_reason := EndTurnAction.new(_player).validate(state)
	_end_turn_button.disabled = _busy or not end_turn_reason.is_empty()
	_end_turn_button.tooltip_text = Texts.reason(end_turn_reason) if not end_turn_reason.is_empty() else ""

	# Plus rien à faire : le bouton pulse pour inviter à finir le tour.
	var nothing_left := player_turn and state.action_used and state.movement_left == 0
	_set_pulse(nothing_left)
	if nothing_left:
		_hint_label.text = Texts.NOTHING_LEFT


func _place_board() -> void:
	_board.position = _board_area.global_position
	_board_origin = _board.position


## Panneau de la cible : l'ennemi survolé, sinon le premier encore en vie.
func _refresh_target() -> void:
	var target := _hovered_enemy
	if target == null or target.is_dead:
		for enemy in state.living_enemies_of(_player):
			target = enemy
			break
	_target_label.visible = target != null
	if target != null:
		_target_label.text = Texts.target_line(target, state.effects_on(target))


## Texte flottant au-dessus d'un point du plateau.
func _float(at: Vector2, text: String, color: Color, font_size: int = 24) -> void:
	FloatingText.spawn(_tokens_root, at, text, color, font_size)


## Petite secousse du plateau (coup critique). Ne bloque pas le jeu.
func _shake() -> void:
	var tween := create_tween()
	for i in 4:
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_STRENGTH
		tween.tween_property(_board, "position", _board_origin + offset, SHAKE_DURATION / 5.0)
	tween.tween_property(_board, "position", _board_origin, SHAKE_DURATION / 5.0)


func _apply_text_size() -> void:
	_hint_label.add_theme_font_size_override(&"font_size", Settings.font_size(18, 21))
	_target_label.add_theme_font_size_override(&"font_size", Settings.font_size(18, 21))


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
	await _wait(end_delay)
	if state.winner == Combatant.Side.PLAYER:
		on_story_end.call(GameState.Outcome.VICTORY, _player)
	else:
		on_story_end.call(GameState.Outcome.DEFEAT, null)


func _on_replay_pressed() -> void:
	SceneRouter.go_to(SceneRouter.COMBAT)


## Attend `seconds` secondes de jeu.
##
## Note Godot : un Tween créé par ce nœud lui est lié. Il s'arrête pendant la
## pause comme le reste de la scène, et disparaît avec elle : si le joueur
## quitte le combat pendant l'attente, la suite de la fonction ne reprend
## jamais sur un nœud détruit. Un timer de SceneTree, lui, continuerait.
func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await create_tween().tween_interval(seconds).finished

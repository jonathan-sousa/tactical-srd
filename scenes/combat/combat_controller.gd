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
const ACTION_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8]
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
## Fiches du groupe, dans l'ordre des cases de départ de la rencontre.
@export var party_ids: Array[StringName] = [&"fighter_lvl1"]
## Pause avant chaque action de l'adversaire, en secondes.
@export var enemy_action_delay := 0.45
## Pause avant de quitter le combat, le temps de lire la dernière ligne.
@export var end_delay := 1.5

var state: CombatState
## Source de hasard du combat. Les tests la remplacent par des dés truqués
## avant d'ajouter la scène à l'arbre ; sinon `_ready` crée des dés à graine
## (voir `seed_value`).
var dice: Dice
## Graine des dés : tirée au hasard pour chaque combat (-1), imposée en mode
## démo ou en rejeu, ou par un test.
var seed_value := -1
## Fichier où le combat est enregistré au fil des choix du joueur (voir
## CombatRecord). Les tests en donnent un autre.
var record_path := "user://replays/last_combat.json"
## Rencontre imposée par un test, à la place de `encounter_id` (hors
## histoire et hors rejeu).
var encounter_override: EncounterDef
## Ce qui se passe à la fin d'un combat de l'histoire. Par défaut,
## GameState.finish_step ; les tests le remplacent pour ne pas changer de scène.
var on_story_end: Callable
## Personnage joueur que l'on commande : celui dont c'est le tour, ou le
## dernier à avoir joué pendant le tour d'un ennemi.
var _player: Combatant
var _tokens: Dictionary[Combatant, TokenView] = {}
## Vrai pendant qu'une action se joue : les clics sont ignorés.
var _busy := false
var _pulse: Tween
## Vrai quand le combat fait partie de l'histoire (et non lancé seul).
var _story_mode := false
## Aiguillage des événements : type d'événement → méthode qui le rejoue.
var _event_handlers: Dictionary[Script, Callable] = {}
## Enregistrement du combat en cours, ou `null` (démo, rejeu, dés truqués).
var _record: CombatRecord
## Rejeu : l'enregistrement à rejouer et le prochain choix à lire.
var _replay: CombatRecord
var _replay_index := 0

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
@onready var _action_bar: VBoxContainer = %ActionBar
@onready var _weapon_bar: HBoxContainer = %WeaponBar
@onready var _decision_panel: PanelContainer = %DecisionPanel
@onready var _decision_question: Label = %DecisionQuestionLabel
@onready var _decision_yes: Button = %DecisionYesButton
@onready var _decision_no: Button = %DecisionNoButton
@onready var _board_area: Control = %BoardArea

## Boutons de la barre d'actions, par code d'action, et l'action que chacun
## propose (une fonction qui la construit).
var _action_buttons: Dictionary[StringName, Button] = {}
var _action_factories: Dictionary[StringName, Callable] = {}
## Arme choisie pour attaquer par le personnage commandé, et les boutons
## des armes. Chaque personnage retrouve l'arme qu'il avait choisie.
var _weapon: WeaponDef
var _chosen_weapons: Dictionary[Combatant, WeaponDef] = {}
var _weapon_buttons: Dictionary[WeaponDef, Button] = {}
## Lettre de la touche de chaque arme, calculée une fois.
var _weapon_key_labels: Array[String] = []
## Case survolée sur le plateau (BoardView.NO_CELL hors du plateau) : la
## bulle et les aperçus sont recalculés quand l'état change.
var _hovered_cell := BoardView.NO_CELL
## Bulle d'information au survol (voir BoardTooltip).
var _tooltip: BoardTooltip
## Fiche d'un combattant, au clic droit (voir CombatantSheet).
var _sheet: CombatantSheet
## Vue tactique affichée (touche Alt maintenue).
var _tactical := false
## Bulle d'un bouton d'action ou d'arme, collée à gauche du panneau.
var _action_tip: BoardTooltip
## Bouton d'action survolé (ou qui a le focus), et son code ; vide sinon.
var _hovered_action: StringName = &""
var _hovered_action_button: Button
## Forme du curseur choisie au survol du plateau (lue par les tests).
var _cursor_shape := Input.CURSOR_ARROW
## Dernier round annoncé dans le journal.
var _logged_round := 0
## Position de repos du plateau, que la secousse retrouve.
var _board_origin: Vector2
## Liste du groupe (PV et état de chaque personnage), au-dessus de la fiche
## du personnage commandé. Cachée quand il est seul.
var _party_list: PartyList
## Bouton Aider pressé : le prochain clic désigne l'ennemi à distraire ou
## l'allié à stabiliser.
var _help_armed := false


func _ready() -> void:
	var encounter: EncounterDef
	var registry := GameState.registry
	var ids: Array[StringName] = party_ids
	# Situation de départ du groupe : PV et ressources de leurs fiches, sauf
	# dans l'histoire (ressources sans repos) et en rejeu (celle du fichier).
	var members: Array[PartyMember] = []
	var step := GameState.current_step()
	_replay = Autoplay.replay
	if _replay != null:
		encounter = registry.encounter(_replay.encounter_id)
		members = _replay.party
		ids = []
		for member in members:
			ids.append(member.id)
	elif not Autoplay.encounter_id.is_empty():
		# Escarmouche lancée depuis la ligne de commande (voir Autoplay).
		encounter = registry.encounter(Autoplay.encounter_id)
		if not Autoplay.party_ids.is_empty():
			ids = Autoplay.party_ids
	elif step != null and step.kind == StoryStep.Kind.ENCOUNTER:
		_story_mode = true
		encounter = step.encounter
		members = GameState.party
		ids = GameState.PARTY_IDS
	else:
		encounter = encounter_override if encounter_override != null else registry.encounter(encounter_id)
	var definitions: Array[CharacterDef] = []
	for id in ids:
		if registry.character(id) != null:
			definitions.append(registry.character(id))
	if encounter == null or definitions.size() != ids.size() or ids.is_empty() \
			or encounter.player_starts.size() < ids.size():
		if _story_mode:
			push_error("Combat : l'étape « %s » n'a pas de rencontre, ou une fiche du groupe est introuvable." % GameState.current_step_id)
		else:
			push_error("Combat : rencontre « %s » introuvable, sans assez de cases de départ, ou fiche introuvable parmi %s." % [encounter_id if Autoplay.encounter_id.is_empty() else Autoplay.encounter_id, ids])
		return
	if not on_story_end.is_valid():
		on_story_end = GameState.finish_step
	var record_choices := dice == null and not Autoplay.enabled and _replay == null
	if dice == null:
		if _replay != null:
			seed_value = _replay.seed_value
		elif Autoplay.enabled:
			seed_value = Autoplay.seed_value
		elif seed_value < 0:
			seed_value = randi()
		dice = Dice.seeded(seed_value)
	_register_event_handlers()

	state = CombatState.create_party(encounter, definitions, members)
	_player = state.party()[0]
	if _replay != null:
		Autoplay.report("rejeu : graine %d, %d choix du joueur." % [_replay.seed_value, _replay.entries.size()])
	if record_choices:
		_record = CombatRecord.new()
		_record.seed_value = seed_value
		_record.encounter_id = encounter.id
		for member in state.party():
			_record.party.append(PartyMember.of(member))
		_save_record()
	for member in state.party():
		_chosen_weapons[member] = member.melee_weapon()
	_weapon = _chosen_weapons[_player]
	_party_list = PartyList.new()
	# Note Godot : add_child ajoute le nœud en dernier ; move_child le place
	# juste au-dessus de la fiche du personnage commandé.
	_panel.get_parent().add_child(_party_list)
	_panel.get_parent().move_child(_party_list, _panel.get_index())
	_party_list.visible = state.party().size() > 1
	_board.setup(encounter)
	_tooltip = BoardTooltip.new()
	$Hud.add_child(_tooltip)
	_sheet = CombatantSheet.new()
	$Hud.add_child(_sheet)
	_action_tip = BoardTooltip.new()
	$Hud.add_child(_action_tip)
	# Le plateau (un Node2D) suit la place que lui réserve l'interface.
	# Note Godot : `item_rect_changed` est émis quand un Control change de
	# position ou de taille, par exemple quand son conteneur le place.
	_board_area.item_rect_changed.connect(_place_board)
	_place_board()
	_apply_text_size()
	Settings.large_text_changed.connect(func(_enabled: bool) -> void: _apply_text_size())
	Settings.exact_enemy_hp_changed.connect(func(_enabled: bool) -> void: _on_exact_hp_changed())
	for combatant in state.combatants:
		var token := TokenView.new()
		token.setup(combatant, combatant.position, _board.cell_center(combatant.position))
		_tokens_root.add_child(token)
		_tokens[combatant] = token
		token.exact_hp = _shows_exact_hp(combatant)
		token.stepped.connect(AudioManager.play.bind(AudioManager.STEP))

	# Note Godot : connecter un signal = s'abonner à un événement (callback).
	_board.cell_clicked.connect(_on_cell_clicked)
	_board.cell_hovered.connect(_on_cell_hovered)
	_board.cell_right_clicked.connect(_on_cell_right_clicked)
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
	# Alt maintenu : vue tactique, tant que la touche reste enfoncée.
	if event.is_action("tactical_view") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_set_tactical(event.is_pressed())
		return
	if event.is_action_pressed("end_turn"):
		get_viewport().set_input_as_handled()
		_on_end_turn_pressed()


# Note Godot : _notification reçoit les avis du moteur. Si la fenêtre perd le
# focus (Alt+Tab), on ne recevra pas le relâchement d'Alt : on éteint la vue.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _tactical:
		_set_tactical(false)


# --- Déroulement -------------------------------------------------------------


func _start_combat() -> void:
	AudioManager.play_music(AudioManager.COMBAT_MUSIC)
	_busy = true
	await _play(state.start(dice))
	# Alert : l'échange d'initiative se décide avant le premier tour.
	await _resolve_decisions()
	_busy = false
	await _continue()


## Après chaque action : fin de combat, tour de l'IA, rejeu, tour d'un
## personnage inconscient, ou main au joueur. En rejeu, la fin du tour d'un
## inconscient est lue dans l'enregistrement, qui l'a notée comme un choix.
func _continue() -> void:
	_refresh()
	if state.is_over:
		_show_result()
	elif state.active().side == Combatant.Side.ENEMY:
		await _play_enemy_turn()
	elif _replay != null:
		await _play_replay_turn()
	elif state.active().is_down():
		await _play_unconscious_turn()
	elif Autoplay.enabled:
		# Mode démo : l'IA joue aussi les personnages joueurs.
		await _play_ai_turn()


## L'IA choisit une action à la fois, jusqu'à finir son tour.
func _play_enemy_turn() -> void:
	_hint_label.text = Texts.ENEMY_TURN
	await _play_ai_turn()


## Tour joué par l'IA : celui d'un ennemi, ou d'un personnage joueur en mode
## démo.
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


## Rejeu : les choix du joueur sont lus dans l'enregistrement, un à un.
func _play_replay_turn() -> void:
	_busy = true
	var actor := state.active()
	while not state.is_over and state.active() == actor:
		await _wait(enemy_action_delay)
		var action := _next_replay_action()
		if action == null:
			_busy = false
			_stop_replay()
			return
		await _play(action.execute(state, dice))
		await _resolve_decisions()
	_busy = false
	await _continue()


## Prochain choix enregistré, prêt à jouer, ou `null` si l'enregistrement
## est fini ou ne correspond plus au combat (règles ou IA modifiées).
func _next_replay_action() -> Action:
	if _replay_index >= _replay.entries.size():
		Autoplay.report("rejeu : fin de l'enregistrement avant la fin du combat.")
		return null
	var entry := _replay.entries[_replay_index]
	_replay_index += 1
	var deciding := state.pending.decider if state.pending != null else state.active()
	var action := CombatRecord.decode(entry, deciding, state)
	var reason := "choix illisible" if action == null else Texts.reason(action.validate(state))
	if action == null or not action.validate(state).is_empty():
		Autoplay.report("rejeu : le choix %d (%s) ne correspond plus au combat : %s." % [_replay_index, entry, reason])
		return null
	return action


## Arrête un rejeu qui ne peut pas continuer, puis quitte.
func _stop_replay() -> void:
	Autoplay.report("rejeu : arrêté.")
	Autoplay.later(self, AudioManager.quit_game, end_delay)


## Note le choix du joueur dans l'enregistrement, et l'écrit aussitôt : il
## reste exploitable même si le jeu est quitté en plein combat.
func _remember(action: Action) -> void:
	if _record == null:
		return
	_record.entries.append(CombatRecord.encode(action))
	_save_record()


func _save_record() -> void:
	DirAccess.make_dir_recursive_absolute(record_path.get_base_dir())
	var file := FileAccess.open(record_path, FileAccess.WRITE)
	if file == null:
		push_error("Enregistrement du combat impossible (%s)." % error_string(FileAccess.get_open_error()))
		return
	file.store_string(_record.to_json())


## Inconscient, un personnage joueur ne peut rien faire : son jet contre la
## mort a déjà eu lieu au début du tour, qui se termine tout seul.
func _play_unconscious_turn() -> void:
	_busy = true
	_hint_label.text = Texts.UNCONSCIOUS_TURN
	await _wait(enemy_action_delay)
	_busy = false
	await _perform(EndTurnAction.new(state.active()))


## Tant qu'une décision est en attente : le joueur choisit si elle le
## concerne, l'IA sinon. Une réponse peut en ouvrir une autre (attaque
## d'opportunité ratée, puis relance), d'où la boucle.
func _resolve_decisions() -> void:
	while state.pending != null and not state.is_over:
		var decision := state.pending
		var answer: Action
		var players_choice := decision.decider.side == Combatant.Side.PLAYER
		if players_choice and _replay != null:
			await _wait(enemy_action_delay)
			answer = _next_replay_action()
			if answer == null:
				_stop_replay()
				return
		elif players_choice and not Autoplay.enabled:
			answer = await _ask_player(decision)
			_remember(answer)
		else:
			await _wait(enemy_action_delay)
			answer = EnemyAI.decide(state)
		await _play(answer.execute(state, dice))


## Pose au joueur la question qui correspond à la décision, et renvoie
## l'action qui traduit sa réponse. La question nomme le personnage qui
## décide quand le groupe en compte plusieurs.
func _ask_player(decision: PendingDecision) -> Action:
	var decider := decision.decider
	var prefix := "%s : " % decider.display_name if state.party().size() > 1 else ""
	if decision is InitiativeSwapWindow:
		# Avant le premier tour : on montre la fiche de celui qui décide. Un
		# allié à la fois, dans l'ordre d'initiative.
		if decider != _player:
			_command(decider)
		_refresh()
		for ally in (decision as InitiativeSwapWindow).allies:
			if await _ask(prefix + Texts.initiative_swap_prompt(decider, ally, state)):
				return SwapInitiativeAction.new(decider, ally)
		return DeclineSwapAction.new(decider)
	if decision is InspirationWindow:
		var window := decision as InspirationWindow
		var question := Texts.death_save_inspiration_prompt(window.death_save) if window.result == null \
			else Texts.inspiration_prompt(window.result)
		if await _ask(prefix + question):
			return UseInspirationAction.new(decider)
		return DeclineInspirationAction.new(decider)
	var mover := (decision as ReactionWindow).mover
	if await _ask(prefix + Texts.reaction_prompt(mover)):
		return OpportunityAttackAction.new(decider)
	return DeclineReactionAction.new(decider)


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
	_clear_hover()
	_refresh()
	if action.actor.side == Combatant.Side.PLAYER:
		_remember(action)
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
		CombatantRecoveredEvent: _on_combatant_recovered,
		CombatantDiedEvent: _on_combatant_died,
		StabilizeAttemptedEvent: _on_stabilize_attempted,
		InitiativeSwappedEvent: _on_initiative_swapped,
	}


func _on_initiative_rolled(event: InitiativeRolledEvent) -> void:
	_initiative_bar.set_order(event.entries)
	_log.add_line(Texts.initiative_line(event.entries), LOG_MUTED_COLOR)


func _on_stabilize_attempted(event: StabilizeAttemptedEvent) -> void:
	_log.add_line(Texts.stabilize_line(event), LOG_HEAL_COLOR if event.success else LOG_MUTED_COLOR)
	if event.success:
		AudioManager.play(AudioManager.HEAL)
	_tokens[event.patient].refresh()
	_refresh()


func _on_initiative_swapped(event: InitiativeSwappedEvent) -> void:
	_log.add_line(Texts.initiative_swapped_line(event), LOG_MUTED_COLOR)


func _on_turn_started(event: TurnStartedEvent) -> void:
	_help_armed = false
	if event.round != _logged_round:
		_logged_round = event.round
		_log.add_header(Texts.round_header(event.round))
	_log.add_line(Texts.turn_line(event), LOG_TURN_COLOR)
	for combatant: Combatant in _tokens:
		_tokens[combatant].is_active = combatant == event.combatant
	if event.combatant.side == Combatant.Side.PLAYER and event.combatant != _player:
		_command(event.combatant)
	_refresh()


## Passe la main à un autre personnage joueur : ses armes et ses actions
## remplacent celles du précédent, qui garde l'arme qu'il avait choisie.
func _command(member: Combatant) -> void:
	_chosen_weapons[_player] = _weapon
	_player = member
	_weapon = _chosen_weapons[member]
	_build_weapon_bar()
	_build_action_bar()


func _on_moved(event: MovedEvent) -> void:
	# Un ennemi caché se déplace sans être vu : son pion reste à sa
	# dernière position connue.
	if event.unseen and event.combatant.side != Combatant.Side.PLAYER:
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


func _on_combatant_recovered(event: CombatantRecoveredEvent) -> void:
	_log.add_line(Texts.recovered_line(event), LOG_HEAL_COLOR)
	AudioManager.play(AudioManager.HEAL)
	await _tokens[event.combatant].rise()
	_tokens[event.combatant].refresh()
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
		var standings: Array[String] = []
		for combatant in state.combatants:
			standings.append("%s %d / %d PV" % [combatant.display_name, combatant.hp, combatant.definition.max_hp])
		Autoplay.report("Résumé : %s au round %d, %s." % [
			(Texts.VICTORY if event.winner == Combatant.Side.PLAYER else Texts.DEFEAT).to_lower(), state.round,
			", ".join(standings),
		])
	if _record != null:
		_record.outcome = CombatRecord.outcome_of(state)
		_save_record()
	if _replay != null:
		_check_replay_outcome()
	_log.add_line(Texts.end_line(event.winner), LOG_TURN_COLOR)
	AudioManager.play_jingle(AudioManager.VICTORY_JINGLE if event.winner == Combatant.Side.PLAYER else AudioManager.DEFEAT_JINGLE)
	combat_finished.emit(event.winner)


# --- Saisie du joueur ----------------------------------------------------------


func _is_player_turn() -> bool:
	return not _busy and not state.is_over and state.active() == _player


func _on_cell_clicked(cell: Vector2i) -> void:
	if not _is_player_turn():
		return
	if _help_armed:
		_help_armed = false
		var occupant := state.combatant_at(cell)
		if occupant != null and not state.is_hidden_from(occupant, _player):
			_perform(HelpAction.new(_player, occupant))
		else:
			_hint_label.text = ""
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
	# Un allié mourant au contact : on le stabilise (action Aider).
	var ally := state.combatant_at(cell)
	if ally != null and ally.side == _player.side and ally.is_dying():
		return HelpAction.new(_player, ally)
	var shown := _enemy_token_at(cell)
	if shown != null and not state.is_hidden_from(shown, _player):
		return _off_hand_or(AttackAction.new(_player, shown, _weapon))
	var hidden_enemy := not state.hidden_enemies_of(_player).is_empty()
	if shown != null or (hidden_enemy and Input.is_key_pressed(KEY_SHIFT)):
		return _off_hand_or(AttackAction.at_cell(_player, cell, _weapon))
	return MoveAction.new(_player, cell)


## Action déjà utilisée : la même attaque, de la main libre (propriété
## Light), avec l'arme choisie si elle convient, sinon la première autre
## arme Légère possible. Sinon `attack`, refusée avec sa raison.
func _off_hand_or(attack: AttackAction) -> AttackAction:
	if not state.action_used or state.light_attack_weapon == null:
		return attack
	var candidates: Array[WeaponDef] = [_weapon]
	candidates.append_array(_player.definition.weapons)
	var first: AttackAction = null
	for weapon in candidates:
		var off_hand := AttackAction.new(_player, attack.target, weapon)
		off_hand.cell = attack.cell
		off_hand.off_hand = true
		if first == null:
			first = off_hand
		if off_hand.validate(state).is_empty():
			return off_hand
	return first


## Ennemi vivant dont le pion est affiché sur cette case (éventuellement à
## sa dernière position connue, s'il est caché), ou `null`.
func _enemy_token_at(cell: Vector2i) -> Combatant:
	for combatant: Combatant in _tokens:
		if combatant.side != _player.side and not combatant.is_dead and _tokens[combatant].cell == cell:
			return combatant
	return null


func _on_cell_hovered(cell: Vector2i) -> void:
	_hovered_cell = cell
	# Hors de son tour, la ligne d'aide garde son message (« Tour de
	# l'adversaire… ») : seuls la bulle et les aperçus s'effacent.
	_clear_hover(_is_player_turn())
	if not _is_player_turn() or cell == BoardView.NO_CELL or _sheet.visible:
		return
	if _help_armed:
		_hint_label.text = Texts.HELP_ARMED_HINT
		return
	var shown := _enemy_token_at(cell)
	if shown != null:
		_hover_enemy(shown, cell)
		return
	var occupant := state.combatant_at(cell)
	if occupant != null and occupant.side == _player.side:
		_hover_ally(occupant)
		return
	_hover_ground(cell)


## Clic droit : la fiche du combattant visible sur cette case (un ennemi
## caché n'en a pas : on ne sait pas qui il est ni s'il est là).
func _on_cell_right_clicked(cell: Vector2i) -> void:
	if not _is_player_turn():
		return
	var combatant := state.combatant_at(cell)
	if combatant == null or state.is_hidden_from(combatant, _player):
		return
	var is_enemy := combatant.side != _player.side
	_tooltip.hide_content()
	_sheet.open(Texts.combatant_sheet(combatant, state, is_enemy, _shows_exact_hp(combatant)), _board_area.get_global_rect())


## Vue tactique : nature des cases, zones de menace de tous les ennemis
## (pour le personnage commandé), nom et PV au-dessus de chaque pion.
func _set_tactical(enabled: bool) -> void:
	_tactical = enabled and state != null
	_board.tactical = _tactical
	var threats: Array[Vector2i] = []
	if _tactical:
		threats.assign(state.threat_cells(_player).keys())
	_board.tactical_threats = threats
	for combatant: Combatant in _tokens:
		var visible_token := not combatant.is_dead and not state.is_hidden_from(combatant, _player)
		_tokens[combatant].label_text = Texts.tactical_label(combatant, _shows_exact_hp(combatant)) if _tactical and visible_token else ""
	if _tactical:
		_hint_label.text = Texts.TACTICAL_LEGEND
	elif state != null:
		_on_cell_hovered(_hovered_cell)


## Curseur de la souris : une main si le clic fait quelque chose, un sens
## interdit s'il serait refusé, la flèche ailleurs.
func _set_cursor(shape: Input.CursorShape) -> void:
	_cursor_shape = shape
	Input.set_default_cursor_shape(shape)


## Efface la bulle et les aperçus du survol précédent. `clear_hint` : la
## ligne d'aide revient au rappel des gestes (pendant son tour) ou se vide.
func _clear_hover(clear_hint: bool = true) -> void:
	_set_cursor(Input.CURSOR_ARROW)
	_tooltip.hide_content()
	_tooltip.keep_clear = Rect2()
	_board.path_preview = []
	_board.path_warning = false
	_board.path_cost = 0
	_board.threat_preview = []
	_board.aim = []
	_board.cover_marks = []
	if clear_hint:
		_hint_label.text = Texts.TACTICAL_HINT if _is_player_turn() else ""


## Survol d'un ennemi (ou de sa dernière position connue s'il est caché) :
## qui il est, puis la prévision de l'attaque avec l'arme choisie. Tout vient
## du moteur (AttackEstimate).
func _hover_enemy(enemy: Combatant, cell: Vector2i) -> void:
	var body := Texts.unit_body(enemy, state.effects_on(enemy), GridPathfinder.chebyshev(_player.position, cell), _shows_exact_hp(enemy))
	if state.is_hidden_from(enemy, _player):
		body = Texts.TOOLTIP_HIDDEN
	var attack := _action_for_cell(cell) as AttackAction
	var reason := attack.validate(state)
	_set_cursor(Input.CURSOR_POINTING_HAND if reason.is_empty() else Input.CURSOR_FORBIDDEN)
	if not reason.is_empty():
		body += "\n" + Texts.refusal(reason)
	elif attack.is_blind():
		body += "\n" + Texts.blind_attack_hint(attack.weapon)
	else:
		var estimate := AttackEstimate.of(state, _player, attack.target, attack.weapon, attack.off_hand)
		body += "\n" + Texts.attack_tooltip(attack.weapon, estimate, attack.off_hand)
		if GridPathfinder.chebyshev(_player.position, enemy.position) > 1:
			_board.aim = [_player.position, enemy.position]
		_board.cover_marks = estimate.cover_cells
		_tooltip.keep_clear = _cells_rect([_player.position, enemy.position])
	_show_unit_tooltip(enemy, body)


## Survol d'un allié (ou du personnage commandé) : PV, effets, jets contre la
## mort ; s'il est mourant, la chance de le stabiliser.
func _hover_ally(ally: Combatant) -> void:
	var distance := GridPathfinder.chebyshev(_player.position, ally.position)
	var body := Texts.unit_body(ally, state.effects_on(ally), distance, true)
	if ally == _player:
		body += "\n" + Texts.colored(Texts.TOOLTIP_YOUR_TURN, Palette.MUTED)
	else:
		var action := _action_for_cell(ally.position)
		if action is HelpAction:
			var reason := action.validate(state)
			body += "\n" + (Texts.stabilize_hint(_player, ally) if reason.is_empty() else Texts.refusal(reason))
			_set_cursor(Input.CURSOR_POINTING_HAND if reason.is_empty() else Input.CURSOR_FORBIDDEN)
	_show_unit_tooltip(ally, body)


func _show_unit_tooltip(combatant: Combatant, body: String) -> void:
	var fraction := _hp_fraction(combatant)
	_tooltip.show_content(Texts.unit_title(combatant, combatant.side != _player.side), body, fraction, TokenView.hp_color(fraction))


## Survol d'une case sans combattant visible : le trajet et son coût sur le
## plateau ; une bulle seulement si la case a une règle (arbre, palissade,
## broussailles) ou si le trajet provoque une attaque d'opportunité.
func _hover_ground(cell: Vector2i) -> void:
	var info := CellInfo.of(state, cell, _player)
	var lines: PackedStringArray = []
	if info.has_rule():
		lines.append(Texts.terrain_rule(info.terrain))
	var move := _action_for_cell(cell)
	var reason := move.validate(state)
	_set_cursor(Input.CURSOR_POINTING_HAND if reason.is_empty() else Input.CURSOR_FORBIDDEN)
	if move is MoveAction and reason.is_empty():
		var path := state.find_path(_player, cell)
		var attackers := state.opportunity_attackers(_player, path)
		_board.path_preview = path
		_board.path_cost = state.path_cost(_player, path)
		_board.path_warning = not attackers.is_empty()
		var shown: Array[Vector2i] = [_player.position]
		shown.append_array(path)
		_tooltip.keep_clear = _cells_rect(shown)
		if not attackers.is_empty():
			lines.append(Texts.opportunity_warning(attackers))
			_board.threat_preview = _threat_cells_of(attackers)
	elif not info.blocks_movement:
		_hint_label.text = Texts.reason(reason)
	if not state.hidden_enemies_of(_player).is_empty():
		var hints: PackedStringArray = []
		if not _hint_label.text.is_empty() and _hint_label.text != Texts.TACTICAL_HINT:
			hints.append(_hint_label.text)
		hints.append(Texts.BLIND_ATTACK_SHIFT_HINT)
		_hint_label.text = "\n".join(hints)
	if not lines.is_empty():
		_tooltip.show_content(Texts.terrain_title(info.terrain) if info.has_rule() else "", "\n".join(lines))


## Rectangle global qui englobe ces cases du plateau : ce que la bulle doit
## éviter de cacher.
func _cells_rect(cells: Array[Vector2i]) -> Rect2:
	var rect := Rect2(_board.to_global(Vector2(cells[0]) * BoardView.CELL_SIZE), Vector2.ONE * BoardView.CELL_SIZE)
	for cell in cells:
		rect = rect.merge(Rect2(_board.to_global(Vector2(cell) * BoardView.CELL_SIZE), Vector2.ONE * BoardView.CELL_SIZE))
	return rect


## Cases menacées par ces ennemis : celles qu'on ne quitte pas sans risque.
func _threat_cells_of(attackers: Array[Combatant]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var threats := state.threat_cells(_player)
	for cell: Vector2i in threats:
		for attacker: Combatant in threats[cell]:
			if attackers.has(attacker):
				cells.append(cell)
				break
	return cells


## Les PV de ce combattant sont-ils montrés en chiffres ? Toujours pour les
## personnages du joueur ; pour les ennemis, selon le réglage.
func _shows_exact_hp(combatant: Combatant) -> bool:
	return combatant.side == Combatant.Side.PLAYER or Settings.exact_enemy_hp


## Remplissage de la barre de PV montrée pour ce combattant.
func _hp_fraction(combatant: Combatant) -> float:
	if _shows_exact_hp(combatant):
		return clampf(float(combatant.hp) / combatant.definition.max_hp, 0.0, 1.0)
	return HealthStatus.bar_fraction(HealthStatus.of_combatant(combatant))


func _on_exact_hp_changed() -> void:
	for combatant: Combatant in _tokens:
		_tokens[combatant].exact_hp = _shows_exact_hp(combatant)
	if state != null:
		_on_cell_hovered(_hovered_cell)
		if _tactical:
			_set_tactical(true)


## Un bouton par arme du personnage, avec sa touche. L'arme choisie sert à
## attaquer ; en changer ne coûte rien (voir docs/rules-deviations.md).
func _build_weapon_bar() -> void:
	_clear_bar(_weapon_bar)
	_weapon_buttons.clear()
	_weapon_key_labels.clear()
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
		button.add_child(_cost_stripe(Palette.FREE))
		button.mouse_entered.connect(_on_weapon_hovered.bind(weapon, button))
		button.mouse_exited.connect(func() -> void: _action_tip.hide_content())
		_weapon_bar.add_child(button)
		_weapon_buttons[weapon] = button


## Barre d'actions, en sections selon le coût : Action (Foncer, Se
## désengager, Esquiver, Chercher, Se cacher, Aider), Action bonus (Second
## Wind si le personnage l'a, rappel de la main libre) et Déplacement (Se
## relever). Les touches 1 à 8 suivent l'ordre affiché.
func _build_action_bar() -> void:
	_clear_bar(_action_bar)
	_action_buttons.clear()
	_action_factories.clear()
	_clear_action_preview()
	var actions: Array[StringName] = []
	for kind in StandardAction.ALL:
		_action_factories[kind] = func() -> Action: return StandardAction.new(_player, kind)
		actions.append(kind)
	_action_factories[SearchAction.ID] = func() -> Action: return SearchAction.new(_player)
	_action_factories[HideAction.ID] = func() -> Action: return HideAction.new(_player)
	_action_factories[HelpAction.ID] = _help_for_button
	actions.append_array([SearchAction.ID, HideAction.ID, HelpAction.ID])
	var bonus: Array[StringName] = []
	if _player.definition.second_wind_uses > 0:
		_action_factories[Texts.SECOND_WIND_ID] = func() -> Action: return SecondWindAction.new(_player)
		bonus.append(Texts.SECOND_WIND_ID)
	_action_factories[StandUpAction.ID] = func() -> Action: return StandUpAction.new(_player)
	var movement: Array[StringName] = [StandUpAction.ID]

	_action_bar.add_child(_section_header(Texts.SECTION_ACTIONS, Palette.ACTION))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 4)
	_action_bar.add_child(grid)
	for id in actions:
		grid.add_child(_make_action_button(id, Palette.ACTION))

	# Action bonus et déplacement côte à côte : une ligne pour deux sections.
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	_action_bar.add_child(row)
	var bonus_box := _section_box(Texts.SECTION_BONUS, Palette.BONUS_ACTION)
	row.add_child(bonus_box)
	for id in bonus:
		bonus_box.add_child(_make_action_button(id, Palette.BONUS_ACTION))
	if bonus.is_empty() and _has_off_hand():
		var reminder := Label.new()
		reminder.text = Texts.OFF_HAND_REMINDER
		reminder.tooltip_text = Texts.OFF_HAND_REMINDER_TOOLTIP
		# Note Godot : un Label ignore la souris par défaut ; pour montrer son
		# infobulle, il doit la recevoir.
		reminder.mouse_filter = Control.MOUSE_FILTER_PASS
		reminder.theme_type_variation = &"MutedLabel"
		reminder.custom_minimum_size = Vector2(0, 34)
		reminder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		reminder.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		reminder.clip_text = true
		bonus_box.add_child(reminder)
	var movement_box := _section_box(Texts.SECTION_MOVEMENT, Palette.MOVEMENT)
	row.add_child(movement_box)
	for id in movement:
		movement_box.add_child(_make_action_button(id, Palette.MOVEMENT))


## Deux armes légères : l'attaque de la main libre est possible.
func _has_off_hand() -> bool:
	var light := 0
	for weapon in _player.definition.weapons:
		if weapon.properties.has(WeaponDef.LIGHT):
			light += 1
	return light >= 2


## Titre de section : un point et le nom, à la couleur du coût.
func _section_header(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = "● " + text
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_font_size_override(&"font_size", 13)
	return label


func _section_box(text: String, color: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", 2)
	box.add_child(_section_header(text, color))
	return box


## Bouton d'une action, avec sa touche et un liseré à la couleur du coût.
func _make_action_button(id: StringName, color: Color) -> Button:
	var index := _action_buttons.size()
	var button := _make_bar_button()
	button.text = Texts.action_name(id)
	if index < ACTION_KEYS.size():
		button.text += " (%d)" % (index + 1)
		button.shortcut = _key_shortcut(ACTION_KEYS[index])
	button.add_child(_cost_stripe(color))
	button.pressed.connect(_on_action_pressed.bind(id))
	button.mouse_entered.connect(_on_action_hovered.bind(id, button))
	button.mouse_exited.connect(_on_action_unhovered.bind(button))
	_action_buttons[id] = button
	return button


## Liseré coloré sur le bord gauche d'un bouton : le coût se lit sans texte.
static func _cost_stripe(color: Color) -> ColorRect:
	var stripe := ColorRect.new()
	stripe.color = color
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Note Godot : les ancres collent le liseré au bord gauche, sur toute la
	# hauteur du bouton, quelle que soit sa taille.
	stripe.anchor_bottom = 1.0
	stripe.offset_left = 3.0
	stripe.offset_top = 4.0
	stripe.offset_right = 7.0
	stripe.offset_bottom = -4.0
	return stripe


## Survol d'un bouton d'action : sa bulle (coût, effet, raison d'un refus) et
## son aperçu sur le plateau.
func _on_action_hovered(id: StringName, button: Button) -> void:
	_hovered_action = id
	_hovered_action_button = button
	_show_action_preview()


func _on_action_unhovered(button: Button) -> void:
	if button == _hovered_action_button:
		_clear_action_preview()


func _clear_action_preview() -> void:
	_hovered_action = &""
	_hovered_action_button = null
	if _action_tip != null:
		_action_tip.hide_content()
	_board.reach_preview = []
	_board.hiding_preview = []
	_board.ring_cells = []
	_board.threats_faded = false
	_board.threat_preview = []


func _show_action_preview() -> void:
	var id := _hovered_action
	if id.is_empty() or state == null:
		return
	_board.reach_preview = []
	_board.hiding_preview = []
	_board.ring_cells = []
	_board.threats_faded = false
	_board.threat_preview = []
	var action: Action = _action_factories[id].call()
	var reason := action.validate(state)
	var lines: PackedStringArray = [Texts.ACTION_DESCRIPTIONS[id]]
	if _is_player_turn():
		var preview := _action_preview_text(id)
		if not preview.is_empty():
			lines.append(Texts.colored(preview, Palette.ALLY))
	if not reason.is_empty():
		lines.append(Texts.refusal(reason))
	var cost: String = Texts.ACTION_COSTS[id]
	var color := Palette.ACTION if cost == Texts.COST_ACTION else (Palette.BONUS_ACTION if cost == Texts.COST_BONUS else Palette.MOVEMENT)
	_action_tip.show_anchored(Texts.action_tip_title(Texts.action_name(id), cost, color), "\n".join(lines), Vector2(_side_panel_left(), _hovered_action_button.global_position.y))


## Aperçu d'une action sur le plateau, et sa phrase pour la bulle. Tout vient
## du moteur : portée, menaces, qui nous voit, cases pour se cacher.
func _action_preview_text(id: StringName) -> String:
	match id:
		StandardAction.DASH:
			var speed := state.speed_in_squares(_player)
			var current := state.reachable_cells()
			var extended := state.reachable_from(_player, _player.position, state.movement_left + speed)
			var extra: Array[Vector2i] = []
			for cell: Vector2i in extended:
				if not current.has(cell):
					extra.append(cell)
			_board.reach_preview = extra
			return Texts.preview_dash(state.movement_left, state.movement_left + speed)
		StandardAction.DISENGAGE:
			var threats := state.threat_cells(_player)
			var cells: Array[Vector2i] = []
			var threatening: Array[Combatant] = []
			for cell: Vector2i in threats:
				cells.append(cell)
				for enemy: Combatant in threats[cell]:
					if not threatening.has(enemy):
						threatening.append(enemy)
			_board.threat_preview = cells
			_board.threats_faded = true
			return Texts.preview_disengage(threatening)
		StandardAction.DODGE:
			var seeing := state.enemies_seeing(_player)
			_board.ring_cells = _token_cells(seeing)
			return Texts.preview_dodge(seeing)
		HideAction.ID:
			_board.hiding_preview = state.hiding_cells(_player)
			var seeing := state.enemies_seeing(_player)
			_board.ring_cells = _token_cells(seeing)
			var here := Texts.PREVIEW_HIDE_HERE if seeing.is_empty() else Texts.preview_hide_seen(seeing)
			return "%s\n%s" % [Texts.PREVIEW_HIDE_CELLS, here]
		HelpAction.ID:
			var targets: Array[Combatant] = []
			for help in _help_targets():
				targets.append(help.target)
			_board.ring_cells = _token_cells(targets)
			return Texts.PREVIEW_HELP if not targets.is_empty() else ""
		SearchAction.ID:
			var hidden := state.hidden_enemies_of(_player)
			_board.ring_cells = _token_cells(hidden)
			return Texts.preview_search(hidden.size())
		StandUpAction.ID:
			return Texts.preview_stand_up(StandUpAction.cost(state, _player))
	return ""


## Cases où sont affichés les pions de ces combattants (la dernière position
## connue pour un caché).
func _token_cells(combatants: Array[Combatant]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for combatant in combatants:
		cells.append(_tokens[combatant].cell)
	return cells


## Vide une barre de boutons avant de la reconstruire pour un autre
## personnage.
##
## Note Godot : queue_free libère le nœud à la fin de l'image en cours ; on
## le retire d'abord de la barre pour qu'il n'y prenne plus de place.
static func _clear_bar(bar: Container) -> void:
	for child in bar.get_children():
		bar.remove_child(child)
		child.queue_free()


func _make_bar_button() -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 34)
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
	if not _is_player_turn():
		return
	if id == HelpAction.ID:
		# Une seule créature à aider : on l'aide. Sinon, on la désigne.
		var targets := _help_targets()
		if targets.size() == 1:
			_perform(targets[0])
		else:
			_help_armed = not targets.is_empty()
			_hint_label.text = Texts.HELP_ARMED_HINT if _help_armed else Texts.reason(_help_for_button().validate(state))
		return
	_perform(_action_factories[id].call())


## Actions Aider possibles maintenant, une par créature au contact.
func _help_targets() -> Array[HelpAction]:
	var found: Array[HelpAction] = []
	for combatant in state.combatants:
		var help := HelpAction.new(_player, combatant)
		if combatant != _player and help.validate(state).is_empty():
			found.append(help)
	return found


## Pour le bouton Aider : une action valide s'il y en a, sinon une action
## sans cible, refusée avec sa raison (action déjà prise, personne à aider).
func _help_for_button() -> Action:
	var targets := _help_targets()
	return targets[0] if not targets.is_empty() else HelpAction.new(_player, null)


func _on_weapon_hovered(weapon: WeaponDef, button: Button) -> void:
	_clear_action_preview()
	var title := Texts.action_tip_title(weapon.display_name, Texts.COST_FREE, Palette.FREE)
	_action_tip.show_anchored(title, Texts.weapon_tooltip(_player, weapon), Vector2(_side_panel_left(), button.global_position.y))


## Bord gauche du panneau de droite, moins une marge : la bulle d'un bouton
## s'y colle, sur le plateau.
func _side_panel_left() -> float:
	return ($Hud/Root/Columns/SidePanel as Control).global_position.x - 8.0


func _on_weapon_pressed(weapon: WeaponDef) -> void:
	_weapon = weapon
	_refresh()


func _on_end_turn_pressed() -> void:
	_help_armed = false
	if _is_player_turn():
		_perform(EndTurnAction.new(_player))


# --- Affichage -----------------------------------------------------------------


func _refresh() -> void:
	_panel.refresh(_player, state)
	if _party_list.visible:
		_party_list.refresh(state, _player)
	_initiative_bar.refresh(state.active())
	for combatant: Combatant in _tokens:
		_tokens[combatant].conditions = state.effects_on(combatant)

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

	# Bouton « Fin de tour » grisé hors du tour du joueur, avec la raison.
	var end_turn_reason := EndTurnAction.new(_player).validate(state)
	_end_turn_button.disabled = _busy or not end_turn_reason.is_empty()
	_end_turn_button.tooltip_text = Texts.reason(end_turn_reason) if not end_turn_reason.is_empty() else ""

	# La bulle et les aperçus suivent le nouvel état.
	_on_cell_hovered(_hovered_cell)
	if not _hovered_action.is_empty() and is_instance_valid(_hovered_action_button):
		_show_action_preview()
	if _tactical:
		_set_tactical(true)

	# Plus rien à faire : le bouton pulse pour inviter à finir le tour.
	var nothing_left := player_turn and state.action_used and state.movement_left == 0 and attackable.is_empty()
	_set_pulse(nothing_left)
	if nothing_left:
		_hint_label.text = Texts.NOTHING_LEFT


func _place_board() -> void:
	_board.position = _board_area.global_position
	_board_origin = _board.position
	if _tooltip != null:
		_tooltip.bounds = _board_area.get_global_rect()


## Fin d'un rejeu : le résultat est-il celui de l'enregistrement ? Puis on
## quitte.
func _check_replay_outcome() -> void:
	var outcome := CombatRecord.outcome_of(state)
	if _replay.outcome.is_empty():
		Autoplay.report("rejeu : combat terminé (l'enregistrement n'avait pas de résultat).")
	elif outcome == _replay.outcome:
		Autoplay.report("rejeu : conforme, même résultat que l'enregistrement.")
	else:
		Autoplay.report("rejeu : DIFFÉRENT de l'enregistrement (%s attendu, %s obtenu)." % [_replay.outcome, outcome])
	Autoplay.later(self, AudioManager.quit_game, end_delay + 1.0)


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
	if Autoplay.enabled:
		# Escarmouche en mode démo : rien d'autre à jouer.
		Autoplay.later(self, AudioManager.quit_game, end_delay)


## Dans l'histoire : victoire → étape suivante, défaite → écran de défaite.
func _leave_combat() -> void:
	_set_pulse(false)
	await _wait(end_delay)
	if state.winner == Combatant.Side.PLAYER:
		on_story_end.call(GameState.Outcome.VICTORY, state.party())
	else:
		var nobody: Array[Combatant] = []
		on_story_end.call(GameState.Outcome.DEFEAT, nobody)


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

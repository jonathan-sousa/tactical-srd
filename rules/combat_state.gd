## État complet d'un combat : grille, combattants, initiative, tour en cours.
##
## Ne contient aucune référence à un Node : il pourra être sérialisé plus
## tard (état initial + liste des actions jouées) pour sauvegarder en combat.
## On ne le modifie qu'à travers les actions (rules/actions/).
class_name CombatState
extends RefCounted

const FEET_PER_SQUARE := 5
## Le Ralentissement (maîtrise Slow) retire 10 ft de vitesse, soit 2 cases.
const SLOW_SQUARES := 2

## Nature d'une attaque selon l'arme et la distance : au corps à corps (dans
## l'allonge), à distance (tir ou lancer, dans la portée longue), ou
## impossible.
enum AttackKind { NONE, MELEE, RANGED }

var encounter: EncounterDef
var pathfinder: GridPathfinder
var line_of_sight: LineOfSight
## Ordre de création : le joueur, puis les ennemis de la rencontre.
var combatants: Array[Combatant] = []
var initiative: Array[InitiativeEntry] = []
## Effets temporaires en cours sur les combattants (voir Effect).
var effects: Array[Effect] = []

var round: int = 0
## Nombre de tours commencés depuis le début du combat, tous combattants
## confondus. Sert aux règles « une fois par tour ».
var turn_count: int = 0
## Déplacement restant du combattant actif, en cases.
var movement_left: int = 0
## Action du tour déjà utilisée ?
var action_used: bool = false
## Action bonus du tour déjà utilisée ?
var bonus_action_used: bool = false

## Décision en attente (réaction, relance…), ou `null`. Tant qu'elle est
## ouverte, seule une réponse est possible (voir PendingDecision).
var pending: PendingDecision = null

var is_over: bool = false
## Camp vainqueur, valable seulement quand `is_over` est vrai.
var winner: Combatant.Side = Combatant.Side.PLAYER

var _active_index: int = -1


## `player_hp` : PV du joueur au début du combat (ceux qui lui restent dans
## l'histoire). Par défaut, ses PV maximum.
static func create(p_encounter: EncounterDef, player: CharacterDef, player_hp: int = -1) -> CombatState:
	var state := CombatState.new()
	state.encounter = p_encounter
	state.pathfinder = GridPathfinder.new(p_encounter.grid_size, p_encounter.blocked_cells)
	state.line_of_sight = LineOfSight.new(p_encounter.blocked_cells)
	var hero := Combatant.new(player, Combatant.Side.PLAYER, p_encounter.player_start)
	if player_hp >= 0:
		hero.hp = mini(player_hp, player.max_hp)
	state.combatants.append(hero)
	for placement in p_encounter.enemies:
		state.combatants.append(Combatant.new(placement.character, Combatant.Side.ENEMY, placement.cell))
	return state


## DD de l'action Se cacher (SRD « Hide »).
const HIDE_DC := 15


## Tire l'initiative et commence le premier tour.
##
## Embuscade : avant l'initiative, chaque ennemi hors de vue tente de se
## cacher. Un combattant caché a l'avantage à l'initiative (condition
## Invisible) ; un adversaire dont il est caché est surpris et a le
## désavantage (SRD « Surprise »).
func start(dice: Dice) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	if encounter.ambush:
		for combatant in combatants:
			if combatant.side == Combatant.Side.ENEMY and can_hide(combatant):
				events.append(roll_hide(combatant, dice, false))

	var modes: Dictionary[Combatant, Dice.RollMode] = {}
	for combatant in combatants:
		if is_hidden(combatant):
			modes[combatant] = Dice.RollMode.ADVANTAGE
		elif not hidden_enemies_of(combatant).is_empty():
			modes[combatant] = Dice.RollMode.DISADVANTAGE
	initiative = Initiative.roll_order(combatants, dice, modes)
	round = 1
	_active_index = 0
	turn_count = 1
	_reset_turn_budget()
	events.append(InitiativeRolledEvent.new(initiative))
	events.append(TurnStartedEvent.new(active(), round))
	return events


## Combattant dont c'est le tour.
func active() -> Combatant:
	if _active_index < 0:
		return null
	return initiative[_active_index].combatant


# Division entière voulue (30 ft / 5 = 6 cases) : on fait taire
# l'avertissement de Godot qui signale toute division entre deux int.
## Vitesse en cases, Ralentissement compris. Nulle pour un combattant
## inconscient (condition Unconscious : « Speed 0 »).
@warning_ignore("integer_division")
func speed_in_squares(combatant: Combatant) -> int:
	if combatant.is_down():
		return 0
	var squares := combatant.definition.speed_feet / FEET_PER_SQUARE
	if has_effect(combatant, Effect.SLOWED):
		squares -= SLOW_SQUARES
	return maxi(squares, 0)


## Combattant vivant sur cette case (même inconscient ou caché), ou `null`.
## Un mort ne compte plus : sa case est libre.
func combatant_at(cell: Vector2i) -> Combatant:
	for combatant in combatants:
		if not combatant.is_dead and combatant.position == cell:
			return combatant
	return null


## Cases que `except` sait occupées par les autres combattants vivants. Un
## ennemi caché n'y figure pas : on ignore où il est, et on peut le heurter
## en entrant dans sa case (voir `walk`).
func occupied_cells(except: Combatant) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for combatant in combatants:
		if combatant != except and not combatant.is_dead and not is_hidden_from(combatant, except):
			cells.append(combatant.position)
	return cells


func find_path(mover: Combatant, destination: Vector2i) -> Array[Vector2i]:
	return pathfinder.find_path(mover.position, destination, occupied_cells(mover))


## Cases où le combattant actif peut aller avec son déplacement restant.
func reachable_cells() -> Dictionary[Vector2i, int]:
	var mover := active()
	return pathfinder.reachable_cells(mover.position, movement_left, occupied_cells(mover))


## Allonge de l'arme en cases : 5 ft = cases adjacentes, diagonales comprises.
func is_within_reach(attacker: Combatant, target: Combatant, weapon: WeaponDef) -> bool:
	return is_cell_within_reach(attacker, target.position, weapon)


@warning_ignore("integer_division")
func is_cell_within_reach(attacker: Combatant, cell: Vector2i, weapon: WeaponDef) -> bool:
	var reach := maxi(weapon.reach_feet / FEET_PER_SQUARE, 1)
	return GridPathfinder.chebyshev(attacker.position, cell) <= reach


## `observer` voit-il `target` ? Il doit être conscient, avoir une ligne
## de vue dégagée, et `target` ne doit pas être caché de lui (condition
## Invisible).
func can_see(observer: Combatant, target: Combatant) -> bool:
	if observer.is_down() or is_hidden_from(target, observer):
		return false
	return line_of_sight.is_clear(observer.position, target.position)


## Aucun obstacle entre `observer` et cette case ? Sinon la case est
## derrière un abri total : on ne peut pas la viser.
func has_line_of_sight_to(observer: Combatant, cell: Vector2i) -> bool:
	return line_of_sight.is_clear(observer.position, cell)


## Distance en pieds entre deux combattants (5 ft par case, diagonales
## comprises).
func distance_feet(a: Combatant, b: Combatant) -> int:
	return GridPathfinder.chebyshev(a.position, b.position) * FEET_PER_SQUARE


## Attaque au corps à corps si la cible est dans l'allonge d'une arme de
## corps à corps ; sinon attaque à distance si l'arme se tire ou se lance et
## que la cible est dans sa portée longue.
func attack_kind(attacker: Combatant, target: Combatant, weapon: WeaponDef) -> AttackKind:
	return attack_kind_at(attacker, target.position, weapon)


## Même chose pour une case visée (attaque à l'aveugle).
func attack_kind_at(attacker: Combatant, cell: Vector2i, weapon: WeaponDef) -> AttackKind:
	if weapon.kind == WeaponDef.Kind.MELEE and is_cell_within_reach(attacker, cell, weapon):
		return AttackKind.MELEE
	var distance := GridPathfinder.chebyshev(attacker.position, cell) * FEET_PER_SQUARE
	if weapon.has_range() and distance <= weapon.range_long_feet:
		return AttackKind.RANGED
	return AttackKind.NONE


# --- Se cacher et trouver ------------------------------------------------------


## Caché (action Se cacher réussie, pas encore trouvé) ?
func is_hidden(combatant: Combatant) -> bool:
	return has_effect(combatant, Effect.HIDDEN)


## `target` est-il caché de `observer` ? On ne se cache que de ses ennemis.
func is_hidden_from(target: Combatant, observer: Combatant) -> bool:
	return target.side != observer.side and is_hidden(target)


## DD pour trouver un combattant caché : le total de son jet de Discrétion.
func hide_dc(combatant: Combatant) -> int:
	for effect in effects:
		if effect.target == combatant and effect.id == Effect.HIDDEN:
			return effect.value
	return 0


## Ennemis vivants cachés de `observer`.
func hidden_enemies_of(observer: Combatant) -> Array[Combatant]:
	var hidden: Array[Combatant] = []
	for enemy in living_enemies_of(observer):
		if is_hidden(enemy):
			hidden.append(enemy)
	return hidden


## Peut-il se cacher ici ? Il faut être hors de la ligne de vue de tout
## ennemi conscient. Sur notre grille, un obstacle qui coupe la vue est un
## abri total : la condition d'abri est remplie du même coup.
func can_hide(combatant: Combatant) -> bool:
	return is_out_of_sight_at(combatant, combatant.position)


## Cette case est-elle hors de la ligne de vue de tous les ennemis
## conscients de `combatant` ?
func is_out_of_sight_at(combatant: Combatant, cell: Vector2i) -> bool:
	for enemy in living_enemies_of(combatant):
		if not enemy.is_down() and line_of_sight.is_clear(enemy.position, cell):
			return false
	return true


## Jet de Dextérité (Discrétion) contre DD 15. En cas de réussite, le
## combattant est caché et son total devient le DD pour le trouver.
func roll_hide(combatant: Combatant, dice: Dice, bonus_action: bool) -> HideAttemptedEvent:
	var bonus := combatant.definition.skill_bonus(CharacterDef.STEALTH)
	var d20 := dice.roll_die(20)
	var success := d20 + bonus >= HIDE_DC
	var event := HideAttemptedEvent.new(combatant, d20, bonus, success, bonus_action)
	if success:
		add_effect(Effect.new(Effect.HIDDEN, combatant, combatant, Effect.Expiry.UNTIL_REMOVED, event.total))
	return event


## Le combattant n'est plus caché. Renvoie l'événement, ou rien s'il ne
## l'était pas. `observer` : l'ennemi qui l'a trouvé, s'il y en a un.
func reveal(combatant: Combatant, reason: StringName, observer: Combatant = null) -> Array[CombatEvent]:
	if not remove_effect(combatant, Effect.HIDDEN):
		return []
	return [RevealedEvent.new(combatant, combatant.position, reason, observer)]


## Perception passive (SRD « Passive Perception ») : 10 + bonus de Sagesse
## (Perception). Aucun effet du jeu ne donne l'avantage ou le désavantage
## en Perception : pas de +5 ni de -5 pour l'instant.
func passive_perception(combatant: Combatant) -> int:
	return 10 + combatant.definition.skill_bonus(CharacterDef.PERCEPTION)


## Règle de MJ (docs/rules-deviations.md) : un caché est trouvé dès qu'un
## ennemi conscient a une vue dégagée sur lui, sauf `skip`, le caché dont
## le tour est en cours (il peut encore sortir de sa cachette et frapper).
## Vérifié à la fin de chaque déplacement et à chaque changement de tour.
func reveal_exposed(skip: Combatant = null) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	for hidden in combatants:
		if hidden == skip or hidden.is_dead or not is_hidden(hidden):
			continue
		for enemy in living_enemies_of(hidden):
			if not enemy.is_down() and line_of_sight.is_clear(enemy.position, hidden.position):
				events.append_array(reveal(hidden, RevealedEvent.SEEN, enemy))
				break
	return events


## Règle de MJ : un ennemi conscient qui voit la case où passe le caché, et
## dont la Perception passive atteint le total de sa Discrétion, le
## remarque. `null` si personne ne le remarque.
func _noticer(hidden: Combatant, cell: Vector2i) -> Combatant:
	for enemy in living_enemies_of(hidden):
		if not enemy.is_down() and line_of_sight.is_clear(enemy.position, cell) 				and passive_perception(enemy) >= hide_dc(hidden):
			return enemy
	return null


## Ennemis debout au contact de `combatant` (à 5 ft) qui le voient.
func hostiles_next_to(combatant: Combatant) -> Array[Combatant]:
	var hostiles: Array[Combatant] = []
	for enemy in living_enemies_of(combatant):
		if GridPathfinder.chebyshev(enemy.position, combatant.position) <= 1 and can_see(enemy, combatant):
			hostiles.append(enemy)
	return hostiles


## Ennemis vivants (debout, inconscients ou cachés) de `combatant`.
func living_enemies_of(combatant: Combatant) -> Array[Combatant]:
	var enemies: Array[Combatant] = []
	for other in combatants:
		if other.side != combatant.side and not other.is_dead:
			enemies.append(other)
	return enemies


## Passe au prochain combattant vivant ; nouveau round quand on revient au
## début de l'initiative. Un combattant mourant fait son jet contre la mort
## au début de son tour : il faut alors des dés.
func advance_turn(dice: Dice = null) -> Array[CombatEvent]:
	var events := _expire_effects(active(), Effect.Expiry.END_OF_SOURCE_TURN)
	# Fin du tour : un caché resté en vue est trouvé.
	events.append_array(reveal_exposed())
	for i in initiative.size():
		_active_index += 1
		if _active_index >= initiative.size():
			_active_index = 0
			round += 1
		if not active().is_dead:
			break
	turn_count += 1
	_reset_turn_budget()
	# La réaction revient au début du tour de son propriétaire.
	active().reaction_available = true
	events.append(TurnStartedEvent.new(active(), round))
	events.append_array(_expire_effects(active(), Effect.Expiry.START_OF_SOURCE_TURN))
	if active().is_dying():
		assert(dice != null, "Jet contre la mort : il faut des dés pour changer de tour.")
		events.append_array(HitPoints.roll_death_save(self, active(), dice))
	# Un combattant qui reprend connaissance voit les cachés en vue.
	events.append_array(reveal_exposed(active()))
	return events


## Applique un effet et prévient la présentation. Le Ralentissement réduit
## aussitôt le déplacement restant si la cible joue en ce moment.
func apply_effect(effect: Effect) -> Array[CombatEvent]:
	var was_slowed := has_effect(effect.target, Effect.SLOWED)
	add_effect(effect)
	if effect.id == Effect.SLOWED and not was_slowed and effect.target == active():
		movement_left = maxi(movement_left - SLOW_SQUARES, 0)
	return [EffectAppliedEvent.new(effect.target, effect.id)]


## Déplace `mover` case par case le long de `path`, en décomptant son
## déplacement. Avant chaque pas qui le ferait sortir de l'allonge d'un
## ennemi capable de réagir, le déplacement s'arrête et une fenêtre de
## réaction s'ouvre (voir ReactionWindow). `already_asked` : combattants
## déjà sollicités pour le premier pas, quand un déplacement reprend.
##
## Règles de MJ sur les cachés (docs/rules-deviations.md) :
## - entrer dans la case d'un ennemi caché le heurte : le déplacement
##   s'arrête sur la case d'avant, et il est trouvé ;
## - un caché qui passe en vue d'un ennemi à la Perception passive
##   suffisante est remarqué sur cette case, et la suite du trajet est vue ;
## - à la fin du déplacement, les cachés que `mover` voit sont trouvés.
func walk(mover: Combatant, path: Array[Vector2i], already_asked: Array[Combatant] = []) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	var from := mover.position
	var walked: Array[Vector2i] = []
	var unseen := is_hidden(mover)
	for i in path.size():
		var blocker := combatant_at(path[i])
		if blocker != null:
			if not walked.is_empty():
				events.append(MovedEvent.new(mover, from, walked, unseen))
			events.append_array(reveal(blocker, RevealedEvent.BUMPED, mover))
			events.append_array(reveal_exposed(mover))
			return events
		var skip: Array[Combatant] = []
		if i == 0:
			skip = already_asked
		var reactor := _opportunity_reactor(mover, mover.position, path[i], skip)
		if reactor != null:
			if not walked.is_empty():
				events.append(MovedEvent.new(mover, from, walked, unseen))
			var asked := skip.duplicate()
			asked.append(reactor)
			pending = ReactionWindow.new(reactor, mover, path.slice(i), asked)
			events.append(ReactionTriggeredEvent.new(reactor, mover))
			return events
		mover.position = path[i]
		movement_left -= 1
		walked.append(path[i])
		if unseen:
			var noticer := _noticer(mover, path[i])
			if noticer != null:
				events.append(MovedEvent.new(mover, from, walked, unseen))
				events.append_array(reveal(mover, RevealedEvent.NOTICED, noticer))
				from = path[i]
				walked = []
				unseen = false
	if not walked.is_empty():
		events.append(MovedEvent.new(mover, from, walked, unseen))
	events.append_array(reveal_exposed(mover))
	return events


## Reprend le déplacement suspendu par `window` une fois la réaction jouée,
## si celui qui se déplaçait tient encore debout.
func resume_movement(window: ReactionWindow) -> Array[CombatEvent]:
	if window == null or window.mover.is_down() or is_over:
		return []
	return walk(window.mover, window.remaining_path, window.asked)


## Ennemis qui auraient droit à une attaque d'opportunité si `mover`
## suivait ce chemin, dans l'ordre où ils seraient sollicités. Sert aux
## prévisualisations et à l'IA : chacun peut encore décider de ne pas réagir.
func opportunity_attackers(mover: Combatant, path: Array[Vector2i]) -> Array[Combatant]:
	var found: Array[Combatant] = []
	var from := mover.position
	for cell in path:
		var reactor := _opportunity_reactor(mover, from, cell, found)
		while reactor != null:
			found.append(reactor)
			reactor = _opportunity_reactor(mover, from, cell, found)
		from = cell
	return found


## Premier ennemi qui peut faire une attaque d'opportunité si `mover` va de
## `from` à `next` (SRD « Opportunity Attacks ») : il le voit, il a encore
## sa réaction, et ce pas fait sortir `mover` de son allonge. Aucun si
## `mover` s'est désengagé.
func _opportunity_reactor(mover: Combatant, from: Vector2i, next: Vector2i, skip: Array[Combatant]) -> Combatant:
	if has_effect(mover, Effect.DISENGAGED):
		return null
	for other in combatants:
		if other.side == mover.side or other.is_down() or not other.reaction_available or skip.has(other):
			continue
		var weapon := other.melee_weapon()
		if weapon == null or is_hidden_from(mover, other):
			continue
		var leaves_reach := is_cell_within_reach(other, from, weapon) and not is_cell_within_reach(other, next, weapon)
		if leaves_reach and line_of_sight.is_clear(other.position, from):
			return other
	return null


func has_effect(combatant: Combatant, id: StringName) -> bool:
	for effect in effects:
		if effect.target == combatant and effect.id == id:
			return true
	return false


## Ajoute un effet. Un effet du même nom sur la même cible est remplacé :
## rejouer Esquiver repousse simplement sa fin.
func add_effect(effect: Effect) -> void:
	remove_effect(effect.target, effect.id)
	effects.append(effect)


## Retire un effet. Renvoie vrai s'il était présent.
func remove_effect(combatant: Combatant, id: StringName) -> bool:
	for i in effects.size():
		if effects[i].target == combatant and effects[i].id == id:
			effects.remove_at(i)
			return true
	return false


## Effets en cours sur ce combattant, dans l'ordre où ils ont commencé.
func effects_on(combatant: Combatant) -> Array[StringName]:
	var ids: Array[StringName] = []
	for effect in effects:
		if effect.target == combatant:
			ids.append(effect.id)
	return ids


## Retire les effets dont `source` fixe la fin à ce moment-là.
func _expire_effects(source: Combatant, expiry: Effect.Expiry) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	var kept: Array[Effect] = []
	for effect in effects:
		if effect.source == source and effect.expiry == expiry:
			events.append(EffectEndedEvent.new(effect.target, effect.id))
		else:
			kept.append(effect)
	effects = kept
	return events


## Termine le combat si un camp n'a plus personne en lice. Un combattant
## mourant y est encore : ses jets contre la mort peuvent le relever. Un
## mort ou un stabilisé n'y est plus : sans allié pour le soigner, un
## stabilisé ne se relèvera pas pendant le combat.
func check_end() -> Array[CombatEvent]:
	if is_over:
		return []
	var player_in_fight := false
	var enemy_in_fight := false
	for combatant in combatants:
		if combatant.is_dead or combatant.is_stable:
			continue
		if combatant.side == Combatant.Side.PLAYER:
			player_in_fight = true
		else:
			enemy_in_fight = true

	if player_in_fight and enemy_in_fight:
		return []
	is_over = true
	winner = Combatant.Side.PLAYER if player_in_fight else Combatant.Side.ENEMY
	return [CombatEndedEvent.new(winner)]


func _reset_turn_budget() -> void:
	movement_left = speed_in_squares(active())
	action_used = false
	bonus_action_used = false

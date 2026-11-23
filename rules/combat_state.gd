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


## Tire l'initiative et commence le premier tour.
func start(dice: Dice) -> Array[CombatEvent]:
	initiative = Initiative.roll_order(combatants, dice)
	round = 1
	_active_index = 0
	turn_count = 1
	_reset_turn_budget()
	return [InitiativeRolledEvent.new(initiative), TurnStartedEvent.new(active(), round)]


## Combattant dont c'est le tour.
func active() -> Combatant:
	if _active_index < 0:
		return null
	return initiative[_active_index].combatant


# Division entière voulue (30 ft / 5 = 6 cases) : on fait taire
# l'avertissement de Godot qui signale toute division entre deux int.
## Vitesse en cases, Ralentissement compris.
@warning_ignore("integer_division")
func speed_in_squares(combatant: Combatant) -> int:
	var squares := combatant.definition.speed_feet / FEET_PER_SQUARE
	if has_effect(combatant, Effect.SLOWED):
		squares -= SLOW_SQUARES
	return maxi(squares, 0)


## Combattant debout sur cette case, ou `null`.
func combatant_at(cell: Vector2i) -> Combatant:
	for combatant in combatants:
		if not combatant.is_down() and combatant.position == cell:
			return combatant
	return null


## Cases occupées par les autres combattants debout.
func occupied_cells(except: Combatant) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for combatant in combatants:
		if combatant != except and not combatant.is_down():
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


## `observer` voit-il `target` ? Il faut une ligne de vue dégagée.
func can_see(observer: Combatant, target: Combatant) -> bool:
	return line_of_sight.is_clear(observer.position, target.position)


## Distance en pieds entre deux combattants (5 ft par case, diagonales
## comprises).
func distance_feet(a: Combatant, b: Combatant) -> int:
	return GridPathfinder.chebyshev(a.position, b.position) * FEET_PER_SQUARE


## Attaque au corps à corps si la cible est dans l'allonge d'une arme de
## corps à corps ; sinon attaque à distance si l'arme se tire ou se lance et
## que la cible est dans sa portée longue.
func attack_kind(attacker: Combatant, target: Combatant, weapon: WeaponDef) -> AttackKind:
	if weapon.kind == WeaponDef.Kind.MELEE and is_within_reach(attacker, target, weapon):
		return AttackKind.MELEE
	if weapon.has_range() and distance_feet(attacker, target) <= weapon.range_long_feet:
		return AttackKind.RANGED
	return AttackKind.NONE


## Ennemis debout au contact de `combatant` (à 5 ft) qui le voient.
func hostiles_next_to(combatant: Combatant) -> Array[Combatant]:
	var hostiles: Array[Combatant] = []
	for enemy in living_enemies_of(combatant):
		if GridPathfinder.chebyshev(enemy.position, combatant.position) <= 1 and can_see(enemy, combatant):
			hostiles.append(enemy)
	return hostiles


func living_enemies_of(combatant: Combatant) -> Array[Combatant]:
	var enemies: Array[Combatant] = []
	for other in combatants:
		if other.side != combatant.side and not other.is_down():
			enemies.append(other)
	return enemies


## Passe au prochain combattant debout ; nouveau round quand on revient au
## début de l'initiative.
func advance_turn() -> Array[CombatEvent]:
	var events := _expire_effects(active(), Effect.Expiry.END_OF_SOURCE_TURN)
	for i in initiative.size():
		_active_index += 1
		if _active_index >= initiative.size():
			_active_index = 0
			round += 1
		if not active().is_down():
			break
	turn_count += 1
	_reset_turn_budget()
	# La réaction revient au début du tour de son propriétaire.
	active().reaction_available = true
	events.append(TurnStartedEvent.new(active(), round))
	events.append_array(_expire_effects(active(), Effect.Expiry.START_OF_SOURCE_TURN))
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
func walk(mover: Combatant, path: Array[Vector2i], already_asked: Array[Combatant] = []) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	var from := mover.position
	var walked: Array[Vector2i] = []
	for i in path.size():
		var skip: Array[Combatant] = []
		if i == 0:
			skip = already_asked
		var reactor := _opportunity_reactor(mover, path[i], skip)
		if reactor != null:
			if not walked.is_empty():
				events.append(MovedEvent.new(mover, from, walked))
			var asked := skip.duplicate()
			asked.append(reactor)
			pending = ReactionWindow.new(reactor, mover, path.slice(i), asked)
			events.append(ReactionTriggeredEvent.new(reactor, mover))
			return events
		mover.position = path[i]
		movement_left -= 1
		walked.append(path[i])
	if not walked.is_empty():
		events.append(MovedEvent.new(mover, from, walked))
	return events


## Reprend le déplacement suspendu par `window` une fois la réaction jouée,
## si celui qui se déplaçait tient encore debout.
func resume_movement(window: ReactionWindow) -> Array[CombatEvent]:
	if window == null or window.mover.is_down() or is_over:
		return []
	return walk(window.mover, window.remaining_path, window.asked)


## Premier ennemi qui peut faire une attaque d'opportunité si `mover` va
## sur `next` (SRD « Opportunity Attacks ») : il le voit, il a encore sa
## réaction, et ce pas fait sortir `mover` de son allonge. Aucun si `mover`
## s'est désengagé.
func _opportunity_reactor(mover: Combatant, next: Vector2i, skip: Array[Combatant]) -> Combatant:
	if has_effect(mover, Effect.DISENGAGED):
		return null
	for other in combatants:
		if other.side == mover.side or other.is_down() or not other.reaction_available or skip.has(other):
			continue
		var weapon := other.melee_weapon()
		if weapon == null:
			continue
		if is_cell_within_reach(other, mover.position, weapon) 				and not is_cell_within_reach(other, next, weapon) 				and can_see(other, mover):
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


## Termine le combat si un camp n'a plus personne debout.
func check_end() -> Array[CombatEvent]:
	if is_over:
		return []
	var player_standing := false
	var enemy_standing := false
	for combatant in combatants:
		if combatant.is_down():
			continue
		if combatant.side == Combatant.Side.PLAYER:
			player_standing = true
		else:
			enemy_standing = true

	if player_standing and enemy_standing:
		return []
	is_over = true
	winner = Combatant.Side.PLAYER if player_standing else Combatant.Side.ENEMY
	return [CombatEndedEvent.new(winner)]


func _reset_turn_budget() -> void:
	movement_left = speed_in_squares(active())
	action_used = false
	bonus_action_used = false

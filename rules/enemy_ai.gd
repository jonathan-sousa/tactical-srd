## IA de combat : choisit une action à la fois, d'après l'état du moment.
##
## Elle renvoie des actions ordinaires, validées et exécutées comme celles
## du joueur : l'IA ne triche pas sur les règles. Le contrôleur la rappelle
## après chaque action, jusqu'à ce qu'elle finisse son tour. Chaque action
## consomme quelque chose (action, action bonus, déplacement) : le tour se
## termine toujours.
##
## Le Guerrier joué par l'IA (mode démo, tests) prend Second Wind à la
## moitié de ses PV.
##
## Face à un groupe, chacun vise le personnage debout qu'il peut attaquer
## ce tour-ci, le plus proche en longueur de chemin. Un personnage à terre
## n'est visé que si aucun autre n'est à portée ce tour-ci.
##
## Tactique du Gobelin, dans l'ordre :
## 1. Hors de vue, il se cache d'abord (Nimble Escape) : son attaque aura
##    l'avantage, et +1d4 dégâts.
## 2. Il attaque : à l'arc de loin, au cimeterre au contact, au contact
##    toujours contre un Guerrier inconscient (coup critique assuré). S'il
##    ne peut pas attaquer d'où il est, il va sur la meilleure case.
## 3. Au contact d'un ennemi, il se désengage avant de reculer.
## 4. Il recule à l'abri d'un obstacle, puis s'y cache s'il le peut encore.
##
## Le Sbire lance ses dagues de loin, mais garde la dernière pour le
## contact.
class_name EnemyAI
extends RefCounted

## Garde-fou du contrôleur : nombre maximal d'actions dans un tour.
const MAX_ACTIONS_PER_TURN := 20
const NO_CELL := Vector2i(-1, -1)


## Prochaine action de `actor`, dont c'est le tour.
static func next_action(state: CombatState, actor: Combatant) -> Action:
	var end_turn := EndTurnAction.new(actor)
	if actor.is_down():
		return end_turn
	var stand_up := StandUpAction.new(actor)
	if stand_up.validate(state).is_empty():
		return stand_up

	# À la moitié de ses PV ou moins : Second Wind (action bonus).
	var second_wind := SecondWindAction.new(actor)
	if actor.hp * 2 <= actor.definition.max_hp and second_wind.validate(state).is_empty():
		return second_wind

	var target := _choose_target(state, actor)
	if target == null:
		# Tous ses ennemis sont cachés : il les cherche.
		var search := SearchAction.new(actor)
		return search if search.validate(state).is_empty() else end_turn

	if not state.action_used and not target.is_down():
		var hide := HideAction.new(actor, true)
		if hide.validate(state).is_empty():
			return hide
	if not state.action_used:
		var attack := _attack_step(state, actor, target)
		if attack != null:
			return attack
	var bonus := _bonus_step(state, actor)
	if bonus != null:
		return bonus
	var retreat := _retreat_step(state, actor)
	if retreat != null:
		return retreat
	return end_turn


## Réponse de l'IA à une décision en attente : elle saisit toujours
## l'occasion d'une attaque d'opportunité et relance toujours un jet raté.
static func decide(state: CombatState) -> Action:
	var decision := state.pending
	if decision is ReactionWindow:
		return OpportunityAttackAction.new(decision.decider)
	if decision is InspirationWindow:
		return UseInspirationAction.new(decision.decider)
	push_error("IA : décision inconnue.")
	return null


# --- Attaquer ------------------------------------------------------------------


## Attaque d'ici si possible, sinon déplacement vers la meilleure case
## d'attaque, sinon approche. `null` s'il n'y a rien à faire.
static func _attack_step(state: CombatState, actor: Combatant, target: Combatant) -> Action:
	# Contre un combattant inconscient (ou sans arme à distance), on va au
	# contact si on le peut ce tour-ci, plutôt que de tirer de loin.
	var wants_melee := target.is_down() or _ranged_weapon(actor) == null
	if wants_melee and state.movement_left > 0 and GridPathfinder.chebyshev(actor.position, target.position) > 1:
		var melee_cell := _best_attack_cell(state, actor, target, state.reachable_cells())
		if melee_cell != NO_CELL and GridPathfinder.chebyshev(melee_cell, target.position) <= 1:
			return MoveAction.new(actor, melee_cell)
	var weapon := _weapon_here(state, actor, target)
	if weapon != null:
		return AttackAction.new(actor, target, weapon)
	if state.movement_left <= 0:
		return null
	var cell := _best_attack_cell(state, actor, target, state.reachable_cells())
	if cell == NO_CELL:
		cell = _approach_cell(state, actor, target)
	if cell == NO_CELL:
		return null
	return MoveAction.new(actor, cell)


## Arme pour attaquer `target` sans bouger : au contact, l'arme de corps à
## corps ; de loin, une arme à distance. `null` si aucune attaque n'est
## possible d'ici.
static func _weapon_here(state: CombatState, actor: Combatant, target: Combatant) -> WeaponDef:
	var candidates: Array[WeaponDef] = []
	if GridPathfinder.chebyshev(actor.position, target.position) <= 1:
		candidates = [actor.melee_weapon(), _ranged_weapon(actor)]
	else:
		candidates = [_ranged_weapon(actor), actor.melee_weapon()]
	for weapon in candidates:
		if weapon != null and AttackAction.new(actor, target, weapon).validate(state).is_empty():
			return weapon
	return null


## Arme à distance utilisable (arc, javelots restants), ou `null`. On ne
## lance pas le dernier exemplaire de son arme de corps à corps (la dernière
## dague du Sbire) : sans elle, il n'aurait plus de quoi frapper.
static func _ranged_weapon(actor: Combatant) -> WeaponDef:
	for weapon in actor.definition.weapons:
		if not weapon.has_range() or actor.quantity(weapon) <= 0:
			continue
		if weapon.has_property(WeaponDef.THROWN) and actor.quantity(weapon) == 1 and actor.melee_weapon() == weapon:
			continue
		return weapon
	return null


## Meilleure case parmi `reachable` (case → coût) pour attaquer `target`,
## ou NO_CELL. Critères, dans l'ordre :
## 1. le type d'attaque voulu : au contact contre une cible inconsciente ou
##    sans arme à distance, de loin sinon ;
## 2. pas d'attaque d'opportunité en chemin ;
## 3. tir à portée normale (pas de désavantage) ;
## 4. un abri reste atteignable après l'attaque ;
## 5. un abri partiel (muret, créature) contre la riposte de la cible ;
## 6. le chemin le plus court, puis la case la plus haute et la plus à gauche
##    (choix reproductible).
static func _best_attack_cell(state: CombatState, actor: Combatant, target: Combatant, reachable: Dictionary[Vector2i, int]) -> Vector2i:
	var melee := actor.melee_weapon()
	var ranged := _ranged_weapon(actor)
	var wants_melee := target.is_down() or ranged == null
	var best := NO_CELL
	var best_score: Array[int] = []
	for cell: Vector2i in reachable:
		var can_melee := melee != null and GridPathfinder.chebyshev(cell, target.position) <= 1
		var can_shoot := ranged != null and _can_shoot_from(state, actor, target, ranged, cell)
		if not can_melee and not can_shoot:
			continue
		var cost: int = reachable[cell]
		var preferred := can_melee if wants_melee else can_shoot
		var distance := GridPathfinder.chebyshev(cell, target.position) * CombatState.FEET_PER_SQUARE
		var long_range := not preferred or (not wants_melee and distance > ranged.range_normal_feet)
		var score: Array[int] = [
			0 if preferred else 1,
			1 if _provokes(state, actor, state.find_path(actor, cell)) else 0,
			1 if long_range else 0,
			0 if _cover_within(state, actor, cell, state.movement_left - cost) else 1,
			0 if state.cover_between(target, target.position, actor, cell) > 0 else 1,
			cost,
			cell.y,
			cell.x,
		]
		# Note GDScript : deux tableaux se comparent élément par élément,
		# comme des tuples : le premier critère qui diffère décide.
		if best == NO_CELL or score < best_score:
			best = cell
			best_score = score
	return best


## Peut-on tirer sur `target` depuis `cell` sans désavantage de contact ?
## Ligne de vue, portée longue, et aucun ennemi conscient au contact.
static func _can_shoot_from(state: CombatState, actor: Combatant, target: Combatant, weapon: WeaponDef, cell: Vector2i) -> bool:
	if not state.line_of_sight.is_clear(cell, target.position):
		return false
	if GridPathfinder.chebyshev(cell, target.position) * CombatState.FEET_PER_SQUARE > weapon.range_long_feet:
		return false
	for enemy in state.living_enemies_of(actor):
		if not enemy.is_down() and GridPathfinder.chebyshev(cell, enemy.position) <= 1:
			return false
	return true


## Trop loin pour attaquer ce tour : on avance le long du chemin vers la
## case d'attaque la plus proche (en longueur de chemin), au plus loin que
## permet le déplacement.
static func _approach_cell(state: CombatState, actor: Combatant, target: Combatant) -> Vector2i:
	var all_cells := state.reachable_from(actor, actor.position, state.encounter.grid_size.x * state.encounter.grid_size.y)
	var goal := _best_attack_cell(state, actor, target, all_cells)
	if goal == NO_CELL:
		return NO_CELL
	var path := state.find_path(actor, goal)
	# On traverse un allié sans pouvoir s'arrêter dans sa case : on s'arrête
	# alors un peu avant.
	var allies := state.ally_cells(actor)
	var stop := mini(state.movement_left, path.size()) - 1
	while stop >= 0 and allies.has(path[stop]):
		stop -= 1
	return path[stop] if stop >= 0 else NO_CELL


# --- Action bonus et repli -------------------------------------------------------


## Action bonus après l'attaque : se cacher si on est hors de vue, sinon se
## désengager avant de reculer quand un ennemi peut frapper au passage.
static func _bonus_step(state: CombatState, actor: Combatant) -> Action:
	if state.bonus_action_used or not _has_conscious_enemy(state, actor):
		return null
	var hide := HideAction.new(actor, true)
	if hide.validate(state).is_empty():
		return hide
	if state.action_used and state.movement_left > 0 and _threatened(state, actor) \
			and _cover_within(state, actor, actor.position, state.movement_left):
		var disengage := StandardAction.new(actor, StandardAction.DISENGAGE, true)
		if disengage.validate(state).is_empty():
			return disengage
	return null


## Après l'attaque : se mettre hors de vue derrière un obstacle, sans
## provoquer d'attaque d'opportunité. `null` si on y est déjà ou si aucun
## abri n'est atteignable.
static func _retreat_step(state: CombatState, actor: Combatant) -> Action:
	if not state.action_used or state.movement_left <= 0:
		return null
	if not _has_conscious_enemy(state, actor) or state.is_out_of_sight_at(actor, actor.position):
		return null
	var reachable := state.reachable_cells()
	var best := NO_CELL
	var best_score: Array[int] = []
	for cell: Vector2i in reachable:
		if not state.is_out_of_sight_at(actor, cell):
			continue
		if _provokes(state, actor, state.find_path(actor, cell)):
			continue
		var score: Array[int] = [reachable[cell], cell.y, cell.x]
		if best == NO_CELL or score < best_score:
			best = cell
			best_score = score
	if best == NO_CELL:
		return null
	return MoveAction.new(actor, best)


# --- Outils ----------------------------------------------------------------------


## Ennemi à viser parmi ceux qu'on ne sait pas cachés, `null` s'il n'y en a
## pas. Critères, dans l'ordre :
## 1. un ennemi debout qu'on peut attaquer ce tour-ci ; à défaut un ennemi à
##    terre qu'on peut attaquer ; à défaut, un ennemi debout ;
## 2. le plus proche en longueur de chemin ;
## 3. le moins de PV, puis l'ordre des combattants (choix reproductible).
static func _choose_target(state: CombatState, actor: Combatant) -> Combatant:
	var reachable := state.reachable_from(actor, actor.position, state.movement_left)
	var everywhere := state.reachable_from(actor, actor.position, state.encounter.grid_size.x * state.encounter.grid_size.y)
	var best: Combatant = null
	var best_score: Array[int] = []
	for enemy in state.living_enemies_of(actor):
		if state.is_hidden_from(enemy, actor):
			continue
		var attackable := _can_attack_this_turn(state, actor, enemy, reachable)
		var tier := 0 if attackable else 2
		if enemy.is_down():
			tier += 1
		var score: Array[int] = [tier, _path_length_to(actor, enemy, everywhere), enemy.hp, state.combatants.find(enemy)]
		if best == null or score < best_score:
			best = enemy
			best_score = score
	return best


## Peut-on attaquer `target` ce tour-ci, d'ici ou après s'être déplacé vers
## une case de `reachable` ?
static func _can_attack_this_turn(state: CombatState, actor: Combatant, target: Combatant, reachable: Dictionary[Vector2i, int]) -> bool:
	if _weapon_here(state, actor, target) != null:
		return true
	var melee := actor.melee_weapon()
	var ranged := _ranged_weapon(actor)
	for cell: Vector2i in reachable:
		if melee != null and GridPathfinder.chebyshev(cell, target.position) <= 1:
			return true
		if ranged != null and _can_shoot_from(state, actor, target, ranged, cell):
			return true
	return false


## Nombre de cases à parcourir pour arriver au contact de `target`, d'après
## `everywhere` (case → coût, sans limite de déplacement). Très grand si on
## ne peut pas l'atteindre.
static func _path_length_to(actor: Combatant, target: Combatant, everywhere: Dictionary[Vector2i, int]) -> int:
	if GridPathfinder.chebyshev(actor.position, target.position) <= 1:
		return 0
	var shortest := 1 << 30
	for cell: Vector2i in everywhere:
		if GridPathfinder.chebyshev(cell, target.position) <= 1:
			shortest = mini(shortest, everywhere[cell])
	return shortest


static func _has_conscious_enemy(state: CombatState, actor: Combatant) -> bool:
	for enemy in state.living_enemies_of(actor):
		if not enemy.is_down():
			return true
	return false


## Un ennemi peut-il faire une attaque d'opportunité si `actor` s'éloigne ?
static func _threatened(state: CombatState, actor: Combatant) -> bool:
	for enemy in state.living_enemies_of(actor):
		var weapon := enemy.melee_weapon()
		if weapon != null and enemy.reaction_available and state.can_see(enemy, actor) \
				and state.is_cell_within_reach(enemy, actor.position, weapon):
			return true
	return false


## Ce chemin fait-il sortir `actor` de l'allonge d'un ennemi capable de
## réagir ? Jamais après Se désengager.
static func _provokes(state: CombatState, actor: Combatant, path: Array[Vector2i]) -> bool:
	return not state.opportunity_attackers(actor, path).is_empty()


## Un abri (case hors de vue de tout ennemi conscient) est-il atteignable
## depuis `from` avec `budget` cases de déplacement ?
static func _cover_within(state: CombatState, actor: Combatant, from: Vector2i, budget: int) -> bool:
	if state.is_out_of_sight_at(actor, from):
		return true
	if budget <= 0:
		return false
	for cell: Vector2i in state.reachable_from(actor, from, budget):
		if state.is_out_of_sight_at(actor, cell):
			return true
	return false

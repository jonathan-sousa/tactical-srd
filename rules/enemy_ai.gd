## IA de la v1 : s'approcher par le plus court chemin, attaquer si au contact,
## sinon finir le tour.
##
## Elle renvoie une liste d'actions ordinaires, validées et exécutées comme
## celles du joueur : l'IA ne triche pas et n'a aucun accès privilégié.
class_name EnemyAI
extends RefCounted

## Ordre fixe des cases autour d'une cible : à distance égale, la première
## de la liste l'emporte, ce qui rend les choix de l'IA reproductibles.
const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]


static func plan_turn(state: CombatState, actor: Combatant) -> Array[Action]:
	var plan: Array[Action] = []
	var end_turn := EndTurnAction.new(actor)

	var target := _closest_enemy(state, actor)
	if target == null:
		plan.append(end_turn)
		return plan

	var attack := AttackAction.new(actor, target)
	if state.is_within_reach(actor, target, attack.weapon):
		plan.append(attack)
		plan.append(end_turn)
		return plan

	var path := _shortest_path_next_to(state, actor, target)
	if path.is_empty():
		plan.append(end_turn)
		return plan

	if path.size() <= state.movement_left:
		plan.append(MoveAction.new(actor, path.back()))
		plan.append(attack)
	elif state.movement_left > 0:
		# Trop loin : on avance au maximum le long du chemin.
		plan.append(MoveAction.new(actor, path[state.movement_left - 1]))
	plan.append(end_turn)
	return plan


## Ennemi debout le plus proche à vol d'oiseau (en cases).
static func _closest_enemy(state: CombatState, actor: Combatant) -> Combatant:
	var closest: Combatant = null
	var best := 0
	for enemy in state.living_enemies_of(actor):
		var distance := GridPathfinder.chebyshev(actor.position, enemy.position)
		if closest == null or distance < best:
			closest = enemy
			best = distance
	return closest


## Plus court chemin vers une case libre adjacente à la cible, sans limite
## de déplacement. Vide si aucune n'est accessible.
static func _shortest_path_next_to(state: CombatState, actor: Combatant, target: Combatant) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	for offset in NEIGHBOURS:
		var path := state.find_path(actor, target.position + offset)
		if not path.is_empty() and (best.is_empty() or path.size() < best.size()):
			best = path
	return best

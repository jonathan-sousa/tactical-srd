## État complet d'un combat : grille, combattants, initiative, tour en cours.
##
## Ne contient aucune référence à un Node : il pourra être sérialisé plus
## tard (état initial + liste des actions jouées) pour sauvegarder en combat.
## On ne le modifie qu'à travers les actions (rules/actions/).
class_name CombatState
extends RefCounted

const FEET_PER_SQUARE := 5

var encounter: EncounterDef
var pathfinder: GridPathfinder
## Ordre de création : le joueur, puis les ennemis de la rencontre.
var combatants: Array[Combatant] = []
var initiative: Array[InitiativeEntry] = []

var round: int = 0
## Déplacement restant du combattant actif, en cases.
var movement_left: int = 0
## Action du tour déjà utilisée ?
var action_used: bool = false

var is_over: bool = false
## Camp vainqueur, valable seulement quand `is_over` est vrai.
var winner: Combatant.Side = Combatant.Side.PLAYER

var _active_index: int = -1


static func create(p_encounter: EncounterDef, player: CharacterDef) -> CombatState:
	var state := CombatState.new()
	state.encounter = p_encounter
	state.pathfinder = GridPathfinder.new(p_encounter.grid_size, p_encounter.blocked_cells)
	state.combatants.append(Combatant.new(player, Combatant.Side.PLAYER, p_encounter.player_start))
	for placement in p_encounter.enemies:
		state.combatants.append(Combatant.new(placement.character, Combatant.Side.ENEMY, placement.cell))
	return state


## Tire l'initiative et commence le premier tour.
func start(dice: Dice) -> Array[CombatEvent]:
	initiative = Initiative.roll_order(combatants, dice)
	round = 1
	_active_index = 0
	_reset_turn_budget()
	return [InitiativeRolledEvent.new(initiative), TurnStartedEvent.new(active(), round)]


## Combattant dont c'est le tour.
func active() -> Combatant:
	if _active_index < 0:
		return null
	return initiative[_active_index].combatant


# Division entière voulue (30 ft / 5 = 6 cases) : on fait taire
# l'avertissement de Godot qui signale toute division entre deux int.
@warning_ignore("integer_division")
func speed_in_squares(combatant: Combatant) -> int:
	return combatant.definition.speed_feet / FEET_PER_SQUARE


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
@warning_ignore("integer_division")
func is_within_reach(attacker: Combatant, target: Combatant, weapon: WeaponDef) -> bool:
	var reach := maxi(weapon.reach_feet / FEET_PER_SQUARE, 1)
	return GridPathfinder.chebyshev(attacker.position, target.position) <= reach


func living_enemies_of(combatant: Combatant) -> Array[Combatant]:
	var enemies: Array[Combatant] = []
	for other in combatants:
		if other.side != combatant.side and not other.is_down():
			enemies.append(other)
	return enemies


## Passe au prochain combattant debout ; nouveau round quand on revient au
## début de l'initiative.
func advance_turn() -> Array[CombatEvent]:
	for i in initiative.size():
		_active_index += 1
		if _active_index >= initiative.size():
			_active_index = 0
			round += 1
		if not active().is_down():
			break
	_reset_turn_budget()
	return [TurnStartedEvent.new(active(), round)]


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

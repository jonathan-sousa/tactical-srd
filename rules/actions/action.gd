## Classe de base des actions de combat, pour le joueur comme pour l'IA.
##
## Toujours en deux temps : `validate` dit si l'action est possible (et sinon
## pourquoi), `execute` l'applique et renvoie les événements produits.
## La présentation appelle `validate` pour griser ce qui est impossible.
##
## Les raisons sont des codes, pas des phrases : le texte affiché est choisi
## par la présentation (ui/texts.gd), ce qui garde les textes centralisés.
class_name Action
extends RefCounted

const COMBAT_OVER := &"combat_over"
const NOT_YOUR_TURN := &"not_your_turn"
const SAME_CELL := &"same_cell"
const CELL_UNREACHABLE := &"cell_unreachable"
const NOT_ENOUGH_MOVEMENT := &"not_enough_movement"
const ACTION_ALREADY_USED := &"action_already_used"
const TARGET_NOT_ENEMY := &"target_not_enemy"
const TARGET_DOWN := &"target_down"
const TARGET_OUT_OF_REACH := &"target_out_of_reach"
const NO_WEAPON := &"no_weapon"

var actor: Combatant


func _init(p_actor: Combatant) -> void:
	actor = p_actor


## Renvoie un code de raison si l'action est impossible, une chaîne vide sinon.
func validate(state: CombatState) -> StringName:
	if state.is_over:
		return COMBAT_OVER
	if state.active() != actor:
		return NOT_YOUR_TURN
	return _validate(state)


## Applique l'action. À n'appeler qu'après un `validate` vide.
func execute(state: CombatState, dice: Dice) -> Array[CombatEvent]:
	assert(validate(state).is_empty(), "Action invalide : %s" % validate(state))
	return _execute(state, dice)


# Note Godot : GDScript n'a pas de méthode abstraite pour une classe
# ordinaire ; les sous-classes redéfinissent ces deux méthodes.
func _validate(_state: CombatState) -> StringName:
	return &""


func _execute(_state: CombatState, _dice: Dice) -> Array[CombatEvent]:
	return []

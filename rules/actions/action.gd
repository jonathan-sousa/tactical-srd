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
const REACTION_PENDING := &"reaction_pending"
const NO_REACTION_PENDING := &"no_reaction_pending"
const NOT_YOUR_REACTION := &"not_your_reaction"

var actor: Combatant


func _init(p_actor: Combatant) -> void:
	actor = p_actor


## Renvoie un code de raison si l'action est impossible, une chaîne vide sinon.
##
## Pendant une fenêtre de réaction, seules les actions de réaction du
## combattant sollicité sont possibles ; en dehors, seules les autres, et
## seulement pour le combattant dont c'est le tour.
func validate(state: CombatState) -> StringName:
	if state.is_over:
		return COMBAT_OVER
	var window := state.reaction_window
	if window != null:
		if not is_reaction():
			return REACTION_PENDING
		if window.reactor != actor:
			return NOT_YOUR_REACTION
	elif is_reaction():
		return NO_REACTION_PENDING
	elif state.active() != actor:
		return NOT_YOUR_TURN
	return _validate(state)


## Vrai pour les actions qui répondent à une fenêtre de réaction.
func is_reaction() -> bool:
	return false


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

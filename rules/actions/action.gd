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
const TARGET_DEAD := &"target_dead"
const TARGET_OUT_OF_REACH := &"target_out_of_reach"
const NO_WEAPON := &"no_weapon"
const TARGET_OUT_OF_RANGE := &"target_out_of_range"
const TARGET_NOT_VISIBLE := &"target_not_visible"
const NO_AMMUNITION := &"no_ammunition"
const BONUS_ACTION_ALREADY_USED := &"bonus_action_already_used"
const NO_USES_LEFT := &"no_uses_left"
const FEATURE_UNAVAILABLE := &"feature_unavailable"
const DECISION_PENDING := &"decision_pending"
const NO_DECISION_PENDING := &"no_decision_pending"
const NOT_YOUR_DECISION := &"not_your_decision"
const INCAPACITATED := &"incapacitated"
const ALREADY_HIDDEN := &"already_hidden"
const SEEN_BY_ENEMY := &"seen_by_enemy"
const NOTHING_TO_SEARCH := &"nothing_to_search"
const NO_TARGET := &"no_target"
const NOT_PRONE := &"not_prone"
const NO_OFF_HAND_ATTACK := &"no_off_hand_attack"
const OFF_HAND_WEAPON := &"off_hand_weapon"
const NOT_DYING := &"not_dying"

var actor: Combatant


func _init(p_actor: Combatant) -> void:
	actor = p_actor


## Renvoie un code de raison si l'action est impossible, une chaîne vide sinon.
##
## Pendant une décision en attente (CombatState.pending), seules les
## actions qui y répondent sont possibles, et seulement pour le combattant
## qui doit décider. Sinon, seules les autres, pour le combattant dont
## c'est le tour.
func validate(state: CombatState) -> StringName:
	if state.is_over:
		return COMBAT_OVER
	var decision := state.pending
	var answered := answers()
	if decision != null:
		if answered == null or decision.get_script() != answered:
			return DECISION_PENDING
		if decision.decider != actor:
			return NOT_YOUR_DECISION
	elif answered != null:
		return NO_DECISION_PENDING
	elif state.active() != actor:
		return NOT_YOUR_TURN
	# Condition Incapacitated : ni action, ni action bonus, ni réaction.
	if actor.is_down() and not usable_while_incapacitated():
		return INCAPACITATED
	return _validate(state)


## Type de décision en attente (sous-classe de PendingDecision) à laquelle
## cette action répond, ou `null` pour une action ordinaire.
func answers() -> Script:
	return null


## Possible même inconscient ? Seulement finir son tour (et répondre à une
## relance de jet contre la mort).
func usable_while_incapacitated() -> bool:
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

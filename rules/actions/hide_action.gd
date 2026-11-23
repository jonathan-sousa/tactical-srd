## Action Se cacher (SRD « Hide ») : jet de Dextérité (Discrétion) contre
## DD 15, hors de la ligne de vue de tout ennemi. Réussite : le combattant
## est caché, avec la condition Invisible, jusqu'à ce qu'il attaque ou qu'un
## ennemi le trouve (action Chercher). Sortir à découvert ne le révèle pas
## (lecture littérale du SRD, voir docs/rules-deviations.md).
##
## Le Gobelin peut la prendre par une action bonus (Nimble Escape).
class_name HideAction
extends Action

const ID := &"hide"

## Par une action bonus (Nimble Escape) plutôt que par l'action du tour.
var bonus_action: bool


func _init(p_actor: Combatant, p_bonus_action: bool = false) -> void:
	super(p_actor)
	bonus_action = p_bonus_action


func _validate(state: CombatState) -> StringName:
	if bonus_action:
		if not actor.definition.has_trait(CharacterDef.NIMBLE_ESCAPE):
			return FEATURE_UNAVAILABLE
		if state.bonus_action_used:
			return BONUS_ACTION_ALREADY_USED
	elif state.action_used:
		return ACTION_ALREADY_USED
	if state.is_hidden(actor):
		return ALREADY_HIDDEN
	if not state.can_hide(actor):
		return SEEN_BY_ENEMY
	return &""


func _execute(state: CombatState, dice: Dice) -> Array[CombatEvent]:
	if bonus_action:
		state.bonus_action_used = true
	else:
		state.action_used = true
	return [state.roll_hide(actor, dice, bonus_action)]

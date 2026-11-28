## Don Alert (Initiative Swap) : juste après le jet d'initiative, le
## personnage peut échanger son initiative avec celle d'un allié consentant.
## Ni lui ni l'allié ne doivent être neutralisés (Incapacitated).
##
## Dans le jeu, les alliés sont les autres personnages du joueur : ils sont
## toujours consentants. Le premier tour attend la réponse.
class_name InitiativeSwapWindow
extends PendingDecision

## Alliés avec qui l'échange est possible, dans l'ordre d'initiative.
var allies: Array[Combatant] = []


func _init(p_decider: Combatant) -> void:
	decider = p_decider


## Fenêtre pour le premier combattant qui a Alert et au moins un allié
## avec qui échanger, ou `null`.
static func open(state: CombatState) -> InitiativeSwapWindow:
	for entry in state.initiative:
		var owner := entry.combatant
		if not owner.definition.has_feat(CharacterDef.ALERT) or owner.is_down():
			continue
		var window := InitiativeSwapWindow.new(owner)
		for other in state.initiative:
			var ally := other.combatant
			if ally != owner and ally.side == owner.side and not ally.is_down():
				window.allies.append(ally)
		if not window.allies.is_empty():
			return window
	return null

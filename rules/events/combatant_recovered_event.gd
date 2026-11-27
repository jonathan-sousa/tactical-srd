## Après une victoire, un personnage resté à terre (mourant ou stabilisé) se
## relève à 1 PV : ses alliés le stabilisent, et un personnage stabilisé
## regagne 1 PV au bout de 1d4 heures (voir docs/rules-deviations.md).
class_name CombatantRecoveredEvent
extends CombatEvent

var combatant: Combatant


func _init(p_combatant: Combatant) -> void:
	combatant = p_combatant

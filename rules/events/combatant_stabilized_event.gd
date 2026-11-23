## Trois réussites aux jets contre la mort : le combattant est stabilisé. Il
## reste inconscient à 0 PV, mais ne fait plus de jet.
class_name CombatantStabilizedEvent
extends CombatEvent

var combatant: Combatant


func _init(p_combatant: Combatant) -> void:
	combatant = p_combatant

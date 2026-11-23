## Un personnage est tombé à 0 PV : il perd connaissance et tombe à terre.
## Un monstre, lui, meurt (CombatantDiedEvent).
class_name CombatantDownedEvent
extends CombatEvent

var combatant: Combatant


func _init(p_combatant: Combatant) -> void:
	combatant = p_combatant

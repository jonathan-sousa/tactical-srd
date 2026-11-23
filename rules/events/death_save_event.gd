## Un jet contre la mort, ou un échec dû à des dégâts subis à 0 PV.
## `successes` et `failures` sont les compteurs après le jet.
class_name DeathSaveEvent
extends CombatEvent

var combatant: Combatant
## d20 lancé, ou 0 si l'échec vient de dégâts subis à 0 PV.
var natural: int
## Échecs dus à des dégâts : deux sur un coup critique.
var critical: bool
var successes: int
var failures: int
## 20 naturel : le combattant regagne 1 PV et reprend connaissance.
var revived: bool


func _init(p_combatant: Combatant, p_natural: int, p_critical: bool = false, p_revived: bool = false) -> void:
	combatant = p_combatant
	natural = p_natural
	critical = p_critical
	revived = p_revived
	successes = p_combatant.death_save_successes
	failures = p_combatant.death_save_failures

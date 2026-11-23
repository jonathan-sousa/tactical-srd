## Un combattant est mort.
class_name CombatantDiedEvent
extends CombatEvent

## Un monstre meurt dès qu'il tombe à 0 PV.
const MONSTER_AT_ZERO := &"monster_at_zero"
## Dégâts massifs : le reste des dégâts atteint ses PV maximum.
const MASSIVE_DAMAGE := &"massive_damage"
## Trois échecs aux jets contre la mort.
const DEATH_SAVES := &"death_saves"

var combatant: Combatant
var cause: StringName


func _init(p_combatant: Combatant, p_cause: StringName) -> void:
	combatant = p_combatant
	cause = p_cause

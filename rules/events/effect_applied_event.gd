## Un effet temporaire commence (maîtrises Sap et Slow…). Les effets des
## actions Esquiver et Se désengager sont annoncés par ActionTakenEvent.
class_name EffectAppliedEvent
extends CombatEvent

var combatant: Combatant
var effect_id: StringName


func _init(p_combatant: Combatant, p_effect_id: StringName) -> void:
	combatant = p_combatant
	effect_id = p_effect_id

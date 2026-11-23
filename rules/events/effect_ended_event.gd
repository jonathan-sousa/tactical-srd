## Un effet temporaire a pris fin (voir Effect).
class_name EffectEndedEvent
extends CombatEvent

var combatant: Combatant
var effect_id: StringName


func _init(p_combatant: Combatant, p_effect_id: StringName) -> void:
	combatant = p_combatant
	effect_id = p_effect_id

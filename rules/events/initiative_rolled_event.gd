## L'ordre d'initiative vient d'être tiré.
class_name InitiativeRolledEvent
extends CombatEvent

var entries: Array[InitiativeEntry]


func _init(p_entries: Array[InitiativeEntry]) -> void:
	entries = p_entries

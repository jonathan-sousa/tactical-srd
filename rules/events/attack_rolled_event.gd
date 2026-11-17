## Une attaque a été résolue. `result` contient tout le détail des jets.
class_name AttackRolledEvent
extends CombatEvent

var result: AttackResult


func _init(p_result: AttackResult) -> void:
	result = p_result

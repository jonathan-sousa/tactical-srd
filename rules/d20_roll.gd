## Résultat d'un d20, avec avantage ou désavantage éventuel.
##
## `rolls` garde les deux dés lancés en cas d'avantage ou de désavantage ;
## `natural` est le dé retenu, celui qui compte pour le 20 et le 1 naturels.
class_name D20Roll
extends RefCounted

var mode: Dice.RollMode
var rolls: Array[int] = []
var natural: int


func _init(p_mode: Dice.RollMode, p_rolls: Array[int], p_natural: int) -> void:
	mode = p_mode
	rolls = p_rolls
	natural = p_natural


func is_natural_20() -> bool:
	return natural == 20


func is_natural_1() -> bool:
	return natural == 1

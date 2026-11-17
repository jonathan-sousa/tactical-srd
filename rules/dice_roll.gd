## Résultat d'un lancer d'expression : chaque dé, le modificateur et le total.
## Garde tout le détail pour le journal de combat.
class_name DiceRoll
extends RefCounted

var expression: DiceExpression
var rolls: Array[int] = []
var modifier: int
var total: int


func _init(p_expression: DiceExpression, p_rolls: Array[int]) -> void:
	expression = p_expression
	rolls = p_rolls
	modifier = p_expression.modifier
	total = modifier
	for value in rolls:
		total += value

## Résultat d'un lancer d'expression : chaque dé, le modificateur et le total.
## Garde tout le détail pour le journal de combat.
class_name DiceRoll
extends RefCounted

var expression: DiceExpression
## Valeur retenue de chaque dé.
var rolls: Array[int] = []
## Valeur lue sur chaque dé avant ajustement (Great Weapon Fighting change
## les 1 et 2 en 3). Identique à `rolls` sans ajustement.
var natural_rolls: Array[int] = []
var modifier: int
var total: int


func _init(p_expression: DiceExpression, p_rolls: Array[int], p_natural_rolls: Array[int] = []) -> void:
	expression = p_expression
	rolls = p_rolls
	natural_rolls.assign(p_rolls if p_natural_rolls.is_empty() else p_natural_rolls)
	modifier = p_expression.modifier
	total = modifier
	for value in rolls:
		total += value

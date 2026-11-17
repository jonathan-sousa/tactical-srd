## Une expression de dés comme `2d6+3` : nombre de dés, taille, modificateur.
##
## Objet immuable : les méthodes `with_*` renvoient une nouvelle expression.
class_name DiceExpression
extends RefCounted

## Dés autorisés par le brief.
const ALLOWED_SIDES: Array[int] = [4, 6, 8, 10, 12, 20]

# Exemples acceptés : "2d6+3", "d20", "1d6 - 1". Insensible à la casse.
const _PATTERN := "^\\s*(\\d*)\\s*[dD]\\s*(\\d+)\\s*(?:([+-])\\s*(\\d+))?\\s*$"

var count: int
var sides: int
var modifier: int


func _init(p_count: int, p_sides: int, p_modifier: int = 0) -> void:
	count = p_count
	sides = p_sides
	modifier = p_modifier


## Lit une expression texte. Renvoie `null` si elle est invalide.
static func parse(text: String) -> DiceExpression:
	var regex := RegEx.create_from_string(_PATTERN)
	var match_result := regex.search(text)
	if match_result == null:
		return null

	var count_text := match_result.get_string(1)
	var parsed_count := 1 if count_text.is_empty() else count_text.to_int()
	var parsed_sides := match_result.get_string(2).to_int()
	var parsed_modifier := match_result.get_string(4).to_int()
	if match_result.get_string(3) == "-":
		parsed_modifier = -parsed_modifier

	if parsed_count < 1 or not ALLOWED_SIDES.has(parsed_sides):
		return null
	return DiceExpression.new(parsed_count, parsed_sides, parsed_modifier)


## Même expression avec deux fois plus de dés (coup critique).
func with_doubled_dice() -> DiceExpression:
	return DiceExpression.new(count * 2, sides, modifier)


## Même expression avec un modificateur ajouté à l'existant.
func with_modifier(extra: int) -> DiceExpression:
	return DiceExpression.new(count, sides, modifier + extra)


# Note Godot : _to_string() est l'équivalent de `to_s` ; str() et print()
# l'appellent automatiquement.
func _to_string() -> String:
	var text := "%dd%d" % [count, sides]
	if modifier > 0:
		text += "+%d" % modifier
	elif modifier < 0:
		text += "%d" % modifier
	return text

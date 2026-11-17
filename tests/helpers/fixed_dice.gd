## Dés truqués pour les tests : renvoient les valeurs données, dans l'ordre.
##
## Ils remplacent le hasard par une suite connue, ce qui permet de tester un
## 20 naturel, un 1 naturel ou un total pile égal à la CA sans chercher une
## graine qui tombe dessus. Ils échouent bruyamment si un test consomme plus
## de dés que prévu ou une valeur impossible pour le dé lancé.
##
## Note Godot : pas de `class_name` ici, pour ne pas ajouter une classe de test
## au namespace global du jeu. Les tests le chargent avec `preload`.
extends Dice

var _values: Array[int] = []


func _init(values: Array[int]) -> void:
	super()
	_values = values.duplicate()


## Nombre de valeurs pas encore consommées.
func remaining() -> int:
	return _values.size()


func _roll_die(sides: int) -> int:
	assert(not _values.is_empty(), "FixedDice : plus aucune valeur à renvoyer.")
	var value: int = _values.pop_front()
	assert(value >= 1 and value <= sides, "FixedDice : %d impossible sur un d%d." % [value, sides])
	return value

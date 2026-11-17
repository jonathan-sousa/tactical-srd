## Lanceur de dés du moteur de règles.
##
## Le générateur aléatoire est injecté : `Dice.seeded(42)` donne toujours la
## même suite de résultats, ce qui sert aux tests et au rejeu d'un combat.
##
## Note Godot : RefCounted est la classe de base des objets ordinaires,
## libérés automatiquement quand plus rien ne les référence (comme en Ruby).
## À l'inverse, un Node vit dans l'arbre de scène et doit être libéré à la main.
class_name Dice
extends RefCounted

enum RollMode { NORMAL, ADVANTAGE, DISADVANTAGE }

var _rng: RandomNumberGenerator


## Sans générateur fourni, on en crée un avec une graine aléatoire.
func _init(rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	_rng = rng


## Dés reproductibles : même graine, mêmes résultats.
static func seeded(seed_value: int) -> Dice:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Dice.new(rng)


## Lance un dé à `sides` faces (résultat entre 1 et `sides`).
func roll_die(sides: int) -> int:
	assert(sides >= 2, "Un dé doit avoir au moins 2 faces.")
	return _roll_die(sides)


## Lance un d20, deux en cas d'avantage ou de désavantage.
func roll_d20(mode: RollMode = RollMode.NORMAL) -> D20Roll:
	var rolls: Array[int] = [roll_die(20)]
	if mode == RollMode.NORMAL:
		return D20Roll.new(mode, rolls, rolls[0])

	rolls.append(roll_die(20))
	var kept := maxi(rolls[0], rolls[1]) if mode == RollMode.ADVANTAGE else mini(rolls[0], rolls[1])
	return D20Roll.new(mode, rolls, kept)


## Lance une expression comme `2d6+3`.
func roll(expression: DiceExpression) -> DiceRoll:
	var rolls: Array[int] = []
	for i in expression.count:
		rolls.append(roll_die(expression.sides))
	return DiceRoll.new(expression, rolls)


## Raccourci : lit l'expression texte puis la lance.
func roll_text(text: String) -> DiceRoll:
	var expression := DiceExpression.parse(text)
	assert(expression != null, "Expression de dés invalide : %s" % text)
	return roll(expression)


# Seul point de contact avec le hasard. Les tests le redéfinissent dans une
# sous-classe pour imposer les valeurs (voir tests/helpers/fixed_dice.gd).
func _roll_die(sides: int) -> int:
	return _rng.randi_range(1, sides)

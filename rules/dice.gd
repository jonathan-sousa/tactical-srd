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
##
## `lucky` : Chance du Halfelin (« When you roll a 1 on the d20 of a D20
## Test, you can reroll the die, and you must use the new roll »). Chaque dé
## qui fait 1 est relancé une fois, et le nouveau jet s'impose.
func roll_d20(mode: RollMode = RollMode.NORMAL, lucky: bool = false) -> D20Roll:
	var luck_rerolls := 0
	var rolls: Array[int] = []
	for i in (1 if mode == RollMode.NORMAL else 2):
		var value := roll_die(20)
		if lucky and value == 1:
			value = roll_die(20)
			luck_rerolls += 1
		rolls.append(value)
	var kept := rolls[0]
	if mode == RollMode.ADVANTAGE:
		kept = maxi(rolls[0], rolls[1])
	elif mode == RollMode.DISADVANTAGE:
		kept = mini(rolls[0], rolls[1])
	var roll := D20Roll.new(mode, rolls, kept)
	roll.luck_rerolls = luck_rerolls
	return roll


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

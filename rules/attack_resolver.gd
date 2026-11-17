## Résolution d'un jet d'attaque et de ses dégâts (SRD 5.2.1).
##
## Fonction pure : elle calcule le résultat sans toucher aux PV. Appliquer les
## dégâts est le travail de l'action d'attaque (J3), avec `Combatant.take_damage`.
class_name AttackResolver
extends RefCounted


static func resolve(
	attacker: Combatant,
	target: Combatant,
	weapon: WeaponDef,
	dice: Dice,
	mode: Dice.RollMode = Dice.RollMode.NORMAL,
) -> AttackResult:
	var result := AttackResult.new()
	result.attacker = attacker
	result.target = target
	result.weapon = weapon
	result.damage_type = weapon.damage_type

	# Jet d'attaque : d20 + modificateur de caractéristique + maîtrise.
	result.d20 = dice.roll_d20(mode)
	result.attack_bonus = attacker.attack_bonus(weapon)
	result.attack_total = result.d20.natural + result.attack_bonus
	result.target_armor_class = target.armor_class()

	# 20 naturel : touché automatique et critique. 1 naturel : raté
	# automatique. Sinon, touché si le total atteint la CA.
	if result.d20.is_natural_20():
		result.is_hit = true
		result.is_critical = true
	elif result.d20.is_natural_1():
		result.is_hit = false
	else:
		result.is_hit = result.attack_total >= result.target_armor_class

	if not result.is_hit:
		return result

	# Dégâts : dés de l'arme + modificateur. Au critique, seuls les dés sont
	# doublés, pas le modificateur.
	var weapon_dice := DiceExpression.parse(weapon.damage_dice)
	assert(weapon_dice != null, "Dés de dégâts invalides pour %s : %s" % [weapon.id, weapon.damage_dice])
	var expression := weapon_dice.with_modifier(attacker.damage_modifier(weapon))
	if result.is_critical:
		expression = expression.with_doubled_dice()

	result.damage_roll = dice.roll(expression)
	result.damage = maxi(result.damage_roll.total, 0)
	return result

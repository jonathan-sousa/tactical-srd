## Fiches de test construites dans le code, conformes au tableau « Fiches de
## la v1 » du brief. Les .tres du jeu arrivent au J2 ; ces fiches permettent
## de tester le moteur sans rien charger depuis le disque.
extends RefCounted


static func greatsword() -> WeaponDef:
	var weapon := WeaponDef.new()
	weapon.id = &"greatsword"
	weapon.display_name = "Épée à deux mains"
	weapon.damage_dice = "2d6"
	weapon.damage_type = DamageType.Type.SLASHING
	weapon.ability = Abilities.Ability.STRENGTH
	return weapon


static func scimitar() -> WeaponDef:
	var weapon := WeaponDef.new()
	weapon.id = &"scimitar"
	weapon.display_name = "Cimeterre"
	weapon.damage_dice = "1d6"
	weapon.damage_type = DamageType.Type.SLASHING
	weapon.ability = Abilities.Ability.DEXTERITY
	return weapon


static func fighter() -> CharacterDef:
	var def := CharacterDef.new()
	def.id = &"fighter_lvl1"
	def.display_name = "Guerrier"
	def.strength = 17
	def.dexterity = 13
	def.constitution = 15
	def.intelligence = 8
	def.wisdom = 12
	def.charisma = 10
	def.max_hp = 12
	def.armor_class = 16
	def.speed_feet = 30
	def.proficiency_bonus = 2
	def.initiative_bonus = 1
	def.weapons = [greatsword()]
	return def


static func goblin() -> CharacterDef:
	var def := CharacterDef.new()
	def.id = &"goblin_warrior"
	def.display_name = "Gobelin guerrier"
	def.strength = 8
	def.dexterity = 15
	def.constitution = 10
	def.intelligence = 10
	def.wisdom = 8
	def.charisma = 8
	def.max_hp = 10
	def.armor_class = 15
	def.speed_feet = 30
	def.proficiency_bonus = 2
	def.initiative_bonus = 2
	def.weapons = [scimitar()]
	return def

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
	weapon.properties = [WeaponDef.HEAVY, WeaponDef.TWO_HANDED]
	weapon.mastery = WeaponDef.GRAZE
	return weapon


static func flail() -> WeaponDef:
	var weapon := WeaponDef.new()
	weapon.id = &"flail"
	weapon.display_name = "Fléau"
	weapon.damage_dice = "1d8"
	weapon.damage_type = DamageType.Type.BLUDGEONING
	weapon.mastery = WeaponDef.SAP
	return weapon


static func javelin() -> WeaponDef:
	var weapon := WeaponDef.new()
	weapon.id = &"javelin"
	weapon.display_name = "Javelot"
	weapon.damage_dice = "1d6"
	weapon.damage_type = DamageType.Type.PIERCING
	weapon.range_normal_feet = 30
	weapon.range_long_feet = 120
	weapon.properties = [WeaponDef.THROWN]
	weapon.mastery = WeaponDef.SLOW
	return weapon


static func shortbow() -> WeaponDef:
	var weapon := WeaponDef.new()
	weapon.id = &"shortbow"
	weapon.display_name = "Arc court"
	weapon.kind = WeaponDef.Kind.RANGED
	weapon.damage_dice = "1d6"
	weapon.damage_type = DamageType.Type.PIERCING
	weapon.ability = Abilities.Ability.DEXTERITY
	weapon.range_normal_feet = 80
	weapon.range_long_feet = 320
	weapon.properties = [WeaponDef.AMMUNITION, WeaponDef.TWO_HANDED]
	weapon.mastery = WeaponDef.VEX
	return weapon


static func scimitar() -> WeaponDef:
	var weapon := WeaponDef.new()
	weapon.id = &"scimitar"
	weapon.display_name = "Cimeterre"
	weapon.damage_dice = "1d6"
	weapon.damage_type = DamageType.Type.SLASHING
	weapon.ability = Abilities.Ability.DEXTERITY
	weapon.properties = [WeaponDef.FINESSE, WeaponDef.LIGHT]
	weapon.mastery = WeaponDef.NICK
	return weapon


static func shortsword() -> WeaponDef:
	var weapon := WeaponDef.new()
	weapon.id = &"shortsword"
	weapon.display_name = "Épée courte"
	weapon.damage_dice = "1d6"
	weapon.damage_type = DamageType.Type.PIERCING
	weapon.ability = Abilities.Ability.DEXTERITY
	weapon.properties = [WeaponDef.FINESSE, WeaponDef.LIGHT]
	weapon.mastery = WeaponDef.VEX
	return weapon


static func dagger() -> WeaponDef:
	var weapon := WeaponDef.new()
	weapon.id = &"dagger"
	weapon.display_name = "Dague"
	weapon.damage_dice = "1d4"
	weapon.damage_type = DamageType.Type.PIERCING
	weapon.ability = Abilities.Ability.DEXTERITY
	weapon.range_normal_feet = 20
	weapon.range_long_feet = 60
	weapon.properties = [WeaponDef.FINESSE, WeaponDef.LIGHT, WeaponDef.THROWN]
	weapon.mastery = WeaponDef.NICK
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
	def.is_monster = true
	def.size = CharacterDef.Size.SMALL
	return def


## Gobelin guerrier complet, conforme à data/characters/goblin_warrior.tres :
## arc court, Discrétion +6, Nimble Escape, +1d4 dégâts avec l'avantage.
static func full_goblin() -> CharacterDef:
	var def := goblin()
	def.weapons = [scimitar(), shortbow()]
	def.skill_bonuses = {CharacterDef.STEALTH: 6}
	def.traits = [CharacterDef.NIMBLE_ESCAPE]
	def.advantage_damage_dice = "1d4"
	return def


## Sbire gobelin, conforme à data/characters/goblin_minion.tres : 3 dagues
## (corps à corps ou lancer), CA 12, 7 PV, Discrétion +6, Nimble Escape.
static func minion() -> CharacterDef:
	var def := goblin()
	def.id = &"goblin_minion"
	def.display_name = "Sbire gobelin"
	def.max_hp = 7
	def.armor_class = 12
	def.weapons = [dagger()]
	def.weapon_quantities = {&"dagger": 3}
	def.skill_bonuses = {CharacterDef.STEALTH: 6}
	def.traits = [CharacterDef.NIMBLE_ESCAPE]
	return def


## Guerrier complet du sprint 2, conforme à data/characters/fighter_lvl1.tres :
## trois armes, Great Weapon Fighting, Savage Attacker, maîtrises, Second
## Wind et Inspiration héroïque. Les tests retirent ce qu'ils n'utilisent pas.
static func full_fighter() -> CharacterDef:
	var def := fighter()
	def.weapons = [greatsword(), flail(), javelin()]
	def.weapon_quantities = {&"javelin": 8}
	def.species = "Humain"
	def.background = "Soldat"
	def.fighting_style = CharacterDef.GREAT_WEAPON_FIGHTING
	def.feats = [CharacterDef.SAVAGE_ATTACKER]
	def.weapon_masteries = [&"greatsword", &"flail", &"javelin"]
	def.second_wind_uses = 2
	def.heroic_inspiration = true
	def.skill_bonuses = {CharacterDef.PERCEPTION: 3}
	return def


## Roublard halfelin, conforme à data/characters/rogue_lvl1.tres : épée
## courte, arc court (20 flèches), 2 dagues, Attaque sournoise 1d6, Vex,
## Chance, Discrétion naturelle et Alert.
static func rogue() -> CharacterDef:
	var def := CharacterDef.new()
	def.id = &"rogue_lvl1"
	def.display_name = "Roublard"
	def.strength = 8
	def.dexterity = 17
	def.constitution = 15
	def.intelligence = 12
	def.wisdom = 13
	def.charisma = 10
	def.size = CharacterDef.Size.SMALL
	def.max_hp = 10
	def.armor_class = 14
	def.speed_feet = 30
	def.proficiency_bonus = 2
	def.initiative_bonus = 5
	def.weapons = [shortsword(), shortbow(), dagger()]
	def.weapon_quantities = {&"dagger": 2, &"shortbow": 20}
	def.species = "Halfelin"
	def.background = "Criminel"
	def.feats = [CharacterDef.ALERT]
	def.weapon_masteries = [&"shortsword", &"shortbow"]
	def.traits = [CharacterDef.HALFLING_LUCK, CharacterDef.NATURALLY_STEALTHY]
	def.sneak_attack_dice = "1d6"
	def.skill_bonuses = {CharacterDef.STEALTH: 7, CharacterDef.PERCEPTION: 5}
	return def


## Rencontre construite dans le code : grille, obstacles, départs.
static func encounter(
	grid_size: Vector2i,
	player_start: Vector2i,
	enemy_cells: Array[Vector2i],
	blocked: Array[Vector2i] = [],
	enemy: CharacterDef = null,
) -> EncounterDef:
	var def := EncounterDef.new()
	def.id = &"test_encounter"
	def.grid_size = grid_size
	def.player_starts = [player_start]
	def.blocked_cells = blocked
	for cell in enemy_cells:
		var placement := EnemyPlacement.new()
		placement.character = enemy if enemy != null else goblin()
		placement.cell = cell
		def.enemies.append(placement)
	return def


## Rencontre d'un groupe : une case de départ par personnage joueur, et des
## ennemis (gobelins de base par défaut).
static func party_encounter(
	grid_size: Vector2i,
	player_starts: Array[Vector2i],
	enemy_cells: Array[Vector2i],
	blocked: Array[Vector2i] = [],
	enemy: CharacterDef = null,
) -> EncounterDef:
	var def := encounter(grid_size, player_starts[0], enemy_cells, blocked, enemy)
	def.player_starts = player_starts
	return def

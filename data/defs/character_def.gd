## Fiche d'un personnage ou d'un monstre, sauvegardée en .tres.
##
## Immuable pendant le combat : l'état qui change (PV, position) vit dans
## `Combatant`. Voir weapon_def.gd pour la notion de Resource.
class_name CharacterDef
extends Resource

## Style de combat du Guerrier : les 1 et 2 des dés de dégâts d'une arme de
## corps à corps tenue à deux mains comptent comme des 3.
const GREAT_WEAPON_FIGHTING := &"great_weapon_fighting"
## Don d'origine (historique Soldat) : une fois par tour, lancer deux fois
## les dés de dégâts de l'arme et garder l'un des deux résultats.
const SAVAGE_ATTACKER := &"savage_attacker"
## Trait du Gobelin : se désengager ou se cacher par une action bonus.
const NIMBLE_ESCAPE := &"nimble_escape"

# Compétences utilisées en combat, et la caractéristique de chacune.
const STEALTH := &"stealth"
const PERCEPTION := &"perception"
const SKILL_ABILITIES: Dictionary[StringName, Abilities.Ability] = {
	STEALTH: Abilities.Ability.DEXTERITY,
	PERCEPTION: Abilities.Ability.WISDOM,
}

## Identifiant stable, utilisé par la sauvegarde et le registre de données.
@export var id: StringName
@export var display_name: String
## Image du pion. Vide jusqu'aux placeholders du J3.
@export var sprite: Texture2D

# Note Godot : @export_group ne fait que regrouper les champs dans l'inspecteur.
@export_group("Caractéristiques")
@export var strength: int = 10
@export var dexterity: int = 10
@export var constitution: int = 10
@export var intelligence: int = 10
@export var wisdom: int = 10
@export var charisma: int = 10

@export_group("Combat")
@export var max_hp: int = 1
@export var armor_class: int = 10
## Vitesse en pieds, comme dans le SRD (30 ft = 9 m = 6 cases).
@export var speed_feet: int = 30
@export var proficiency_bonus: int = 2
@export var initiative_bonus: int = 0
@export var weapons: Array[WeaponDef] = []
## Nombre d'exemplaires des armes qu'on peut épuiser (javelots), par id.
## Une arme absente de ce dictionnaire compte pour un exemplaire.
@export var weapon_quantities: Dictionary[StringName, int] = {}

@export_group("Origine et capacités")
## Espèce et historique, pour l'affichage (Humain, Soldat…).
@export var species: String
@export var background: String
@export var level: int = 1
## Style de combat (constante ci-dessus), vide si aucun.
@export var fighting_style: StringName = &""
## Dons (constantes ci-dessus).
@export var feats: Array[StringName] = []
## Armes dont le personnage peut utiliser la maîtrise, par id.
@export var weapon_masteries: Array[StringName] = []
## Utilisations de Second Wind (Guerrier). 0 : pas de Second Wind.
@export var second_wind_uses: int = 0
## Inspiration héroïque au début de la partie (trait Ingénieux de l'Humain).
@export var heroic_inspiration: bool = false
## Traits particuliers (constantes ci-dessus), surtout ceux des monstres.
@export var traits: Array[StringName] = []
## Dés de dégâts ajoutés à une attaque qui a l'avantage (« plus 1d4 dégâts
## si le jet d'attaque avait l'avantage » du Gobelin). Vide si aucun.
@export var advantage_damage_dice: String = ""

@export_group("Compétences et survie")
## Bonus total de compétence, comme dans un bloc de statistiques
## (Discrétion +6). Une compétence absente vaut le modificateur de sa
## caractéristique.
@export var skill_bonuses: Dictionary[StringName, int] = {}
## Monstre : meurt dès qu'il tombe à 0 PV (SRD « Monster Death »). Un
## personnage, lui, perd connaissance et fait des jets contre la mort.
@export var is_monster: bool = false


func ability_score(ability: Abilities.Ability) -> int:
	match ability:
		Abilities.Ability.STRENGTH:
			return strength
		Abilities.Ability.DEXTERITY:
			return dexterity
		Abilities.Ability.CONSTITUTION:
			return constitution
		Abilities.Ability.INTELLIGENCE:
			return intelligence
		Abilities.Ability.WISDOM:
			return wisdom
		_:
			return charisma


func has_feat(feat: StringName) -> bool:
	return feats.has(feat)


func has_trait(trait_id: StringName) -> bool:
	return traits.has(trait_id)


## Bonus d'un test de compétence (d20 + ce bonus).
func skill_bonus(skill: StringName) -> int:
	assert(SKILL_ABILITIES.has(skill), "Compétence inconnue : %s" % skill)
	return skill_bonuses.get(skill, Abilities.modifier(ability_score(SKILL_ABILITIES[skill])))


## Le personnage peut-il utiliser la maîtrise de cette arme ?
func masters(weapon: WeaponDef) -> bool:
	return not weapon.mastery.is_empty() and weapon_masteries.has(weapon.id)

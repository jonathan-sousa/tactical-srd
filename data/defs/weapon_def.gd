## Définition d'une arme, éditable dans l'inspecteur et sauvegardée en .tres.
##
## Note Godot : une Resource est un objet de données sérialisable, un peu
## comme un modèle ActiveRecord sans base de données : ses champs `@export`
## apparaissent dans l'éditeur et sont écrits dans un fichier .tres.
## Ce n'est pas un Node : on peut la créer et la tester sans aucune scène.
class_name WeaponDef
extends Resource

## Arme de corps à corps (épée, javelot…) ou arme à distance (arc…). Un
## javelot reste une arme de corps à corps : il peut aussi être lancé grâce à
## sa propriété Lancer.
enum Kind { MELEE, RANGED }

# Propriétés d'arme du SRD 5.2.1 utilisées par le jeu.
const FINESSE := &"finesse"
const HEAVY := &"heavy"
const LIGHT := &"light"
const THROWN := &"thrown"
const TWO_HANDED := &"two_handed"
const VERSATILE := &"versatile"
const AMMUNITION := &"ammunition"

# Maîtrises d'arme (Weapon Mastery) du SRD 5.2.1.
## Écorchure : un échec inflige quand même le modificateur de caractéristique.
const GRAZE := &"graze"
## Sape : la cible touchée a le désavantage à sa prochaine attaque.
const SAP := &"sap"
## Ralentissement : la cible touchée perd 10 ft de vitesse.
const SLOW := &"slow"
## Coup double : attaque de l'arme Légère en plus, dans l'action Attaque.
const NICK := &"nick"
## Ouverture : avantage à la prochaine attaque contre la cible touchée.
const VEX := &"vex"

## Identifiant stable, utilisé par la sauvegarde et le registre de données.
@export var id: StringName
@export var display_name: String
## Nom court pour les boutons (« Épée »). Vide : `display_name`.
@export var short_name: String
@export var kind: Kind = Kind.MELEE
## Dés de dégâts sans modificateur, par exemple "2d6".
@export var damage_dice: String = "1d4"
@export var damage_type: DamageType.Type = DamageType.Type.BLUDGEONING
## Caractéristique utilisée pour l'attaque et les dégâts.
@export var ability: Abilities.Ability = Abilities.Ability.STRENGTH
## Allonge en pieds (5 ft = une case).
@export var reach_feet: int = 5
## Portées normale et longue en pieds, pour une arme à distance ou de lancer.
## 0 si l'arme ne se lance pas.
@export var range_normal_feet: int = 0
@export var range_long_feet: int = 0
## Propriétés d'arme (voir les constantes ci-dessus).
@export var properties: Array[StringName] = []
## Maîtrise de l'arme, utilisable seulement par qui la maîtrise
## (CharacterDef.weapon_masteries). Vide si aucune.
@export var mastery: StringName = &""


func has_property(property: StringName) -> bool:
	return properties.has(property)


## Peut-on attaquer à distance avec cette arme (tir ou lancer) ?
func has_range() -> bool:
	return kind == Kind.RANGED or has_property(THROWN)

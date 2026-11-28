## Un combattant pendant un combat : sa fiche (immuable) et son état courant.
##
## La fiche (`CharacterDef`) est partagée et jamais modifiée ; tout ce qui
## change en combat (PV, position, réaction) vit ici. Les effets temporaires
## sont rangés dans CombatState (voir Effect).
class_name Combatant
extends RefCounted

enum Side { PLAYER, ENEMY }

var definition: CharacterDef
## Nom affiché : celui de la fiche, numéroté quand plusieurs combattants
## partagent la même (« Sbire gobelin 2 », voir CombatState.create_party).
var display_name: String
## Numéro parmi les combattants de même fiche, 0 s'il est seul de sa sorte.
var number: int = 0
var side: Combatant.Side
var hp: int
var position: Vector2i
## Réaction encore disponible ? Une seule entre deux de ses tours (SRD).
var reaction_available: bool = true
## Utilisations de Second Wind restantes.
var second_wind_uses: int
## Inspiration héroïque disponible ?
var heroic_inspiration: bool
## Exemplaires restants des armes qui s'épuisent (javelots), par id.
var quantities: Dictionary[StringName, int] = {}
## Numéro du dernier tour où Savage Attacker a servi (une fois par tour).
var savage_attacker_turn: int = -1
## Numéro du dernier tour où l'Attaque sournoise a servi (une fois par tour).
var sneak_attack_turn: int = -1

# À 0 PV (SRD « Dropping to 0 Hit Points ») : un monstre meurt aussitôt, un
# personnage perd connaissance et fait des jets contre la mort.
var is_dead: bool = false
## Stabilisé : à 0 PV, inconscient, mais sans jet contre la mort à faire.
var is_stable: bool = false
var death_save_successes: int = 0
var death_save_failures: int = 0


func _init(p_definition: CharacterDef, p_side: Combatant.Side, p_position: Vector2i = Vector2i.ZERO) -> void:
	definition = p_definition
	display_name = p_definition.display_name
	side = p_side
	position = p_position
	hp = p_definition.max_hp
	second_wind_uses = p_definition.second_wind_uses
	heroic_inspiration = p_definition.heroic_inspiration
	quantities.assign(p_definition.weapon_quantities)


## Hors de combat : mort, ou à 0 PV et inconscient (condition
## Unconscious : Incapacitated, à terre, vitesse 0).
func is_down() -> bool:
	return hp <= 0 or is_dead


## À 0 PV, vivant et pas stabilisé : jets contre la mort à chaque tour.
func is_dying() -> bool:
	return hp <= 0 and not is_dead and not is_stable


func armor_class() -> int:
	return definition.armor_class


## Bonus au jet d'attaque : modificateur de la caractéristique de l'arme +
## bonus de maîtrise.
func attack_bonus(weapon: WeaponDef) -> int:
	return damage_modifier(weapon) + definition.proficiency_bonus


## Modificateur ajouté aux dégâts : celui de la caractéristique de l'arme.
func damage_modifier(weapon: WeaponDef) -> int:
	return Abilities.modifier(definition.ability_score(weapon.ability))


## Retire des PV sans descendre sous 0. Renvoie les PV réellement perdus.
func take_damage(amount: int) -> int:
	assert(amount >= 0, "Des dégâts ne peuvent pas être négatifs.")
	var lost := mini(amount, hp)
	hp -= lost
	return lost


## Chance du Halfelin : ses 1 au d20 sont relancés.
func is_lucky() -> bool:
	return definition.has_trait(CharacterDef.HALFLING_LUCK)


## Nom court (CharacterDef.short_name), numéroté comme `display_name`.
func short_name() -> String:
	var base := definition.short_name if not definition.short_name.is_empty() else definition.display_name
	return "%s %d" % [base, number] if number > 0 else base


## Rend des PV sans dépasser le maximum. Renvoie les PV réellement rendus.
## Regagner des PV à 0 PV fait reprendre connaissance : les jets contre la
## mort repartent de zéro. Un mort ne regagne rien.
func heal(amount: int) -> int:
	assert(amount >= 0, "Des soins ne peuvent pas être négatifs.")
	if is_dead:
		return 0
	var gained := mini(amount, definition.max_hp - hp)
	hp += gained
	if gained > 0:
		reset_death_saves()
		is_stable = false
	return gained


func reset_death_saves() -> void:
	death_save_successes = 0
	death_save_failures = 0


## Exemplaires restants de cette arme (1 pour une arme qui ne s'épuise pas).
## Pour une arme à munitions (arc court), ce sont ses munitions.
func quantity(weapon: WeaponDef) -> int:
	return quantity_of(weapon.id)


func quantity_of(id: StringName) -> int:
	return quantities.get(id, 1)


## Arme de corps à corps par défaut, pour attaquer comme pour les attaques
## d'opportunité : la première arme de corps à corps de la fiche. `null`
## sans arme de corps à corps.
func melee_weapon() -> WeaponDef:
	for weapon in definition.weapons:
		if weapon.kind == WeaponDef.Kind.MELEE and quantity(weapon) > 0:
			return weapon
	return null


## Tout ce qui s'est passé lors d'une attaque, pour l'appliquer puis l'afficher
## dans le journal (« 14 + 4 = 18 contre CA 16, touché, 5 dégâts tranchants »).
class_name AttackResult
extends RefCounted

var attacker: Combatant
var target: Combatant
var weapon: WeaponDef

var d20: D20Roll
var attack_bonus: int
var attack_total: int
## CA de la cible, abri compris.
var target_armor_class: int
## Bonus d'abri ajouté à la CA de la cible (0 ou +2).
var cover_bonus: int = 0

## Avantage ou désavantage appliqué, avec ses raisons. `null` si l'attaque
## a été résolue directement par AttackResolver (tests).
var advantage: AdvantageResult
## Attaque d'opportunité (réaction) plutôt qu'action Attaque.
var is_opportunity: bool = false
## Attaque à distance (tir ou lancer) plutôt qu'au corps à corps.
var is_ranged: bool = false

var is_hit: bool = false
var is_critical: bool = false
## Toute touche est un critique : cible inconsciente à 5 ft ou moins
## (condition Unconscious, « Automatic Critical Hits »).
var critical_on_hit: bool = false

## `null` si l'attaque rate.
var damage_roll: DiceRoll
## Dégâts à appliquer (jamais négatifs). 0 si l'attaque rate.
var damage: int = 0
var damage_type: DamageType.Type
## Savage Attacker : le jet de dégâts écarté, ou `null`.
var discarded_damage_roll: DiceRoll
## Dés en plus quand l'attaque a l'avantage (+1d4 du Gobelin), ou `null`.
var advantage_damage_roll: DiceRoll
## Great Weapon Fighting appliqué aux dés de dégâts ?
var great_weapon_fighting: bool = false
## Maîtrise Graze : dégâts infligés malgré l'échec (0 sinon).
var graze_damage: int = 0

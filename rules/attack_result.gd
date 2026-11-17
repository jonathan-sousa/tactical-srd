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
var target_armor_class: int

var is_hit: bool = false
var is_critical: bool = false

## `null` si l'attaque rate.
var damage_roll: DiceRoll
## Dégâts à appliquer (jamais négatifs). 0 si l'attaque rate.
var damage: int = 0
var damage_type: DamageType.Type

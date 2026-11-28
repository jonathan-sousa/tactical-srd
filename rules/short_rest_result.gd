## Ce qu'un personnage a récupéré pendant un repos court (voir ShortRest).
class_name ShortRestResult
extends RefCounted

## Identifiant de la fiche (CharacterDef.id).
var member_id: StringName
## Dé de vie lancé, 0 si aucun n'a été dépensé.
var hit_die_roll: int = 0
## PV regagnés.
var healed: int = 0
## Une utilisation de Second Wind est revenue.
var second_wind_regained: bool = false

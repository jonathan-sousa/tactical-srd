## Ce qu'un personnage joueur garde d'un combat à l'autre : ses PV et les
## ressources qui ne reviennent qu'avec un repos, absent du jeu (Second Wind,
## Inspiration héroïque).
##
## Sert à la progression de l'histoire (GameState), à la sauvegarde
## (SaveManager) et aux enregistrements de combat (CombatRecord). Lu depuis un
## fichier, il est validé champ par champ (`from_dict`).
class_name PartyMember
extends RefCounted

## Identifiant de la fiche (CharacterDef.id).
var id: StringName
var hp: int
var second_wind_uses: int
var heroic_inspiration: bool


## Personnage frais : PV et ressources de sa fiche.
static func fresh(definition: CharacterDef) -> PartyMember:
	var member := PartyMember.new()
	member.id = definition.id
	member.hp = definition.max_hp
	member.second_wind_uses = definition.second_wind_uses
	member.heroic_inspiration = definition.heroic_inspiration
	return member


## Situation d'un personnage en combat.
static func of(combatant: Combatant) -> PartyMember:
	var member := PartyMember.new()
	member.id = combatant.definition.id
	member.hp = combatant.hp
	member.second_wind_uses = combatant.second_wind_uses
	member.heroic_inspiration = combatant.heroic_inspiration
	return member


## Ramène les valeurs dans ce que permet la fiche : de 1 PV au maximum,
## jamais plus de ressources que la fiche n'en donne.
func clamp_to(definition: CharacterDef) -> void:
	hp = clampi(hp, 1, definition.max_hp)
	second_wind_uses = clampi(second_wind_uses, 0, definition.second_wind_uses)
	heroic_inspiration = heroic_inspiration and definition.heroic_inspiration


## Reprend cette situation pour un combattant tout juste créé.
func apply_to(combatant: Combatant) -> void:
	combatant.hp = mini(hp, combatant.definition.max_hp)
	combatant.second_wind_uses = second_wind_uses
	combatant.heroic_inspiration = heroic_inspiration


func to_dict() -> Dictionary:
	return {
		"def_id": str(id),
		"hp_current": hp,
		"second_wind_uses": second_wind_uses,
		"heroic_inspiration": heroic_inspiration,
	}


## Lit un personnage écrit par `to_dict`. `null` si un champ manque ou n'a
## pas le bon type. Un personnage enregistré est toujours debout (1 PV ou
## plus) : on enregistre entre deux étapes, ou au début d'un combat.
static func from_dict(raw: Variant) -> PartyMember:
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var dict: Dictionary = raw
	var hp_value: Variant = dict.get("hp_current")
	var uses: Variant = dict.get("second_wind_uses")
	var inspiration: Variant = dict.get("heroic_inspiration")
	if typeof(dict.get("def_id")) != TYPE_STRING or not _is_whole_number(hp_value) or int(hp_value) < 1 \
			or not _is_whole_number(uses) or int(uses) < 0 or typeof(inspiration) != TYPE_BOOL:
		return null
	var member := PartyMember.new()
	member.id = StringName(dict["def_id"])
	member.hp = int(hp_value)
	member.second_wind_uses = int(uses)
	member.heroic_inspiration = inspiration
	return member


## Lit une liste de personnages (au moins un). Vide si l'un d'eux est
## invalide.
static func list_from(raw: Variant) -> Array[PartyMember]:
	var members: Array[PartyMember] = []
	if typeof(raw) != TYPE_ARRAY or (raw as Array).is_empty():
		return members
	for entry: Variant in raw:
		var member := from_dict(entry)
		if member == null:
			return []
		members.append(member)
	return members


static func list_to(members: Array[PartyMember]) -> Array[Dictionary]:
	var dicts: Array[Dictionary] = []
	for member in members:
		dicts.append(member.to_dict())
	return dicts


# Piège Godot : JSON ne distingue pas entiers et décimaux, tout nombre lu
# devient un float. On accepte 12.0 mais pas 2.5 ni "12".
static func _is_whole_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_equal_approx(value, roundf(value))

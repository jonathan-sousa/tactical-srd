## Tous les textes affichés par l'interface de combat, au même endroit pour
## faciliter une traduction plus tard. Le moteur ne produit que des codes et
## des nombres ; c'est ici qu'ils deviennent des phrases.
class_name Texts
extends RefCounted

const END_TURN := "Fin de tour"
const END_TURN_WITH_KEY := "Fin de tour (Espace)"
const HIT_POINTS := "PV"
const ARMOR_CLASS := "CA"
const MOVEMENT := "Déplacement"
const ACTION_AVAILABLE := "Action : disponible"
const ACTION_USED := "Action : utilisée"
const VICTORY := "Victoire"
const DEFEAT := "Défaite"
const REPLAY := "Rejouer"
const ENEMY_TURN := "Tour de l'adversaire…"
const NOTHING_LEFT := "Plus de déplacement ni d'action : terminez le tour (Espace)."

# --- Écrans et menus ------------------------------------------------------------

const PRESS_ANY_KEY := "Appuyez sur une touche"
const NEW_GAME := "Nouvelle partie"
const CONTINUE := "Continuer"
const OPTIONS := "Options"
const CREDITS := "Crédits"
const QUIT := "Quitter"
const COMING_SOON := "Bientôt disponible."
const NO_SAVE := "Aucune partie à continuer."
const NEW_GAME_CONFIRM_TITLE := "Nouvelle partie"
const NEW_GAME_CONFIRM := "Commencer une nouvelle partie ?\nLa progression actuelle sera perdue."
const CANCEL := "Annuler"
const PAUSE := "Pause"
const RESUME := "Reprendre"
const BACK_TO_MENU := "Retour au menu"
const BACK := "Retour"
const DEFEAT_MESSAGE := "Le Guerrier s'effondre. La route de Pierrefeu s'arrête ici… pour cette fois."
const RETRY_COMBAT := "Réessayer le combat"
const MAIN_MENU := "Menu principal"
const MASTER_VOLUME := "Volume général"
const FULLSCREEN := "Plein écran"
const SAVE_CORRUPT := "Sauvegarde illisible : impossible de reprendre la partie."
const SAVE_UNKNOWN_VERSION := "Sauvegarde créée par une autre version du jeu : impossible de la charger."
const STORY_COMPLETED := "Histoire terminée. Lancez une nouvelle partie pour la rejouer."
const CREDITS_RULES := "Règles"
const CREDITS_ENGINE := "Moteur"
const CREDITS_ASSETS := "Graphismes et police"
const CREDITS_ASSETS_BODY := "Plateau, pions et interface dessinés par le code du jeu. Police par défaut de Godot Engine (voir les licences ci-dessous)."
const CREDITS_TOOLS := "Outils"
const CREDITS_TOOLS_BODY := "Tests automatisés avec gdUnit4 (licence MIT), non inclus dans le jeu exporté."
const CREDITS_THIRD_PARTY := "Composants tiers de Godot Engine"
const CREDITS_LICENSES := "Textes des licences"
## Mention d'attribution officielle, recopiée mot pour mot depuis le SRD
## 5.2.1. Ne pas la traduire ni la reformuler (exigence de la licence).
const SRD_ATTRIBUTION := "This work includes material from the System Reference Document 5.2.1 (“SRD 5.2.1”) by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode."
const DIALOGUE_HINT := "Clic ou Entrée pour continuer"

const DAMAGE_TYPES: Dictionary[DamageType.Type, String] = {
	DamageType.Type.ACID: "d'acide",
	DamageType.Type.BLUDGEONING: "contondants",
	DamageType.Type.COLD: "de froid",
	DamageType.Type.FIRE: "de feu",
	DamageType.Type.FORCE: "de force",
	DamageType.Type.LIGHTNING: "de foudre",
	DamageType.Type.NECROTIC: "nécrotiques",
	DamageType.Type.PIERCING: "perforants",
	DamageType.Type.POISON: "de poison",
	DamageType.Type.PSYCHIC: "psychiques",
	DamageType.Type.RADIANT: "radiants",
	DamageType.Type.SLASHING: "tranchants",
	DamageType.Type.THUNDER: "de tonnerre",
}

const REASONS: Dictionary[StringName, String] = {
	Action.COMBAT_OVER: "Le combat est terminé.",
	Action.NOT_YOUR_TURN: "Ce n'est pas votre tour.",
	Action.SAME_CELL: "Vous êtes déjà sur cette case.",
	Action.CELL_UNREACHABLE: "Case inaccessible.",
	Action.NOT_ENOUGH_MOVEMENT: "Pas assez de déplacement pour aller jusque-là.",
	Action.ACTION_ALREADY_USED: "Action déjà utilisée ce tour-ci.",
	Action.TARGET_NOT_ENEMY: "Ce n'est pas un ennemi.",
	Action.TARGET_DOWN: "La cible est déjà à terre.",
	Action.TARGET_OUT_OF_REACH: "Hors de portée : placez-vous sur une case adjacente.",
	Action.NO_WEAPON: "Aucune arme équipée.",
}


static func reason(code: StringName) -> String:
	return REASONS.get(code, str(code))


static func damage_type(type: DamageType.Type) -> String:
	return DAMAGE_TYPES[type]


static func squares(count: int) -> String:
	return "%d case%s" % [count, "" if count <= 1 else "s"]


## Aide au survol d'une case libre : « Déplacement : 3 cases ».
static func move_hint(square_count: int) -> String:
	return "%s : %s" % [MOVEMENT, squares(square_count)]


## Aide au survol d'un ennemi : « Attaquer Gobelin guerrier : Épée à deux
## mains, + 5 2d6+3 ».
static func attack_hint(target: Combatant, weapon: WeaponDef, attack_bonus: int, damage: DiceExpression) -> String:
	return "Attaquer %s : %s, %s %s" % [target.definition.display_name, weapon.display_name, signed(attack_bonus), damage]


# --- Journal de combat ---------------------------------------------------------


static func initiative_line(entries: Array[InitiativeEntry]) -> String:
	var parts: PackedStringArray = []
	for entry in entries:
		parts.append("%s %d (%d %s)" % [entry.combatant.definition.display_name, entry.total, entry.d20, signed(entry.bonus)])
	return "Initiative : %s." % ", ".join(parts)


static func turn_line(event: TurnStartedEvent) -> String:
	return "— Round %d : tour de %s —" % [event.round, event.combatant.definition.display_name]


static func move_line(event: MovedEvent) -> String:
	return "%s se déplace de %s." % [event.combatant.definition.display_name, squares(event.path.size())]


## Exemple : « Gobelin guerrier attaque : 14 + 4 = 18 contre CA 16, touché,
## 5 dégâts tranchants (1d6+2 : 3 + 2) ».
static func attack_line(result: AttackResult) -> String:
	var roll := str(result.d20.natural)
	if result.d20.rolls.size() > 1:
		roll = "%d [%s]" % [result.d20.natural, ", ".join(result.d20.rolls.map(str))]

	var line := "%s attaque : %s %s = %d contre %s %d" % [
		result.attacker.definition.display_name,
		roll,
		signed(result.attack_bonus),
		result.attack_total,
		ARMOR_CLASS,
		result.target_armor_class,
	]
	if result.d20.is_natural_1():
		return line + ", 1 naturel, raté"
	if not result.is_hit:
		return line + ", raté"

	var outcome := "20 naturel, coup critique" if result.is_critical else "touché"
	return line + ", %s, %d dégâts %s (%s)" % [
		outcome,
		result.damage,
		damage_type(result.damage_type),
		_damage_detail(result.damage_roll),
	]


static func downed_line(combatant: Combatant) -> String:
	return "%s tombe à 0 PV." % combatant.definition.display_name


static func end_line(winner: Combatant.Side) -> String:
	return "%s !" % (VICTORY if winner == Combatant.Side.PLAYER else DEFEAT)


# « 2d6+3 : 4 + 2 + 3 »
static func _damage_detail(roll: DiceRoll) -> String:
	var terms: PackedStringArray = []
	for value in roll.rolls:
		terms.append(str(value))
	var text := "%s : %s" % [roll.expression, " + ".join(terms)]
	if roll.modifier > 0:
		text += " + %d" % roll.modifier
	elif roll.modifier < 0:
		text += " − %d" % -roll.modifier
	return text


## Bonus avec son signe : « + 4 » ou « − 1 ».
static func signed(value: int) -> String:
	return "+ %d" % value if value >= 0 else "− %d" % -value

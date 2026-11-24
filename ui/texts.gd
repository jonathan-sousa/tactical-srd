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
const REACTION_AVAILABLE := "Réaction : disponible"
const REACTION_USED := "Réaction : utilisée"
const BONUS_ACTION_AVAILABLE := "Action bonus : disponible"
const BONUS_ACTION_USED := "Action bonus : utilisée"
const SECOND_WIND := "Second souffle"
const HEROIC_INSPIRATION := "Inspiration héroïque"
const DEATH_SAVES := "Jets contre la mort"
const UNCONSCIOUS_TURN := "Inconscient : jet contre la mort au début de chaque tour."
const EFFECTS := "Effets"
const YES := "Oui"
const NO := "Non"
const VICTORY := "Victoire"
const DEFEAT := "Défaite"
const REPLAY := "Rejouer"
const ENEMY_TURN := "Tour de l'adversaire…"
const NOTHING_LEFT := "Plus de déplacement ni d'action : terminez le tour (Espace)."
## Aide au survol d'une case libre quand un ennemi est caché.
const BLIND_ATTACK_SHIFT_HINT := "Maj + clic : attaquer cette case à l'aveugle."

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
const MUSIC_VOLUME := "Musique"
const EFFECTS_VOLUME := "Effets"
const FULLSCREEN := "Plein écran"
const SAVE_CORRUPT := "Sauvegarde illisible : impossible de reprendre la partie."
const SAVE_UNKNOWN_VERSION := "Sauvegarde créée par une autre version du jeu : impossible de la charger."
const STORY_COMPLETED := "Histoire terminée. Lancez une nouvelle partie pour la rejouer."
const CREDITS_RULES := "Règles"
const CREDITS_ENGINE := "Moteur"
const CREDITS_ASSETS := "Graphismes et police"
## Ressources graphiques et police : une ligne par pack (voir assets/CREDITS.md).
const CREDITS_ASSETS_LINES: Array[String] = [
	"Tuiles du plateau : Tiny Town, par Kenney (www.kenney.nl), licence CC0.",
	"Pions et portraits : Tiny Dungeon, par Kenney (www.kenney.nl), licence CC0 ; le Gobelin est une tuile recolorée pour ce jeu.",
	"Panneaux et boutons : UI Pack RPG Expansion, par Kenney (www.kenney.nl), licence CC0.",
	"Police : Pixelify Sans, © 2021 The Pixelify Sans Project Authors, SIL Open Font License 1.1 (texte ci-dessous).",
]
const CREDITS_FONT_LICENSE := "Pixelify Sans — SIL Open Font License 1.1"
const CREDITS_TOOLS := "Outils"
const CREDITS_TOOLS_BODY := "Tests automatisés avec gdUnit4 (licence MIT), non inclus dans le jeu exporté."
const CREDITS_THIRD_PARTY := "Composants tiers de Godot Engine"
const CREDITS_LICENSES := "Textes des licences"
## Mention d'attribution officielle, recopiée mot pour mot depuis le SRD
## 5.2.1. Ne pas la traduire ni la reformuler (exigence de la licence).
const SRD_ATTRIBUTION := "This work includes material from the System Reference Document 5.2.1 (“SRD 5.2.1”) by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode."
const DIALOGUE_HINT := "Clic ou Entrée pour continuer"
const DIALOGUE_SKIP := "Passer (Tab)"
const DIALOGUE_HISTORY := "Historique (H)"
const DIALOGUE_HISTORY_CLOSE := "Fermer l'historique (H)"
const LARGE_TEXT := "Texte agrandi"
## Textes flottants au-dessus des pions.
const FLOAT_MISS := "Raté !"
const FLOAT_CRITICAL := "Critique !"

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
	Action.TARGET_DEAD: "La cible est morte.",
	Action.TARGET_OUT_OF_REACH: "Hors de portée : placez-vous sur une case adjacente.",
	Action.NO_WEAPON: "Aucune arme équipée.",
	Action.TARGET_OUT_OF_RANGE: "Hors de portée de l'arme.",
	Action.TARGET_NOT_VISIBLE: "Cible hors de vue : un obstacle la protège entièrement.",
	Action.NO_AMMUNITION: "Plus aucun exemplaire de cette arme.",
	Action.BONUS_ACTION_ALREADY_USED: "Action bonus déjà utilisée ce tour-ci.",
	Action.NO_USES_LEFT: "Plus aucune utilisation.",
	Action.FEATURE_UNAVAILABLE: "Capacité indisponible.",
	Action.DECISION_PENDING: "Une décision est en attente.",
	Action.NO_DECISION_PENDING: "Aucune décision en attente.",
	Action.NOT_YOUR_DECISION: "Ce n'est pas à vous de décider.",
	Action.INCAPACITATED: "Inconscient : impossible d'agir.",
	Action.ALREADY_HIDDEN: "Déjà caché.",
	Action.SEEN_BY_ENEMY: "Un ennemi vous voit : impossible de se cacher.",
	Action.NOTHING_TO_SEARCH: "Aucun ennemi caché à chercher.",
	Action.NO_TARGET: "Aucune cible à attaquer ici.",
	Action.PRONE: "À terre : relevez-vous d'abord.",
	Action.NOT_PRONE: "Vous n'êtes pas à terre.",
}

## Identifiant de Second Wind dans la barre d'actions.
const SECOND_WIND_ID := &"second_wind"

## Noms des actions de la barre, tels que le SRD français les nomme.
const ACTION_NAMES: Dictionary[StringName, String] = {
	StandardAction.DASH: "Foncer",
	StandardAction.DISENGAGE: "Se désengager",
	StandardAction.DODGE: "Esquiver",
	SECOND_WIND_ID: SECOND_WIND,
	SearchAction.ID: "Chercher",
	StandUpAction.ID: "Se relever",
	HideAction.ID: "Se cacher",
}

const ACTION_DESCRIPTIONS: Dictionary[StringName, String] = {
	StandardAction.DASH: "Déplacement supplémentaire égal à votre vitesse, pour ce tour.",
	StandardAction.DISENGAGE: "Vos déplacements ne provoquent plus d'attaque d'opportunité jusqu'à la fin du tour.",
	StandardAction.DODGE: "Jusqu'au début de votre prochain tour, les attaques contre vous ont le désavantage si vous voyez l'attaquant.",
	SECOND_WIND_ID: "Action bonus : regagnez 1d10 + 1 PV. Deux utilisations par partie.",
	SearchAction.ID: "Test de Sagesse (Perception) : un ennemi caché dont vous atteignez le jet de Discrétion est trouvé.",
	StandUpAction.ID: "À terre, se relever coûte la moitié de votre vitesse (3 cases).",
	HideAction.ID: "Test de Dextérité (Discrétion) contre DD 15, hors de vue de tout ennemi.",
}

## Journal : « Guerrier fonce. »
const ACTION_LOG: Dictionary[StringName, String] = {
	StandardAction.DASH: "%s fonce : son déplacement double pour ce tour.",
	StandardAction.DISENGAGE: "%s se désengage : pas d'attaque d'opportunité contre lui ce tour-ci.",
	StandardAction.DODGE: "%s esquive : les attaques contre lui auront le désavantage.",
}

const EFFECT_NAMES: Dictionary[StringName, String] = {
	Effect.DODGING: "Esquive",
	Effect.DISENGAGED: "Désengagé",
	Effect.SAPPED: "Sapé",
	Effect.SLOWED: "Ralenti",
	Effect.HIDDEN: "Caché",
	Effect.PRONE: "À terre",
}

const EFFECT_APPLIED_LOG: Dictionary[StringName, String] = {
	Effect.DODGING: "%s esquive.",
	Effect.DISENGAGED: "%s se désengage.",
	Effect.SAPPED: "%s est sapé (Sap) : désavantage à sa prochaine attaque.",
	Effect.SLOWED: "%s est ralenti (Slow) : 10 ft (2 cases) de vitesse en moins.",
	Effect.HIDDEN: "%s se cache.",
	Effect.PRONE: "%s tombe à terre.",
}

const EFFECT_ENDED_LOG: Dictionary[StringName, String] = {
	Effect.DODGING: "%s n'esquive plus.",
	Effect.DISENGAGED: "%s n'est plus désengagé.",
	Effect.SAPPED: "%s n'est plus sapé.",
	Effect.SLOWED: "%s n'est plus ralenti.",
	Effect.HIDDEN: "%s n'est plus caché.",
	Effect.PRONE: "%s se relève.",
}

## Maîtrises d'arme, nommées comme dans le SRD 5.2.1 (en anglais).
const MASTERY_DESCRIPTIONS: Dictionary[StringName, String] = {
	WeaponDef.GRAZE: "Graze : en cas d'échec, inflige quand même votre modificateur de caractéristique.",
	WeaponDef.SAP: "Sap : la cible touchée a le désavantage à sa prochaine attaque.",
	WeaponDef.SLOW: "Slow : la cible touchée perd 10 ft de vitesse jusqu'à votre prochain tour.",
	WeaponDef.NICK: "Nick : l'attaque supplémentaire de l'arme Légère fait partie de l'action Attaque.",
	WeaponDef.VEX: "Vex : avantage à votre prochaine attaque contre la cible touchée.",
}

const PROPERTY_NAMES: Dictionary[StringName, String] = {
	WeaponDef.FINESSE: "Finesse",
	WeaponDef.HEAVY: "Lourde",
	WeaponDef.LIGHT: "Légère",
	WeaponDef.THROWN: "Lancer",
	WeaponDef.TWO_HANDED: "Deux mains",
	WeaponDef.VERSATILE: "Polyvalente",
	WeaponDef.AMMUNITION: "Munitions",
}

## Pastille d'un effet sur un pion : une lettre.
const EFFECT_BADGES: Dictionary[StringName, String] = {
	Effect.DODGING: "E",
	Effect.DISENGAGED: "D",
	Effect.SAPPED: "S",
	Effect.SLOWED: "R",
	Effect.HIDDEN: "C",
	Effect.PRONE: "T",
}

## Raisons d'avantage ou de désavantage, affichées après le jet.
const ADVANTAGE_REASONS: Dictionary[StringName, String] = {
	AdvantageResolver.TARGET_DODGING: "la cible esquive",
	AdvantageResolver.ATTACKER_SAPPED: "attaquant sapé",
	AdvantageResolver.LONG_RANGE: "longue portée",
	AdvantageResolver.HOSTILE_NEARBY: "ennemi au contact",
	AdvantageResolver.ATTACKER_HIDDEN: "attaquant caché",
	AdvantageResolver.TARGET_UNSEEN: "cible invisible",
	AdvantageResolver.TARGET_UNCONSCIOUS: "cible inconsciente",
	AdvantageResolver.TARGET_PRONE: "cible à terre au contact",
	AdvantageResolver.TARGET_PRONE_FAR: "cible à terre, de loin",
	AdvantageResolver.ATTACKER_PRONE: "attaquant à terre",
}

## Causes de mort, pour le journal.
const DEATH_CAUSES: Dictionary[StringName, String] = {
	CombatantDiedEvent.MONSTER_AT_ZERO: "%s tombe à 0 PV et meurt.",
	CombatantDiedEvent.MASSIVE_DAMAGE: "Dégâts massifs : %s meurt sur le coup.",
	CombatantDiedEvent.DEATH_SAVES: "Troisième échec : %s meurt.",
}


static func reason(code: StringName) -> String:
	return REASONS.get(code, str(code))


static func damage_type(type: DamageType.Type) -> String:
	return DAMAGE_TYPES[type]


static func action_name(kind: StringName) -> String:
	return ACTION_NAMES[kind]


static func effect_name(id: StringName) -> String:
	return EFFECT_NAMES.get(id, str(id))


## Liste des effets d'un combattant : « Effets : Esquive, Désengagé ».
static func effects_line(ids: Array[StringName]) -> String:
	var names: PackedStringArray = []
	for id in ids:
		names.append(effect_name(id))
	return "%s : %s" % [EFFECTS, ", ".join(names)]


## Question posée au joueur quand un ennemi quitte son allonge.
static func reaction_prompt(mover: Combatant) -> String:
	return "%s quitte votre allonge.\nAttaque d'opportunité ?" % mover.definition.display_name


## Question posée au joueur après une attaque ratée.
static func inspiration_prompt(result: AttackResult) -> String:
	return "Attaque ratée : %d contre %s %d.\nRelancer le d20 grâce à l'%s ?" % [
		result.attack_total, ARMOR_CLASS, result.target_armor_class, HEROIC_INSPIRATION.to_lower(),
	]


## Question posée au joueur après un jet contre la mort raté.
static func death_save_inspiration_prompt(natural: int) -> String:
	var failures := "deux échecs" if natural == 1 else "un échec"
	return "Jet contre la mort : %d, %s.\nRelancer le d20 grâce à l'%s ?" % [natural, failures, HEROIC_INSPIRATION.to_lower()]


## « Jets contre la mort : 1 réussite, 2 échecs ».
static func death_saves_line(combatant: Combatant) -> String:
	return "%s : %s, %s" % [
		DEATH_SAVES,
		_count(combatant.death_save_successes, "réussite"),
		_count(combatant.death_save_failures, "échec"),
	]


static func _count(value: int, noun: String) -> String:
	return "%d %s%s" % [value, noun, "" if value <= 1 else "s"]


## « Action bonus : disponible ».
static func bonus_action_line(used: bool) -> String:
	return BONUS_ACTION_USED if used else BONUS_ACTION_AVAILABLE


## « Second souffle : 2 / 2 · Inspiration héroïque : oui ».
static func resources_line(combatant: Combatant) -> String:
	var parts: PackedStringArray = []
	if combatant.definition.second_wind_uses > 0:
		parts.append("%s : %d / %d" % [SECOND_WIND, combatant.second_wind_uses, combatant.definition.second_wind_uses])
	if combatant.definition.heroic_inspiration:
		parts.append("%s : %s" % ["Inspiration", "oui" if combatant.heroic_inspiration else "non"])
	return " · ".join(parts)


## Texte d'un bouton d'arme : « Javelot ×8 ».
static func weapon_button(combatant: Combatant, weapon: WeaponDef) -> String:
	var name := weapon.short_name if not weapon.short_name.is_empty() else weapon.display_name
	if combatant.quantities.has(weapon.id):
		return "%s ×%d" % [name, combatant.quantity(weapon)]
	return name


## Fiche d'une arme pour l'infobulle : bonus, dégâts, portée, propriétés,
## maîtrise.
@warning_ignore("integer_division")
static func weapon_tooltip(combatant: Combatant, weapon: WeaponDef) -> String:
	var expression := DiceExpression.parse(weapon.damage_dice).with_modifier(combatant.damage_modifier(weapon))
	var lines: PackedStringArray = [
		"%s : %s au toucher, %s dégâts %s" % [weapon.display_name, signed(combatant.attack_bonus(weapon)), expression, damage_type(weapon.damage_type)],
	]
	if weapon.has_range():
		lines.append("Portée %d / %d ft (%s / %s)" % [
			weapon.range_normal_feet, weapon.range_long_feet,
			squares(weapon.range_normal_feet / CombatState.FEET_PER_SQUARE),
			squares(weapon.range_long_feet / CombatState.FEET_PER_SQUARE),
		])
	var properties: PackedStringArray = []
	for property in weapon.properties:
		properties.append(PROPERTY_NAMES.get(property, str(property)))
	if not properties.is_empty():
		lines.append("Propriétés : %s" % ", ".join(properties))
	if combatant.definition.masters(weapon):
		lines.append(MASTERY_DESCRIPTIONS.get(weapon.mastery, str(weapon.mastery)))
	return "\n".join(lines)


static func squares(count: int) -> String:
	return "%d case%s" % [count, "" if count <= 1 else "s"]


## Aide au survol d'une case libre : « Déplacement : 3 cases », et
## l'avertissement si le trajet provoque une attaque d'opportunité.
static func move_hint(square_count: int, opportunity_attackers: Array[Combatant] = []) -> String:
	var line := "%s : %s" % [MOVEMENT, squares(square_count)]
	if not opportunity_attackers.is_empty():
		var names: PackedStringArray = []
		for attacker in opportunity_attackers:
			names.append(attacker.definition.display_name)
		line += ". Attention : attaque d'opportunité de %s (Se désengager l'évite)." % ", ".join(names)
	return line


## Panneau de la cible : « Gobelin guerrier · PV 7 / 10 · CA 15 · Caché ».
static func target_line(combatant: Combatant, effect_ids: Array[StringName]) -> String:
	var parts: PackedStringArray = [
		combatant.definition.display_name,
		"%s %d / %d" % [HIT_POINTS, combatant.hp, combatant.definition.max_hp],
		"%s %d" % [ARMOR_CLASS, combatant.armor_class()],
	]
	if combatant.is_dead:
		parts.append("mort")
	elif combatant.is_down():
		parts.append("inconscient")
	for id in effect_ids:
		parts.append(effect_name(id))
	return " · ".join(parts)


## En-tête d'un nouveau round dans le journal.
static func round_header(round: int) -> String:
	return "Round %d" % round


## Aide au survol d'un ennemi, d'après la prévision du moteur :
## « Attaquer Gobelin guerrier (Épée à deux mains) : 55 % de toucher, 9 à
## 15 dégâts ; Graze : 3 si raté ».
static func attack_hint(target: Combatant, weapon: WeaponDef, estimate: AttackEstimate) -> String:
	var line := "Attaquer %s (%s) : %s de toucher, %s dégâts" % [
		target.definition.display_name, weapon.display_name, percent(estimate.hit_chance),
		_range_text(estimate.damage_min, estimate.damage_max),
	]
	if estimate.critical_chance >= estimate.hit_chance and estimate.hit_chance > 0.0:
		line += " (toujours critique)"
	if estimate.graze_damage > 0:
		line += " ; Graze : %d si raté" % estimate.graze_damage
	return line + _advantage_detail(estimate.advantage)


## « 55 % ».
static func percent(chance: float) -> String:
	return "%d %%" % roundi(chance * 100.0)


static func _range_text(low: int, high: int) -> String:
	return str(low) if low == high else "%d à %d" % [low, high]


## Aide au survol de la dernière position connue d'un ennemi caché.
static func blind_attack_hint(weapon: WeaponDef) -> String:
	return "Attaque à l'aveugle (%s) : désavantage, et ratée si personne n'est là." % weapon.display_name


# --- Journal de combat ---------------------------------------------------------


static func initiative_line(entries: Array[InitiativeEntry]) -> String:
	var parts: PackedStringArray = []
	for entry in entries:
		var roll := str(entry.d20)
		if entry.roll.rolls.size() > 1:
			var why := "caché, avantage" if entry.roll.mode == Dice.RollMode.ADVANTAGE else "surpris, désavantage"
			roll = "%d [%s ; %s]" % [entry.d20, ", ".join(entry.roll.rolls.map(str)), why]
		parts.append("%s %d (%s %s)" % [entry.combatant.definition.display_name, entry.total, roll, signed(entry.bonus)])
	return "Initiative : %s." % ", ".join(parts)


static func turn_line(event: TurnStartedEvent) -> String:
	return "Tour de %s" % event.combatant.definition.display_name


static func move_line(event: MovedEvent) -> String:
	return "%s se déplace de %s." % [event.combatant.definition.display_name, squares(event.path.size())]


## Ligne principale du journal : qui attaque, avec quoi, et le résultat.
## Exemple : « Gobelin guerrier attaque (Cimeterre) : touché, 5 dégâts
## tranchants ». Le détail des jets suit sur une ligne à part.
static func attack_summary(result: AttackResult) -> String:
	var verb := "attaque"
	if result.advantage != null and result.advantage.disadvantages.has(AdvantageResolver.TARGET_UNSEEN):
		verb = "attaque à l'aveugle"
	elif result.is_opportunity:
		verb = "attaque d'opportunité"
	elif result.is_ranged:
		verb = "lance" if result.weapon.has_property(WeaponDef.THROWN) else "tire"
	var outcome := "raté"
	if result.d20.is_natural_1():
		outcome = "1 naturel, raté"
	elif result.is_hit:
		var hit := "touché"
		if result.is_critical:
			hit = "20 naturel, coup critique" if result.d20.is_natural_20() else "coup critique (cible inconsciente au contact)"
		outcome = "%s, %d dégâts %s" % [hit, result.damage, damage_type(result.damage_type)]
	return "%s %s (%s) : %s" % [result.attacker.definition.display_name, verb, result.weapon.display_name, outcome]


## Détail des jets d'une attaque : « 14 + 4 = 18 contre CA 16 ; 1d6+2 : 3 + 2 ».
static func attack_detail(result: AttackResult) -> String:
	var roll := str(result.d20.natural)
	if result.d20.rolls.size() > 1:
		roll = "%d [%s]" % [result.d20.natural, ", ".join(result.d20.rolls.map(str))]
	var line := "%s %s = %d contre %s %d" % [roll, signed(result.attack_bonus), result.attack_total, ARMOR_CLASS, result.target_armor_class]
	if result.is_hit:
		line += " ; %s" % _damage_detail(result.damage_roll)
		if result.discarded_damage_roll != null:
			line += " ; meilleur de deux jets, l'autre faisait %d" % result.discarded_damage_roll.total
		if result.advantage_damage_roll != null:
			line += " ; avec l'avantage, %s" % _damage_detail(result.advantage_damage_roll)
	return line + _advantage_detail(result.advantage)


# « (désavantage : la cible esquive) », vide sans avantage ni désavantage.
static func _advantage_detail(advantage: AdvantageResult) -> String:
	if advantage == null:
		return ""
	var parts: PackedStringArray = []
	if not advantage.advantages.is_empty():
		parts.append("avantage : %s" % _reasons(advantage.advantages))
	if not advantage.disadvantages.is_empty():
		parts.append("désavantage : %s" % _reasons(advantage.disadvantages))
	if parts.is_empty():
		return ""
	var cancelled := " ; ils s'annulent" if parts.size() == 2 else ""
	return " (%s%s)" % [" ; ".join(parts), cancelled]


static func _reasons(codes: Array[StringName]) -> String:
	var texts: PackedStringArray = []
	for code in codes:
		texts.append(ADVANTAGE_REASONS.get(code, str(code)))
	return ", ".join(texts)


static func action_line(event: ActionTakenEvent) -> String:
	var line: String = ACTION_LOG[event.action] % event.combatant.definition.display_name
	if event.bonus_action:
		line += " (Nimble Escape, action bonus)"
	return line


## « Gobelin guerrier se cache (Nimble Escape). » Le total du jet reste
## secret tant qu'on ne l'a pas trouvé : c'est le DD pour le trouver.
static func hide_line(event: HideAttemptedEvent) -> String:
	var name := event.combatant.definition.display_name
	var how := " (Nimble Escape)" if event.bonus_action else ""
	if event.success:
		return "%s se cache%s : invisible tant qu'on ne l'a pas trouvé." % [name, how]
	return "%s tente de se cacher%s : Discrétion %d %s = %d contre DD %d, raté." % [
		name, how, event.d20, signed(event.bonus), event.total, CombatState.HIDE_DC,
	]


static func revealed_line(event: RevealedEvent) -> String:
	var name := event.combatant.definition.display_name
	if event.reason == RevealedEvent.ATTACKED:
		return "%s sort de sa cachette pour attaquer !" % name
	return "%s est trouvé : il n'est plus caché." % name


static func search_line(event: SearchedEvent) -> String:
	var name := event.combatant.definition.display_name
	var roll := "Perception %d %s = %d" % [event.d20, signed(event.bonus), event.total]
	if event.found.is_empty():
		return "%s cherche (%s) : rien." % [name, roll]
	var found: PackedStringArray = []
	for i in event.found.size():
		found.append("%s (Discrétion %d)" % [event.found[i].definition.display_name, event.found_dcs[i]])
	return "%s cherche (%s) et trouve %s." % [name, roll, ", ".join(found)]


static func empty_cell_attack_line(event: AttackedEmptyCellEvent) -> String:
	return "%s attaque à l'aveugle (%s) : il n'y a personne, raté." % [event.attacker.definition.display_name, event.weapon.display_name]


static func death_save_line(event: DeathSaveEvent) -> String:
	var name := event.combatant.definition.display_name
	var tally := "%s, %s" % [_count(event.successes, "réussite"), _count(event.failures, "échec")]
	if event.natural == 0:
		var hit := "deux échecs (coup critique)" if event.critical else "un échec"
		return "%s est frappé à 0 PV : %s aux jets contre la mort (%s)." % [name, hit, tally]
	if event.revived:
		return "Jet contre la mort de %s : 20 naturel ! Il reprend connaissance avec 1 PV, toujours à terre." % name
	var outcome := "réussite"
	if event.natural == 1:
		outcome = "1 naturel, deux échecs"
	elif event.natural < HitPoints.DEATH_SAVE_DC:
		outcome = "échec"
	return "Jet contre la mort de %s : %d, %s (%s)." % [name, event.natural, outcome, tally]


static func stabilized_line(event: CombatantStabilizedEvent) -> String:
	return "Trois réussites : %s est stabilisé, mais reste inconscient." % event.combatant.definition.display_name


static func died_line(event: CombatantDiedEvent) -> String:
	return DEATH_CAUSES[event.cause] % event.combatant.definition.display_name


static func effect_applied_line(event: EffectAppliedEvent) -> String:
	return EFFECT_APPLIED_LOG[event.effect_id] % event.combatant.definition.display_name


## Ligne du journal pour des dégâts sans jet propre (Graze). Les dégâts
## d'une attaque qui touche sont déjà sur la ligne de l'attaque.
static func graze_line(event: DamageDealtEvent) -> String:
	return "Graze : %s subit quand même %d dégâts %s." % [event.target.definition.display_name, event.amount, damage_type(event.damage_type)]


static func healed_line(event: HealedEvent) -> String:
	return "%s reprend son souffle : +%d PV (%s), %d PV." % [
		event.combatant.definition.display_name, event.amount, _damage_detail(event.roll), event.hp_after,
	]


static func inspiration_used_line(event: InspirationUsedEvent) -> String:
	return "%s dépense son %s : le %d devient %d." % [
		event.combatant.definition.display_name, HEROIC_INSPIRATION.to_lower(), event.old_value, event.new_value,
	]


static func effect_ended_line(event: EffectEndedEvent) -> String:
	return EFFECT_ENDED_LOG[event.effect_id] % event.combatant.definition.display_name


static func reaction_triggered_line(event: ReactionTriggeredEvent) -> String:
	return "%s quitte l'allonge de %s." % [event.mover.definition.display_name, event.reactor.definition.display_name]


static func reaction_declined_line(event: ReactionDeclinedEvent) -> String:
	return "%s laisse passer %s." % [event.reactor.definition.display_name, event.mover.definition.display_name]


static func downed_line(combatant: Combatant) -> String:
	return "%s tombe à 0 PV : inconscient et à terre." % combatant.definition.display_name


static func end_line(winner: Combatant.Side) -> String:
	return "%s !" % (VICTORY if winner == Combatant.Side.PLAYER else DEFEAT)


# « 2d6+3 : 4 + 2 + 3 », et « 1→3 » pour un dé relevé par Great Weapon
# Fighting.
static func _damage_detail(roll: DiceRoll) -> String:
	var terms: PackedStringArray = []
	for i in roll.rolls.size():
		var value := roll.rolls[i]
		var natural := roll.natural_rolls[i]
		terms.append(str(value) if value == natural else "%d→%d" % [natural, value])
	var text := "%s : %s" % [roll.expression, " + ".join(terms)]
	if roll.modifier > 0:
		text += " + %d" % roll.modifier
	elif roll.modifier < 0:
		text += " − %d" % -roll.modifier
	return text


## Bonus avec son signe : « + 4 » ou « − 1 ».
static func signed(value: int) -> String:
	return "+ %d" % value if value >= 0 else "− %d" % -value

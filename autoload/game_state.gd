## Progression de la partie : étape courante de l'histoire et état persistant
## du personnage. Avance dans `story.tres` et prévient quand la progression
## change (la sauvegarde automatique s'y abonne).
##
## Note Godot : un autoload est un Node créé au lancement du jeu et
## accessible partout par son nom (ici `GameState`), comme un singleton
## global. Il survit aux changements de scène.
##
## La logique (`complete_step`) ne change jamais de scène : elle dit
## seulement quoi afficher ensuite. C'est `enter`/`go_to_current_step` qui
## navigue, via SceneRouter. Les tests n'utilisent que la logique.
extends Node

## Émis à chaque nouvelle étape franchie, à la nouvelle partie et à la fin.
signal progress_changed

enum Outcome { DONE, VICTORY, DEFEAT }
enum Next { STEP, DEFEAT_SCREEN, END }

## Fiches du groupe, dans l'ordre (celui des cases de départ des rencontres).
const PARTY_IDS: Array[StringName] = [&"fighter_lvl1"]

var registry: DataRegistry
var story: StoryDef
## Étape en cours. Vide quand aucune partie n'est en cours.
var current_step_id: StringName = &""
var story_completed := false
## PV et ressources de chaque personnage, dans l'ordre du groupe. Les
## ressources ne reviennent qu'avec un repos, absent du jeu : elles sont
## comptées sur toute la partie.
var party: Array[PartyMember] = []


func _ready() -> void:
	setup(DataRegistry.load_from())


func setup(p_registry: DataRegistry) -> void:
	registry = p_registry
	story = registry.story
	for error in registry.errors():
		push_error("Données : %s" % error)
	# Garde-fou : dans un jeu exporté, un registre vide passerait sinon
	# inaperçu jusqu'au premier combat.
	for id in PARTY_IDS:
		if registry.character(id) == null:
			push_error("Données : fiche du joueur « %s » introuvable." % id)


## Fiches du groupe, dans l'ordre. Vide si l'une d'elles manque.
func party_definitions() -> Array[CharacterDef]:
	var definitions: Array[CharacterDef] = []
	for id in PARTY_IDS:
		var definition := registry.character(id)
		if definition == null:
			return []
		definitions.append(definition)
	return definitions


func has_game() -> bool:
	return not current_step_id.is_empty()


func current_step() -> StoryStep:
	if story == null or current_step_id.is_empty():
		return null
	return story.get_step(current_step_id)


func new_game() -> void:
	current_step_id = story.first_step
	story_completed = false
	party.clear()
	for definition in party_definitions():
		party.append(PartyMember.fresh(definition))
	progress_changed.emit()


## Reprend une partie sauvegardée. Renvoie faux si l'étape n'existe plus ou
## si le groupe sauvegardé n'est pas celui du jeu (mêmes fiches, même ordre).
## Les valeurs sont ramenées dans ce que permettent les fiches.
func restore(step_id: StringName, members: Array[PartyMember], completed: bool) -> bool:
	if not step_id.is_empty() and story.get_step(step_id) == null:
		return false
	var definitions := party_definitions()
	if members.size() != definitions.size():
		return false
	for i in members.size():
		if members[i].id != definitions[i].id:
			return false
	for i in members.size():
		members[i].clamp_to(definitions[i])
	current_step_id = step_id
	party = members
	story_completed = completed
	return true


## L'étape courante est terminée avec ce résultat. Renvoie ce qu'il faut
## afficher ensuite, sans changer de scène. Après une victoire, `survivors`
## est le groupe à la fin du combat : chacun garde ses PV et ses ressources.
func complete_step(outcome: Outcome, survivors: Array[Combatant] = []) -> Next:
	var step := current_step()
	assert(step != null, "Aucune étape en cours.")

	if outcome == Outcome.DEFEAT:
		if step.defeat_step.is_empty():
			# On reste sur le combat : « Réessayer » le relance à l'identique.
			return Next.DEFEAT_SCREEN
		current_step_id = step.defeat_step
		progress_changed.emit()
		return Next.STEP

	if outcome == Outcome.VICTORY:
		for survivor in survivors:
			for i in party.size():
				if party[i].id == survivor.definition.id and survivor.hp > 0:
					party[i] = PartyMember.of(survivor)

	if step.is_end():
		current_step_id = &""
		story_completed = true
		progress_changed.emit()
		return Next.END

	current_step_id = step.next_step
	progress_changed.emit()
	return Next.STEP


# --- Navigation ----------------------------------------------------------------


## Termine l'étape puis affiche la suite.
func finish_step(outcome: Outcome, survivors: Array[Combatant] = []) -> void:
	enter(complete_step(outcome, survivors))


func enter(next: Next) -> void:
	match next:
		Next.STEP:
			go_to_current_step()
		Next.DEFEAT_SCREEN:
			SceneRouter.go_to(SceneRouter.DEFEAT)
		Next.END:
			SceneRouter.go_to(SceneRouter.MENU)


## Affiche la scène de l'étape courante (dialogue ou combat).
func go_to_current_step() -> void:
	var step := current_step()
	if step == null:
		SceneRouter.go_to(SceneRouter.MENU)
	elif step.kind == StoryStep.Kind.DIALOGUE:
		SceneRouter.go_to(SceneRouter.DIALOGUE)
	else:
		SceneRouter.go_to(SceneRouter.COMBAT)

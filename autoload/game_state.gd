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

const PLAYER_ID := &"fighter_lvl1"

var registry: DataRegistry
var story: StoryDef
## Étape en cours. Vide quand aucune partie n'est en cours.
var current_step_id: StringName = &""
var story_completed := false
var player_hp := 0
## Ressources du Guerrier qui ne reviennent qu'avec un repos, absent du jeu :
## elles sont comptées sur toute la partie.
var player_second_wind_uses := 0
var player_heroic_inspiration := false


func _ready() -> void:
	setup(DataRegistry.load_from())


func setup(p_registry: DataRegistry) -> void:
	registry = p_registry
	story = registry.story
	for error in registry.errors():
		push_error("Données : %s" % error)
	# Garde-fou : dans un jeu exporté, un registre vide passerait sinon
	# inaperçu jusqu'au premier combat.
	if player_definition() == null:
		push_error("Données : fiche du joueur « %s » introuvable." % PLAYER_ID)


func player_definition() -> CharacterDef:
	return registry.character(PLAYER_ID)


func has_game() -> bool:
	return not current_step_id.is_empty()


func current_step() -> StoryStep:
	if story == null or current_step_id.is_empty():
		return null
	return story.get_step(current_step_id)


func new_game() -> void:
	current_step_id = story.first_step
	story_completed = false
	var definition := player_definition()
	player_hp = definition.max_hp
	player_second_wind_uses = definition.second_wind_uses
	player_heroic_inspiration = definition.heroic_inspiration
	progress_changed.emit()


## Reprend une partie sauvegardée. Renvoie faux si l'étape n'existe plus.
func restore(step_id: StringName, hp: int, completed: bool, second_wind_uses: int, heroic_inspiration: bool) -> bool:
	if not step_id.is_empty() and story.get_step(step_id) == null:
		return false
	var definition := player_definition()
	current_step_id = step_id
	player_hp = clampi(hp, 1, definition.max_hp)
	player_second_wind_uses = clampi(second_wind_uses, 0, definition.second_wind_uses)
	player_heroic_inspiration = heroic_inspiration and definition.heroic_inspiration
	story_completed = completed
	return true


## L'étape courante est terminée avec ce résultat. Renvoie ce qu'il faut
## afficher ensuite, sans changer de scène. Après une victoire, `survivor`
## est le Guerrier à la fin du combat : on garde ses PV et ses ressources.
func complete_step(outcome: Outcome, survivor: Combatant = null) -> Next:
	var step := current_step()
	assert(step != null, "Aucune étape en cours.")

	if outcome == Outcome.DEFEAT:
		if step.defeat_step.is_empty():
			# On reste sur le combat : « Réessayer » le relance à l'identique.
			return Next.DEFEAT_SCREEN
		current_step_id = step.defeat_step
		progress_changed.emit()
		return Next.STEP

	if outcome == Outcome.VICTORY and survivor != null and survivor.hp > 0:
		player_hp = survivor.hp
		player_second_wind_uses = survivor.second_wind_uses
		player_heroic_inspiration = survivor.heroic_inspiration

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
func finish_step(outcome: Outcome, survivor: Combatant = null) -> void:
	enter(complete_step(outcome, survivor))


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

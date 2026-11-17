## Registre des données du jeu : charge les fiches de `res://data` et les
## retrouve par leur id stable. La sauvegarde ne stocke que ces ids.
##
## Objet ordinaire (pas un autoload), donc testable sans lancer le jeu.
##
## Piège Godot : dans un jeu exporté, les .tres sont convertis en binaire et
## renommés (fichiers `.remap`). Parcourir le dossier avec DirAccess marche
## dans l'éditeur mais plus dans l'exécutable. `ResourceLoader.list_directory`
## renvoie les noms d'origine dans les deux cas.
class_name DataRegistry
extends RefCounted

const DATA_ROOT := "res://data"
const STORY_FILE := "story.tres"

var story: StoryDef

var _characters: Dictionary[StringName, CharacterDef] = {}
var _weapons: Dictionary[StringName, WeaponDef] = {}
var _encounters: Dictionary[StringName, EncounterDef] = {}
var _dialogues: Dictionary[StringName, DialogueDef] = {}
var _errors: Array[String] = []


## Charge tout le contenu de `root`. Les problèmes (fichier du mauvais type,
## id différent du nom de fichier) sont listés par `errors()`.
static func load_from(root: String = DATA_ROOT) -> DataRegistry:
	var registry := DataRegistry.new()
	registry._load_folder(root.path_join("characters"), registry._characters, "CharacterDef")
	registry._load_folder(root.path_join("weapons"), registry._weapons, "WeaponDef")
	registry._load_folder(root.path_join("encounters"), registry._encounters, "EncounterDef")
	registry._load_folder(root.path_join("dialogues"), registry._dialogues, "DialogueDef")
	registry._load_story(root.path_join(STORY_FILE))
	return registry


# --- Recherche par id ----------------------------------------------------------
# Un id inconnu renvoie `null` sans rien afficher : c'est à l'appelant de
# décider du message (par exemple une sauvegarde qui cite un id disparu).


func character(id: StringName) -> CharacterDef:
	return _characters.get(id)


func weapon(id: StringName) -> WeaponDef:
	return _weapons.get(id)


func encounter(id: StringName) -> EncounterDef:
	return _encounters.get(id)


func dialogue(id: StringName) -> DialogueDef:
	return _dialogues.get(id)


func errors() -> Array[String]:
	return _errors


# --- Chargement --------------------------------------------------------------


func _load_folder(folder: String, into: Dictionary, expected_class: StringName) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		_errors.append("Dossier introuvable : %s" % folder)
		return

	for file in ResourceLoader.list_directory(folder):
		if not file.ends_with(".tres"):
			continue
		var path := folder.path_join(file)
		var resource := ResourceLoader.load(path)
		if resource == null or resource.get_script() == null or resource.get_script().get_global_name() != expected_class:
			_errors.append("%s n'est pas un %s." % [path, expected_class])
			continue

		# Convention : l'id est le nom du fichier. Elle garantit aussi l'unicité
		# des ids dans un dossier.
		var id: StringName = resource.get("id")
		var expected_id := StringName(file.get_basename())
		if id != expected_id:
			_errors.append("%s : id « %s » différent du nom de fichier « %s »." % [path, id, expected_id])
			continue
		into[id] = resource


func _load_story(path: String) -> void:
	if not ResourceLoader.exists(path):
		_errors.append("Histoire introuvable : %s" % path)
		return
	story = ResourceLoader.load(path) as StoryDef
	if story == null:
		_errors.append("%s n'est pas un StoryDef." % path)

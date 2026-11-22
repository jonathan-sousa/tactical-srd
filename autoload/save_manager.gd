## Lecture et écriture de la sauvegarde (un seul emplacement, en JSON).
##
## - Écriture automatique à chaque changement d'étape (signal
##   `GameState.progress_changed`). Pas de sauvegarde en plein combat.
## - Écriture atomique : on écrit un fichier .tmp puis on le renomme. Un
##   plantage pendant l'écriture laisse la sauvegarde précédente intacte.
## - Champ `version` obligatoire, une fonction de migration par version.
## - Sécurité : on ne lit que du JSON, validé champ par champ. Jamais de
##   Resource (.tres, .res) depuis user:// : ces formats peuvent exécuter du
##   code embarqué.
##
## Note Godot : `user://` est le dossier de données du jeu propre à chaque
## joueur (sous Windows : %APPDATA%\Godot\app_userdata\Projet Phénix).
extends Node

enum Status { NONE, OK, CORRUPT, UNKNOWN_VERSION }

const CURRENT_VERSION := 1
const DEFAULT_PATH := "user://save_1.json"

## Fonctions de migration, indexées par la version qu'elles mettent à jour :
## MIGRATIONS[1] transformerait une sauvegarde v1 en v2. Vide tant qu'il
## n'existe qu'une version.
const MIGRATIONS: Dictionary[int, Callable] = {}

var path := DEFAULT_PATH
var status: Status = Status.NONE
## Contenu validé (et migré) de la sauvegarde quand `status` vaut OK.
var data: Dictionary = {}


func _ready() -> void:
	reload()
	watch(GameState)


## S'abonne à la progression d'une partie pour sauvegarder automatiquement.
func watch(game: Node) -> void:
	game.progress_changed.connect(func() -> void: save_game(game))


func has_save_file() -> bool:
	return FileAccess.file_exists(path)


## Vrai s'il existe une partie sauvegardée à reprendre.
func can_continue() -> bool:
	return status == Status.OK and not data["story_completed"] and not str(data["story_step"]).is_empty()


func status_message() -> String:
	match status:
		Status.CORRUPT:
			return Texts.SAVE_CORRUPT
		Status.UNKNOWN_VERSION:
			return Texts.SAVE_UNKNOWN_VERSION
	return ""


# --- Lecture -------------------------------------------------------------------


## Relit le fichier et met à jour `status` et `data`.
func reload() -> Status:
	data = {}
	if not has_save_file():
		status = Status.NONE
		return status

	# JSON.new().parse() renvoie un code d'erreur sans rien écrire dans la
	# console, contrairement à JSON.parse_string() : un fichier illisible est
	# un cas prévu, pas une erreur du jeu.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		status = Status.CORRUPT
		return status
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		status = Status.CORRUPT
		return status

	var raw: Dictionary = parsed
	if not _is_whole_number(raw.get("version")):
		status = Status.CORRUPT
		return status
	var version := int(raw["version"])
	if version > CURRENT_VERSION or (version < CURRENT_VERSION and not MIGRATIONS.has(version)):
		status = Status.UNKNOWN_VERSION
		return status

	var migrated := _migrate(raw, version)
	var validated := _validate(migrated)
	if validated.is_empty():
		status = Status.CORRUPT
		return status
	data = validated
	status = Status.OK
	return status


## Applique les migrations une par une jusqu'à la version courante.
func _migrate(raw: Dictionary, version: int) -> Dictionary:
	var current := raw
	while version < CURRENT_VERSION:
		current = MIGRATIONS[version].call(current)
		version += 1
	return current


## Renvoie une copie propre et typée, ou un dictionnaire vide si un champ
## manque ou n'a pas le bon type.
func _validate(raw: Dictionary) -> Dictionary:
	if typeof(raw.get("story_step")) != TYPE_STRING:
		return {}
	var completed: Variant = raw.get("story_completed", false)
	if typeof(completed) != TYPE_BOOL:
		return {}
	var player: Variant = raw.get("player")
	if typeof(player) != TYPE_DICTIONARY:
		return {}
	var player_dict: Dictionary = player
	if typeof(player_dict.get("def_id")) != TYPE_STRING:
		return {}
	var hp: Variant = player_dict.get("hp_current")
	if not _is_whole_number(hp) or int(hp) < 0:
		return {}
	var saved_at: Variant = raw.get("saved_at", "")
	return {
		"version": CURRENT_VERSION,
		"saved_at": saved_at if typeof(saved_at) == TYPE_STRING else "",
		"story_step": raw["story_step"],
		"story_completed": completed,
		"player": {"def_id": player_dict["def_id"], "hp_current": int(hp)},
	}


# Piège Godot : JSON ne distingue pas entiers et décimaux, tout nombre lu
# devient un float. On accepte 12.0 mais pas 2.5 ni "12".
static func _is_whole_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_equal_approx(value, roundf(value))


## Remet la partie sauvegardée dans GameState. Faux si la sauvegarde ne
## correspond plus aux données du jeu (étape ou personnage disparus).
func restore_into(game: Node) -> bool:
	if status != Status.OK:
		return false
	var player: Dictionary = data["player"]
	var known_player: bool = game.registry.character(StringName(player["def_id"])) != null
	if not known_player or not game.restore(StringName(data["story_step"]), player["hp_current"], data["story_completed"]):
		status = Status.CORRUPT
		return false
	return true


# --- Écriture ------------------------------------------------------------------


## Photographie de la partie, prête à écrire.
static func snapshot(game: Node) -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true) + "Z",
		"story_step": str(game.current_step_id),
		"story_completed": game.story_completed,
		"player": {"def_id": str(game.PLAYER_ID), "hp_current": game.player_hp},
	}


func save_game(game: Node) -> Error:
	var error := write(snapshot(game))
	if error != OK:
		push_error("Sauvegarde impossible (%s)." % error_string(error))
	reload()
	return error


## Écriture atomique : .tmp complet d'abord, puis renommage.
func write(save: Dictionary) -> Error:
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(save, "  "))
	file.close()
	if file.get_error() != OK:
		return file.get_error()
	# Le renommage remplace l'ancien fichier en une seule opération.
	return DirAccess.rename_absolute(tmp_path, path)

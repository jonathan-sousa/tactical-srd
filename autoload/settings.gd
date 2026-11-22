## Options du joueur (volume général, plein écran), persistées dans
## `user://settings.cfg` indépendamment de la sauvegarde, et appliquées au
## démarrage du jeu.
##
## Note Godot : ConfigFile lit et écrit un fichier de type .ini, avec des
## sections et des clés. On vérifie tout de même le type de chaque valeur :
## le fichier peut avoir été modifié à la main.
extends Node

const DEFAULT_PATH := "user://settings.cfg"
const DEFAULT_VOLUME := 1.0

var path := DEFAULT_PATH
## Volume général de 0.0 (muet) à 1.0.
var master_volume := DEFAULT_VOLUME
var fullscreen := false


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	master_volume = DEFAULT_VOLUME
	fullscreen = false
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	var volume: Variant = config.get_value("audio", "master_volume", DEFAULT_VOLUME)
	if typeof(volume) in [TYPE_FLOAT, TYPE_INT]:
		master_volume = clampf(float(volume), 0.0, 1.0)
	var full: Variant = config.get_value("display", "fullscreen", false)
	if typeof(full) == TYPE_BOOL:
		fullscreen = full


func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("display", "fullscreen", fullscreen)
	return config.save(path)


func set_master_volume(volume: float) -> void:
	master_volume = clampf(volume, 0.0, 1.0)
	apply_volume()
	save_settings()


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	apply_window_mode()
	save_settings()


func apply() -> void:
	apply_volume()
	apply_window_mode()


## Note Godot : le volume d'un bus audio se règle en décibels ; le bus 0 est
## le bus « Master » par lequel passent tous les sons.
func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, volume_to_db(master_volume))
	AudioServer.set_bus_mute(0, master_volume <= 0.0)


func apply_window_mode() -> void:
	# En mode headless (tests), il n'y a pas de fenêtre à régler.
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


static func volume_to_db(volume: float) -> float:
	return linear_to_db(maxf(volume, 0.0001))

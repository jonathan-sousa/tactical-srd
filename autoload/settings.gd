## Options du joueur (volumes général, musique et effets, plein écran, texte
## agrandi, PV ennemis exacts), persistées dans
## `user://settings.cfg` indépendamment de la sauvegarde, et appliquées au
## démarrage du jeu.
##
## Note Godot : ConfigFile lit et écrit un fichier de type .ini, avec des
## sections et des clés. On vérifie tout de même le type de chaque valeur :
## le fichier peut avoir été modifié à la main.
extends Node

## Émis quand le joueur change la taille du texte : les écrans ouverts
## s'adaptent aussitôt.
signal large_text_changed(enabled: bool)
## Émis quand le joueur choisit de voir ou non les PV exacts des ennemis.
signal exact_enemy_hp_changed(enabled: bool)

const DEFAULT_PATH := "user://settings.cfg"
const DEFAULT_VOLUME := 1.0

var path := DEFAULT_PATH
## Volumes de 0.0 (muet) à 1.0 : général, puis musique et effets, qui
## s'ajoutent au général. Un fichier d'avant le sprint 2 n'a que le volume
## général : les deux autres prennent alors leur valeur par défaut.
var master_volume := DEFAULT_VOLUME
var music_volume := DEFAULT_VOLUME
var effects_volume := DEFAULT_VOLUME
var fullscreen := false
## Texte agrandi dans le journal de combat, les aides et les dialogues.
var large_text := false
## PV exacts des ennemis. Par défaut, seulement leur état (Indemne, Blessé,
## En sang : voir HealthStatus), comme à une table de jeu.
var exact_enemy_hp := false


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	master_volume = DEFAULT_VOLUME
	music_volume = DEFAULT_VOLUME
	effects_volume = DEFAULT_VOLUME
	fullscreen = false
	large_text = false
	exact_enemy_hp = false
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	master_volume = _read_volume(config, "master_volume")
	music_volume = _read_volume(config, "music_volume")
	effects_volume = _read_volume(config, "effects_volume")
	var full: Variant = config.get_value("display", "fullscreen", false)
	if typeof(full) == TYPE_BOOL:
		fullscreen = full
	var large: Variant = config.get_value("display", "large_text", false)
	if typeof(large) == TYPE_BOOL:
		large_text = large
	var exact: Variant = config.get_value("gameplay", "exact_enemy_hp", false)
	if typeof(exact) == TYPE_BOOL:
		exact_enemy_hp = exact


func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "effects_volume", effects_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "large_text", large_text)
	config.set_value("gameplay", "exact_enemy_hp", exact_enemy_hp)
	return config.save(path)


func set_master_volume(volume: float) -> void:
	master_volume = clampf(volume, 0.0, 1.0)
	apply_volume()
	save_settings()


func set_music_volume(volume: float) -> void:
	music_volume = clampf(volume, 0.0, 1.0)
	apply_volume()
	save_settings()


func set_effects_volume(volume: float) -> void:
	effects_volume = clampf(volume, 0.0, 1.0)
	apply_volume()
	save_settings()


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	apply_window_mode()
	save_settings()


func set_large_text(enabled: bool) -> void:
	large_text = enabled
	save_settings()
	large_text_changed.emit(enabled)


func set_exact_enemy_hp(enabled: bool) -> void:
	exact_enemy_hp = enabled
	save_settings()
	exact_enemy_hp_changed.emit(enabled)


## Taille de police selon l'option : `normal`, ou `large` si le texte est
## agrandi.
func font_size(normal: int, large: int) -> int:
	return large if large_text else normal


func apply() -> void:
	apply_volume()
	apply_window_mode()


## Note Godot : le volume d'un bus audio se règle en décibels ; le bus
## « Master » reçoit tous les sons, dont ceux des bus « Music » et
## « Effects » (default_bus_layout.tres).
func apply_volume() -> void:
	_apply_bus(&"Master", master_volume)
	_apply_bus(&"Music", music_volume)
	_apply_bus(&"Effects", effects_volume)


static func _apply_bus(bus_name: StringName, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_error("Bus audio introuvable : %s" % bus_name)
		return
	AudioServer.set_bus_volume_db(index, volume_to_db(volume))
	AudioServer.set_bus_mute(index, volume <= 0.0)


static func _read_volume(config: ConfigFile, key: String) -> float:
	var volume: Variant = config.get_value("audio", key, DEFAULT_VOLUME)
	if typeof(volume) in [TYPE_FLOAT, TYPE_INT]:
		return clampf(float(volume), 0.0, 1.0)
	return DEFAULT_VOLUME


func apply_window_mode() -> void:
	# En mode headless (tests), il n'y a pas de fenêtre à régler.
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


static func volume_to_db(volume: float) -> float:
	return linear_to_db(maxf(volume, 0.0001))

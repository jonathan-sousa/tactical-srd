## Son du jeu : musique en fondu enchaîné sur le bus « Music », bruitages
## sur le bus « Effects » (voir default_bus_layout.tres). Les volumes des
## bus sont réglés par Settings.
##
## Les vues déclenchent les sons à partir des événements du moteur ; les
## règles (rules/) n'en savent rien.
##
## Note Godot : un AudioStreamPlayer joue un son (AudioStream) sur un bus.
## Ici, deux lecteurs servent à la musique (l'ancienne s'efface pendant que
## la nouvelle monte) et une petite réserve de lecteurs aux bruitages, pour
## que plusieurs sons puissent se chevaucher.
extends Node

const MUSIC_BUS := &"Music"
const EFFECTS_BUS := &"Effects"
const FADE_DURATION := 1.0
## Volume d'un lecteur muet, en décibels.
const SILENT_DB := -60.0
const EFFECT_PLAYERS := 8
## Attente avant de quitter, le temps que le mélangeur lâche les sons.
const QUIT_DELAY := 0.15

const MENU_MUSIC: AudioStream = preload("res://assets/audio/music/old_tower_inn.mp3")
const COMBAT_MUSIC: AudioStream = preload("res://assets/audio/music/battle.mp3")
const VICTORY_JINGLE: AudioStream = preload("res://assets/audio/jingles/jingles_STEEL00.ogg")
const DEFEAT_JINGLE: AudioStream = preload("res://assets/audio/jingles/jingles_PIZZI03.ogg")

# Bruitages, par nom. Un nom peut avoir plusieurs variantes, tirées au
# hasard pour éviter la répétition (des pas, par exemple).
const STEP := &"step"
const SWING := &"swing"
const THROW := &"throw"
const HIT := &"hit"
const CRITICAL := &"critical"
const GRAZE := &"graze"
const MISS := &"miss"
const HEAL := &"heal"
const HIDE := &"hide"
const REVEAL := &"reveal"
const SEARCH := &"search"
const DOWN := &"down"
const DEATH := &"death"
const DEATH_SAVE := &"death_save"
const INSPIRATION := &"inspiration"
const CLICK := &"click"
const REFUSED := &"refused"

const EFFECTS: Dictionary[StringName, Array] = {
	STEP: [
		preload("res://assets/audio/sfx/footstep_grass_000.ogg"),
		preload("res://assets/audio/sfx/footstep_grass_001.ogg"),
		preload("res://assets/audio/sfx/footstep_grass_002.ogg"),
	],
	SWING: [preload("res://assets/audio/sfx/knifeSlice.ogg"), preload("res://assets/audio/sfx/knifeSlice2.ogg")],
	THROW: [preload("res://assets/audio/sfx/drawKnife1.ogg")],
	HIT: [preload("res://assets/audio/sfx/impactPunch_medium_000.ogg"), preload("res://assets/audio/sfx/impactPunch_medium_001.ogg")],
	CRITICAL: [preload("res://assets/audio/sfx/impactPunch_heavy_000.ogg")],
	GRAZE: [preload("res://assets/audio/sfx/impactGeneric_light_000.ogg")],
	MISS: [preload("res://assets/audio/sfx/cloth1.ogg")],
	HEAL: [preload("res://assets/audio/sfx/confirmation_001.ogg")],
	HIDE: [preload("res://assets/audio/sfx/cloth3.ogg")],
	REVEAL: [preload("res://assets/audio/sfx/question_001.ogg")],
	SEARCH: [preload("res://assets/audio/sfx/scroll_001.ogg")],
	DOWN: [preload("res://assets/audio/sfx/impactPunch_heavy_000.ogg")],
	DEATH: [preload("res://assets/audio/sfx/impactPlate_heavy_000.ogg")],
	DEATH_SAVE: [preload("res://assets/audio/sfx/tick_001.ogg")],
	INSPIRATION: [preload("res://assets/audio/sfx/maximize_003.ogg")],
	CLICK: [preload("res://assets/audio/sfx/click_001.ogg")],
	REFUSED: [preload("res://assets/audio/sfx/error_004.ogg")],
}

var _music_players: Array[AudioStreamPlayer] = []
## Lecteur de la musique en cours (0 ou 1).
var _current := 0
var _effect_players: Array[AudioStreamPlayer] = []
var _next_effect := 0
## Dernier bruitage demandé, pour les tests.
var last_effect: StringName = &""
## Musique demandée en dernier (`null` après un arrêt).
var _music: AudioStream
## Sans écran (tests, intégration continue), le pilote audio factice ne
## libère jamais un son lancé : Godot signalerait une fuite à la sortie. On
## garde alors l'état (musique en cours, dernier bruitage) sans rien jouer.
var _silent := DisplayServer.get_name() == "headless"


func _ready() -> void:
	# La musique continue pendant la pause, comme les clics des menus.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = MUSIC_BUS
		player.volume_db = SILENT_DB
		add_child(player)
		_music_players.append(player)
	for i in EFFECT_PLAYERS:
		var player := AudioStreamPlayer.new()
		player.bus = EFFECTS_BUS
		add_child(player)
		_effect_players.append(player)
	# Un clic pour chaque bouton du jeu, sans rien ajouter dans les scènes.
	# Note Godot : `node_added` est émis pour chaque nœud qui entre dans
	# l'arbre de scène.
	get_tree().node_added.connect(_on_node_added)
	get_tree().auto_accept_quit = false


## Quitte le jeu proprement : le son est coupé, puis on laisse au mélangeur
## audio le temps de libérer les sons en cours, sans quoi Godot signale une
## fuite à la sortie. Sert au bouton Quitter et à la croix de la fenêtre.
func quit_game() -> void:
	_release_players()
	await get_tree().create_timer(QUIT_DELAY).timeout
	get_tree().quit()


# Note Godot : avec `auto_accept_quit` désactivé, fermer la fenêtre envoie
# seulement cette notification ; c'est à nous de quitter.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


func _exit_tree() -> void:
	_release_players()


func _release_players() -> void:
	for player: AudioStreamPlayer in _music_players + _effect_players:
		player.stop()
		player.stream = null


## Musique en boucle, en fondu enchaîné. Rejouer la musique en cours ne la
## redémarre pas.
func play_music(stream: AudioStream) -> void:
	if _music == stream:
		return
	_music = stream
	if _silent:
		return
	var playing := _music_players[_current]
	var next := _music_players[1 - _current]
	_set_loop(stream)
	next.stream = stream
	next.volume_db = SILENT_DB
	next.play()
	_fade(next, 0.0)
	_fade(playing, SILENT_DB, true)
	_current = 1 - _current


## Arrête la musique en fondu.
func stop_music() -> void:
	_music = null
	if not _silent:
		_fade(_music_players[_current], SILENT_DB, true)


## Musique en cours, ou `null`.
func current_music() -> AudioStream:
	return _music


## Joue une courte musique (victoire, défaite) à la place de la musique.
func play_jingle(stream: AudioStream) -> void:
	stop_music()
	_play_effect_stream(stream)


## Joue un bruitage par son nom (constantes ci-dessus).
func play(effect: StringName) -> void:
	var variants: Array = EFFECTS.get(effect, [])
	if variants.is_empty():
		push_error("Son inconnu : %s" % effect)
		return
	last_effect = effect
	_play_effect_stream(variants.pick_random())


func _play_effect_stream(stream: AudioStream) -> void:
	if _silent:
		return
	var player := _effect_players[_next_effect]
	_next_effect = (_next_effect + 1) % _effect_players.size()
	player.stream = stream
	player.play()


func _fade(player: AudioStreamPlayer, target_db: float, stop_after: bool = false) -> void:
	var tween := create_tween()
	tween.tween_property(player, "volume_db", target_db, FADE_DURATION)
	if stop_after:
		tween.tween_callback(player.stop)


static func _set_loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(play.bind(CLICK))

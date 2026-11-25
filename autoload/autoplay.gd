## Mode démo : le jeu se joue tout seul, de l'écran titre à la fin de
## l'histoire, puis se ferme.
##
##     godot --path . -- --autoplay --seed=42 --speed=2
##
## - `--seed=N` : graine des dés du combat. Même graine, même partie.
## - `--speed=N` : accélère tout le jeu (Engine.time_scale), 1 par défaut.
##
## Rejeu d'un combat enregistré (voir CombatRecord) :
##
##     godot --path . -- --replay=user://replays/last_combat.json
##
## Le combat reprend la graine et la situation de départ du fichier, joue
## les choix du joueur dans l'ordre, dit si le résultat est le même, puis
## le jeu se ferme.
##
## Le Guerrier est conduit par la même IA que le Gobelin. Le journal du
## combat est recopié dans la console, avec un résumé à la fin. La partie du
## joueur n'est pas touchée : le mode démo sauvegarde dans un autre fichier.
##
## Note Godot : les arguments placés après `--` sur la ligne de commande sont
## réservés au jeu ; OS.get_cmdline_user_args() les renvoie.
extends Node

const AUTOPLAY_SAVE_PATH := "user://autoplay_save.json"
## Pause entre deux gestes du joueur automatique (écran, réplique, action).
const STEP_DELAY := 0.8

var enabled := false
## Combat à rejouer (option `--replay`), ou `null`.
var replay: CombatRecord
var seed_value := 0
var speed := 1.0
## Vrai une fois la partie lancée : au retour au menu, le mode démo quitte.
var game_started := false


func _ready() -> void:
	var options := parse(OS.get_cmdline_user_args())
	if not options["replay"].is_empty():
		_start_replay(options["replay"], options["speed"])
		return
	enabled = options["enabled"]
	if not enabled:
		return
	seed_value = options["seed"]
	speed = options["speed"]
	Engine.time_scale = speed
	SaveManager.path = AUTOPLAY_SAVE_PATH
	if FileAccess.file_exists(AUTOPLAY_SAVE_PATH):
		DirAccess.remove_absolute(AUTOPLAY_SAVE_PATH)
	SaveManager.reload()
	report("graine %d, vitesse ×%s" % [seed_value, speed])


## Lit les arguments du mode démo. Sans `--autoplay`, le mode est éteint.
static func parse(args: PackedStringArray) -> Dictionary:
	var options := {"enabled": false, "seed": 0, "speed": 1.0, "replay": ""}
	for arg in args:
		if arg == "--autoplay":
			options["enabled"] = true
		elif arg.begins_with("--seed=") and arg.trim_prefix("--seed=").is_valid_int():
			options["seed"] = arg.trim_prefix("--seed=").to_int()
		elif arg.begins_with("--replay="):
			options["replay"] = arg.trim_prefix("--replay=")
		elif arg.begins_with("--speed=") and arg.trim_prefix("--speed=").is_valid_float():
			options["speed"] = clampf(arg.trim_prefix("--speed=").to_float(), 0.25, 16.0)
	return options


## Charge l'enregistrement et ouvre directement le combat.
func _start_replay(path: String, replay_speed: float) -> void:
	var record := CombatRecord.from_json(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if record == null:
		report("rejeu impossible : « %s » n'est pas un enregistrement de combat lisible." % path)
		get_tree().quit.call_deferred(1)
		return
	replay = record
	speed = replay_speed
	Engine.time_scale = speed
	SceneRouter.go_to.call_deferred(SceneRouter.COMBAT)


## Une ligne dans la console, préfixée pour la repérer.
func report(text: String) -> void:
	print("[démo] %s" % text)


## Attend `seconds` secondes de jeu, puis appelle `then` si `owner_node`
## est toujours là (le joueur a pu changer d'écran entre-temps).
func later(owner_node: Node, then: Callable, seconds: float = STEP_DELAY) -> void:
	await owner_node.get_tree().create_timer(seconds).timeout
	if is_instance_valid(owner_node) and owner_node.is_inside_tree():
		then.call()

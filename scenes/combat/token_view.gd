## Pion d'un combattant : un disque de couleur avec l'initiale du nom et une
## barre de PV. Placeholder dessiné en code, en attendant de vrais sprites.
##
## Un ennemi caché est montré en transparence à sa dernière position connue
## (`cell`), qui n'est pas forcément sa vraie case.
##
## Les animations sont des fonctions qu'on attend avec `await` : le
## contrôleur joue ainsi les événements les uns après les autres.
class_name TokenView
extends Node2D

const RADIUS := 24.0
const PLAYER_COLOR := Color(0.27, 0.52, 0.92)
const ENEMY_COLOR := Color(0.82, 0.3, 0.25)
const ACTIVE_RING_COLOR := Color(1.0, 0.85, 0.3)
const HP_BACK_COLOR := Color(0.1, 0.1, 0.1)
const HP_COLOR := Color(0.35, 0.85, 0.4)
const STEP_DURATION := 0.12
const DOWN_TINT := Color(0.45, 0.45, 0.45, 0.75)
const DEAD_TINT := Color(0.3, 0.3, 0.3, 0.6)
const DEAD_MARK_COLOR := Color(0.1, 0.1, 0.1)
## Opacité d'un pion caché.
const GHOST_ALPHA := 0.35

var combatant: Combatant
## Case où le pion est affiché : la vraie, ou la dernière connue s'il est caché.
var cell: Vector2i
var is_active := false:
	set(value):
		is_active = value
		queue_redraw()
## Caché : affiché en transparence.
# Note Godot : `self_modulate` ne teinte que ce nœud ; `modulate` sert aux
# clignotements et à l'assombrissement, sans se mélanger à la transparence.
var is_ghost := false:
	set(value):
		is_ghost = value
		self_modulate = Color(1, 1, 1, GHOST_ALPHA) if value else Color.WHITE

## Teinte de repos, que le clignotement retrouve ensuite.
var _rest_tint := Color.WHITE


func setup(p_combatant: Combatant, p_cell: Vector2i, center: Vector2) -> void:
	combatant = p_combatant
	cell = p_cell
	position = center
	queue_redraw()


## Rafraîchit l'affichage (PV, état) après un changement.
func refresh() -> void:
	queue_redraw()


## Déplacement case par case le long des points donnés.
##
## Note Godot : un Tween anime une propriété dans le temps. `await` sur son
## signal `finished` suspend la fonction jusqu'à la fin de l'animation, un
## peu comme une promesse qu'on attend.
func move_along(points: Array[Vector2]) -> void:
	for point in points:
		var tween := create_tween()
		tween.tween_property(self, "position", point, STEP_DURATION)
		await tween.finished


## Petit élan vers la cible, puis retour.
func lunge(toward: Vector2) -> void:
	var origin := position
	var tween := create_tween()
	tween.tween_property(self, "position", origin.lerp(toward, 0.35), 0.1)
	tween.tween_property(self, "position", origin, 0.12)
	await tween.finished


## Clignotement rouge quand le pion est touché.
func flash() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.6, 0.5, 0.5), 0.08)
	tween.tween_property(self, "modulate", _rest_tint, 0.15)
	await tween.finished
	refresh()


## Le pion s'éteint quand le combattant tombe inconscient.
func fall() -> void:
	await _tint_to(DOWN_TINT)


## Le pion se rallume quand le combattant reprend connaissance.
func rise() -> void:
	await _tint_to(Color.WHITE)


## Le pion s'assombrit et se barre quand le combattant meurt.
func die() -> void:
	await _tint_to(DEAD_TINT)
	queue_redraw()


func _tint_to(tint: Color) -> void:
	_rest_tint = tint
	var tween := create_tween()
	tween.tween_property(self, "modulate", tint, 0.3)
	await tween.finished


func _draw() -> void:
	if combatant == null:
		return
	var color := PLAYER_COLOR if combatant.side == Combatant.Side.PLAYER else ENEMY_COLOR
	if is_active and not combatant.is_down():
		draw_arc(Vector2.ZERO, RADIUS + 5.0, 0.0, TAU, 48, ACTIVE_RING_COLOR, 3.0)
	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, color.darkened(0.4), 2.0)

	var font := ThemeDB.fallback_font
	# Deux lettres pour distinguer Guerrier (Gu) et Gobelin (Go).
	var initial := combatant.definition.display_name.left(2)
	var font_size := 20
	var text_size := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, Vector2(-text_size.x / 2.0, text_size.y / 3.0), initial, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

	var ratio := clampf(float(combatant.hp) / combatant.definition.max_hp, 0.0, 1.0)
	var bar := Rect2(Vector2(-RADIUS, RADIUS + 4.0), Vector2(RADIUS * 2.0, 5.0))
	draw_rect(bar, HP_BACK_COLOR)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), HP_COLOR)

	if combatant.is_dead:
		var arm := RADIUS * 0.7
		draw_line(Vector2(-arm, -arm), Vector2(arm, arm), DEAD_MARK_COLOR, 4.0)
		draw_line(Vector2(-arm, arm), Vector2(arm, -arm), DEAD_MARK_COLOR, 4.0)

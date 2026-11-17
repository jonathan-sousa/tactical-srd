## Pion d'un combattant : un disque de couleur avec l'initiale du nom et une
## barre de PV. Placeholder dessiné en code, en attendant de vrais sprites.
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

var combatant: Combatant
var is_active := false:
	set(value):
		is_active = value
		queue_redraw()


func setup(p_combatant: Combatant, center: Vector2) -> void:
	combatant = p_combatant
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
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	await tween.finished
	refresh()


## Le pion s'éteint quand le combattant tombe à 0 PV.
func fall() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0.4, 0.4, 0.4, 0.6), 0.3)
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

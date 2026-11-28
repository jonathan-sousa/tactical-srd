## Pion d'un combattant : son sprite (CharacterDef.sprite, 16 px agrandi ×3)
## sur un anneau à la couleur de son camp, avec une barre de PV. Sans
## sprite, un disque avec les deux premières lettres du nom.
##
## Un ennemi caché est montré en transparence à sa dernière position connue
## (`cell`), qui n'est pas forcément sa vraie case.
##
## Les animations sont des fonctions qu'on attend avec `await` : le
## contrôleur joue ainsi les événements les uns après les autres.
class_name TokenView
extends Node2D

## Émis à chaque case franchie pendant un déplacement (bruit de pas).
signal stepped

const RADIUS := 24.0
const PLAYER_COLOR := Color(0.27, 0.52, 0.92)
const ENEMY_COLOR := Color(0.82, 0.3, 0.25)
const ACTIVE_RING_COLOR := Palette.GOLD
const HP_BACK_COLOR := Color(0.1, 0.1, 0.1)
## Barre de PV : vert au-dessus de la moitié, orange jusqu'au quart, rouge
## en dessous.
const HP_HIGH_COLOR := Color(0.35, 0.85, 0.4)
const HP_MID_COLOR := Color(0.95, 0.65, 0.2)
const HP_LOW_COLOR := Color(0.9, 0.25, 0.2)
const HP_BAR_DURATION := 0.35
## Pastilles d'effets : couleur de fond de chacune (la lettre vient de
## Texts.EFFECT_BADGES).
const BADGE_RADIUS := 9.0
const BADGE_COLORS: Dictionary[StringName, Color] = {
	Effect.DODGING: Color(0.3, 0.6, 0.95),
	Effect.DISENGAGED: Color(0.45, 0.75, 0.55),
	Effect.SAPPED: Color(0.65, 0.4, 0.8),
	Effect.SLOWED: Color(0.35, 0.7, 0.85),
	Effect.HIDDEN: Color(0.4, 0.4, 0.45),
	Effect.PRONE: Color(0.75, 0.55, 0.3),
}
const STEP_DURATION := 0.12
## Sprite agrandi ×3, posé sur l'anneau.
const SPRITE_SIZE := 48.0
## Léger balancement au repos : amplitude en pixels et durée d'un aller.
const BOB_HEIGHT := 2.0
const BOB_DURATION := 0.7
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

## Effets en cours, affichés en pastilles au-dessus du pion.
var conditions: Array[StringName] = []:
	set(value):
		conditions = value
		queue_redraw()

## Teinte de repos, que le clignotement retrouve ensuite.
var _rest_tint := Color.WHITE
## PV affichés par la barre : ils rejoignent les vrais PV en douceur.
var _shown_hp := 0.0:
	set(value):
		_shown_hp = value
		queue_redraw()
var _hp_tween: Tween
## Décalage vertical du balancement.
var _bob := 0.0:
	set(value):
		_bob = value
		queue_redraw()


func _ready() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(self, "_bob", -BOB_HEIGHT, BOB_DURATION).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "_bob", 0.0, BOB_DURATION).set_trans(Tween.TRANS_SINE)


func setup(p_combatant: Combatant, p_cell: Vector2i, center: Vector2) -> void:
	combatant = p_combatant
	cell = p_cell
	position = center
	_shown_hp = combatant.hp


## Rafraîchit l'affichage après un changement : la barre de PV glisse vers
## les PV actuels.
func refresh() -> void:
	queue_redraw()
	if combatant == null or is_equal_approx(_shown_hp, float(combatant.hp)):
		return
	if _hp_tween != null:
		_hp_tween.kill()
	_hp_tween = create_tween()
	_hp_tween.tween_property(self, "_shown_hp", float(combatant.hp), HP_BAR_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Déplacement case par case le long des points donnés.
##
## Note Godot : un Tween anime une propriété dans le temps. `await` sur son
## signal `finished` suspend la fonction jusqu'à la fin de l'animation, un
## peu comme une promesse qu'on attend.
func move_along(points: Array[Vector2]) -> void:
	for point in points:
		stepped.emit()
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


## Anneau aplati sous les pieds, à la couleur du camp ; doré pendant son tour.
func _draw_feet_ring(color: Color) -> void:
	draw_set_transform(Vector2(0, RADIUS - 4.0), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, RADIUS - 2.0, Color(color, 0.35))
	var ring := ACTIVE_RING_COLOR if is_active and not combatant.is_down() else color
	draw_arc(Vector2.ZERO, RADIUS - 2.0, 0.0, TAU, 48, ring, 4.0 if is_active else 3.0)
	draw_set_transform(Vector2.ZERO)


## Couleur de la barre de PV selon la part de PV restants.
static func hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return HP_HIGH_COLOR
	if ratio > 0.25:
		return HP_MID_COLOR
	return HP_LOW_COLOR


func _tint_to(tint: Color) -> void:
	_rest_tint = tint
	var tween := create_tween()
	tween.tween_property(self, "modulate", tint, 0.3)
	await tween.finished


func _draw() -> void:
	if combatant == null:
		return
	var color := PLAYER_COLOR if combatant.side == Combatant.Side.PLAYER else ENEMY_COLOR
	var font := ThemeDB.fallback_font
	var sprite := combatant.definition.sprite
	if sprite != null:
		_draw_feet_ring(color)
		var standing := not combatant.is_down()
		var rect := Rect2(Vector2(-SPRITE_SIZE / 2.0, -SPRITE_SIZE / 2.0 - 4.0 + (_bob if standing else 0.0)), Vector2.ONE * SPRITE_SIZE)
		if not standing:
			# Inconscient ou mort : le personnage est couché.
			draw_set_transform(Vector2(0, 8), PI / 2.0)
			rect.position = Vector2(-SPRITE_SIZE / 2.0, -SPRITE_SIZE / 2.0)
		draw_texture_rect(sprite, rect, false)
		draw_set_transform(Vector2.ZERO)
	else:
		if is_active and not combatant.is_down():
			draw_arc(Vector2.ZERO, RADIUS + 5.0, 0.0, TAU, 48, ACTIVE_RING_COLOR, 3.0)
		draw_circle(Vector2.ZERO, RADIUS, color)
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, color.darkened(0.4), 2.0)
		# Deux lettres pour distinguer Guerrier (Gu) et Gobelin (Go).
		var initial := combatant.display_name.left(2)
		var text_size := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
		draw_string(font, Vector2(-text_size.x / 2.0, text_size.y / 3.0), initial, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color.WHITE)

	var ratio := clampf(_shown_hp / combatant.definition.max_hp, 0.0, 1.0)
	var bar := Rect2(Vector2(-RADIUS, RADIUS + 4.0), Vector2(RADIUS * 2.0, 6.0))
	draw_rect(bar, HP_BACK_COLOR)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), hp_color(ratio))

	# Numéro en bas à gauche, pour distinguer deux combattants de même fiche.
	if combatant.number > 0:
		var number := str(combatant.number)
		var number_center := Vector2(-RADIUS + 2.0, RADIUS - 6.0)
		draw_circle(number_center, BADGE_RADIUS, color.darkened(0.3))
		draw_arc(number_center, BADGE_RADIUS, 0.0, TAU, 24, Color(0.05, 0.05, 0.08), 1.5)
		var number_size := font.get_string_size(number, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
		draw_string(font, number_center + Vector2(-number_size.x / 2.0, 5.0), number, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.WHITE)

	# Pastilles d'effets en haut à droite, de droite à gauche.
	var badge_center := Vector2(RADIUS - 2.0, -RADIUS + 2.0)
	for id in conditions:
		draw_circle(badge_center, BADGE_RADIUS, BADGE_COLORS.get(id, Color.DIM_GRAY))
		draw_arc(badge_center, BADGE_RADIUS, 0.0, TAU, 24, Color(0.05, 0.05, 0.08), 1.5)
		var letter: String = Texts.EFFECT_BADGES.get(id, "?")
		var letter_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
		draw_string(font, badge_center + Vector2(-letter_size.x / 2.0, 4.5), letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color.WHITE)
		badge_center.x -= BADGE_RADIUS * 2.0 + 2.0

	if combatant.is_dead:
		var arm := RADIUS * 0.7
		draw_line(Vector2(-arm, -arm), Vector2(arm, arm), DEAD_MARK_COLOR, 4.0)
		draw_line(Vector2(-arm, arm), Vector2(arm, -arm), DEAD_MARK_COLOR, 4.0)

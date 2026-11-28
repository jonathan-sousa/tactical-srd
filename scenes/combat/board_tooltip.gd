## Bulle d'information au survol du plateau : un titre, une barre de PV
## facultative et quelques lignes. Elle suit la souris sans sortir de la zone
## du plateau, et ne capte jamais les clics.
##
## Elle n'affiche que ce qu'on lui donne : le contrôleur compose le texte
## (ui/texts.gd) à partir de ce que dit le moteur.
##
## Note Godot : un RichTextLabel comprend le BBCode ([color=…], [b]…), une
## petite syntaxe de balises proche du HTML, pour colorer une partie du texte.
class_name BoardTooltip
extends PanelContainer

## Écart entre le curseur et la bulle, en pixels.
const CURSOR_OFFSET := Vector2(20, 20)
const WIDTH := 320.0
const FONT_SIZE := 16
## Marges intérieures de la bulle (style TooltipPanel : 12 px de chaque côté).
const TEXT_MARGIN := 24.0
const BAR_HEIGHT := 7.0
const BAR_BACK_COLOR := Color(0.1, 0.1, 0.1)

## Zone où la bulle doit rester (celle du plateau), en coordonnées globales.
var bounds := Rect2()
## Zone que la bulle ne doit pas cacher si elle peut l'éviter (ligne de tir,
## trajet), en coordonnées globales. Vide : rien à éviter.
var keep_clear := Rect2()
## Suit la souris (plateau), ou reste où on l'a posée (boutons d'action).
var follows_mouse := true
## Coin haut-droit de la bulle quand elle est ancrée (voir `show_anchored`).
var _anchor := Vector2.ZERO

var _title: RichTextLabel
var _bar: Control
var _body: RichTextLabel
var _bar_fraction := -1.0
var _bar_color := Color.WHITE


func _init() -> void:
	# Note Godot : MOUSE_FILTER_IGNORE laisse passer la souris au plateau
	# dessous, comme `pointer-events: none` en CSS.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 0)
	# Même style que les infobulles des boutons (ui/theme.tres) : fond sombre
	# et fin liseré doré.
	theme_type_variation = &"TooltipPanel"
	hide()
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	_title = _make_label()
	box.add_child(_title)
	_bar = Control.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	_bar.draw.connect(_draw_bar)
	box.add_child(_bar)
	_body = _make_label()
	box.add_child(_body)


static func _make_label() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Largeur connue d'avance : sans elle, le texte se met d'abord en page sur
	# une largeur nulle, un mot par ligne, et la bulle devient immense.
	label.custom_minimum_size = Vector2(WIDTH - TEXT_MARGIN, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pas de cadre propre au texte : seul celui de la bulle se voit.
	label.add_theme_stylebox_override(&"normal", StyleBoxEmpty.new())
	label.add_theme_font_size_override(&"normal_font_size", FONT_SIZE)
	label.add_theme_font_size_override(&"bold_font_size", FONT_SIZE + 1)
	return label


## Affiche la bulle. `bar_fraction` : remplissage de la barre de PV (0 à 1),
## ou négatif pour ne pas en montrer. Un titre ou un corps vide est masqué.
func show_content(title: String, body: String, bar_fraction: float = -1.0, bar_color: Color = Color.WHITE) -> void:
	_title.text = title
	_title.visible = not title.is_empty()
	_body.text = body
	_body.visible = not body.is_empty()
	_bar_fraction = bar_fraction
	_bar_color = bar_color
	_bar.visible = bar_fraction >= 0.0
	_bar.queue_redraw()
	follows_mouse = true
	show()
	_fit()


## La hauteur suit le texte : on repart de la plus petite taille. Note
## Godot : le texte n'est mis en page qu'à la frame suivante, d'où un second
## ajustement différé (call_deferred).
func _fit() -> void:
	_resize()
	_resize.call_deferred()


func _resize() -> void:
	size = Vector2(WIDTH, 0)
	reset_size()
	if follows_mouse:
		_follow_mouse()
	else:
		_place_anchored()


## Affiche la bulle à une place fixe : son bord droit en `right_edge.x`, son
## haut en `right_edge.y` (sans sortir de l'écran par le bas).
func show_anchored(title: String, body: String, right_edge: Vector2) -> void:
	_title.text = title
	_title.visible = not title.is_empty()
	_body.text = body
	_body.visible = not body.is_empty()
	_bar.visible = false
	follows_mouse = false
	_anchor = right_edge
	show()
	_fit()


func _place_anchored() -> void:
	var bottom := get_viewport_rect().size.y - 8.0
	global_position = Vector2(_anchor.x - size.x, minf(_anchor.y, bottom - size.y))


func hide_content() -> void:
	hide()


## Texte complet affiché (titre et corps, sans balises) : sert aux tests.
func text() -> String:
	return "%s\n%s" % [_title.get_parsed_text(), _body.get_parsed_text()]


func _process(_delta: float) -> void:
	if visible and follows_mouse:
		_follow_mouse()


## Près du curseur : en bas à droite de préférence, sinon dans un autre
## coin, sinon au-dessus ou en dessous de la zone à garder visible. On garde
## la première place qui tient dans le plateau sans cacher `keep_clear`.
func _follow_mouse() -> void:
	var mouse := get_global_mouse_position()
	var right := mouse.x + CURSOR_OFFSET.x
	var left := mouse.x - CURSOR_OFFSET.x - size.x
	var below := mouse.y + CURSOR_OFFSET.y
	var above := mouse.y - CURSOR_OFFSET.y - size.y
	var candidates: Array[Vector2] = [
		Vector2(right, below), Vector2(left, below), Vector2(right, above), Vector2(left, above),
	]
	if keep_clear.has_area():
		for x: float in [right, left]:
			candidates.append(Vector2(x, keep_clear.end.y + CURSOR_OFFSET.y))
			candidates.append(Vector2(x, keep_clear.position.y - CURSOR_OFFSET.y - size.y))
	global_position = _best_place(candidates)


func _best_place(candidates: Array[Vector2]) -> Vector2:
	if not bounds.has_area():
		return candidates[0]
	var fallback := Vector2.INF
	for at in candidates:
		var rect := Rect2(at, size)
		if not bounds.encloses(rect):
			continue
		if not keep_clear.has_area() or not rect.intersects(keep_clear):
			return at
		if fallback == Vector2.INF:
			fallback = at
	if fallback == Vector2.INF:
		fallback = candidates[0]
	return Vector2(
		clampf(fallback.x, bounds.position.x, maxf(bounds.end.x - size.x, bounds.position.x)),
		clampf(fallback.y, bounds.position.y, maxf(bounds.end.y - size.y, bounds.position.y)),
	)


func _draw_bar() -> void:
	var rect := Rect2(Vector2.ZERO, _bar.size)
	_bar.draw_rect(rect, BAR_BACK_COLOR)
	_bar.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(_bar_fraction, 0.0, 1.0), rect.size.y)), _bar_color)

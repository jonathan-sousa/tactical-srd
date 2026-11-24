## Ordre d'initiative affiché en haut de l'écran, combattant actif en évidence.
class_name InitiativeBar
extends HBoxContainer

const ACTIVE_COLOR := Palette.GOLD
const IDLE_COLOR := Color(0.85, 0.85, 0.85)
const DOWN_COLOR := Color(0.45, 0.45, 0.45)

var _entries: Array[InitiativeEntry] = []


func set_order(entries: Array[InitiativeEntry]) -> void:
	_entries = entries


func refresh(active: Combatant) -> void:
	# Note Godot : queue_free() supprime un Node à la fin de l'image en cours.
	for child in get_children():
		child.queue_free()
	for entry in _entries:
		var label := Label.new()
		var combatant := entry.combatant
		label.text = "%s (%d)" % [combatant.definition.display_name, entry.total]
		var color := IDLE_COLOR
		if combatant.is_down():
			color = DOWN_COLOR
		elif combatant == active:
			color = ACTIVE_COLOR
			label.text = "▶ " + label.text
		label.add_theme_color_override("font_color", color)
		add_child(label)

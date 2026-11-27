## Liste du groupe : une ligne par personnage joueur, avec ses PV et son état
## (à terre, stabilisé, mort). Le personnage commandé est mis en évidence ;
## sa fiche détaillée est juste en dessous (CharacterPanel).
##
## Créée par le contrôleur de combat, seulement quand le groupe compte
## plusieurs personnages.
class_name PartyList
extends VBoxContainer

const COMMANDED_COLOR := Palette.GOLD
const DOWN_COLOR := Palette.DANGER

var _lines: Dictionary[Combatant, Label] = {}


func refresh(state: CombatState, commanded: Combatant) -> void:
	for member in state.party():
		if not _lines.has(member):
			var label := Label.new()
			add_child(label)
			_lines[member] = label
		var line := _lines[member]
		line.text = Texts.party_line(member, member == commanded)
		if member == commanded:
			line.add_theme_color_override(&"font_color", COMMANDED_COLOR)
		elif member.is_down():
			line.add_theme_color_override(&"font_color", DOWN_COLOR)
		else:
			line.remove_theme_color_override(&"font_color")

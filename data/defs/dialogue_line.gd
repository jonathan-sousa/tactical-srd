## Une réplique : qui parle, ce qu'il dit, et un portrait optionnel.
class_name DialogueLine
extends Resource

@export var speaker: String
# Note Godot : @export_multiline affiche un champ de texte sur plusieurs
# lignes dans l'inspecteur.
@export_multiline var text: String
@export var portrait: Texture2D

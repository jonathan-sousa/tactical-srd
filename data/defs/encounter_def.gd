## Une rencontre : la carte (taille et cases bloquées) et qui commence où.
##
## La carte est décrite par des données plutôt que par une scène : le moteur
## de règles peut ainsi calculer déplacements et combat sans rien afficher.
## La grille visible du J3 est construite à partir de ces champs.
##
## Ajouter un ennemi = ajouter une ligne à `enemies`, sans code.
class_name EncounterDef
extends Resource

@export var id: StringName
## Largeur et hauteur en cases.
@export var grid_size: Vector2i = Vector2i(12, 8)
## Obstacles : cases infranchissables.
@export var blocked_cells: Array[Vector2i] = []
@export var player_start: Vector2i
@export var enemies: Array[EnemyPlacement] = []


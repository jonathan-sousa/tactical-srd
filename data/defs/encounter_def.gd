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
## Obstacles : cases infranchissables, qui bloquent aussi la vue (abri
## total).
@export var blocked_cells: Array[Vector2i] = []
## Murets : infranchissables, mais on voit par-dessus. Un muret entre
## l'attaquant et sa cible lui donne un abri partiel (+2 CA).
@export var low_walls: Array[Vector2i] = []
## Cases de départ des personnages joueurs, dans l'ordre du groupe : la
## première pour le premier personnage, etc.
@export var player_starts: Array[Vector2i] = []
## Embuscade : au début du combat, chaque ennemi hors de vue du joueur tente
## de se cacher. S'il y parvient, le joueur est surpris (SRD « Surprise »).
@export var ambush: bool = false
@export var enemies: Array[EnemyPlacement] = []


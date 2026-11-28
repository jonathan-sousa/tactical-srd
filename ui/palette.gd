## Couleurs de l'interface, au même endroit. Le thème (ui/theme.tres)
## reprend les mêmes valeurs pour les contrôles ; ces constantes servent au
## dessin en code (plateau, pions, journal).
class_name Palette
extends RefCounted

## Or : titres, tour en cours, combattant actif.
const GOLD := Color(1.0, 0.85, 0.3)
## Texte courant, clair sur fond sombre.
const TEXT := Color(0.95, 0.92, 0.86)
## Texte discret : détails, informations secondaires.
const MUTED := Color(0.65, 0.64, 0.66)
## Danger : chute, mort, dégâts.
const DANGER := Color(1.0, 0.45, 0.4)
## Soin.
const HEAL := Color(0.55, 0.9, 0.55)
## Coûts du tour : action (or), action bonus (vert), réaction (violet),
## déplacement (bleu). Pastilles du budget et liserés des boutons.
const ACTION := Color(1.0, 0.85, 0.3)
const BONUS_ACTION := Color(0.45, 0.85, 0.45)
const REACTION := Color(0.72, 0.56, 1.0)
const MOVEMENT := Color(0.36, 0.6, 0.95)
## Ce qui ne coûte rien (changer d'arme).
const FREE := Color(0.6, 0.58, 0.62)
## Nom d'un allié dans les bulles.
const ALLY := Color(0.6, 0.75, 1.0)
## Effets en cours (À terre, Sapé…) dans les bulles.
const EFFECT := Color(0.8, 0.7, 1.0)
## Nom d'un élément du décor dans les bulles.
const TERRAIN := Color(0.85, 0.79, 0.64)

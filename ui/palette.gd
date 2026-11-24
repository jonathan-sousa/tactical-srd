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

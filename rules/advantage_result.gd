## Avantage ou désavantage d'un jet, avec ses raisons (pour le journal et
## les prévisualisations).
class_name AdvantageResult
extends RefCounted

var mode: Dice.RollMode = Dice.RollMode.NORMAL
var advantages: Array[StringName] = []
var disadvantages: Array[StringName] = []

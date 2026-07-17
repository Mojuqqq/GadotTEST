extends Resource
class_name ItemData

@export var id: String
@export var name: String
@export var description: String
@export var icon: Texture2D

# Храним функцию применения предмета
var apply: Callable

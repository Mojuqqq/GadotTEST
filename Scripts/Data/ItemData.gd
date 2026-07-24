extends Resource
class_name ItemData


@export_group("General")

@export var id: String
@export var name: String
@export_multiline var description: String
@export var icon: Texture2D


@export_group("Shop")

@export_range(1, 9999, 1)
var shop_price: int = 20


# Храним функцию применения предмета.
var apply: Callable

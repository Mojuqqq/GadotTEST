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

enum UseMode {
	PASSIVE,
	INSTANT,
	TIMED,
	AMMO,
	COMPANION
}


@export_group("Inventory")

@export var use_mode: UseMode = (
	UseMode.PASSIVE
)

@export_range(1, 999, 1)
var min_grant_amount: int = 1

@export_range(1, 999, 1)
var max_grant_amount: int = 1

@export_range(1, 999, 1)
var max_inventory_stack: int = 99

# Храним функцию применения предмета.
var apply: Callable

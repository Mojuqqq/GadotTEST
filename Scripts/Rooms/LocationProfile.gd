extends Resource
class_name LocationProfile


enum FloorType {
	DIRT,
	GRASS,
	WOOD
}

@export_group("Location")

@export var id: StringName = &""
@export var display_name: String = ""


@export_group("Floor")

@export var floor_tile_set: TileSet = null
@export var floor_terrain_set: int = 0
@export var floor_terrain: int = 0


# =========================================================
# БУДУЩЕЕ
# =========================================================

@export_group("Walls")

@export var wall_tile_set: TileSet = null


@export_group("Doors")

@export var door_tile_set: TileSet = null


@export_group("Decor")

@export var decor_pool: Array[PackedScene] = []

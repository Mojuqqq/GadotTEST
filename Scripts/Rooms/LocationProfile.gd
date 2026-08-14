extends Resource
class_name LocationProfile


enum FloorType {
	DIRT,
	GRASS,
	WOOD
}

enum WallType {
	FARM,
	BARN,
	GARDEN
}

@export var wall_type: WallType = WallType.FARM

@export_group("Location")

@export var id: StringName = &""
@export var display_name: String = ""


@export_group("Floor")

@export var floor_type: FloorType = FloorType.DIRT


# =========================================================
# БУДУЩЕЕ
# =========================================================

@export_group("Walls")
@export var wall_theme: WallTheme
@export var wall_tile_set: TileSet = null

const WALL_TILES := {
	LocationProfile.WallType.FARM: {
		"top": Vector2i(0, 0),
		"bottom": Vector2i(0, 2),
		"left": Vector2i(0, 1),
		"right": Vector2i(2, 1),
		"top_left": Vector2i(0, 0),
		"top_right": Vector2i(2, 0),
		"bottom_left": Vector2i(0, 2),
		"bottom_right": Vector2i(2, 2),
	},

	LocationProfile.WallType.BARN: {

	},

	LocationProfile.WallType.GARDEN: {

	},
}



@export_group("Doors")

@export var door_tile_set: TileSet = null


@export_group("Decor")

@export var decor_pool: Array[PackedScene] = []

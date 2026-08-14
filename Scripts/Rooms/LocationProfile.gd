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

const WALL_TILES := {
	WallType.FARM: {
		"left_closed": Vector2i(0, 0),
		"left": Vector2i(1, 0),
		"bottom_left": Vector2i(2, 0),
		"top_right": Vector2i(3, 0),

		"top_open": Vector2i(4, 0),
		"top_closed": Vector2i(5, 0),
		"top": Vector2i(6, 0),
		"top_left": Vector2i(7, 0),

		"bottom_right": Vector2i(8, 0),
		"right": Vector2i(9, 0),
		"right_closed": Vector2i(10, 0),
		"bottom_closed": Vector2i(11, 0),

		"bottom": Vector2i(12, 0),
		"bottom_open": Vector2i(13, 0),

		# Добавишь позже:
		# "left_open": Vector2i(14, 0),
		# "right_open": Vector2i(15, 0),
	},

	WallType.BARN: {
		"left_closed": Vector2i(0, 1),
		"left": Vector2i(1, 1),
		"bottom_left": Vector2i(2, 1),
		"top_right": Vector2i(3, 1),

		"top_open": Vector2i(4, 1),
		"top_closed": Vector2i(5, 1),
		"top": Vector2i(6, 1),
		"top_left": Vector2i(7, 1),

		"bottom_right": Vector2i(8, 1),
		"right": Vector2i(9, 1),
		"right_closed": Vector2i(10, 1),
		"bottom_closed": Vector2i(11, 1),

		"bottom": Vector2i(12, 1),
		"bottom_open": Vector2i(13, 1),

		# "left_open": Vector2i(14, 1),
		# "right_open": Vector2i(15, 1),
	},

	WallType.GARDEN: {
		"left_closed": Vector2i(0, 2),
		"left": Vector2i(1, 2),
		"bottom_left": Vector2i(2, 2),
		"top_right": Vector2i(3, 2),

		"top_open": Vector2i(4, 2),
		"top_closed": Vector2i(5, 2),
		"top": Vector2i(6, 2),
		"top_left": Vector2i(7, 2),

		"bottom_right": Vector2i(8, 2),
		"right": Vector2i(9, 2),
		"right_closed": Vector2i(10, 2),
		"bottom_closed": Vector2i(11, 2),

		"bottom": Vector2i(12, 2),
		"bottom_open": Vector2i(13, 2),

		# "left_open": Vector2i(14, 2),
		# "right_open": Vector2i(15, 2),
	},
}



@export_group("Doors")

@export var door_tile_set: TileSet = null


@export_group("Decor")

@export var decor_pool: Array[PackedScene] = []

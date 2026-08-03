extends Control
class_name Minimap


@export_group("Layout")

@export var room_draw_size := Vector2(
	26.0,
	18.0
)


@export_group("Background")

@export var background_color := Color(
	0.05,
	0.04,
	0.03,
	0.68
)

@export var background_border_color := Color(
	0.32,
	0.23,
	0.14,
	0.9
)

@export var background_border_width: float = 2.0

@export_group("Door Colors")

@export var open_door_color := Color(
	0.2,
	0.85,
	0.3,
	1.0
)

@export var closed_door_color := Color(
	0.9,
	0.16,
	0.12,
	1.0
)

@export var horizontal_door_size := Vector2(
	8.0,
	4.0
)

@export var vertical_door_size := Vector2(
	4.0,
	8.0
)


@export_group("Room Colors")

@export var undiscovered_room_color := Color(
	0.16,
	0.12,
	0.08,
	0.8
)

@export var visited_room_color := Color(
	0.48,
	0.36,
	0.22,
	0.95
)

@export var current_room_color := Color(
	0.95,
	0.78,
	0.38,
	1.0
)

@export var room_outline_color := Color(
	0.12,
	0.07,
	0.03,
	1.0
)

@export_group("Room Type Colors")

@export var start_icon_color := Color(
	0.9,
	0.9,
	0.82,
	1.0
)

@export var treasure_icon_color := Color(
	1.0,
	0.78,
	0.15,
	1.0
)

@export var shop_icon_color := Color(
	0.35,
	0.78,
	0.38,
	1.0
)

@export var boss_icon_color := Color(
	0.8,
	0.15,
	0.12,
	1.0
)


var visited_rooms: Dictionary = {}
var connected_door_sockets: Array[DoorSocket] = []
var current_room_index: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not resized.is_connected(
		queue_redraw
	):
		resized.connect(
			queue_redraw
	)

	if not GameManager.room_changed.is_connected(
		_on_room_changed
	):
		GameManager.room_changed.connect(
			_on_room_changed
		)

	call_deferred(
		&"_sync_with_current_dungeon"
	)


func _exit_tree() -> void:
	if GameManager.room_changed.is_connected(
		_on_room_changed
	):
		GameManager.room_changed.disconnect(
			_on_room_changed
		)
	
	_disconnect_door_signals()


func _sync_with_current_dungeon() -> void:
	if GameManager.room_instances.is_empty():
		return

	current_room_index = (
		GameManager.current_room_index
	)

	if current_room_index < 0:
		return

	if current_room_index >= GameManager.room_instances.size():
		return

	visited_rooms[current_room_index] = true

	_connect_door_signals()

	queue_redraw()


func _on_room_changed(
	_room_name: StringName,
	room_index: int
) -> void:
	if room_index < 0:
		return

	if room_index >= GameManager.room_instances.size():
		return

	current_room_index = room_index
	visited_rooms[room_index] = true

	_connect_door_signals()

	queue_redraw()


func _get_connected_room_indices(
	room_index: int
) -> Array[int]:
	var result: Array[int] = []

	if room_index < 0:
		return result

	if room_index >= GameManager.room_instances.size():
		return result

	var room: Node2D = (
		GameManager.room_instances[room_index]
	)

	if not is_instance_valid(room):
		return result

	var typed_room := room as Room

	if typed_room == null:
		return result

	for door_variant in typed_room.doors:
		if not is_instance_valid(door_variant):
			continue

		var socket := door_variant as DoorSocket

		if socket == null:
			continue

		var target_room: Node2D = (
			socket.target_room_node
		)

		if not is_instance_valid(target_room):
			continue

		var target_index: int = (
			GameManager.room_instances.find(
				target_room
			)
		)

		if target_index == -1:
			continue

		if result.has(target_index):
			continue

		result.append(target_index)

	return result


func _draw() -> void:
	var background_rect := Rect2(
		Vector2.ZERO,
		size
	)

	draw_rect(
		background_rect,
		background_color,
		true
	)

	if background_border_width > 0.0:
		var border_offset: float = (
			background_border_width * 0.5
		)

		var border_rect := Rect2(
			Vector2(
				border_offset,
				border_offset
			),
			size - Vector2(
				background_border_width,
				background_border_width
			)
		)

		draw_rect(
			border_rect,
			background_border_color,
			false,
			background_border_width
		)

	var room_indices: Array[int] = (
		_get_visited_room_indices()
	)

	if room_indices.is_empty():
		return

	var room_cells: Dictionary = {}

	var minimum_cell := Vector2i(
		2147483647,
		2147483647
	)

	var maximum_cell := Vector2i(
		-2147483648,
		-2147483648
	)

	for room_index in room_indices:
		var cell: Vector2i = (
			_get_room_cell(
				room_index
			)
		)

		room_cells[room_index] = cell

		minimum_cell.x = mini(
			minimum_cell.x,
			cell.x
		)

		minimum_cell.y = mini(
			minimum_cell.y,
			cell.y
		)

		maximum_cell.x = maxi(
			maximum_cell.x,
			cell.x
		)

		maximum_cell.y = maxi(
			maximum_cell.y,
			cell.y
		)

	var content_size := Vector2(
		float(maximum_cell.x - minimum_cell.x + 1)
		* room_draw_size.x,
		float(maximum_cell.y - minimum_cell.y + 1)
		* room_draw_size.y
	)

	var content_top_left: Vector2 = (
		(size - content_size) * 0.5
	)

	for room_index in room_indices:
		var room_cell: Vector2i = (
			room_cells[room_index]
		)

		var room_center: Vector2 = (
			_get_cell_center(
				room_cell,
				minimum_cell,
				content_top_left
			)
		)

		_draw_room(
			room_index,
			room_center
		)

	_draw_shared_doors(
		room_indices,
		room_cells,
		minimum_cell,
		content_top_left
	)

func _draw_shared_doors(
	room_indices: Array[int],
	room_cells: Dictionary,
	minimum_cell: Vector2i,
	content_top_left: Vector2
) -> void:
	for room_index in room_indices:
		if room_index < 0:
			continue

		if room_index >= GameManager.room_instances.size():
			continue

		var room: Node2D = (
			GameManager.room_instances[room_index]
		)

		if not is_instance_valid(room):
			continue

		var typed_room := room as Room

		if typed_room == null:
			continue

		var room_center: Vector2 = (
			_get_cell_center(
				room_cells[room_index],
				minimum_cell,
				content_top_left
			)
		)

		for door_variant in typed_room.doors:
			if not is_instance_valid(door_variant):
				continue

			var socket := door_variant as DoorSocket

			if socket == null:
				continue

			if not socket.connection_enabled:
				continue

			if not is_instance_valid(
				socket.target_room_node
			):
				continue

			var target_index: int = (
				GameManager.room_instances.find(
					socket.target_room_node
				)
			)

			if target_index == -1:
				continue

			var target_is_visited: bool = (
				visited_rooms.has(target_index)
				and room_cells.has(target_index)
			)

			var door_center: Vector2
			var door_size: Vector2

			if target_is_visited:
				# Когда обе комнаты видны, рисуем дверь
				# один раз между ними.
				if target_index < room_index:
					continue

				var target_center: Vector2 = (
					_get_cell_center(
						room_cells[target_index],
						minimum_cell,
						content_top_left
					)
				)

				door_center = (
					room_center + target_center
				) * 0.5

				var cell_difference: Vector2i = (
					room_cells[target_index]
					- room_cells[room_index]
				)

				if cell_difference.x != 0:
					door_size = vertical_door_size
				else:
					door_size = horizontal_door_size

			else:
				# Соседняя комната ещё скрыта.
				# Показываем один выход на границе
				# посещённой комнаты.
				var half_room_size: Vector2 = (
					room_draw_size * 0.5
				)

				match socket.direction:
					DoorSocket.Direction.TOP:
						door_center = (
							room_center
							+ Vector2(
								0.0,
								-half_room_size.y
							)
						)

						door_size = (
							horizontal_door_size
						)

					DoorSocket.Direction.RIGHT:
						door_center = (
							room_center
							+ Vector2(
								half_room_size.x,
								0.0
							)
						)

						door_size = (
							vertical_door_size
						)

					DoorSocket.Direction.BOTTOM:
						door_center = (
							room_center
							+ Vector2(
								0.0,
								half_room_size.y
							)
						)

						door_size = (
							horizontal_door_size
						)

					DoorSocket.Direction.LEFT:
						door_center = (
							room_center
							+ Vector2(
								-half_room_size.x,
								0.0
							)
						)

						door_size = (
							vertical_door_size
						)

			var door_color: Color = (
				open_door_color
				if socket.is_open
				else closed_door_color
			)

			var door_rect := Rect2(
				door_center - door_size * 0.5,
				door_size
			)

			draw_rect(
				door_rect,
				door_color,
				true
			)

			draw_rect(
				door_rect,
				room_outline_color,
				false,
				1.0
			)

func _get_visited_room_indices() -> Array[int]:
	var result: Array[int] = []

	for index_variant in visited_rooms.keys():
		var room_index: int = int(
			index_variant
		)

		if room_index < 0:
			continue

		if room_index >= GameManager.room_instances.size():
			continue

		result.append(room_index)

	result.sort()

	return result


func _get_room_cell(
	room_index: int
) -> Vector2i:
	var room: Node2D = (
		GameManager.room_instances[room_index]
	)

	var horizontal_step: float = float(
		GameManager.room_width
		+ GameManager.room_spacing
	)

	var vertical_step: float = float(
		GameManager.room_height
		+ GameManager.room_spacing
	)

	return Vector2i(
		roundi(
			room.global_position.x
			/ horizontal_step
		),
		roundi(
			room.global_position.y
			/ vertical_step
		)
	)


func _get_cell_center(
	cell: Vector2i,
	minimum_cell: Vector2i,
	content_top_left: Vector2
) -> Vector2:
	var relative_cell: Vector2i = (
		cell - minimum_cell
	)

	return (
		content_top_left
		+ room_draw_size * 0.5
		+ Vector2(
			float(relative_cell.x)
			* room_draw_size.x,
			float(relative_cell.y)
			* room_draw_size.y
		)
	)


func _draw_room(
	room_index: int,
	room_center: Vector2
) -> void:
	var room_rect := Rect2(
		room_center
		- room_draw_size * 0.5,
		room_draw_size
	)

	var fill_color: Color = (
		visited_room_color
	)

	if room_index == current_room_index:
		fill_color = current_room_color

	draw_rect(
		room_rect,
		fill_color,
		true
	)

	draw_rect(
		room_rect,
		room_outline_color,
		false,
		2.0
	)

	_draw_room_type_icon(
		room_index,
		room_center
	)

func _draw_room_type_icon(
	room_index: int,
	room_center: Vector2
) -> void:
	var room: Node2D = (
		GameManager.room_instances[room_index]
	)

	var typed_room := room as Room

	if typed_room == null:
		return

	match typed_room.room_type:
		Room.RoomType.START:
			draw_circle(
				room_center,
				3.0,
				start_icon_color
			)

		Room.RoomType.TREASURE:
			draw_circle(
				room_center,
				4.0,
				treasure_icon_color
			)

		Room.RoomType.SHOP:
			draw_rect(
				Rect2(
					room_center
					- Vector2(4.0, 4.0),
					Vector2(8.0, 8.0)
				),
				shop_icon_color,
				true
			)

		Room.RoomType.BOSS:
			var boss_shape := PackedVector2Array([
				room_center
				+ Vector2(0.0, -5.0),
				room_center
				+ Vector2(5.0, 0.0),
				room_center
				+ Vector2(0.0, 5.0),
				room_center
				+ Vector2(-5.0, 0.0)
			])

			draw_colored_polygon(
				boss_shape,
				boss_icon_color
			)

func _connect_door_signals() -> void:
	_disconnect_door_signals()

	for room_variant in GameManager.room_instances:
		if not is_instance_valid(room_variant):
			continue

		var typed_room := room_variant as Room

		if typed_room == null:
			continue

		for door_variant in typed_room.doors:
			if not is_instance_valid(door_variant):
				continue

			var socket := door_variant as DoorSocket

			if socket == null:
				continue

			if not socket.state_changed.is_connected(
				_on_door_state_changed
			):
				socket.state_changed.connect(
					_on_door_state_changed
				)

			connected_door_sockets.append(
				socket
			)


func _disconnect_door_signals() -> void:
	for socket in connected_door_sockets:
		if not is_instance_valid(socket):
			continue

		if socket.state_changed.is_connected(
			_on_door_state_changed
		):
			socket.state_changed.disconnect(
				_on_door_state_changed
			)

	connected_door_sockets.clear()


func _on_door_state_changed(
	_socket: DoorSocket,
	_is_open: bool
) -> void:
	queue_redraw()

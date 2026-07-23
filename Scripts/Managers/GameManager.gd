extends Node

# GameManager остаётся единственным Autoload.
# Он больше не хранит всю игровую логику внутри себя,
# а передаёт работу отдельным менеджерам.

signal player_hp_changed(hp: int, max_hp: int)
signal room_changed(room_name: StringName, room_index: int)
signal enemies_changed(count: int)
signal game_over(victory: bool)
signal stats_changed(stats)


enum GameState {
	MENU,
	PLAYING,
	GAME_OVER,
	VICTORY
}

# Отдельные менеджеры
const RunStateService = preload("res://Scripts/Managers/RunState.gd")
const DungeonService = preload("res://Scripts/Managers/DungeonManager.gd")
const ItemDatabaseService = preload("res://Scripts/Managers/ItemDatabase.gd")
const GameFlowService = preload("res://Scripts/Managers/GameFlow.gd")

var _run_state = RunStateService.new()
var _dungeon = DungeonService.new()
var _items = ItemDatabaseService.new()
var _flow = GameFlowService.new()


# =========================================================
# СОВМЕСТИМЫЕ СВОЙСТВА
#
# Благодаря этим свойствам старый код продолжит работать:
#
# GameManager.player
# GameManager.player_stats
# GameManager.room_width
# GameManager.enemy_pool
# =========================================================


# Состояние игры

var state: int:
	get:
		return _flow.state
	set(value):
		_flow.state = value


var game_over_started: bool:
	get:
		return _flow.game_over_started
	set(value):
		_flow.game_over_started = value


# Игрок

var player: Node2D:
	get:
		return _run_state.player
	set(value):
		_run_state.player = value


var player_hp: int:
	get:
		return _run_state.player_hp
	set(value):
		_run_state.player_hp = value


var player_max_hp: int:
	get:
		return _run_state.player_max_hp
	set(value):
		_run_state.player_max_hp = value


var player_stats:
	get:
		return _run_state.player_stats
	set(value):
		_run_state.player_stats = value


# Комнаты и генерация

var is_transitioning: bool:
	get:
		return _dungeon.is_transitioning
	set(value):
		_dungeon.is_transitioning = value


var boss_scene: PackedScene:
	get:
		return _dungeon.boss_scene
	set(value):
		_dungeon.boss_scene = value


var room_instances: Array[Node2D]:
	get:
		return _dungeon.room_instances


var current_room_index: int:
	get:
		return _dungeon.current_room_index
	set(value):
		_dungeon.current_room_index = value


var room_width: int:
	get:
		return _dungeon.room_width
	set(value):
		_dungeon.room_width = value


var room_height: int:
	get:
		return _dungeon.room_height
	set(value):
		_dungeon.room_height = value


var room_spacing: int:
	get:
		return _dungeon.room_spacing
	set(value):
		_dungeon.room_spacing = value


var min_rooms: int:
	get:
		return _dungeon.min_rooms
	set(value):
		_dungeon.min_rooms = value


var max_rooms: int:
	get:
		return _dungeon.max_rooms
	set(value):
		_dungeon.max_rooms = value


var start_room_scene: PackedScene:
	get:
		return _dungeon.start_room_scene
	set(value):
		_dungeon.start_room_scene = value


var end_room_scene: PackedScene:
	get:
		return _dungeon.end_room_scene
	set(value):
		_dungeon.end_room_scene = value


var room_pool: Array[PackedScene]:
	get:
		return _dungeon.room_pool
	set(value):
		_dungeon.room_pool = value


var enemy_pool: Array[PackedScene]:
	get:
		return _dungeon.enemy_pool
	set(value):
		_dungeon.enemy_pool = value


var min_enemies_per_room: int:
	get:
		return _dungeon.min_enemies_per_room
	set(value):
		_dungeon.min_enemies_per_room = value


var max_enemies_per_room: int:
	get:
		return _dungeon.max_enemies_per_room
	set(value):
		_dungeon.max_enemies_per_room = value


var enemies_in_start_room: int:
	get:
		return _dungeon.enemies_in_start_room
	set(value):
		_dungeon.enemies_in_start_room = value


var enemies_in_end_room: int:
	get:
		return _dungeon.enemies_in_end_room
	set(value):
		_dungeon.enemies_in_end_room = value


# Предметы

var all_items: Array[ItemData]:
	get:
		return _items.all_items


# =========================================================
# ЗАПУСК МЕНЕДЖЕРОВ
# =========================================================

func _ready() -> void:
	_add_service(_run_state, "RunState")
	_add_service(_dungeon, "DungeonManager")
	_add_service(_items, "ItemDatabase")
	_add_service(_flow, "GameFlow")

	_connect_service_signals()

	_items.init_items(self)


func _add_service(
	service: Node,
	service_name: String
) -> void:
	service.name = service_name
	add_child(service)


func _connect_service_signals() -> void:
	_run_state.player_hp_changed.connect(
		_on_player_hp_changed
	)

	_run_state.stats_changed.connect(
		_on_stats_changed
	)

	_dungeon.room_changed.connect(
		_on_room_changed
	)

	_dungeon.enemies_changed.connect(
		_on_enemies_changed
	)

	_flow.game_over.connect(
		_on_game_over
	)


# =========================================================
# УПРАВЛЕНИЕ ИГРОЙ
# =========================================================

func start_game() -> void:
	_flow.start_game(
		Callable(self, "reset_game_state")
	)


func trigger_game_over(
	victory: bool = false
) -> void:
	_flow.trigger_game_over(
		victory,
		_run_state.player
	)


func restart_game() -> void:
	_flow.restart_game(
		Callable(self, "reset_game_state")
	)


func return_to_menu() -> void:
	_flow.return_to_menu(
		Callable(self, "reset_game_state")
	)


# =========================================================
# ИГРОК И ХАРАКТЕРИСТИКИ
# =========================================================

func set_player(
	player_node: Node2D
) -> void:
	_run_state.set_player(player_node)


func unregister_player(
	player_node: Node
) -> void:
	_run_state.unregister_player(player_node)


func set_player_stats(stats) -> void:
	_run_state.set_player_stats(stats)


func upgrade_stat(
	stat_name: String,
	amount: float
) -> void:
	_run_state.upgrade_stat(
		stat_name,
		amount
	)


func take_damage(amount: int) -> void:
	if _flow.game_over_started:
		return

	var player_died := _run_state.take_damage(
		amount
	)

	if player_died:
		trigger_game_over(false)


func heal(amount: int) -> void:
	_run_state.heal(amount)


func increase_max_hp(amount: int) -> void:
	_run_state.increase_max_hp(amount)


func notify_stats_changed() -> void:
	if _run_state.player_stats == null:
		return

	stats_changed.emit(
		_run_state.player_stats
	)


# =========================================================
# КОМНАТЫ И ГЕНЕРАЦИЯ
# =========================================================

func generate_dungeon(
	root_node: Node
) -> void:
	_dungeon.generate_dungeon(root_node)


func connect_rooms() -> void:
	_dungeon.connect_rooms()


func disable_unconnected_doors() -> void:
	_dungeon.disable_unconnected_doors()


func enter_room(index: int) -> void:
	_dungeon.enter_room(index)


func move_player_to_room(
	target_room_node: Node2D,
	door_position: Vector2
) -> int:
	return _dungeon.move_player_to_room(
		target_room_node,
		door_position
	)


func get_current_room() -> Node2D:
	return _dungeon.get_current_room()


func get_enemy_count_in_room() -> int:
	return _dungeon.get_enemy_count_in_room()


func update_enemy_count() -> void:
	_dungeon.update_enemy_count()


func spawn_enemies_for_room(
	room: Node2D,
	index: int
) -> void:
	_dungeon.spawn_enemies_for_room(
		room,
		index
	)


# =========================================================
# ПОЛНЫЙ СБРОС ЗАБЕГА
# =========================================================

func reset_game_state() -> void:
	_run_state.reset()
	_dungeon.reset()
	_flow.reset()


# =========================================================
# ПЕРЕДАЧА СИГНАЛОВ НАРУЖУ
#
# UI продолжает слушать сигналы GameManager,
# а не отдельные менеджеры.
# =========================================================

func _on_player_hp_changed(
	hp: int,
	max_hp: int
) -> void:
	player_hp_changed.emit(
		hp,
		max_hp
	)


func _on_stats_changed(stats) -> void:
	stats_changed.emit(stats)


func _on_room_changed(
	room_name: StringName,
	room_index: int
) -> void:
	room_changed.emit(
		room_name,
		room_index
	)


func _on_enemies_changed(
	count: int
) -> void:
	enemies_changed.emit(count)


func _on_game_over(
	victory: bool
) -> void:
	game_over.emit(victory)

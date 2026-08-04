extends Node

signal player_hp_changed(hp: int, max_hp: int)
signal player_speed_changed(value: float)
signal room_changed(room_name: StringName, room_index: int)
signal enemies_changed(count: int)
signal game_over(victory: bool)
signal stats_changed(stats)
signal banked_gold_changed(value: int)
signal run_gold_changed(value: int)
signal keys_changed(value: int)
signal total_gold_changed(value: int)
signal floor_completed_changed(completed: bool)
signal inventory_changed(entries: Array)
signal inventory_item_amount_changed(item_id: String,amount: int)
signal inventory_item_added(item: ItemData,amount: int)
signal quick_slots_changed(slots: Array)
signal selected_quick_slot_changed(slot_index: int)
signal passive_upgrades_changed(entries: Array)

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
const EconomyService = preload("res://Scripts/Managers/EconomyManager.gd")
const InventoryService = preload("res://Scripts/Managers/InventoryManager.gd")
const INVENTORY_MENU_SCENE: PackedScene = preload("res://Scenes/UI/InventoryMenu.tscn")

var _run_state = RunStateService.new()
var _dungeon = DungeonService.new()
var _items = ItemDatabaseService.new()
var _flow = GameFlowService.new()
var _economy = EconomyService.new()
var floor_completed: bool = false
var last_lost_gold: int = 0
var last_lost_keys: int = 0
var _inventory = InventoryService.new()
var passive_run_upgrades: Dictionary = {}
var current_floor: int = 1

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

# Экономика

var banked_gold: int:
	get:
		return _economy.banked_gold


var run_gold: int:
	get:
		return _economy.run_gold


var keys: int:
	get:
		return _economy.keys


var total_gold: int:
	get:
		return _economy.get_total_gold()

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
	_add_service(_economy,"EconomyManager")
	_add_service(_inventory,"InventoryManager")
	set_process_input(true)
	
	_economy.banked_gold_changed.connect(_on_banked_gold_changed)
	_economy.run_gold_changed.connect(_on_run_gold_changed)
	_economy.keys_changed.connect(_on_keys_changed)
	_economy.total_gold_changed.connect(_on_total_gold_changed)
	_economy.emit_current_state()

	_connect_service_signals()

	_items.init_items(self)
	_inventory.emit_current_state()


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
	
	_inventory.inventory_changed.connect(
		_on_inventory_changed
	)

	_inventory.item_amount_changed.connect(
		_on_inventory_item_amount_changed
	)

	_inventory.item_added.connect(
		_on_inventory_item_added
	)
	
	_inventory.quick_slots_changed.connect(
		_on_quick_slots_changed
	)

	_inventory.selected_quick_slot_changed.connect(
		_on_selected_quick_slot_changed
	)


# =========================================================
# УПРАВЛЕНИЕ ИГРОЙ
# =========================================================

func start_game() -> void:
	last_lost_gold = 0
	last_lost_keys = 0

	_economy.start_new_run()

	_flow.start_game(
		Callable(self, "reset_game_state")
	)


func trigger_game_over(
	victory: bool = false
) -> void:
	if _flow.game_over_started:
		return

	last_lost_gold = 0
	last_lost_keys = 0

	if not victory:
		var lost_rewards: Dictionary = (
			_economy.lose_run_rewards()
		)

		last_lost_gold = int(
			lost_rewards.get("gold", 0)
		)

		last_lost_keys = int(
			lost_rewards.get("keys", 0)
		)


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
	_run_state.set_player(
		player_node
	)

	if not is_instance_valid(
		player_node
	):
		return

	if player_node.has_method(
		&"get_current_speed"
	):
		notify_player_speed_changed(
			float(
				player_node.call(
					&"get_current_speed"
				)
			)
		)


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

func notify_player_speed_changed(
	value: float
) -> void:
	player_speed_changed.emit(
		maxf(value, 0.0)
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
	_inventory.reset()
	_clear_passive_run_upgrades()
	_flow.reset()

	current_floor = 1

	floor_completed = false
	floor_completed_changed.emit(
		false
	)

	print(
		"[FLOOR] Новый забег. Этаж: ",
		current_floor
	)

# =========================================================
# ПЕРЕДАЧА СИГНАЛОВ НАРУЖУ
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

func start_new_run_economy() -> void:
	_economy.start_new_run()

func add_gold(amount: int) -> void:
	_economy.add_gold(amount)

func add_keys(amount: int = 1) -> void:
	_economy.add_keys(amount)

func can_afford(amount: int) -> bool:
	return _economy.can_afford(amount)

func spend_gold(amount: int) -> bool:
	return _economy.spend_gold(amount)

func has_key() -> bool:
	return _economy.has_key()

func use_key() -> bool:
	return _economy.use_key()

func leave_floor_economy() -> int:
	return _economy.leave_floor()

func finish_run_voluntarily() -> int:
	return _economy.finish_run_voluntarily()

func lose_run_rewards() -> Dictionary:
	return _economy.lose_run_rewards()
	
func _on_banked_gold_changed(
	value: int
) -> void:
	banked_gold_changed.emit(value)

func _on_run_gold_changed(
	value: int
) -> void:
	run_gold_changed.emit(value)


func _on_keys_changed(value: int) -> void:
	keys_changed.emit(value)


func _on_total_gold_changed(value: int) -> void:
	total_gold_changed.emit(value)

func complete_floor() -> void:
	if floor_completed:
		return

	floor_completed = true
	floor_completed_changed.emit(true)


func can_stay_on_completed_floor() -> bool:
	if not floor_completed:
		return false

	# Сначала ищем несобранные сундуки.
	for chest_node in get_tree().get_nodes_in_group(
		&"FloorChests"
	):
		if not is_instance_valid(
			chest_node
		):
			continue

		if chest_node.is_queued_for_deletion():
			continue

		if not chest_node.has_method(
			&"has_uncollected_reward"
		):
			continue

		var has_reward: bool = bool(
			chest_node.call(
				&"has_uncollected_reward"
			)
		)

		if has_reward:
			return true

	# Затем ищем непроданные товары.
	for merchant_node in get_tree().get_nodes_in_group(
		&"Merchants"
	):
		if not is_instance_valid(
			merchant_node
		):
			continue

		if merchant_node.is_queued_for_deletion():
			continue

		if not merchant_node.has_method(
			&"has_unsold_offers"
		):
			continue

		var has_unsold_offers: bool = bool(
			merchant_node.call(
				&"has_unsold_offers"
			)
		)

		if has_unsold_offers:
			return true

	# Ни сундуков, ни товаров больше не осталось.
	return false

func resume_after_floor_victory() -> void:
	if not floor_completed:
		push_warning(
			"Нельзя остаться на этаже: "
			+ "этаж ещё не завершён."
		)
		return

	if not can_stay_on_completed_floor():
		push_warning(
			"Нельзя остаться на этаже: "
			+ "все сундуки собраны "
			+ "и все товары куплены."
		)
		return
		
	var current_player: Node2D = (
		_run_state.player
	)

	if (
		is_instance_valid(current_player)
		and not current_player.is_queued_for_deletion()
	):
		if current_player.has_method(
			&"activate_completed_floor_speed_boost"
		):
			current_player.call(
				&"activate_completed_floor_speed_boost"
			)
		else:
			push_warning(
				"У игрока отсутствует метод "
				+ "activate_completed_floor_speed_boost()."
			)

	game_over_started = false
	state = GameState.PLAYING
	get_tree().paused = false

func go_to_next_floor() -> void:
	if not floor_completed:
		push_warning(
			"Нельзя перейти дальше: "
			+ "этаж ещё не завершён."
		)
		return

	_economy.leave_floor()

	floor_completed = false
	floor_completed_changed.emit(
		false
	)

	# Комнаты очищаются, но характеристики,
	# здоровье и экономика забега остаются.
	_dungeon.reset()

	current_floor += 1

	print(
		"[FLOOR] Переход на этаж: ",
		current_floor
	)

	_flow.go_to_next_floor()
	
func finish_run_and_return_to_menu() -> void:
	if not floor_completed:
		push_warning(
			"Нельзя сохранить награды: "
			+ "забег ещё не завершён."
		)
		return

	_economy.finish_run_voluntarily()


	floor_completed = false
	floor_completed_changed.emit(false)

	get_tree().paused = false

	_flow.return_to_menu(
		Callable(self, "reset_game_state")
	)

func abandon_run_and_return_to_menu() -> void:
	_economy.lose_run_rewards()


	floor_completed = false
	floor_completed_changed.emit(false)

	get_tree().paused = false

	_flow.return_to_menu(
		Callable(self, "reset_game_state")
	)
	
func _on_inventory_changed(
	entries: Array
) -> void:
	inventory_changed.emit(entries)


func _on_inventory_item_amount_changed(
	item_id: String,
	amount: int
) -> void:
	inventory_item_amount_changed.emit(
		item_id,
		amount
	)


func _on_inventory_item_added(
	item: ItemData,
	amount: int
) -> void:
	inventory_item_added.emit(
		item,
		amount
	)

func _on_quick_slots_changed(
	slots: Array
) -> void:
	quick_slots_changed.emit(slots)


func _on_selected_quick_slot_changed(
	slot_index: int
) -> void:
	selected_quick_slot_changed.emit(
		slot_index
	)
	
# =========================================================
# ИНВЕНТАРЬ
# =========================================================

func add_item_to_inventory(
	item: ItemData,
	amount: int = -1
) -> Dictionary:
	if item == null:
		return {
			"success": false,
			"message": "Предмет не назначен.",
			"added_amount": 0
		}

	var final_amount: int = amount

	# Значение -1 означает случайное количество,
	# указанное в данных предмета.
	if final_amount < 0:
		final_amount = (
			_inventory.roll_grant_amount(item)
		)

	if final_amount <= 0:
		return {
			"success": false,
			"message": "Количество должно быть больше нуля.",
			"added_amount": 0
		}

	# Пассивные награды применяются мгновенно
	# и не сохраняются в инвентаре.
	if (
		item.use_mode
		== ItemData.UseMode.PASSIVE
	):
		return _apply_passive_reward(
			item,
			final_amount
		)

	# Все используемые предметы отправляются
	# в обычный инвентарь.
	return _inventory.add_item(
		item,
		final_amount
	)

func can_receive_passive_upgrade(
	item: ItemData
) -> bool:
	if item == null:
		return false

	if (
		item.use_mode
		!= ItemData.UseMode.PASSIVE
	):
		return true

	var current_stacks: int = (
		get_passive_upgrade_count(
			item.id
		)
	)

	var maximum_stacks: int = maxi(
		item.max_passive_stacks,
		1
	)

	return current_stacks < maximum_stacks

func _apply_passive_reward(
	item: ItemData,
	amount: int
) -> Dictionary:
	if player_stats == null:
		return {
			"success": false,
			"message": (
				"Не найдены характеристики игрока."
			),
			"added_amount": 0
		}

	if not item.apply.is_valid():
		return {
			"success": false,
			"message": (
				"У награды отсутствует эффект: "
				+ item.name
			),
			"added_amount": 0
		}

	var current_stacks: int = (
		get_passive_upgrade_count(
			item.id
		)
	)

	var maximum_stacks: int = maxi(
		item.max_passive_stacks,
		1
	)

	var available_stacks: int = maxi(
		maximum_stacks - current_stacks,
		0
	)

	var applied_amount: int = mini(
		amount,
		available_stacks
	)

	if applied_amount <= 0:
		return {
			"success": false,
			"message": (
				"Достигнут максимум улучшения: "
				+ item.name
			),
			"requested_amount": amount,
			"added_amount": 0,
			"overflow_amount": amount,
			"new_amount": current_stacks,
			"applied_immediately": false
		}

	for _stack_index in range(
		applied_amount
	):
		item.apply.call(
			player_stats,
			self
		)

	_register_passive_upgrade(
		item,
		applied_amount
	)

	var new_stack_amount: int = (
		current_stacks
		+ applied_amount
	)

	return {
		"success": true,
		"message": (
			"Получено улучшение: "
			+ item.name
			+ (
				" ×" + str(applied_amount)
				if applied_amount > 1
				else ""
			)
		),
		"item": item,
		"requested_amount": amount,
		"added_amount": applied_amount,
		"overflow_amount": (
			amount - applied_amount
		),
		"new_amount": new_stack_amount,
		"applied_immediately": true
	}

func roll_item_grant_amount(
	item: ItemData
) -> int:
	return _inventory.roll_grant_amount(item)

func remove_inventory_item(
	item_id: String,
	amount: int = 1
) -> bool:
	return _inventory.remove_item(
		item_id,
		amount
	)


func get_inventory_item_amount(
	item_id: String
) -> int:
	return _inventory.get_amount(item_id)


func has_inventory_item(
	item_id: String,
	amount: int = 1
) -> bool:
	return _inventory.has_item(
		item_id,
		amount
	)


func get_inventory_entries() -> Array[Dictionary]:
	return _inventory.get_entries()


func clear_run_inventory() -> void:
	_inventory.clear_inventory()

func assign_item_to_quick_slot(
	item_id: String,
	slot_index: int
) -> Dictionary:
	return _inventory.assign_item_to_quick_slot(
		item_id,
		slot_index
	)


func clear_quick_slot(
	slot_index: int
) -> bool:
	return _inventory.clear_quick_slot(
		slot_index
	)


func select_quick_slot(
	slot_index: int
) -> bool:
	return _inventory.select_quick_slot(
		slot_index
	)

func use_quick_slot(
	slot_index: int
) -> Dictionary:
	if (
		slot_index < 0
		or slot_index >= get_quick_slot_count()
	):
		return {
			"success": false,
			"message": (
				"Некорректный быстрый слот."
			)
		}

	var item: ItemData = (
		get_quick_slot_item(
			slot_index
		)
	)

	if item == null:
		return {
			"success": false,
			"message": (
				"Быстрый слот "
				+ str(slot_index + 1)
				+ " пуст."
			)
		}

	if not has_inventory_item(
		item.id,
		1
	):
		clear_quick_slot(
			slot_index
		)

		return {
			"success": false,
			"message": (
				"Предмет закончился."
			)
		}


	# Боеприпасы не используются сразу.
	# Клавиша включает или выключает выбранный тип снаряда.
	if (
		item.use_mode
		== ItemData.UseMode.AMMO
	):
		if (
			get_selected_quick_slot()
			== slot_index
		):
			clear_selected_quick_slot()

			return {
				"success": true,
				"consumed": false,
				"message": (
					"Боеприпас выключен. "
					+ "Используются обычные яйца."
				)
			}

		var selected: bool = (
			select_quick_slot(
				slot_index
			)
		)

		return {
			"success": selected,
			"consumed": false,
			"message": (
				"Выбран боеприпас: "
				+ item.name
			)
		}

	if not is_instance_valid(player):
		return {
			"success": false,
			"message": (
				"Игрок не найден."
			)
		}

	if not player.has_method(
		"use_inventory_item"
	):
		return {
			"success": false,
			"message": (
				"Игрок не умеет использовать предметы."
			)
		}

	var use_result = player.call(
		"use_inventory_item",
		item.id
	)

	if not (use_result is Dictionary):
		return {
			"success": false,
			"message": (
				"Предмет вернул некорректный результат."
			)
		}

	var result: Dictionary = use_result

	if not bool(
		result.get(
			"success",
			false
		)
	):
		return result

	var removed: bool = (
		remove_inventory_item(
			item.id,
			1
		)
	)

	if not removed:
		var should_rollback: bool = bool(
			result.get(
				"rollback_on_consume_failure",
				false
			)
		)

		if (
			should_rollback
			and player.has_method(
				"rollback_inventory_item_use"
			)
		):
			player.call(
				"rollback_inventory_item_use",
				item.id
			)

		push_warning(
			"Предмет был применён, "
			+ "но его не удалось списать: "
			+ item.id
		)

		return {
			"success": false,
			"message": (
				"Не удалось списать предмет."
			)
		}

	result["consumed"] = true
	result["remaining_amount"] = (
		get_inventory_item_amount(
			item.id
		)
	)

	return result

func clear_selected_quick_slot() -> void:
	_inventory.clear_selected_quick_slot()


func get_quick_slot_count() -> int:
	return _inventory.get_quick_slot_count()


func get_quick_slots() -> Array[String]:
	return _inventory.get_quick_slots()


func get_quick_slot_item_id(
	slot_index: int
) -> String:
	return _inventory.get_quick_slot_item_id(
		slot_index
	)


func get_quick_slot_item(
	slot_index: int
) -> ItemData:
	return _inventory.get_quick_slot_item(
		slot_index
	)


func get_selected_quick_slot() -> int:
	return _inventory.get_selected_quick_slot()


func get_quick_slot_entries() -> Array[Dictionary]:
	return _inventory.get_quick_slot_entries()

# =========================================================
# ОКНО ИНВЕНТАРЯ
# =========================================================

func _input(
	event: InputEvent
) -> void:
	if not event.is_action_pressed(
		"inventory"
	):
		return


	if state != GameState.PLAYING:
		return

	if get_tree().paused:
		return

	if get_tree().get_first_node_in_group(
		"InventoryMenu"
	) != null:
		return

	get_viewport().set_input_as_handled()

	_open_inventory_menu()


func _open_inventory_menu() -> void:
	if INVENTORY_MENU_SCENE == null:
		push_error(
			"Не удалось загрузить InventoryMenu.tscn"
		)
		return

	var current_scene: Node = (
		get_tree().current_scene
	)

	if current_scene == null:
		push_error(
			"Не найдена текущая игровая сцена."
		)
		return

	var menu := (
		INVENTORY_MENU_SCENE.instantiate()
	)

	if menu == null:
		push_error(
			"Не удалось создать InventoryMenu."
		)
		return

	current_scene.add_child(menu)
	
func get_active_timed_effects() -> Array[Dictionary]:
	if not is_instance_valid(player):
		return []

	if not player.has_method(
		"get_active_timed_effects"
	):
		return []

	var raw_result = player.call(
		"get_active_timed_effects"
	)

	if not (raw_result is Array):
		return []

	var result: Array[Dictionary] = []

	for entry in raw_result:
		if entry is Dictionary:
			result.append(entry)

	return result


func _clear_passive_run_upgrades() -> void:
	passive_run_upgrades.clear()
	passive_upgrades_changed.emit(
		get_passive_upgrade_entries()
	)


func _register_passive_upgrade(
	item: ItemData,
	amount: int
) -> void:
	if item == null:
		return

	if amount <= 0:
		return

	if not passive_run_upgrades.has(item.id):
		passive_run_upgrades[item.id] = {
			"item": item,
			"count": 0
		}

	passive_run_upgrades[item.id]["count"] += amount

	passive_upgrades_changed.emit(
		get_passive_upgrade_entries()
	)


func get_passive_upgrade_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for item_id in passive_run_upgrades.keys():
		var entry: Dictionary = passive_run_upgrades[item_id]
		var item := entry.get("item") as ItemData
		var count: int = int(
			entry.get("count", 0)
		)

		if item == null:
			continue

		if count <= 0:
			continue

		result.append({
			"item_id": item_id,
			"item": item,
			"count": count
		})

	return result


func get_passive_upgrade_count(
	item_id: String
) -> int:
	if not passive_run_upgrades.has(item_id):
		return 0

	return int(
		passive_run_upgrades[item_id].get(
			"count",
			0
		)
	)

extends Node
class_name BalanceTelemetry


@export_group("Telemetry")

@export var telemetry_enabled: bool = true
@export var save_automatically: bool = true
@export var print_room_summaries: bool = true


var run_started_msec: int = 0
var visit_counter: int = 0

var current_room_data: Dictionary = {}
var finished_room_visits: Array[Dictionary] = []

var acquired_items: Array[Dictionary] = []

var totals: Dictionary = {
	"shots": 0,
	"hits": 0,
	"direct_damage_dealt": 0,
	"damage_taken": 0,
	"healing_received": 0,
	"direct_player_kills": 0,
	"enemy_removals": 0
}

var registered_enemy_ids: Dictionary = {}
var registered_enemies: Array[Node] = []

var report_saved: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if (
		not OS.is_debug_build()
		or not telemetry_enabled
	):
		set_process_input(false)
		return

	add_to_group(
		&"BalanceTelemetry"
	)

	run_started_msec = Time.get_ticks_msec()

	_connect_game_signals()

	if not get_tree().node_added.is_connected(
		_on_tree_node_added
	):
		get_tree().node_added.connect(
			_on_tree_node_added
		)

	print(
		"[BALANCE] Телеметрия запущена. "
		+ "F3 — сохранить промежуточный отчёт."
	)


func _exit_tree() -> void:
	_disconnect_registered_enemies()

	if get_tree().node_added.is_connected(
		_on_tree_node_added
	):
		get_tree().node_added.disconnect(
			_on_tree_node_added
		)


# =========================================================
# ПОДКЛЮЧЕНИЕ СИГНАЛОВ
# =========================================================

func _connect_game_signals() -> void:
	if not GameManager.room_changed.is_connected(
		_on_room_changed
	):
		GameManager.room_changed.connect(
			_on_room_changed
		)

	if not GameManager.enemies_changed.is_connected(
		_on_enemies_changed
	):
		GameManager.enemies_changed.connect(
			_on_enemies_changed
		)

	if not GameManager.game_over.is_connected(
		_on_game_over
	):
		GameManager.game_over.connect(
			_on_game_over
		)

	if not GameManager.inventory_item_added.is_connected(
		_on_inventory_item_added
	):
		GameManager.inventory_item_added.connect(
			_on_inventory_item_added
		)


# =========================================================
# КОМНАТЫ
# =========================================================

func _on_room_changed(
	room_name: StringName,
	room_index: int
) -> void:
	_finalize_current_room(
		"left_room"
	)

	visit_counter += 1

	var room: Node2D = null

	if (
		room_index >= 0
		and room_index
		< GameManager.room_instances.size()
	):
		room = GameManager.room_instances[
			room_index
		]

	current_room_data = {
		"visit_number": visit_counter,
		"room_name": String(room_name),
		"room_index": room_index,
		"room_type": _get_room_type_name(room),

		"entered_msec": Time.get_ticks_msec(),
		"duration_seconds": 0.0,

		"combat_started": false,
		"combat_started_msec": 0,
		"cleared": false,
		"clear_time_seconds": null,

		"hp_start": GameManager.player_hp,
		"hp_end": GameManager.player_hp,
		"max_hp": GameManager.player_max_hp,

		"initial_enemy_count": 0,
		"peak_enemy_count": 0,
		"last_enemy_count": 0,

		"enemy_spawns": {},
		"enemy_removals_by_type": {},

		"shots": 0,
		"hits": 0,
		"direct_damage_dealt": 0,
		"damage_taken": 0,
		"healing_received": 0,
		"direct_player_kills": 0,
		"enemy_removals": 0,

		"stats_at_entry": _get_stats_snapshot()
	}

	call_deferred(
		&"_refresh_current_room_enemies"
	)


func _on_enemies_changed(
	count: int
) -> void:
	if current_room_data.is_empty():
		return

	current_room_data["last_enemy_count"] = count

	var peak_count: int = int(
		current_room_data.get(
			"peak_enemy_count",
			0
		)
	)

	current_room_data["peak_enemy_count"] = maxi(
		peak_count,
		count
	)

	var combat_started: bool = bool(
		current_room_data.get(
			"combat_started",
			false
		)
	)

	if count > 0 and not combat_started:
		current_room_data["combat_started"] = true
		current_room_data["combat_started_msec"] = (
			Time.get_ticks_msec()
		)

		current_room_data["initial_enemy_count"] = (
			count
		)

		return

	var cleared: bool = bool(
		current_room_data.get(
			"cleared",
			false
		)
	)

	if (
		count == 0
		and combat_started
		and not cleared
	):
		current_room_data["cleared"] = true

		var combat_started_msec: int = int(
			current_room_data.get(
				"combat_started_msec",
				Time.get_ticks_msec()
			)
		)

		current_room_data["clear_time_seconds"] = (
			_seconds_since(
				combat_started_msec
			)
		)

		current_room_data["hp_end"] = (
			GameManager.player_hp
		)

		if print_room_summaries:
			_print_current_room_summary(
				"room_cleared"
			)


func _refresh_current_room_enemies() -> void:
	var room: Node2D = (
		GameManager.get_current_room()
	)

	if not is_instance_valid(room):
		return

	for enemy in get_tree().get_nodes_in_group(
		&"Enemies"
	):
		if not is_instance_valid(enemy):
			continue

		if not room.is_ancestor_of(enemy):
			continue

		_register_enemy(enemy)

	_on_enemies_changed(
		GameManager.get_enemy_count_in_room()
	)


# =========================================================
# ВРАГИ
# =========================================================

func _on_tree_node_added(
	node: Node
) -> void:
	if current_room_data.is_empty():
		return

	call_deferred(
		&"_try_register_enemy",
		node
	)


func _try_register_enemy(
	node: Node
) -> void:
	if not is_instance_valid(node):
		return

	var is_enemy: bool = (
		node is BaseEnemy
		or node.is_in_group(&"Enemies")
	)

	if not is_enemy:
		return

	var room: Node2D = (
		GameManager.get_current_room()
	)

	if not is_instance_valid(room):
		return

	if not room.is_ancestor_of(node):
		return

	_register_enemy(node)


func _register_enemy(
	enemy: Node
) -> void:
	if not is_instance_valid(enemy):
		return

	var instance_id: int = (
		enemy.get_instance_id()
	)

	if registered_enemy_ids.has(
		instance_id
	):
		return

	registered_enemy_ids[instance_id] = true
	registered_enemies.append(enemy)

	if (
		enemy.has_signal(&"died")
		and not enemy.died.is_connected(
			_on_enemy_died
		)
	):
		enemy.died.connect(
			_on_enemy_died
		)

	var enemy_type: String = (
		_get_node_type_name(enemy)
	)

	_increment_dictionary_counter(
		current_room_data,
		"enemy_spawns",
		enemy_type,
		1
	)


func _on_enemy_died(
	victim: Node
) -> void:
	if current_room_data.is_empty():
		return

	current_room_data["enemy_removals"] = (
		int(
			current_room_data.get(
				"enemy_removals",
				0
			)
		)
		+ 1
	)

	totals["enemy_removals"] = (
		int(totals["enemy_removals"])
		+ 1
	)

	var enemy_type: String = (
		_get_node_type_name(victim)
	)

	_increment_dictionary_counter(
		current_room_data,
		"enemy_removals_by_type",
		enemy_type,
		1
	)


func _disconnect_registered_enemies() -> void:
	for enemy in registered_enemies:
		if not is_instance_valid(enemy):
			continue

		if (
			enemy.has_signal(&"died")
			and enemy.died.is_connected(
				_on_enemy_died
			)
		):
			enemy.died.disconnect(
				_on_enemy_died
			)

	registered_enemies.clear()
	registered_enemy_ids.clear()


# =========================================================
# СОБЫТИЯ ИГРОКА
# =========================================================

func record_shot() -> void:
	_increment_total_and_room(
		"shots",
		1
	)


func record_direct_hit(
	target: Node,
	damage_amount: int,
	killed_by_hit: bool
) -> void:
	_increment_total_and_room(
		"hits",
		1
	)

	_increment_total_and_room(
		"direct_damage_dealt",
		maxi(damage_amount, 0)
	)

	if killed_by_hit:
		_increment_total_and_room(
			"direct_player_kills",
			1
		)

	var target_name: String = (
		_get_node_type_name(target)
	)

	_increment_dictionary_counter(
		current_room_data,
		"direct_hits_by_type",
		target_name,
		1
	)


func record_damage_taken(
	amount: int
) -> void:
	_increment_total_and_room(
		"damage_taken",
		maxi(amount, 0)
	)

	if not current_room_data.is_empty():
		current_room_data["hp_end"] = (
			GameManager.player_hp
			- amount
		)


func record_healing(
	amount: int
) -> void:
	_increment_total_and_room(
		"healing_received",
		maxi(amount, 0)
	)

	if not current_room_data.is_empty():
		current_room_data["hp_end"] = (
			GameManager.player_hp
		)


func _increment_total_and_room(
	key: String,
	amount: int
) -> void:
	totals[key] = (
		int(totals.get(key, 0))
		+ amount
	)

	if current_room_data.is_empty():
		return

	current_room_data[key] = (
		int(
			current_room_data.get(
				key,
				0
			)
		)
		+ amount
	)


# =========================================================
# ПРЕДМЕТЫ
# =========================================================

func _on_inventory_item_added(
	item: ItemData,
	amount: int
) -> void:
	if item == null:
		return

	acquired_items.append({
		"item_id": item.id,
		"item_name": item.name,
		"amount": amount,
		"room_index": (
			GameManager.current_room_index
		),
		"time_seconds": _seconds_since(
			run_started_msec
		)
	})


# =========================================================
# ЗАВЕРШЕНИЕ КОМНАТЫ
# =========================================================

func _finalize_current_room(
	reason: String
) -> void:
	if current_room_data.is_empty():
		return

	current_room_data["duration_seconds"] = (
		_seconds_since(
			int(
				current_room_data.get(
					"entered_msec",
					Time.get_ticks_msec()
				)
			)
		)
	)

	current_room_data["hp_end"] = (
		GameManager.player_hp
	)

	current_room_data["exit_reason"] = reason
	current_room_data["stats_at_exit"] = (
		_get_stats_snapshot()
	)

	_add_accuracy_to_dictionary(
		current_room_data
	)

	if print_room_summaries:
		_print_current_room_summary(reason)

	finished_room_visits.append(
		current_room_data.duplicate(true)
	)

	current_room_data.clear()

	_disconnect_registered_enemies()


# =========================================================
# ИТОГ ЗАБЕГА
# =========================================================

func _on_game_over(
	victory: bool
) -> void:
	if report_saved:
		return

	_finalize_current_room(
		"victory"
		if victory
		else "defeat"
	)

	report_saved = true

	if save_automatically:
		_save_report(
			"victory"
			if victory
			else "defeat"
		)


func _save_report(
	status: String
) -> void:
	var rooms_for_report: Array[Dictionary] = (
		finished_room_visits.duplicate(true)
	)

	if not current_room_data.is_empty():
		var current_snapshot: Dictionary = (
			current_room_data.duplicate(true)
		)

		current_snapshot["duration_seconds"] = (
			_seconds_since(
				int(
					current_snapshot.get(
						"entered_msec",
						Time.get_ticks_msec()
					)
				)
			)
		)

		current_snapshot["hp_end"] = (
			GameManager.player_hp
		)

		current_snapshot["exit_reason"] = (
			"report_snapshot"
		)

		_add_accuracy_to_dictionary(
			current_snapshot
		)

		rooms_for_report.append(
			current_snapshot
		)

	var totals_snapshot: Dictionary = (
		totals.duplicate(true)
	)

	_add_accuracy_to_dictionary(
		totals_snapshot
	)

	var report: Dictionary = {
		"version": 1,
		"saved_at": (
			Time.get_datetime_string_from_system()
		),
		"status": status,

		"run_duration_seconds": (
			_seconds_since(run_started_msec)
		),

		"final_hp": GameManager.player_hp,
		"final_max_hp": GameManager.player_max_hp,

		"final_stats": _get_stats_snapshot(),

		"run_gold": GameManager.run_gold,
		"keys": GameManager.keys,

		"totals": totals_snapshot,
		"acquired_items": acquired_items,
		"room_visits": rooms_for_report
	}

	var directory_path: String = (
		"user://balance_logs"
	)

	var user_directory := DirAccess.open(
		"user://"
	)

	if user_directory == null:
		push_error(
			"[BALANCE] Не удалось открыть user://"
		)
		return

	user_directory.make_dir_recursive(
		"balance_logs"
	)

	var timestamp: String = (
		Time.get_datetime_string_from_system(
			false,
			true
		)
		.replace(":", "-")
		.replace(" ", "_")
	)

	var file_path: String = (
		directory_path
		+ "/balance_"
		+ timestamp
		+ "_"
		+ status
		+ ".json"
	)

	var file := FileAccess.open(
		file_path,
		FileAccess.WRITE
	)

	if file == null:
		push_error(
			"[BALANCE] Не удалось создать отчёт: "
			+ file_path
		)
		return

	file.store_string(
		JSON.stringify(
			report,
			"\t"
		)
	)

	file.close()

	print(
		"[BALANCE] Отчёт сохранён: "
		+ file_path
	)


# =========================================================
# РУЧНОЕ СОХРАНЕНИЕ
# =========================================================

func _input(
	event: InputEvent
) -> void:
	if not telemetry_enabled:
		return

	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey

	if (
		not key_event.pressed
		or key_event.echo
	):
		return

	var is_f3: bool = (
		key_event.keycode == KEY_F3
		or key_event.physical_keycode == KEY_F3
	)

	if not is_f3:
		return

	_save_report(
		"manual"
	)

	get_viewport().set_input_as_handled()


# =========================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# =========================================================

func _get_room_type_name(
	room: Node
) -> String:
	var typed_room := room as Room

	if typed_room == null:
		return "UNKNOWN"

	match typed_room.room_type:
		Room.RoomType.START:
			return "START"

		Room.RoomType.COMBAT:
			return "COMBAT"

		Room.RoomType.TREASURE:
			return "TREASURE"

		Room.RoomType.SHOP:
			return "SHOP"

		Room.RoomType.BOSS:
			return "BOSS"

	return "UNKNOWN"


func _get_node_type_name(
	node: Node
) -> String:
	if not is_instance_valid(node):
		return "InvalidNode"

	if not node.scene_file_path.is_empty():
		return (
			node.scene_file_path
			.get_file()
			.get_basename()
		)

	var node_script: Script = (
		node.get_script() as Script
	)

	if (
		node_script != null
		and not node_script.resource_path.is_empty()
	):
		return (
			node_script.resource_path
			.get_file()
			.get_basename()
		)

	return String(node.name)


func _get_stats_snapshot() -> Dictionary:
	var stats = GameManager.player_stats

	if stats == null:
		return {}

	return {
		"max_hp": stats.max_hp,
		"damage": stats.damage,
		"speed": stats.speed,
		"fire_rate": stats.fire_rate,
		"egg_speed": stats.egg_speed,
		"attack_range": stats.attack_range,
		"attack_range_multiplier": (
			stats.attack_range_multiplier
		)
	}


func _seconds_since(
	start_msec: int
) -> float:
	return snappedf(
		float(
			Time.get_ticks_msec()
			- start_msec
		)
		/ 1000.0,
		0.01
	)


func _increment_dictionary_counter(
	container: Dictionary,
	dictionary_key: String,
	counter_key: String,
	amount: int
) -> void:
	if container.is_empty():
		return

	var counters: Dictionary = (
		container.get(
			dictionary_key,
			{}
		)
	)

	counters[counter_key] = (
		int(
			counters.get(
				counter_key,
				0
			)
		)
		+ amount
	)

	container[dictionary_key] = counters


func _add_accuracy_to_dictionary(
	data: Dictionary
) -> void:
	var shots: int = int(
		data.get("shots", 0)
	)

	var hits: int = int(
		data.get("hits", 0)
	)

	var accuracy: float = 0.0

	if shots > 0:
		accuracy = (
			float(hits)
			/ float(shots)
			* 100.0
		)

	data["accuracy_percent"] = (
		snappedf(accuracy, 0.1)
	)


func _print_current_room_summary(
	reason: String
) -> void:
	if current_room_data.is_empty():
		return

	var shots: int = int(
		current_room_data.get(
			"shots",
			0
		)
	)

	var hits: int = int(
		current_room_data.get(
			"hits",
			0
		)
	)

	var accuracy: float = 0.0

	if shots > 0:
		accuracy = (
			float(hits)
			/ float(shots)
			* 100.0
		)

	print(
		"\n[BALANCE ROOM] ",
		current_room_data.get(
			"room_name",
			"Unknown"
		),
		" | ",
		current_room_data.get(
			"room_type",
			"UNKNOWN"
		),
		" | reason=",
		reason,
		"\n  time=",
		_seconds_since(
			int(
				current_room_data.get(
					"entered_msec",
					Time.get_ticks_msec()
				)
			)
		),
		" sec",
		"\n  clear_time=",
		current_room_data.get(
			"clear_time_seconds",
			"-"
		),
		"\n  enemies initial/peak=",
		current_room_data.get(
			"initial_enemy_count",
			0
		),
		"/",
		current_room_data.get(
			"peak_enemy_count",
			0
		),
		"\n  shots/hits=",
		shots,
		"/",
		hits,
		" | accuracy=",
		snappedf(accuracy, 0.1),
		"%",
		"\n  damage dealt/taken=",
		current_room_data.get(
			"direct_damage_dealt",
			0
		),
		"/",
		current_room_data.get(
			"damage_taken",
			0
		),
		"\n  hp=",
		current_room_data.get(
			"hp_start",
			0
		),
		" → ",
		GameManager.player_hp
	)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

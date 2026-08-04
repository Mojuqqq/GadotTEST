extends Node
class_name BalanceTelemetry


@export_group("Telemetry")

@export var telemetry_enabled: bool = true
@export var save_automatically: bool = true
@export var print_room_summaries: bool = true


# =========================================================
# КОНТЕКСТ ВСЕГО ЗАБЕГА
# =========================================================

# Static-поля сохраняются между переходами
# на следующие этажи.
static var active_run_id: String = ""
static var active_floor_number: int = 0

static var active_run_started_unix_msec: int = 0

static var previous_floor_final_stats: Dictionary = {}


var run_id: String = ""
var floor_number: int = 1
var started_as_new_run: bool = false

var previous_floor_stats_snapshot: Dictionary = {}


# =========================================================
# СОСТОЯНИЕ ТЕКУЩЕГО ЭТАЖА
# =========================================================

var floor_started_msec: int = 0
var visit_counter: int = 0

var tracked_room: Node2D = null

var current_room_data: Dictionary = {}
var finished_room_visits: Array[Dictionary] = []


# =========================================================
# СОБЫТИЯ ЭТАЖА
# =========================================================

var acquired_items: Array[Dictionary] = []
var stat_changes: Array[Dictionary] = []
var passive_upgrade_events: Array[Dictionary] = []
var damage_events: Array[Dictionary] = []

var last_stats_snapshot: Dictionary = {}


# =========================================================
# ОБЩИЕ СЧЁТЧИКИ
# =========================================================

var totals: Dictionary = {
	"shots": 0,
	"hits": 0,

	"direct_damage_dealt": 0,

	# Периодический урон ядовитой лужи.
	"poison_damage_dealt": 0,
	"poison_ticks": 0,
	"poison_kills": 0,
	"poison_damage_by_target": {},
	
	# Урон дружественных компаньонов.
	"companion_damage_dealt": 0,
	"companion_hits": 0,
	"companion_kills": 0,
	"companion_damage_by_source": {},
	"companion_damage_by_target": {},

	"damage_taken": 0,
	"healing_received": 0,
	"direct_player_kills": 0,
	"enemy_removals": 0,

	"damage_by_source": {},
	"damage_by_attack_type": {}
}


# =========================================================
# ЗАРЕГИСТРИРОВАННЫЕ ВРАГИ
# =========================================================

var registered_enemy_ids: Dictionary = {}
var registered_enemies: Array[Node] = []


var report_saved: bool = false


# =========================================================
# ИНИЦИАЛИЗАЦИЯ
# =========================================================

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

	_initialize_run_context()

	floor_started_msec = Time.get_ticks_msec()

	last_stats_snapshot = (
		_get_stats_snapshot()
	)

	_connect_game_signals()

	if not get_tree().node_added.is_connected(
		_on_tree_node_added
	):
		get_tree().node_added.connect(
			_on_tree_node_added
		)

	print(
		"[BALANCE] Телеметрия запущена. ",
		"run_id=",
		run_id,
		", floor=",
		floor_number,
		". F3 — сохранить промежуточный отчёт."
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
# КОНТЕКСТ ЗАБЕГА
# =========================================================

func _initialize_run_context() -> void:
	# На новом забеге характеристики ещё не созданы.
	# При переходе на следующий этаж они сохраняются.
	started_as_new_run = (
		GameManager.player_stats == null
	)

	if (
		started_as_new_run
		or active_run_id.is_empty()
	):
		active_run_id = _create_run_id()
		active_floor_number = 1

		active_run_started_unix_msec = (
			_get_current_unix_msec()
		)

		previous_floor_final_stats = {}

	else:
		active_floor_number += 1

	run_id = active_run_id

	floor_number = maxi(
		active_floor_number,
		1
	)

	previous_floor_stats_snapshot = (
		previous_floor_final_stats.duplicate(
			true
		)
	)


func _create_run_id() -> String:
	return (
		str(
			int(
				Time.get_unix_time_from_system()
			)
		)
		+ "-"
		+ str(randi())
	)


func _get_current_unix_msec() -> int:
	return int(
		Time.get_unix_time_from_system()
		* 1000.0
	)


func _get_total_run_duration() -> float:
	if active_run_started_unix_msec <= 0:
		return _seconds_since(
			floor_started_msec
		)

	return snappedf(
		float(
			_get_current_unix_msec()
			- active_run_started_unix_msec
		)
		/ 1000.0,
		0.01
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

	if not GameManager.stats_changed.is_connected(
		_on_stats_changed
	):
		GameManager.stats_changed.connect(
			_on_stats_changed
		)

	if not GameManager.passive_upgrades_changed.is_connected(
		_on_passive_upgrades_changed
	):
		GameManager.passive_upgrades_changed.connect(
			_on_passive_upgrades_changed
		)


# =========================================================
# ВХОД В КОМНАТУ
# =========================================================

func _on_room_changed(
	room_name: StringName,
	room_index: int
) -> void:
	# tracked_room всё ещё указывает на предыдущую
	# комнату, поэтому сначала завершаем её.
	_finalize_current_room(
		"left_room"
	)

	visit_counter += 1

	tracked_room = null

	if (
		room_index >= 0
		and room_index
		< GameManager.room_instances.size()
	):
		tracked_room = GameManager.room_instances[
			room_index
		]

	current_room_data = {
		"run_id": run_id,
		"floor_number": floor_number,

		"visit_number": visit_counter,
		"room_name": String(room_name),
		"room_index": room_index,
		"room_type": (
			_get_room_type_name(
				tracked_room
			)
		),

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

		"poison_damage_dealt": 0,
		"poison_ticks": 0,
		"poison_kills": 0,
		"poison_damage_by_target": {},
		"companion_damage_dealt": 0,
		"companion_hits": 0,
		"companion_kills": 0,
		"companion_damage_by_source": {},
		"companion_damage_by_target": {},

		"damage_taken": 0,
		"healing_received": 0,

		"direct_player_kills": 0,
		"enemy_removals": 0,

		"damage_by_source": {},
		"damage_by_attack_type": {},
		"damage_events": [],

		"stats_at_entry": (
			_get_stats_snapshot()
		)
	}

	call_deferred(
		&"_refresh_current_room_enemies"
	)


# =========================================================
# КОЛИЧЕСТВО ВРАГОВ
# =========================================================

func _on_enemies_changed(
	count: int
) -> void:
	if current_room_data.is_empty():
		return

	var safe_count: int = maxi(
		count,
		0
	)

	current_room_data["last_enemy_count"] = (
		safe_count
	)

	current_room_data["peak_enemy_count"] = maxi(
		int(
			current_room_data.get(
				"peak_enemy_count",
				0
			)
		),
		safe_count
	)

	var combat_started: bool = bool(
		current_room_data.get(
			"combat_started",
			false
		)
	)

	if safe_count > 0 and not combat_started:
		current_room_data["combat_started"] = true

		current_room_data["combat_started_msec"] = (
			Time.get_ticks_msec()
		)

		current_room_data["initial_enemy_count"] = (
			safe_count
		)

		return

	_mark_room_cleared_if_needed(
		safe_count,
		true
	)


func _refresh_current_room_enemies() -> void:
	if not is_instance_valid(
		tracked_room
	):
		return

	for enemy in get_tree().get_nodes_in_group(
		&"Enemies"
	):
		if not _is_live_enemy_in_room(
			enemy,
			tracked_room
		):
			continue

		_register_enemy(
			enemy
		)

	_reconcile_current_room_enemy_count()


func _reconcile_current_room_enemy_count() -> void:
	if current_room_data.is_empty():
		return

	var live_count: int = (
		_count_live_enemies_in_tracked_room()
	)

	_on_enemies_changed(
		live_count
	)


func _mark_room_cleared_if_needed(
	live_count: int,
	print_summary: bool
) -> void:
	if current_room_data.is_empty():
		return

	if live_count > 0:
		return

	var combat_started: bool = bool(
		current_room_data.get(
			"combat_started",
			false
		)
	)

	if not combat_started:
		return

	var already_cleared: bool = bool(
		current_room_data.get(
			"cleared",
			false
		)
	)

	if already_cleared:
		return

	current_room_data["cleared"] = true
	current_room_data["last_enemy_count"] = 0

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

	if (
		print_summary
		and print_room_summaries
	):
		_print_current_room_summary(
			"room_cleared"
		)


func _count_live_enemies_in_tracked_room() -> int:
	if not is_instance_valid(
		tracked_room
	):
		return 0

	var count: int = 0

	for enemy in get_tree().get_nodes_in_group(
		&"Enemies"
	):
		if _is_live_enemy_in_room(
			enemy,
			tracked_room
		):
			count += 1

	return count


func _is_live_enemy_in_room(
	enemy: Node,
	room: Node2D
) -> bool:
	if not is_instance_valid(enemy):
		return false

	if enemy.is_queued_for_deletion():
		return false

	if not room.is_ancestor_of(enemy):
		return false

	if enemy is BaseEnemy:
		var base_enemy := enemy as BaseEnemy

		if base_enemy.is_dead:
			return false

	return true


# =========================================================
# РЕГИСТРАЦИЯ ВРАГОВ
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

	if not is_instance_valid(
		tracked_room
	):
		return

	if not tracked_room.is_ancestor_of(
		node
	):
		return

	_register_enemy(
		node
	)

	_reconcile_current_room_enemy_count()


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
	registered_enemies.append(
		enemy
	)

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
		_get_node_type_name(
			enemy
		)
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

	_increment_total_and_room(
		"enemy_removals",
		1
	)

	var enemy_type: String = (
		_get_node_type_name(
			victim
		)
	)

	_increment_dictionary_counter(
		current_room_data,
		"enemy_removals_by_type",
		enemy_type,
		1
	)

	# Дождёмся, когда враг удалится из группы
	# или получит is_dead.
	call_deferred(
		&"_reconcile_current_room_enemy_count"
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
# ВЫСТРЕЛЫ И ПОПАДАНИЯ
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
		maxi(
			damage_amount,
			0
		)
	)

	if killed_by_hit:
		_increment_total_and_room(
			"direct_player_kills",
			1
		)

	var target_name: String = (
		_get_node_type_name(
			target
		)
	)

	_increment_dictionary_counter(
		current_room_data,
		"direct_hits_by_type",
		target_name,
		1
	)

func record_poison_damage_dealt(
	target: Node,
	damage_amount: int,
	killed_by_poison: bool
) -> void:
	var actual_amount: int = maxi(
		damage_amount,
		0
	)

	if actual_amount <= 0:
		return

	_increment_total_and_room(
		"poison_damage_dealt",
		actual_amount
	)

	_increment_total_and_room(
		"poison_ticks",
		1
	)

	if killed_by_poison:
		_increment_total_and_room(
			"poison_kills",
			1
		)

	var target_name: String = (
		_get_node_type_name(
			target
		)
	)

	_increment_dictionary_counter(
		totals,
		"poison_damage_by_target",
		target_name,
		actual_amount
	)

	_increment_dictionary_counter(
		current_room_data,
		"poison_damage_by_target",
		target_name,
		actual_amount
	)


func record_companion_damage(
	source_name: String,
	target: Node,
	damage_amount: int,
	killed_by_companion: bool
) -> void:
	var actual_amount: int = maxi(
		damage_amount,
		0
	)

	if actual_amount <= 0:
		return

	var safe_source_name: String = (
		source_name.strip_edges()
	)

	if safe_source_name.is_empty():
		safe_source_name = "UnknownCompanion"

	_increment_total_and_room(
		"companion_damage_dealt",
		actual_amount
	)

	_increment_total_and_room(
		"companion_hits",
		1
	)

	if killed_by_companion:
		_increment_total_and_room(
			"companion_kills",
			1
		)

	var target_name: String = (
		_get_node_type_name(
			target
		)
	)

	_increment_dictionary_counter(
		totals,
		"companion_damage_by_source",
		safe_source_name,
		actual_amount
	)

	_increment_dictionary_counter(
		current_room_data,
		"companion_damage_by_source",
		safe_source_name,
		actual_amount
	)

	_increment_dictionary_counter(
		totals,
		"companion_damage_by_target",
		target_name,
		actual_amount
	)

	_increment_dictionary_counter(
		current_room_data,
		"companion_damage_by_target",
		target_name,
		actual_amount
	)
# =========================================================
# ПОЛУЧЕННЫЙ УРОН
# =========================================================

func record_damage_taken(
	amount: int
) -> void:
	var actual_amount: int = maxi(
		amount,
		0
	)

	if actual_amount <= 0:
		return

	_increment_total_and_room(
		"damage_taken",
		actual_amount
	)

	var context: Dictionary = (
		_infer_damage_context_from_stack()
	)

	var attacker_type: String = str(
		context.get(
			"attacker_type",
			"Unknown"
		)
	)

	var attack_type: String = str(
		context.get(
			"attack_type",
			"unknown"
		)
	)

	_increment_dictionary_counter(
		totals,
		"damage_by_source",
		attacker_type,
		actual_amount
	)

	_increment_dictionary_counter(
		totals,
		"damage_by_attack_type",
		attack_type,
		actual_amount
	)

	_increment_dictionary_counter(
		current_room_data,
		"damage_by_source",
		attacker_type,
		actual_amount
	)

	_increment_dictionary_counter(
		current_room_data,
		"damage_by_attack_type",
		attack_type,
		actual_amount
	)

	var hp_before: int = (
		GameManager.player_hp
	)

	var hp_after: int = maxi(
		hp_before - actual_amount,
		0
	)

	var damage_event: Dictionary = {
		"time_seconds": (
			_seconds_since(
				floor_started_msec
			)
		),

		"run_time_seconds": (
			_get_total_run_duration()
		),

		"floor_number": floor_number,

		"room_index": (
			GameManager.current_room_index
		),

		"room_name": str(
			current_room_data.get(
				"room_name",
				""
			)
		),

		"attacker_type": attacker_type,
		"attack_type": attack_type,

		"source_path": str(
			context.get(
				"source_path",
				""
			)
		),

		"source_function": str(
			context.get(
				"source_function",
				""
			)
		),

		"damage": actual_amount,

		"hp_before": hp_before,
		"hp_after": hp_after
	}

	damage_events.append(
		damage_event.duplicate(
			true
		)
	)

	if not current_room_data.is_empty():
		var room_damage_events: Array = (
			current_room_data.get(
				"damage_events",
				[]
			)
		)

		room_damage_events.append(
			damage_event.duplicate(
				true
			)
		)

		current_room_data["damage_events"] = (
			room_damage_events
		)

		current_room_data["hp_end"] = (
			hp_after
		)


func _infer_damage_context_from_stack() -> Dictionary:
	var stack: Array = get_stack()

	for frame_variant in stack:
		if not (
			frame_variant is Dictionary
		):
			continue

		var frame: Dictionary = (
			frame_variant
		)

		var source_path: String = str(
			frame.get(
				"source",
				""
			)
		)

		if source_path.is_empty():
			continue

		if source_path.ends_with(
			"BalanceTelemetry.gd"
		):
			continue

		if source_path.ends_with(
			"Player.gd"
		):
			continue

		var is_combat_source: bool = (
			source_path.contains(
				"/Enemies/"
			)
			or source_path.contains(
				"/Projectiles/"
			)
			or source_path.contains(
				"/Effects/"
			)
		)

		if not is_combat_source:
			continue

		var source_function: String = str(
			frame.get(
				"function",
				""
			)
		)

		return {
			"attacker_type": (
				_normalize_attacker_type(
					source_path
				)
			),

			"attack_type": (
				_classify_attack_type(
					source_path,
					source_function
				)
			),

			"source_path": source_path,
			"source_function": source_function
		}

	return {
		"attacker_type": "Unknown",
		"attack_type": "unknown",
		"source_path": "",
		"source_function": ""
	}


func _normalize_attacker_type(
	source_path: String
) -> String:
	var file_name: String = (
		source_path
		.get_file()
		.get_basename()
	)

	match file_name:
		"Corn_bullet":
			return "Enemy_corn"

	return file_name


func _classify_attack_type(
	source_path: String,
	source_function: String
) -> String:
	var combined: String = (
		source_path
		+ " "
		+ source_function
	).to_lower()

	if (
		combined.contains("poison")
		or combined.contains("cloud")
	):
		return "poison"

	if (
		combined.contains("explode")
		or combined.contains("explosion")
		or combined.contains("enemy_egg")
	):
		return "explosion"

	if (
		combined.contains("bullet")
		or combined.contains("projectile")
		or combined.contains("ranged")
		or combined.contains("shoot")
	):
		return "projectile"

	if (
		combined.contains("dash")
		or combined.contains("flight")
	):
		return "dash"

	if (
		combined.contains("melee")
		or combined.contains("attack_timer")
		or combined.contains("attack_area")
	):
		return "melee"

	return "contact"


# =========================================================
# ЛЕЧЕНИЕ
# =========================================================

func record_healing(
	amount: int
) -> void:
	_increment_total_and_room(
		"healing_received",
		maxi(
			amount,
			0
		)
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
		int(
			totals.get(
				key,
				0
			)
		)
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

		"floor_number": floor_number,

		"room_index": (
			GameManager.current_room_index
		),

		"time_seconds": (
			_seconds_since(
				floor_started_msec
			)
		),

		"run_time_seconds": (
			_get_total_run_duration()
		)
	})


# =========================================================
# ИЗМЕНЕНИЯ ХАРАКТЕРИСТИК
# =========================================================

func _on_stats_changed(
	_stats: Variant
) -> void:
	var current_snapshot: Dictionary = (
		_get_stats_snapshot()
	)

	if current_snapshot.is_empty():
		return

	if current_snapshot == last_stats_snapshot:
		return

	var event_kind: String = (
		"stats_changed"
	)

	if last_stats_snapshot.is_empty():
		event_kind = "initial_stats"

	stat_changes.append({
		"kind": event_kind,

		"time_seconds": (
			_seconds_since(
				floor_started_msec
			)
		),

		"run_time_seconds": (
			_get_total_run_duration()
		),

		"floor_number": floor_number,

		"room_index": (
			GameManager.current_room_index
		),

		"before": (
			last_stats_snapshot.duplicate(
				true
			)
		),

		"after": (
			current_snapshot.duplicate(
				true
			)
		),

		"delta": (
			_calculate_stats_delta(
				last_stats_snapshot,
				current_snapshot
			)
		)
	})

	last_stats_snapshot = (
		current_snapshot.duplicate(
			true
		)
	)


func _on_passive_upgrades_changed(
	entries: Array
) -> void:
	passive_upgrade_events.append({
		"time_seconds": (
			_seconds_since(
				floor_started_msec
			)
		),

		"run_time_seconds": (
			_get_total_run_duration()
		),

		"floor_number": floor_number,

		"room_index": (
			GameManager.current_room_index
		),

		"entries": (
			_make_json_safe(
				entries
			)
		)
	})


func _calculate_stats_delta(
	before: Dictionary,
	after: Dictionary
) -> Dictionary:
	var delta: Dictionary = {}

	for key_variant in after.keys():
		var key: String = str(
			key_variant
		)

		var after_value: Variant = (
			after[key_variant]
		)

		if not before.has(
			key_variant
		):
			delta[key] = {
				"before": null,
				"after": after_value
			}

			continue

		var before_value: Variant = (
			before[key_variant]
		)

		if before_value == after_value:
			continue

		var before_is_number: bool = (
			typeof(before_value) == TYPE_INT
			or typeof(before_value) == TYPE_FLOAT
		)

		var after_is_number: bool = (
			typeof(after_value) == TYPE_INT
			or typeof(after_value) == TYPE_FLOAT
		)

		if (
			before_is_number
			and after_is_number
		):
			delta[key] = snappedf(
				float(after_value)
				- float(before_value),
				0.001
			)

		else:
			delta[key] = {
				"before": before_value,
				"after": after_value
			}

	return delta


# =========================================================
# ЗАВЕРШЕНИЕ КОМНАТЫ
# =========================================================

func _finalize_current_room(
	reason: String
) -> void:
	if current_room_data.is_empty():
		return

	# Проверяем реальное количество врагов,
	# а не только последнее значение сигнала.
	var live_count: int = (
		_count_live_enemies_in_tracked_room()
	)

	current_room_data["last_enemy_count"] = (
		live_count
	)

	_mark_room_cleared_if_needed(
		live_count,
		false
	)

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
		_print_current_room_summary(
			reason
		)

	finished_room_visits.append(
		current_room_data.duplicate(
			true
		)
	)

	current_room_data.clear()

	_disconnect_registered_enemies()


# =========================================================
# ЗАВЕРШЕНИЕ ЭТАЖА
# =========================================================

func _on_game_over(
	victory: bool
) -> void:
	if report_saved:
		return

	var status: String = (
		"victory"
		if victory
		else "defeat"
	)

	_finalize_current_room(
		status
	)

	report_saved = true

	var final_snapshot: Dictionary = (
		_get_stats_snapshot()
	)

	if save_automatically:
		_save_report(
			status
		)

	# Сохраняем характеристики для отчёта
	# следующего этажа.
	previous_floor_final_stats = (
		final_snapshot.duplicate(
			true
		)
	)


# =========================================================
# СОХРАНЕНИЕ ОТЧЁТА
# =========================================================

func _save_report(
	status: String
) -> void:
	var rooms_for_report: Array[Dictionary] = (
		finished_room_visits.duplicate(
			true
		)
	)

	if not current_room_data.is_empty():
		var current_snapshot: Dictionary = (
			current_room_data.duplicate(
				true
			)
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

		current_snapshot["last_enemy_count"] = (
			_count_live_enemies_in_tracked_room()
		)

		_add_accuracy_to_dictionary(
			current_snapshot
		)

		rooms_for_report.append(
			current_snapshot
		)

	var totals_snapshot: Dictionary = (
		totals.duplicate(
			true
		)
	)

	_add_accuracy_to_dictionary(
		totals_snapshot
	)

	var report: Dictionary = {
		"version": 4,

		"saved_at": (
			Time.get_datetime_string_from_system()
		),

		"status": status,

		"run_id": run_id,
		"floor_number": floor_number,

		"started_as_new_run": (
			started_as_new_run
		),

		"previous_floor_final_stats": (
			previous_floor_stats_snapshot
		),

		"run_duration_seconds": (
			_get_total_run_duration()
		),

		"floor_duration_seconds": (
			_seconds_since(
				floor_started_msec
			)
		),

		"initial_stats": (
			_get_initial_stats_for_report()
		),

		"final_hp": GameManager.player_hp,

		"final_max_hp": (
			GameManager.player_max_hp
		),

		"final_stats": (
			_get_stats_snapshot()
		),

		"run_gold": GameManager.run_gold,
		"keys": GameManager.keys,

		"totals": totals_snapshot,

		"damage_events": damage_events,
		"acquired_items": acquired_items,
		"stat_changes": stat_changes,

		"passive_upgrade_events": (
			passive_upgrade_events
		),

		"room_visits": rooms_for_report
	}

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

	var short_run_id: String = run_id

	if short_run_id.length() > 8:
		short_run_id = short_run_id.substr(
			short_run_id.length() - 8
		)

	var file_path: String = (
		"user://balance_logs/balance_"
		+ timestamp
		+ "_run-"
		+ short_run_id
		+ "_floor-"
		+ str(floor_number)
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
			_make_json_safe(
				report
			),
			"\t"
		)
	)

	file.close()

	print(
		"[BALANCE] Отчёт сохранён: ",
		file_path
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
# НАЗВАНИЯ КОМНАТ И УЗЛОВ
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

	return String(
		node.name
	)


# =========================================================
# ХАРАКТЕРИСТИКИ
# =========================================================

func _get_stats_snapshot() -> Dictionary:
	var stats: Variant = (
		GameManager.player_stats
	)

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


func _get_initial_stats_for_report() -> Dictionary:
	if not finished_room_visits.is_empty():
		var first_stats: Variant = (
			finished_room_visits[0].get(
				"stats_at_entry",
				{}
			)
		)

		if first_stats is Dictionary:
			var first_dictionary: Dictionary = (
				first_stats
			)

			return first_dictionary.duplicate(
				true
			)

	if not current_room_data.is_empty():
		var current_stats: Variant = (
			current_room_data.get(
				"stats_at_entry",
				{}
			)
		)

		if current_stats is Dictionary:
			var current_dictionary: Dictionary = (
				current_stats
			)

			return current_dictionary.duplicate(
				true
			)

	return last_stats_snapshot.duplicate(
		true
	)


# =========================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# =========================================================

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
		data.get(
			"shots",
			0
		)
	)

	var hits: int = int(
		data.get(
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

	data["accuracy_percent"] = (
		snappedf(
			accuracy,
			0.1
		)
	)


# =========================================================
# ПРЕОБРАЗОВАНИЕ В JSON
# =========================================================

func _make_json_safe(
	value: Variant
) -> Variant:
	match typeof(value):
		TYPE_NIL:
			return null

		TYPE_BOOL:
			return value

		TYPE_INT:
			return value

		TYPE_FLOAT:
			return value

		TYPE_STRING:
			return value

		TYPE_STRING_NAME:
			return String(value)

		TYPE_ARRAY:
			var safe_array: Array = []

			for item in value:
				safe_array.append(
					_make_json_safe(
						item
					)
				)

			return safe_array

		TYPE_DICTIONARY:
			var safe_dictionary: Dictionary = {}

			for key_variant in value.keys():
				safe_dictionary[
					str(key_variant)
				] = _make_json_safe(
					value[key_variant]
				)

			return safe_dictionary

		TYPE_OBJECT:
			if value is Resource:
				var resource := value as Resource

				if not resource.resource_path.is_empty():
					return resource.resource_path

				return str(resource)

			if value is Node:
				return _get_node_type_name(
					value as Node
				)

			return str(value)

		_:
			return str(value)


# =========================================================
# ВЫВОД ПО КОМНАТЕ
# =========================================================

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

	var direct_damage_dealt: int = int(
		current_room_data.get(
			"direct_damage_dealt",
			0
		)
	)

	var poison_damage_dealt: int = int(
		current_room_data.get(
			"poison_damage_dealt",
			0
		)
	)

	var companion_damage_dealt: int = int(
		current_room_data.get(
			"companion_damage_dealt",
			0
		)
	)

	var total_damage_dealt: int = (
		direct_damage_dealt
		+ poison_damage_dealt
		+ companion_damage_dealt
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

		"\n  enemies initial/peak/live=",
		current_room_data.get(
			"initial_enemy_count",
			0
		),
		"/",
		current_room_data.get(
			"peak_enemy_count",
			0
		),
		"/",
		current_room_data.get(
			"last_enemy_count",
			0
		),

		"\n  shots/hits=",
		shots,
		"/",
		hits,
		" | accuracy=",
		snappedf(
			accuracy,
			0.1
		),
		"%",

		"\n  damage dealt/taken=",
		total_damage_dealt,
		"/",
		current_room_data.get(
			"damage_taken",
			0
		),

		"\n  damage sources=",
		current_room_data.get(
			"damage_by_source",
			{}
		),
		
		"\n  damage direct/poison/companions=",
		direct_damage_dealt,
		"/",
		poison_damage_dealt,
		"/",
		companion_damage_dealt,

		"\n  hp=",
		current_room_data.get(
			"hp_start",
			0
		),
		" → ",
		GameManager.player_hp
	)

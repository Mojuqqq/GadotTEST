extends BaseBoss


# =========================================================
# СОСТОЯНИЯ БОССА
# =========================================================

enum State {
	CHASE,
	PREPARE,
	ASCENDING,
	AIR_TRACKING,
	AIR_LOCKED,
	DESCENDING,
	RECOVERY
}


# =========================================================
# ОСНОВНЫЕ ПАРАМЕТРЫ
# =========================================================

@export_group("Boss")

@export_range(1, 200, 1)
var boss_max_hp: int = 35

@export_range(10.0, 500.0, 5.0)
var movement_speed: float = 70.0

@export_range(10.0, 300.0, 5.0)
var stop_distance: float = 90.0


# =========================================================
# ПРЫЖОК БОССА
# =========================================================

@export_group("Boss Jump")

@export_range(0.1, 30.0, 0.1)
var first_jump_delay: float = 2.5

@export_range(1.0, 30.0, 0.1)
var jump_cooldown: float = 4.5

@export_range(0.05, 3.0, 0.05)
var prepare_duration: float = 0.5

@export_range(0.05, 3.0, 0.05)
var ascend_duration: float = 0.45

@export_range(100.0, 2000.0, 20.0)
var jump_height: float = 900.0

@export_range(0.1, 10.0, 0.1)
var air_tracking_duration: float = 1.2

@export_range(0.1, 3.0, 0.05)
var landing_warning_duration: float = 0.55

@export_range(0.05, 3.0, 0.05)
var descend_duration: float = 0.35

@export_range(0.05, 5.0, 0.05)
var recovery_duration: float = 0.75


# =========================================================
# УРОН БОССА ПРИ ПАДЕНИИ
# =========================================================

@export_group("Boss Landing Attack")

@export_range(1, 20, 1)
var landing_damage: int = 3

@export_range(20.0, 500.0, 5.0)
var landing_radius: float = 130.0


# =========================================================
# ДОЖДЬ ИЗ МИНИ-ОМЛЕТОВ
# =========================================================

@export_group("Mini Omelet Rain")

# Сюда в Inspector назначается сцена мини-омлета.
@export var mini_omelet_scene: PackedScene

# Количество мини-омлетов в одной волне.
@export_range(1, 50, 1)
var rain_omelet_count: int = 20

# Через сколько секунд после перехода во вторую фазу
# начинается первый дождь.
@export_range(0.1, 20.0, 0.1)
var first_rain_delay: float = 0.5

# Период между волнами дождя.
@export_range(1.0, 30.0, 0.1)
var rain_interval: float = 5.0

# Интервал появления отдельных мини-омлетов внутри волны.
@export_range(0.01, 1.0, 0.01)
var rain_spawn_step: float = 0.1

# Отступ от стен комнаты.
@export_range(20.0, 300.0, 5.0)
var rain_wall_margin: float = 50.0

# Желательная дистанция между точками падения.
@export_range(0.0, 300.0, 5.0)
var rain_min_spacing: float = 50.0


# =========================================================
# СОСТОЯНИЕ БОССА
# =========================================================

var current_state: int = State.CHASE
var current_target: Node2D = null

var state_elapsed: float = 0.0
var jump_timer: float = 0.0

var landing_position: Vector2 = Vector2.ZERO
var is_airborne: bool = false

var base_visual_position: Vector2 = Vector2.ZERO
var base_visual_scale: Vector2 = Vector2.ONE
var base_marker_scale: Vector2 = Vector2.ONE


# =========================================================
# СОСТОЯНИЕ ДОЖДЯ
# =========================================================

var rain_phase_active: bool = false
var rain_wave_active: bool = false

var rain_cooldown_left: float = 0.0
var rain_spawn_left: float = 0.0
var rain_spawned_in_wave: int = 0

var rain_wave_positions: Array[Vector2] = []
var active_mini_omelets: Array[Node] = []


# =========================================================
# УЗЛЫ СЦЕНЫ
# =========================================================

@onready var visual: Node2D = (
	get_node_or_null("Sprite2D") as Node2D
)

@onready var body_collision: CollisionShape2D = (
	get_node_or_null("CollisionShape2D")
	as CollisionShape2D
)

@onready var landing_marker: Node2D = (
	get_node_or_null("LandingMarker") as Node2D
)


# =========================================================
# ИНИЦИАЛИЗАЦИЯ
# =========================================================

func _ready() -> void:
	hp = boss_max_hp
	max_hp = boss_max_hp

	super()

	add_to_group("Enemies")

	if visual != null:
		base_visual_position = visual.position
		base_visual_scale = visual.scale

	if landing_marker != null:
		landing_marker.top_level = true
		landing_marker.visible = false

		base_marker_scale = landing_marker.scale

	if hp_bar != null:
		hp_bar.size = Vector2(150.0, 20.0)
		hp_bar.position = Vector2(-75.0, -90.0)

		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = Color(0.8, 0.1, 0.1)

		hp_bar.add_theme_stylebox_override(
			"fill",
			fill_style
		)

	_reset_jump_state()

	print("Босс Омлет создан.")


# =========================================================
# АКТИВАЦИЯ КОМНАТЫ
# =========================================================

func set_active(
	active: bool
) -> void:
	if not active:
		_reset_jump_state()
		_stop_rain_runtime(true)

	super(active)

	if active:
		current_state = State.CHASE
		current_target = _find_player()
		jump_timer = first_jump_delay

		if rain_phase_active:
			rain_cooldown_left = first_rain_delay
	else:
		current_target = null
		velocity = Vector2.ZERO


# =========================================================
# ОСНОВНОЙ ЦИКЛ
# =========================================================

func _physics_process(
	delta: float
) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	if not is_active:
		velocity = Vector2.ZERO
		return

	current_target = _find_player()

	_process_rain(delta)

	match current_state:
		State.CHASE:
			_process_chase(delta)

		State.PREPARE:
			_process_prepare(delta)

		State.ASCENDING:
			_process_ascending(delta)

		State.AIR_TRACKING:
			_process_air_tracking(delta)

		State.AIR_LOCKED:
			_process_air_locked(delta)

		State.DESCENDING:
			_process_descending(delta)

		State.RECOVERY:
			_process_recovery(delta)


# =========================================================
# ПРЕСЛЕДОВАНИЕ
# =========================================================

func _process_chase(
	delta: float
) -> void:
	if not _is_valid_target(current_target):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var distance: float = global_position.distance_to(
		current_target.global_position
	)

	if distance > stop_distance:
		var direction: Vector2 = (
			current_target.global_position
			- global_position
		).normalized()

		velocity = direction * movement_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_clamp_to_room()

	jump_timer -= delta

	if jump_timer <= 0.0:
		_begin_prepare()


# =========================================================
# ПОДГОТОВКА К ПРЫЖКУ
# =========================================================

func _begin_prepare() -> void:
	if not _is_valid_target(current_target):
		jump_timer = 0.5
		return

	current_state = State.PREPARE
	state_elapsed = 0.0
	velocity = Vector2.ZERO


func _process_prepare(
	delta: float
) -> void:
	velocity = Vector2.ZERO
	state_elapsed += delta

	var progress: float = clampf(
		state_elapsed / maxf(prepare_duration, 0.01),
		0.0,
		1.0
	)

	if visual != null:
		visual.scale = Vector2(
			base_visual_scale.x * lerpf(
				1.0,
				1.2,
				progress
			),
			base_visual_scale.y * lerpf(
				1.0,
				0.75,
				progress
			)
		)

	if progress >= 1.0:
		_begin_ascending()


# =========================================================
# ПОДЪЁМ
# =========================================================

func _begin_ascending() -> void:
	current_state = State.ASCENDING
	state_elapsed = 0.0

	is_airborne = true
	velocity = Vector2.ZERO

	_set_body_collision_enabled(false)

	if hp_bar != null:
		hp_bar.visible = false


func _process_ascending(
	delta: float
) -> void:
	state_elapsed += delta

	var progress: float = clampf(
		state_elapsed / maxf(ascend_duration, 0.01),
		0.0,
		1.0
	)

	var eased_progress: float = (
		1.0
		- pow(
			1.0 - progress,
			2.0
		)
	)

	if visual != null:
		visual.scale = base_visual_scale

		visual.position = (
			base_visual_position
			+ Vector2(
				0.0,
				-jump_height * eased_progress
			)
		)

	if progress < 1.0:
		return

	if visual != null:
		visual.visible = false

	current_state = State.AIR_TRACKING
	state_elapsed = 0.0

	_update_landing_position()


# =========================================================
# ОТСЛЕЖИВАНИЕ ИГРОКА
# =========================================================

func _process_air_tracking(
	delta: float
) -> void:
	state_elapsed += delta

	_update_landing_position()

	if state_elapsed >= air_tracking_duration:
		_lock_landing_position()


func _update_landing_position() -> void:
	if not _is_valid_target(current_target):
		return

	landing_position = _clamp_position_to_room(
		current_target.global_position
	)


# =========================================================
# ФИКСАЦИЯ ТОЧКИ ПАДЕНИЯ
# =========================================================

func _lock_landing_position() -> void:
	_update_landing_position()

	current_state = State.AIR_LOCKED
	state_elapsed = 0.0

	_show_landing_marker()


func _process_air_locked(
	delta: float
) -> void:
	state_elapsed += delta

	_update_marker_pulse()

	if state_elapsed >= landing_warning_duration:
		_begin_descending()


# =========================================================
# ПАДЕНИЕ
# =========================================================

func _begin_descending() -> void:
	current_state = State.DESCENDING
	state_elapsed = 0.0

	global_position = landing_position
	velocity = Vector2.ZERO

	if visual != null:
		visual.visible = true
		visual.scale = base_visual_scale

		visual.position = (
			base_visual_position
			+ Vector2(
				0.0,
				-jump_height
			)
		)


func _process_descending(
	delta: float
) -> void:
	state_elapsed += delta

	var progress: float = clampf(
		state_elapsed / maxf(descend_duration, 0.01),
		0.0,
		1.0
	)

	var eased_progress: float = progress * progress

	if visual != null:
		visual.position = (
			base_visual_position
			+ Vector2(
				0.0,
				-jump_height
				* (1.0 - eased_progress)
			)
		)

	if progress >= 1.0:
		_land()


# =========================================================
# ПРИЗЕМЛЕНИЕ
# =========================================================

func _land() -> void:
	if visual != null:
		visual.position = base_visual_position

		visual.scale = Vector2(
			base_visual_scale.x * 1.25,
			base_visual_scale.y * 0.75
		)

	_hide_landing_marker()
	_set_body_collision_enabled(true)

	is_airborne = false

	_deal_landing_damage()

	current_state = State.RECOVERY
	state_elapsed = 0.0

	if hp_bar != null:
		hp_bar.visible = is_active


func _deal_landing_damage() -> void:
	_deal_area_damage(
		global_position,
		landing_radius,
		landing_damage
	)


# =========================================================
# ВОССТАНОВЛЕНИЕ
# =========================================================

func _process_recovery(
	delta: float
) -> void:
	velocity = Vector2.ZERO
	state_elapsed += delta

	var progress: float = clampf(
		state_elapsed / maxf(recovery_duration, 0.01),
		0.0,
		1.0
	)

	if visual != null:
		visual.scale = Vector2(
			base_visual_scale.x * lerpf(
				1.25,
				1.0,
				progress
			),
			base_visual_scale.y * lerpf(
				0.75,
				1.0,
				progress
			)
		)

	if progress < 1.0:
		return

	if visual != null:
		visual.scale = base_visual_scale

	current_state = State.CHASE
	state_elapsed = 0.0
	jump_timer = jump_cooldown


# =========================================================
# ВТОРАЯ ФАЗА
# =========================================================

func take_damage(
	amount: int
) -> void:
	if is_airborne:
		return

	super(amount)

	if is_dead:
		return

	_try_activate_rain_phase()


func _try_activate_rain_phase() -> void:
	if rain_phase_active:
		return

	if float(hp) > float(max_hp) * 0.5:
		return

	rain_phase_active = true
	rain_cooldown_left = first_rain_delay

	print(
		"Омлет перешёл во вторую фазу. "
		+ "Начинается дождь из мини-омлетов."
	)


# =========================================================
# УПРАВЛЕНИЕ ДОЖДЁМ
# =========================================================

func _process_rain(
	delta: float
) -> void:
	if not rain_phase_active:
		return

	_cleanup_active_mini_omelets()

	if rain_wave_active:
		rain_spawn_left -= delta

		while (
			rain_spawn_left <= 0.0
			and rain_spawned_in_wave < rain_omelet_count
		):
			_spawn_one_mini_omelet()

			rain_spawned_in_wave += 1

			rain_spawn_left += maxf(
				rain_spawn_step,
				0.01
			)

		if rain_spawned_in_wave >= rain_omelet_count:
			rain_wave_active = false
			rain_cooldown_left = rain_interval

			rain_wave_positions.clear()

		return

	rain_cooldown_left -= delta

	if rain_cooldown_left <= 0.0:
		_start_rain_wave()


func _start_rain_wave() -> void:
	if mini_omelet_scene == null:
		push_warning(
			"У Омлета не назначена сцена мини-омлета."
		)

		rain_cooldown_left = rain_interval
		return

	rain_wave_active = true
	rain_spawned_in_wave = 0
	rain_spawn_left = 0.0

	rain_wave_positions.clear()

	print(
		"Начинается дождь из ",
		rain_omelet_count,
		" мини-омлетов."
	)


func _spawn_one_mini_omelet() -> void:
	var room_node := get_parent() as Node2D

	if room_node == null:
		push_warning(
			"Омлет не находится внутри комнаты."
		)
		return

	var mini_instance: Node = (
		mini_omelet_scene.instantiate()
	)

	var mini := mini_instance as Node2D

	if mini == null:
		if mini_instance != null:
			mini_instance.queue_free()

		push_warning(
			"Корень сцены мини-омлета должен быть Node2D."
		)
		return

	var spawn_position: Vector2 = (
		_get_random_rain_position()
	)

	rain_wave_positions.append(
		spawn_position
	)

	# Позиция назначается до add_child,
	# чтобы объект не появился сначала в точке 0, 0.
	mini.position = room_node.to_local(
		spawn_position
	)

	room_node.add_child(mini)

	active_mini_omelets.append(mini)

	if mini.has_signal("finished"):
		var callback := Callable(
			self,
			"_on_mini_omelet_finished"
		)

		if not mini.is_connected(
			"finished",
			callback
		):
			mini.connect(
				"finished",
				callback
			)


func _get_random_rain_position() -> Vector2:
	if room_limits == Rect2():
		return (
			global_position
			+ Vector2(
				randf_range(-350.0, 350.0),
				randf_range(-250.0, 250.0)
			)
		)

	var minimum_x: float = (
		room_limits.position.x
		+ rain_wall_margin
	)

	var maximum_x: float = (
		room_limits.end.x
		- rain_wall_margin
	)

	var minimum_y: float = (
		room_limits.position.y
		+ rain_wall_margin
	)

	var maximum_y: float = (
		room_limits.end.y
		- rain_wall_margin
	)

	if (
		minimum_x >= maximum_x
		or minimum_y >= maximum_y
	):
		return room_limits.get_center()

	var last_candidate := room_limits.get_center()

	for _attempt in range(25):
		var candidate := Vector2(
			randf_range(
				minimum_x,
				maximum_x
			),
			randf_range(
				minimum_y,
				maximum_y
			)
		)

		last_candidate = candidate

		var position_is_free: bool = true

		for existing_position in rain_wave_positions:
			if (
				candidate.distance_to(
					existing_position
				)
				< rain_min_spacing
			):
				position_is_free = false
				break

		if position_is_free:
			return candidate

	return last_candidate


func _on_mini_omelet_finished(
	mini: Node
) -> void:
	active_mini_omelets.erase(mini)


func _cleanup_active_mini_omelets() -> void:
	for index in range(
		active_mini_omelets.size() - 1,
		-1,
		-1
	):
		var mini: Node = active_mini_omelets[index]

		if not is_instance_valid(mini):
			active_mini_omelets.remove_at(index)
			continue

		if mini.is_queued_for_deletion():
			active_mini_omelets.remove_at(index)


func _stop_rain_runtime(
	clear_existing: bool
) -> void:
	rain_wave_active = false
	rain_spawned_in_wave = 0
	rain_spawn_left = 0.0

	rain_wave_positions.clear()

	if rain_phase_active:
		rain_cooldown_left = first_rain_delay
	else:
		rain_cooldown_left = 0.0

	if clear_existing:
		_clear_active_mini_omelets()


func _clear_active_mini_omelets() -> void:
	for mini in active_mini_omelets:
		if not is_instance_valid(mini):
			continue

		if mini.is_queued_for_deletion():
			continue

		mini.queue_free()

	active_mini_omelets.clear()


# =========================================================
# ОБЩИЙ УРОН ПО ОБЛАСТИ
# =========================================================

func _deal_area_damage(
	center: Vector2,
	radius: float,
	damage: int
) -> void:
	var target_groups: Array[StringName] = [
		&"Player",
		&"Companions"
	]

	var damaged_targets: Array[Node] = []

	for group_name in target_groups:
		for candidate in get_tree().get_nodes_in_group(
			group_name
		):
			if not is_instance_valid(candidate):
				continue

			if candidate.is_queued_for_deletion():
				continue

			if not candidate.has_method("take_damage"):
				continue

			var target := candidate as Node2D

			if target == null:
				continue

			if damaged_targets.has(target):
				continue

			if (
				center.distance_to(
					target.global_position
				)
				> radius
			):
				continue

			damaged_targets.append(target)

			target.take_damage(damage)


# =========================================================
# МАРКЕР ПАДЕНИЯ БОССА
# =========================================================

func _show_landing_marker() -> void:
	if landing_marker == null:
		return

	landing_marker.global_position = landing_position
	landing_marker.scale = base_marker_scale
	landing_marker.visible = true


func _hide_landing_marker() -> void:
	if landing_marker == null:
		return

	landing_marker.visible = false
	landing_marker.scale = base_marker_scale


func _update_marker_pulse() -> void:
	if landing_marker == null:
		return

	var pulse: float = (
		1.0
		+ sin(
			state_elapsed * TAU * 3.0
		) * 0.08
	)

	landing_marker.scale = (
		base_marker_scale * pulse
	)


# =========================================================
# ПОИСК ИГРОКА
# =========================================================

func _find_player() -> Node2D:
	for candidate in get_tree().get_nodes_in_group(
		"Player"
	):
		if not _is_valid_target(candidate):
			continue

		return candidate as Node2D

	return null


func _is_valid_target(
	target: Node
) -> bool:
	if not is_instance_valid(target):
		return false

	if target.is_queued_for_deletion():
		return false

	if not target.has_method("take_damage"):
		return false

	return target.is_in_group("Player")


# =========================================================
# ГРАНИЦЫ КОМНАТЫ
# =========================================================

func _clamp_to_room() -> void:
	global_position = _clamp_position_to_room(
		global_position
	)


func _clamp_position_to_room(
	target_position: Vector2
) -> Vector2:
	if room_limits == Rect2():
		return target_position

	var margin: float = maxf(
		landing_radius,
		50.0
	)

	var minimum_x: float = (
		room_limits.position.x + margin
	)

	var maximum_x: float = (
		room_limits.end.x - margin
	)

	var minimum_y: float = (
		room_limits.position.y + margin
	)

	var maximum_y: float = (
		room_limits.end.y - margin
	)

	if (
		minimum_x >= maximum_x
		or minimum_y >= maximum_y
	):
		return room_limits.get_center()

	return Vector2(
		clampf(
			target_position.x,
			minimum_x,
			maximum_x
		),
		clampf(
			target_position.y,
			minimum_y,
			maximum_y
		)
	)


# =========================================================
# КОЛЛИЗИЯ
# =========================================================

func _set_body_collision_enabled(
	enabled: bool
) -> void:
	if body_collision == null:
		return

	body_collision.set_deferred(
		"disabled",
		not enabled
	)


# =========================================================
# СБРОС
# =========================================================

func _reset_jump_state() -> void:
	current_state = State.CHASE

	state_elapsed = 0.0
	jump_timer = first_jump_delay

	is_airborne = false
	velocity = Vector2.ZERO

	if visual != null:
		visual.visible = true
		visual.position = base_visual_position
		visual.scale = base_visual_scale

	_set_body_collision_enabled(true)
	_hide_landing_marker()


# =========================================================
# СМЕРТЬ
# =========================================================

func die() -> void:
	_hide_landing_marker()
	_stop_rain_runtime(true)

	super()

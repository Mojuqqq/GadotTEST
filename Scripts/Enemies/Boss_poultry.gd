extends BaseBoss

# =========================================================
# СОСТОЯНИЯ ДВИЖЕНИЯ
# =========================================================

enum MovementState {
	CHASE,
	TAKEOFF,
	FLYING,
	LANDING
}


# =========================================================
# ОСНОВНЫЕ ПАРАМЕТРЫ
# =========================================================

@export_group("Boss")

@export_range(1, 200, 1)
var boss_max_hp: int = 30

# Рост максимального здоровья за каждый
# этаж после первого.
@export_range(0.0, 1.0, 0.05)
var boss_hp_growth_per_floor: float = 0.25

@export_range(10.0, 500.0, 5.0)
var speed: float = 95.0

# На каком расстоянии босс прекращает обычное движение,
# чтобы не пытаться постоянно залезть внутрь игрока.
@export_range(10.0, 200.0, 5.0)
var stop_distance: float = 65.0


@onready var sprite: Sprite2D = $Sprite2D
@onready var flight_sprite: Sprite2D = $FlightSprite

# =========================================================
# БЛИЖНЯЯ АТАКА
# =========================================================

@export_group("Melee Attack")

@export_range(10.0, 400.0, 5.0)
var melee_range: float = 115.0

@export_range(1, 20, 1)
var melee_damage: int = 3

@export_range(0.1, 10.0, 0.1)
var melee_cooldown: float = 1.0


# =========================================================
# ПРИЗЫВ КУРИЦ
# =========================================================

@export_group("Chicken Summon")

@export var chicken_scene: PackedScene = preload(
	"res://Scenes/Enemies/Enemy_chicken.tscn"
)

# Через сколько секунд происходит первая волна.
@export_range(0.1, 30.0, 0.1)
var first_summon_delay: float = 2.5

# Интервал между волнами.
@export_range(1.0, 30.0, 0.5)
var summon_interval: float = 2.0

# Сколько куриц появляется за одну волну.
@export_range(1, 10, 1)
var chickens_per_summon: int = 1

# Максимальное количество одновременно живых
# куриц, призванных этим боссом.
@export_range(1, 20, 1)
var max_alive_chickens: int = 5

@export_range(30.0, 300.0, 5.0)
var summon_radius: float = 110.0


# =========================================================
# ПОЛЁТ-РЫВОК
# =========================================================

@export_group("Flight Dash")

# Задержка до первого полёта.
@export_range(0.1, 30.0, 0.1)
var first_flight_delay: float = 3.0

# Как часто курица пытается совершить полёт.
@export_range(1.0, 20.0, 0.5)
var flight_interval: float = 3

# Максимальная скорость во время полёта.
@export_range(100.0, 1200.0, 10.0)
var flight_speed: float = 550.0

# Расстояние одного полёта.
@export_range(50.0, 800.0, 10.0)
var flight_distance: float = 260.0

# Дополнительное расстояние после позиции цели,
# чтобы курица пролетала через неё, а не
# останавливалась перед ней.
@export_range(0.0, 300.0, 10.0)
var flight_overshoot_distance: float = 120.0

# Максимальная фактическая длина рывка.
@export_range(100.0, 900.0, 10.0)
var flight_max_distance: float = 520.0

# Урон при пересечении игрока рывком.
@export_range(1, 20, 1)
var flight_damage: int = 2

# Допустимое расстояние между игроком
# и траекторией полёта.
@export_range(20.0, 200.0, 5.0)
var flight_hit_radius: float = 105.0

# Время разгона до максимальной скорости.
@export_range(0.05, 2.0, 0.05)
var flight_acceleration_time: float = 0.25

# Подготовка перед рывком.
@export_range(0.05, 2.0, 0.05)
var takeoff_duration: float = 0.25

# Задержка после приземления.
@export_range(0.05, 2.0, 0.05)
var landing_duration: float = 0.2

# Страховка на случай, если босс упрётся в стену.
@export_range(0.2, 5.0, 0.1)
var flight_max_duration: float = 1.2

# Насколько спрайт визуально поднимается над землёй.
@export_range(0.0, 100.0, 2.0)
var flight_visual_height: float = 34.0


# =========================================================
# СОСТОЯНИЕ
# =========================================================

var current_target: Node2D = null

var movement_state: int = MovementState.CHASE
var state_elapsed: float = 0.0

var flight_direction: Vector2 = Vector2.ZERO
var flight_travelled: float = 0.0
var flight_elapsed: float = 0.0
var active_flight_distance: float = 0.0

# За один рывок одна цель может получить
# урон только один раз.
var flight_damage_dealt: bool = false

var attack_timer: Timer = null
var summon_timer: Timer = null
var flight_timer: Timer = null

var summoned_chickens: Array[Node2D] = []

var base_sprite_position: Vector2 = Vector2.ZERO
var base_sprite_z_index: int = 0




# =========================================================
# ИНИЦИАЛИЗАЦИЯ
# =========================================================

func _ready() -> void:
	var floor_number: int = maxi(
		GameManager.current_floor,
		1
	)

	var floor_multiplier: float = (
		1.0
		+ boss_hp_growth_per_floor
		* float(floor_number - 1)
	)

	var scaled_boss_hp: int = ceili(
		float(
			maxi(
				boss_max_hp,
				1
			)
		)
		* floor_multiplier
	)

	max_hp = scaled_boss_hp
	hp = scaled_boss_hp

	print(
		"[BOSS POULTRY] floor=",
		floor_number,
		" | base_hp=",
		boss_max_hp,
		" | multiplier=",
		floor_multiplier,
		" | hp=",
		scaled_boss_hp
	)

	super()

	add_to_group("Enemies")

	if sprite != null:
		base_sprite_position = sprite.position
		base_sprite_z_index = sprite.z_index

	if hp_bar != null:
		hp_bar.size = Vector2(150.0, 20.0)
		hp_bar.position = Vector2(-75.0, -100.0)

		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = Color(0.8, 0.1, 0.1)

		hp_bar.add_theme_stylebox_override(
			"fill",
			fill_style
		)

	attack_timer = _create_timer(
		"MeleeAttackTimer",
		_on_attack_timer_timeout
	)

	summon_timer = _create_timer(
		"ChickenSummonTimer",
		_on_summon_timer_timeout
	)

	flight_timer = _create_timer(
		"FlightTimer",
		_on_flight_timer_timeout
	)



func _create_timer(
	timer_name: String,
	callback: Callable
) -> Timer:
	var timer := Timer.new()

	timer.name = timer_name
	timer.one_shot = true

	timer.timeout.connect(callback)

	add_child(timer)

	return timer


# =========================================================
# АКТИВАЦИЯ КОМНАТЫ
# =========================================================

func set_active(
	active: bool
) -> void:
	super(active)

	if (
		attack_timer == null
		or summon_timer == null
		or flight_timer == null
	):
		return

	if active:
		current_target = _find_nearest_target()

		attack_timer.start(0.4)
		summon_timer.start(first_summon_delay)
		flight_timer.start(first_flight_delay)
	else:
		attack_timer.stop()
		summon_timer.stop()
		flight_timer.stop()

		current_target = null
		velocity = Vector2.ZERO

		_reset_movement_state()


# =========================================================
# ДВИЖЕНИЕ
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

	current_target = _find_nearest_target()

	if not _is_valid_target(current_target):
		current_target = null
		velocity = Vector2.ZERO

		_reset_movement_state()
		move_and_slide()

		return

	match movement_state:
		MovementState.CHASE:
			_process_chase()

		MovementState.TAKEOFF:
			_process_takeoff(delta)

		MovementState.FLYING:
			_process_flight(delta)

		MovementState.LANDING:
			_process_landing(delta)


func _process_chase() -> void:
	var distance: float = global_position.distance_to(
		current_target.global_position
	)

	if distance > stop_distance:
		var direction: Vector2 = (
			current_target.global_position
			- global_position
		).normalized()

		velocity = direction * speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_clamp_to_room()

func _set_flight_visual(active: bool) -> void:
	if sprite == null or flight_sprite == null:
		return

	if active:
		flight_sprite.flip_h = sprite.flip_h

	sprite.visible = not active
	flight_sprite.visible = active

func _sync_flight_facing() -> void:
	if sprite == null or flight_sprite == null:
		return

	flight_sprite.flip_h = sprite.flip_h


func _process_takeoff(
	delta: float
) -> void:
	_set_flight_visual(true)
	velocity = Vector2.ZERO
	state_elapsed += delta

	var progress: float = clampf(
		state_elapsed
		/ maxf(
			takeoff_duration,
			0.01
		),
		0.0,
		1.0
	)

	_set_sprite_height(
		flight_visual_height * progress
	)

	if progress < 1.0:
		return

	current_target = _find_nearest_target()

	if not _is_valid_target(current_target):
		_reset_movement_state()
		_set_flight_visual(false)
		return

	var target_offset: Vector2 = (
		current_target.global_position
		- global_position
	)

	if target_offset == Vector2.ZERO:
		_reset_movement_state()
		return

	# Направление фиксируется только после
	# завершения подготовки к рывку.
	flight_direction = target_offset.normalized()

	# Курица пролетает немного дальше
	# текущей позиции игрока.
	active_flight_distance = clampf(
		target_offset.length()
		+ flight_overshoot_distance,
		flight_distance,
		flight_max_distance
	)

	flight_damage_dealt = false

	movement_state = MovementState.FLYING
	
	AudioManager.play_world_sfx(
		&"whoosh_heavy",
		global_position,
		-13.0,
		0.78,
		0.88
	)

	state_elapsed = 0.0
	flight_elapsed = 0.0
	flight_travelled = 0.0


func _process_flight(
	delta: float
) -> void:
	flight_elapsed += delta

	var acceleration_progress: float = clampf(
		flight_elapsed
		/ maxf(flight_acceleration_time, 0.01),
		0.0,
		1.0
	)

	var current_speed: float = lerpf(
		speed,
		flight_speed,
		acceleration_progress
	)

	var previous_position: Vector2 = global_position

	velocity = flight_direction * current_speed
	_sync_flight_facing()

	move_and_slide()
	_clamp_to_room()

	_try_deal_flight_damage(
		previous_position,
		global_position
	)

	flight_travelled += previous_position.distance_to(
		global_position
	)

	_set_sprite_height(flight_visual_height)

	if (
		flight_travelled
		>= active_flight_distance
		or flight_elapsed
		>= flight_max_duration
	):
		_begin_landing()

func _try_deal_flight_damage(
	from_position: Vector2,
	to_position: Vector2
) -> void:
	if flight_damage_dealt:
		return

	var player := (
		get_tree().get_first_node_in_group(
			&"Player"
		) as Node2D
	)

	if not _is_valid_target(player):
		return

	if not player.has_method(
		&"take_damage"
	):
		return

	var closest_point: Vector2 = (
		Geometry2D.get_closest_point_to_segment(
			player.global_position,
			from_position,
			to_position
		)
	)

	var distance_to_flight_path: float = (
		player.global_position.distance_to(
			closest_point
		)
	)

	if (
		distance_to_flight_path
		> flight_hit_radius
	):
		return

	player.call(
		&"take_damage",
		maxi(
			flight_damage,
			1
		)
	)

	flight_damage_dealt = true

func _process_landing(
	delta: float
) -> void:
	velocity = Vector2.ZERO
	state_elapsed += delta

	var progress: float = clampf(
		state_elapsed / maxf(landing_duration, 0.01),
		0.0,
		1.0
	)

	_set_sprite_height(
		flight_visual_height * (1.0 - progress)
	)

	if progress < 1.0:
		return

	AudioManager.play_world_sfx(
		&"impact_heavy",
		global_position,
		-12.0,
		0.88,
		0.96
	)

	_reset_movement_state()


func _start_flight() -> void:
	if movement_state != MovementState.CHASE:
		return

	if not _is_valid_target(current_target):
		return

	# Направление пока не фиксируем.
	# Игрок ещё может двигаться во время подготовки.
	flight_direction = Vector2.ZERO
	active_flight_distance = 0.0
	flight_damage_dealt = false

	movement_state = MovementState.TAKEOFF
	state_elapsed = 0.0

	velocity = Vector2.ZERO
	
	AudioManager.play_sfx(
		&"boss_telegraph",
		-11.0
	)

	AudioManager.play_world_sfx(
		&"bird_flap",
		global_position,
		-12.0,
		0.72,
		0.84
	)



func _begin_landing() -> void:
	movement_state = MovementState.LANDING
	state_elapsed = 0.0

	velocity = Vector2.ZERO


func _reset_movement_state() -> void:
	movement_state = MovementState.CHASE

	_set_flight_visual(false)

	state_elapsed = 0.0
	flight_elapsed = 0.0
	flight_travelled = 0.0

	flight_direction = Vector2.ZERO
	active_flight_distance = 0.0
	flight_damage_dealt = false

	_set_sprite_height(0.0)


func _set_sprite_height(
	height: float
) -> void:
	if sprite == null:
		return

	sprite.position = (
		base_sprite_position
		+ Vector2(
			0.0,
			-height
		)
	)

	if height > 0.0:
		sprite.z_index = base_sprite_z_index + 1
	else:
		sprite.z_index = base_sprite_z_index


func _clamp_to_room() -> void:
	if room_limits == Rect2():
		return

	var margin: float = 25.0

	global_position.x = clampf(
		global_position.x,
		room_limits.position.x + margin,
		room_limits.end.x - margin
	)

	global_position.y = clampf(
		global_position.y,
		room_limits.position.y + margin,
		room_limits.end.y - margin
	)


# =========================================================
# БЛИЖНЯЯ АТАКА
# =========================================================

func _on_attack_timer_timeout() -> void:
	if not is_active or is_dead:
		return

	AudioManager.play_world_sfx(
		&"bird_flap",
		global_position,
		-16.0,
		0.78,
		0.90
	)

	current_target = _find_nearest_target()

	if not _is_valid_target(current_target):
		attack_timer.start(0.25)
		return

	var distance: float = global_position.distance_to(
		current_target.global_position
	)

	if distance <= melee_range:
		current_target.take_damage(melee_damage)


	attack_timer.start(melee_cooldown)


# =========================================================
# ПОЛЁТ ПО ТАЙМЕРУ
# =========================================================

func _on_flight_timer_timeout() -> void:
	if not is_active or is_dead:
		return

	current_target = _find_nearest_target()

	if (
		movement_state == MovementState.CHASE
		and _is_valid_target(current_target)
	):
		_start_flight()

	flight_timer.start(flight_interval)


# =========================================================
# ПРИЗЫВ ENEMY_CHICKEN
# =========================================================

func _on_summon_timer_timeout() -> void:
	if not is_active or is_dead:
		return

	_summon_chickens()

	summon_timer.start(summon_interval)


func _summon_chickens() -> void:
	if chicken_scene == null:
		push_warning(
			"У босса-курицы не назначена сцена Enemy_chicken."
		)
		return

	# Удаляем из массива недействительные ссылки.
	_cleanup_summoned_chickens()

	var alive_chickens: int = (
		summoned_chickens.size()
	)

	# Определяем, сколько свободных мест осталось.
	var available_slots: int = maxi(
		max_alive_chickens - alive_chickens,
		0
	)

	# За одну волну создаём не больше chickens_per_summon,
	# но никогда не превышаем лимит живых куриц.
	var spawn_count: int = mini(
		chickens_per_summon,
		available_slots
	)

	if spawn_count <= 0:
		return

	var room_node := get_parent() as Node2D

	if room_node == null:
		push_warning(
			"Босс-курица не находится внутри комнаты."
		)
		return

	AudioManager.play_world_sfx(
		&"chicken_alarm",
		global_position,
		-13.0,
		0.72,
		0.82
	)

	AudioManager.play_world_sfx(
		&"companion_spawn",
		global_position,
		-17.0,
		0.88,
		0.96
	)

	for index in range(spawn_count):
		var chicken_instance: Node = (
			chicken_scene.instantiate()
		)

		var chicken := chicken_instance as Node2D

		if chicken == null:
			if chicken_instance != null:
				chicken_instance.queue_free()

			push_warning(
				"Корень Enemy_chicken должен быть Node2D."
			)
			continue

		var base_angle: float = (
			TAU
			* float(index)
			/ float(maxi(spawn_count, 1))
		)

		var angle: float = (
			base_angle
			+ randf_range(-0.35, 0.35)
		)

		var distance: float = randf_range(
			summon_radius * 0.65,
			summon_radius
		)

		var spawn_global_position: Vector2 = (
			global_position
			+ Vector2.RIGHT.rotated(angle)
			* distance
		)

		spawn_global_position = _clamp_spawn_position(
			spawn_global_position
		)

		# Позиция назначается до добавления в дерево,
		# чтобы курица не появилась сначала в точке 0, 0.
		chicken.position = room_node.to_local(
			spawn_global_position
		)

		room_node.add_child(chicken)

		if chicken.has_method("set_room_limits"):
			chicken.call(
				"set_room_limits",
				room_limits
			)

		if chicken.has_method("set_active"):
			chicken.call(
				"set_active",
				is_active
			)

		# Сохраняем только призванных этим боссом куриц.
		summoned_chickens.append(chicken)

		# Сразу узнаём о смерти курицы и освобождаем
		# место для следующей волны призыва.
		if chicken.has_signal("died"):
			var death_callback := Callable(
				self,
				"_on_summoned_chicken_died"
			)

			if not chicken.is_connected(
				"died",
				death_callback
			):
				chicken.connect(
					"died",
					death_callback
				)

	# Обновляем список комнаты, чтобы новые курицы
	# учитывались при подсчёте оставшихся врагов.
	if room_node.has_method("update_enemies_list"):
		room_node.call_deferred(
			"update_enemies_list"
		)
	else:
		push_warning(
			"У родительской комнаты отсутствует "
			+ "update_enemies_list()."
		)

func _on_summoned_chicken_died(
	victim: Node
) -> void:
	var chicken := victim as Node2D

	if chicken == null:
		return

	summoned_chickens.erase(chicken)

func _cleanup_summoned_chickens() -> void:
	for index in range(
		summoned_chickens.size() - 1,
		-1,
		-1
	):
		var chicken: Node2D = (
			summoned_chickens[index]
		)

		if not is_instance_valid(chicken):
			summoned_chickens.remove_at(index)
			continue

		if chicken.is_queued_for_deletion():
			summoned_chickens.remove_at(index)

func _clamp_spawn_position(
	spawn_position: Vector2
) -> Vector2:
	if room_limits == Rect2():
		return spawn_position

	var margin: float = 50.0

	return Vector2(
		clampf(
			spawn_position.x,
			room_limits.position.x + margin,
			room_limits.end.x - margin
		),
		clampf(
			spawn_position.y,
			room_limits.position.y + margin,
			room_limits.end.y - margin
		)
	)


# =========================================================
# ПОИСК ЦЕЛИ
# =========================================================

func _find_nearest_target() -> Node2D:
	# Основная цель босса — игрок.
	var player := (
		get_tree().get_first_node_in_group(
			&"Player"
		) as Node2D
	)

	if _is_valid_target(player):
		return player

	# Компаньон используется только тогда,
	# когда игрок временно недоступен.
	var nearest_companion: Node2D = null
	var nearest_distance_squared: float = INF

	for candidate in get_tree().get_nodes_in_group(
		&"Companions"
	):
		if not _is_valid_target(candidate):
			continue

		var companion := candidate as Node2D

		if companion == null:
			continue

		var distance_squared: float = (
			global_position.distance_squared_to(
				companion.global_position
			)
		)

		if (
			distance_squared
			>= nearest_distance_squared
		):
			continue

		nearest_distance_squared = distance_squared
		nearest_companion = companion

	return nearest_companion


func _is_valid_target(
	target: Node
) -> bool:
	if not is_instance_valid(target):
		return false

	if target.is_queued_for_deletion():
		return false

	return is_player_side_target(target)

func die() -> void:
	if is_dead:
		return

	AudioManager.play_world_sfx(
		&"chicken_death",
		global_position,
		-8.0,
		0.68,
		0.78
	)

	AudioManager.play_world_sfx(
		&"body_fall_heavy",
		global_position,
		-9.0,
		0.92,
		1.0
	)

	super()

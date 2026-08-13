extends BaseBoss


# =========================================================
# СОСТОЯНИЯ БОССА
# =========================================================

enum BullState {
	CHASE,
	CHARGE_PREPARE,
	CHARGING,
	PINNING,
	RETREAT,
	WAIT_PLAYER_RECOVERY,
	WALL_STUN
}


# =========================================================
# ОСНОВНЫЕ ПАРАМЕТРЫ
# =========================================================

@export_group("Boss")

@export_range(1, 300, 1)
var boss_max_hp: int = 45

@export_range(0.0, 1.0, 0.05)
var boss_hp_growth_per_floor: float = 0.25

@export_range(10.0, 500.0, 5.0)
var movement_speed: float = 130.0

@export_range(10.0, 300.0, 5.0)
var stop_distance: float = 90.0


# =========================================================
# БЛИЖНЯЯ АТАКА
# =========================================================

@export_group("Melee Attack")

@export_range(20.0, 400.0, 5.0)
var melee_range: float = 115.0

@export_range(1, 20, 1)
var melee_damage: int = 1

@export_range(0.1, 10.0, 0.1)
var melee_cooldown: float = 1.0


# =========================================================
# ТАРАН
# =========================================================

@export_group("Charge")

@export_range(0.1, 30.0, 0.1)
var first_charge_delay: float = 3.0

@export_range(1.0, 30.0, 0.1)
var charge_cooldown: float = 5

@export_range(0.1, 3.0, 0.05)
var charge_prepare_duration: float = 1

@export_range(100.0, 1500.0, 10.0)
var charge_speed: float = 760.0

@export_range(0.2, 5.0, 0.1)
var charge_max_duration: float = 1.8

@export_range(0.0, 600.0, 10.0)
var minimum_charge_distance: float = 170.0

@export_range(1, 20, 1)
var charge_damage: int = 4

# Расстояние, на котором игрок удерживается
# перед Быком во время тарана.
@export_range(10.0, 200.0, 5.0)
var captured_target_offset: float = 75.0

# Смещение зоны захвата вперёд от центра Быка.
@export_range(0.0, 200.0, 5.0)
var charge_hitbox_forward_offset: float = 55.0


# =========================================================
# ПРИКОВЫВАНИЕ ИГРОКА
# =========================================================

@export_group("Pin Player")

# Полное время оглушения игрока.
@export_range(0.1, 5.0, 0.1)
var pin_duration: float = 3

# Сколько Бык задерживается возле стены,
# прежде чем начать отход.
@export_range(0.0, 1.0, 0.01)
var retreat_after_pin_delay: float = 0.1


# =========================================================
# ОТХОД ПОСЛЕ ЗАХВАТА
# =========================================================

@export_group("Retreat")

@export_range(20.0, 700.0, 10.0)
var retreat_speed: float = 240.0

@export_range(20.0, 600.0, 10.0)
var retreat_distance: float = 200.0

# Случайный угол отхода относительно направления,
# противоположного тарану.
@export_range(0.0, 170.0, 5.0)
var retreat_random_angle_degrees: float = 75.0

# =========================================================
# БЛУЖДАНИЕ, ПОКА ИГРОК ОГЛУШЁН
# =========================================================

@export_group("Recovery Wander")

# Скорость спокойного блуждания.
@export_range(10.0, 500.0, 5.0)
var recovery_wander_speed: float = 110.0

# Насколько близко Бык должен подойти
# к выбранной случайной точке.
@export_range(5.0, 100.0, 5.0)
var recovery_wander_reach_distance: float = 25.0

# Бык старается не выбирать точку рядом
# с прикованным игроком.
@export_range(0.0, 600.0, 10.0)
var recovery_wander_min_player_distance: float = 220.0

# Через какое время выбирается новая точка,
# даже если старая ещё не достигнута.
@export_range(0.2, 5.0, 0.1)
var recovery_wander_retarget_interval: float = 1.0


# =========================================================
# ПРОМАХ
# =========================================================

@export_group("Missed Charge")

# Оглушение Быка применяется только тогда,
# когда он не захватил игрока и врезался в стену.
@export_range(0.0, 5.0, 0.05)
var missed_charge_stun_duration: float = 0.1


# =========================================================
# ГРАНИЦЫ КОМНАТЫ
# =========================================================

@export_group("Room")

@export_range(10.0, 200.0, 5.0)
var room_edge_margin: float = 65.0


# =========================================================
# ТЕКУЩЕЕ СОСТОЯНИЕ
# =========================================================

var current_state: int = BullState.CHASE

var current_target: Node2D = null
var captured_target: Node2D = null

var state_elapsed: float = 0.0

var melee_cooldown_left: float = 0.0
var charge_cooldown_left: float = 0.0

var charge_direction: Vector2 = Vector2.ZERO


# =========================================================
# ОГЛУШЕНИЕ ИГРОКА
# =========================================================

var target_is_pinned: bool = false

var pinned_target_time_left: float = 0.0

var pinned_position: Vector2 = Vector2.ZERO


# =========================================================
# ОТХОД
# =========================================================

var retreat_direction: Vector2 = Vector2.ZERO
var retreat_travelled: float = 0.0

var recovery_wander_target: Vector2 = Vector2.ZERO
var recovery_wander_retarget_left: float = 0.0


# =========================================================
# ВИЗУАЛ
# =========================================================

var visual: Node2D = null

var visual_base_scale: Vector2 = Vector2.ONE


# =========================================================
# УЗЛЫ СЦЕНЫ
# =========================================================

@onready var charge_hitbox: Area2D = (
	get_node_or_null("ChargeHitbox")
	as Area2D
)


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

	var scaled_hp: int = ceili(
		float(
			maxi(
				boss_max_hp,
				1
			)
		)
		* floor_multiplier
	)

	max_hp = scaled_hp
	hp = scaled_hp

	super()

	visual = (
		get_node_or_null("AnimatedSprite2D")
		as Node2D
	)

	if visual == null:
		visual = (
			get_node_or_null("Sprite2D")
			as Node2D
		)

	if visual != null:
		visual_base_scale = visual.scale

	if hp_bar != null:
		hp_bar.size = Vector2(
			170.0,
			20.0
		)

		hp_bar.position = Vector2(
			-85.0,
			-115.0
		)

		var fill_style := StyleBoxFlat.new()

		fill_style.bg_color = Color(
			0.8,
			0.1,
			0.1
		)

		hp_bar.add_theme_stylebox_override(
			"fill",
			fill_style
		)

	if charge_hitbox == null:
		push_error(
			"Boss_bull: отсутствует узел ChargeHitbox."
		)
	else:
		if not charge_hitbox.body_entered.is_connected(
			_on_charge_hitbox_body_entered
		):
			charge_hitbox.body_entered.connect(
				_on_charge_hitbox_body_entered
			)

	_set_charge_hitbox_enabled(false)

	charge_cooldown_left = first_charge_delay
	melee_cooldown_left = 0.3

	print(
		"[BOSS BULL] floor=",
		floor_number,
		" | hp=",
		scaled_hp
	)


# =========================================================
# АКТИВАЦИЯ КОМНАТЫ
# =========================================================

func set_active(
	active: bool
) -> void:
	if not active:
		_release_captured_target()

	super(active)

	_set_charge_hitbox_enabled(false)

	if active:
		current_target = _find_player()

		current_state = BullState.CHASE
		state_elapsed = 0.0

		charge_cooldown_left = first_charge_delay
		melee_cooldown_left = 0.3
	else:
		current_target = null
		velocity = Vector2.ZERO

		_reset_special_attack()


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

	# Оглушение игрока работает независимо
	# от движения Быка.
	_process_pinned_target(delta)

	melee_cooldown_left = maxf(
		melee_cooldown_left - delta,
		0.0
	)

	if (
		current_state != BullState.PINNING
		and not target_is_pinned
	):
		current_target = _find_player()

	match current_state:
		BullState.CHASE:
			_process_chase(delta)

		BullState.CHARGE_PREPARE:
			_process_charge_prepare(delta)

		BullState.CHARGING:
			_process_charging(delta)

		BullState.PINNING:
			_process_pinning(delta)

		BullState.RETREAT:
			_process_retreat(delta)

		BullState.WAIT_PLAYER_RECOVERY:
			_process_wait_player_recovery(delta)

		BullState.WALL_STUN:
			_process_wall_stun(delta)


# =========================================================
# ПРЕСЛЕДОВАНИЕ
# =========================================================

func _process_chase(
	delta: float
) -> void:
	# Бык не может начать преследование,
	# пока игрок оглушён после тарана.
	if target_is_pinned:
		_begin_wait_player_recovery()
		return

	if not _is_valid_player(current_target):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var distance: float = (
		global_position.distance_to(
			current_target.global_position
		)
	)

	var direction: Vector2 = (
		current_target.global_position
		- global_position
	).normalized()

	if distance > stop_distance:
		velocity = (
			direction
			* movement_speed
		)
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_clamp_to_room()

	if (
		distance <= melee_range
		and melee_cooldown_left <= 0.0
	):
		_deal_melee_damage()

	charge_cooldown_left -= delta

	if charge_cooldown_left > 0.0:
		return

	if distance < minimum_charge_distance:
		charge_cooldown_left = 0.4
		return

	_begin_charge_prepare()


func _deal_melee_damage() -> void:
	if not _is_valid_player(current_target):
		return

	current_target.call(
		&"take_damage",
		melee_damage
	)

	melee_cooldown_left = melee_cooldown

	print(
		"Бык ударил игрока. Урон: ",
		melee_damage
	)


# =========================================================
# ПОДГОТОВКА К ТАРАНУ
# =========================================================

func _begin_charge_prepare() -> void:
	if target_is_pinned:
		_begin_wait_player_recovery()
		return

	if not _is_valid_player(current_target):
		charge_cooldown_left = 0.5
		return

	current_state = BullState.CHARGE_PREPARE
	state_elapsed = 0.0

	charge_direction = Vector2.ZERO
	velocity = Vector2.ZERO
	
	AudioManager.play_sfx(
		&"boss_telegraph",
		-9.0
	)

	AudioManager.play_world_sfx(
		&"bull_snort_01",
		global_position,
		-10.0,
		0.88,
		0.96
	)

	if randf() <= 0.25:
		AudioManager.play_world_sfx(
			&"bull_ring_jingle",
			global_position,
			-22.0,
			0.96,
			1.03
		)

	print("Бык готовится к тарану.")


func _process_charge_prepare(
	delta: float
) -> void:
	velocity = Vector2.ZERO
	state_elapsed += delta

	if target_is_pinned:
		_begin_wait_player_recovery()
		return

	if not _is_valid_player(current_target):
		_finish_special_attack()
		return

	var progress: float = clampf(
		state_elapsed
		/ maxf(
			charge_prepare_duration,
			0.01
		),
		0.0,
		1.0
	)

	if visual != null:
		var pulse: float = (
			1.0
			+ sin(
				progress
				* TAU
				* 3.0
			)
			* 0.025
		)

		visual.scale = Vector2(
			visual_base_scale.x
			* 1.08
			* pulse,
			visual_base_scale.y
			* 0.9
		)

	if progress < 1.0:
		return

	var target_offset: Vector2 = (
		current_target.global_position
		- global_position
	)

	if target_offset == Vector2.ZERO:
		_finish_special_attack()
		return

	# Направление фиксируется только после
	# завершения подготовки.
	charge_direction = target_offset.normalized()

	_begin_charging()


# =========================================================
# НАЧАЛО ТАРАНА
# =========================================================

func _begin_charging() -> void:
	current_state = BullState.CHARGING
	state_elapsed = 0.0
	
	AudioManager.play_world_sfx(
		&"bull_bellow",
		global_position,
		-9.0,
		0.86,
		0.94
	)

	AudioManager.play_world_sfx(
		&"bull_stomp",
		global_position,
		-14.0,
		0.86,
		0.94
	)

	captured_target = null

	if visual != null:
		visual.scale = visual_base_scale

	if charge_hitbox != null:
		charge_hitbox.position = (
			charge_direction
			* charge_hitbox_forward_offset
		)

		charge_hitbox.rotation = (
			charge_direction.angle()
		)

	_set_charge_hitbox_enabled(true)

	print(
		"Бык начинает таран. Направление: ",
		charge_direction
	)


# =========================================================
# ДВИЖЕНИЕ ВО ВРЕМЯ ТАРАНА
# =========================================================

func _process_charging(
	delta: float
) -> void:
	state_elapsed += delta

	_try_capture_overlapping_player()

	var motion: Vector2 = (
		charge_direction
		* charge_speed
		* delta
	)

	velocity = (
		charge_direction
		* charge_speed
	)

	var collision := move_and_collide(
		motion
	)

	_try_capture_overlapping_player()

	_move_captured_target_with_bull()

	var reached_room_edge: bool = (
		_is_at_room_edge()
	)

	if reached_room_edge:
		_clamp_to_room()
		_move_captured_target_with_bull()

	if (
		collision != null
		or reached_room_edge
	):
		if _is_valid_player(captured_target):
			_begin_pinning()
		else:
			_begin_wall_stun()

		return

	if state_elapsed < charge_max_duration:
		return

	# Страховка на случай, если стены комнаты
	# не имеют физической коллизии.
	if _is_valid_player(captured_target):
		_begin_pinning()
	else:
		_begin_wall_stun()


# =========================================================
# ОБНАРУЖЕНИЕ И ЗАХВАТ ИГРОКА
# =========================================================

func _on_charge_hitbox_body_entered(
	body: Node
) -> void:
	_try_capture_target(body)


func _try_capture_overlapping_player() -> void:
	if charge_hitbox == null:
		return

	if captured_target != null:
		return

	for body in charge_hitbox.get_overlapping_bodies():
		_try_capture_target(body)

		if captured_target != null:
			return


func _try_capture_target(
	body: Node
) -> void:
	if current_state != BullState.CHARGING:
		return

	if captured_target != null:
		return

	if not _is_valid_player(body):
		return

	if not body.has_method(
		&"set_external_movement_lock"
	):
		push_error(
			"Player.gd не содержит "
			+ "set_external_movement_lock()."
		)
		return

	if not body.has_method(
		&"force_external_position"
	):
		push_error(
			"Player.gd не содержит "
			+ "force_external_position()."
		)
		return

	captured_target = body as Node2D

	captured_target.call(
		&"set_external_movement_lock",
		self,
		true
	)

	captured_target.call(
		&"take_damage",
		charge_damage
	)
	
	AudioManager.play_world_sfx(
		&"impact_heavy",
		global_position,
		-7.0,
		0.88,
		0.96
	)

	if not _is_valid_player(captured_target):
		_release_captured_target()
		return

	_move_captured_target_with_bull()

	print(
		"Бык захватил игрока. Урон: ",
		charge_damage
	)


# =========================================================
# ПЕРЕМЕЩЕНИЕ ЗАХВАЧЕННОГО ИГРОКА
# =========================================================

func _move_captured_target_with_bull() -> void:
	if not _is_valid_player(captured_target):
		if captured_target != null:
			_release_captured_target()

		return

	var target_position: Vector2 = (
		global_position
		+ charge_direction
		* captured_target_offset
	)

	captured_target.call(
		&"force_external_position",
		self,
		target_position
	)


# =========================================================
# ПРИКОВЫВАНИЕ К СТЕНЕ
# =========================================================

func _begin_pinning() -> void:
	if not _is_valid_player(captured_target):
		_begin_wall_stun()
		return

	current_state = BullState.PINNING
	state_elapsed = 0.0

	velocity = Vector2.ZERO

	_set_charge_hitbox_enabled(false)

	pinned_position = (
		captured_target.global_position
	)

	pinned_target_time_left = pin_duration
	target_is_pinned = true

	captured_target.call(
		&"force_external_position",
		self,
		pinned_position
	)

	print(
		"Игрок прижат к стене на ",
		pin_duration,
		" сек."
	)


func _process_pinning(
	delta: float
) -> void:
	velocity = Vector2.ZERO
	state_elapsed += delta

	if not _is_valid_player(captured_target):
		_release_captured_target()
		_begin_retreat()
		return

	# Бык задерживается у стены совсем недолго.
	if state_elapsed < retreat_after_pin_delay:
		return

	# Игрок остаётся оглушённым, а Бык
	# уже начинает движение от стены.
	_begin_retreat()


# =========================================================
# НЕЗАВИСИМЫЙ ТАЙМЕР ОГЛУШЕНИЯ ИГРОКА
# =========================================================

func _process_pinned_target(
	delta: float
) -> void:
	if not target_is_pinned:
		return

	if not _is_valid_player(captured_target):
		_release_captured_target()
		return

	captured_target.call(
		&"force_external_position",
		self,
		pinned_position
	)

	pinned_target_time_left -= delta

	if pinned_target_time_left > 0.0:
		return

	print("Игрок освобождён после тарана.")

	_release_captured_target()


# =========================================================
# НАЧАЛО ОТХОДА
# =========================================================

func _begin_retreat() -> void:
	current_state = BullState.RETREAT
	state_elapsed = 0.0

	retreat_travelled = 0.0

	retreat_direction = (
		_choose_retreat_direction()
	)

	if visual != null:
		visual.scale = visual_base_scale

	print(
		"Бык отходит после захвата. Направление: ",
		retreat_direction
	)


# =========================================================
# ДВИЖЕНИЕ ОТ СТЕНЫ
# =========================================================

func _process_retreat(
	delta: float
) -> void:
	var previous_position: Vector2 = (
		global_position
	)

	velocity = (
		retreat_direction
		* retreat_speed
	)

	var collision := move_and_collide(
		velocity * delta
	)

	retreat_travelled += (
		previous_position.distance_to(
			global_position
		)
	)

	_clamp_to_room()

	if (
		collision == null
		and retreat_travelled < retreat_distance
	):
		return

	velocity = Vector2.ZERO

	# После отхода Бык не возвращается
	# к преследованию, пока игрок оглушён.
	if target_is_pinned:
		_begin_wait_player_recovery()
		return

	_finish_special_attack()


# =========================================================
# СЛУЧАЙНОЕ НАПРАВЛЕНИЕ ОТХОДА
# =========================================================

func _choose_retreat_direction() -> Vector2:
	var away_from_wall: Vector2 = (
		-charge_direction
	)

	if away_from_wall == Vector2.ZERO:
		away_from_wall = Vector2.RIGHT.rotated(
			randf_range(
				0.0,
				TAU
			)
		)

	var maximum_angle: float = deg_to_rad(
		retreat_random_angle_degrees
	)

	for _attempt in range(12):
		var candidate: Vector2 = (
			away_from_wall.rotated(
				randf_range(
					-maximum_angle,
					maximum_angle
				)
			).normalized()
		)

		var destination: Vector2 = (
			global_position
			+ candidate
			* retreat_distance
		)

		if _is_position_inside_room(
			destination
		):
			return candidate

	return away_from_wall.normalized()


# =========================================================
# БЛУЖДАНИЕ ДО ОСВОБОЖДЕНИЯ ИГРОКА
# =========================================================

func _begin_wait_player_recovery() -> void:
	current_state = BullState.WAIT_PLAYER_RECOVERY
	state_elapsed = 0.0

	velocity = Vector2.ZERO

	recovery_wander_retarget_left = 0.0
	_choose_recovery_wander_target()

	if visual != null:
		visual.scale = visual_base_scale

	print(
		"Бык бродит по комнате, "
		+ "пока игрок остаётся оглушённым."
	)


func _process_wait_player_recovery(
	delta: float
) -> void:
	# Игрок освободился — возвращаемся
	# к обычному поведению.
	if not target_is_pinned:
		_finish_special_attack()
		return

	recovery_wander_retarget_left -= delta

	var target_offset: Vector2 = (
		recovery_wander_target
		- global_position
	)

	var reached_target: bool = (
		target_offset.length()
		<= recovery_wander_reach_distance
	)

	if (
		reached_target
		or recovery_wander_retarget_left <= 0.0
	):
		_choose_recovery_wander_target()

		target_offset = (
			recovery_wander_target
			- global_position
		)

	if target_offset.length_squared() <= 1.0:
		velocity = Vector2.ZERO
		return

	var wander_direction: Vector2 = (
		target_offset.normalized()
	)

	velocity = (
		wander_direction
		* recovery_wander_speed
	)

	var collision := move_and_collide(
		velocity * delta
	)

	_clamp_to_room()

	# Если Бык наткнулся на стену или другой
	# физический объект, сразу ищем новую точку.
	if collision != null:
		velocity = Vector2.ZERO
		_choose_recovery_wander_target()

func _choose_recovery_wander_target() -> void:
	recovery_wander_retarget_left = (
		recovery_wander_retarget_interval
	)

	# Запасной вариант, если границы комнаты
	# ещё не были переданы боссу.
	if room_limits == Rect2():
		var random_direction: Vector2 = (
			Vector2.RIGHT.rotated(
				randf_range(
					0.0,
					TAU
				)
			)
		)

		recovery_wander_target = (
			global_position
			+ random_direction
			* randf_range(
				100.0,
				250.0
			)
		)

		return

	var minimum_x: float = (
		room_limits.position.x
		+ room_edge_margin
	)

	var maximum_x: float = (
		room_limits.end.x
		- room_edge_margin
	)

	var minimum_y: float = (
		room_limits.position.y
		+ room_edge_margin
	)

	var maximum_y: float = (
		room_limits.end.y
		- room_edge_margin
	)

	if (
		minimum_x >= maximum_x
		or minimum_y >= maximum_y
	):
		recovery_wander_target = (
			room_limits.get_center()
		)

		return

	var best_candidate: Vector2 = (
		room_limits.get_center()
	)

	var best_distance_from_player: float = -1.0

	# Пытаемся найти случайную точку,
	# расположенную не слишком близко к игроку.
	for _attempt in range(20):
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

		var distance_from_player: float = (
			candidate.distance_to(
				pinned_position
			)
		)

		if (
			distance_from_player
			> best_distance_from_player
		):
			best_candidate = candidate
			best_distance_from_player = (
				distance_from_player
			)

		if (
			distance_from_player
			>= recovery_wander_min_player_distance
		):
			recovery_wander_target = candidate
			return

	# Если подходящую точку найти не удалось,
	# используем самую удалённую из проверенных.
	recovery_wander_target = best_candidate

# =========================================================
# ОГЛУШЕНИЕ ПОСЛЕ ПРОМАХА
# =========================================================

func _begin_wall_stun() -> void:
	_release_captured_target()
	_set_charge_hitbox_enabled(false)

	current_state = BullState.WALL_STUN
	state_elapsed = 0.0

	velocity = Vector2.ZERO
	
	AudioManager.play_world_sfx(
		&"impact_heavy",
		global_position,
		-6.0,
		0.82,
		0.92
	)

	AudioManager.play_world_sfx(
		&"shockwave",
		global_position,
		-13.0,
		0.88,
		0.96
	)

	if visual != null:
		visual.scale = Vector2(
			visual_base_scale.x * 1.08,
			visual_base_scale.y * 0.9
		)

	print(
		"Бык промахнулся и оглушён на ",
		missed_charge_stun_duration,
		" сек."
	)


func _process_wall_stun(
	delta: float
) -> void:
	velocity = Vector2.ZERO
	state_elapsed += delta

	if state_elapsed < missed_charge_stun_duration:
		return

	_finish_special_attack()


# =========================================================
# ОСВОБОЖДЕНИЕ ИГРОКА
# =========================================================

func _release_captured_target() -> void:
	if is_instance_valid(captured_target):
		if captured_target.has_method(
			&"set_external_movement_lock"
		):
			captured_target.call(
				&"set_external_movement_lock",
				self,
				false
			)

	captured_target = null

	target_is_pinned = false
	pinned_target_time_left = 0.0
	pinned_position = Vector2.ZERO


# =========================================================
# ЗАВЕРШЕНИЕ СПЕЦИАЛЬНОЙ АТАКИ
# =========================================================

func _finish_special_attack() -> void:
	# Дополнительная страховка:
	# в преследование нельзя переходить,
	# пока игрок оглушён.
	if target_is_pinned:
		_begin_wait_player_recovery()
		return

	_release_captured_target()
	_set_charge_hitbox_enabled(false)

	current_state = BullState.CHASE
	state_elapsed = 0.0

	charge_direction = Vector2.ZERO

	retreat_direction = Vector2.ZERO
	retreat_travelled = 0.0
	
	recovery_wander_target = Vector2.ZERO
	recovery_wander_retarget_left = 0.0

	charge_cooldown_left = charge_cooldown
	melee_cooldown_left = 0.4

	velocity = Vector2.ZERO

	if visual != null:
		visual.scale = visual_base_scale

	current_target = _find_player()


# =========================================================
# СБРОС СОСТОЯНИЯ
# =========================================================

func _reset_special_attack() -> void:
	_release_captured_target()
	_set_charge_hitbox_enabled(false)

	current_state = BullState.CHASE
	state_elapsed = 0.0

	charge_direction = Vector2.ZERO

	retreat_direction = Vector2.ZERO
	retreat_travelled = 0.0
	
	recovery_wander_target = Vector2.ZERO
	recovery_wander_retarget_left = 0.0

	charge_cooldown_left = first_charge_delay
	melee_cooldown_left = 0.3

	velocity = Vector2.ZERO

	if visual != null:
		visual.scale = visual_base_scale


# =========================================================
# ЗОНА ЗАХВАТА
# =========================================================

func _set_charge_hitbox_enabled(
	enabled: bool
) -> void:
	if charge_hitbox == null:
		return

	charge_hitbox.set_deferred(
		"monitoring",
		enabled
	)


# =========================================================
# ПОИСК ИГРОКА
# =========================================================

func _find_player() -> Node2D:
	var player := (
		get_tree().get_first_node_in_group(
			&"Player"
		) as Node2D
	)

	if not _is_valid_player(player):
		return null

	return player


func _is_valid_player(
	target: Node
) -> bool:
	if not is_instance_valid(target):
		return false

	if target.is_queued_for_deletion():
		return false

	if not target.is_in_group(
		&"Player"
	):
		return false

	if not target.has_method(
		&"take_damage"
	):
		return false

	var target_is_dead = target.get(
		"is_dead"
	)

	if target_is_dead == true:
		return false

	return true


# =========================================================
# ГРАНИЦЫ КОМНАТЫ
# =========================================================

func _clamp_to_room() -> void:
	if room_limits == Rect2():
		return

	var minimum_x: float = (
		room_limits.position.x
		+ room_edge_margin
	)

	var maximum_x: float = (
		room_limits.end.x
		- room_edge_margin
	)

	var minimum_y: float = (
		room_limits.position.y
		+ room_edge_margin
	)

	var maximum_y: float = (
		room_limits.end.y
		- room_edge_margin
	)

	if (
		minimum_x >= maximum_x
		or minimum_y >= maximum_y
	):
		global_position = (
			room_limits.get_center()
		)
		return

	global_position = Vector2(
		clampf(
			global_position.x,
			minimum_x,
			maximum_x
		),
		clampf(
			global_position.y,
			minimum_y,
			maximum_y
		)
	)


func _is_at_room_edge() -> bool:
	if room_limits == Rect2():
		return false

	return (
		global_position.x
		<= room_limits.position.x
		+ room_edge_margin
		or global_position.x
		>= room_limits.end.x
		- room_edge_margin
		or global_position.y
		<= room_limits.position.y
		+ room_edge_margin
		or global_position.y
		>= room_limits.end.y
		- room_edge_margin
	)


func _is_position_inside_room(
	position_to_check: Vector2
) -> bool:
	if room_limits == Rect2():
		return true

	return (
		position_to_check.x
		>= room_limits.position.x
		+ room_edge_margin
		and position_to_check.x
		<= room_limits.end.x
		- room_edge_margin
		and position_to_check.y
		>= room_limits.position.y
		+ room_edge_margin
		and position_to_check.y
		<= room_limits.end.y
		- room_edge_margin
	)


# =========================================================
# СМЕРТЬ
# =========================================================

func die() -> void:
	if is_dead:
		return

	_release_captured_target()
	_set_charge_hitbox_enabled(false)

	AudioManager.play_world_sfx(
		&"bull_bellow",
		global_position,
		-7.0,
		0.68,
		0.78
	)

	AudioManager.play_world_sfx(
		&"body_fall_heavy",
		global_position,
		-6.0,
		0.82,
		0.90
	)

	super()

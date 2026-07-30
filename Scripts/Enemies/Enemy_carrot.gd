extends BaseEnemy


# =========================================================
# КОНСТАНТЫ
# =========================================================

const TARGET_GROUPS: Array[StringName] = [
	&"Player",
	&"Companions"
]


# =========================================================
# ПАРАМЕТРЫ АТАКИ
# =========================================================

@export_group("Attack")

@export_range(0, 100, 1)
var damage: int = 1

@export_range(0.05, 10.0, 0.05)
var attack_cooldown: float = 1.0


# =========================================================
# ПАРАМЕТРЫ ДВИЖЕНИЯ
# =========================================================

@export_group("Movement")

@export_range(0.0, 1000.0, 5.0)
var speed: float = 100.0

@export_range(0.0, 500.0, 1.0)
var min_distance: float = 30.0

@export_range(0.0, 100.0, 1.0)
var room_margin: float = 10.0


# =========================================================
# ПАРАМЕТРЫ РЫВКА
# =========================================================

@export_group("Dash")

@export_range(0.05, 30.0, 0.05)
var dash_cooldown: float = 3.0

@export_range(0.05, 10.0, 0.05)
var dash_duration: float = 0.3

@export_range(1.0, 20.0, 0.1)
var dash_speed_multiplier: float = 4.0

@export var dash_color: Color = Color.ORANGE


# =========================================================
# УЗЛЫ
# =========================================================

@onready var attack_area: Area2D = (
	get_node_or_null("AttackArea") as Area2D
)


# =========================================================
# СОСТОЯНИЕ
# =========================================================

var current_target: Node2D = null

var attack_targets: Array[Node2D] = []

var attack_timer: Timer = null

var dash_timer: Timer = null

var dash_cooldown_timer: Timer = null

var is_dashing: bool = false

var base_self_modulate: Color = Color.WHITE


# =========================================================
# ИНИЦИАЛИЗАЦИЯ
# =========================================================

func _ready() -> void:
	# Значения BaseEnemy по умолчанию уже равны 3.
	# Благодаря отсутствию принудительного присваивания
	# HP теперь можно менять через инспектор.
	super()

	add_to_group(&"Enemies")

	base_self_modulate = self_modulate

	_create_attack_timer()
	_create_dash_timer()
	_create_dash_cooldown_timer()
	_connect_attack_area()

	# Враг не должен двигаться и атаковать,
	# пока его комната не активирована.
	set_active(false)


func _create_attack_timer() -> void:
	attack_timer = Timer.new()

	attack_timer.name = &"AttackTimer"
	attack_timer.one_shot = false
	attack_timer.process_callback = (
		Timer.TIMER_PROCESS_PHYSICS
	)

	attack_timer.timeout.connect(
		_on_attack_timer_timeout
	)

	add_child(attack_timer)


func _create_dash_timer() -> void:
	dash_timer = Timer.new()

	dash_timer.name = &"DashTimer"
	dash_timer.one_shot = true
	dash_timer.process_callback = (
		Timer.TIMER_PROCESS_PHYSICS
	)

	dash_timer.timeout.connect(
		_on_dash_end
	)

	add_child(dash_timer)


func _create_dash_cooldown_timer() -> void:
	dash_cooldown_timer = Timer.new()

	dash_cooldown_timer.name = &"DashCooldownTimer"
	dash_cooldown_timer.one_shot = true
	dash_cooldown_timer.process_callback = (
		Timer.TIMER_PROCESS_PHYSICS
	)

	dash_cooldown_timer.timeout.connect(
		_on_dash_cooldown_end
	)

	add_child(dash_cooldown_timer)


func _connect_attack_area() -> void:
	if attack_area == null:
		push_warning(
			"Enemy_carrot: не найден узел AttackArea."
		)
		return

	if not attack_area.body_entered.is_connected(
		_on_attack_area_body_entered
	):
		attack_area.body_entered.connect(
			_on_attack_area_body_entered
		)

	if not attack_area.body_exited.is_connected(
		_on_attack_area_body_exited
	):
		attack_area.body_exited.connect(
			_on_attack_area_body_exited
		)


# =========================================================
# АКТИВАЦИЯ КОМНАТЫ
# =========================================================

func set_active(
	active: bool
) -> void:
	if not active:
		_stop_all_actions()

	super(active)

	if active and not is_dead:
		_start_dash_cooldown()


func _stop_all_actions() -> void:
	velocity = Vector2.ZERO
	current_target = null

	attack_targets.clear()

	is_dashing = false
	self_modulate = base_self_modulate

	if is_instance_valid(attack_timer):
		attack_timer.stop()

	if is_instance_valid(dash_timer):
		dash_timer.stop()

	if is_instance_valid(dash_cooldown_timer):
		dash_cooldown_timer.stop()


# =========================================================
# ДВИЖЕНИЕ
# =========================================================

func _physics_process(
	_delta: float
) -> void:
	if is_dead or not is_active:
		velocity = Vector2.ZERO
		return

	current_target = _find_nearest_target()

	if not _is_valid_target(current_target):
		current_target = null
		velocity = Vector2.ZERO
		return

	_move_towards_target()
	move_and_slide()
	_clamp_to_room()


func _move_towards_target() -> void:
	if current_target == null:
		velocity = Vector2.ZERO
		return

	var target_position: Vector2 = (
		current_target.global_position
	)

	var offset_to_target: Vector2 = (
		target_position
		- global_position
	)

	var distance_to_target: float = (
		offset_to_target.length()
	)

	if distance_to_target <= min_distance:
		velocity = Vector2.ZERO
		return

	var movement_direction: Vector2 = (
		offset_to_target.normalized()
	)

	var current_speed: float = speed

	if is_dashing:
		current_speed *= maxf(
			dash_speed_multiplier,
			1.0
		)

	velocity = (
		movement_direction
		* current_speed
	)


func _clamp_to_room() -> void:
	if not room_limits.has_area():
		return

	var minimum_x: float = (
		room_limits.position.x
		+ room_margin
	)

	var maximum_x: float = (
		room_limits.end.x
		- room_margin
	)

	var minimum_y: float = (
		room_limits.position.y
		+ room_margin
	)

	var maximum_y: float = (
		room_limits.end.y
		- room_margin
	)

	if minimum_x > maximum_x:
		global_position.x = (
			room_limits.get_center().x
		)
	else:
		global_position.x = clampf(
			global_position.x,
			minimum_x,
			maximum_x
		)

	if minimum_y > maximum_y:
		global_position.y = (
			room_limits.get_center().y
		)
	else:
		global_position.y = clampf(
			global_position.y,
			minimum_y,
			maximum_y
		)


# =========================================================
# ПОИСК ЦЕЛИ
# =========================================================

func _find_nearest_target() -> Node2D:
	var nearest_target: Node2D = null
	var nearest_distance_squared: float = INF

	for group_name: StringName in TARGET_GROUPS:
		var group_nodes: Array[Node] = (
			get_tree().get_nodes_in_group(
				group_name
			)
		)

		for candidate: Node in group_nodes:
			if not _is_valid_target(candidate):
				continue

			var target: Node2D = (
				candidate as Node2D
			)

			if target == null:
				continue

			var distance_squared: float = (
				global_position.distance_squared_to(
					target.global_position
				)
			)

			if distance_squared >= nearest_distance_squared:
				continue

			nearest_distance_squared = (
				distance_squared
			)

			nearest_target = target

	return nearest_target


func _is_valid_target(
	target: Node
) -> bool:
	if not is_instance_valid(target):
		return false

	if target.is_queued_for_deletion():
		return false

	if not target is Node2D:
		return false

	return is_player_side_target(target)


# =========================================================
# ЗОНА АТАКИ
# =========================================================

func _on_attack_area_body_entered(
	body: Node
) -> void:
	if is_dead or not is_active:
		return

	if not _is_valid_target(body):
		return

	var target: Node2D = body as Node2D

	if target == null:
		return

	if not attack_targets.has(target):
		attack_targets.append(target)

	if (
		is_instance_valid(attack_timer)
		and attack_timer.is_stopped()
	):
		_start_attack_timer()


func _on_attack_area_body_exited(
	body: Node
) -> void:
	var target: Node2D = body as Node2D

	if target == null:
		return

	attack_targets.erase(target)

	if (
		attack_targets.is_empty()
		and is_instance_valid(attack_timer)
	):
		attack_timer.stop()


func _start_attack_timer() -> void:
	if not is_instance_valid(attack_timer):
		return

	if is_dead or not is_active:
		return

	attack_timer.start(
		maxf(
			attack_cooldown,
			0.05
		)
	)


func _on_attack_timer_timeout() -> void:
	if is_dead or not is_active:
		attack_timer.stop()
		return

	var target: Node2D = (
		_find_nearest_attack_target()
	)

	if target == null:
		attack_timer.stop()
		return

	if damage <= 0:
		return

	target.call(
		&"take_damage",
		damage
	)


func _find_nearest_attack_target() -> Node2D:
	var nearest_target: Node2D = null
	var nearest_distance_squared: float = INF

	# Копия массива позволяет удалять невалидные
	# цели во время обхода.
	var stored_targets: Array[Node2D] = (
		attack_targets.duplicate()
	)

	for stored_target: Node2D in stored_targets:
		if not _is_valid_target(stored_target):
			attack_targets.erase(stored_target)
			continue

		var distance_squared: float = (
			global_position.distance_squared_to(
				stored_target.global_position
			)
		)

		if distance_squared >= nearest_distance_squared:
			continue

		nearest_distance_squared = (
			distance_squared
		)

		nearest_target = stored_target

	return nearest_target


# =========================================================
# РЫВОК
# =========================================================

func start_dash() -> void:
	if is_dead or not is_active:
		return

	if is_dashing:
		return

	is_dashing = true
	self_modulate = dash_color

	if is_instance_valid(dash_timer):
		dash_timer.start(
			maxf(
				dash_duration,
				0.05
			)
		)


func _on_dash_end() -> void:
	if is_dead:
		return

	is_dashing = false
	self_modulate = base_self_modulate

	if is_active:
		_start_dash_cooldown()


func _start_dash_cooldown() -> void:
	if not is_instance_valid(
		dash_cooldown_timer
	):
		return

	if is_dead or not is_active:
		return

	dash_cooldown_timer.start(
		maxf(
			dash_cooldown,
			0.05
		)
	)


func _on_dash_cooldown_end() -> void:
	if is_dead or not is_active:
		return

	start_dash()


# =========================================================
# СМЕРТЬ
# =========================================================

func die() -> void:
	if is_dead:
		return

	_stop_all_actions()

	super()

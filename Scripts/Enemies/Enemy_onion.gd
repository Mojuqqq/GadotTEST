extends BaseEnemy

const CRY_SOUNDS: Array[StringName] = [
	&"onion_cry_01",
	&"onion_cry_02",
	&"onion_cry_03"
]

# =========================================================
# ПАРАМЕТРЫ
# =========================================================

@export_group("Movement")

@export_range(0.0, 1000.0, 5.0)
var speed: float = 200.0

@export_range(0.05, 10.0, 0.05)
var min_walk_duration: float = 0.5

@export_range(0.05, 10.0, 0.05)
var max_walk_duration: float = 1.5

@export_range(0.0, 100.0, 1.0)
var room_margin: float = 10.0


@export_group("Tear Effect")

@export_range(0.1, 30.0, 0.1)
var tear_duration: float = 3.0


# =========================================================
# СОСТОЯНИЕ
# =========================================================

var player: Node2D = null

var direction: Vector2 = Vector2.RIGHT

var walk_timer: Timer = null


# =========================================================
# ИНИЦИАЛИЗАЦИЯ
# =========================================================

func _ready() -> void:
	hp = 2
	max_hp = 2

	super()

	add_to_group(&"Enemies")

	_create_walk_timer()
	_find_player()


func _create_walk_timer() -> void:
	walk_timer = Timer.new()

	walk_timer.name = &"WalkTimer"
	walk_timer.one_shot = true
	walk_timer.process_callback = (
		Timer.TIMER_PROCESS_PHYSICS
	)

	walk_timer.timeout.connect(
		_on_walk_timer_timeout
	)

	add_child(walk_timer)


# =========================================================
# АКТИВАЦИЯ КОМНАТЫ
# =========================================================

func set_active(
	active: bool
) -> void:
	if is_dead:
		return

	# Останавливаем таймер до отключения обработки узла.
	if not active:
		if is_instance_valid(walk_timer):
			walk_timer.stop()

	super(active)

	if not active:
		return

	_find_player()
	_choose_new_direction()
	_restart_walk_timer()


# =========================================================
# ДВИЖЕНИЕ
# =========================================================

func _physics_process(
	_delta: float
) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	if not is_active:
		velocity = Vector2.ZERO
		return

	velocity = direction * speed

	move_and_slide()

	# Если лук столкнулся со стеной или другим препятствием,
	# сразу выбираем новое направление.
	if get_slide_collision_count() > 0:
		_choose_new_direction()
		_restart_walk_timer()

	_clamp_to_room()


func _choose_new_direction() -> void:
	var angle: float = randf_range(
		0.0,
		TAU
	)

	direction = Vector2.RIGHT.rotated(
		angle
	)


func _clamp_to_room() -> void:
	if room_limits == Rect2():
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

	# Страховка для слишком маленькой комнаты.
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
# ТАЙМЕР ДВИЖЕНИЯ
# =========================================================

func _on_walk_timer_timeout() -> void:
	if is_dead:
		return

	if not is_active:
		return

	_choose_new_direction()
	_restart_walk_timer()


func _restart_walk_timer() -> void:
	if not is_instance_valid(walk_timer):
		return

	if is_dead or not is_active:
		return

	var minimum_duration: float = maxf(
		minf(
			min_walk_duration,
			max_walk_duration
		),
		0.05
	)

	var maximum_duration: float = maxf(
		maxf(
			min_walk_duration,
			max_walk_duration
		),
		minimum_duration
	)

	var next_duration: float = randf_range(
		minimum_duration,
		maximum_duration
	)

	walk_timer.start(
		next_duration
	)


# =========================================================
# ПОИСК ИГРОКА
# =========================================================

func _find_player() -> void:
	player = null

	var candidate: Node2D = (
		get_tree().get_first_node_in_group(
			&"Player"
		) as Node2D
	)

	if not is_instance_valid(candidate):
		return

	if candidate.is_queued_for_deletion():
		return

	player = candidate


func _get_valid_player() -> Node2D:
	if not is_instance_valid(player):
		_find_player()

	elif player.is_queued_for_deletion():
		_find_player()

	if not is_instance_valid(player):
		return null

	if player.is_queued_for_deletion():
		return null

	return player

func _play_random_cry() -> void:
	var sound_name: StringName = (
		CRY_SOUNDS.pick_random()
	)

	AudioManager.play_world_sfx(
		sound_name,
		global_position,
		-16.0,
		0.96,
		1.04
	)

# =========================================================
# СМЕРТЬ И ЭФФЕКТ СЛЁЗ
# =========================================================

func die() -> void:
	if is_dead:
		return

	if is_instance_valid(walk_timer):
		walk_timer.stop()

	_play_random_cry()

	_apply_tear_effect_to_player()

	super()


func _apply_tear_effect_to_player() -> void:
	if tear_duration <= 0.0:
		return

	var current_player: Node2D = (
		_get_valid_player()
	)

	if current_player == null:
		return

	if not current_player.has_method(
		&"apply_tear_effect"
	):
		push_warning(
			"Enemy_onion: у игрока отсутствует "
			+ "метод apply_tear_effect()."
		)
		return

	current_player.call(
		&"apply_tear_effect",
		tear_duration
	)

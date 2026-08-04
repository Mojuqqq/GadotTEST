extends BaseBoss


# =========================================================
# ПАРАМЕТРЫ БОССА
# =========================================================


@export_group("Base Combat")

@export var speed: float = 80.0

@export var melee_range: float = 300.0
@export var melee_damage: int = 3
@export var melee_cooldown: float = 1.0

@export var ranged_damage: int = 2
@export var ranged_cooldown: float = 2.0

@export var bullet_scene: PackedScene
@export var bullet_speed: float = 350.0


@export_group("Floor Scaling")

# Здоровье петуха на первом этаже.
@export_range(1, 500, 1)
var base_boss_hp: int = 32

# +25% здоровья за каждый следующий этаж.
@export_range(0.0, 1.0, 0.05)
var boss_hp_growth_per_floor: float = 0.25


@export_group("Phase Two")

# Вторая фаза начинается при 50% здоровья.
@export_range(0.1, 0.9, 0.05)
var phase_two_hp_ratio: float = 0.5

# Ускорение передвижения.
@export_range(1.0, 3.0, 0.05)
var phase_two_speed_multiplier: float = 1.5

# Уменьшение перезарядки ближней атаки.
@export_range(0.1, 1.0, 0.05)
var phase_two_melee_cooldown_multiplier: float = 0.65

# Уменьшение перезарядки дальней атаки.
@export_range(0.1, 1.0, 0.05)
var phase_two_ranged_cooldown_multiplier: float = 0.6

# Ускорение снарядов.
@export_range(1.0, 3.0, 0.05)
var phase_two_bullet_speed_multiplier: float = 1.3


# =========================================================
# СОСТОЯНИЕ
# =========================================================

var current_target: Node2D = null
var is_melee_mode: bool = false
var attack_timer: Timer = null


var phase_two_active: bool = false
var phase_two_threshold_hp: int = 0

var initial_speed: float = 0.0
var initial_melee_cooldown: float = 0.0
var initial_ranged_cooldown: float = 0.0
var initial_bullet_speed: float = 0.0


# =========================================================
# ИНИЦИАЛИЗАЦИЯ
# =========================================================

func _ready() -> void:
	var floor_number: int = maxi(
		GameManager.current_floor,
		1
	)

	var hp_multiplier: float = (
		1.0
		+ boss_hp_growth_per_floor
		* float(floor_number - 1)
	)

	max_hp = ceili(
		float(base_boss_hp)
		* hp_multiplier
	)

	hp = max_hp

	phase_two_threshold_hp = maxi(
		ceili(
			float(max_hp)
			* phase_two_hp_ratio
		),
		1
	)

	initial_speed = speed
	initial_melee_cooldown = melee_cooldown
	initial_ranged_cooldown = ranged_cooldown
	initial_bullet_speed = bullet_speed

	super()

	print(
		"[BOSS COCK] floor=",
		floor_number,
		" | hp=",
		max_hp,
		" | phase_2_at=",
		phase_two_threshold_hp
	)

	add_to_group("Enemies")

	if hp_bar != null:
		hp_bar.size = Vector2(150.0, 20.0)
		hp_bar.position = Vector2(-75.0, -80.0)

		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = Color(0.8, 0.1, 0.1)

		hp_bar.add_theme_stylebox_override(
			"fill",
			fill_style
		)

	attack_timer = Timer.new()
	attack_timer.name = "AttackTimer"
	attack_timer.one_shot = true
	attack_timer.wait_time = ranged_cooldown

	attack_timer.timeout.connect(
		_on_attack_timer_timeout
	)

	add_child(attack_timer)



# =========================================================
# ДВИЖЕНИЕ И ВЫБОР ЦЕЛИ
# =========================================================
func _update_phase_two() -> void:
	if phase_two_active:
		return

	if hp <= 0:
		return

	if hp > phase_two_threshold_hp:
		return

	phase_two_active = true

	speed = (
		initial_speed
		* phase_two_speed_multiplier
	)

	melee_cooldown = maxf(
		initial_melee_cooldown
		* phase_two_melee_cooldown_multiplier,
		0.15
	)

	ranged_cooldown = maxf(
		initial_ranged_cooldown
		* phase_two_ranged_cooldown_multiplier,
		0.25
	)

	bullet_speed = (
		initial_bullet_speed
		* phase_two_bullet_speed_multiplier
	)

	# Ускоряем следующую атаку после смены фазы.
	if (
		attack_timer != null
		and is_active
	):
		attack_timer.stop()
		attack_timer.start(0.25)

	# Визуально показываем переход во вторую фазу.
	if is_instance_valid(
		damage_visual
	):
		damage_visual_base_modulate = Color(
			1.0,
			0.65,
			0.65,
			1.0
		)

		damage_visual.modulate = (
			damage_visual_base_modulate
		)

	print(
		"[BOSS COCK] PHASE 2",
		" | floor=",
		GameManager.current_floor,
		" | hp=",
		hp,
		"/",
		max_hp,
		" | speed=",
		speed,
		" | melee_cd=",
		melee_cooldown,
		" | ranged_cd=",
		ranged_cooldown,
		" | bullet_speed=",
		bullet_speed
	)

func _physics_process(
	_delta: float
) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_update_phase_two()

	current_target = _find_nearest_target()

	if not _is_valid_target(current_target):
		current_target = null
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var distance: float = global_position.distance_to(
		current_target.global_position
	)

	var direction: Vector2 = (
		current_target.global_position
		- global_position
	).normalized()

	is_melee_mode = distance <= melee_range

	if is_melee_mode:
		velocity = direction * speed * 0.3
	else:
		velocity = direction * speed

	move_and_slide()

	_clamp_to_room()


func _find_nearest_target() -> Node2D:
	var nearest_target: Node2D = null
	var nearest_distance: float = INF

	var target_groups: Array[StringName] = [
		&"Player",
		&"Companions"
	]

	for group_name in target_groups:
		for candidate in get_tree().get_nodes_in_group(
			group_name
		):
			if not _is_valid_target(candidate):
				continue

			var target := candidate as Node2D

			if target == null:
				continue

			var distance: float = (
				global_position.distance_to(
					target.global_position
				)
			)

			if distance >= nearest_distance:
				continue

			nearest_distance = distance
			nearest_target = target

	return nearest_target


func _is_valid_target(
	target: Node
) -> bool:
	if not is_instance_valid(target):
		return false

	if target.is_queued_for_deletion():
		return false

	if not target.has_method("take_damage"):
		return false

	if target.is_in_group("Player"):
		return true

	if target.is_in_group("Companions"):
		return true

	return false


func _clamp_to_room() -> void:
	if room_limits == Rect2():
		return

	global_position.x = clampf(
		global_position.x,
		room_limits.position.x + 10.0,
		room_limits.position.x
		+ room_limits.size.x
		- 10.0
	)

	global_position.y = clampf(
		global_position.y,
		room_limits.position.y + 10.0,
		room_limits.position.y
		+ room_limits.size.y
		- 10.0
	)


# =========================================================
# АКТИВНОСТЬ КОМНАТЫ
# =========================================================

func set_active(
	active: bool
) -> void:
	super(active)

	if attack_timer == null:
		return

	if active:
		current_target = _find_nearest_target()

		attack_timer.wait_time = 0.5
		attack_timer.start()
	else:
		current_target = null
		velocity = Vector2.ZERO
		attack_timer.stop()


# =========================================================
# АТАКА
# =========================================================

func _on_attack_timer_timeout() -> void:
	if not is_active:
		return

	if is_dead:
		return

	current_target = _find_nearest_target()

	if not _is_valid_target(current_target):
		current_target = null

		attack_timer.wait_time = 0.5
		attack_timer.start()
		return

	var distance: float = global_position.distance_to(
		current_target.global_position
	)

	is_melee_mode = distance <= melee_range

	if is_melee_mode:
		melee_attack(current_target)
	else:
		ranged_attack(current_target)

	attack_timer.wait_time = (
		melee_cooldown
		if is_melee_mode
		else ranged_cooldown
	)

	attack_timer.start()


func melee_attack(
	target: Node2D
) -> void:
	if not _is_valid_target(target):
		return

	var distance: float = global_position.distance_to(
		target.global_position
	)

	if distance > melee_range:
		return

	target.take_damage(melee_damage)



func ranged_attack(
	target: Node2D
) -> void:
	if not _is_valid_target(target):
		return

	if bullet_scene == null:
		push_warning(
			"У босса не назначена сцена снаряда."
		)
		return

	var bullet := bullet_scene.instantiate()

	if bullet == null:
		push_warning(
			"Не удалось создать снаряд босса."
		)
		return

	var current_scene: Node = get_tree().current_scene

	if current_scene == null:
		bullet.queue_free()
		return

	current_scene.add_child(bullet)

	if not bullet is Node2D:
		bullet.queue_free()
		return

	var bullet_node := bullet as Node2D

	bullet_node.global_position = global_position

	var direction_to_target: Vector2 = (
		target.global_position
		- global_position
	).normalized()

	if bullet.has_method("setup"):
		bullet.setup(
			direction_to_target,
			bullet_speed,
			ranged_damage
		)

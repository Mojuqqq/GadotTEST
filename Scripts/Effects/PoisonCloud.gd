extends Area2D

const PLAYER_POISON_COOLDOWN_META: StringName = (
	&"player_poison_damage_available_at_msec"
)

# Урон по врагам. Он зависит от урона яйца,
# создавшего ядовитую лужу.
@export var damage_per_tick: int = 1

# Собственный урон по игроку не масштабируется
# вместе с характеристикой damage.
@export_range(1, 10, 1)
var player_damage_per_tick: int = 1

# Минимальный интервал между успешными
# тиками яда по игроку.
@export_range(0.1, 5.0, 0.1)
var player_damage_interval: float = 1.0

@export var tick_interval: float = 1.0
@export var lifetime: float = 4.0


@onready var damage_timer: Timer = $DamageTimer
@onready var life_timer: Timer = $LifeTimer
@onready var visual: AnimatedSprite2D = $Visual


var bodies_inside: Array[Node] = []
var is_disappearing: bool = false


func _ready() -> void:
	if not visual.animation_finished.is_connected(
		_on_visual_animation_finished
	):
		visual.animation_finished.connect(
			_on_visual_animation_finished
		)

	if not damage_timer.timeout.is_connected(
		_on_damage_timer_timeout
	):
		damage_timer.timeout.connect(
			_on_damage_timer_timeout
		)

	if not body_entered.is_connected(
		_on_body_entered
	):
		body_entered.connect(
			_on_body_entered
		)

	if not body_exited.is_connected(
		_on_body_exited
	):
		body_exited.connect(
			_on_body_exited
		)

	if not life_timer.timeout.is_connected(
		start_disappearing
	):
		life_timer.timeout.connect(
			start_disappearing
		)

	damage_timer.wait_time = tick_interval

	life_timer.wait_time = lifetime
	life_timer.one_shot = true

	set_deferred(
		"monitorable",
		true
	)

	set_deferred(
		"monitoring",
		true
	)

	visual.play(&"appear")

	AudioManager.play_world_sfx(
		&"poison_spawn",
		global_position,
		-12.0,
		0.97,
		1.03
	)

	life_timer.start()


# =========================================================
# АНИМАЦИЯ
# =========================================================

func _on_visual_animation_finished() -> void:
	match visual.animation:
		&"appear":
			if not is_disappearing:
				visual.play(&"loop")

		&"disappear":
			queue_free()


func start_disappearing() -> void:
	if is_disappearing:
		return

	is_disappearing = true

	_disable_damage()

	visual.play(&"disappear")


# =========================================================
# ОТКЛЮЧЕНИЕ УРОНА
# =========================================================

func _disable_damage() -> void:
	damage_timer.stop()
	life_timer.stop()

	bodies_inside.clear()

	# Корень PoisonCloud сам является Area2D.
	set_deferred(
		"monitoring",
		false
	)

	set_deferred(
		"monitorable",
		false
	)


# =========================================================
# ТЕЛА ВНУТРИ ЛУЖИ
# =========================================================

func _on_body_entered(
	body: Node
) -> void:
	if is_disappearing:
		return

	if not _can_take_poison_damage(body):
		return

	if not bodies_inside.has(body):
		bodies_inside.append(body)

	_apply_damage(body)

	if damage_timer.is_stopped():
		damage_timer.start()


func _on_body_exited(
	body: Node
) -> void:
	bodies_inside.erase(body)

	if bodies_inside.is_empty():
		damage_timer.stop()


# =========================================================
# ПЕРИОДИЧЕСКИЙ УРОН
# =========================================================

func _on_damage_timer_timeout() -> void:
	if is_disappearing:
		damage_timer.stop()
		return

	var had_valid_target: bool = false

	for body in bodies_inside.duplicate():
		if not is_instance_valid(body):
			bodies_inside.erase(body)
			continue

		if not _can_take_poison_damage(body):
			bodies_inside.erase(body)
			continue

		_apply_damage(body)
		had_valid_target = true

	if had_valid_target:
		AudioManager.play_world_sfx(
			&"poison_tick",
			global_position,
			-26.0,
			0.94,
			1.06
		)

	if bodies_inside.is_empty():
		damage_timer.stop()


func _can_take_poison_damage(
	body: Node
) -> bool:
	if body.is_in_group("Player"):
		return true

	if (
		body.is_in_group("Enemies")
		and body.has_method("take_damage")
	):
		return true

	return false

func _can_apply_player_poison_damage(
	player: Node
) -> bool:
	var current_time_msec: int = (
		Time.get_ticks_msec()
	)

	var available_at_msec: int = int(
		player.get_meta(
			PLAYER_POISON_COOLDOWN_META,
			0
		)
	)

	if current_time_msec < available_at_msec:
		return false

	var cooldown_msec: int = maxi(
		roundi(
			player_damage_interval
			* 1000.0
		),
		1
	)

	player.set_meta(
		PLAYER_POISON_COOLDOWN_META,
		current_time_msec + cooldown_msec
	)

	return true

func _apply_damage(
	body: Node
) -> void:
	if not is_instance_valid(body):
		return

	var telemetry: Node = (
		get_tree().get_first_node_in_group(
			&"BalanceTelemetry"
		)
	)

	# =====================================================
	# УРОН ИГРОКУ
	# =====================================================

	if body.is_in_group(&"Player"):
		if GameManager.game_over_started:
			return

		if not body.has_method(
			&"take_damage"
		):
			return

		if not _can_apply_player_poison_damage(
			body
		):
			return

		body.call(
			&"take_damage",
			maxi(
				player_damage_per_tick,
				1
			)
		)

		return


	# =====================================================
	# УРОН ВРАГУ
	# =====================================================

	if not body.has_method(
		&"take_damage"
	):
		return

	var enemy_hp_before: int = -1

	if body is BaseEnemy:
		var enemy := body as BaseEnemy

		enemy_hp_before = maxi(
			enemy.hp,
			0
		)

	var enemy_actual_damage: int = (
		damage_per_tick
	)

	if enemy_hp_before >= 0:
		enemy_actual_damage = mini(
			damage_per_tick,
			enemy_hp_before
		)

	if enemy_actual_damage <= 0:
		return

	body.call(
		&"take_damage",
		enemy_actual_damage
	)

	var killed_by_poison: bool = (
		enemy_hp_before > 0
		and enemy_actual_damage
		>= enemy_hp_before
	)

	if (
		telemetry != null
		and telemetry.has_method(
			&"record_poison_damage_dealt"
		)
	):
		telemetry.call(
			&"record_poison_damage_dealt",
			body,
			enemy_actual_damage,
			killed_by_poison
		)


# =========================================================
# НАСТРОЙКА
# =========================================================

func setup(
	damage: int,
	duration: float = 4.0,
	interval: float = 1.0
) -> void:
	damage_per_tick = maxi(
		damage,
		1
	)

	lifetime = maxf(
		duration,
		0.1
	)

	tick_interval = maxf(
		interval,
		0.05
	)

	if not is_node_ready():
		return

	damage_timer.wait_time = tick_interval
	life_timer.wait_time = lifetime

	# setup() вызывается после добавления лужи в сцену,
	# поэтому обновляем уже запущенный таймер.
	life_timer.start()


func _exit_tree() -> void:
	bodies_inside.clear()

	if is_instance_valid(damage_timer):
		damage_timer.stop()

	if is_instance_valid(life_timer):
		life_timer.stop()

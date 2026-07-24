extends Area2D


@export var damage_per_tick: int = 1
@export var tick_interval: float = 0.5
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

	for body in bodies_inside.duplicate():
		if not is_instance_valid(body):
			bodies_inside.erase(body)
			continue

		if not _can_take_poison_damage(body):
			bodies_inside.erase(body)
			continue

		_apply_damage(body)

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


func _apply_damage(
	body: Node
) -> void:
	if body.is_in_group("Player"):
		if not GameManager.game_over_started:
			GameManager.take_damage(
				damage_per_tick
			)

		return

	if body.has_method("take_damage"):
		body.take_damage(
			damage_per_tick
		)


# =========================================================
# НАСТРОЙКА
# =========================================================

func setup(
	damage: int,
	duration: float = 4.0,
	interval: float = 0.5
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

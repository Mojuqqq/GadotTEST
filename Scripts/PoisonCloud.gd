extends Area2D

@export var damage_per_tick: int = 1
@export var tick_interval: float = 0.5
@export var lifetime: float = 4.0

@onready var damage_timer: Timer = $DamageTimer
@onready var life_timer: Timer = $LifeTimer

var bodies_inside: Array[Node] = []


func _ready():
	damage_timer.wait_time = tick_interval

	if not damage_timer.timeout.is_connected(_on_damage_timer_timeout):
		damage_timer.timeout.connect(_on_damage_timer_timeout)

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	life_timer.wait_time = lifetime
	life_timer.one_shot = true

	if not life_timer.timeout.is_connected(queue_free):
		life_timer.timeout.connect(queue_free)

	life_timer.start()

	set_deferred("monitorable", true)
	set_deferred("monitoring", true)


func _on_body_entered(body: Node):
	if not _can_take_poison_damage(body):
		return

	if not bodies_inside.has(body):
		bodies_inside.append(body)

	_apply_damage(body)

	if damage_timer.is_stopped():
		damage_timer.start()


func _on_body_exited(body: Node):
	bodies_inside.erase(body)

	if bodies_inside.is_empty():
		damage_timer.stop()


func _on_damage_timer_timeout():
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


func _can_take_poison_damage(body: Node):
	if body.is_in_group("Player"):
		return true

	if body.is_in_group("Enemies") and body.has_method("take_damage"):
		return true

	return false


func _apply_damage(body: Node):
	if body.is_in_group("Player"):
		if not GameManager.game_over_started:
			GameManager.take_damage(damage_per_tick)
		return

	if body.has_method("take_damage"):
		body.take_damage(damage_per_tick)


func setup(
	damage: int,
	duration: float = 4.0,
	interval: float = 0.5
):
	damage_per_tick = damage
	lifetime = duration
	tick_interval = interval

	if is_node_ready():
		damage_timer.wait_time = tick_interval
		life_timer.wait_time = lifetime


func _exit_tree():
	bodies_inside.clear()

	if is_instance_valid(damage_timer):
		damage_timer.stop()

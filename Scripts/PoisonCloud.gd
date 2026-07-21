extends Area2D

@export var damage: int = 1
@export var damage_interval: float = 0.5
@export var lifetime: float = 3.0
@export var slow_factor: float = 0.5  # замедление врагов

var enemies_in_area: Array = []
var damage_timer: Timer = null

func _ready():
	# Таймер для периодического урона
	damage_timer = Timer.new()
	damage_timer.wait_time = damage_interval
	damage_timer.one_shot = false
	damage_timer.timeout.connect(_on_damage_timer_timeout)
	add_child(damage_timer)
	damage_timer.start()
	
	# Таймер для удаления
	var lifetime_timer = Timer.new()
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(queue_free)
	add_child(lifetime_timer)
	lifetime_timer.start()
	
	# Подключаем сигналы
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Визуальный эффект: можно добавить анимацию или пульсацию
	modulate = Color(0.0, 1.0, 0.0, 0.5)  # зелёный полупрозрачный

func _on_body_entered(body):
	if body.is_in_group("Enemies"):
		if not enemies_in_area.has(body):
			enemies_in_area.append(body)
			# Применяем замедление (если есть метод)
			if body.has_method("apply_slow"):
				body.apply_slow(slow_factor)

func _on_body_exited(body):
	if body.is_in_group("Enemies"):
		if enemies_in_area.has(body):
			enemies_in_area.erase(body)
			# Снимаем замедление
			if body.has_method("remove_slow"):
				body.remove_slow()

func _on_damage_timer_timeout():
	for enemy in enemies_in_area:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(damage)

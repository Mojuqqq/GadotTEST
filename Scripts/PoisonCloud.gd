extends Area2D

@export var damage_per_tick: int = 1
@export var tick_interval: float = 0.5
@export var lifetime: float = 4.0

@onready var damage_timer = $DamageTimer
@onready var life_timer = $LifeTimer
@onready var sprite = $Sprite2D

func _ready():
	damage_timer.wait_time = tick_interval
	damage_timer.timeout.connect(_on_damage_timer_timeout)
	damage_timer.start()
	
	life_timer.wait_time = lifetime
	life_timer.one_shot = true
	life_timer.timeout.connect(queue_free)
	life_timer.start()
	
	# Включаем мониторинг после добавления
	await get_tree().physics_frame
	monitorable = true
	monitoring = true

func _on_damage_timer_timeout():
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body.has_method("take_damage") and body.is_in_group("Enemies"):
			body.take_damage(damage_per_tick)

# Настройка параметров извне
func setup(damage: int, duration: float = 4.0, interval: float = 0.5):
	damage_per_tick = damage
	lifetime = duration
	tick_interval = interval

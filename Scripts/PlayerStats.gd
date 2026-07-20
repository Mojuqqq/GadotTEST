extends Resource
class_name PlayerStats

# === ХАРАКТЕРИСТИКИ ===
@export var max_hp: int = 5
@export var damage: int = 1
@export var speed: float = 300.0
@export var fire_rate: float = 1.3
@export var egg_speed: float = 700.0

# Дополнительные флаги для сложных эффектов
@export var bullet_bounce: bool = false
@export var poison_cloud: bool = false
@export var has_chick: bool = false
@export var attack_range_multiplier: float = 1.0  # для увеличения дальности

# Метод для клонирования (если нужно)
func duplicate_stats() -> PlayerStats:
	var copy = PlayerStats.new()
	copy.max_hp = max_hp
	copy.damage = damage
	copy.speed = speed
	copy.fire_rate = fire_rate
	copy.egg_speed = egg_speed
	return copy

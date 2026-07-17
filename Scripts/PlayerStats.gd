extends Resource
class_name PlayerStats

# === ХАРАКТЕРИСТИКИ ===
@export var max_hp: int = 5
@export var damage: int = 1
@export var speed: float = 300.0
@export var fire_rate: float = 0.3   # задержка между выстрелами (сек)
@export var egg_speed: float = 700.0

# Метод для клонирования (если нужно)
func duplicate_stats() -> PlayerStats:
	var copy = PlayerStats.new()
	copy.max_hp = max_hp
	copy.damage = damage
	copy.speed = speed
	copy.fire_rate = fire_rate
	copy.egg_speed = egg_speed
	return copy

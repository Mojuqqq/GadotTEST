extends CanvasLayer

@onready var room_label = $RoomLabel
@onready var enemy_counter = $EnemyCounter
@onready var damage_label = $StatsContainer/DamageLabel
@onready var speed_label = $StatsContainer/SpeedLabel
@onready var fire_rate_label = $StatsContainer/FireRateLabel
@onready var egg_speed_label = $StatsContainer/EggSpeedLabel
@onready var range_label = $StatsContainer/RangeLabel

func _ready():
	# Подключаемся к сигналам GameManager
	GameManager.connect("room_changed", _on_room_changed)
	GameManager.connect("enemies_changed", _on_enemies_changed)
	GameManager.connect("game_over", _on_game_over)
	GameManager.connect("stats_changed", _on_stats_changed) 
	
	# Инициализация
	_on_room_changed("", 0)
	_on_enemies_changed(0)
	# Обновляем статы при старте
	if GameManager.player_stats:
		_on_stats_changed(GameManager.player_stats)
		
	pass

func _on_room_changed(room_name, _index):
	room_label.text = "Комната: " + room_name

func _on_enemies_changed(count):
	enemy_counter.text = "Врагов: " + str(count)

func _on_game_over(victory: bool):
	var text = "ПОБЕДА!" if victory else "ПОРАЖЕНИЕ!"
	print(text)

# Новая функция обновления статов
func _on_stats_changed(stats):
	if stats == null:
		return
	damage_label.text = "Урон: " + str(stats.damage)
	speed_label.text = "Скорость: " + str(stats.speed)
	fire_rate_label.text = "Скорострельность: " + str(stats.fire_rate)
	egg_speed_label.text = "Скорость яйца: " + str(stats.egg_speed)
	# НОВОЕ: отображаем множитель дальности
	range_label.text = "Дальность: x" + str(stats.attack_range_multiplier)

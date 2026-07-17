extends CanvasLayer

@onready var hp_bar = $HPBar
@onready var room_label = $RoomLabel
@onready var enemy_counter = $EnemyCounter
@onready var damage_label = $StatsContainer/DamageLabel
@onready var speed_label = $StatsContainer/SpeedLabel
@onready var fire_rate_label = $StatsContainer/FireRateLabel
@onready var egg_speed_label = $StatsContainer/EggSpeedLabel

func _ready():
	# Подключаемся к сигналам GameManager
	GameManager.connect("player_hp_changed", _on_player_hp_changed)
	GameManager.connect("room_changed", _on_room_changed)
	GameManager.connect("enemies_changed", _on_enemies_changed)
	GameManager.connect("game_over", _on_game_over)
	GameManager.connect("stats_changed", _on_stats_changed) 
	
	# Инициализация
	_on_player_hp_changed(GameManager.player_hp, GameManager.player_max_hp)
	_on_room_changed("", 0)
	_on_enemies_changed(0)
	# Обновляем статы при старте
	if GameManager.player_stats:
		_on_stats_changed(GameManager.player_stats)

func _on_player_hp_changed(hp, max_hp):
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	if hp <= max_hp * 0.25:
		hp_bar.modulate = Color.RED
	elif hp <= max_hp * 0.5:
		hp_bar.modulate = Color.YELLOW
	else:
		hp_bar.modulate = Color.GREEN

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

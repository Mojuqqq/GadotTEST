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
	GameManager.connect("player_speed_changed", _on_player_speed_changed)
	
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

func _on_game_over(
	_victory: bool
) -> void:
	pass

func _on_player_speed_changed(
	value: float
) -> void:
	var displayed_value: float = snappedf(
		maxf(value, 0.0),
		0.01
	)

	speed_label.text = (
		"Скорость: "
		+ str(displayed_value)
	)

# Новая функция обновления статов
func _on_stats_changed(
	stats
) -> void:
	if stats == null:
		return

	damage_label.text = (
		"Урон: "
		+ str(stats.damage)
	)

	var displayed_speed: float = float(
		stats.speed
	)

	var current_player: Node2D = (
		GameManager.player
	)

	if (
		is_instance_valid(current_player)
		and current_player.has_method(
			&"get_current_speed"
		)
	):
		displayed_speed = float(
			current_player.call(
				&"get_current_speed"
			)
		)

	_on_player_speed_changed(
		displayed_speed
	)

	fire_rate_label.text = (
		"Скорострельность: "
		+ str(stats.fire_rate)
	)

	egg_speed_label.text = (
		"Скорость яйца: "
		+ str(stats.egg_speed)
	)

	range_label.text = (
		"Дальность: x"
		+ str(stats.attack_range_multiplier)
	)
